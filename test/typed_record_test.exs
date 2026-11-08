defmodule TypedRecordTest do
  use ExUnit.Case

  import TypedStructs

  defmodule RecordFieldDocs do
    @moduledoc "Record used to verify generated field docs."
    use TypedStruct

    typedrecord :user do
      field :name, String.t(), doc: "Display name in the record."
      field :id, integer(), doc: "Unique user id."
      field :enabled, boolean()
    end

    def docs, do: @moduledoc
  end

  defmodule HiddenRecordFieldDocs do
    @moduledoc false
    use TypedStruct

    typedrecord :user do
      field :secret, String.t(), doc: "Should not become module docs."
    end

    def docs, do: @moduledoc
  end

  defmodule RecordConstructors do
    defmodule Defaults do
      def token, do: "generated-token"
    end

    use TypedStruct

    typedrecord :user, constructors: true, reflection: true do
      field :id, integer(), enforce: true
      field :name, String.t(), default: "anonymous"
      field :token, String.t(), default_fn: &Defaults.token/0
    end
  end

  defmodule RecordFieldsOnlyDocs do
    @moduledoc "Should be replaced"
    use TypedStruct

    typedrecord :item, docs: :fields_only do
      field :name, String.t(), doc: "Item name"
    end

    def docs, do: @moduledoc
  end

  defmodule RecordModuleOnlyDocs do
    @moduledoc "Should stay"
    use TypedStruct

    typedrecord :item, docs: :module_only do
      field :name, String.t(), doc: "Should not be appended"
    end

    def docs, do: @moduledoc
  end

  ############################################################################
  ##                             Standard cases                             ##
  ############################################################################

  test "generates the record with its defaults" do
    require TypedRecord.Record.Actual
    assert TypedRecord.Record.Actual.user() == {:user, 1, nil, "def", :hi}
  end

  test "generates a type for the record in default case" do
    type1 = standardize_first_type(TypedRecord.Record.Actual)
    type2 = standardize_first_type(TypedRecord.Record.Expected)

    assert type1 == type2
  end

  test "generates a type for the record in default case with a record tag" do
    type1 = standardize_first_type(TypedRecord.Public.Actual)
    type2 = standardize_first_type(TypedRecord.Public.Expected)

    assert type1 == type2
  end

  test "generates a type for the record with the `visibility: :public`" do
    type1 = standardize_first_type(TypedRecord.VisibilityPublic.Actual)
    type2 = standardize_first_type(TypedRecord.VisibilityPublic.Expected)

    assert type1 == type2
  end

  test "generates an opaque type if `visibility: :opaque` is set" do
    type1 = standardize_first_type(TypedRecord.VisibilityOpaque.Actual, :opaque)

    type2 =
      standardize_first_type(TypedRecord.VisibilityOpaque.Expected, :opaque)

    assert type1 == type2
  end

  test "generates a private type if `visibility: private` is set" do
    type1 = standardize_first_type(TypedRecord.VisibilityPrivate.Actual, :typep)

    type2 =
      standardize_first_type(TypedRecord.VisibilityPrivate.Expected, :typep)

    assert type1 == type2
  end

  test "generates the struct in a submodule if `module: ModuleName` is set" do
    require TypedRecord.TestRecModule.Rec
    alias TypedRecord.TestRecModule.Rec
    assert Rec.user() == {:user, 1}
  end

  test "adds field docs to moduledoc for typedrecord" do
    assert RecordFieldDocs.docs() =~ "Record used to verify generated field docs."
    assert RecordFieldDocs.docs() =~ "## Fields"
    assert RecordFieldDocs.docs() =~ "`name` - Display name in the record."
    assert RecordFieldDocs.docs() =~ "`id` - Unique user id."
    refute RecordFieldDocs.docs() =~ "`enabled`"
  end

  test "does not override @moduledoc false for typedrecord field docs" do
    assert HiddenRecordFieldDocs.docs() == false
  end

  test "generates record constructors with validation" do
    assert {:ok, {:user, 1, "anonymous", "generated-token"}} =
             RecordConstructors.user_new(%{id: 1})

    assert {:ok, {:user, 2, "bob", "generated-token"}} =
             RecordConstructors.user_from_keyword(id: 2, name: "bob")

    assert {:user, 3, "anonymous", "generated-token"} =
             RecordConstructors.user_new!(%{id: 3})
  end

  test "record constructor reflection helpers are generated" do
    assert RecordConstructors.user_fields() == [:id, :name, :token]
    assert RecordConstructors.user_required() == [:id]
    assert RecordConstructors.user_defaults()[:name] == "anonymous"
    assert RecordConstructors.user_dynamic_defaults() == [:token]
    assert is_list(RecordConstructors.user_types())
  end

  test "record docs mode supports fields_only and module_only" do
    assert RecordFieldsOnlyDocs.docs() =~ "## Fields"
    refute RecordFieldsOnlyDocs.docs() =~ "Should be replaced"

    assert RecordModuleOnlyDocs.docs() == "Should stay"
  end

  ############################################################################
  ##                                Problems                                ##
  ############################################################################

  test "Typedrecord field's name is not an atom" do
    assert_raise(
      ArgumentError,
      "a field name must be an atom, got \"one\"",
      fn ->
        defmodule TestRecordBadKeyType do
          use TypedStruct

          typedrecord :user do
            field "one", integer(), default: 1
            field :two, String.t()
            field :three, atom(), default: :hi
          end
        end
      end
    )
  end

  test "Typedrecord missing record name" do
    assert_raise ArgumentError,
                 ~r/typedrecord requires a record name as the first argument/,
                 fn ->
                   ExUnit.CaptureIO.capture_io(:stderr, fn ->
                     defmodule ScopeTest do
                       use TypedStruct

                       typedrecord do
                         field :in_scope, term()
                       end
                     end
                   end)
                 end
  end

  test "it is not possible to add twice a field with the same name" do
    assert_raise ArgumentError, ~r/the field :name is already set at line/, fn ->
      defmodule InvalidStruct do
        use TypedStruct

        typedrecord :user do
          field :name, String.t()
          field :name, integer()
        end
      end
    end
  end

  test "typedrecord strict mode rejects nullable fields" do
    assert_raise ArgumentError,
                 ~r/strict mode requires each field to define :default or :default_fn, or be enforced/,
                 fn ->
                   defmodule InvalidStrictRecord do
                     use TypedStruct

                     typedrecord :user, strict: true do
                       field :nullable, integer()
                     end
                   end
                 end
  end

  test "unknown typedrecord options are rejected" do
    assert_raise ArgumentError, ~r/unknown options for typedrecord/, fn ->
      defmodule InvalidTypedRecordOptions do
        use TypedStruct

        typedrecord :user, unknown_option: true do
          field :id, integer()
        end
      end
    end
  end

  defmodule MultipleRecords do
    use TypedStruct

    typedrecord :first do
      field :a, integer(), default: 42
    end

    typedrecord :second do
      field :b, String.t(), default: "hello"
    end
  end

  test "multiple typedrecords in the same module" do
    import MultipleRecords, only: [first: 0, second: 0]

    assert first() == {:first, 42}
    assert second() == {:second, "hello"}
  end

  test "typed records are pretty-printed without outer quotes" do
    import RecordConstructors, only: [user: 1]

    rec = user(id: 1, name: "Alice", token: "token123")
    inspected = inspect(rec)

    # Should NOT have outer quotes
    refute String.starts_with?(inspected, "\"")
    refute String.ends_with?(inspected, "\"")

    # Should have the record format
    assert String.starts_with?(inspected, "TypedRecordTest.RecordConstructors.user(")
    assert String.ends_with?(inspected, ")")

    # Field names should be present
    assert inspected =~ "id: 1"
    assert inspected =~ "name: \"Alice\""
    assert inspected =~ "token: \"token123\""
  end

  test "non-record tuples use default tuple printing" do
    regular_tuple = {:mytag, "value", 123}
    inspected = inspect(regular_tuple)

    # Should use curly braces for regular tuples
    assert String.starts_with?(inspected, "{")
    assert String.ends_with?(inspected, "}")
    assert inspected =~ ":mytag"
    assert inspected =~ "\"value\""
    assert inspected =~ "123"
  end
end
