require "spec_helper"

describe SchemaEnumerator::Util::SortedHash do
  let(:initial_hash) {
    {
      :d => "Hello",
      :e => "World",
      :a => :b,
      :c => "Imagination"
    }
  }
  subject { described_class.new(initial_hash) }

  context "initialization" do
    it "recursively converts hashes" do
      subject = described_class.new(:a => {:b => :c})
      subject.class.should     == described_class
      subject[:a].class.should == described_class
    end
  end

  context "hash methods" do
    describe "#[]" do
      it "returns value for given key" do
        subject[:a].should == :b
        subject[{}].should == nil
      end
    end

    describe "#[]=" do
      it "sets value for the given key" do
        subject[:a] = :d
        subject[:a].should == :d
      end
    end

    describe "#delete_if" do
      it "deletes some elements from the hash" do
        subject.delete_if {|k,v| v.kind_of?(Symbol) }
        subject.keys.should == [:c, :d, :e]
        subject.values.should == ["Imagination", "Hello", "World"]
      end
    end

    describe "#==" do
      it "compares with other hashes" do
        subject.should == initial_hash
      end

      it "compares with other sorted hashes" do
        subject.should == described_class.new(initial_hash)
      end
    end
  end

  context "Enumerable methods" do
    describe "#map" do
      it "returns values in order of succession of keys" do
        subject.map {|k,v| v }.should == [:b, "Imagination", "Hello", "World"]
      end

      it "works after insertion of another key" do
        subject[:b] = "What"
        subject.map {|k,v| v }.should == [:b, "What", "Imagination", "Hello", "World"]
      end
    end
  end

end
