defmodule Mediate.FreezeTest do
  @moduledoc """
  The frozen lists. A change here follows a change to `docs/design.md` or
  `docs/conformance.md`, in the same commit.
  """

  use ExUnit.Case, async: true

  alias Mediate.Conformance.Law
  alias Mediate.Conformance.RepoCase

  @moduletag :freeze

  @conformance Path.expand("../../../../docs/conformance.md", __DIR__)

  test "Mediate.Adapter has the frozen callbacks" do
    assert Enum.sort(Mediate.Adapter.behaviour_info(:callbacks)) ==
             Enum.sort(
               decide: 5,
               scope: 5,
               around_query: 3,
               options_schema: 0,
               scope_cap: 0,
               settle: 0
             )

    assert Enum.sort(Mediate.Adapter.behaviour_info(:optional_callbacks)) ==
             Enum.sort(around_query: 3, options_schema: 0, settle: 0)
  end

  test "the structs have the frozen fields" do
    assert fields(Mediate.Answer) == ~w(meta reason verdict version)a
    assert fields(Mediate.Exemption) == ~w(caller kind on reason)a

    assert fields(Mediate.Decision) ==
             ~w(adapter at id object operation operation_id policy_version reason subject verdict)a

    assert fields(Mediate.Config) == ~w(adapter caps clock)a
  end

  test "the subject kinds and the reason lists are the frozen lists" do
    assert Mediate.Port.subject_kinds() == [:user, :non_person_entity, :privileged]

    assert Mediate.Answer.reasons() ==
             ~w(allowed deny_by_default rule_denied engine_unreachable missing_fact unknown_operation
                unknown_subject_kind)a

    assert Mediate.Error.reasons() ==
             ~w(deny_by_default rule_denied engine_unreachable missing_fact unknown_operation unknown_subject_kind
                unsupported invalid unmediated)a
  end

  test "the law table equals docs/conformance.md §2" do
    assert Law.all() == Enum.map(rows("\n## 2. The laws"), &law/1)
  end

  test "the guarantee table equals docs/conformance.md §5" do
    assert RepoCase.guarantees() == Enum.map(rows("\n## 5. The repo case"), &guarantee/1)
  end

  defp fields(module) do
    module.__struct__()
    |> Map.keys()
    |> List.delete(:__struct__)
    |> Enum.sort()
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
