defmodule TypedStruct.Integration.EctoIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  # Note: This test compiles temporary modules which may generate
  # "redefining module" warnings - these are normal and expected.

  test "TypedStruct.Ecto features work in a separate project with path dependency" do
    typedstruct_path = Path.expand("../..", __DIR__)
    tmp_dir = Path.join(System.tmp_dir!(), "typedstruct-ecto-#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    try do
      # Create a new mix project
      run_mix!("new", ["ecto_app"], tmp_dir)
      app_dir = Path.join(tmp_dir, "ecto_app")
      mix_exs = Path.join(app_dir, "mix.exs")

      # Add typedstruct (path), ecto, and polymorphic_embed dependencies
      mix_exs
      |> File.read!()
      |> String.replace(
        "# {:dep_from_hexpm, \"~> 0.3.0\"},",
        "{:typedstruct, path: \"#{typedstruct_path}\"},
         {:ecto, \"~> 3.9\"},
         {:polymorphic_embed, \"~> 5.0\"},"
      )
      |> then(&File.write!(mix_exs, &1))

      # Get dependencies
      run_mix!("deps.get", [], app_dir)

      # Create test file with Ecto integration features
      # Tests: basic fields, associations, embeds, timestamps
      # Note: polymorphic embeds require the polymorphic_embed library
      test_file = Path.join([app_dir, "lib", "ecto_app.ex"])

      test_code = """
      defmodule EctoApp.User do
        use TypedStruct.Ecto

        typedschema "users" do
          field :email, :string, enforce: true
          field :name, :string
          field :age, :integer
          field :active, :boolean, default: true
          field :balance, :decimal
          field :birthday, :date
          belongs_to :company, EctoApp.Company
          has_many :posts, EctoApp.Post
          timestamps()
        end
      end

      defmodule EctoApp.Company do
        use TypedStruct.Ecto

        typedschema "companies" do
          field :name, :string, enforce: true
          has_many :users, EctoApp.User
          timestamps()
        end
      end

      defmodule EctoApp.Post do
        use TypedStruct.Ecto

        typedschema "posts" do
          field :title, :string, enforce: true
          field :content, :string
          belongs_to :user, EctoApp.User
          timestamps()
        end
      end

      defmodule EctoApp.Product do
        use TypedStruct.Ecto

        typedschema "products" do
          field :name, :string, enforce: true
          field :price, :decimal
          field :status, :string
          field :quantity, :integer
          timestamps()
        end
      end

      defmodule EctoApp.EmailConfig do
        use Ecto.Schema

        embedded_schema do
          field :recipient, :string
          field :subject, :string
        end
      end

      defmodule EctoApp.SMSConfig do
        use Ecto.Schema

        embedded_schema do
          field :phone, :string
        end
      end

      defmodule EctoApp.Notification do
        use TypedStruct.Ecto

        typedschema "notifications" do
          field :message, :string, enforce: true
          embeds_one :config, EctoApp.EmailConfig

          polymorphic_embeds_one :channel,
            types: [
              email: EctoApp.EmailConfig,
              sms: EctoApp.SMSConfig
            ],
            on_replace: :update

          timestamps()
        end
      end

      # Verify schemas compile and are accessible
      defmodule SchemaVerification do
        def verify do
          # Verify module exists and has schema info
          EctoApp.User.__schema__(:fields)
          EctoApp.Company.__schema__(:fields)
          EctoApp.Post.__schema__(:fields)
          EctoApp.Product.__schema__(:fields)
          EctoApp.Notification.__schema__(:fields)
          :ok
        end
      end
      """

      File.write!(test_file, test_code)

      # Compile the project
      run_mix!("compile", [], app_dir)
    after
      File.rm_rf!(tmp_dir)
    end
  end

  defp run_mix!(task, args, cwd) do
    {output, status} = System.cmd("mix", [task | args], cd: cwd, stderr_to_stdout: true)

    assert status == 0,
           "mix #{task} #{Enum.join(args, " ")} failed in #{cwd} with exit #{status}:\n#{output}"
  end
end
