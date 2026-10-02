defmodule ExampleRbac.Infrastructure.Predicates do
  # Hidden, because the policy's surface is what the policy names, not this
  # module. The functions here are the predicates and the hop filter the
  # policy gives the engine, as `dynamic` expressions it puts in every rule.
  # Each reads the tables at the time of the call (C11). None copies a fact.
  #
  # The restrictions predicates are one subquery: the blocked rows, which a
  # restriction blocks for the subject until the repository's embargo lifts.
  # A restriction blocks a row when a kind in effect for its visibility
  # blocks the subject. The kinds in effect are the visibility's own and
  # those a sensitive label it names implies (C3). The repository's list
  # applies to the repository and to each of its directories.
  @moduledoc false

  import Ecto.Query, only: [dynamic: 1, dynamic: 2, from: 2]

  alias Example.Domain.Account
  alias Example.Domain.Directory
  alias Example.Domain.Enterprise
  alias Example.Domain.Label
  alias Example.Domain.Reauthentication
  alias Example.Domain.Repository
  alias Example.Domain.Restrictions
  alias Example.Domain.Team
  alias Example.Domain.Visibility

  @doc "A project that is not archived: the hop filter of every membership grant rule (C1, C11)."
  @spec not_archived() :: Ecto.Query.dynamic_expr()
  def not_archived, do: dynamic([project], is_nil(project.archived_at))

  @doc "C2, C3, C5, and C6 on a repository: no kind in effect for its rollup blocks the subject."
  @spec repository_restrictions(Mediate.subject(), Mediate.context()) :: Ecto.Query.dynamic_expr()
  def repository_restrictions({_kind, subject_id}, %{now: now}) do
    blocked =
      from(m in Visibility,
        as: :visibility,
        join: d in Repository,
        as: :repository,
        on: d.id == m.repository_id,
        join: l in Visibility,
        as: :invited_list,
        on: l.id == m.id,
        select: m.repository_id
      )

    dynamic([repository], repository.id not in subquery(join_facts(blocked, subject_id, now)))
  end

  @doc "C2, C3, C5, and C6 on a directory: its own visibility, under the repository's invited list and embargo."
  @spec directory_restrictions(Mediate.subject(), Mediate.context()) :: Ecto.Query.dynamic_expr()
  def directory_restrictions({_kind, subject_id}, %{now: now}) do
    blocked =
      from(p in Directory,
        as: :visibility,
        join: d in Repository,
        as: :repository,
        on: d.id == p.repository_id,
        join: l in Visibility,
        as: :invited_list,
        on: l.repository_id == d.id,
        select: p.id
      )

    dynamic([directory], directory.id not in subquery(join_facts(blocked, subject_id, now)))
  end

  @doc "C8: the session is fresh, re-authenticated within the window by the context's clock."
  @spec fresh_session(Mediate.subject(), Mediate.context()) :: boolean()
  def fresh_session({_kind, _account}, %{now: _now} = context), do: Reauthentication.fresh?(context)

  @doc "C9: the reviewer is not the proposer."
  @spec another_reviewer(Mediate.subject(), Mediate.context()) :: Ecto.Query.dynamic_expr()
  def another_reviewer({_kind, subject_id}, %{now: _now}) do
    dynamic([proposal], proposal.proposer_id != ^subject_id)
  end

  # One query joins the subject's account row, the owning enterprise, and the
  # sensitive labels the visibility names. So every clause reads the tables
  # at call time (C11).
  defp join_facts(query, subject_id, now) do
    from([visibility: m, repository: d] in query,
      join: o in Team,
      on: o.id == d.owning_team_id,
      join: a in Enterprise,
      as: :enterprise,
      on: a.id == o.enterprise_id,
      join: u in Account,
      as: :account,
      on: u.id == ^subject_id,
      left_join: c in Label,
      as: :label,
      on: c.name in m.labels and c.sensitive,
      where: ^under_embargo(now),
      where: ^blocked(subject_id)
    )
  end

  # C5: a repository stays restricted until its embargo lifts, by the core's clock.
  defp under_embargo(%DateTime{} = now) do
    at = DateTime.truncate(now, :second)
    dynamic([repository: d], is_nil(d.embargo) or d.embargo > ^at)
  end

  defp blocked(subject_id) do
    Restrictions.kinds()
    |> Enum.map(&blocks(&1, subject_id))
    |> Enum.reduce(fn clause, acc -> dynamic(^acc or ^clause) end)
  end

  defp blocks(:employees_only = kind, _subject_id) do
    dynamic([account: u], ^in_effect(kind) and u.employment != ^:employee)
  end

  defp blocks(:export_controlled = kind, _subject_id) do
    dynamic([account: u, enterprise: a], ^in_effect(kind) and u.country != a.country)
  end

  defp blocks(:releasable_to = kind, _subject_id) do
    dynamic([visibility: m, account: u], ^in_effect(kind) and u.country not in m.releasable_to)
  end

  defp blocks(:invite_only = kind, subject_id) do
    dynamic([invited_list: l], ^in_effect(kind) and ^subject_id not in l.invited)
  end

  # C3: declared on the visibility, or implied by a sensitive label it names.
  defp in_effect(kind) do
    dynamic([visibility: m, label: c], ^kind in m.restrictions or ^kind in c.implied_restrictions)
  end
end
