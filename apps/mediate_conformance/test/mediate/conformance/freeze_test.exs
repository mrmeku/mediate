defmodule Mediate.Conformance.FreezeTest do
  @moduledoc """
  The frozen tables. A change here follows a change to `docs/conformance.md`
  under "The laws" or "The guarantees", in the same commit.
  """

  use ExUnit.Case, async: true

  alias Mediate.Conformance.Law
  alias Mediate.Conformance.RepoCase

  @moduletag :freeze

  @conformance Path.expand("../../../../../docs/conformance.md", __DIR__)

  test "the law table equals docs/conformance.md under The laws" do
    assert Law.all() == Enum.map(rows("\n## The laws"), &law/1)
  end

  test "the guarantee table equals docs/conformance.md under The guarantees" do
    assert RepoCase.guarantees() == Enum.map(rows("\n## The guarantees"), &guarantee/1)
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

  defp law([id, sentence, controls]) do
    %Law{id: String.trim(id, "`"), sentence: sentence, controls: String.split(controls, ", ")}
  end

  defp guarantee([id, sentence]), do: {String.trim(id, "`"), sentence}

  defp cells(line) do
    line
    |> String.split("|")
    |> Enum.drop(1)
    |> Enum.drop(-1)
    |> Enum.map(&String.trim/1)
  end
end
