![TypedStruct](assets/typedstruct-banner.png)

[![Build Status](https://github.com/saleyn/typedstruct/actions/workflows/ci.yml/badge.svg)](https://github.com/saleyn/typedstruct/actions/workflows/ci.yml)
[![hex.pm version](https://img.shields.io/hexpm/v/typedstruct.svg?style=flat)](https://hex.pm/packages/typedstruct)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg?style=flat)](https://hexdocs.pm/typedstruct/)
[![License](https://img.shields.io/hexpm/l/typedstruct.svg?style=flat)](https://github.com/saleyn/typedstruct/blob/main/LICENSE.md)
[![Hex.pm](https://img.shields.io/hexpm/dt/typedstruct.svg)](https://hex.pm/packages/typedstruct)

<!-- @moduledoc -->

TypedStruct is a library for defining structs with a type without writing
boilerplate code.

**NOTE:** This is an active fork of the original
[typedstruct](https://github.com/ejpcmac/typed_struct) work by Jean-Philippe Cugnet, which seems
to be no longer maintained.  This version adds type information to Erlang
records and makes the project compile under OTP-26 and later.

## Rationale

To define a struct in Elixir, you probably want to define three things:

* the struct itself, with default values,
* the list of enforced keys,
* its associated type.

It ends up in something like this:

```elixir
defmodule Person do
  @moduledoc """
  A struct representing a person.
  """

  @enforce_keys [:name]
  defstruct name: nil,
            age: nil,
            happy?: true,
            phone: nil

  @typedoc "A person"
  @type t() :: %__MODULE__{
          name: String.t(),
          age: non_neg_integer() | nil,
          happy?: boolean(),
          phone: String.t() | nil
        }
end
```

In the example above you can notice several points:

* the keys are present in both the `defstruct` and type definition,
* enforced keys must also be written in `@enforce_keys`,
* if a key has no default value and is not enforced, its type should be
  nullable.

If you want to add a field in the struct, you must therefore:

* add the key with its default value in the `defstruct` list,
* add the key with its type in the type definition.

If the field is not optional, you should even add it to `@enforce_keys`. This is
way too much work for lazy people like me, and moreover it can be error-prone.

It would be way better if we could write something like this:

```elixir
defmodule Person do
  @moduledoc """
  A struct representing a person.
  """

  use TypedStruct

  typedstruct do
    @typedoc "A person"

    field :name, String.t(), enforce: true
    field :age, non_neg_integer()
    field :happy?, boolean(), default: true
    field :phone, String.t()
  end
end
```

## How do I use `TypedStruct`?

### Setup

To use TypedStruct in your project, add this to your Mix dependencies:

```elixir
{:typedstruct, "~> 0.6"}
```

If you do not plan to compile modules using TypedStruct at runtime, you can add
`runtime: false` to the dependency tuple as TypedStruct is only used at build
time.

If you want to avoid `mix format` putting parentheses on field definitions,
you can add to your `.formatter.exs`:

```elixir
[
  ...,
  import_deps: [:typedstruct]
]
```

### General usage

To define a typed struct, use
[`TypedStruct`](https://hexdocs.pm/typedstruct/TypedStruct.html), then define
your struct within a `typedstruct` block:

```elixir
defmodule MyStruct do
  # Use TypedStruct to import the typedstruct macro.
  use TypedStruct

  # Define your struct.
  typedstruct do
    # Define each field with the field macro.
    field :a_string, String.t()

    # You can set a default value.
    field :string_with_default, String.t(), default: "default"

    # You can enforce a field.
    field :enforced_field, integer(), enforce: true
  end
end
```

Each field is defined through the
[`field/2`](https://hexdocs.pm/typedstruct/TypedStruct.html#field/2) macro.

To define a record use the `typedrecord` block:

```elixir
defmodule Person do
  use TypedStruct

  typedrecord :person do
    @typedoc "A person"

    field :name, String.t()
    field :age,  non_neg_integer(), default: 0
  end
end
```

**Note on Records:** Records in Elixir are compile-time constructs that generate macros, not runtime functions. You cannot call them like regular functions at runtime. They're best suited for Erlang interop and pattern matching.

```elixir
iex(2)> Person.person()
** (UndefinedFunctionError) function Person.person/0 is undefined or private. However, there is a macro with the same name and arity. Be sure to require Person if you intend to invoke this macro
    Person.person()
    iex:10: (file)
iex(2)> require Person    # <-- This is essential!
Person
iex(3)> Person.person()
Person.person(name: nil, age: 0)
iex(4)> rec = Person.person(name: "John")
Person.person(name: "John", age: 0)
iex(5)> Person.person(rec, name: "Alex")
Person.person(name: "Alex", age: 0)
```
For most Elixir code, use `typedstruct` instead:

```elixir
# With typedstruct - works naturally at runtime
defmodule Person do
  use TypedStruct

  typedstruct do
    field :name, String.t()
    field :age, non_neg_integer(), default: 0
  end
end

iex(1)> %Person{name: "Alice", age: 30}
%Person{name: "Alice", age: 30}

# With typedrecord - requires `require` and special macro syntax
require Person

iex(2)> Person.person(:name, "Alice")           # Create record
Person.person(name: "Alice", age: 0)

iex(3)> Person.person(person, :name, "Bob")     # Update field
Person.person(name: "Bob", age: 0)
```

Records generate macros (`/0`, `/1`, `/2`) that only work when the module is required. For normal Elixir code, prefer structs via `typedstruct`.

**Pretty-printing records:** Records print nicely formatted in the shell without outer quotes:

```elixir
require Person

iex(1)> rec = Person.person(name: "Alice", age: 30)
Person.person(name: "Alice", age: 30)

iex(2)> IO.inspect(rec)
Person.person(name: "Alice", age: 30)

iex(4)> Person.person(name: "John", age: 30)
Person.person(name: "John", age: 30)
```

The `Inspect` protocol respects all standard options like `:pretty`, `:limit`, and `:width`.

**Disabling custom record inspection:** TypedStruct implements a custom `Inspect` protocol for tuples to provide this nice formatting. If you want to use the default Elixir tuple inspection instead, disable it in your config:

```elixir
config :typed_struct, :inspect_records, false
```

### Options

All options are listed together here for quick reference.

Top-level options available on both `typedstruct` and `typedrecord`:

* `module: ModuleName` - defines the generated struct/record in a submodule.
* `visibility: :public | :private | :opaque` - controls generated type visibility.
* `strict: true` - requires each field to be enforced or provide `default` / `default_fn`.
* `constructors: true` - generates validated constructors.
* `reflection: true` - generates helper functions for fields, defaults,
  required fields, and types (see [Introspection helpers](#reflection-helpers)).
* `docs: :full | :module_only | :fields_only | false` - controls how field docs
  are merged into module documentation.

Additional `typedstruct`-only options:

* `enforce: true` - enforces all fields by default unless overridden per field.
* `new: true` - generates a simple `new/1` constructor (`struct(__MODULE__, attrs)`).
* `derive: [Protocol1, Protocol2]` - passes through `@derive` before `defstruct`.
* `opaque: true` - deprecated alias for `visibility: :opaque`.

Additional `typedrecord`-only options:

* `tag: atom()` - sets record tag passed to `Record.defrecord/3`.
* `opaque: true` - deprecated alias for `visibility: :opaque`.

Field-level options (`field/3`):

* `default: value` - static default value.
* `default_fn: &Mod.fun/0` - dynamic default used by generated constructors.
  (`default` and `default_fn` are mutually exclusive.)
* `enforce: true | false` - field-level enforce override.
* `doc: "..."` - field-level documentation included in generated docs.

Examples

Enforce all keys by default:

```elixir
defmodule MyStruct do
  use TypedStruct

  # Enforce keys by default.
  typedstruct enforce: true do
    # This key is enforced.
    field :enforced_by_default, term()

    # You can override the default behaviour.
    field :not_enforced, term(), enforce: false

    # A key with a default value is not enforced.
    field :not_enforced_either, integer(), default: 1
  end
end
```

Generate opaque/private types with `visibility`:

```elixir
defmodule MyOpaqueStruct do
  use TypedStruct

  # Generate an opaque type for the struct.
  typedstruct visibility: :opaque do
    field :name, String.t()
  end
end
```

Define generated code in a submodule:

```elixir
defmodule MyPrivateStruct do
  use TypedStruct

  # Generate a private type for the struct.
  typedstruct visibility: :private do
    field :name, String.t()
  end
end
```

```elixir
defmodule MyModule do
  use TypedStruct

  # You now have %MyModule.Struct{}.
  typedstruct module: Struct do
    field :field, term()
  end
end
```

#### Introspection helpers

When `reflection: true` is enabled, TypedStruct generates reflection helpers
at compile time.

For `typedstruct`, the following functions are generated on the struct module:

* `__fields__/0` - ordered list of field names.
* `__required__/0` - ordered list of enforced field names.
* `__defaults__/0` - map of static defaults from `default:`.
* `__dynamic_defaults__/0` - ordered list of fields using `default_fn:`.
* `__types__/0` - internal list used to build the generated typespec.

Example:

```elixir
defmodule User do
  use TypedStruct

  typedstruct reflection: true do
    field :id, integer(), enforce: true
    field :name, String.t(), default: "anonymous"
    field :token, String.t(), default_fn: &UserDefaults.token/0
  end
end

User.__fields__()
# => [:id, :name, :token]

User.__required__()
# => [:id]

User.__defaults__()
# => %{id: nil, name: "anonymous", token: nil}

User.__dynamic_defaults__()
# => [:token]
```

For `typedrecord :person`, the same information is exposed with record-prefixed
function names to avoid collisions when multiple records are defined in one
module:

* `person_fields/0`
* `person_required/0`
* `person_defaults/0`
* `person_dynamic_defaults/0`
* `person_types/0`

Example:

```elixir
defmodule People do
  use TypedStruct

  typedrecord :person, reflection: true do
    field :id, integer(), enforce: true
    field :name, String.t(), default: "anonymous"
  end
end

People.person_fields()
# => [:id, :name]
```

These helpers are intended for tooling, schema inspection, and diagnostics.
If you need runtime validation/construction as well, combine with
`constructors: true`.

## Common Patterns

### Validated Constructors

Enable `constructors: true` to automatically generate constructor functions that validate input:

```elixir
defmodule User do
  use TypedStruct

  typedstruct constructors: true do
    field :name, String.t(), enforce: true
    field :age, integer()
  end
end

# Generated functions:
User.new(name: "Alice", age: 30)          # Returns %User{...}
User.new!(name: "Alice")                  # Raises on missing required fields
User.from_map(%{"name" => "Alice"})       # Convert from map
User.from_keyword(name: "Alice")          # Convert from keyword list

# For typedrecord :person, generates:
# People.person_new/1, person_new!/1, person_from_map/1, person_from_keyword/1
```

### Strict Mode

Use `strict: true` to ensure all fields either have `enforce: true` or a default value:

```elixir
defmodule StrictUser do
  use TypedStruct

  typedstruct strict: true do
    field :id, integer(), enforce: true
    field :name, String.t(), enforce: true
    field :active, boolean(), default: true
    # field :email, String.t()  # Error: must have enforce or default!
  end
end
```

This prevents accidental creation of structs with undefined fields and ensures compile-time safety.

### Dynamic Defaults

Use `default_fn: &Module.function/0` for values that should be computed at construction time:

```elixir
defmodule Token do
  use TypedStruct

  defmodule Defaults do
    def token, do: :crypto.strong_rand_bytes(32) |> Base.encode16()
    def timestamp, do: System.os_time(:second)
  end

  typedstruct do
    field :value, binary(), default_fn: &Defaults.token/0
    field :created_at, integer(), default_fn: &Defaults.timestamp/0
  end
end

# Each new token gets a fresh random value and timestamp
Token.new()  # => %Token{value: "A1B2C3...", created_at: 1699000000}
Token.new()  # => %Token{value: "D4E5F6...", created_at: 1699000010}
```

### Combined: Constructors + Reflection + Strict

Combining these features creates robust, inspectable structs:

```elixir
defmodule User do
  use TypedStruct

  typedstruct constructors: true, reflection: true, strict: true do
    field :id, integer(), enforce: true
    field :email, String.t(), enforce: true
    field :active, boolean(), default: true
    field :created_at, integer(), default_fn: &System.os_time(:second)
  end
end

# Safe construction with validation
user = User.new!(id: 1, email: "alice@example.com")

# Runtime introspection
User.__fields__()          # [:id, :email, :active, :created_at]
User.__required__()        # [:id, :email]
User.__defaults__()        # %{active: true, created_at: 1699000000}
```

### Documentation

TypedStruct supports comprehensive documentation through multiple attributes:

#### Type Documentation with @typedoc

Add a `@typedoc` attribute in the `typedstruct` block to document the type:

```elixir
typedstruct do
  @typedoc "A typed struct"

  field :a_string, String.t()
  field :an_int, integer()
end
```

#### Module Documentation

You can also document the entire module and submodules:

```elixir
typedstruct module: MyStruct do
  @moduledoc "A submodule with a typed struct."
  @typedoc "A typed struct in a submodule"

  field :a_string, String.t()
  field :an_int, integer()
end
```

#### Field Documentation

Document individual fields in two ways:

**1. Using the `doc:` option:**

```elixir
typedstruct do
  field :a_string, String.t(), doc: "A string field"
  field :an_int, integer(), doc: "An integer field"
end
```

**2. Using the `@doc` attribute (applies to the next field):**

```elixir
typedstruct do
  @doc "A string field"
  field :a_string, String.t()

  @doc "An integer field"
  field :an_int, integer()
end
```

The `@doc` attribute is automatically cleared after each field, ensuring it only documents the intended field. This approach is useful when you want to keep documentation close to the field definition.

TypedStruct will append a generated `## Fields` section to the module documentation when running `mix docs` for both `typedstruct` and `typedrecord` blocks:

```elixir
defmodule User do
  use TypedStruct

  @moduledoc "Represents an account user."

  typedstruct do
    field :name, String.t(), doc: "Display name shown in the UI."
    field :email, String.t(), doc: "Primary email address."
    field :active, boolean()
  end
end
```

Only fields with a `doc` value are included in the generated `## Fields`
section.

You can combine docs and constructors options, for example:

```elixir
defmodule User do
  use TypedStruct

  typedstruct constructors: true, strict: true, reflection: true do
    field :id, integer(), enforce: true, doc: "User id"
    field :name, String.t(), default: "anonymous", doc: "Display name"
    field :token, String.t(), default_fn: &UserDefaults.token/0
  end
end
```

## Plugins

It is possible to extend the scope of TypedStruct by using its plugin interface,
as described in
[`TypedStruct.Plugin`](https://hexdocs.pm/typedstruct/TypedStruct.Plugin.html).
For instance, to automatically generate lenses with the
[Lens](https://github.com/obrok/lens) library, you can use
[`TypedStructLens`](https://github.com/saleyn/typedstruct_lens) and do:

```elixir
defmodule MyStruct do
  use TypedStruct

  typedstruct do
    plugin TypedStructLens

    field :a_field, String.t()
    field :other_field, atom()
  end

  @spec change(t()) :: t()
  def change(data) do
    # a_field/0 is generated by TypedStructLens.
    lens = a_field()
    put_in(data, [lens], "Changed")
  end
end
```

Presently plugins are not supported by the `typedrecord` block.

#### Default Plugins

You can specify default plugins when using TypedStruct, which will be automatically
injected into all `typedstruct` and `typedrecord` definitions. This is useful for
creating wrapper modules that provide preset plugins:

```elixir
defmodule MyApp.Type do
  defmacro __using__(_) do
    quote do
      use TypedStruct, plugins: [MyApp.TypedStruct.Plugin.EctoTypes]
    end
  end
end

defmodule MyApp.User do
  use MyApp.Type

  typedstruct do
    field :id, integer(), enforce: true
    field :name, String.t(), ecto_type: :string
  end
end
```

Now `MyApp.User` automatically has the `EctoTypes` plugin injected without needing
to manually call `plugin MyApp.TypedStruct.Plugin.EctoTypes` in the `typedstruct` block.

### Ecto Integration

TypedStruct provides optional integration with Ecto through the `TypedStruct.Ecto` module, enabling you to define Ecto schemas with automatic type inference:

```elixir
defmodule User do
  use TypedStruct.Ecto

  typedschema "users" do
    field      :id,      :id
    field      :email,   :string, enforce: true
    field      :name,    :string
    field      :age,     :integer
    belongs_to :company, Company
    has_many   :posts,   Post
    timestamps()
  end
end
```

The `typedschema` macro automatically infers Elixir types from Ecto field types, generates proper types for associations, supports polymorphic embeds, and enables type overrides with `::` syntax.

**For comprehensive guide with examples, see [ecto.md](ecto.md):**
- Field types and associations
- Embedded and polymorphic schemas
- Type overrides and custom types
- Real-world examples (e-commerce, CMS, notifications)
- Validation patterns
- Comparison with [typed_ecto_schema](https://hex.pm/packages/typed_ecto_schema)

### Built-in Integrations

* `TypedStruct.Ecto` – Optional module providing `typedschema/2` macro for seamless
  Ecto schema integration. Requires Ecto to be installed.
* `TypedStruct.Plugin.EctoSchema` – Reference plugin showing how to build plugins for
  external libraries.

### Third-party Plugins

* [`typedstruct_lens`](https://github.com/saleyn/typedstruct_lens) –
    Integration with the [Lens](https://github.com/obrok/lens) library.
* [`typedstruct_legacy_reflection`](https://github.com/saleyn/typedstruct_legacy_reflection)
  – Re-enables the legacy reflection functions from TypedStruct 0.1.x.
* [`typed_struct_ctor`](https://hexdocs.pm/typed_struct_ctor/TypedStructCtor.html)
  – Adds validating (`new` and `from`) constructor functions.
  > Try the macro out in real time without having to install or write any of your own code.
  > All you need is a running instance of [Livebook](https://livebook.dev/)
  >
  > [![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https://github.com/withbelay/typed_struct_ctor/blob/main/try_it_out.livemd)
* [`typed_ecto_schema`](https://hex.pm/packages/typed_ecto_schema) –
    Specialized library for Ecto schemas with automatic typespec generation for associations,
    timestamps, and other Ecto-specific features.

This list is not meant to be exhaustive, please [search for “typedstruct” on
hex.pm](https://hex.pm/packages?search=typedstruct) for other results. If you
want your plugin to appear here, please open an issue.

## What do I get?

When defining an empty `typedstruct` block:

```elixir
defmodule Example do
  use TypedStruct

  typedstruct do
  end
end
```

you get an empty struct with its module type `t()`:

```elixir
defmodule Example do
  @enforce_keys []
  defstruct []

  @type t() :: %__MODULE__{}
end
```

Each `field` call adds information to the struct, `@enforce_keys` and the type
`t()`.

A field with no options adds the name to the `defstruct` list, with `nil` as
default. The type itself is made nullable:

```elixir
defmodule Example do
  use TypedStruct

  typedstruct do
    field :name, String.t()
  end
end
```

becomes:

```elixir
defmodule Example do
  @enforce_keys []
  defstruct name: nil

  @type t() :: %__MODULE__{
          name: String.t() | nil
        }
end
```

The `default` option adds the default value to the `defstruct`:

```elixir
field :name, String.t(), default: "John Smith"

# Becomes
defstruct name: "John Smith"
```

When set to `true`, the `enforce` option enforces the key by adding it to the
`@enforce_keys` attribute.

```elixir
field :name, String.t(), enforce: true

# Becomes
@enforce_keys [:name]
defstruct name: nil
```

In both cases, the type has no reason to be nullable anymore by default. In one
case the field is filled with its default value and not `nil`, and in the other
case it is enforced. Both options would generate the following type:

```elixir
@type t() :: %__MODULE__{
        name: String.t() # Not nullable
      }
```

Passing `opaque: true` replaces `@type` with `@opaque` in the struct type
specification:

```elixir
typedstruct opaque: true do
  field :name, String.t()
end
```

generates the following type:

```elixir
@opaque t() :: %__MODULE__{
          name: String.t()
        }
```

When passing `module: ModuleName`, the whole `typedstruct` block is wrapped in a
module definition. This way, the following definition:

```elixir
defmodule MyModule do
  use TypedStruct

  typedstruct module: Struct do
    field :field, term()
  end
end
```

becomes:

```elixir
defmodule MyModule do
  defmodule Struct do
    @enforce_keys []
    defstruct field: nil

    @type t() :: %__MODULE__{
            field: term() | nil
          }
  end
end
```

To define a typed record, the following definition of the `typedrecord`:

```elixir
defmodule Person do
  use TypedStruct
  typedrecord :person do
    @typedoc "A person"
    field :name, String.t()
    field :age,  non_neg_integer(), default: 0
  end
end
```

becomes:

```elixir
defmodule Person do
  use Record
  Record.defrecord(:person, name: nil, age: 0)
  @type person :: {:person, String.t()|nil, non_neg_integer()}
end
```

## Usage

### General usage

To define a typed struct, use
[`TypedStruct`](https://hexdocs.pm/typedstruct/TypedStruct.html), then define
your struct within a `typedstruct` block:

```elixir
defmodule MyStruct do
  # Use TypedStruct to import the typedstruct macro.
  use TypedStruct

  # Define your struct.
  typedstruct do
    # Define each field with the field macro.
    field :a_string, String.t()

    # You can set a default value.
    field :string_with_default, String.t(), default: "default"

    # You can enforce a field.
    field :enforced_field, integer(), enforce: true
  end
end
```

Each field is defined through the
[`field/2`](https://hexdocs.pm/typedstruct/TypedStruct.html#field/2) macro.

To define a record use the `typedrecord` block:

```elixir
defmodule Person do
  use TypedStruct

  typedrecord :person do
    @typedoc "A person"

    field :name, String.t(),
    field :age,  non_neg_integer(), default: 0
  end
end
```

## Options

All options are listed together here for quick reference.

Top-level options available on both `typedstruct` and `typedrecord`:

* `module: ModuleName` - defines the generated struct/record in a submodule.
* `visibility: :public | :private | :opaque` - controls generated type visibility.
* `strict: true` - requires each field to be enforced or provide `default` / `default_fn`.
* `constructors: true` - generates validated constructors.
* `reflection: true` - generates helper functions for fields, defaults,
  required fields, and types (see [Introspection helpers](#reflection-helpers)).
* `docs: :full | :module_only | :fields_only | false` - controls how field docs
  are merged into module documentation.

Additional `typedstruct`-only options:

* `enforce: true` - enforces all fields by default unless overridden per field.
* `new: true` - generates a simple `new/1` constructor (`struct(__MODULE__, attrs)`).
* `derive: [Protocol1, Protocol2]` - passes through `@derive` before `defstruct`.
* `opaque: true` - deprecated alias for `visibility: :opaque`.

Additional `typedrecord`-only options:

* `tag: atom()` - sets record tag passed to `Record.defrecord/3`.
* `opaque: true` - deprecated alias for `visibility: :opaque`.

Field-level options (`field/3`):

* `default: value` - static default value.
* `default_fn: &Mod.fun/0` - dynamic default used by generated constructors.
  (`default` and `default_fn` are mutually exclusive.)
* `enforce: true | false` - field-level enforce override.
* `doc: "..."` - field-level documentation included in generated docs.

Examples

Enforce all keys by default:

```elixir
defmodule MyStruct do
  use TypedStruct

  # Enforce keys by default.
  typedstruct enforce: true do
    # This key is enforced.
    field :enforced_by_default, term()

    # You can override the default behaviour.
    field :not_enforced, term(), enforce: false

    # A key with a default value is not enforced.
    field :not_enforced_either, integer(), default: 1
  end
end
```

Generate opaque/private types with `visibility`:

```elixir
defmodule MyOpaqueStruct do
  use TypedStruct

  # Generate an opaque type for the struct.
  typedstruct visibility: :opaque do
    field :name, String.t()
  end
end
```

Define generated code in a submodule:

```elixir
defmodule MyPrivateStruct do
  use TypedStruct

  # Generate a private type for the struct.
  typedstruct visibility: :private do
    field :name, String.t()
  end
end
```

```elixir
defmodule MyModule do
  use TypedStruct

  # You now have %MyModule.Struct{}.
  typedstruct module: Struct do
    field :field, term()
  end
end
```

### Introspection helpers

When `reflection: true` is enabled, TypedStruct generates reflection helpers
at compile time.

For `typedstruct`, the following functions are generated on the struct module:

* `__fields__/0` - ordered list of field names.
* `__required__/0` - ordered list of enforced field names.
* `__defaults__/0` - map of static defaults from `default:`.
* `__dynamic_defaults__/0` - ordered list of fields using `default_fn:`.
* `__types__/0` - internal list used to build the generated typespec.

Example:

```elixir
defmodule User do
  use TypedStruct

  typedstruct reflection: true do
    field :id, integer(), enforce: true
    field :name, String.t(), default: "anonymous"
    field :token, String.t(), default_fn: &UserDefaults.token/0
  end
end

User.__fields__()
# => [:id, :name, :token]

User.__required__()
# => [:id]

User.__defaults__()
# => %{id: nil, name: "anonymous", token: nil}

User.__dynamic_defaults__()
# => [:token]
```

For `typedrecord :person`, the same information is exposed with record-prefixed
function names to avoid collisions when multiple records are defined in one
module:

* `person_fields/0`
* `person_required/0`
* `person_defaults/0`
* `person_dynamic_defaults/0`
* `person_types/0`

Example:

```elixir
defmodule People do
  use TypedStruct

  typedrecord :person, reflection: true do
    field :id, integer(), enforce: true
    field :name, String.t(), default: "anonymous"
  end
end

People.person_fields()
# => [:id, :name]
```

These helpers are intended for tooling, schema inspection, and diagnostics.
If you need runtime validation/construction as well, combine with
`constructors: true`.

## Common Patterns

### Validated Constructors

Enable `constructors: true` to automatically generate constructor functions that validate input:

```elixir
defmodule User do
  use TypedStruct

  typedstruct constructors: true do
    field :name, String.t(), enforce: true
    field :age, integer()
  end
end

# Generated functions:
User.new(name: "Alice", age: 30)          # Returns %User{...}
User.new!(name: "Alice")                  # Raises on missing required fields
User.from_map(%{"name" => "Alice"})       # Convert from map
User.from_keyword(name: "Alice")          # Convert from keyword list

# For typedrecord :person, generates:
# People.person_new/1, person_new!/1, person_from_map/1, person_from_keyword/1
```

### Strict Mode

Use `strict: true` to ensure all fields either have `enforce: true` or a default value:

```elixir
defmodule StrictUser do
  use TypedStruct

  typedstruct strict: true do
    field :id, integer(), enforce: true
    field :name, String.t(), enforce: true
    field :active, boolean(), default: true
    # field :email, String.t()  # Error: must have enforce or default!
  end
end
```

This prevents accidental creation of structs with undefined fields and ensures compile-time safety.

### Dynamic Defaults

Use `default_fn: &Module.function/0` for values that should be computed at construction time:

```elixir
defmodule Token do
  use TypedStruct

  defmodule Defaults do
    def token, do: :crypto.strong_rand_bytes(32) |> Base.encode16()
    def timestamp, do: System.os_time(:second)
  end

  typedstruct do
    field :value, binary(), default_fn: &Defaults.token/0
    field :created_at, integer(), default_fn: &Defaults.timestamp/0
  end
end

# Each new token gets a fresh random value and timestamp
Token.new()  # => %Token{value: "A1B2C3...", created_at: 1699000000}
Token.new()  # => %Token{value: "D4E5F6...", created_at: 1699000010}
```

### Combined: Constructors + Reflection + Strict

Combining these features creates robust, inspectable structs:

```elixir
defmodule User do
  use TypedStruct

  typedstruct constructors: true, reflection: true, strict: true do
    field :id, integer(), enforce: true
    field :email, String.t(), enforce: true
    field :active, boolean(), default: true
    field :created_at, integer(), default_fn: &System.os_time(:second)
  end
end

# Safe construction with validation
user = User.new!(id: 1, email: "alice@example.com")

# Runtime introspection
User.__fields__()          # [:id, :email, :active, :created_at]
User.__required__()        # [:id, :email]
User.__defaults__()        # %{active: true, created_at: 1699000000}
```

### Documentation

TypedStruct supports comprehensive documentation through multiple attributes:

#### Type Documentation with @typedoc

Add a `@typedoc` attribute in the `typedstruct` block to document the type:

```elixir
typedstruct do
  @typedoc "A typed struct"

  field :a_string, String.t()
  field :an_int, integer()
end
```

#### Module Documentation

You can also document the entire module and submodules:

```elixir
typedstruct module: MyStruct do
  @moduledoc "A submodule with a typed struct."
  @typedoc "A typed struct in a submodule"

  field :a_string, String.t()
  field :an_int, integer()
end
```

#### Field Documentation

Document individual fields in two ways:

**1. Using the `doc:` option:**

```elixir
typedstruct do
  field :a_string, String.t(), doc: "A string field"
  field :an_int, integer(), doc: "An integer field"
end
```

**2. Using the `@doc` attribute (applies to the next field):**

```elixir
typedstruct do
  @doc "A string field"
  field :a_string, String.t()

  @doc "An integer field"
  field :an_int, integer()
end
```

The `@doc` attribute is automatically cleared after each field, ensuring it only documents the intended field. This approach is useful when you want to keep documentation close to the field definition.

`TypedStruct` will append a generated `## Fields` section to the module documentation when running `mix docs` for both `typedstruct` and `typedrecord` blocks:

```elixir
defmodule User do
  use TypedStruct

  @moduledoc "Represents an account user."

  typedstruct do
    field :name, String.t(), doc: "Display name shown in the UI."
    field :email, String.t(), doc: "Primary email address."
    field :active, boolean()
  end
end
```

Only fields with a `doc` value are included in the generated `## Fields`
section.

You can combine docs and constructors options, for example:

```elixir
defmodule User do
  use TypedStruct

  typedstruct constructors: true, strict: true, reflection: true do
    field :id, integer(), enforce: true, doc: "User id"
    field :name, String.t(), default: "anonymous", doc: "Display name"
    field :token, String.t(), default_fn: &UserDefaults.token/0
  end
end
```

## Plugins

It is possible to extend the scope of TypedStruct by using its plugin interface,
as described in
[`TypedStruct.Plugin`](https://hexdocs.pm/typedstruct/TypedStruct.Plugin.html).
For instance, to automatically generate lenses with the
[Lens](https://github.com/obrok/lens) library, you can use
[`TypedStructLens`](https://github.com/saleyn/typedstruct_lens) and do:

```elixir
defmodule MyStruct do
  use TypedStruct

  typedstruct do
    plugin TypedStructLens

    field :a_field, String.t()
    field :other_field, atom()
  end

  @spec change(t()) :: t()
  def change(data) do
    # a_field/0 is generated by TypedStructLens.
    lens = a_field()
    put_in(data, [lens], "Changed")
  end
end
```

Presently plugins are not supported by the `typedrecord` block.

### Default Plugins

You can specify default plugins when using TypedStruct, which will be automatically
injected into all `typedstruct` and `typedrecord` definitions. This is useful for
creating wrapper modules that provide preset plugins:

```elixir
defmodule MyApp.Type do
  defmacro __using__(_) do
    quote do
      use TypedStruct, plugins: [MyApp.TypedStruct.Plugin.EctoTypes]
    end
  end
end

defmodule MyApp.User do
  use MyApp.Type

  typedstruct do
    field :id, integer(), enforce: true
    field :name, String.t(), ecto_type: :string
  end
end
```

Now `MyApp.User` automatically has the `EctoTypes` plugin injected without needing
to manually call `plugin MyApp.TypedStruct.Plugin.EctoTypes` in the `typedstruct` block.

### Third-party Plugins

* [`typedstruct_lens`](https://github.com/saleyn/typedstruct_lens) –
    Integration with the [Lens](https://github.com/obrok/lens) library.
* [`typedstruct_legacy_reflection`](https://github.com/saleyn/typedstruct_legacy_reflection)
  – Re-enables the legacy reflection functions from TypedStruct 0.1.x.
* [`typed_struct_ctor`](https://hexdocs.pm/typed_struct_ctor/TypedStructCtor.html)
  – Adds validating (`new` and `from`) constructor functions.
  > Try the macro out in real time without having to install or write any of your own code.
  > All you need is a running instance of [Livebook](https://livebook.dev/)
  >
  > [![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https://github.com/withbelay/typed_struct_ctor/blob/main/try_it_out.livemd)
* [`typed_ecto_schema`](https://hex.pm/packages/typed_ecto_schema) –
    Specialized library for Ecto schemas with automatic typespec generation for associations,
    timestamps, and other Ecto-specific features.

This list is not meant to be exhaustive, please [search for “typedstruct” on
hex.pm](https://hex.pm/packages?search=typedstruct) for other results. If you
want your plugin to appear here, please open an issue.

## Ecto Integration

TypedStruct provides optional integration with Ecto through the `TypedStruct.Ecto` module, enabling you to define Ecto schemas with automatic type inference:

```elixir
defmodule User do
  use TypedStruct.Ecto

  typedschema "users" do
    field      :id,      :id
    field      :email,   :string, enforce: true
    field      :name,    :string
    field      :age,     :integer
    belongs_to :company, Company
    has_many   :posts,   Post
    timestamps()
  end
end
```

The `typedschema` macro automatically infers Elixir types from Ecto field types, generates proper types for associations, supports polymorphic embeds, and enables type overrides with `::` syntax.

**For comprehensive guide with examples, see [TypedStruct.Ecto Guide](ecto.md):**
- Field types and associations
- Embedded and polymorphic schemas
- Type overrides and custom types
- Real-world examples (e-commerce, CMS, notifications)
- Validation patterns
- Comparison with [typed_ecto_schema](https://hex.pm/packages/typed_ecto_schema)

### Built-in Integrations

* `TypedStruct.Ecto` – Optional module providing `typedschema/2` macro for seamless
  Ecto schema integration. Requires Ecto to be installed.
* `TypedStruct.Plugin.EctoSchema` – Reference plugin showing how to build plugins for
  external libraries.

<!-- @moduledoc -->

## Related libraries

* [Domo](https://github.com/IvanRublev/Domo): a library to validate structs that
    define a `t()` type, like the one generated by `TypedStruct`.
* [TypedEctoSchema](https://github.com/bamorim/typed_ecto_schema): a library
    that provides a DSL on top of `Ecto.Schema` to achieve the same result as
    `TypedStruct`, with `Ecto`.

## [Contributing](CONTRIBUTING.md)

Before contributing to this project, please read the
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

This project is licensed under the [MIT license](./LICENSE.md).
