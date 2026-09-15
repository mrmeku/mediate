defmodule Mediate.Postgres.Domain.DeclaredTest do
  use ExUnit.Case, async: true

  alias Mediate.Postgres.Binding
  alias Mediate.Postgres.Carried.Folder
  alias Mediate.Postgres.Carried.Item
  alias Mediate.Postgres.Carried.Shelf
  alias Mediate.Postgres.Domain.Declared
  alias Mediate.TestRepos.Sandboxed

  test "a carried relation declares the key of the schema that holds it, and one carried through another declares none" do
    {:ok, binding} = Binding.new(repo: Sandboxed, schemas: [Shelf, Folder, Item])

    columns = [
      {"mediate_carried_folders", "shelf_id"},
      {"mediate_carried_items", "folder_id"}
    ]

    assert Declared.findings(binding, columns) == [{Item, "folder_id"}]
    assert Declared.describe([{Item, "folder_id"}]) == "folder_id of #{inspect(Item)}"
  end
end
