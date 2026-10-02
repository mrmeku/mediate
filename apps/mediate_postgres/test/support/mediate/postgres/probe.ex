defmodule Mediate.Postgres.Probe do
  @moduledoc """
  Tables and schemas of its own for the cases the reference world cannot
  carry. One table has a rule that reads a column no declaration names,
  and a rule that reads a table no bound schema owns. One has the shape
  of a migration source and holds no version. Either rule on a world
  table widens what the world's own scenarios read. So the probe keeps
  its own tables, and the world's stay as the conformance migration wrote
  them.

  Three schemas hold the two shapes of covered relation the world does
  not: one covered through another relation, so it has a foreign key
  nowhere, and one whose key is on the schema that covers it. The fact
  check reads the declarations alone, so those three have no tables.
  """

  use Boundary, top_level?: true, deps: [Ecto, Mediate, Mediate.Postgres], exports: [Folder, Item, Row, Shelf]

  alias Mediate.Postgres.Migration

  @table "mediate_probe_rows"
  @migrations "mediate_probe_migrations"
  @undeclared "current_setting('mediate.probe', true) = label"
  @unbound """
  EXISTS (SELECT 1 FROM mediate_fixture_accounts a
          WHERE a.id = current_setting('mediate.probe', true))
  """

  @doc "The table shaped like a migration source that holds no version, because no migration ever ran against it."
  @spec empty_migrations() :: String.t()
  def empty_migrations, do: @migrations

  @doc "Creates the tables and the rules, through an owner-role repo."
  @spec create!(module()) :: :ok
  def create!(repo) when is_atom(repo) do
    _rows = repo.query!("CREATE TABLE #{@table} (id bigserial PRIMARY KEY, label text)")
    _migrations = repo.query!("CREATE TABLE #{@migrations} (version bigint PRIMARY KEY)")
    :ok = Migration.privileges!(repo, table: @migrations, to: "mediate_app", commands: [:select])
    :ok = Migration.protect!(repo, @table)
    :ok = Migration.filter!(repo, table: @table, action: :read, using: @undeclared)
    :ok = Migration.filter!(repo, table: @table, action: :sighted, using: @unbound)
    Migration.privileges!(repo, table: @table, to: "mediate_app", commands: [:select])
  end
end

defmodule Mediate.Postgres.Probe.Row do
  @moduledoc "The probe's row: a primary key it declares and a label it does not."

  use Ecto.Schema
  use Mediate.Schema

  @type t :: %__MODULE__{}

  schema "mediate_probe_rows" do
    field(:label, :string)
  end

  resource_type(:probe_row)
end

defmodule Mediate.Postgres.Probe.Item do
  @moduledoc "A row a folder holds, whose folder no declaration covers."

  use Ecto.Schema
  use Mediate.Schema

  @type t :: %__MODULE__{}

  schema "mediate_probe_items" do
    belongs_to(:folder, Mediate.Postgres.Probe.Folder)
  end

  resource_type(:probe_item)
end

defmodule Mediate.Postgres.Probe.Folder do
  @moduledoc "A folder that covers the shelf it belongs to, whose key it holds itself."

  use Ecto.Schema
  use Mediate.Schema

  alias Mediate.Postgres.Probe.Item
  alias Mediate.Postgres.Probe.Shelf

  @type t :: %__MODULE__{}

  schema "mediate_probe_folders" do
    belongs_to(:shelf, Shelf)
    has_many(:items, Item)
  end

  resource_type(:probe_folder)
  covers([:shelf])
end

defmodule Mediate.Postgres.Probe.Shelf do
  @moduledoc "A shelf that covers its folders and, through them, their items."

  use Ecto.Schema
  use Mediate.Schema

  alias Mediate.Postgres.Probe.Folder

  @type t :: %__MODULE__{}

  schema "mediate_probe_shelves" do
    has_many(:folders, Folder)
    has_many(:shelf_items, through: [:folders, :items])
  end

  resource_type(:probe_shelf)
  covers([:folders, :shelf_items])
end
