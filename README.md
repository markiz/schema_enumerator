# SchemaEnumerator

Simple schema enumerator and table differ.

## Usage

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

That kinda sums it up.
