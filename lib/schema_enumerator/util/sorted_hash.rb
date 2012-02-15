#
# Hash that keeps its keys sorted
#
require 'schema_enumerator/core_ext/symbol'
class SchemaEnumerator
  module Util
    class SortedHash
      include Enumerable
      def initialize(hash = {})
        @hash = hash
        sort_keys!
        recursively_convert_hashes!
      end

      def each
        @keys.each {|key| yield key, self[key] }
      end

      def [](key)
        @hash[key]
      end

      def []=(key, value)
        @hash[key] = value
        sort_keys!
        recursively_convert_hashes!
      end

      def empty?
        @hash.empty?
      end

      def keys
        @keys
      end

      def values
        map {|k,v| v }
      end

      def delete(key)
        result = @hash.delete(key)
        sort_keys!
        result
      end

      def delete_if(&block)
        result = @hash.delete_if(&block)
        sort_keys!
        result
      end

      def ==(other)
        case other
        when SortedHash
          to_hash == other.to_hash
        when Hash
          @hash == other
        else
          false
        end
      end

      def to_hash
        @hash
      end

      def pretty_print(pp)
        first = true
        pp.group 1, "{", "}" do
          each do |key, value|
            if first
              first = false
            else
              pp.text ","
              pp.breakable ""
            end
            pp.pp key
            pp.text " => "
            pp.group(1) do
              pp.breakable ''
              pp.pp value
            end
          end
        end
      end

      protected

      def sort_keys!
        @keys = @hash.keys.sort
      end

      def recursively_convert_hashes!
        each {|k,v| self[k] = SortedHash.new(v) if v.kind_of?(Hash) }
      end
    end
  end
end
