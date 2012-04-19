begin
  require "diffy"
rescue LoadError => e
  # Plaintext diffs will not work without diffy
end
require "sequel"
require "pp"

class SchemaEnumerator
  def self.loggers
    @loggers ||= []
  end

  def initialize(db_connect_options)
    @db_connect_options = db_connect_options
  end

  def db
    @db ||= Sequel.connect(@db_connect_options, :loggers => SchemaEnumerator.loggers)
  end

  def tables
    @tables ||= tables_by_names.values
  end

  def table(*names)
    if names.count > 1
      names.map {|name| tables_by_names[name.to_s] }
    else
      tables_by_names[names[0].to_s]
    end
  end

  def tables_by_names
    @tables_by_names ||= db.tables.inject({}) do |result, table_name|
      table_name = table_name.to_s
      result[table_name] ||= Table.new(db, table_name)
      result
    end
  end

  def table_names
    tables_by_names.keys
  end

  class Table
    SCHEMA_FIELDS = [:db_type, :primary_key, :default, :allow_null].freeze unless defined?(SCHEMA_FIELDS)

    attr_reader :name, :db
    def initialize(db, name)
      @db   = db
      @name = name
    end

    def schema
      @schema ||= db.schema(name, :reload => true)
    end

    def engine
      if mysql?
        @engine ||= detect_engine
      end
    end

    def fields
      @fields ||= schema.inject({}) do |result, (field, props)|
        result[field.to_sym] = slice_hash(props, SCHEMA_FIELDS)
        if mysql?
          result[field.to_sym][:collate] = detect_collation(field)
          result[field.to_sym][:charset] = detect_charset(field)
        end
        result
      end
    end

    def indices
      @indices ||= db.indexes(name, :partial => true)
    end
    alias_method :indexes, :indices

    def matches?(check_hash = {})
      fields  = check_hash.fetch(:fields,  {})
      indices = check_hash.fetch(:indices, {})
      matches_by_fields?(fields) && matches_by_indices?(indices)
    end

    def matches_by_fields?(fields_hash)
      fields_hash.each do |field, assumption|
        return false unless fields.has_key?(field) == !!assumption
      end
      true
    end

    def matches_by_indices?(indices_hash)
      true
    end

    def to_hash
      result = Util::SortedHash.new({
        :fields  => fields,
        :indices => indices_by_columns
      })
      result[:engine] = engine if mysql?
      result
    end

    def diff(other_table, format = :text)
      case format
      when :text, :color, :html
        own_string   = PP.pp(self.to_hash, "")
        other_string = PP.pp(other_table.to_hash, "")
        Diffy::Diff.new(own_string, other_string).to_s(format)
      when :hash
        hash_diff(other_table)
      end
    end

    def indices_by_columns
      indices.inject({}) do |result, (name, index)|
        result[index[:columns]] = index.dup
        result
      end
    end

    def indices_by_columns_with_names
      indices.inject({}) do |result, (name, index)|
        result[index[:columns]] = index.dup
        result[index[:columns]][:name] = name
        result
      end
    end

    def hash_diff(other_table)
      diff = {
        :missing_fields  => {}, :extra_fields    => {},
        :changed_fields  => {},
        :missing_indices => {}, :extra_indices   => {}
      }

      other_fields = other_table.fields
      other_indices = other_table.indices_by_columns_with_names
      indices = indices_by_columns_with_names

      (fields.keys - other_fields.keys).each do |field|
        diff[:missing_fields][field] = fields[field]
      end

      (other_fields.keys - fields.keys).each do |field|
        diff[:extra_fields][field] = other_fields[field]
      end

      (other_fields.keys & fields.keys).each do |field|
        if fields[field] != other_fields[field]
          diff[:changed_fields][field] = {
            :other => other_fields[field],
            :own   => fields[field]
          }
        end
      end

      (indices.keys - other_indices.keys).each do |index|
        diff[:missing_indices][index] = indices[index]
      end

      (other_indices.keys - indices.keys).each do |index|
        diff[:extra_indices][index] = other_indices[index]
      end

      Util::SortedHash.new(diff)
    end

    protected

    def detect_engine
      tables_dataset.select(:engine).
                     filter(:table_name => name).
                     first[:engine]
    end

    def detect_collation(field)
      field_data(field, :collation_name)
    end

    def detect_charset(field)
      field_data(field, :character_set_name)
    end

    def field_data(field, key)
      fields_data[field.to_s][key]
    end

    def fields_data
      @fields_data ||= fields_dataset.select(:column_name,
                                             :character_set_name,
                                             :collation_name).all.
                                      inject({}) do |result, data|
                                        result[data[:column_name]] = data
                                        result
                                      end
    end

    def fields_dataset
      @fields_dataset ||= mysql_info_db[:columns].
                           filter({
                             :table_schema => db_name,
                             :table_name   => name
                           })
    end

    def tables_dataset
      @tables_dataset ||= mysql_info_db[:tables].
                           filter({
                             :table_schema => db_name
                           })
    end

    def db_name
      db.opts[:database]
    end

    def mysql_info_db
      @@mysql_info_db ||= Sequel.connect(db.opts.merge(:database => "information_schema"),
                                         :loggers => SchemaEnumerator.loggers)
    end

    def mysql?
      db.adapter_scheme.to_s =~ /mysql/
    end

    def slice_hash(hash, keys)
      hash.dup.delete_if {|k,_| !keys.include?(k) }
    end
  end
end
