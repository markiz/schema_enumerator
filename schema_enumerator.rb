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
      own_string   = PP.pp(self.to_hash, "")
      other_string = PP.pp(other_table.to_hash, "")
      diff = Diffy::Diff.new(own_string, other_string)
      unless format == false
        diff.to_s(format)
      else
        diff
      end
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

    db.create_table :table_3, :force => true do
      primary_key :id, :null => false
      column :vk_id, :integer, :null => false
      column :vk_name, :string
      index :vk_id
      index :vk_name
    end
  end

  describe SchemaEnumerator do
    let(:connect_options) { { :adapter => 'sqlite' } }

    before(:all) { create_tables(subject.db) }
    subject { described_class.new(connect_options) }

    it "has a list of table names" do
      subject.table_names.should =~ ["test_table_1",
                                     "test_table_2",
                                     "table_3"]
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
  end
end
