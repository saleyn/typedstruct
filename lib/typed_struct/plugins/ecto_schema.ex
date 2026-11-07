defmodule TypedStruct.Plugin.EctoSchema do
  @moduledoc """
  Optional TypedStruct plugin for Ecto schema integration.

  This plugin allows you to use TypedStruct with Ecto schemas by automatically
  calling `use Ecto.Schema` and providing sensible defaults for Ecto integration.

  ## Usage

  The recommended way is to use `use Ecto.Schema` directly before TypedStruct, or to
  include it in a wrapper:

      defmodule MyApp.EctoType do
        defmacro __using__(_) do
          quote do
            use Ecto.Schema
            use TypedStruct
          end
        end
      end

  Then use it in your schemas:

      defmodule MyApp.User do
        use MyApp.EctoType

        typedstruct do
          field :id, integer()
          field :email, String.t(), enforce: true
          field :inserted_at, DateTime.t()
        end
      end

  Alternatively, you can use this plugin if Ecto is installed:

      defmodule MyApp.Type do
        defmacro __using__(_) do
          quote do
            use TypedStruct, plugins: [TypedStruct.Plugin.EctoSchema]
          end
        end
      end

  ## Notes

  - This plugin requires Ecto to be installed
  - For full Ecto schema support with automatic typespec generation for associations,
    timestamps, and other Ecto-specific features, consider using
    [typed_ecto_schema](https://hex.pm/packages/typed_ecto_schema)
  - This plugin is mainly useful as a reference for how to build plugins that integrate
    with external libraries
  """

  use TypedStruct.Plugin
end
