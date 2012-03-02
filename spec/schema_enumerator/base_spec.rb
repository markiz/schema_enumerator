require 'logger'
require 'spec_helper'

describe SchemaEnumerator do
  def create_tables(db)
    db.create_table! :test_table_1 do
      primary_key :id, :null => false
      column :title, String
      column :body, :text
      index :title
    end

    db.create_table! :test_table_2 do
      primary_key :id, :null => false
      column :title, String, :null => false
      column :body, :text
    end

    db.create_table! :test_table_3 do
      primary_key :id, :null => false
      column :body, :text
    end

    db.create_table! :test_table_4 do
      primary_key :id, :null => false
      column :title, String, :null => false, :size => 50
      column :body, :text
    end

    db.create_table! :test_table_5, :engine => "InnoDB" do
      primary_key :id, :null => false
      column :body, "TEXT CHARSET utf8 COLLATE utf8_general_ci"
    end
  end
  let(:connect_options) { {
    :adapter => 'mysql2',
    :database => "schenum_test",
    :logger => Logger.new("/dev/null")
  } }
  before(:each) { create_tables(subject.db) }
  subject { described_class.new(connect_options) }

  it "has a list of table names" do
    subject.table_names.should include("test_table_1",
                                       "test_table_2",
                                       "test_table_3",
                                       "test_table_4")
  end

  it "has fields" do
    fields = subject.table(:test_table_1).fields
    fields[:id][:db_type].should =~ /int/
    fields[:id][:primary_key].should be_true
    fields[:id][:allow_null].should be_false
    fields[:body][:allow_null].should be_true
  end

  it "knows about engines" do
    subject.table(:test_table_5).engine.should == "InnoDB"
  end

  it "knows about charsets and collations" do
    fields = subject.table(:test_table_5).fields
    fields[:body][:charset].should == "utf8"
    fields[:body][:collate].should == "utf8_general_ci"
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
    # - :indices=>{[:title] => {:columns => [:title],:unique => false}}}
    # + :indices=>{}}
    #
    result.should =~ %r(\-.*allow_null.*true)m
    result.should =~ %r(\+.*allow_null.*false)m
    result.should =~ %r(\-.*indices.*\[:title\])m
    result.should =~ %r(\+.*indices.*\{\})m
  end

  describe "#diff", "as :hash" do
    it "can diff tables and return results as hash" do
      blueprint, checked_table = subject.table(:test_table_1, :test_table_2)
      result = blueprint.diff(checked_table, :hash)
      result.should respond_to(:keys)
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
      missing_field[:db_type].should     =~ /varchar/
    end

    it "recognizes extra fields" do
      blueprint, checked_table = subject.table(:test_table_3, :test_table_1)
      result = blueprint.diff(checked_table, :hash)
      missing_field = result[:extra_fields][:title]
      missing_field.should_not be_nil
      missing_field[:default].should     == nil
      missing_field[:primary_key].should == false
      missing_field[:allow_null].should  == true
      missing_field[:db_type].should     =~ /varchar/
    end

    it "recognizes changed fields" do
      blueprint, checked_table = subject.table(:test_table_1, :test_table_4)
      result = blueprint.diff(checked_table, :hash)
      field = result[:changed_fields][:title]
      field.should_not be_nil
      field[:own][:db_type].should      == "varchar(255)"
      field[:other][:db_type].should    == "varchar(50)"
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
      props[:columns].should == [:title]
      props[:unique].should == false
    end

    it "recognizes extra indices" do
      blueprint, checked_table = subject.table(:test_table_2, :test_table_1)
      result = blueprint.diff(checked_table, :hash)
      extra_index = result[:extra_indices].first
      extra_index.should_not be_nil
      cols, props = extra_index
      cols.should  == [:title]
      props[:columns].should == [:title]
      props[:unique].should == false
    end
  end
end
