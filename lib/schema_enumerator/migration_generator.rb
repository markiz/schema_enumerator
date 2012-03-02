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
      diff[:missing_fields].each do |field, values|
        column_opts = {
          :null    => values[:allow_null],
          :default => values[:default]
        }.delete_if {|_,v| v.nil? }
        migration << "add_column :#{target.name}, :#{field}, \"#{values[:db_type]}\""
        migration << ", #{column_opts.inspect}\n"
      end

      diff[:extra_fields].each do |field, values|
        migration << "drop_column :#{target.name}, :#{field}\n"
      end

      diff[:changed_fields].each do |field, values|
        own, other = values[:own], values[:other]
        if own[:default] != other[:default]
          migration << "alter_table(:#{target.name}) { set_column_default :#{field}, #{values[:own][:default].inspect} }\n"
        end
        if own[:allow_null] != other[:allow_null]
          migration << "alter_table(:#{target.name}) { set_column_allow_null :#{field}, #{values[:own][:allow_null]} }\n"
        end
      end

      diff[:missing_indices].each do |cols, values|
        index_opts = {
          :unique => values[:unique]
        }
        migration << "add_index :#{target.name}, #{cols.inspect}, #{index_opts.inspect}\n"
      end

      diff[:extra_indices].each do |cols, values|
        migration << "drop_index :#{target.name}, #{cols.inspect}, :name => :#{values[:name]}\n"
      end
      migration
    end

  end
end
