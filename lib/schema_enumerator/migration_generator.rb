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
