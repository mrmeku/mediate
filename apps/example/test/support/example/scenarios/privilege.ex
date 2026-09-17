defmodule Example.Scenarios.Privilege do
  @moduledoc "The least-privilege and separation-of-duties scenarios, lp-01 to lp-08 and sod-01 to sod-03."

  use Boundary,
    top_level?: true,
    deps: [Example, Example.Fixture, Example.Scenarios.Support, Mediate, Mediate.Test, Ecto, ExUnit]

  import Example.Scenarios.Support
  import ExUnit.Assertions

  alias Example.Application.Accounts
  alias Example.Application.Proposals
  alias Example.Application.Repositories
  alias Example.Application.Review
  alias Example.Domain.Proposal
  alias Example.Domain.Repository
  alias Example.Fixture

  @export %{restrictions: [:export_controlled]}

  @spec lp_01() :: term()
  def lp_01 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    settle()
    assert_read(subject("ann"), repository)
    assert_refused(Repositories.change_visibility(subject("ann"), repository.id, @export, fresh()), :change_visibility)
    assert {:ok, %Repository{visibility: %{restrictions: []}}} = Repositories.read(subject("ann"), repository.id)
  end

  @spec lp_02() :: term()
  def lp_02 do
    world = Fixture.world!()
    globex = Fixture.repository!(world, project: world.other_project, team: world.other_team)

    settle()
    assert_refused(Repositories.change_visibility(subject("dana"), globex.id, @export, fresh()), :change_visibility)
    acme = Fixture.repository!(world)

    settle()
    assert_refused(Repositories.change_visibility(subject("hana"), acme.id, @export, fresh()), :change_visibility)
    assert {:ok, %Repository{visibility: %{restrictions: []}}} = Repositories.read(subject("dana"), acme.id)
  end

  @spec lp_03() :: term()
  def lp_03 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    settle()

    assert {:ok, %Example.Domain.Visibility{restrictions: [:export_controlled]}} =
             Repositories.change_visibility(subject("dana"), repository.id, @export, fresh())

    settle()

    assert {:ok, %Repository{visibility: %{restrictions: [:export_controlled]}}} =
             Repositories.read(subject("dana"), repository.id)
  end

  @spec lp_04() :: term()
  def lp_04 do
    world = Fixture.world!()
    repository = Fixture.repository!(world, restrictions: [:employees_only])
    at = DateTime.shift(DateTime.utc_now(), minute: -1)

    settle()
    assert_refused(Repositories.set_embargo(subject("ann"), repository.id, at, fresh()), :set_embargo)
    assert_refused(Repositories.lift_embargo(subject("eve"), repository.id, fresh()), :lift_embargo)
    assert_denied(subject("bob"), repository)

    assert {:ok, %Repository{embargo: %DateTime{}}} =
             Repositories.set_embargo(subject("dana"), repository.id, at, fresh())

    settle()
    assert_read(subject("bob"), repository)
  end

  @spec lp_05() :: term()
  def lp_05 do
    world = Fixture.world!()
    repository = Fixture.repository!(world, directories: [%{name: "open", contents: "open"}])
    [directory] = repository.directories
    tightened = %{restrictions: [:export_controlled]}

    settle()

    for id <- ["ann", "eve", "hana"] do
      assert_refused(
        Repositories.change_directory_visibility(subject(id), directory.id, tightened, fresh()),
        :change_visibility
      )
    end

    assert {:ok, %Example.Domain.Directory{restrictions: [:export_controlled]}} =
             Repositories.change_directory_visibility(subject("dana"), directory.id, tightened, fresh())

    settle()

    assert {:ok, %Repository{visibility: %{restrictions: [:export_controlled]}}} =
             Repositories.read(subject("dana"), repository.id)
  end

  @spec lp_06() :: term()
  def lp_06 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    settle()
    assert_denied(subject("frank"), repository)

    assert {:error, %Repositories.OverrideRefused{reason: :not_privileged}} =
             Repositories.override_read(subject("frank"), repository.id, "incident 12")

    assert Repositories.override_reports(world.team.id) == []
  end

  @spec lp_07() :: term()
  def lp_07 do
    world = Fixture.world!()
    repository = Fixture.repository!(world, restrictions: [:invite_only], invited: ["frank"])
    ordinary = subject("gil-user")
    assert {:user, _id} = ordinary

    settle()
    assert_denied(ordinary, repository)

    assert {:error, %Repositories.OverrideRefused{reason: :not_privileged}} =
             Repositories.override_read(ordinary, repository.id, "incident 12")

    assert {:ok, %Repository{}} = Repositories.override_read(subject("gil"), repository.id, "incident 12")
    assert [%{user_id: "gil"}] = Repositories.override_reports(world.team.id)
  end

  @spec lp_08() :: term()
  def lp_08 do
    world = Fixture.world!()
    repository = Fixture.repository!(world, restrictions: [:employees_only])

    settle()
    report = Review.report(subject("eve"), fresh())
    assert report =~ "enterprise Acme"
    assert report =~ "ann reads [#{repository.id}]"
    assert report =~ "bob reads []"
    assert report =~ "dana may change_visibility [#{repository.id}]"
    assert report =~ "ann may change_visibility []"
    assert report =~ "eve may change_visibility []"
    assert report =~ "privileged accounts"
    assert report =~ "gil (person gil) holds [override]"
    refute report =~ "gil-user (person"
  end

  @spec sod_01() :: term()
  def sod_01 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    settle()
    assert {:ok, proposal} = Proposals.propose(subject("dana"), repository.id, @export, fresh())

    settle()

    assert {:ok, %Proposal{status: :approved, reviewer_id: "eve"}} =
             Proposals.approve(subject("eve"), proposal.id, fresh())

    settle()

    assert {:ok, %Repository{visibility: %{restrictions: [:export_controlled]}}} =
             Repositories.read(subject("dana"), repository.id)

    assert {:error, :not_found} = Proposals.approve(subject("eve"), proposal.id, fresh())
  end

  @spec sod_02() :: term()
  def sod_02 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)
    _role = Accounts.team_role("dana", world.team.id, :reviewer)

    refute_own_approval(repository)
    assert_approval_of_another(world, repository)
  end

  @spec sod_03() :: term()
  def sod_03 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    settle()
    assert {:ok, %Proposal{status: :pending}} = Proposals.propose(subject("dana"), repository.id, @export, fresh())

    settle()
    assert {:ok, %Repository{visibility: %{restrictions: []}}} = Repositories.read(subject("dana"), repository.id)
    assert_read(subject("carl"), repository)
  end

  # An account with both roles cannot approve what it proposed. The port
  # refuses the approval, and the visibility stays where it was.
  defp refute_own_approval(repository) do
    settle()
    assert {:ok, proposal} = Proposals.propose(subject("dana"), repository.id, @export, fresh())

    settle()
    assert_refused(Proposals.approve(subject("dana"), proposal.id, fresh()), :approve_visibility)
    assert {:ok, %Repository{visibility: %{restrictions: []}}} = Repositories.read(subject("dana"), repository.id)
  end

  # The same account approves what another proposed. So it holds the role,
  # and what it lacks is the standing to approve its own proposal.
  defp assert_approval_of_another(world, repository) do
    _role = Accounts.team_role("eve", world.team.id, :admin)

    settle()
    assert {:ok, other} = Proposals.propose(subject("eve"), repository.id, %{restrictions: [:employees_only]}, fresh())

    settle()

    assert {:ok, %Proposal{status: :approved, reviewer_id: "dana"}} =
             Proposals.approve(subject("dana"), other.id, fresh())
  end
end
