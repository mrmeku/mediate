defmodule Example.Application.Review do
  @moduledoc """
  Access review (AC-2, AC-6(5), AC-6(7)): who can do what today, per enterprise,
  and every privileged account. The port's `review` answers a rule and a
  decision per subject under one operation id. The reviewer runs the
  population query under each subject's decision. So every row the report
  names is a read logged for the subject it is about. The rows the review
  ranges over come from a read under a declared exemption. Every verdict
  comes from the port, so the report says what the adapter enforces.

  The review answers for today and for no other day. The tables hold today,
  and nothing here keeps what they held last March.

  A review of `change_visibility` asks what a role can do, not what one session
  can do. So the call carries a re-authentication as of the clock the
  configuration names. Without it every visibility row is absent for a reason
  that is the session's and not the role's.
  """

  import Ecto.Query, only: [where: 2]

  alias Example.Application.Accounts
  alias Example.Application.Repositories
  alias Example.Domain.Enterprise
  alias Example.Infrastructure.Repo
  alias Example.Infrastructure.ReviewQuery
  alias Mediate.Decision

  @review {:exempt, "access review: the population the reviewer ranges over"}
  @proposal_operations [:approve_visibility]

  @typedoc "Per subject, per operation, the ids of the rows the subject can act on."
  @type permissions :: %{Mediate.subject() => %{atom() => [integer()]}}

  @doc "Who can read which repositories of an enterprise, by subject, over every account."
  @spec readers(Mediate.subject(), Enterprise.t(), keyword()) :: %{Mediate.subject() => [integer()]}
  def readers({_kind, _account} = reviewer, %Enterprise{id: enterprise_id}, opts \\ []) when is_list(opts) do
    reviewed(reviewer, :read, :repository, ReviewQuery.repositories(enterprise_id), opts)
  end

  @doc "The operations a permission line names, in report order."
  @spec operations() :: [atom()]
  def operations, do: Repositories.operations() ++ @proposal_operations

  @doc """
  Every permission every account holds on the repositories of an enterprise, by
  operation, and on the proposals over those repositories.
  """
  @spec permissions(Mediate.subject(), Enterprise.t(), keyword()) :: permissions()
  def permissions({_kind, _account} = reviewer, %Enterprise{id: enterprise_id}, opts \\ []) when is_list(opts) do
    enterprise_id
    |> populations()
    |> Enum.flat_map(fn {operation, type, query} -> held(reviewer, operation, type, query, opts) end)
    |> Enum.group_by(fn {subject, _op, _ids} -> subject end, fn {_subject, op, ids} -> {op, ids} end)
    |> Map.new(fn {subject, entries} -> {subject, Map.new(entries)} end)
  end

  @doc """
  The report: readers per enterprise, then every operation of each account
  that holds any permission, then privileged accounts.
  """
  @spec report(Mediate.subject(), keyword()) :: String.t()
  def report({_kind, _account} = reviewer, opts \\ []) when is_list(opts) do
    enterprises = Repo.all(ReviewQuery.enterprises(), mediate: @review)

    lines =
      Enum.flat_map(enterprises, fn enterprise ->
        ["enterprise #{enterprise.name}"] ++
          reader_lines(reviewer, enterprise, opts) ++ permission_lines(reviewer, enterprise, opts)
      end)

    Enum.join(lines ++ privileged_lines(), "\n") <> "\n"
  end

  defp reader_lines(reviewer, enterprise, opts) do
    reviewer
    |> readers(enterprise, opts)
    |> Enum.sort_by(fn {{_kind, id}, _ids} -> id end)
    |> Enum.map(fn {{_kind, id}, ids} -> "  #{id} reads #{invited(ids)}" end)
  end

  defp permission_lines(reviewer, enterprise, opts) do
    reviewer
    |> permissions(enterprise, opts)
    |> Enum.reject(fn {_subject, by_op} -> Enum.all?(by_op, fn {_operation, ids} -> ids == [] end) end)
    |> Enum.sort_by(fn {{_kind, id}, _by_op} -> id end)
    |> Enum.flat_map(fn {{_kind, id}, by_op} ->
      for operation <- operations() do
        "  #{id} may #{operation} #{invited(by_op[operation] || [])}"
      end
    end)
  end

  defp invited(ids), do: "[#{Enum.join(ids, ", ")}]"

  defp privileged_lines do
    ["privileged accounts"] ++
      Enum.map(Accounts.privileged(), fn {user, roles} ->
        "  #{user.id} (person #{user.person_id}) holds [#{Enum.join(roles, ", ")}]"
      end)
  end

  defp populations(enterprise_id) do
    repositories = ReviewQuery.repositories(enterprise_id)
    proposals = ReviewQuery.proposals(enterprise_id)

    for(operation <- Repositories.operations(), do: {operation, :repository, repositories}) ++
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
