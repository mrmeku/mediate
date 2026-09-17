defmodule ExampleCerbos.Infrastructure.Facts do
  @moduledoc """
  The subqueries the attribute declarations name. There is one per attribute
  whose value depends on the subject that asks, or on a derivation the
  policies do not carry. Each selects the row the value belongs to and the
  value as text, because text is what a policy compares.

  `lib/example_cerbos/infrastructure/restrictions.ex` holds the derivation behind
  two of them. It says which restrictions are effective on a visibility. For a
  directory, it also says whether its repository is still under embargo. The
  second test compares against the moment the port stamped the request
  with. This module cuts that moment to the second, as the adapter cuts
  the request-time facts it sends to the sidecar.

  Every column read here is a declared fact of the example.
  `ExampleCerbos.CoverageTest` holds it there.
  """

  import Ecto.Query, only: [from: 2]

  alias Example.Domain.Directory
  alias Example.Domain.Enterprise
  alias Example.Domain.Membership
  alias Example.Domain.Project
  alias Example.Domain.Proposal
  alias Example.Domain.Repository
  alias Example.Domain.Team
  alias Example.Domain.TeamRole
  alias Example.Domain.User
  alias Example.Domain.Visibility
  alias ExampleCerbos.Infrastructure.Restrictions

  @doc "The roles the subject holds through an open project, by repository (C1)."
  @spec project_roles(Mediate.subject(), Mediate.environment()) :: Ecto.Query.t()
  def project_roles({_kind, id}, %{now: _now}) do
    from(a in Membership,
      join: p in Project,
      on: p.id == a.project_id,
      join: d in Repository,
      on: d.project_id == p.id,
      where: a.user_id == ^id and is_nil(p.archived_at),
      select: %{id: d.id, value: type(a.role, :string)}
    )
  end

  @doc "The roles the subject holds in a repository's owning team, by repository (C1)."
  @spec team_roles(Mediate.subject(), Mediate.environment()) :: Ecto.Query.t()
  def team_roles({_kind, id}, %{now: _now}) do
    from(r in TeamRole,
      join: d in Repository,
      on: d.owning_team_id == r.team_id,
      where: r.user_id == ^id,
      select: %{id: d.id, value: type(r.role, :string)}
    )
  end

  @doc "The restrictions effective on a repository's rollup, declared or implied, by repository (C2, C3)."
  @spec effective_restrictions(Mediate.subject(), Mediate.environment()) :: Ecto.Query.t()
  def effective_restrictions({_kind, _account}, %{now: _now}), do: Restrictions.on_repositories()

  @doc "The subject's country where a repository's rollup releases to it, by repository (C2)."
  @spec releasable_to(Mediate.subject(), Mediate.environment()) :: Ecto.Query.t()
  def releasable_to({_kind, id}, %{now: _now}) do
    from(m in Visibility,
      join: u in User,
      on: u.id == ^id,
      where: u.country in m.releasable_to,
      select: %{id: m.repository_id, value: u.country}
    )
  end

  @doc "The country of the enterprise a repository's owning team belongs to, by repository (C2)."
  @spec enterprise_countries(Mediate.subject(), Mediate.environment()) :: Ecto.Query.t()
  def enterprise_countries({_kind, _account}, %{now: _now}) do
    from(d in Repository,
      join: o in Team,
      on: o.id == d.owning_team_id,
      join: a in Enterprise,
      on: a.id == o.enterprise_id,
      select: %{id: d.id, value: a.country}
    )
  end

  @doc "The subject's own id where a repository's visibility invites it, by repository (C6)."
  @spec invited(Mediate.subject(), Mediate.environment()) :: Ecto.Query.t()
  def invited({_kind, id}, %{now: _now}) do
    from(m in Visibility,
      where: ^id in m.invited,
      select: %{id: m.repository_id, value: type(^id, :string)}
    )
  end

  @doc "The roles the subject holds through an open project, by directory (C1)."
  @spec directory_project_roles(Mediate.subject(), Mediate.environment()) :: Ecto.Query.t()
  def directory_project_roles({_kind, id}, %{now: _now}) do
    from(a in Membership,
      join: p in Project,
      on: p.id == a.project_id,
      join: d in Repository,
      on: d.project_id == p.id,
      join: directory in Directory,
      on: directory.repository_id == d.id,
      where: a.user_id == ^id and is_nil(p.archived_at),
      select: %{id: directory.id, value: type(a.role, :string)}
    )
  end

  @doc "The roles the subject holds in the owning team of a directory's repository, by directory (C1)."
  @spec directory_team_roles(Mediate.subject(), Mediate.environment()) :: Ecto.Query.t()
  def directory_team_roles({_kind, id}, %{now: _now}) do
    from(r in TeamRole,
      join: d in Repository,
      on: d.owning_team_id == r.team_id,
      join: directory in Directory,
      on: directory.repository_id == d.id,
      where: r.user_id == ^id,
      select: %{id: directory.id, value: type(r.role, :string)}
    )
  end

  @doc "The restrictions effective on a directory's own visibility while its repository is under embargo, by directory (C4, C5)."
  @spec directory_effective_restrictions(Mediate.subject(), Mediate.environment()) :: Ecto.Query.t()
  def directory_effective_restrictions({_kind, _account}, %{now: now}) do
    Restrictions.on_directories(DateTime.truncate(now, :second))
  end

  @doc "The subject's country where a directory's visibility releases to it, by directory (C2)."
  @spec directory_releasable_to(Mediate.subject(), Mediate.environment()) :: Ecto.Query.t()
  def directory_releasable_to({_kind, id}, %{now: _now}) do
    from(directory in Directory,
      join: u in User,
      on: u.id == ^id,
      where: u.country in directory.releasable_to,
      select: %{id: directory.id, value: u.country}
    )
  end

  @doc "The country of the enterprise behind a directory's repository, by directory (C2)."
  @spec directory_enterprise_countries(Mediate.subject(), Mediate.environment()) :: Ecto.Query.t()
  def directory_enterprise_countries({_kind, _account}, %{now: _now}) do
    from(directory in Directory,
      join: d in Repository,
      on: d.id == directory.repository_id,
      join: o in Team,
      on: o.id == d.owning_team_id,
      join: a in Enterprise,
      on: a.id == o.enterprise_id,
      select: %{id: directory.id, value: a.country}
    )
  end

  @doc "The subject's own id where the repository of a directory invites it, by directory (C4, C6)."
  @spec directory_invited(Mediate.subject(), Mediate.environment()) :: Ecto.Query.t()
  def directory_invited({_kind, id}, %{now: _now}) do
    from(m in Visibility,
      join: directory in Directory,
      on: directory.repository_id == m.repository_id,
      where: ^id in m.invited,
      select: %{id: directory.id, value: type(^id, :string)}
    )
  end

  @doc "The roles the subject holds in the owning team of a proposal's repository, by proposal (C9)."
  @spec proposal_team_roles(Mediate.subject(), Mediate.environment()) :: Ecto.Query.t()
  def proposal_team_roles({_kind, id}, %{now: _now}) do
    from(r in TeamRole,
      join: d in Repository,
      on: d.owning_team_id == r.team_id,
      join: proposal in Proposal,
      on: proposal.repository_id == d.id,
      where: r.user_id == ^id,
      select: %{id: proposal.id, value: type(r.role, :string)}
    )
  end
end
