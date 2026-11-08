defmodule TypedStruct do
  @external_resource "README.md"
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- @moduledoc -->")
             |> Enum.fetch!(1)

  @common_accumulating_attrs [
    :ts_plugins,
    :ts_plugin_fields,
    :ts_fields,
    :ts_field_lines,
    :ts_field_docs,
    :ts_dynamic_defaults,
    :ts_types,
    :ts_enforce_keys
  ]

  @struct_accumulating_attrs @common_accumulating_attrs ++ [:ts_enforce_keys]
  @record_accumulating_attrs @common_accumulating_attrs

  @attrs_to_delete [:ts_enforce?, :ts_strict? | @struct_accumulating_attrs]

  @typedstruct_options [
    :constructors,
    :derive,
    :docs,
    :enforce,
    :reflection,
    :module,
    :new,
    :opaque,
    :strict,
    :visibility
  ]

  @typedrecord_options [
    :constructors,
    :docs,
    :reflection,
    :module,
    :opaque,
    :strict,
    :tag,
    :visibility
  ]

  @doc false
  defmacro __using__(opts) do
    plugins = Keyword.get(opts, :plugins, [])

    quote do
      import TypedStruct,
        only: [typedstruct: 1, typedstruct: 2, typedrecord: 1, typedrecord: 2, typedrecord: 3]

      @typedstruct_default_plugins unquote(plugins)
    end
  end

  @doc """
  Defines a typed struct.

  Inside a `typedstruct` block, each field is defined through the `field/2`
  macro.

  ## Options

    * `enforce` - if set to true, sets `enforce: true` to all fields by default.
      This can be overridden by setting `enforce: false` or a default value on
      individual fields.
    * `visibility` - one of the values: `:public` (default), `:private`, `:opaque`.
    * `module` - if set, creates the struct in a submodule named `module`.
    * `new` - if set to `true`, it will generate `__MODULE__.new(attrs \\ %{})`.
    * `constructors` - if set to `true`, generates validated constructor helpers:
      `new/1`, `new!/1`, `from_map/1`, `from_keyword/1`.
    * `reflection` - if set to `true`, generates reflection helper functions:
      `__fields__/0`, `__required__/0`, `__defaults__/0`,
      `__dynamic_defaults__/0`, `__types__/0`.
    * `strict` - if set to `true`, each field must be enforced or define a default.
    * `docs` - controls how generated field docs are merged into `@moduledoc`:
      * `:full` (default) appends a `## Fields` section to existing module docs.
      * `:module_only` keeps existing module docs and skips generated field docs.
      * `:fields_only` replaces module docs with the generated `## Fields` section.
      * `false` disables generated field docs entirely.
    * `derive` - passes through `@derive` before `defstruct`.
    * `opaque` - (deprecated) if set to true, creates an opaque type for the struct.

  ## Examples

      defmodule MyStruct do
        use TypedStruct

        typedstruct do
          field :field_one, String.t()
          field :field_two, integer(), enforce: true
          field :field_three, boolean(), enforce: true
          field :field_four, atom(), default: :hey
        end
      end

  The following is an equivalent using the *enforce by default* behaviour:

      defmodule MyStruct do
        use TypedStruct

        typedstruct enforce: true do
          field :field_one, String.t(), enforce: false
          field :field_two, integer()
          field :field_three, boolean()
          field :field_four, atom(), default: :hey
        end
      end

  You can create the struct in a submodule instead:

      defmodule MyModule do
        use TypedStruct

        typedstruct module: Struct do
          field :field_one, String.t()
          field :field_two, integer(), enforce: true
          field :field_three, boolean(), enforce: true
          field :field_four, atom(), default: :hey
        end
      end

  You can derive protocols on the generated struct:

      defmodule Event do
        use TypedStruct

        typedstruct derive: [Jason.Encoder] do
          field :id, integer(), enforce: true
          field :payload, map(), default: %{}
        end
      end

  You can generate validated constructors:

      defmodule User do
        use TypedStruct

        typedstruct constructors: true do
          field :id, integer(), enforce: true
          field :name, String.t(), default: "anonymous"
        end
      end

      # Generated:
      # User.new/1
      # User.new!/1
      # User.from_map/1
      # User.from_keyword/1

  You can generate reflection helpers:

      defmodule Account do
        use TypedStruct

        typedstruct reflection: true do
          field :id, integer(), enforce: true
          field :enabled, boolean(), default: true
        end
      end

      # Generated:
      # Account.__fields__/0
      # Account.__required__/0
      # Account.__defaults__/0
      # Account.__dynamic_defaults__/0
      # Account.__types__/0
  """
  defmacro typedstruct(opts \\ [], do: block) do
    TypedStruct.__validate_typedstruct_opts__(opts)

    # Get default plugins and inject them into the block at compile time
    default_plugins =
      quote do
        Module.get_attribute(__MODULE__, :typedstruct_default_plugins) || []
      end

    # Inject default plugins into the block before processing
    block_with_plugins = TypedStruct.__inject_def_plugins_into_block__(block, default_plugins)
    ast = TypedStruct.__typedstruct__(block_with_plugins, opts)

    case opts[:module] do
      nil ->
        quote do
          # Create a lexical scope.
          (fn -> unquote(ast) end).()
        end

      module ->
        quote do
          defmodule unquote(module) do
            unquote(ast)
          end
        end
    end
  end

  @doc """
  Defines a typed record.

  Inside a `typedrecord` block, each field is defined through the `field/2`
  macro.

  ## Arguments

    * `name` - the record tag name (required, must be an atom). This identifies
      the record and is used in generated function names (e.g., `:person` generates
      `person_new/1`, `person_from_map/1`, etc.).

  ## Options

    * `tag` - if set, used as the `tag` parameter passed to `Record.defrecord/3`.
    * `visibility` - one of the values: `:public` (default), `:private`, `:opaque`.
    * `module` - if set, creates the struct in a submodule named `module`.
    * `constructors` - if set to `true`, generates validated constructor helpers:
      `<name>_new/1`, `<name>_new!/1`, `<name>_from_map/1`,
      `<name>_from_keyword/1`.
    * `reflection` - if set to `true`, generates reflection helper functions:
      `<name>_fields/0`, `<name>_required/0`, `<name>_defaults/0`,
      `<name>_dynamic_defaults/0`, `<name>_types/0`.
    * `strict` - if set to `true`, each field must be enforced or define a default.
    * `docs` - controls how generated field docs are merged into `@moduledoc`:
      * `:full` (default) appends a `## Fields` section to existing module docs.
      * `:module_only` keeps existing module docs and skips generated field docs.
      * `:fields_only` replaces module docs with the generated `## Fields` section.
      * `false` disables generated field docs entirely.

  ## Example

      defmodule People do
        use TypedStruct

        typedrecord :person, constructors: true, reflection: true do
          field :id, integer(), enforce: true
          field :name, String.t(), default: "anonymous"
        end
      end

      # Generated constructors:
      # People.person_new/1
      # People.person_new!/1
      # People.person_from_map/1
      # People.person_from_keyword/1

      # Generated reflection:
      # People.person_fields/0
      # People.person_required/0
      # People.person_defaults/0
      # People.person_dynamic_defaults/0
      # People.person_types/0
  """
  defmacro typedrecord(name, opts \\ [], do: block) when is_list(opts) do
    TypedStruct.__validate_typedrecord_opts__(opts)
    ast = TypedStruct.__typedrecord__(name, block, opts)

    case opts[:module] do
      nil ->
        quote do
          # Create a lexical scope.
          (fn -> unquote(ast) end).()
        end

      module ->
        quote do
          defmodule unquote(module) do
            unquote(ast)
          end
        end
    end
  end

  # Catch the common mistake of calling typedrecord without a name
  defmacro typedrecord(_block_expr) do
    raise ArgumentError,
          "typedrecord requires a record name as the first argument.\n\n" <>
          "  Incorrect:  typedrecord do ... end\n" <>
          "  Correct:    typedrecord :name do ... end\n\n" <>
          "The record name identifies the record and is used in generated function names " <>
          "(e.g., :person generates person_new/1, person_from_map/1, etc.)."
  end

  @doc false
  def __inject_def_plugins_into_block__(block, default_plugins_expr) do
    # Generate code that registers default plugins.
    # We just register them in :ts_plugins without calling init, since init
    # is a macro and can only be called at compile time. Users can call it
    # manually if they need it, or we generate it for them with a helper.

    plugin_inject_expr =
      quote do
        # Get the list of default plugins
        default_plugins_list = unquote(default_plugins_expr)

        # For each plugin, register it
        Enum.each(default_plugins_list, fn
          {plugin_mod, plugin_opts} ->
            Module.put_attribute(__MODULE__, :ts_plugins, {plugin_mod, plugin_opts})

          plugin_mod ->
            Module.put_attribute(__MODULE__, :ts_plugins, {plugin_mod, []})
        end)
      end

    case block do
      {:__block__, env_meta, statements} ->
        {:__block__, env_meta, [plugin_inject_expr | statements]}

      single_statement ->
        {:__block__, [], [plugin_inject_expr, single_statement]}
    end
  end

  @doc false
  def __typedstruct__(block, opts) do
    docs_mode = TypedStruct.__docs_mode__(opts)
    derive_block = __typedstruct_derive_block__(opts)
    generated_blocks = __typedstruct_generated_blocks__(opts)

    quote do
      Enum.each(unquote(@struct_accumulating_attrs), fn attr ->
        Module.register_attribute(__MODULE__, attr, accumulate: true)
      end)

      Module.put_attribute(__MODULE__, :ts_enforce?, unquote(!!opts[:enforce]))
      Module.put_attribute(__MODULE__, :ts_strict?, unquote(!!opts[:strict]))
      @before_compile {unquote(__MODULE__), :__plugin_callbacks__}

      import TypedStruct

      unquote(block)

      TypedStruct.__append_field_docs__(__MODULE__, unquote(docs_mode))

      unquote(derive_block)

      @enforce_keys @ts_enforce_keys
      defstruct Enum.reverse(@ts_fields)

      TypedStruct.__struct_type__(@ts_types, unquote(opts))

      unquote_splicing(generated_blocks)
    end
  end

  @doc false
  def __typedrecord__(name, block, opts) do
    tag = Keyword.get(opts, :tag, name)
    docs_mode = TypedStruct.__docs_mode__(opts)
    generated_blocks = __typedrecord_generated_blocks__(name, tag, opts)

    quote do
      Enum.each(unquote(@record_accumulating_attrs), fn attr ->
        Module.register_attribute(__MODULE__, attr, accumulate: true)
      end)

      Module.put_attribute(__MODULE__, :ts_strict?, unquote(!!opts[:strict]))
      @before_compile {unquote(__MODULE__), :__plugin_callbacks__}

      import TypedStruct
      require Record

      default_plugins = Module.get_attribute(__MODULE__, :typedstruct_default_plugins) || []
      for {plugin, plugin_opts} <- default_plugins do
        Module.put_attribute(__MODULE__, :ts_plugins, {plugin, plugin_opts})
        Code.require_module(plugin)
        plugin.init(plugin_opts)
      end

      unquote(block)
      TypedStruct.__append_field_docs__(__MODULE__, unquote(docs_mode))
      Record.defrecord(unquote(name), unquote(tag), Enum.reverse(@ts_fields))

      TypedStruct.__record_type__(
        @ts_types,
        unquote(opts),
        unquote(name),
        unquote(tag)
      )

      unquote_splicing(generated_blocks)

      # Register this typed record in persistent_term for runtime Inspect support
      field_names_for_inspect = Keyword.keys(Enum.reverse(@ts_fields))
      # Get module name without "Elixir." prefix for cleaner output
      module_name = Module.split(__MODULE__) |> Enum.join(".")
      record_metadata = %{
        fields: field_names_for_inspect,
        count: length(field_names_for_inspect),
        module: module_name
      }
      :persistent_term.put({:typed_record_fields, unquote(tag)}, record_metadata)

      # Clean up accumulating attributes after each record definition
      Enum.each(unquote(@record_accumulating_attrs), fn attr ->
        Module.delete_attribute(__MODULE__, attr)
      end)
    end
  end

  @doc false
  def __visibility__(opts) do
    # For backward compatibility support `opaque: true` (default to :public)
    Keyword.get(opts, :visibility) ||
      ((Keyword.get(opts, :opaque) == true && :opaque) || :public)
  end

  @doc false
  defmacro __struct_type__(types, opts) do
    case TypedStruct.__visibility__(opts) do
      :public ->
        quote bind_quoted: [types: types] do
          @type t() :: %__MODULE__{unquote_splicing(types)}
        end

      :opaque ->
        quote bind_quoted: [types: types] do
          @opaque t() :: %__MODULE__{unquote_splicing(types)}
        end

      :private ->
        quote bind_quoted: [types: types] do
          @typep t() :: %__MODULE__{unquote_splicing(types)}
        end
    end
  end

  @doc false
  defmacro __record_type__(types, opts, name, tag) do
    types =
      quote do
        :lists.reverse(for {_, v} <- unquote(types), do: v)
      end

    case TypedStruct.__visibility__(opts) do
      :public ->
        quote bind_quoted: [name: name, tag: tag, types: types] do
          @type unquote(name)() :: {unquote(tag), unquote_splicing(types)}
        end

      :opaque ->
        quote bind_quoted: [name: name, tag: tag, types: types] do
          @opaque unquote(name)() :: {unquote(tag), unquote_splicing(types)}
        end

      :private ->
        quote bind_quoted: [name: name, tag: tag, types: types] do
          @typep unquote(name)() :: {unquote(tag), unquote_splicing(types)}
        end
    end
  end

  @doc """
  Registers a plugin for the currently defined struct.

  ## Example

      typedstruct do
        plugin MyPlugin

        field :a_field, String.t()
      end

  For more information on how to define your own plugins, please see
  `TypedStruct.Plugin`. To use a third-party plugin, please refer directly to
  its documentation.
  """
  defmacro plugin(plugin, opts \\ []) do
    quote do
      Module.put_attribute(
        __MODULE__,
        :ts_plugins,
        {unquote(plugin), unquote(opts)}
      )

      require unquote(plugin)
      unquote(plugin).init(unquote(opts))
    end
  end

  @doc """
  Defines a field in a typed struct.

  ## Example

      # A field named :example of type String.t()
      field :example, String.t()

  ## Options

    * `default` - sets the default value for the field
    * `default_fn` - sets a dynamic default using a remote function capture (`&Mod.fun/0`)
    * `enforce` - if set to true, enforces the field and makes its type
      non-nullable
    * `doc` - adds field-level documentation to the module docs under
      a generated "Fields" section. If not provided, the `@doc` attribute
      is used if present.

  ## Field Documentation

  You can document fields in two ways:

  1. Using the `doc:` option:

      ```elixir
      field :name, String.t(), doc: "User's full name"
      ```

  2. Using the `@doc` attribute (documentation applies to the next field):

      ```elixir
      @doc "User's full name"
      field :name, String.t()

      @doc "User's email address"
      field :email, String.t(), enforce: true
      ```

  The `@doc` attribute is automatically cleared after being applied to a field,
  ensuring it only documents the intended field.
  """
  defmacro field(name, type, opts \\ []) do
    quote bind_quoted: [name: name, type: Macro.escape(type), opts: opts] do
      TypedStruct.__field__(name, type, opts, __ENV__)
    end
  end

  @doc false
  def __field__(name, type, opts, %Macro.Env{module: mod} = env)
      when is_atom(name) do
    __ensure_field_is_unique__(mod, name, env.line)

    {has_default?, default_fn} = __resolve_default_field_options__(name, opts)
    enforce? = __resolve_field_enforce__(mod, opts, has_default?)
    __validate_strict_field!(mod, name, has_default?, enforce?)
    __validate_and_store_field_doc!(mod, name, opts)
    __maybe_store_dynamic_default__(mod, name, default_fn)

    Module.put_attribute(mod, :ts_fields, {name, opts[:default]})
    Module.put_attribute(mod, :ts_field_lines, {name, env.line})
    Module.put_attribute(mod, :ts_plugin_fields, {name, type, opts, env})
    Module.put_attribute(mod, :ts_types, {name, type_for(type, !has_default? && !enforce?)})
    if enforce?, do: Module.put_attribute(mod, :ts_enforce_keys, name)
  end

  def __field__(name, _type, _opts, _env) do
    raise ArgumentError, "a field name must be an atom, got #{inspect(name)}"
  end

  # Makes the type nullable if the key is not enforced.
  defp type_for(type, false), do: type
  defp type_for(type, _), do: quote(do: unquote(type) | nil)

  @doc false
  def __append_field_docs__(_mod, mode) when mode in [false, :module_only], do: :ok

  @doc false
  def __append_field_docs__(mod, mode) do
    field_docs =
      mod
      |> Module.get_attribute(:ts_field_docs)
      |> Enum.reverse()

    if field_docs != [] do
      fields_section = render_fields_section(field_docs)

      case {mode, Module.get_attribute(mod, :moduledoc)} do
        {_, {_, false}} ->
          :ok

        {_, false} ->
          :ok

        {:fields_only, _} ->
          Module.put_attribute(mod, :moduledoc, {0, fields_section})

        {:full, nil} ->
          Module.put_attribute(mod, :moduledoc, {0, fields_section})

        {:full, {line, moduledoc}} when is_binary(moduledoc) ->
          Module.put_attribute(mod, :moduledoc, {line, moduledoc <> "\n\n" <> fields_section})

        {:full, {line, moduledoc}} when is_list(moduledoc) ->
          Module.put_attribute(mod, :moduledoc, {line, Keyword.update(moduledoc, :en, fields_section, &(&1 <> "\n\n" <> fields_section))})

        _ ->
          :ok
      end
    end
  end

  @doc false
  def __docs_mode__(opts) do
    case Keyword.get(opts, :docs, :full) do
      true -> :full
      mode -> mode
    end
  end

  @doc false
  def __validate_typedstruct_opts__(opts) do
    __validate_keyword_opts__(opts, @typedstruct_options, "typedstruct")

    if Keyword.get(opts, :new) && Keyword.get(opts, :constructors) do
      raise ArgumentError,
            "typedstruct options :new and :constructors cannot be enabled together"
    end

    __validate_visibility_opt__(opts)
    __validate_docs_opt__(opts)
    __validate_boolean_opt__(opts, :enforce, "typedstruct")
    __validate_boolean_opt__(opts, :new, "typedstruct")
    __validate_boolean_opt__(opts, :strict, "typedstruct")
    __validate_boolean_opt__(opts, :constructors, "typedstruct")
    __validate_boolean_opt__(opts, :reflection, "typedstruct")

    derive = Keyword.get(opts, :derive)

    if !is_nil(derive) && !is_list(derive) do
      raise ArgumentError, "typedstruct option :derive must be a list, got #{inspect(derive)}"
    end
  end

  @doc false
  def __validate_typedrecord_opts__(opts) do
    __validate_keyword_opts__(opts, @typedrecord_options, "typedrecord")
    __validate_visibility_opt__(opts)
    __validate_docs_opt__(opts)
    __validate_boolean_opt__(opts, :strict, "typedrecord")
    __validate_boolean_opt__(opts, :constructors, "typedrecord")
    __validate_boolean_opt__(opts, :reflection, "typedrecord")
  end

  defp __validate_keyword_opts__(opts, allowed, kind) when is_list(opts) do
    unknown = Keyword.keys(opts) -- allowed

    if unknown != [] do
      raise ArgumentError,
            "unknown options for #{kind}: #{inspect(unknown)}; allowed options are #{inspect(allowed)}"
    end
  end

  defp __validate_keyword_opts__(opts, _allowed, kind) do
    raise ArgumentError,
          "#{kind} options must be a keyword list, got #{inspect(opts)}"
  end

  defp __validate_visibility_opt__(opts) do
    visibility = Keyword.get(opts, :visibility)

    if !is_nil(visibility) && visibility not in [:public, :opaque, :private] do
      raise ArgumentError,
            "invalid :visibility value #{inspect(visibility)}; expected one of :public, :opaque, :private"
    end
  end

  defp __validate_docs_opt__(opts) do
    docs = __docs_mode__(opts)

    if docs not in [false, :module_only, :fields_only, :full] do
      raise ArgumentError,
            "invalid :docs value #{inspect(docs)}; expected false, :module_only, :fields_only, or :full"
    end
  end

  defp __validate_boolean_opt__(opts, key, kind) do
    value = Keyword.get(opts, key)

    if !is_nil(value) && !is_boolean(value) do
      raise ArgumentError,
            "#{kind} option #{inspect(key)} must be a boolean, got #{inspect(value)}"
    end
  end

  @doc false
  def __build_struct__(module, attrs, field_names, required, static_defaults, dynamic_defaults) do
    with {:ok, attrs_map} <- __normalize_attrs__(attrs),
         :ok <- __validate_unknown_keys__(attrs_map, field_names),
         :ok <- __validate_required_keys__(attrs_map, required) do
      attrs_map =
        attrs_map
        |> __apply_dynamic_defaults__(dynamic_defaults)
        |> __apply_defaults__(static_defaults)

      {:ok, struct(module, attrs_map)}
    end
  end

  @doc false
  def __build_record__(attrs, tag, field_names, required, static_defaults, dynamic_defaults) do
    with {:ok, attrs_map} <- __normalize_attrs__(attrs),
         :ok <- __validate_unknown_keys__(attrs_map, field_names),
         :ok <- __validate_required_keys__(attrs_map, required) do
      attrs_map =
        attrs_map
        |> __apply_dynamic_defaults__(dynamic_defaults)
        |> __apply_defaults__(static_defaults)

      values = Enum.map(field_names, &Map.get(attrs_map, &1))
      {:ok, List.to_tuple([tag | values])}
    end
  end

  @doc false
  def __normalize_attrs__(attrs) when is_map(attrs), do: {:ok, attrs}
  def __normalize_attrs__(attrs) when is_list(attrs), do: {:ok, Enum.into(attrs, %{})}

  def __normalize_attrs__(attrs) do
    {:error, [{:attrs, "expected a map or keyword list, got #{inspect(attrs)}"}]}
  end

  @doc false
  def __validate_unknown_keys__(attrs_map, field_names) do
    unknown = Map.keys(attrs_map) -- field_names

    if unknown == [] do
      :ok
    else
      {:error, [{:unknown_fields, "unknown fields: #{inspect(unknown)}"}]}
    end
  end

  @doc false
  def __validate_required_keys__(attrs_map, required) do
    missing = Enum.reject(required, &Map.has_key?(attrs_map, &1))

    if missing == [] do
      :ok
    else
      {:error, [{:missing_fields, "missing required fields: #{inspect(missing)}"}]}
    end
  end

  @doc false
  def __apply_defaults__(attrs_map, defaults) do
    Enum.reduce(defaults, attrs_map, fn {field, default}, acc ->
      if Map.has_key?(acc, field), do: acc, else: Map.put(acc, field, default)
    end)
  end

  @doc false
  def __apply_dynamic_defaults__(attrs_map, dynamic_defaults) do
    Enum.reduce(dynamic_defaults, attrs_map, fn {field, default_fn}, acc ->
      if Map.has_key?(acc, field) do
        acc
      else
        Map.put(acc, field, default_fn.())
      end
    end)
  end

  @doc false
  def __format_errors__(errors) do
    Enum.map_join(errors, "; ", fn {_kind, message} -> message end)
  end


  defp __typedstruct_generated_blocks__(opts) do
    []
    |> __maybe_add_simple_new__(opts)
    |> __maybe_add_struct_constructors__(opts)
    |> __maybe_add_struct_reflection__(opts)
  end

  defp __typedstruct_derive_block__(opts) do
    case opts[:derive] do
      nil -> quote(do: nil)
      derive -> quote(do: @derive unquote(Macro.escape(derive)))
    end
  end

  defp __typedrecord_generated_blocks__(name, tag, opts) do
    []
    |> __maybe_add_record_constructors__(name, tag, opts)
    |> __maybe_add_record_reflection__(name, opts)
  end

  defp __maybe_add_simple_new__(blocks, opts) do
    if opts[:new] do
      [
        quote do
          def new(attrs \\ %{}), do: struct(__MODULE__, attrs)
        end
        | blocks
      ]
    else
      blocks
    end
  end

  defp __maybe_add_struct_constructors__(blocks, opts) do
    if opts[:constructors] do
      constructor_block =
        quote do
          def from_map(attrs), do: new(attrs)
          def from_keyword(attrs), do: new(attrs)

          def new(attrs \\ %{}) do
            TypedStruct.__build_struct__(
              __MODULE__,
              attrs,
              Keyword.keys(Enum.reverse(@ts_fields)),
              Enum.reverse(@ts_enforce_keys),
              Map.new(Enum.reverse(@ts_fields)),
              Enum.reverse(@ts_dynamic_defaults)
            )
          end

          def new!(attrs \\ %{}) do
            case new(attrs) do
              {:ok, struct} -> struct
              {:error, errors} -> raise ArgumentError, TypedStruct.__format_errors__(errors)
            end
          end
        end

      [constructor_block | blocks]
    else
      blocks
    end
  end

  defp __maybe_add_struct_reflection__(blocks, opts) do
    if opts[:reflection] do
      reflection_block =
        quote do
          def __fields__, do: Keyword.keys(Enum.reverse(@ts_fields))
          def __required__, do: Enum.reverse(@ts_enforce_keys)
          def __defaults__, do: Map.new(Enum.reverse(@ts_fields))
          def __dynamic_defaults__, do: Keyword.keys(Enum.reverse(@ts_dynamic_defaults))
          def __types__, do: Enum.reverse(@ts_types)
        end

      [reflection_block | blocks]
    else
      blocks
    end
  end

  defp __maybe_add_record_constructors__(blocks, name, tag, opts) do
    if opts[:constructors] do
      new_fun = String.to_atom("#{name}_new")
      new_bang_fun = String.to_atom("#{name}_new!")
      from_map_fun = String.to_atom("#{name}_from_map")
      from_keyword_fun = String.to_atom("#{name}_from_keyword")

      constructor_block =
        quote do
          def unquote(from_map_fun)(attrs), do: unquote(new_fun)(attrs)
          def unquote(from_keyword_fun)(attrs), do: unquote(new_fun)(attrs)

          def unquote(new_fun)(attrs \\ %{}) do
            TypedStruct.__build_record__(
              attrs,
              unquote(tag),
              Keyword.keys(Enum.reverse(@ts_fields)),
              Enum.reverse(@ts_enforce_keys),
              Map.new(Enum.reverse(@ts_fields)),
              Enum.reverse(@ts_dynamic_defaults)
            )
          end

          def unquote(new_bang_fun)(attrs \\ %{}) do
            case unquote(new_fun)(attrs) do
              {:ok, record} -> record
              {:error, errors} -> raise ArgumentError, TypedStruct.__format_errors__(errors)
            end
          end
        end

      [constructor_block | blocks]
    else
      blocks
    end
  end

  defp __maybe_add_record_reflection__(blocks, name, opts) do
    if opts[:reflection] do
      fields_fun = String.to_atom("#{name}_fields")
      required_fun = String.to_atom("#{name}_required")
      defaults_fun = String.to_atom("#{name}_defaults")
      dynamic_defaults_fun = String.to_atom("#{name}_dynamic_defaults")
      types_fun = String.to_atom("#{name}_types")

      reflection_block =
        quote do
          def unquote(fields_fun)(), do: Keyword.keys(Enum.reverse(@ts_fields))
          def unquote(required_fun)(), do: Enum.reverse(@ts_enforce_keys)
          def unquote(defaults_fun)(), do: Map.new(Enum.reverse(@ts_fields))
          def unquote(dynamic_defaults_fun)(), do: Keyword.keys(Enum.reverse(@ts_dynamic_defaults))
          def unquote(types_fun)(), do: Enum.reverse(@ts_types)
        end

      [reflection_block | blocks]
    else
      blocks
    end
  end

  defp __ensure_field_is_unique__(mod, name, line) do
    if mod |> Module.get_attribute(:ts_fields) |> Keyword.has_key?(name) do
      previous_line =
        mod
        |> Module.get_attribute(:ts_field_lines)
        |> Keyword.get(name)

      raise ArgumentError,
            "the field #{inspect(name)} is already set at line #{previous_line}, cannot redefine it at line #{line}"
    end
  end

  defp __resolve_default_field_options__(name, opts) do
    has_default_fn? = Keyword.has_key?(opts, :default_fn)

    if has_default_fn? && Keyword.has_key?(opts, :default) do
      raise ArgumentError,
            "field #{inspect(name)} cannot define both :default and :default_fn"
    end

    default_fn = opts[:default_fn]
    __validate_default_fn__(name, has_default_fn?, default_fn)

    {Keyword.has_key?(opts, :default) || has_default_fn?, default_fn}
  end

  defp __validate_default_fn__(_name, false, _default_fn), do: :ok

  defp __validate_default_fn__(name, true, default_fn) do
    if !is_function(default_fn, 0) do
      raise ArgumentError,
            "the :default_fn option for field #{inspect(name)} must be a remote 0-arity function capture, got #{inspect(default_fn)}"
    end

    if :erlang.fun_info(default_fn, :type) != {:type, :external} do
      raise ArgumentError,
            "the :default_fn option for field #{inspect(name)} must be a remote 0-arity function capture like &Mod.fun/0"
    end
  end

  defp __resolve_field_enforce__(mod, opts, has_default?) do
    enforce_by_default? = Module.get_attribute(mod, :ts_enforce?)

    if is_nil(opts[:enforce]),
      do: enforce_by_default? && !has_default?,
      else: !!opts[:enforce]
  end

  defp __validate_strict_field!(mod, name, has_default?, enforce?) do
    strict? = Module.get_attribute(mod, :ts_strict?)
    nullable? = !has_default? && !enforce?

    if strict? && nullable? do
      raise ArgumentError,
            "strict mode requires each field to define :default or :default_fn, or be enforced; field #{inspect(name)} is nullable"
    end
  end

  defp __validate_and_store_field_doc!(mod, name, opts) do
    case opts[:doc] do
      nil ->
        # Try to infer from @doc attribute if present
        case Module.get_attribute(mod, :doc) do
          {_line, doc} when is_binary(doc) ->
            Module.put_attribute(mod, :ts_field_docs, {name, doc})
            # Clear @doc after using it so it doesn't apply to the next field
            Module.delete_attribute(mod, :doc)

          nil ->
            :ok

          invalid ->
            raise ArgumentError,
                  "the @doc attribute must be a string, got #{inspect(invalid)}"
        end

      doc when is_binary(doc) ->
        Module.put_attribute(mod, :ts_field_docs, {name, doc})

      invalid ->
        raise ArgumentError,
              "the :doc option for field #{inspect(name)} must be a string, got #{inspect(invalid)}"
    end
  end

  defp __maybe_store_dynamic_default__(_mod, _name, nil), do: :ok

  defp __maybe_store_dynamic_default__(mod, name, default_fn) do
    Module.put_attribute(mod, :ts_dynamic_defaults, {name, default_fn})
  end

  defp render_fields_section(field_docs) do
    entries =
      Enum.map(field_docs, fn {name, doc} ->
        "* `#{name}` - #{doc}"
      end)

    Enum.join(["## Fields", "" | entries], "\n")
  end

  @doc false
  defmacro __plugin_callbacks__(%Macro.Env{module: module}) do
    plugins = Module.get_attribute(module, :ts_plugins)
    fields = Module.get_attribute(module, :ts_plugin_fields) |> Enum.reverse()

    fields_block =
      for {plugin, plugin_opts} <- plugins,
          {name, type, field_opts, env} <- fields do
        plugin.field(name, type, field_opts ++ plugin_opts, env)
      end

    after_definition_block =
      for {plugin, plugin_opts} <- plugins do
        plugin.after_definition(plugin_opts)
      end

    # Keep typedstruct attributes available while plugin callbacks run.
    Enum.each(unquote(@attrs_to_delete), &Module.delete_attribute(module, &1))

    quote do
      unquote_splicing(fields_block)
      unquote_splicing(after_definition_block)
    end
  end
end

# Generic Inspect implementation for typed records
# Uses persistent_term to look up field metadata registered during record compilation
# Disable via config: config :typed_struct, :inspect_records, false
if Application.compile_env(:typed_struct, :inspect_records, true) do
  defimpl Inspect, for: Tuple do
    def inspect(tuple, opts) do
      case elem(tuple, 0) do
        tag when is_atom(tag) and tuple_size(tuple) > 1 ->
          # Look up metadata for this record tag in persistent_term
          metadata = :persistent_term.get({:typed_record_fields, tag}, nil)

          if metadata && tuple_size(tuple) == metadata.count + 1 do
            # Format as: Module.tag(field1: val1, field2: val2, ...)
            %{fields: field_names, module: module} = metadata
            [_tag | values] = Tuple.to_list(tuple)
            fields = Enum.zip(field_names, values)

            # Build field documents respecting the inspect options
            inner_docs =
              Enum.map(fields, fn {k, v} ->
                Inspect.Algebra.concat([
                  Inspect.Algebra.to_doc(k, opts),
                  ": ",
                  Inspect.Algebra.to_doc(v, opts)
                ])
              end)

            # Join with commas and build the final document
            Inspect.Algebra.concat(
              ["#{module}.#{tag}("] ++
                Enum.intersperse(inner_docs, ", ") ++
                [")"]
            )
          else
            # Not a known record, format as regular tuple
            format_regular_tuple(tuple, opts)
          end

        _ ->
          # Not a record, format as regular tuple
          format_regular_tuple(tuple, opts)
      end
    end

    defp format_regular_tuple(tuple, _opts) do
      # Format tuple manually: {elem1, elem2, ...}
      elements = Tuple.to_list(tuple) |> Enum.map(&inspect/1)
      Inspect.Algebra.concat([
        "{",
        Enum.join(elements, ", "),
        "}"
      ])
    end
  end
end
