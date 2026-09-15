defmodule Mediate.Postgres.CatalogTest do
  use ExUnit.Case, async: true

  alias Ecto.Adapters.SQL.Sandbox
  alias Mediate.Error
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Item
  alias Mediate.Postgres.Binding
  alias Mediate.Postgres.Catalog
  alias Mediate.Postgres.Conformance.Rules
  alias Mediate.Postgres.Policy
  alias Mediate.Postgres.Probe
  alias Mediate.TestRepos.Sandboxed

  setup do
    Sandbox.checkout(Sandboxed)
  end

  test "the catalog is the version, the policies of the bound tables, and the columns they read" do
    catalog = Catalog.read!(binding!())

    assert catalog.version == to_string(Rules.version())
    assert {"mediate_fixture_folders", "id"} in catalog.columns
    assert {"mediate_fixture_memberships", "role"} in catalog.columns

    written =
      catalog.policies
      |> Enum.map(& &1.name)
      |> Enum.uniq()
      |> Enum.sort()

    assert written == names()
  end

  test "a scope policy and a gate policy are found by the operation they were written for" do
    catalog = Catalog.read!(binding!())

    assert %Policy{command: :select, using: using} = Catalog.scope(catalog, "mediate_fixture_folders", :read)
    assert using =~ "'read'::text"
    assert %Policy{command: :update} = Catalog.gate(catalog, "mediate_fixture_folders", :edit)
    assert Catalog.gate(catalog, "mediate_fixture_items", :edit) == nil
    assert Catalog.scope(catalog, "mediate_fixture_folders", :publish) == nil
  end

  test "the text a version carries names the table, the policy, the command, and both expressions" do
    catalog = Catalog.read!(binding!())
    text = Catalog.to_text(catalog.policies)

    assert text =~ "mediate_fixture_folders mediate_gate_edit update\n"
    assert text =~ "  WITH CHECK -\n"
  end

  test "a migrations table that holds no version is an invalid catalog" do
    binding = binding!(migrations_table: Probe.empty_versions())

    assert %Error{reason: :invalid, detail: "invalid catalog: " <> detail} = catch_error(Catalog.read!(binding))
    assert detail == "#{Probe.empty_versions()} holds no migration version"
  end

  defp names do
    ~w(
      mediate_admit_delete
      mediate_admit_insert
      mediate_exempt_mediate_owner_select
      mediate_gate_edit
      mediate_scope_edit
      mediate_scope_read
    )
  end

  defp binding!(overrides \\ []) do
    {:ok, binding} = Binding.new(Keyword.merge([repo: Sandboxed, schemas: [Folder, Item]], overrides))
    binding
  end
end
