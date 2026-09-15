defmodule ExampleRbac.Infrastructure.Predicates do
  @moduledoc false
  # Hidden, because the policy's surface is what the policy names, not this
  # module. The functions here are the predicates and the hop filter the
  # policy gives the adapter, as `dynamic` expressions it puts in every rule.
  # Each reads the tables at the time of the call (C11). None copies a fact.
  #
  # The controls predicates are one subquery: the rows a control blocks for
  # the subject until the document's decontrol date. A control blocks a row
  # when an effective control of its marking fails the subject. The effective
  # controls are the marking's own and those a specified category it names
  # implies (C3). The document's list applies to the document and to each of
  # its portions.

  import Ecto.Query, only: [dynamic: 1, dynamic: 2, from: 2]

  alias Example.Domain.Agency
  alias Example.Domain.Category
  alias Example.Domain.Controls
  alias Example.Domain.Document
  alias Example.Domain.Marking
  alias Example.Domain.Office
  alias Example.Domain.Portion
  alias Example.Domain.Sessions
  alias Example.Domain.User

  @doc "A program that has not closed: the hop filter of every assignment grant (C1, C11)."
  @spec open() :: Ecto.Query.dynamic_expr()
  def open, do: dynamic([program], is_nil(program.closed_at))

  @doc "C2, C3, C5, and C6 on a document: no effective control of its banner blocks the subject."
  @spec controls(Mediate.subject(), Mediate.environment()) :: Ecto.Query.dynamic_expr()
  def controls({_kind, subject_id}, %{now: now}) do
    blocked =
      from(m in Marking,
        as: :marking,
        join: d in Document,
        as: :document,
        on: d.id == m.document_id,
        join: l in Marking,
        as: :listed,
        on: l.id == m.id,
        select: m.document_id
      )

    dynamic([document], document.id not in subquery(joined(blocked, subject_id, now)))
  end

  @doc "C2, C3, C5, and C6 on a portion: its own marking, under the document's list and decontrol."
  @spec portion_controls(Mediate.subject(), Mediate.environment()) :: Ecto.Query.dynamic_expr()
  def portion_controls({_kind, subject_id}, %{now: now}) do
    blocked =
      from(p in Portion,
        as: :marking,
        join: d in Document,
        as: :document,
        on: d.id == p.document_id,
        join: l in Marking,
        as: :listed,
        on: l.document_id == d.id,
        select: p.id
      )

    dynamic([portion], portion.id not in subquery(joined(blocked, subject_id, now)))
  end

  @doc "C8: the session re-authenticated within the window, by the environment's clock."
  @spec session(Mediate.subject(), Mediate.environment()) :: boolean()
  def session({_kind, _account}, %{now: _now} = environment), do: Sessions.fresh?(environment)

  @doc "C9: the approver is not the proposer."
  @spec another_approver(Mediate.subject(), Mediate.environment()) :: Ecto.Query.dynamic_expr()
  def another_approver({_kind, subject_id}, %{now: _now}) do
    dynamic([proposal], proposal.proposer_id != ^subject_id)
  end

  # One query joins the subject's row, the designating agency, and the
  # specified categories the marking names. So every clause reads the tables
  # at call time (C11).
  defp joined(query, subject_id, now) do
    from([marking: m, document: d] in query,
      join: o in Office,
      on: o.id == d.designating_office_id,
      join: a in Agency,
      as: :agency,
      on: a.id == o.agency_id,
      join: u in User,
      as: :subject,
      on: u.id == ^subject_id,
      left_join: c in Category,
      as: :category,
      on: c.name in m.categories and c.specified,
      where: ^controlled(now),
      where: ^failed(subject_id)
    )
  end

  # C5: a document stays controlled until its decontrol date, by the port's clock.
  defp controlled(%DateTime{} = now) do
    at = DateTime.truncate(now, :second)
    dynamic([document: d], is_nil(d.decontrol) or d.decontrol > ^at)
  end

  defp failed(subject_id) do
    Controls.all()
    |> Enum.map(&fails(&1, subject_id))
    |> Enum.reduce(fn clause, acc -> dynamic(^acc or ^clause) end)
  end

  defp fails(:federal_only = control, _subject_id) do
    dynamic([subject: u], ^effective(control) and u.employment != ^:federal)
  end

  defp fails(:no_foreign = control, _subject_id) do
    dynamic([subject: u, agency: a], ^effective(control) and u.nationality != a.nationality)
  end

  defp fails(:releasable_to = control, _subject_id) do
    dynamic([marking: m, subject: u], ^effective(control) and u.nationality not in m.releasable_to)
  end

  defp fails(:named_list = control, subject_id) do
    dynamic([listed: l], ^effective(control) and ^subject_id not in l.list)
  end

  # C3: declared on the marking, or implied by a specified category it names.
  defp effective(control) do
    dynamic([marking: m, category: c], ^control in m.controls or ^control in c.implied_controls)
  end
end
