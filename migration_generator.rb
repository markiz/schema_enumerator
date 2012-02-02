require File.expand_path('../schema_enumerator', __FILE__)

class SchemaEnumerator
  class MigrationGenerator
    attr_reader :blueprint, :target
    def initialize(blueprint, target)
      @blueprint = blueprint
      @target    = target
    end

    def sequel_migration
      diff = blueprint.diff(target, :hash)

      migration = ""
      migration << "alter_table(:#{target.name}) do\n"

      diff[:missing_fields].each do |field, values|
        column_opts = {
          :null    => values[:allow_null],
          :default => values[:default]
        }.delete_if {|_,v| v.nil? }
        migration << "  add_column :#{field}, \"#{values[:db_type]}\""
        migration << ", #{column_opts.inspect}\n"
      end

      diff[:missing_indices].each do |cols, values|
        index_opts = {
          :unique => values[:unique]
        }
        migration << "  add_index #{cols.inspect}, #{index_opts.inspect}\n"
      end

      migration << "end\n\n"
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
      column :pid,   :integer, :null => false, :default => 1
      index :title
      index :pid, :unique => true
    end

    db.create_table :test_table_2, :force => true do
      primary_key :id, :null => false
      column :title, :string, :null => false
      column :body, :text
    end
  end

  describe SchemaEnumerator::MigrationGenerator do
    let(:connect_options) { { :adapter => 'sqlite' } }
    before(:each) { create_tables(enum.db) }
    let(:enum) { SchemaEnumerator.new(connect_options) }
    let(:blueprint) { enum.table(:test_table_1) }
    let(:target) { enum.table(:test_table_2) }
    subject { described_class.new(blueprint, target) }

    it "creates a sequel migration" do
      migration = subject.sequel_migration
      migration.should be_a(String)
      migration.should =~ /alter_table\(:test_table_2\)/
    end

    it "adds missing fields" do
      migration = subject.sequel_migration
      migration.should =~ /add_column :pid, "integer"/
    end

    it "knows about some column params" do
      migration = subject.sequel_migration
      migration.should =~ /add_column :pid,.*:default\s*=>\s*(1|\"1\")/
      migration.should =~ /add_column :pid,.*:null\s*=>\s*false/
    end

    it "adds missing indices" do
      migration = subject.sequel_migration
      migration.should =~ /add_index \[:title\]/
      migration.should =~ /add_index \[:pid\]/
    end

    it "knows about some index params" do
      migration = subject.sequel_migration
      migration.should =~ /add_index \[:pid\].*:unique\s*=>\s*true/
    end
  end
end
