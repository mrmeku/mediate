defmodule Mediate.Fixture do
  @moduledoc """
  A neutral set of schemas for the core package's own mediated repo tests:

  - a folder that covers its items
  - an item that does not cover its folder back
  - a membership, a grant with a role, an expiry, and the kind of subject
    that holds it
  - an account with one fact column

  They name no domain of any application.

  The folder, item, and membership schemas share this file because their
  associations refer to one another, and the dependency gate forbids a
  cycle between files.
  """

  use Boundary, top_level?: true, deps: [Ecto, Mediate], exports: [Account, Folder, Item, Membership]
end

defmodule Mediate.Fixture.Item do
  @moduledoc "A protected resource type inside a folder. It does not cover the folder back."

  use Ecto.Schema
  use Mediate.Schema

  alias Mediate.Fixture.Folder

  @type t :: %__MODULE__{}

  schema "mediate_fixture_items" do
    field(:title, :string)
    belongs_to(:folder, Folder)
  end

  resource_type(:item)
end

defmodule Mediate.Fixture.Membership do
  @moduledoc """
  A grant: an account holds a role on a folder, as a subject of one kind,
  until the grant expires. One membership per account and folder, which
  the table holds as a unique index. Unprotected as a query target.
  """

  use Ecto.Schema
  use Mediate.Schema

  alias Mediate.Fixture.Folder

  @type t :: %__MODULE__{}

  schema "mediate_fixture_memberships" do
    field(:account_id, :string)
    field(:role, Ecto.Enum, values: [:reader, :editor])
    field(:subject_kind, Ecto.Enum, values: [:user, :service, :privileged], default: :user)
    field(:expires_at, :utc_datetime)
    belongs_to(:folder, Folder)
  end

  identity(:role)
  grant(subject: :account_id, resource: :folder_id, attributes: [:role, :subject_kind, :expires_at])
end

defmodule Mediate.Fixture.Folder do
  @moduledoc "A protected resource type that covers its items."

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

  resource_type(:folder)
  covers([:items])
end
