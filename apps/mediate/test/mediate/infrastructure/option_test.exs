defmodule Mediate.Infrastructure.OptionTest do
  use ExUnit.Case, async: true

  alias Mediate.Decision
  alias Mediate.Domain.Mediation
  alias Mediate.Fixture.Folder
  alias Mediate.Id
  alias Mediate.Infrastructure.Option
  alias Mediate.Test.Fake
  alias Mediate.TestRepos.Sandboxed

  test "a decision on a table name carries nothing, and a resolved mediation is passed through" do
    decision = decision(:folder, 1)

    assert {%Mediation{covered: [], decision: ^decision}, opts} =
             Option.resolve(Sandboxed, {:all, 2}, "mediate_fixture_folders", authorized_by: decision)

    assert {%Mediation{call: {:one, 2}} = nested, nested_opts} = Option.resolve(Sandboxed, {:one, 2}, Folder, opts)
    assert nested_opts[:authorized_by] == nested
  end

  defp decision(type, id) do
    %Decision{
      id: Id.new(),
      subject: {:user, "user-1"},
      resource: {type, id},
      action: :read,
      effect: :allow,
      reason: :rule_allowed,
      engine: Fake,
      policy_version: nil,
      correlation_id: Id.new(),
      decided_at: DateTime.utc_now()
    }
  end
end
