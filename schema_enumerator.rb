require "rubygems"
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
    SCHEMA_FIELDS = [:db_type, :primary_key, :default, :allow_null].freeze

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
      {
        :fields  => fields,
        :indices => indices
      }
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

      diff
    end

    protected

    def slice_hash(hash, keys)
      hash.dup.delete_if {|k,_| !keys.include?(k) }
    end
  end
end


if __FILE__ == $0
  require 'rspec'
  require 'rspec/autorun'

  def create_tables(db)
    db.create_table :test_table_1, :force => true do
      primary_key :id, :null => false
      column :title, :string
      column :body,  :text
      index :title
    end

    db.create_table :test_table_2, :force => true do
      primary_key :id, :null => false
      column :title, :string, :null => false
      column :body, :text
    end

    db.create_table :test_table_3, :force => true do
      primary_key :id, :null => false
      column :body, :text
    end

    db.create_table :test_table_4, :force => true do
      primary_key :id, :null => false
      column :title, :string, :null => false, :size => 50
      column :body, :text
    end
  end

  describe SchemaEnumerator do
    let(:connect_options) { { :adapter => 'sqlite' } }

    before(:all) { create_tables(subject.db) }
    subject { described_class.new(connect_options) }

    it "has a list of table names" do
      subject.table_names.should =~ ["test_table_1",
                                     "test_table_2",
                                     "test_table_3",
                                     "test_table_4"]
    end

    it "has fields" do
      fields = subject.table(:test_table_1).fields
      fields[:id][:db_type].should == "integer"
      fields[:id][:primary_key].should be_true
      fields[:id][:allow_null].should be_false
      fields[:body][:allow_null].should be_true
    end

    it "has indices" do
      indices = subject.table(:test_table_1).indices
      index = indices.values.first
      index[:unique].should be_false
      index[:columns].should == [:title]
    end

    it "can diff tables" do
      blueprint, checked_table = subject.table(:test_table_1, :test_table_2)
      result = blueprint.diff(checked_table)
      # Expect something like
      # -    {:allow_null=>true,
      # +    {:allow_null=>false,
      # And
      #- :indices=>{:test_table_1_title_index=>{:unique=>false, :columns=>[:title]}}}
      # + :indices=>{}}
      #
      result.should =~ %r(-.*allow_null.*true)m
      result.should =~ %r(\+.*allow_null.*false)m
      result.should =~ %r(-.*indices.*title_index)m
      result.should =~ %r(\+.*indices.*\{\})m
    end

    describe "#diff", "as :hash" do
      it "can diff tables and return results as hash" do
        blueprint, checked_table = subject.table(:test_table_1, :test_table_2)
        result = blueprint.diff(checked_table, :hash)
        result.should be_a(Hash)
        result.keys.should include(:missing_indices, :extra_indices,
                                   :missing_fields, :extra_fields,
                                   :changed_fields)
      end

      it "recognizes missing fields" do
        blueprint, checked_table = subject.table(:test_table_1, :test_table_3)
        result = blueprint.diff(checked_table, :hash)
        missing_field = result[:missing_fields][:title]
        missing_field.should_not be_nil
        missing_field[:default].should     == nil
        missing_field[:primary_key].should == false
        missing_field[:allow_null].should  == true
        missing_field[:db_type].should     == "string"
      end

      it "recognizes extra fields" do
        blueprint, checked_table = subject.table(:test_table_3, :test_table_1)
        result = blueprint.diff(checked_table, :hash)
        missing_field = result[:extra_fields][:title]
        missing_field.should_not be_nil
        missing_field[:default].should     == nil
        missing_field[:primary_key].should == false
        missing_field[:allow_null].should  == true
        missing_field[:db_type].should     == "string"
      end

      it "recognizes changed fields" do
        blueprint, checked_table = subject.table(:test_table_1, :test_table_4)
        result = blueprint.diff(checked_table, :hash)
        field = result[:changed_fields][:title]
        field.should_not be_nil
        field[:own][:db_type].should      == "string"
        field[:other][:db_type].should    == "string(50)"
        field[:own][:allow_null].should   == true
        field[:other][:allow_null].should == false
      end

      it "recognizes missing indices" do
        blueprint, checked_table = subject.table(:test_table_1, :test_table_2)
        result = blueprint.diff(checked_table, :hash)
        missing_index = result[:missing_indices].first
        missing_index.should_not be_nil
        cols, props = missing_index
        cols.should  == [:title]
        props.should == {:columns => [:title], :unique => false}
      end

      it "recognizes extra indices" do
        blueprint, checked_table = subject.table(:test_table_2, :test_table_1)
        result = blueprint.diff(checked_table, :hash)
        extra_index = result[:extra_indices].first
        extra_index.should_not be_nil
        cols, props = extra_index
        cols.should  == [:title]
        props.should == {:columns => [:title], :unique => false}
      end
    end
  end
end
