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

    assert {%Mediation{carried: [], decision: ^decision}, opts} =
             Option.resolve(Sandboxed, {:all, 2}, "mediate_fixture_folders", mediate: decision)

    assert {%Mediation{call: {:one, 2}} = nested, nested_opts} = Option.resolve(Sandboxed, {:one, 2}, Folder, opts)
    assert nested_opts[:mediate] == nested
  end

  defp decision(type, id) do
    %Decision{
      id: Id.new(),
      subject: {:user, "user-1"},
      object: {type, id},
      operation: :read,
      verdict: :allow,
      reason: :allowed,
      adapter: Fake,
      policy_version: nil,
      operation_id: Id.new(),
      at: DateTime.utc_now()
    }
  end
end
