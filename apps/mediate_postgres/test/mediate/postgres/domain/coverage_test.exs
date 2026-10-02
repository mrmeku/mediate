defmodule Mediate.Postgres.Domain.CoverageTest do
  use ExUnit.Case, async: true

  alias Mediate.Postgres.Binding
  alias Mediate.Postgres.Domain.Coverage
  alias Mediate.Postgres.Probe.Folder
  alias Mediate.Postgres.Probe.Item
  alias Mediate.Postgres.Probe.Shelf
  alias Mediate.TestRepos.Sandboxed

  test "a covered relation declares the key of the schema that holds it, and one covered through another declares none" do
    {:ok, binding} = Binding.new(repo: Sandboxed, schemas: [Shelf, Folder, Item])

    reads = [
      {"mediate_probe_folders", "shelf_id"},
      {"mediate_probe_items", "folder_id"}
    ]

    assert Coverage.undeclared(binding, reads) == [{Item, "folder_id"}]
    assert Coverage.describe([{Item, "folder_id"}]) == "folder_id of #{inspect(Item)}"
  end

  test "a read of a table no bound schema owns is a table finding" do
    {:ok, binding} = Binding.new(repo: Sandboxed, schemas: [Item])

    assert Coverage.undeclared(binding, [{"pg_class", "oid"}]) == [{:table, "pg_class"}]
    assert Coverage.describe([{:table, "pg_class"}]) == "table pg_class"
  end
end
