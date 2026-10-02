defmodule Mediate.Conformance.FreezeTest do
  @moduledoc """
  The frozen tables. A change here follows a change to `docs/conformance.md`
  under "The engine requirements" or "The repo requirements", in the same
  commit.
  """

  use ExUnit.Case, async: true

  alias Mediate.Conformance.Requirement

  @moduletag :freeze

  @conformance Path.expand("../../../../../docs/conformance.md", __DIR__)

  test "the engine table equals docs/conformance.md under The engine requirements" do
    assert Requirement.all(:engine) == Enum.map(rows("\n## The engine requirements"), &requirement/1)
  end

  test "the repo table equals docs/conformance.md under The repo requirements" do
    assert Requirement.all(:repo) == Enum.map(rows("\n## The repo requirements"), &requirement/1)
  end

  # The table rows of one section, each as its cells.
  defp rows(heading) do
    @conformance
    |> File.read!()
    |> String.split(heading)
    |> Enum.at(1)
    |> String.split("\n## ")
    |> hd()
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "| `"))
    |> Enum.map(&cells/1)
  end

  defp requirement([id, text, controls]) do
    %Requirement{id: String.trim(id, "`"), text: text, controls: String.split(controls, ", ")}
  end

  defp cells(line) do
    line
    |> String.split("|")
    |> Enum.drop(1)
    |> Enum.drop(-1)
    |> Enum.map(&String.trim/1)
  end
end
