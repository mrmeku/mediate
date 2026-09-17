defmodule Example.Domain.Repository do
  @moduledoc """
  A hosted repository, not an Ecto repo. A project holds it, a team owns
  it, a visibility marks it, and a date lifts its embargo or no date does.
  It carries its project, its owning team, its visibility, and its
  proposals, because a repository decision admits queries on them. It does
  not carry its directories, which have an object type and decisions of
  their own.

  The repository, the visibility, the directory, and the proposal share
  this file because their associations refer to one another.
  """

  use Ecto.Schema
  use Mediate.Schema

  alias Example.Domain.Directory
  alias Example.Domain.Project
  alias Example.Domain.Proposal
  alias Example.Domain.Team
  alias Example.Domain.Visibility

  @type t :: %__MODULE__{}

  schema "repositories" do
    field(:name, :string)
    field(:embargo, :utc_datetime)
    belongs_to(:project, Project)
    belongs_to(:owning_team, Team)
    has_one(:visibility, Visibility)
    has_many(:directories, Directory)
    has_many(:proposals, Proposal)
  end

  object_type(:repository)
  carries([:project, :owning_team, :visibility, :proposals])
  audited(:entity)
  fact(:embargo, kind: :object_attribute, object: :id)
  fact(:project_id, kind: :object_attribute, object: :id)
  fact(:owning_team_id, kind: :object_attribute, object: :id)
end

defmodule Example.Domain.Visibility do
  @moduledoc """
  The restrictions that stand on a repository, which is not the public or
  private setting a code host shows: labels, restrictions, the countries
  REGIONS releases to, and the accounts INVITE ONLY admits. Each set emits
  one fact event per element. The invited accounts are a relationship whose
  subjects are its elements.
  """

  use Ecto.Schema
  use Mediate.Schema

  alias Example.Domain.Repository
  alias Example.Domain.Restrictions

  @type t :: %__MODULE__{}

  schema "visibilities" do
    field(:labels, {:array, :string}, default: [])
    field(:restrictions, {:array, Ecto.Enum}, values: Restrictions.all(), default: [])
    field(:releasable_to, {:array, :string}, default: [])
    field(:invited, {:array, :string}, default: [])
    belongs_to(:repository, Repository)
  end

  @doc "The visibility fields, cast and validated. The invited accounts are a set."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = visibility, attrs) when is_map(attrs) do
    visibility
    |> Ecto.Changeset.cast(attrs, [:labels, :restrictions, :releasable_to, :invited])
    |> Ecto.Changeset.update_change(:invited, &Enum.sort(Enum.uniq(&1)))
  end

  object_type(:visibility)
  audited(:entity)
  fact(:labels, kind: :object_attribute, object: :repository_id, element: :label)
  fact(:restrictions, kind: :object_attribute, object: :repository_id, element: :restriction)
  fact(:releasable_to, kind: :object_attribute, object: :repository_id, element: :country)
  fact(:invited, kind: :relationship, object: :repository_id, element: :user)
end

defmodule Example.Domain.Directory do
  @moduledoc """
  A directory of a repository with a visibility of its own. The
  repository's rollup combines the directories' visibilities and admits no
  subject any of them denies. It carries its repository, which the rules
  reach it through.
  """

  use Ecto.Schema
  use Mediate.Schema

  alias Example.Domain.Repository
  alias Example.Domain.Restrictions

  @type t :: %__MODULE__{}

  schema "directories" do
    field(:name, :string)
    field(:contents, :string)
    field(:labels, {:array, :string}, default: [])
    field(:restrictions, {:array, Ecto.Enum}, values: Restrictions.all(), default: [])
    field(:releasable_to, {:array, :string}, default: [])
    belongs_to(:repository, Repository)
  end

  @doc "The directory's visibility fields, cast."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = directory, attrs) when is_map(attrs) do
    Ecto.Changeset.cast(directory, attrs, [:labels, :restrictions, :releasable_to])
  end

  object_type(:directory)
  carries([:repository])
  audited(:entity)
  fact(:repository_id, kind: :object_attribute, object: :id)
  fact(:labels, kind: :object_attribute, object: :id, element: :label)
  fact(:restrictions, kind: :object_attribute, object: :id, element: :restriction)
  fact(:releasable_to, kind: :object_attribute, object: :id, element: :country)
end

defmodule Example.Domain.Proposal do
  @moduledoc """
  A visibility change that one admin proposes and a different reviewer
  approves. The proposal carries its repository, so the approval decision
  admits the visibility it applies.
  """

  use Ecto.Schema
  use Mediate.Schema

  alias Example.Domain.Repository
  alias Example.Domain.Restrictions

  @type t :: %__MODULE__{}

  schema "visibility_proposals" do
    field(:proposer_id, :string)
    field(:reviewer_id, :string)
    field(:status, Ecto.Enum, values: [:pending, :approved], default: :pending)
    field(:labels, {:array, :string}, default: [])
    field(:restrictions, {:array, Ecto.Enum}, values: Restrictions.all(), default: [])
    field(:releasable_to, {:array, :string}, default: [])
    field(:invited, {:array, :string}, default: [])
    belongs_to(:repository, Repository)
  end

  @doc "A new proposal's visibility fields, cast, with the proposer and the repository."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = proposal, attrs) when is_map(attrs) do
    proposal
    |> Ecto.Changeset.cast(attrs, [:labels, :restrictions, :releasable_to, :invited])
    |> Ecto.Changeset.validate_required([:proposer_id, :repository_id])
  end

  @doc "The visibility the proposal carries."
  @spec visibility(t()) :: map()
  def visibility(%__MODULE__{} = proposal) do
    Map.take(proposal, [:labels, :restrictions, :releasable_to, :invited])
  end

  object_type(:proposal)
  carries([:repository])
  audited(:entity)
  fact(:repository_id, kind: :object_attribute, object: :id)
  fact(:proposer_id, kind: :object_attribute, object: :id)
  relationship(subject: :proposer_id, object: :repository_id, attributes: [:status])
end
