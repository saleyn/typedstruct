defmodule TypedStruct.Integration.UmbrellaChildDepsCompileTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  test "mix deps.compile succeeds from umbrella child app directory" do
    typedstruct_path = Path.expand("../..", __DIR__)
    tmp_dir = Path.join(System.tmp_dir!(), "typedstruct-issue-15-#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    try do
      run_mix!("new", ["demo_umbrella", "--umbrella"], tmp_dir)

      apps_dir = Path.join([tmp_dir, "demo_umbrella", "apps"])
      run_mix!("new", ["child_app"], apps_dir)

      child_dir = Path.join(apps_dir, "child_app")
      child_mix_exs = Path.join(child_dir, "mix.exs")

      child_mix_exs
      |> File.read!()
      |> String.replace(
        "# {:dep_from_hexpm, \"~> 0.3.0\"},",
        "{:typedstruct, path: \"#{typedstruct_path}\"},"
      )
      |> then(&File.write!(child_mix_exs, &1))

      umbrella_dir = Path.join(tmp_dir, "demo_umbrella")
      run_mix!("deps.get", [], umbrella_dir)
      run_mix!("deps.compile", [], child_dir)
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
