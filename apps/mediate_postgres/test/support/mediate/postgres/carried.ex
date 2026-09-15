defmodule Mediate.Postgres.Carried do
  @moduledoc """
  Schemas for the two shapes of carried relation the fixture does not hold.
  One goes through another relation, so it has a foreign key nowhere. One
  has its key on the schema that carries it. The coverage check reads the
  declarations alone, so these schemas need no tables and no policies.
  """

  use Boundary, top_level?: true, deps: [Ecto, Mediate], exports: [Folder, Item, Shelf]
end

defmodule Mediate.Postgres.Carried.Item do
  @moduledoc "A row a folder holds, whose folder no declaration carries."

  use Ecto.Schema
  use Mediate.Schema

  @type t :: %__MODULE__{}

  schema "mediate_carried_items" do
    belongs_to(:folder, Mediate.Postgres.Carried.Folder)
  end

  object_type(:carried_item)
end

defmodule Mediate.Postgres.Carried.Folder do
  @moduledoc "A folder that carries the shelf it belongs to, whose key it holds itself."

  use Ecto.Schema
  use Mediate.Schema

  alias Mediate.Postgres.Carried.Item
  alias Mediate.Postgres.Carried.Shelf

  @type t :: %__MODULE__{}

  schema "mediate_carried_folders" do
    belongs_to(:shelf, Shelf)
    has_many(:items, Item)
  end

  object_type(:carried_folder)
  carries([:shelf])
end

defmodule Mediate.Postgres.Carried.Shelf do
  @moduledoc "A shelf that carries its folders and, through them, their items."

  use Ecto.Schema
  use Mediate.Schema

  alias Mediate.Postgres.Carried.Folder

  @type t :: %__MODULE__{}

  schema "mediate_carried_shelves" do
    has_many(:folders, Folder)
    has_many(:shelf_items, through: [:folders, :items])
  end

  object_type(:carried_shelf)
  carries([:folders, :shelf_items])
end
