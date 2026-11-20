defmodule TypedStruct.Integration.InspectRecordsConfigTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  test "config :typedstruct, :inspect_records, false skips the Inspect override" do
    refute inspect_impl_compiled?("config :typedstruct, :inspect_records, false")
  end

  test "the older :typed_struct key is still honored" do
    refute inspect_impl_compiled?("config :typed_struct, :inspect_records, false")
  end

  test "the Inspect override is compiled by default" do
    assert inspect_impl_compiled?(nil)
  end

  defp inspect_impl_compiled?(config_line) do
    typedstruct_path = Path.expand("../..", __DIR__)
    tmp_dir = Path.join(System.tmp_dir!(), "typedstruct-issue-16-#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    try do
      run_mix!("new", ["demo_app"], tmp_dir)

      app_dir = Path.join(tmp_dir, "demo_app")
      mix_exs = Path.join(app_dir, "mix.exs")

      mix_exs
      |> File.read!()
      |> String.replace(
        "# {:dep_from_hexpm, \"~> 0.3.0\"},",
        "{:typedstruct, path: \"#{typedstruct_path}\"},"
      )
      |> then(&File.write!(mix_exs, &1))

      if config_line do
        File.mkdir_p!(Path.join(app_dir, "config"))
        File.write!(Path.join([app_dir, "config", "config.exs"]), "import Config\n#{config_line}\n")
      end

      run_mix!("deps.get", [], app_dir)
      run_mix!("compile", [], app_dir)

      Path.join([app_dir, "_build", "dev", "lib", "typedstruct", "ebin", "Elixir.Inspect.Tuple.beam"])
      |> File.exists?()
    after
      File.rm_rf!(tmp_dir)
    end
  end

  defp run_mix!(task, args, cwd) do
    {output, status} = System.cmd("mix", [task | args],
        cd: cwd,
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "dev"}]
      )

    assert status == 0,
           "mix #{task} #{Enum.join(args, " ")} failed in #{cwd} with exit #{status}:\n#{output}"
  end
end
