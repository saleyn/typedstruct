# TypedStruct.Ecto Guide

TypedStruct provides optional integration with Ecto through the `TypedStruct.Ecto` module. This guide shows how to use it with comprehensive examples.

## Requirements

To use TypedStruct.Ecto features, you need to add Ecto as a dependency:

```elixir
# mix.exs
def deps do
  [
    {:ecto, "~> 3.9"}
  ]
end
```

TypedStruct.Ecto automatically detects if Ecto is available. If Ecto is not installed:
- `use TypedStruct.Ecto` will fail with an undefined module error
- `TypedStruct` (without `.Ecto`) still works fine for plain struct definitions

### When You DON'T Need Ecto

If you're just defining regular structs with types (not database schemas), you don't need Ecto:

```elixir
# For plain structs without database persistence
defmodule Person do
  use TypedStruct  # No .Ecto

  typedstruct do
    field :name, String.t(), enforce: true
    field :age, integer()
  end
end
```

Use `TypedStruct.Ecto` only when:
- You're defining Ecto schemas (database models)
- You need automatic type inference from Ecto field types
- You want to define both schema and type at once with `typedschema`

### Optional: Polymorphic Embeds

If you need polymorphic embed support with automatic type discriminators, also add:

```elixir
def deps do
  [
    {:ecto, "~> 3.9"},
    {:polymorphic_embed, "~> 5.0"}
  ]
end
```

When installed, TypedStruct.Ecto automatically imports `polymorphic_embeds_one/2-3` and `polymorphic_embeds_many/2-3` macros and generates proper union types.

## Table of Contents

- [Quick Start](#quick-start)
- [Basic Field Types](#basic-field-types)
- [Associations](#associations)
- [Embeds](#embeds)
- [Type Overrides](#type-overrides)
- [Real-World Examples](#real-world-examples)
- [Validation](#validation)
- [Comparison with typed_ecto_schema](#comparison-with-typed_ecto_schema)

## Quick Start

```elixir
defmodule User do
  use TypedStruct.Ecto

  typedschema "users" do
    field :id,    :id
    field :email, :string, enforce: true
    field :name,  :string
    field :age,   :integer
    timestamps()
  end
end
```

The `typedschema` macro automatically:
- Sets up `use Ecto.Schema`
- Infers Elixir types from Ecto field types
- Creates both Ecto schema and TypedStruct with matching types
- Handles associations and embeds

## Basic Field Types

TypedStruct.Ecto automatically maps Ecto types to Elixir types:

```elixir
defmodule Product do
  use TypedStruct.Ecto

  typedschema "products" do
    # Numeric types
    field :id,            :id               # → integer()
    field :quantity,      :integer          # → integer()
    field :price,         :decimal          # → Decimal.t()
    field :rating,        :float            # → float()

    # String types
    field :name,          :string           # → String.t()
    field :description,   :binary           # → binary()

    # Boolean
    field :active,        :boolean          # → boolean()

    # Date/Time types
    field :published_at,  :datetime         # → DateTime.t()
    field :created_date,  :date             # → Date.t()
    field :reminder_time, :time             # → Time.t()
    field :start_at,      :naive_datetime   # → NaiveDateTime.t()

    # Complex types
    field :metadata,      :map              # → map()

    timestamps()
  end
end
```

## Associations

All Ecto associations are automatically typed:

```elixir
defmodule User do
  use TypedStruct.Ecto

  typedschema "users" do
    field :id,    :id
    field :email, :string,  enforce: true

    # Associations - all automatically typed
    belongs_to    :company, Company         # → company_id: integer(), company: Company.t() | NotLoaded
    has_many      :posts,   Post            # → posts: [Post.t()] | NotLoaded
    has_one       :profile, Profile         # → profile: Profile.t() | NotLoaded
    many_to_many  :tags,    Tag             # → tags: [Tag.t()] | NotLoaded

    timestamps()
  end
end
```

### Example: User with Company Relationship

```elixir
defmodule Company do
  use TypedStruct.Ecto

  typedschema "companies" do
    field    :name,       :string, enforce: true
    field    :founded_at, :date
    has_many :users,      User
    timestamps()
  end
end

defmodule User do
  use TypedStruct.Ecto

  typedschema "users" do
    field      :email,   :string, enforce: true
    field      :name,    :string
    belongs_to :company, Company
    has_many   :posts,   Post
    timestamps()
  end
end

defmodule Post do
  use TypedStruct.Ecto

  typedschema "posts" do
    field      :title,   :string, enforce: true
    field      :content, :string
    belongs_to :user,    User
    timestamps()
  end
end
```

Generated types:
- `User.t()` includes: `company_id: integer() | nil`, `company: Company.t() | NotLoaded`, `posts: [Post.t()] | NotLoaded`
- `Company.t()` includes: `users: [User.t()] | NotLoaded`
- `Post.t()` includes: `user_id: integer() | nil`, `user: User.t() | NotLoaded`

## Embeds

Both regular and polymorphic embeds are supported:

### Regular Embeds

```elixir
defmodule Address do
  use Ecto.Schema

  embedded_schema do
    field :street, :string
    field :city,   :string
    field :state,  :string
    field :zip,    :string
  end
end

defmodule Person do
  use TypedStruct.Ecto

  typedschema "people" do
    field       :name,    :string, enforce: true
    embeds_one  :address, Address           # → address: Address.t()
    embeds_many :phones,  Phone             # → phones: [Phone.t()]
    timestamps()
  end
end
```

### Polymorphic Embeds

TypedStruct.Ecto supports polymorphic embeds through the [`polymorphic_embed`](https://hex.pm/packages/polymorphic_embed) library. When this library is installed, TypedStruct.Ecto automatically imports its macros and generates union types for polymorphic relationships.

#### Setup

Add `polymorphic_embed` to your dependencies:

```elixir
# mix.exs
def deps do
  [
    {:ecto, "~> 3.9"},
    {:polymorphic_embed, "~> 5.0"}
  ]
end
```

#### Basic Example

```elixir
defmodule EmailConfig do
  use Ecto.Schema

  embedded_schema do
    field :recipient, :string
    field :subject,   :string
  end
end

defmodule SMSConfig do
  use Ecto.Schema

  embedded_schema do
    field :phone, :string
  end
end

defmodule PushConfig do
  use Ecto.Schema

  embedded_schema do
    field :app_id, :string
  end
end

defmodule NotificationTemplate do
  use TypedStruct.Ecto

  typedschema "notification_templates" do
    field :name, :string, enforce: true

    # Polymorphic embed with automatic union type generation
    polymorphic_embeds_one :channel,
      types: [
        email: EmailConfig,
        sms:   SMSConfig,
        push:  PushConfig
      ],
      on_replace: :update
    # Generated type: channel: EmailConfig.t() | SMSConfig.t() | PushConfig.t()

    timestamps()
  end
end
```

#### Multiple Polymorphic Embeds

You can have multiple polymorphic embeds with different unions:

```elixir
defmodule Notification do
  use TypedStruct.Ecto

  typedschema "notifications" do
    field :message, :string, enforce: true

    # Notification channel (email, sms, push)
    polymorphic_embeds_one :channel,
      types: [
        email: EmailConfig,
        sms:   SMSConfig,
        push:  PushConfig
      ],
      on_replace: :update

    # Notification priority levels
    polymorphic_embeds_one :priority,
      types: [
        critical: CriticalPriority,
        normal:   NormalPriority,
        low:      LowPriority
      ],
      on_replace: :update

    timestamps()
  end
end
```

#### Polymorphic Embeds Many

Use `polymorphic_embeds_many` for multiple items of different types:

```elixir
defmodule Order do
  use TypedStruct.Ecto

  typedschema "orders" do
    field :order_number, :string, enforce: true

    # Multiple events of different types in order
    polymorphic_embeds_many :events,
      types: [
        created:   OrderCreatedEvent,
        updated:   OrderUpdatedEvent,
        cancelled: OrderCancelledEvent,
        shipped:   OrderShippedEvent
      ],
      on_replace: :delete
    # Generated type: events: [OrderCreatedEvent.t() | OrderUpdatedEvent.t() | OrderCancelledEvent.t() | OrderShippedEvent.t()]

    timestamps()
  end
end
```

#### Type Generated

TypedStruct.Ecto automatically generates union types for all polymorphic embeds:

```elixir
# For polymorphic_embeds_one :channel, types: [email: Email, sms: SMS, push: Push]
# Generates:
@type t() :: %__MODULE__{
  channel: Email.t() | SMS.t() | Push.t()
}

# For polymorphic_embeds_many :events, types: [created: Created, updated: Updated]
# Generates:
@type t() :: %__MODULE__{
  events: [Created.t() | Updated.t()]
}
```

#### How It Works

1. **Library Detection**: TypedStruct.Ecto detects if `polymorphic_embed` is installed
2. **Macro Import**: If available, it automatically imports `polymorphic_embeds_one/2`, `polymorphic_embeds_one/3`, `polymorphic_embeds_many/2`, and `polymorphic_embeds_many/3`
3. **Type Generation**: The `typedschema` macro transforms polymorphic embed declarations into union types for the TypedStruct
4. **Ecto Integration**: The polymorphic embed macros are passed directly to Ecto's schema for database handling

#### Without polymorphic_embed Library

If you don't need the full `polymorphic_embed` library features but want to document polymorphic types, you can manually create union types:

```elixir
defmodule Notification do
  use TypedStruct.Ecto

  typedschema "notifications" do
    field :message, :string, enforce: true
    # Without polymorphic_embed library, use manual union type
    field :config, EmailConfig.t() | SMSConfig.t() | PushConfig.t() :: EmailConfig.t() | SMSConfig.t() | PushConfig.t()
    timestamps()
  end
end
```

Note: This approach requires manual management of the polymorphic data structure - you lose the automatic type discriminator handling that `polymorphic_embed` provides.

## Type Overrides

Use `::` syntax to override inferred types for custom types or narrowed types:

### Custom Ecto Types

```elixir
defmodule Money do
  use Ecto.Type
  def type, do: :decimal
  # ... cast/dump/load implementations
end

defmodule Price do
  use Ecto.Type
  def type, do: :string
  # ... implementation
end

defmodule Product do
  use TypedStruct.Ecto

  typedschema "products" do
    field :name, :string, enforce: true

    # Override Decimal.t() with Money.t()
    field :price, :decimal :: Money.t()

    # Override String.t() with Price.t()
    field :display_price, :string :: Price.t()

    timestamps()
  end
end
```

### Narrowed Types

```elixir
defmodule Survey do
  use TypedStruct.Ecto

  typedschema "surveys" do
    field :title, :string, enforce: true

    # Narrow integer() to 1..5 range
    field :rating, :integer :: 1..5

    # Narrow integer() to positive integers
    field :question_count, :integer :: pos_integer()

    # Union type for status enum
    field :status, :string :: :draft | :active | :closed

    timestamps()
  end
end
```

### Domain-Specific Types

```elixir
defmodule Email do
  defstruct value: ""
end

defmodule PhoneNumber do
  defstruct value: ""
end

defmodule Contact do
  use TypedStruct.Ecto

  typedschema "contacts" do
    field :name, :string, enforce: true

    # Use domain-specific types instead of generic String.t()
    field :email, :string :: Email.t()
    field :phone, :string :: PhoneNumber.t()

    timestamps()
  end
end
```

## Real-World Examples

### E-Commerce Order

```elixir
defmodule Order do
  use TypedStruct.Ecto

  typedschema "orders" do
    field :order_number, :string, enforce: true

    # Basic fields with type narrowing
    field :amount, :decimal :: Money.t()
    field :status, :string  :: :pending | :processing | :shipped | :delivered | :cancelled

    # Relationships
    belongs_to :customer, Customer
    has_many   :items,    OrderItem

    # Shipping address
    embeds_one :shipping_address, {:polymorphic,
      type_field: :type,
      types: [
        residential: ResidentialAddress,
        commercial:  CommercialAddress,
        po_box:      POBoxAddress
      ]
    }

    # Payment method
    embeds_one :payment_method, {:polymorphic,
      type_field: :type,
      types: [
        credit_card:   CreditCardPayment,
        paypal:        PayPalPayment,
        bank_transfer: BankTransferPayment
      ]
    }

    timestamps()
  end
end

defmodule OrderItem do
  use TypedStruct.Ecto

  typedschema "order_items" do
    field :quantity,   :integer :: pos_integer()
    field :unit_price, :decimal :: Money.t()

    belongs_to :order,   Order
    belongs_to :product, Product

    timestamps()
  end
end
```

### Content Management System

```elixir
defmodule Article do
  use TypedStruct.Ecto

  typedschema "articles" do
    field :title,        :string, enforce: true
    field :slug,         :string, enforce: true
    field :content,      :string
    field :status,       :string :: :draft | :published | :archived
    field :published_at, :naive_datetime

    # Author relationship
    belongs_to :author, User

    # Tags (many-to-many)
    many_to_many :tags, Tag

    # Content blocks (polymorphic embeds)
    embeds_many :blocks, {:polymorphic,
      type_field: :type,
      types: [
        text:  TextBlock,
        image: ImageBlock,
        video: VideoBlock,
        quote: QuoteBlock,
        code:  CodeBlock
      ]
    }

    # SEO metadata
    embeds_one :seo_metadata, SEOMetadata

    timestamps()
  end
end
```

### Notification System

```elixir
defmodule NotificationPreference do
  use TypedStruct.Ecto

  typedschema "notification_preferences" do
    belongs_to :user, User

    # Channel-specific configs (polymorphic)
    embeds_one :email_config, {:polymorphic,
      type_field: :type,
      types: [email: EmailNotificationConfig]
    }

    embeds_one :sms_config, {:polymorphic,
      type_field: :type,
      types: [sms: SMSNotificationConfig]
    }

    embeds_one :push_config, {:polymorphic,
      type_field: :type,
      types: [push: PushNotificationConfig]
    }

    # Notification schedule
    embeds_one :schedule, NotificationSchedule

    # Enabled notifications (many-to-many)
    many_to_many :enabled_events, Event

    timestamps()
  end
end
```

## Validation

Validation works the same in TypedStruct.Ecto as in typed_ecto_schema - through changesets:

```elixir
defmodule User do
  use TypedStruct.Ecto

  typedschema "users" do
    field      :email,    :string, enforce: true
    field      :password, :string
    field      :name,     :string
    field      :age,      :integer
    belongs_to :company,  Company
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> Ecto.Changeset.cast(attrs, [:email, :password, :name, :age, :company_id])
    |> Ecto.Changeset.validate_required([:email, :password])
    |> Ecto.Changeset.validate_format(:email, ~r/@/)
    |> Ecto.Changeset.validate_length(:password, min: 8)
    |> Ecto.Changeset.validate_number(:age, greater_than_or_equal_to: 0, less_than_or_equal_to: 150)
    |> Ecto.Changeset.unique_constraint(:email)
    |> Ecto.Changeset.assoc_constraint(:company)
  end

  def registration_changeset(user, attrs) do
    user
    |> changeset(attrs)
    |> Ecto.Changeset.validate_confirmation(:password)
  end
end
```

## Comparison with typed_ecto_schema

| Feature | TypedStruct.Ecto | typed_ecto_schema |
|---------|------------------|-------------------|
| Basic fields | ✅ | ✅ |
| Type inference | ✅ Good | ✅ Excellent |
| Type overrides | ✅ | ✅ |
| Associations | ✅ | ✅ |
| Polymorphic embeds | ✅ | ✅ |
| Custom Ecto types | ✅ | ✅ |
| Validation | ✅ Same (changesets) | ✅ Same (changesets) |
| Built into TypedStruct | ✅ | ❌ |
| No extra dependencies | ✅ | ❌ |

### When to Use TypedStruct.Ecto

- Production schemas with automatic type inference
- Custom Ecto types with proper typing
- Polymorphic embeds with union types
- Domain-specific type narrowing
- Most real-world Ecto use cases
- When you want everything built-in without extra dependencies

### When to Use typed_ecto_schema

- Perfect association typing for complex nested relationships
- Very advanced Ecto features
- Highly specialized use cases requiring cutting-edge type handling

## More Information

See the `TypedStruct.Ecto` module documentation for complete API reference.