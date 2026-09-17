defmodule Example.Application.Proposals do
  @moduledoc """
  Separation of duties on visibility changes (C9). An admin proposes, and a
  different reviewer approves. The approval applies the visibility under the
  proposal's decision. That decision carries the repository and the repository's
  visibility, so the approval writes both as nested changes of the proposal. A
  proposal without approval changes nothing.
  """

  alias Example.Application.Repositories
  alias Example.Domain.Proposal
  alias Example.Domain.Repository
  alias Example.Infrastructure.Repo

  @doc "Propose a visibility for a repository. It needs `propose_visibility` on the repository (C7)."
  @spec propose(Mediate.subject(), integer(), map(), keyword()) ::
          {:ok, Proposal.t()} | {:error, Repositories.refusal()}
  def propose({_kind, proposer} = subject, repository_id, attrs, opts \\ [])
      when is_integer(repository_id) and is_map(attrs) do
    with {:ok, decision} <- Mediate.authorize(subject, :propose_visibility, Repositories.object(repository_id), opts),
         {:ok, repository} <- Repositories.fetch(repository_id, decision) do
      proposal = Proposal.changeset(%Proposal{proposer_id: proposer, repository_id: repository.id}, attrs)
      change = appended(repository, proposal, decision)

      with {:ok, %Repository{proposals: proposals}} <- Repo.update(change, mediate: decision) do
        {:ok, List.last(proposals)}
      end
    end
  end

  @doc "Approve a proposal. It needs `approve_visibility` on it, which C9 gives to a different reviewer alone."
  @spec approve(Mediate.subject(), integer(), keyword()) ::
          {:ok, Proposal.t()} | {:error, Repositories.refusal() | Repositories.RollupViolation.t()}
  def approve({_kind, reviewer} = subject, proposal_id, opts \\ []) when is_integer(proposal_id) do
    object = Repositories.object(:proposal, proposal_id)

    with {:ok, decision} <- Mediate.authorize(subject, :approve_visibility, object, opts),
         %Proposal{status: :pending} = proposal <-
           Repo.get(Proposal, proposal_id, mediate: decision) || {:error, :not_found} do
      Repo.transaction(fn -> approve_or_roll_back(proposal, reviewer, decision) end)
    else
      %Proposal{status: :approved} -> {:error, :not_found}
      other -> other
    end
  end

  defp approve_or_roll_back(%Proposal{} = proposal, reviewer, decision) do
    proposal = Repo.preload(proposal, [repository: :visibility], mediate: decision)

    case Repositories.visibility_change(proposal.repository, Proposal.visibility(proposal)) do
      {:ok, repository_change} ->
        proposal
        |> Ecto.Changeset.change(status: :approved, reviewer_id: reviewer)
        |> Ecto.Changeset.put_assoc(:repository, repository_change)
        |> Repo.update!(mediate: decision)

      {:error, violation} ->
        Repo.rollback(violation)
    end
  end

  defp appended(%Repository{} = repository, proposal, decision) do
    repository = Repo.preload(repository, :proposals, mediate: decision)

    repository
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:proposals, Enum.reverse([proposal | Enum.reverse(repository.proposals)]))
  end
end
