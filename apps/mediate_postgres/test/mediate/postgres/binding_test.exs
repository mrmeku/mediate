defmodule Mediate.Postgres.BindingTest do
  use ExUnit.Case, async: true

  alias Mediate.Error
  alias Mediate.Fixture.Account
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Item
  alias Mediate.Fixture.Membership
  alias Mediate.Postgres.Binding
  alias Mediate.TestRepos.Sandboxed

  defmodule Undeclared do
    @moduledoc false
    use Ecto.Schema

    schema "mediate_binding_test_rows" do
      field(:name, :string)
    end
  end

  test "the binding names the repo, the schemas, and the migration source the version is read from" do
    assert {:ok, binding} = Binding.new(repo: Sandboxed, schemas: [Folder])
    assert {binding.repo, binding.schemas, binding.migration_source} == {Sandboxed, [Folder], "schema_migrations"}
  end

  test "a schema that did not use Mediate.Schema is refused by name, with the fix" do
    assert {:error, %Error{reason: :invalid, message: "invalid binding: schemas: " <> rest}} =
             Binding.new(repo: Sandboxed, schemas: [Folder, Undeclared])

    assert rest =~ "Undeclared did not use Mediate.Schema; add use Mediate.Schema"
  end

  test "a missing repo is refused" do
    assert {:error, %Error{reason: :invalid, message: "invalid binding: " <> _rest}} = Binding.new(schemas: [Folder])
  end

  test "an override is read from the calling process and from its callers" do
    :ok = Binding.override(repo: Sandboxed, schemas: [Folder, Item])
    assert {:ok, binding} = Binding.resolve()
    assert Binding.tables(binding) == ["mediate_fixture_folders", "mediate_fixture_items"]

    task = Task.async(fn -> Binding.resolve() end)
    assert {:ok, ^binding} = Task.await(task)
  end

  test "an override around a function is put back afterwards" do
    :ok = Binding.override(repo: Sandboxed, schemas: [Folder])

    inner = Binding.override([schemas: [Item]], fn -> Binding.resolve() end)
    assert {:ok, %Binding{schemas: [Item]}} = inner
    assert {:ok, %Binding{schemas: [Folder]}} = Binding.resolve()
  end

  test "with nothing bound and no override, resolve says so and names the call that binds" do
    assert {:error, %Error{reason: :invalid, message: message}} = Binding.resolve()
    assert message == "invalid binding: nothing bound and no override; call Mediate.Postgres.Binding.bind!/1 at boot"
  end

  test "a resource type resolves to its table and primary key, and an unknown one to nothing" do
    assert {:ok, binding} = Binding.new(repo: Sandboxed, schemas: [Folder, Item, Membership, Account])
    assert Binding.table_of(binding, :folder) == {"mediate_fixture_folders", :id}
    assert Binding.table_of(binding, :item) == {"mediate_fixture_items", :id}
    assert Binding.table_of(binding, :document) == nil
  end

  test "the binding round-trips through the keyword list its schema validates" do
    assert %NimbleOptions{} = Binding.options_schema()
    assert {:ok, binding} = Binding.new(repo: Sandboxed, schemas: [Folder])

    assert Binding.to_keyword(binding) == [repo: Sandboxed, schemas: [Folder], migration_source: "schema_migrations"]
    assert Binding.new(Binding.to_keyword(binding)) == {:ok, binding}
  end

  test "a table resolves back to the schema whose declarations cover it" do
    assert {:ok, binding} = Binding.new(repo: Sandboxed, schemas: [Folder, Membership])
    assert Binding.schema_of(binding, "mediate_fixture_memberships") == Membership
    assert Binding.schema_of(binding, "pg_class") == nil
  end
end
