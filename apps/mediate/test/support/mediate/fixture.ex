defmodule Mediate.Fixture do
  @moduledoc """
  A neutral set of schemas for the core package's own seam tests:

  - a folder that carries its items
  - an item that does not carry its folder back
  - a membership, a relationship grant with a role, an expiry, and the kind
    of subject that holds it
  - an account with one fact column

  They name no domain of any application.

  The folder, item, and membership schemas share this file because their
  associations refer to one another, and the dependency gate forbids a
  cycle between files.
  """

  use Boundary,
    top_level?: true,
    deps: [
      Ecto,
      ExUnitProperties,
      StreamData,
      Mediate,
      Mediate.Conformance,
      Mediate.Test,
      Mediate.Dev.Sandbox,
      Mediate.TestRepos
    ],
    exports: [Account, Folder, Item, Membership, Rows, World]
end

defmodule Mediate.Fixture.Item do
  @moduledoc "A protected object type inside a folder. It does not carry the folder back."

  use Ecto.Schema
  use Mediate.Schema

  alias Mediate.Fixture.Folder

  @type t :: %__MODULE__{}

  schema "mediate_fixture_items" do
    field(:title, :string)
    belongs_to(:folder, Folder)
  end

  object_type(:item)
end

defmodule Mediate.Fixture.Membership do
  @moduledoc """
  A relationship grant: an account holds a role on a folder, as a subject
  of one kind, until the grant expires. One membership per account and
  folder, which the table holds as a unique index. Unprotected as a query
  target.
  """

  use Ecto.Schema
  use Mediate.Schema

  alias Mediate.Fixture.Folder

  @type t :: %__MODULE__{}

  schema "mediate_fixture_memberships" do
    field(:account_id, :string)
    field(:role, Ecto.Enum, values: [:reader, :editor])
    field(:subject_kind, Ecto.Enum, values: [:user, :non_person_entity, :privileged], default: :user)
    field(:expires_at, :utc_datetime)
    belongs_to(:folder, Folder)
  end

  audited(:role)
  relationship(subject: :account_id, object: :folder_id, attributes: [:role, :subject_kind, :expires_at])
end

defmodule Mediate.Fixture.Folder do
  @moduledoc "A protected object type that carries its items."

  use Ecto.Schema
  use Mediate.Schema

  alias Mediate.Fixture.Item
  alias Mediate.Fixture.Membership

  @type t :: %__MODULE__{}

  schema "mediate_fixture_folders" do
    field(:name, :string)
    has_many(:items, Item)
    has_many(:memberships, Membership)
    has_many(:item_folders, through: [:items, :folder])
  end

  object_type(:folder)
  carries([:items])
end
