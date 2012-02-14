require "sequel"
require "diffy"
require "pp"

class SchemaEnumerator
  def initialize(db_connect_options)
    @db_connect_options = db_connect_options
  end

  def db
    @db ||= Sequel.connect(@db_connect_options)
  end

  def tables
    @tables ||= db.tables.inject({}) do |result, table_name|
      table_name = table_name.to_s
      result[table_name] ||= Table.new(db, table_name)
      result
    end
  end

  def table(*names)
    if names.count > 1
      names.map {|name| tables[name.to_s] }
    else
      tables[names[0].to_s]
    end
  end

  def table_names
    tables.keys
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

    def fields
      @fields ||= schema.inject({}) do |result, (field, props)|
        result[field.to_sym] = slice_hash(props, SCHEMA_FIELDS)
        result
      end
    end

    def indices
      @indices ||= db.indexes(name)
    end
    alias_method :indexes, :indices

    def to_hash
      Util::SortedHash.new({
        :fields  => fields,
        :indices => indices
      })
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
      @indices_by_columns ||= indices.inject({}) do |result, (name, index)|
        result[index[:columns]] = index
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
      other_indices = other_table.indices_by_columns
      indices = indices_by_columns

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

    def slice_hash(hash, keys)
      hash.dup.delete_if {|k,_| !keys.include?(k) }
    end
  end
end
