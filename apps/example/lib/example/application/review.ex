defmodule Example.Application.Review do
  @moduledoc """
  Access review (AC-2, AC-6(5), AC-6(7)): who can do what today, per agency,
  and every privileged account. The port's `review` answers a rule and a
  decision per subject under one operation id. The reviewer runs the
  population query under each subject's decision. So every row the report
  names is a read logged for the subject it is about. The rows the review
  ranges over come from a read under a declared exemption. Every verdict
  comes from the port, so the report says what the adapter enforces.

  The review answers for today and for no other day. The tables hold today,
  and nothing here keeps what they held last March.

  A review of `change_marking` asks what a role can do, not what one session
  can do. So the call carries a re-authentication as of the clock the
  configuration names. Without it every marking row is absent for a reason
  that is the session's and not the role's.
  """

  import Ecto.Query, only: [where: 2]

  alias Example.Application.Accounts
  alias Example.Application.Documents
  alias Example.Domain.Agency
  alias Example.Infrastructure.Repo
  alias Example.Infrastructure.ReviewQuery
  alias Mediate.Decision

  @review {:exempt, "access review: the population the reviewer ranges over"}
  @proposal_operations [:approve_marking]

  @typedoc "Per subject, per operation, the ids of the rows the subject can act on."
  @type permissions :: %{Mediate.subject() => %{atom() => [integer()]}}

  @doc "Who can read which documents of an agency, by subject, over every account."
  @spec readers(Mediate.subject(), Agency.t(), keyword()) :: %{Mediate.subject() => [integer()]}
  def readers({_kind, _account} = reviewer, %Agency{id: agency_id}, opts \\ []) when is_list(opts) do
    reviewed(reviewer, :read, :document, ReviewQuery.documents(agency_id), opts)
  end

  @doc "The operations a permission line names, in report order."
  @spec operations() :: [atom()]
  def operations, do: Documents.operations() ++ @proposal_operations

  @doc """
  Every permission every account holds on the documents of an agency, by
  operation, and on the proposals over those documents.
  """
  @spec permissions(Mediate.subject(), Agency.t(), keyword()) :: permissions()
  def permissions({_kind, _account} = reviewer, %Agency{id: agency_id}, opts \\ []) when is_list(opts) do
    agency_id
    |> populations()
    |> Enum.flat_map(fn {operation, type, query} -> held(reviewer, operation, type, query, opts) end)
    |> Enum.group_by(fn {subject, _op, _ids} -> subject end, fn {_subject, op, ids} -> {op, ids} end)
    |> Map.new(fn {subject, entries} -> {subject, Map.new(entries)} end)
  end

  @doc """
  The report: readers per agency, then every operation of each account
  that holds any permission, then privileged accounts.
  """
  @spec report(Mediate.subject(), keyword()) :: String.t()
  def report({_kind, _account} = reviewer, opts \\ []) when is_list(opts) do
    agencies = Repo.all(ReviewQuery.agencies(), mediate: @review)

    lines =
      Enum.flat_map(agencies, fn agency ->
        ["agency #{agency.name}"] ++ reader_lines(reviewer, agency, opts) ++ permission_lines(reviewer, agency, opts)
      end)

    Enum.join(lines ++ privileged_lines(), "\n") <> "\n"
  end

  defp reader_lines(reviewer, agency, opts) do
    reviewer
    |> readers(agency, opts)
    |> Enum.sort_by(fn {{_kind, id}, _ids} -> id end)
    |> Enum.map(fn {{_kind, id}, ids} -> "  #{id} reads #{listed(ids)}" end)
  end

  defp permission_lines(reviewer, agency, opts) do
    reviewer
    |> permissions(agency, opts)
    |> Enum.reject(fn {_subject, by_op} -> Enum.all?(by_op, fn {_operation, ids} -> ids == [] end) end)
    |> Enum.sort_by(fn {{_kind, id}, _by_op} -> id end)
    |> Enum.flat_map(fn {{_kind, id}, by_op} ->
      for operation <- operations() do
        "  #{id} may #{operation} #{listed(by_op[operation] || [])}"
      end
    end)
  end

  defp listed(ids), do: "[#{Enum.join(ids, ", ")}]"

  defp privileged_lines do
    ["privileged accounts"] ++
      Enum.map(Accounts.privileged(), fn {user, roles} ->
        "  #{user.id} (person #{user.person_id}) holds [#{Enum.join(roles, ", ")}]"
      end)
  end

  defp populations(agency_id) do
    documents = ReviewQuery.documents(agency_id)
    proposals = ReviewQuery.proposals(agency_id)

    for(operation <- Documents.operations(), do: {operation, :document, documents}) ++
      for(operation <- @proposal_operations, do: {operation, :proposal, proposals})
  end

  defp held(reviewer, operation, type, query, opts) do
    for {subject, ids} <- reviewed(reviewer, operation, type, query, opts), do: {subject, operation, ids}
  end

  defp subjects do
    query = ReviewQuery.subjects()

    query
    |> Repo.all()
    |> Enum.map(fn {id, kind} -> {kind, id} end)
  end

  defp reviewed(reviewer, operation, type, query, opts) do
    reviewer
    |> Mediate.review(subjects(), operation, type, opts)
    |> Map.new(fn {subject, {rule, decision}} -> {subject, ids(query, rule, decision)} end)
  end

  defp ids(_query, _rule, %Decision{verdict: :deny}), do: []

  defp ids(query, rule, %Decision{} = decision) do
    query
    |> where(^rule)
    |> Repo.all(mediate: decision)
    |> Enum.sort()
  end
end
