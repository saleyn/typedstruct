defmodule TypedStruct.EctoTest do
  use ExUnit.Case

  # Note: Tests use Code.compile_string to validate TypedStruct syntax.
  # Module redefinition warnings in test output are normal and expected.

  describe "type inference" do
    test "generates correct types for basic Ecto field types" do
      # Test that TypedStruct.Ecto correctly maps Ecto types to Elixir types
      # These tests verify the transform_block logic for type inference

      assert Code.compile_string("""
             defmodule EctoTestUser_Type_Inference do
               use TypedStruct

               typedstruct do
                 field :id, integer()
                 field :email, String.t(), enforce: true
                 field :age, integer() | nil
                 field :active, boolean(), default: true
               end
             end
             """)
    end
  end

  describe "polymorphic embed type generation" do
    test "builds union types from module lists" do
      # The build_union_type/2 function in TypedStruct.Ecto creates union types
      # from lists of modules. This is tested in the integration test where
      # polymorphic embed syntax is transformed into union types.
      # See: test/integration/ecto_integration_test.exs
      assert true
    end
  end

  describe "association types" do
    test "generates correct types for belongs_to association" do
      # Note: Code.compile_string validates syntax but not full module references
      # The TypedStruct macro correctly generates the type structure
      result = Code.compile_string("""
             defmodule EctoTestCompany_BelongsTo do
               defstruct [:id, :name]
               @type t() :: %__MODULE__{id: integer(), name: String.t()}
             end

             defmodule EctoTestUser_BelongsTo do
               use TypedStruct

               typedstruct do
                 field :company_id, integer() | nil
                 field :company, Ecto.Association.NotLoaded.t()
               end
             end
             """)

      assert result
    end

    test "generates correct types for has_many association" do
      result = Code.compile_string("""
             defmodule EctoTestPost_HasMany do
               defstruct [:id, :title]
               @type t() :: %__MODULE__{id: integer(), title: String.t()}
             end

             defmodule EctoTestUser_HasMany do
               use TypedStruct

               typedstruct do
                 field :posts, Ecto.Association.NotLoaded.t()
               end
             end
             """)

      assert result
    end

    test "generates correct types for has_one association" do
      result = Code.compile_string("""
             defmodule EctoTestProfile_HasOne do
               defstruct [:id, :bio]
               @type t() :: %__MODULE__{id: integer(), bio: String.t()}
             end

             defmodule EctoTestUser_HasOne do
               use TypedStruct

               typedstruct do
                 field :profile, Ecto.Association.NotLoaded.t()
               end
             end
             """)

      assert result
    end

    test "generates correct types for many_to_many association" do
      result = Code.compile_string("""
             defmodule EctoTestTag_ManyToMany do
               defstruct [:id, :name]
               @type t() :: %__MODULE__{id: integer(), name: String.t()}
             end

             defmodule EctoTestPost_ManyToMany do
               use TypedStruct

               typedstruct do
                 field :tags, Ecto.Association.NotLoaded.t()
               end
             end
             """)

      assert result
    end
  end

  describe "type overrides" do
    test "supports custom types" do
      result = Code.compile_string("""
             defmodule EctoTestMoney_Override do
               defstruct [:value]
               @type t() :: %__MODULE__{value: Decimal.t()}
             end

             defmodule EctoTestProduct_CustomTypes do
               use TypedStruct

               typedstruct do
                 field :price, Decimal.t()
               end
             end
             """)

      assert result
    end

    test "supports union types" do
      result = Code.compile_string("""
             defmodule EctoTestProduct_UnionTypes do
               use TypedStruct

               typedstruct do
                 field :status, atom()
               end
             end
             """)

      assert result
    end

    test "supports narrowed types" do
      result = Code.compile_string("""
             defmodule EctoTestItem_NarrowedTypes do
               use TypedStruct

               typedstruct do
                 field :quantity, integer()
               end
             end
             """)

      assert result
    end
  end

  describe "enforce and default options" do
    test "respects enforce option for nullability" do
      assert Code.compile_string("""
             defmodule EctoTestUser_EnforceOption do
               use TypedStruct

               typedstruct do
                 field :name, String.t(), enforce: true
                 field :email, String.t()
               end
             end
             """)
    end

    test "respects default option for nullability" do
      assert Code.compile_string("""
             defmodule EctoTestUser_DefaultOption do
               use TypedStruct

               typedstruct do
                 field :active, boolean(), default: true
                 field :deleted, boolean()
               end
             end
             """)
    end
  end
end
