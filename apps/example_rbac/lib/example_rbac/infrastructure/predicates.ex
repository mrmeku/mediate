defmodule ExampleRbac.Infrastructure.Predicates do
  # Hidden, because the policy's surface is what the policy names, not this
  # module. The functions here are the predicates and the hop filter the
  # policy gives the adapter, as `dynamic` expressions it puts in every rule.
  # Each reads the tables at the time of the call (C11). None copies a fact.
  #
  # The restrictions predicates are one subquery: the rows a restriction blocks for
  # the subject until the repository's embargo date. A restriction blocks a row
  # when an effective restriction of its visibility fails the subject. The effective
  # restrictions are the visibility's own and those a sensitive label it names
  # implies (C3). The repository's list applies to the repository and to each of
  # its directories.
  @moduledoc false

  import Ecto.Query, only: [dynamic: 1, dynamic: 2, from: 2]

  alias Example.Domain.Directory
  alias Example.Domain.Enterprise
  alias Example.Domain.Label
  alias Example.Domain.Repository
  alias Example.Domain.Restrictions
  alias Example.Domain.Sessions
  alias Example.Domain.Team
  alias Example.Domain.User
  alias Example.Domain.Visibility

  @doc "A project that has not been archived: the hop filter of every membership grant (C1, C11)."
  @spec open() :: Ecto.Query.dynamic_expr()
  def open, do: dynamic([project], is_nil(project.archived_at))

  @doc "C2, C3, C5, and C6 on a repository: no effective restriction of its rollup blocks the subject."
  @spec restrictions(Mediate.subject(), Mediate.environment()) :: Ecto.Query.dynamic_expr()
  def restrictions({_kind, subject_id}, %{now: now}) do
    blocked =
      from(m in Visibility,
        as: :visibility,
        join: d in Repository,
        as: :repository,
        on: d.id == m.repository_id,
        join: l in Visibility,
        as: :invited,
        on: l.id == m.id,
        select: m.repository_id
      )

    dynamic([repository], repository.id not in subquery(joined(blocked, subject_id, now)))
  end

  @doc "C2, C3, C5, and C6 on a directory: its own visibility, under the repository's list and embargo."
  @spec directory_restrictions(Mediate.subject(), Mediate.environment()) :: Ecto.Query.dynamic_expr()
  def directory_restrictions({_kind, subject_id}, %{now: now}) do
    blocked =
      from(p in Directory,
        as: :visibility,
        join: d in Repository,
        as: :repository,
        on: d.id == p.repository_id,
        join: l in Visibility,
        as: :invited,
        on: l.repository_id == d.id,
        select: p.id
      )

    dynamic([directory], directory.id not in subquery(joined(blocked, subject_id, now)))
  end

  @doc "C8: the session re-authenticated within the window, by the environment's clock."
  @spec session(Mediate.subject(), Mediate.environment()) :: boolean()
  def session({_kind, _account}, %{now: _now} = environment), do: Sessions.fresh?(environment)

  @doc "C9: the reviewer is not the proposer."
  @spec another_reviewer(Mediate.subject(), Mediate.environment()) :: Ecto.Query.dynamic_expr()
  def another_reviewer({_kind, subject_id}, %{now: _now}) do
    dynamic([proposal], proposal.proposer_id != ^subject_id)
  end

  # One query joins the subject's row, the owning enterprise, and the
  # sensitive labels the visibility names. So every clause reads the tables
  # at call time (C11).
  defp joined(query, subject_id, now) do
    from([visibility: m, repository: d] in query,
      join: o in Team,
      on: o.id == d.owning_team_id,
      join: a in Enterprise,
      as: :enterprise,
      on: a.id == o.enterprise_id,
      join: u in User,
      as: :subject,
      on: u.id == ^subject_id,
      left_join: c in Label,
      as: :label,
      on: c.name in m.labels and c.sensitive,
      where: ^restricted(now),
      where: ^failed(subject_id)
    )
  end

  # C5: a repository stays restricted until its embargo date, by the port's clock.
  defp restricted(%DateTime{} = now) do
    at = DateTime.truncate(now, :second)
    dynamic([repository: d], is_nil(d.embargo) or d.embargo > ^at)
  end

  defp failed(subject_id) do
    Restrictions.all()
    |> Enum.map(&fails(&1, subject_id))
    |> Enum.reduce(fn clause, acc -> dynamic(^acc or ^clause) end)
  end

  defp fails(:employees_only = restriction, _subject_id) do
    dynamic([subject: u], ^effective(restriction) and u.employment != ^:employee)
  end

  defp fails(:export_controlled = restriction, _subject_id) do
    dynamic([subject: u, enterprise: a], ^effective(restriction) and u.country != a.country)
  end

  defp fails(:releasable_to = restriction, _subject_id) do
    dynamic([visibility: m, subject: u], ^effective(restriction) and u.country not in m.releasable_to)
  end

  defp fails(:invite_only = restriction, subject_id) do
    dynamic([invited: l], ^effective(restriction) and ^subject_id not in l.invited)
  end

  # C3: declared on the visibility, or implied by a sensitive label it names.
  defp effective(restriction) do
    dynamic([visibility: m, label: c], ^restriction in m.restrictions or ^restriction in c.implied_restrictions)
  end
end
