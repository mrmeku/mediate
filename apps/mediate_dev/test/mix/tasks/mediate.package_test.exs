defmodule Mix.Tasks.Mediate.PackageTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Mediate.Package

  test "it takes --check or no argument" do
    assert_raise Mix.Error, ~r/takes --check or no argument/, fn -> Package.run(["--all"]) end
    assert_raise Mix.Error, ~r/takes --check or no argument/, fn -> Package.run(["--check", "mediate"]) end
  end

  test "it runs at the umbrella root" do
    assert_raise Mix.Error, ~r/runs at the umbrella root/, fn -> Package.run([]) end
  end
end
