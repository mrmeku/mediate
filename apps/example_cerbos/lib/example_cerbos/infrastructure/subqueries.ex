defmodule ExampleCerbos.Infrastructure.Subqueries do
  @moduledoc """
  The subquery behind each subquery attribute the declarations name. Each
  is a function of the subject and the context that answers an Ecto query
  of the rows the value holds of, and the value as text, because text is
  what a policy compares. A function is named for the resource and the
  attribute it serves, so a declaration reads `subquery:
  &Subqueries.directory_invited/2`.

  Two of them read a hidden module beside this one, which holds the one
  derivation the policy language does not carry: which restriction kinds
  are in effect on a visibility. For a directory, the derivation also
  tests whether its repository is under embargo at the moment Mediate
  stamped the call with. This module cuts that moment to the second, as the
  engine cuts the context facts it sends the server.

  Every column read here is a declared fact of the example.
  `ExampleCerbos.Infrastructure.DeclarationsTest` holds it there.
  """

  import Ecto.Query, only: [from: 2]

  alias Example.Domain.Account
  alias Example.Domain.Directory
  alias Example.Domain.Enterprise
  alias Example.Domain.Membership
  alias Example.Domain.Project
  alias Example.Domain.Proposal
  alias Example.Domain.Repository
  alias Example.Domain.Team
  alias Example.Domain.TeamRole
  alias Example.Domain.Visibility
  alias ExampleCerbos.Infrastructure.EffectiveRestrictions

  @doc "The roles the subject holds through a project that is not archived, by repository (C1)."
  @spec repository_project_roles(Mediate.subject(), Mediate.context()) :: Ecto.Query.t()
  def repository_project_roles({_kind, id}, %{now: _now}) do
    from(m in Membership,
      join: p in Project,
      on: p.id == m.project_id,
      join: r in Repository,
      on: r.project_id == p.id,
      where: m.account_id == ^id and is_nil(p.archived_at),
      select: %{id: r.id, value: type(m.role, :string)}
    )
  end

  @doc "The roles the subject holds in a repository's owning team, by repository (C1)."
  @spec repository_team_roles(Mediate.subject(), Mediate.context()) :: Ecto.Query.t()
  def repository_team_roles({_kind, id}, %{now: _now}) do
    from(t in TeamRole,
      join: r in Repository,
      on: r.owning_team_id == t.team_id,
      where: t.account_id == ^id,
      select: %{id: r.id, value: type(t.role, :string)}
    )
  end

  @doc "The restriction kinds in effect on a repository's rollup, declared or implied, by repository (C2, C3)."
  @spec repository_effective_restrictions(Mediate.subject(), Mediate.context()) :: Ecto.Query.t()
  def repository_effective_restrictions({_kind, _id}, %{now: _now}), do: EffectiveRestrictions.on_repositories()

  @doc "The subject's country where a repository's rollup releases to it, by repository (C2)."
  @spec repository_releasable_to(Mediate.subject(), Mediate.context()) :: Ecto.Query.t()
  def repository_releasable_to({_kind, id}, %{now: _now}) do
    from(v in Visibility,
      join: a in Account,
      on: a.id == ^id,
      where: a.country in v.releasable_to,
      select: %{id: v.repository_id, value: a.country}
    )
  end

  @doc "The country of the enterprise a repository's owning team belongs to, by repository (C2)."
  @spec repository_enterprise_countries(Mediate.subject(), Mediate.context()) :: Ecto.Query.t()
  def repository_enterprise_countries({_kind, _id}, %{now: _now}) do
    from(r in Repository,
      join: t in Team,
      on: t.id == r.owning_team_id,
      join: e in Enterprise,
      on: e.id == t.enterprise_id,
      select: %{id: r.id, value: e.country}
    )
  end

  @doc "The subject's own id where a repository's invited list names it, by repository (C6)."
  @spec repository_invited(Mediate.subject(), Mediate.context()) :: Ecto.Query.t()
  def repository_invited({_kind, id}, %{now: _now}) do
    from(v in Visibility,
      where: ^id in v.invited,
      select: %{id: v.repository_id, value: type(^id, :string)}
    )
  end

  @doc "The roles the subject holds through a project that is not archived, by directory (C1)."
  @spec directory_project_roles(Mediate.subject(), Mediate.context()) :: Ecto.Query.t()
  def directory_project_roles({_kind, id}, %{now: _now}) do
    from(m in Membership,
      join: p in Project,
      on: p.id == m.project_id,
      join: r in Repository,
      on: r.project_id == p.id,
      join: d in Directory,
      on: d.repository_id == r.id,
      where: m.account_id == ^id and is_nil(p.archived_at),
      select: %{id: d.id, value: type(m.role, :string)}
    )
  end

  @doc "The roles the subject holds in the owning team of a directory's repository, by directory (C1)."
  @spec directory_team_roles(Mediate.subject(), Mediate.context()) :: Ecto.Query.t()
  def directory_team_roles({_kind, id}, %{now: _now}) do
    from(t in TeamRole,
      join: r in Repository,
      on: r.owning_team_id == t.team_id,
      join: d in Directory,
      on: d.repository_id == r.id,
      where: t.account_id == ^id,
      select: %{id: d.id, value: type(t.role, :string)}
    )
  end

  @doc "The restriction kinds in effect on a directory's own visibility while its repository is under embargo, by directory (C4, C5)."
  @spec directory_effective_restrictions(Mediate.subject(), Mediate.context()) :: Ecto.Query.t()
  def directory_effective_restrictions({_kind, _id}, %{now: now}) do
    EffectiveRestrictions.on_directories(DateTime.truncate(now, :second))
  end

  @doc "The subject's country where a directory's visibility releases to it, by directory (C2)."
  @spec directory_releasable_to(Mediate.subject(), Mediate.context()) :: Ecto.Query.t()
  def directory_releasable_to({_kind, id}, %{now: _now}) do
    from(d in Directory,
      join: a in Account,
      on: a.id == ^id,
      where: a.country in d.releasable_to,
      select: %{id: d.id, value: a.country}
    )
  end

  @doc "The country of the enterprise behind a directory's repository, by directory (C2)."
  @spec directory_enterprise_countries(Mediate.subject(), Mediate.context()) :: Ecto.Query.t()
  def directory_enterprise_countries({_kind, _id}, %{now: _now}) do
    from(d in Directory,
      join: r in Repository,
      on: r.id == d.repository_id,
      join: t in Team,
      on: t.id == r.owning_team_id,
      join: e in Enterprise,
      on: e.id == t.enterprise_id,
      select: %{id: d.id, value: e.country}
    )
  end

  @doc "The subject's own id where the invited list of a directory's repository names it, by directory (C4, C6)."
  @spec directory_invited(Mediate.subject(), Mediate.context()) :: Ecto.Query.t()
  def directory_invited({_kind, id}, %{now: _now}) do
    from(v in Visibility,
      join: d in Directory,
      on: d.repository_id == v.repository_id,
      where: ^id in v.invited,
      select: %{id: d.id, value: type(^id, :string)}
    )
  end

  @doc "The roles the subject holds in the owning team of a proposal's repository, by proposal (C9)."
  @spec proposal_team_roles(Mediate.subject(), Mediate.context()) :: Ecto.Query.t()
  def proposal_team_roles({_kind, id}, %{now: _now}) do
    from(t in TeamRole,
      join: r in Repository,
      on: r.owning_team_id == t.team_id,
      join: p in Proposal,
      on: p.repository_id == r.id,
      where: t.account_id == ^id,
      select: %{id: p.id, value: type(t.role, :string)}
    )
  end
end
