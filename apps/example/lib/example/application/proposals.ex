defmodule Example.Application.Proposals do
  @moduledoc """
  Separation of duties on marking changes (C9). A designator proposes, and a
  different approver approves. The approval applies the marking under the
  proposal's decision. That decision carries the document and the document's
  marking, so the approval writes both as nested changes of the proposal. A
  proposal without approval changes nothing.
  """

  alias Example.Application.Documents
  alias Example.Domain.Document
  alias Example.Domain.Proposal
  alias Example.Infrastructure.Repo

  @doc "Propose a marking for a document. It needs `propose_marking` on the document (C7)."
  @spec propose(Mediate.subject(), integer(), map(), keyword()) :: {:ok, Proposal.t()} | {:error, Documents.refusal()}
  def propose({_kind, proposer} = subject, document_id, attrs, opts \\ [])
      when is_integer(document_id) and is_map(attrs) do
    with {:ok, decision} <- Mediate.authorize(subject, :propose_marking, Documents.object(document_id), opts),
         {:ok, document} <- Documents.fetch(document_id, decision) do
      proposal = Proposal.changeset(%Proposal{proposer_id: proposer, document_id: document.id}, attrs)
      change = appended(document, proposal, decision)

      with {:ok, %Document{proposals: proposals}} <- Repo.update(change, mediate: decision) do
        {:ok, List.last(proposals)}
      end
    end
  end

  @doc "Approve a proposal. It needs `approve_marking` on it, which C9 gives to a different approver alone."
  @spec approve(Mediate.subject(), integer(), keyword()) ::
          {:ok, Proposal.t()} | {:error, Documents.refusal() | Documents.BannerViolation.t()}
  def approve({_kind, approver} = subject, proposal_id, opts \\ []) when is_integer(proposal_id) do
    object = Documents.object(:proposal, proposal_id)

    with {:ok, decision} <- Mediate.authorize(subject, :approve_marking, object, opts),
         %Proposal{status: :pending} = proposal <-
           Repo.get(Proposal, proposal_id, mediate: decision) || {:error, :not_found} do
      Repo.transaction(fn -> approve_or_roll_back(proposal, approver, decision) end)
    else
      %Proposal{status: :approved} -> {:error, :not_found}
      other -> other
    end
  end

  defp approve_or_roll_back(%Proposal{} = proposal, approver, decision) do
    proposal = Repo.preload(proposal, [document: :marking], mediate: decision)

    case Documents.marking_change(proposal.document, Proposal.marking(proposal)) do
      {:ok, document_change} ->
        proposal
        |> Ecto.Changeset.change(status: :approved, approver_id: approver)
        |> Ecto.Changeset.put_assoc(:document, document_change)
        |> Repo.update!(mediate: decision)

      {:error, violation} ->
        Repo.rollback(violation)
    end
  end

  defp appended(%Document{} = document, proposal, decision) do
    document = Repo.preload(document, :proposals, mediate: decision)

    document
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:proposals, Enum.reverse([proposal | Enum.reverse(document.proposals)]))
  end
end
