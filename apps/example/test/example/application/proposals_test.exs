defmodule Example.Application.ProposalsTest do
  use Example.FakeCase, async: true

  alias Example.Application.Proposals
  alias Example.Application.Repositories
  alias Example.Domain.Proposal
  alias Example.Domain.Visibility
  alias Example.Fixture
  alias Example.Infrastructure.Repo
  alias Mediate.Error

  @dana {:user, "dana"}
  @eve {:user, "eve"}

  setup %{world: world} do
    {:ok, repository: Fixture.repository!(world)}
  end

  test "propose needs the repository's operation and records a pending proposal", ctx do
    assert {:error, %Error{detail: "user dana may not propose_visibility" <> _rest}} =
             Proposals.propose(@dana, ctx.repository.id, %{restrictions: [:export_controlled]})

    allow(ctx.rules, "dana", :propose_visibility, {:repository, ctx.repository.id})

    assert {:ok, %Proposal{status: :pending, proposer_id: "dana", restrictions: [:export_controlled]}} =
             Proposals.propose(@dana, ctx.repository.id, %{restrictions: [:export_controlled]})

    assert {:ok, %Proposal{}} = Proposals.propose(@dana, ctx.repository.id, %{"restrictions" => ["employees_only"]})
  end

  test "approve needs the proposal's operation, applies the visibility, and closes the proposal", ctx do
    allow(ctx.rules, "dana", :propose_visibility, {:repository, ctx.repository.id})
    {:ok, proposal} = Proposals.propose(@dana, ctx.repository.id, %{restrictions: [:export_controlled]})
    assert {:error, %Error{detail: "user eve may not approve_visibility" <> _rest}} = Proposals.approve(@eve, proposal.id)
    allow(ctx.rules, "eve", :approve_visibility, {:proposal, proposal.id})
    assert {:ok, %Proposal{status: :approved, reviewer_id: "eve"}} = Proposals.approve(@eve, proposal.id)
    assert {:error, :not_found} = Proposals.approve(@eve, proposal.id)
    allow(ctx.rules, "eve", :read, {:repository, ctx.repository.id})

    assert {:ok, %{visibility: %Visibility{restrictions: [:export_controlled]}}} =
             Repositories.read(@eve, ctx.repository.id)

    allow(ctx.rules, "eve", :approve_visibility, {:proposal, :any})
    assert {:error, :not_found} = Proposals.approve(@eve, proposal.id + 1000)
  end

  test "an approval that would break the rollup rolls back the proposal", ctx do
    repository =
      Fixture.repository!(ctx.world,
        directories: [%{name: "export", contents: "export", restrictions: [:export_controlled]}]
      )

    allow(ctx.rules, "dana", :propose_visibility, {:repository, repository.id})
    {:ok, proposal} = Proposals.propose(@dana, repository.id, %{restrictions: []})
    allow(ctx.rules, "eve", :approve_visibility, {:proposal, proposal.id})
    assert {:error, %Repositories.RollupViolation{}} = Proposals.approve(@eve, proposal.id)

    assert %Proposal{status: :pending} =
             Repo.get(Proposal, proposal.id, mediate: Fixture.exemption())
  end
end
