defmodule Mediate.Postgres.FactsTest do
  use ExUnit.Case, async: true

  alias Ecto.Adapters.SQL.Sandbox
  alias Mediate.Fixture.Account
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Item
  alias Mediate.Fixture.Membership
  alias Mediate.Postgres.Binding
  alias Mediate.Postgres.Facts
  alias Mediate.Postgres.Probe
  alias Mediate.TestRepos.Sandboxed

  setup do
    Sandbox.checkout(Sandboxed)
  end

  test "every column the conformance rules read is a declared fact" do
    binding = binding!([Account, Folder, Item, Membership])
    assert Facts.check(binding) == :ok
    assert Facts.check!(binding) == :ok
  end

  test "a rule that reads an undeclared column fails with the column's name and the fix" do
    binding = binding!([Probe.Row])

    assert {:error, findings} = Facts.check(binding)
    assert {Probe.Row, "label"} in findings

    message =
      ~r/the policies on mediate_probe_rows read undeclared columns: .*label of Mediate.Postgres.Probe.Row.*; declare/

    assert_raise ArgumentError, message, fn -> Facts.check!(binding) end
  end

  test "a rule that reads a table no bound schema owns fails as that table" do
    assert {:table, "mediate_fixture_accounts"} in Facts.undeclared(binding!([Probe.Row]))
  end

  test "the foreign key of a covered relation is declared on the schema that holds it" do
    assert {Item, "folder_id"} in Facts.undeclared(binding!([Item]))
    refute {Item, "folder_id"} in Facts.undeclared(binding!([Folder, Item]))
  end

  test "a catalog the check cannot read raises the read's error" do
    assert_raise Mediate.Error, fn -> Facts.undeclared(binding!([Folder], migration_source: "mediate_no_such_table")) end
  end

  defp binding!(schemas, overrides \\ []) do
    {:ok, binding} = Binding.new(Keyword.merge([repo: Sandboxed, schemas: schemas], overrides))
    binding
  end
end
