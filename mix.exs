defmodule TypedStruct.MixProject do
  use Mix.Project

  @version "0.5.3"
  @repo_url "https://github.com/saleyn/typedstruct"

  def project do
    version = vsn()
    [
      app: :typedstruct,
      version: version,
      elixir: "~> 1.13",
      start_permanent: false,
      deps: deps(),
      elixirc_paths: elixirc_paths(),

      # Tools
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: cli_env(),

      # Docs
      name: "TypedStruct",
      docs: [
        extras: [
          "README.md": [title: "Overview"],
          "CHANGELOG.md": [title: "Changelog"],
          "CONTRIBUTING.md": [title: "Contributing"],
          "LICENSE.md": [title: "License"]
        ],
        main: "readme",
        source_url: @repo_url,
        source_ref: "v#{version}",
        formatters: ["html"]
      ],

      # Package
      package: package(),
      description:
        "A library for defining structs with a type without writing " <>
          "boilerplate code."
    ]
  end

  defp deps do
    [
      # Development and test dependencies
      {:ex_check, "~> 0.14.0", only: :dev, runtime: false},
      {:credo, "~> 1.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:excoveralls, ">= 0.0.0", only: :test, runtime: false},
      {:mix_test_watch, ">= 0.0.0", only: :test, runtime: false},
      {:ex_unit_notifier, ">= 0.0.0", only: :test, runtime: false},
      # Project dependencies

      # Documentation dependencies
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(), do: (Mix.env() == :test && ["lib", "test"]) || ["lib"]

  # Dialyzer configuration
  defp dialyzer do
    [
      # Use a custom PLT directory for continuous integration caching.
      plt_core_path: System.get_env("PLT_DIR"),
      plt_file: plt_file(),
      plt_add_deps: :app_tree,
      flags: [
        :unmatched_returns,
        :error_handling
      ],
      ignore_warnings: ".dialyzer_ignore"
    ]
  end

  defp plt_file do
    case System.get_env("PLT_DIR") do
      nil -> nil
      plt_dir -> {:no_warn, Path.join(plt_dir, "typedstruct.plt")}
    end
  end

  defp cli_env do
    [
      # Run mix test.watch in `:test` env.
      "test.watch": :test,

      # Always run Coveralls Mix tasks in `:test` env.
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.html": :test,

      # Use a custom env for docs.
      docs: :docs
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "Changelog" => "https://hexdocs.pm/typedstruct/changelog.html",
        "GitHub" => @repo_url
      }
    ]
  end

  # Obtain the version of this library
  # If it's loaded as a dependency from Hex.pm, then the project contains
  # ".hex" file, which contains the version.  If it's loaded from git, then
  # we can use "git describe" command to format the version with a revision.
  # Otherwise use a verbatim version from the attribute.
  #
  # NOTE: with this method of calculating the version number, you need to make
  # sure that in the Github action the checkout includes:
  # ```
  #   - name: Checkout the repository
  #     uses: actions/checkout@v4
  #     with:
  #       fetch-depth: 0
  # ```
  # This ensures that the git history is checked out with tags so that
  # `git describe --tags` returns the proper version number.
  defp vsn() do
    hex_spec = Mix.Project.deps_path() |> Path.dirname() |> Path.join(".hex")
    if File.exists?(hex_spec) do
      hex_spec
      |> File.read!()
      |> :erlang.binary_to_term()
      |> elem(1)
      |> Map.get(:version)
    else
      with {ver, 0} <-
            System.cmd("git", ~w(describe --always --tags),
              stderr_to_stdout: true
            ) do
        ver
        |> String.trim()
        |> String.replace(~r/^v/, "")
      else _ ->
        #raise "Cannot determine application version!"
        @version
      end
    end
  end
end
