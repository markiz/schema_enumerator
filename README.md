# SchemaEnumerator

Simple schema enumerator and table differ.

## Dependencies

Gems:

* sequel
* diffy
* gem for your db adapter (sqlite3, pg, mysql2, or whatever sequel supports)

## Usage

### Schema enumerator

    enum = SchemaEnumerator.new({:adapter => 'mysql2', :database => 'test'})
    # see http://sequel.rubyforge.org/rdoc/files/doc/opening_databases_rdoc.html
    # for help on connection to db
    people, users = enum.table("people", "users")
    p people.fields
    p people.indices

    puts people.diff(users, :color)
    # {:fields=>
    #    {:id=>
    #      {:allow_null=>false,
    #       :default=>nil,
    #       :primary_key=>true,
    #       :db_type=>"integer"},
    #     :name=>
    # -    {:allow_null=>true,
    # +    {:allow_null=>false,
    # ...

    # Also advanced diff:
    pp people.diff(users, :hash)
    # {:missing_fields=>{},
    #  :extra_fields=>{},
    #  :changed_fields=>
    #   {:name=>
    #     {:other=>
    #       {:default=>nil,
    #        :primary_key=>false,
    #        :allow_null=>true,
    #        :db_type=>"string"},
    #      :own=>
    #       {:default=>nil,
    #        :primary_key=>false,
    #        :allow_null=>false,
    #        :db_type=>"string"}}},
    #  :missing_indices=>{},
    #  :extra_indices=>{[:name]=>{:unique=>false, :columns=>[:name]}}}

### Migration generator

    enum = SchemaEnumerator.new({:adapter => 'mysql2', :database => 'test'})
    people, users = enum.table(:people, :users)
    # Generates non-destructive migration to make `users`
    # as identical to `people` as possible
    puts SchemaEnumerator::MigrationGenerator.new(:people, :users).sequel_migration
    # alter_table(:users) do
    #   column :job, "varchar(80)", {:null=>true}
    #   index [:name], {:unique=>false}
    # end
