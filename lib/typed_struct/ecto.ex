defmodule TypedStruct.Ecto do
  alias Ecto.Association

  @moduledoc """
  TypedStruct integration with Ecto schemas.

  This module provides utilities for combining Ecto schemas with TypedStruct to get
  both typed structs and Ecto schema functionality in one definition.

  ## Quick Reference: Ecto Type to Elixir Type Mapping

  When defining fields, use this mapping for `typedstruct` field types:

  | Ecto Type | Elixir Type | Example |
  |-----------|-------------|---------|
  | `:id` | `integer()` | `field :id, :id` (Ecto) → `field :id, integer()` (TypedStruct) |
  | `:binary_id` | `binary()` | UUID fields |
  | `:string` | `String.t()` | Text fields |
  | `:binary` | `binary()` | Binary data |
  | `:integer` | `integer()` | Whole numbers |
  | `:float` | `float()` | Decimal numbers |
  | `:boolean` | `boolean()` | true/false |
  | `:map` | `map()` | JSON/map data |
  | `:decimal` | `Decimal.t()` | Precise decimals |
  | `:date` | `Date.t()` | Calendar date |
  | `:time` | `Time.t()` | Time of day |
  | `:datetime` | `DateTime.t()` | Date and time |
  | `:naive_datetime` | `NaiveDateTime.t()` | Date and time without timezone |
  | `:utc_datetime` | `DateTime.t()` | UTC timestamp |

  ## Usage

  The recommended approach is to use `use Ecto.Schema` alongside `use TypedStruct`:

  ```elixir
  defmodule User do
    use Ecto.Schema
    use TypedStruct

    schema "users" do
      field :email, :string
      field :age, :integer
      timestamps()
    end

    typedstruct do
      field :email, String.t(), enforce: true
      field :age, integer()
    end

    @type t() :: %__MODULE__{
      id: integer() | nil,
      email: String.t(),
      age: integer() | nil,
      inserted_at: NaiveDateTime.t() | nil,
      updated_at: NaiveDateTime.t() | nil
    }
  end
  ```

  However, if you want a more concise definition for simple schemas, you can use the
  `typedschema/2` macro:

  ```elixir
  defmodule Product do
    use TypedStruct.Ecto

    typedschema "products" do
      field :name, :string, enforce: true
      field :price, :decimal
      field :active, :boolean, default: true
      timestamps()
    end
  end
  ```

  The `typedschema` macro automatically:
  - Sets up `use Ecto.Schema`
  - Calls `schema` with the table name
  - Infers Elixir types from Ecto field types
  - Handles `enforce:`, `default:`, and other standard options
  - Supports associations (`belongs_to`, `has_many`, `has_one`, `many_to_many`)
  - Supports embeds (`embeds_one`, `embeds_many`)
  - Supports type overrides with `::` syntax for custom types

  ## Association Support

  The `typedschema` macro automatically generates types for associations:

  ```elixir
  defmodule User do
    use TypedStruct.Ecto

    typedschema "users" do
      field :email, :string, enforce: true
      belongs_to :company, Company
      has_many :posts, Post
      timestamps()
    end
  end
  ```

  This generates:
  - `company_id: integer()` (foreign key for belongs_to)
  - `company: Company.t() | Ecto.Association.NotLoaded.t()` (the association)
  - `posts: [Post.t()] | Ecto.Association.NotLoaded.t()` (has_many returns a list)

  All association types are automatically set to be nullable or as `NotLoaded` as appropriate.

  ## Polymorphic Embeds

  TypedStruct.Ecto supports polymorphic embeds through the optional
  [`polymorphic_embed`](https://hex.pm/packages/polymorphic_embed) library.
  When this library is installed, TypedStruct.Ecto automatically imports its
  macros and generates union types for polymorphic relationships.

  ### With polymorphic_embed Library

  For the recommended approach using the `polymorphic_embed` library:

  ```elixir
  defmodule Notification do
    use TypedStruct.Ecto

    typedschema "notifications" do
      field :message, :string

      polymorphic_embeds_one :channel,
        types: [
          email: EmailConfig,
          sms: SMSConfig,
          push: PushConfig
        ],
        on_replace: :update

      timestamps()
    end
  end
  ```

  This generates: `channel: EmailConfig.t() | SMSConfig.t() | PushConfig.t()`

  For multiple items of different types:

  ```elixir
  polymorphic_embeds_many :events,
    types: [
      created: CreatedEvent,
      updated: UpdatedEvent,
      cancelled: CancelledEvent
    ],
    on_replace: :delete
  ```

  This generates: `events: [CreatedEvent.t() | UpdatedEvent.t() | CancelledEvent.t()]`

  ### Without polymorphic_embed Library

  If you don't want to add the `polymorphic_embed` dependency, you can still
  create union types manually:

  ```elixir
  defmodule Notification do
    use TypedStruct.Ecto

    typedschema "notifications" do
      field :message, :string
      field :config, EmailConfig.t() | SMSConfig.t() | PushConfig.t() :: EmailConfig.t() | SMSConfig.t() | PushConfig.t()
      timestamps()
    end
  end
  ```

  Note: Without the library, you lose automatic type discriminator handling.

  ## Type Overrides

  You can override the automatically inferred type using the `::` syntax. This is useful for:
  - Custom Ecto types
  - Narrowing generic types (e.g., `integer()` → `pos_integer()`)
  - Using domain-specific types (e.g., `Money.t()` instead of `Decimal.t()`)

  ```elixir
  defmodule Product do
    use TypedStruct.Ecto

    typedschema "products" do
      field :id, :id
      field :name, :string, enforce: true

      # Override inferred Decimal.t() with Money.t()
      field :price, :decimal :: Money.t()

      # Narrow integer() to positive_integer()
      field :stock, :integer :: pos_integer()

      # Custom Ecto type with custom type spec
      field :metadata, :map :: CustomMetadata.t()

      # Union type for enum-like fields
      field :status, :string :: :active | :inactive | :archived

      timestamps()
    end
  end
  ```

  The type override completely replaces the inferred type, including nullability handling:

  ```elixir
  # Without override (inferred as: String.t() | nil)
  field :name, :string

  # With override and enforce (type: Money.t())
  field :price, :decimal, enforce: true :: Money.t()

  # With override without enforce (type: Money.t() | nil)
  field :price, :decimal :: Money.t()
  ```

  ## Advanced Usage

  For other advanced Ecto features beyond what's supported here,
  consider using the dedicated [typed_ecto_schema](https://hex.pm/packages/typed_ecto_schema) library:

  ```elixir
  defmodule User do
    use TypedEctoSchema

    typed_schema "users" do
      field :email, :string
      belongs_to :company, Company
      timestamps()
    end
  end
  ```

  This library handles all advanced Ecto features automatically.
  """

  defmacro __using__(_opts) do
    # Check if polymorphic_embed is available
    polymorphic_import =
      if Code.ensure_loaded?(PolymorphicEmbed) do
        quote do
          import PolymorphicEmbed,
            only: [polymorphic_embeds_one: 2, polymorphic_embeds_one: 3,
                   polymorphic_embeds_many: 2, polymorphic_embeds_many: 3]
        end
      else
        quote do: nil
      end

    quote do
      use Ecto.Schema
      use TypedStruct

      import Ecto.Schema,
        only: [timestamps: 0, timestamps: 1, embeds_one: 2, embeds_one: 3,
               embeds_many: 2, embeds_many: 3]

      unquote(polymorphic_import)

      import TypedStruct.Ecto, only: [typedschema: 2]
    end
  end

  @doc """
  Defines a typed Ecto schema.

  This macro combines `typedstruct` and Ecto's `schema` macro, allowing you to define
  both in one concise block. The macro handles type inference for standard Ecto types.

  ## Example

      typedschema "users" do
        field :id,    :id
        field :email, :string, enforce: true
        field :name,  :string
        timestamps()
      end

  See `TypedStruct.Ecto` module documentation for the Ecto type to Elixir type mapping.
  """
  defmacro typedschema(table_name, do: block) do
    # Transform the block to generate type specifications
    transformed_fields = transform_block(block)
    ecto_calls = extract_ecto_calls(block)

    quote do
      import Ecto.Schema, only: [schema: 2, timestamps: 0, timestamps: 1,
                                embeds_one: 2, embeds_one: 3,
                                embeds_many: 2, embeds_many: 3]

      # Create the Ecto schema (which calls defstruct)
      schema(unquote(table_name)) do
        unquote(ecto_calls)
      end

      # Build the TypeSpec without creating another struct
      TypedStruct.Ecto.__type_from_fields__(unquote(transformed_fields))
    end
  end

  # Generate @type definition from transformed fields without calling defstruct
  defmacro __type_from_fields__(fields) do
    type_def = build_type_from_fields(fields)

    quote do
      @typedoc "Schema type"
      @type t() :: unquote(type_def)
    end
  end

  # Build the type definition from field specifications
  defp build_type_from_fields(fields) do
    field_types = extract_field_types(fields)

    # Create map type with all fields
    quote do
      %__MODULE__{unquote_splicing(field_types)}
    end
  end

  # Extract field name and type pairs from transformed fields
  defp extract_field_types({:__block__, _meta, statements}) do
    Enum.map_reduce(statements, [], fn {:field, _meta, [name, type, _opts]}, acc ->
      {name, type_with_meta} = {name, type}
      {{name, type_with_meta}, acc}
    end)
    |> elem(0)
    |> Enum.map(fn {name, type} -> {name, type} end)
  end

  defp extract_field_types(_), do: []

  # Extract only the Ecto-specific macro calls (field, timestamps, etc.)
  # and clean them for Ecto (remove TypedStruct-specific options and type overrides)
  defp extract_ecto_calls({:__block__, meta, statements}) do
    filtered =
      statements
      |> Enum.filter(&ecto_compat_call?/1)
      |> Enum.map(&clean_for_ecto/1)

    {:__block__, meta, filtered}
  end

  defp extract_ecto_calls(statement) do
    if ecto_compat_call?(statement) do
      clean_for_ecto(statement)
    else
      quote do: nil
    end
  end

  # Check if call is Ecto-compatible (excluding type overrides)
  defp ecto_compat_call?({:"::", _, _}), do: false
  defp ecto_compat_call?({name, _, _})
       when name in [
         :field,
         :timestamps,
         :belongs_to,
         :has_many,
         :has_one,
         :many_to_many,
         :embeds_one,
         :embeds_many,
         :polymorphic_embeds_one,
         :polymorphic_embeds_many
       ] do
    true
  end

  defp ecto_compat_call?(_), do: false

  # Remove TypedStruct-specific options for Ecto schema
  defp clean_for_ecto({:field, fmeta, [n, t, opts]}) when is_list(opts) do
    clean_opts = Keyword.drop(opts, [:enforce])
    {:field, fmeta, [n, t, clean_opts]}
  end

  defp clean_for_ecto(other), do: other

  # Transform field calls to include type inference
  defp transform_block({:__block__, meta, statements}) do
    statements =
      Enum.flat_map(statements, fn
        # Handle type override with :: syntax for fields with options
        {:"::", _, [{:field, fmeta, [n, _t, opts]}, otype]} when is_list(opts) ->
          enforce = Keyword.get(opts, :enforce, false)
          ts_opts = build_field_opts(opts, enforce)
          final_type =
            if enforce, do: otype, else: quote(do: unquote(otype) | nil)

          [{:field, fmeta, [n, final_type, ts_opts]}]

        # Handle type override with :: syntax for fields without options
        {:"::", _, [{:field, fmeta, [n, _t]}, otype]} ->
          final_type = quote(do: unquote(otype) | nil)
          [{:field, fmeta, [n, final_type, []]}]

        {:field, meta, [n, t, opts]} when is_list(opts) ->
          etype = infer_type(t)
          enforce = Keyword.get(opts, :enforce, false)
          ts_opts = build_field_opts(opts, enforce)
          final_type =
            if enforce, do: etype, else: quote(do: unquote(etype) | nil)

          [{:field, meta, [n, final_type, ts_opts]}]

        {:field, meta, [n, t]} ->
          etype = infer_type(t)
          final_type = quote(do: unquote(etype) | nil)
          [{:field, meta, [n, final_type, []]}]

        # Handle belongs_to
        {:belongs_to, meta, [n, mod | opts_list]} ->
          opts = if opts_list != [] and is_list(hd(opts_list)), do: hd(opts_list), else: []
          fk = Keyword.get(opts, :foreign_key, :"#{n}_id")
          not_loaded = quote(do: Association.NotLoaded.t())

          [
            {:field, meta, [fk, quote(do: integer()), []]},
            {:field, meta, [n, quote(do: unquote(mod).t() | unquote(not_loaded)), []]}
          ]

        # Handle has_many
        {:has_many, meta, [n, mod | _]} ->
          not_loaded = quote(do: Association.NotLoaded.t())
          [
            {:field, meta, [n, quote(do: [unquote(mod).t()] | unquote(not_loaded)), []]}
          ]

        # Handle has_one
        {:has_one, meta, [n, mod | _]} ->
          not_loaded = quote(do: Association.NotLoaded.t())
          [
            {:field, meta, [n, quote(do: unquote(mod).t() | unquote(not_loaded)), []]}
          ]

        # Handle many_to_many
        {:many_to_many, meta, [n, mod | _]} ->
          not_loaded = quote(do: Association.NotLoaded.t())
          [
            {:field, meta, [n, quote(do: [unquote(mod).t()] | unquote(not_loaded)), []]}
          ]

        # Handle embeds_one with polymorphic
        {:embeds_one, meta, [name, {:polymorphic, poly_opts} | _rest]} ->
          types = Keyword.get(poly_opts, :types, [])
          union_type = build_union_type(types, false)
          [
            {:field, meta, [name, union_type, []]}
          ]

        # Handle embeds_one regular
        {:embeds_one, meta, [name, module | _opts_list]} ->
          [
            {:field, meta, [name, quote(do: unquote(module).t()), []]}
          ]

        # Handle embeds_many with polymorphic
        {:embeds_many, meta, [name, {:polymorphic, poly_opts} | _rest]} ->
          types = Keyword.get(poly_opts, :types, [])
          union_type = build_union_type(types, true)
          [
            {:field, meta, [name, union_type, []]}
          ]

        # Handle embeds_many regular
        {:embeds_many, meta, [name, module | _opts_list]} ->
          [
            {:field, meta, [name, quote(do: [unquote(module).t()]), []]}
          ]

        # Handle polymorphic_embeds_one from polymorphic_embed library
        {:polymorphic_embeds_one, meta, [name, poly_opts | _rest]} when is_list(poly_opts) ->
          types = Keyword.get(poly_opts, :types, [])
          union_type = build_union_type(types, false)
          [
            {:field, meta, [name, union_type, []]}
          ]

        # Handle polymorphic_embeds_many from polymorphic_embed library
        {:polymorphic_embeds_many, meta, [name, poly_opts | _rest]} when is_list(poly_opts) ->
          types = Keyword.get(poly_opts, :types, [])
          union_type = build_union_type(types, true)
          [
            {:field, meta, [name, union_type, []]}
          ]

        # Skip timestamps since it's handled by Ecto
        {:timestamps, _, _} ->
          []

        other ->
          [other]
      end)

    {:__block__, meta, statements}
  end

  defp transform_block(statement) do
    statement
  end

  # Build TypedStruct field options from Ecto options
  defp build_field_opts(opts, enforce) do
    ts_opts = []
    ts_opts = if enforce, do: Keyword.put(ts_opts, :enforce, true), else: ts_opts

    if Keyword.has_key?(opts, :default) do
      Keyword.put(ts_opts, :default, Keyword.get(opts, :default))
    else
      ts_opts
    end
  end

  # Build a union type from a list of modules for polymorphic embeds
  defp build_union_type(types, is_many) do
    module_types = Enum.map(types, fn
      {_key, module} -> quote(do: unquote(module).t())
      module -> quote(do: unquote(module).t())
    end)

    # Create union of all module types
    union = Enum.reduce(module_types, nil, fn type, acc ->
      if acc == nil do
        type
      else
        quote do: unquote(acc) | unquote(type)
      end
    end)

    if is_many do
      quote do: [unquote(union)]
    else
      union
    end
  end

  # Infer Elixir type from Ecto type
  defp infer_type(:id), do: quote(do: integer())
  defp infer_type(:binary_id), do: quote(do: binary())
  defp infer_type(:string), do: quote(do: String.t())
  defp infer_type(:binary), do: quote(do: binary())
  defp infer_type(:integer), do: quote(do: integer())
  defp infer_type(:float), do: quote(do: float())
  defp infer_type(:boolean), do: quote(do: boolean())
  defp infer_type(:map), do: quote(do: map())
  defp infer_type(:decimal), do: quote(do: Decimal.t())
  defp infer_type(:date), do: quote(do: Date.t())
  defp infer_type(:time), do: quote(do: Time.t())
  defp infer_type(:datetime), do: quote(do: DateTime.t())
  defp infer_type(:naive_datetime), do: quote(do: NaiveDateTime.t())
  defp infer_type(:utc_datetime), do: quote(do: DateTime.t())
  defp infer_type(:atom), do: quote(do: atom())
  defp infer_type(:any), do: quote(do: any())
  defp infer_type(_), do: quote(do: term())
end
