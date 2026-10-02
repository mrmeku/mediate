defmodule Mediate.OpenFGA.Conformance.ReferenceTest do
  use Mediate.OpenFGA.MappingCase,
    async: true,
    mapping: Mediate.OpenFGA.Conformance.Reference,
    repo: Mediate.TestRepos.Sandboxed,
    population: Mediate.OpenFGA.Conformance.Population,
    setup: Mediate.OpenFGA.Conformance.Setup

  alias Mediate.Fixture.Item
  alias Mediate.OpenFGA.Condition
  alias Mediate.OpenFGA.Conformance.Reference
  alias Mediate.OpenFGA.TupleKey
  alias Mediate.TestRepos.Sandboxed

  @cleared %Condition{
    name: "grant_holds",
    context: %{"clearance" => "cleared", "kind" => "user", "expires_at" => "9999-12-31T23:59:59Z"}
  }
  @exemption {:exempt, "reference test"}

  test "a role on a folder is the account holding it, under the condition its clearance, kind, and expiry carry" do
    tuples = Reference.tuples(Sandboxed, "folder:1")

    assert %TupleKey{user: "user:acct-a", relation: "editor", object: "folder:1", condition: @cleared} in tuples
    assert %TupleKey{user: "user:acct-b", relation: "reader", object: "folder:1", condition: @cleared} in tuples
    assert length(tuples) == 2
  end

  test "a membership with an expiry and a kind carries both on its condition" do
    condition = Reference.condition("cleared", :privileged, ~U[2999-01-01 00:00:00Z])

    assert condition.context == %{
             "clearance" => "cleared",
             "kind" => "privileged",
             "expires_at" => "2999-01-01T00:00:00Z"
           }
  end

  test "a membership whose account has no clearance states no tuple" do
    tuples = Reference.tuples(Sandboxed, "folder:2")

    assert Enum.map(tuples, & &1.user) == ["user:acct-a"]
  end

  test "a clearance is an object of its own, which every account of that clearance holds member on" do
    tuples = Reference.tuples(Sandboxed, "clearance:cleared")

    assert Enum.map(tuples, & &1.user) == ["user:acct-a", "user:acct-b"]
    assert Enum.all?(tuples, &(&1.relation == "member" and &1.condition == nil))
  end

  test "a folder with no membership on it is an object of its type and requires nothing" do
    assert "folder:3" in Reference.objects(Sandboxed, "folder")
    assert Reference.tuples(Sandboxed, "folder:3") == []
  end

  test "an item is an object of its type whose one tuple names the folder it is in" do
    _item = Sandboxed.insert!(%Item{id: 7, title: "item 7", folder_id: 1}, authorized_by: @exemption)

    assert "item:7" in Reference.objects(Sandboxed, "item")
    assert Reference.tuples(Sandboxed, "item:7") == [%TupleKey{user: "folder:1", relation: "folder", object: "item:7"}]
    assert Reference.affected(Sandboxed, %{schema: Item, resource: {:item, 7}, changes: %{}}) == ["item:7"]
  end
end
