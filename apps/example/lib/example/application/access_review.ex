defmodule Example.Application.AccessReview do
  @moduledoc """
  Access review (AC-2, AC-6(5), AC-6(7)): who can do what today, per
  enterprise, and every privileged account. `Mediate.review/5` answers a
  rule and a decision per subject under one decision id. The reviewer runs
  the population query under each subject's decision. So every row the
  report names is a read logged for the subject it is about. The rows the
  review ranges over come from a read under a declared exemption. Every
  decision comes from Mediate, so the report says what the engine enforces.

  The review answers for today and for no other day. The tables hold today,
  and nothing here keeps what they held last March.

  A review of `change_visibility` asks what an account can do, not what one
  session can do. So the call carries a fresh session as of the clock the
  configuration names. Without it every visibility row is absent for a
  reason that is the session's and not the account's.
  """

  import Ecto.Query, only: [where: 2]

  alias Example.Application.Accounts
  alias Example.Application.Repositories
  alias Example.Domain.Enterprise
  alias Example.Infrastructure.AccessReviewQuery
  alias Example.Infrastructure.Repo
  alias Mediate.Decision

  @review {:exempt, "access review: the population the reviewer ranges over"}
  @proposal_actions [:approve_visibility]

  @typedoc "Per subject, per action, the ids of the rows the subject is allowed to act on."
  @type allowed :: %{Mediate.subject() => %{atom() => [integer()]}}

  @doc "Who can read which repositories of an enterprise, by subject, over every account."
  @spec readers(Mediate.subject(), Enterprise.t(), keyword()) :: %{Mediate.subject() => [integer()]}
  def readers({_kind, _account} = reviewer, %Enterprise{id: enterprise_id}, opts \\ []) when is_list(opts) do
    reviewed(reviewer, :read, :repository, AccessReviewQuery.repositories(enterprise_id), opts)
  end

  @doc "The actions a report line names, in report order."
  @spec actions() :: [atom()]
  def actions, do: Repositories.actions() ++ @proposal_actions

  @doc """
  What every account is allowed on the repositories of an enterprise, by
  action, and on the proposals over those repositories.
  """
  @spec allowed(Mediate.subject(), Enterprise.t(), keyword()) :: allowed()
  def allowed({_kind, _account} = reviewer, %Enterprise{id: enterprise_id}, opts \\ []) when is_list(opts) do
    enterprise_id
    |> populations()
    |> Enum.flat_map(fn {action, type, query} -> held(reviewer, action, type, query, opts) end)
    |> Enum.group_by(fn {subject, _op, _ids} -> subject end, fn {_subject, op, ids} -> {op, ids} end)
    |> Map.new(fn {subject, entries} -> {subject, Map.new(entries)} end)
  end

  @doc """
  The report: readers per enterprise, then every action of each account
  that is allowed any, then privileged accounts.
  """
  @spec report(Mediate.subject(), keyword()) :: String.t()
  def report({_kind, _account} = reviewer, opts \\ []) when is_list(opts) do
    enterprises = Repo.all(AccessReviewQuery.enterprises(), authorized_by: @review)

    lines =
      Enum.flat_map(enterprises, fn enterprise ->
        ["enterprise #{enterprise.name}"] ++
          reader_lines(reviewer, enterprise, opts) ++ allowed_lines(reviewer, enterprise, opts)
      end)

    Enum.join(lines ++ privileged_lines(), "\n") <> "\n"
  end

  defp reader_lines(reviewer, enterprise, opts) do
    reviewer
    |> readers(enterprise, opts)
    |> Enum.sort_by(fn {{_kind, id}, _ids} -> id end)
    |> Enum.map(fn {{_kind, id}, ids} -> "  #{id} reads #{invited(ids)}" end)
  end

  defp allowed_lines(reviewer, enterprise, opts) do
    reviewer
    |> allowed(enterprise, opts)
    |> Enum.reject(fn {_subject, by_action} -> Enum.all?(by_action, fn {_action, ids} -> ids == [] end) end)
    |> Enum.sort_by(fn {{_kind, id}, _by_action} -> id end)
    |> Enum.flat_map(fn {{_kind, id}, by_action} ->
      for action <- actions() do
        "  #{id} may #{action} #{invited(by_action[action] || [])}"
      end
    end)
  end

  defp invited(ids), do: "[#{Enum.join(ids, ", ")}]"

  defp privileged_lines do
    ["privileged accounts"] ++
      Enum.map(Accounts.privileged(), fn {account, permissions} ->
        "  #{account.id} (person #{account.person_id}) holds [#{Enum.join(permissions, ", ")}]"
      end)
  end

  defp populations(enterprise_id) do
    repositories = AccessReviewQuery.repositories(enterprise_id)
    proposals = AccessReviewQuery.proposals(enterprise_id)

    for(action <- Repositories.actions(), do: {action, :repository, repositories}) ++
      for(action <- @proposal_actions, do: {action, :proposal, proposals})
  end

  defp held(reviewer, action, type, query, opts) do
    for {subject, ids} <- reviewed(reviewer, action, type, query, opts), do: {subject, action, ids}
  end

  defp subjects do
    query = AccessReviewQuery.subjects()

    query
    |> Repo.all()
    |> Enum.map(fn {id, kind} -> {kind, id} end)
  end

  defp reviewed(reviewer, action, type, query, opts) do
    reviewer
    |> Mediate.review(subjects(), action, type, opts)
    |> Map.new(fn {subject, {rule, decision}} -> {subject, ids(query, rule, decision)} end)
  end

  defp ids(_query, _rule, %Decision{effect: :deny}), do: []

  defp ids(query, rule, %Decision{} = decision) do
    query
    |> where(^rule)
    |> Repo.all(authorized_by: decision)
    |> Enum.sort()
  end
end
