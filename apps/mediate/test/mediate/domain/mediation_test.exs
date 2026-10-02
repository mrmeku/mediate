defmodule Mediate.Domain.MediationTest do
  use ExUnit.Case, async: true

  alias Mediate.Decision
  alias Mediate.Domain.Mediation
  alias Mediate.Error
  alias Mediate.Exemption
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Item
  alias Mediate.Id
  alias Mediate.Test.Fake

  test "a refusal names the caller where the mediated repo could read one, and says nothing where it could not" do
    parts = fn caller -> [function: :all, arity: 2, schema: Folder, resource_type: nil, caller: caller] end

    assert %Error{reason: :decision_missing, message: named} = Mediation.decision_missing(parts.(__MODULE__))
    assert named =~ "(from #{inspect(__MODULE__)})"

    assert %Error{message: bare} = Mediation.decision_missing(parts.(:any))
    assert bare == "Repo.all/2 on #{inspect(Folder)} carries no decision and no exemption"
  end

  test "the option's schema is a NimbleOptions schema that admits a resolved mediation" do
    assert %NimbleOptions{} = Mediation.schema()
    assert {:ok, %Mediation{}} = Mediation.validate_option(Mediation.empty({:all, 2}))
  end

  test "related/2 follows a through association and answers nil for an unknown one" do
    assert Mediation.related(Folder, :items) == Item
    assert Mediation.related(Folder, :item_folders) == Folder
    assert Mediation.related(Folder, :missing) == nil
  end

  test "a decision covers the root and every schema its covered associations reach, a denial raises, and an exemption records its caller" do
    decision = decision(:folder, 1)

    assert %Mediation{decision: ^decision, covered: [Folder, Item]} = Mediation.decided({:all, 2}, Folder, decision)
    assert %Mediation{covered: [Item]} = Mediation.decided({:all, 2}, Item, decision(:item, 1))
    assert %Mediation{covered: []} = Mediation.decided({:all, 2}, "mediate_fixture_folders", decision)

    denial = %{decision | effect: :deny, reason: :no_rule_matched}
    assert_raise Error, fn -> Mediation.decided({:all, 2}, Folder, denial) end

    assert %Mediation{exemption: %Exemption{declared_by: :library, caller: __MODULE__, justification: "library"}} =
             Mediation.library({:all, 2}, Folder, __MODULE__)

    assert %Mediation{exemption: %Exemption{declared_by: :caller, caller: __MODULE__, justification: "a reason"}} =
             Mediation.declared({:all, 2}, Folder, __MODULE__, "a reason")
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
