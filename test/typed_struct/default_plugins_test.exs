defmodule TypedStruct.DefaultPluginsTest do
  use ExUnit.Case

  defmodule TestPlugin do
    use TypedStruct.Plugin

    def after_definition(_opts) do
      quote do
        def has_plugin, do: true
      end
    end
  end

  defmodule WrapperWithDefaultPlugin do
    defmacro __using__(_) do
      quote do
        use TypedStruct, plugins: [TypedStruct.DefaultPluginsTest.TestPlugin]
      end
    end
  end

  defmodule StructWithDefault do
    use TypedStruct.DefaultPluginsTest.WrapperWithDefaultPlugin

    typedstruct do
      field :name, String.t()
    end
  end

  defmodule StructWithDefaultNormal do
    use TypedStruct.DefaultPluginsTest.WrapperWithDefaultPlugin

    typedstruct do
      field :value, integer()
    end
  end

  defmodule Struct1 do
    use TypedStruct.DefaultPluginsTest.WrapperWithDefaultPlugin

    typedstruct do
      field :a, String.t()
    end
  end

  defmodule Struct2 do
    use TypedStruct.DefaultPluginsTest.WrapperWithDefaultPlugin

    typedstruct do
      field :b, String.t()
    end
  end

  test "default plugins are injected into struct" do
    assert function_exported?(StructWithDefault, :has_plugin, 0)
    assert StructWithDefault.has_plugin() == true
  end

  test "struct with default plugin works normally" do
    struct = %StructWithDefaultNormal{value: 42}
    assert struct.value == 42
    assert StructWithDefaultNormal.has_plugin() == true
  end

  test "multiple structs with same default plugin" do
    assert Struct1.has_plugin() == true
    assert Struct2.has_plugin() == true
  end
end
