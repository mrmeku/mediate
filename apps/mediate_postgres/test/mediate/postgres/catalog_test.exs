defmodule Mediate.Postgres.CatalogTest do
  use ExUnit.Case, async: true

  alias Ecto.Adapters.SQL.Sandbox
  alias Mediate.Error
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Item
  alias Mediate.Postgres.Binding
  alias Mediate.Postgres.Catalog
  alias Mediate.Postgres.Conformance.Reference
  alias Mediate.Postgres.Probe
  alias Mediate.Postgres.Rule
  alias Mediate.TestRepos.Sandboxed

  setup do
    Sandbox.checkout(Sandboxed)
  end

  test "the catalog is the policy version, the rules of the bound tables, and the columns they read" do
    assert {:ok, catalog} = Catalog.read(binding!())

    assert catalog.policy_version == to_string(Reference.version())
    assert {"mediate_fixture_folders", "id"} in catalog.reads
    assert {"mediate_fixture_memberships", "role"} in catalog.reads

    written =
      catalog.rules
      |> Enum.map(& &1.name)
      |> Enum.uniq()
      |> Enum.sort()

    assert written == names()
  end

  test "a filter rule and a gate rule are found by the action they were written for" do
    {:ok, catalog} = Catalog.read(binding!())

    assert %Rule{command: :select, using: using} = Catalog.filter_rule(catalog, "mediate_fixture_folders", :read)
    assert using =~ "'read'::text"
    assert %Rule{command: :update} = Catalog.gate_rule(catalog, "mediate_fixture_folders", :edit)
    assert Catalog.gate_rule(catalog, "mediate_fixture_items", :edit) == nil
    assert Catalog.filter_rule(catalog, "mediate_fixture_folders", :publish) == nil
  end

  test "resolve answers the kept catalog, and loads on first use for a caller that did not" do
    binding = binding!()

    assert {:ok, %Catalog{} = loaded} = Catalog.resolve(binding)
    assert Catalog.resolve(binding) == {:ok, loaded}
    assert Catalog.load!(binding) == loaded
  end

  test "a migration source that holds no version is an invalid catalog, and the message says what to run" do
    binding = binding!(migration_source: Probe.empty_migrations())

    assert {:error, %Error{reason: :invalid, message: "invalid catalog: " <> message}} = Catalog.read(binding)

    assert message ==
             "#{Probe.empty_migrations()} holds no migration version; run the migrations before " <>
               "Mediate.Postgres.load_catalog/0"

    assert_raise Error, fn -> Catalog.load!(binding) end
  end

  test "a statement the driver refuses is an engine failure carrying the driver's text" do
    assert {:error, %Error{reason: :engine_failed, message: "catalog read failed: " <> text}} =
             Catalog.read(binding!(migration_source: "mediate_no_such_table"))

    assert text =~ "mediate_no_such_table"
  end

  defp names do
    ~w(
      mediate_admit_delete
      mediate_admit_insert
      mediate_exempt_mediate_owner_select
      mediate_filter_edit
      mediate_filter_read
      mediate_gate_edit
    )
  end

  defp binding!(overrides \\ []) do
    {:ok, binding} = Binding.new(Keyword.merge([repo: Sandboxed, schemas: [Folder, Item]], overrides))
    binding
  end
end
