defmodule Mediate.FreezeTest do
  @moduledoc """
  The frozen lists of the port. The law and guarantee tables are frozen
  against `docs/conformance.md` by the freeze test of `mediate_conformance`.
  """

  use ExUnit.Case, async: true

  @moduletag :freeze

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

  defp fields(module) do
    module.__struct__()
    |> Map.keys()
    |> List.delete(:__struct__)
    |> Enum.sort()
  end
end
