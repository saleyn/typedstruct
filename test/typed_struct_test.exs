defmodule TypedStructTest do
  use ExUnit.Case

  import TypedStructs
  import ExUnit.CaptureIO

  ############################################################################
  ##                               Test data                                ##
  ############################################################################

  defmodule EnforcedTypedStruct do
    use TypedStruct

    typedstruct enforce: true do
      field :enforced_by_default, term()
      field :not_enforced, term(), enforce: false
      field :with_default, integer(), default: 1
      field :with_false_default, boolean(), default: false
      field :with_nil_default, term(), default: nil
    end

    def enforce_keys, do: @enforce_keys
  end

  defmodule TestModule do
    use TypedStruct

    typedstruct module: Struct do
      field :field, term()
    end
  end

  defmodule TestWithNew do
    use TypedStruct

    typedstruct new: true do
      field :field, term()
    end
  end

  defmodule FieldDocsStruct do
    @moduledoc "Struct used to verify generated field docs."
    use TypedStruct

    typedstruct do
      field :name, String.t(), doc: "The display name."
      field :age, non_neg_integer(), doc: "Age in full years."
      field :active, boolean()
    end

    def docs, do: @moduledoc
  end

  defmodule HiddenFieldDocsStruct do
    @moduledoc false
    use TypedStruct

    typedstruct do
      field :secret, String.t(), doc: "Should not become module docs."
    end

    def docs, do: @moduledoc
  end

  defmodule ConstructorsStruct do
    defmodule Defaults do
      def token, do: "generated-token"
    end

    use TypedStruct

    typedstruct constructors: true, introspection: true do
      field :id, integer(), enforce: true
      field :name, String.t(), default: "anonymous"
      field :token, String.t(), default_fn: &Defaults.token/0
    end
  end

  defmodule StrictStruct do
    use TypedStruct

    typedstruct strict: true do
      field :id, integer(), enforce: true
      field :enabled, boolean(), default: true
    end
  end

  defmodule FieldsOnlyDocsStruct do
    @moduledoc "This line should be replaced."
    use TypedStruct

    typedstruct docs: :fields_only do
      field :value, integer(), doc: "Documented field"
    end

    def docs, do: @moduledoc
  end

  defmodule ModuleOnlyDocsStruct do
    @moduledoc "This line should stay as-is."
    use TypedStruct

    typedstruct docs: :module_only do
      field :value, integer(), doc: "Should not be appended"
    end

    def docs, do: @moduledoc
  end

  defmodule LegacyReflectionPlugin do
    def init(_opts), do: quote(do: nil)

    def field(_name, _type, _opts, %Macro.Env{module: module}) do
      fields = Module.get_attribute(module, :ts_fields)
      types = Module.get_attribute(module, :ts_types)
      enforce_keys = Module.get_attribute(module, :ts_enforce_keys)

      if is_nil(fields) or is_nil(types) or is_nil(enforce_keys) do
        raise "typedstruct attributes were cleaned up before plugin field callback"
      end

      quote(do: nil)
    end

    def after_definition(opts) do
      module = Keyword.fetch!(opts, :module)

      fields = Module.get_attribute(module, :ts_fields)
      types = Module.get_attribute(module, :ts_types)
      enforce_keys = Module.get_attribute(module, :ts_enforce_keys)

      if is_nil(fields) or is_nil(types) or is_nil(enforce_keys) do
        raise "typedstruct attributes were cleaned up before plugin after_definition callback"
      end

      quote do
        def legacy_reflection_plugin_loaded?, do: true
      end
    end
  end

  defmodule LegacyReflectionStruct do
    use TypedStruct

    typedstruct do
      plugin LegacyReflectionPlugin, module: __MODULE__

      field :id, integer(), enforce: true
      field :name, String.t(), default: "anonymous"
    end
  end

  ############################################################################
  ##                             Standard cases                             ##
  ############################################################################

  test "generates the struct with its defaults" do
    assert TypedStructs.TestStruct.Actual.__struct__() ==
             %TypedStructs.TestStruct.Actual{
               int: nil,
               string: nil,
               string_with_default: "default",
               mandatory_int: nil
             }
  end

  test "enforces keys for fields with `enforce: true`" do
    assert TypedStructs.TestStruct.Actual.enforce_keys() == [:mandatory_int]
  end

  test "enforces keys by default if `enforce: true` is set at top-level" do
    assert :enforced_by_default in EnforcedTypedStruct.enforce_keys()
  end

  test "does not enforce keys for fields explicitely setting `enforce: false" do
    refute :not_enforced in EnforcedTypedStruct.enforce_keys()
  end

  test "does not enforce keys for fields with a default value" do
    refute :with_default in EnforcedTypedStruct.enforce_keys()
  end

  test "does not enforce keys for fields with a default value set to `false`" do
    refute :with_false_default in EnforcedTypedStruct.enforce_keys()
  end

  test "does not enforce keys for fields with a default value set to `nil`" do
    refute :with_nil_default in EnforcedTypedStruct.enforce_keys()
  end

  test "generates a type for the struct in default case" do
    # Define a second struct with the type expected for TestStruct.

    # Get both types and standardise them (remove line numbers and rename
    # the second struct with the name of the first one).
    type1 = standardize_first_type(TypedStructs.TestStruct.Actual)
    type2 = standardize_first_type(TypedStructs.TestStruct.Expected)

    assert type1 == type2
  end

  test "generates a type for the struct if the `visibility: :public` is set" do
    type1 = standardize_first_type(TypedStructs.PublicTestStruct.Actual)
    type2 = standardize_first_type(TypedStructs.PublicTestStruct.Expected)

    assert type1 == type2
  end

  test "generates an opaque type if `visibility: :opaque` is set" do
    type1 =
      standardize_first_type(TypedStructs.OpaqueTestStruct.Actual, :opaque)

    type2 =
      standardize_first_type(TypedStructs.OpaqueTestStruct.Expected, :opaque)

    assert type1 == type2
  end

  test "generates a private type if `visibility: private` is set" do
    type1 =
      standardize_first_type(TypedStructs.PrivateTestStruct.Actual, :typep)

    type2 =
      standardize_first_type(TypedStructs.PrivateTestStruct.Expected, :typep)

    assert type1 == type2
  end

  test "generates the struct in a submodule if `module: ModuleName` is set" do
    assert TestModule.Struct.__struct__() == %TestModule.Struct{field: nil}
  end

  test "generates the struct with `new` function" do
    assert %TestWithNew{field: 1} == TestWithNew.new(field: 1)
    assert %TestWithNew{field: 1} == TestWithNew.new(%{field: 1})
  end

  test "generates validated constructors when `constructors: true` is set" do
    assert {:ok, %ConstructorsStruct{id: 1, name: "anonymous", token: "generated-token"}} =
             ConstructorsStruct.new(%{id: 1})

    assert {:ok, %ConstructorsStruct{id: 2, name: "alice", token: "generated-token"}} =
             ConstructorsStruct.from_keyword(id: 2, name: "alice")

    assert %ConstructorsStruct{id: 3, token: "generated-token"} =
             ConstructorsStruct.new!(%{id: 3})
  end

  test "constructor validation returns errors for missing or unknown fields" do
    assert {:error, _} = ConstructorsStruct.new(%{})
    assert {:error, _} = ConstructorsStruct.new(%{id: 1, extra: true})
  end

  test "constructor introspection helpers are generated when requested" do
    assert ConstructorsStruct.__fields__() == [:id, :name, :token]
    assert ConstructorsStruct.__required__() == [:id]
    assert ConstructorsStruct.__defaults__()[:name] == "anonymous"
    assert ConstructorsStruct.__dynamic_defaults__() == [:token]
    assert is_list(ConstructorsStruct.__types__())
  end

  test "strict mode compiles for non-nullable fields" do
    assert %StrictStruct{id: 1, enabled: true} = %StrictStruct{id: 1}
  end

  test "strict mode rejects nullable fields" do
    assert_raise ArgumentError,
                 ~r/strict mode requires each field to define :default or :default_fn, or be enforced/,
                 fn ->
                   defmodule InvalidStrictStruct do
                     use TypedStruct

                     typedstruct strict: true do
                       field :nullable, integer()
                     end
                   end
                 end
  end

  test "docs mode can replace moduledoc with fields only" do
    assert FieldsOnlyDocsStruct.docs() =~ "## Fields"
    assert FieldsOnlyDocsStruct.docs() =~ "`value` - Documented field"
    refute FieldsOnlyDocsStruct.docs() =~ "This line should be replaced."
  end

  test "docs mode can preserve module docs without field section" do
    assert ModuleOnlyDocsStruct.docs() == "This line should stay as-is."
  end

  test "adds field docs to moduledoc when `doc` option is provided" do
    assert FieldDocsStruct.docs() =~ "Struct used to verify generated field docs."
    assert FieldDocsStruct.docs() =~ "## Fields"
    assert FieldDocsStruct.docs() =~ "`name` - The display name."
    assert FieldDocsStruct.docs() =~ "`age` - Age in full years."
    refute FieldDocsStruct.docs() =~ "`active`"
  end

  test "does not override @moduledoc false when field docs are provided" do
    assert HiddenFieldDocsStruct.docs() == false
  end

  test "plugin callbacks can read typedstruct attributes before cleanup" do
    assert LegacyReflectionStruct.legacy_reflection_plugin_loaded?()
  end

  ############################################################################
  ##                                Problems                                ##
  ############################################################################

  test "TypedStruct macros are available only in the typedstruct block" do
    assert_raise CompileError,
                 if(Version.compare(System.version(), "1.14.9") == :lt,
                   do: ~r"undefined function field/2",
                   else: ~r"cannot compile module TypedStructTest.ScopeTest"
                 ),
                 fn ->
                   capture_io(:stderr, fn ->
                     defmodule ScopeTest do
                       use TypedStruct

                       typedstruct do
                         field :in_scope, term()
                       end

                       # Let’s try to use field/2 outside the block.
                       field :out_of_scope, term()
                     end
                   end)
                 end
  end

  test "the name of a field must be an atom" do
    assert_raise ArgumentError, "a field name must be an atom, got 3", fn ->
      defmodule InvalidStruct do
        use TypedStruct

        typedstruct do
          field 3, integer()
        end
      end
    end
  end

  test "it is not possible to add twice a field with the same name" do
    assert_raise ArgumentError, ~r/the field :name is already set at line/, fn ->
      defmodule InvalidStruct do
        use TypedStruct

        typedstruct do
          field :name, String.t()
          field :name, integer()
        end
      end
    end
  end

  test "the :doc option must be a string when provided" do
    assert_raise ArgumentError,
                 "the :doc option for field :name must be a string, got 123",
                 fn ->
                   defmodule InvalidDocStruct do
                     use TypedStruct

                     typedstruct do
                       field :name, String.t(), doc: 123
                     end
                   end
                 end
  end

  test "unknown typedstruct options are rejected" do
    assert_raise ArgumentError, ~r/unknown options for typedstruct/, fn ->
      defmodule InvalidTypedStructOptions do
        use TypedStruct

        typedstruct unknown_option: true do
          field :value, integer()
        end
      end
    end
  end

  test "typedstruct docs option is validated" do
    assert_raise ArgumentError,
                 ~r/invalid :docs value/,
                 fn ->
                   defmodule InvalidTypedStructDocs do
                     use TypedStruct

                     typedstruct docs: :invalid do
                       field :value, integer()
                     end
                   end
                 end
  end

  test "aliases are properly resolved in types" do
    type1 = standardize_first_type(TypedStructs.Alias.Without)
    type2 = standardize_first_type(TypedStructs.Alias.With)

    assert type1 == type2
  end

end
