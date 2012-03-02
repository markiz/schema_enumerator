require 'spec_helper'

describe SchemaEnumerator::MigrationGenerator do
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

  let(:connect_options) { { :adapter => 'sqlite' } }
  before(:each) { create_tables(enum.db) }
  let(:enum) { SchemaEnumerator.new(connect_options) }
  let(:blueprint) { enum.table(:test_table_1) }
  let(:target) { enum.table(:test_table_2) }
  subject { described_class.new(blueprint, target) }

  it "creates a sequel migration" do
    migration = subject.sequel_migration
    migration.should be_a(String)
  end

  it "adds missing fields" do
    migration = subject.sequel_migration
    migration.should =~ /add_column.*:pid, "integer"/
  end

  it "knows about some column params" do
    migration = subject.sequel_migration
    migration.should =~ /add_column.*:pid.*:default\s*=>\s*(1|\"1\")/
    migration.should =~ /add_column.*:pid.*:null\s*=>\s*false/
  end

  it "adds missing indices" do
    migration = subject.sequel_migration
    migration.should =~ /add_index.*\[:title\]/
    migration.should =~ /add_index.*\[:pid\]/
  end

  it "knows about some index params" do
    migration = subject.sequel_migration
    migration.should =~ /add_index.*\[:pid\].*:unique\s*=>\s*true/
  end
end
