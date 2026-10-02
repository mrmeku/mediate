defmodule Mediate.FreezeTest do
  @moduledoc """
  The frozen lists of the library. The law and guarantee tables are frozen
  against `docs/conformance.md` by the freeze test of `mediate_conformance`.
  """

  use ExUnit.Case, async: true

  @moduletag :freeze

  test "Mediate.Engine has the frozen callbacks" do
    assert Enum.sort(Mediate.Engine.behaviour_info(:callbacks)) ==
             Enum.sort(
               authorize: 5,
               filter: 5,
               around_query: 3,
               options_schema: 0,
               filter_limit: 0,
               sync: 0
             )

    assert Enum.sort(Mediate.Engine.behaviour_info(:optional_callbacks)) ==
             Enum.sort(around_query: 3, options_schema: 0, sync: 0)
  end

  test "the structs have the frozen fields" do
    assert fields(Mediate.Verdict) == ~w(effect meta policy_version reason)a
    assert fields(Mediate.Exemption) == ~w(caller declared_by justification source)a

    assert fields(Mediate.Decision) ==
             ~w(action correlation_id decided_at effect engine id policy_version reason resource subject)a

    assert fields(Mediate.PolicyRelease) ==
             ~w(approval author engine policy_version released_at text text_hash text_location)a

    assert fields(Mediate.Config) == ~w(caps clock engine)a
  end

  test "the subject kinds, the effects, and the reason lists are the frozen lists" do
    assert Mediate.subject_kinds() == [:user, :service, :privileged]
    assert Mediate.Decision.effects() == [:allow, :deny, :filter]

    assert Mediate.Verdict.reasons() ==
             ~w(rule_allowed no_rule_matched rule_denied engine_failed fact_missing action_unknown
                subject_kind_unknown)a

    assert Mediate.Error.reasons() ==
             ~w(no_rule_matched rule_denied engine_failed fact_missing action_unknown subject_kind_unknown
                unsupported invalid decision_missing)a
  end

  defp fields(module) do
    module.__struct__()
    |> Map.keys()
    |> List.delete(:__struct__)
    |> Enum.sort()
  end
end
