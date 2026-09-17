defmodule Example.Scenarios.Revocation do
  @moduledoc "The revocation scenarios, rev-01 to rev-06."

  use Boundary,
    top_level?: true,
    deps: [Example, Example.Fixture, Example.Scenarios.Support, Mediate, Mediate.Test, ExUnit]

  import Example.Scenarios.Support
  import ExUnit.Assertions

  alias Example.Application.Accounts
  alias Example.Domain.Membership
  alias Example.Domain.Project
  alias Example.Domain.Repository
  alias Example.Fixture
  alias Example.Infrastructure.Repo

  @spec rev_01() :: term()
  def rev_01 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    settle()
    assert_read(subject("ann"), repository)
    started = System.monotonic_time(:millisecond)
    assert 1 = Accounts.unassign("ann", world.project.id)
    committed = System.monotonic_time(:millisecond)
    settled = settle()
    polled = System.monotonic_time(:millisecond)
    assert Mediate.Test.poll(fn -> not reads?(subject("ann"), repository) end)
    finished = System.monotonic_time(:millisecond)

    latency_report(
      total: finished - started,
      commit: committed - started,
      drain: drain(settled, polled - committed),
      poll: finished - polled
    )

    assert_denied(subject("ann"), repository)
  end

  @spec rev_02() :: term()
  def rev_02 do
    world = Fixture.world!()
    repository = Fixture.repository!(world, restrictions: [:invite_only], invited: ["ann", "bob"])

    settle()
    assert_read(subject("bob"), repository)
    _visibility = Fixture.set_invited!(repository, ["ann"])

    settle()
    assert_denied(subject("bob"), repository)
    assert_read(subject("ann"), repository)
  end

  @spec rev_03() :: term()
  def rev_03 do
    world = Fixture.world!()
    repository = Fixture.repository!(world, restrictions: [:employees_only])

    settle()
    assert_read(subject("ann"), repository)
    _user = Accounts.set_employment("ann", :contractor)

    settle()
    assert_denied(subject("ann"), repository)
  end

  @spec rev_04() :: term()
  def rev_04 do
    world = Fixture.world!()
    repository = Fixture.repository!(world, restrictions: [:export_controlled])

    settle()
    assert_denied(subject("carl"), repository)
    _user = Accounts.set_country("carl", "US")

    settle()
    assert_read(subject("carl"), repository)
    _user = Accounts.set_country("ann", "FR")

    settle()
    assert_denied(subject("ann"), repository)
  end

  @spec rev_05() :: term()
  def rev_05 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    settle()
    for id <- ["ann", "bob", "carl"], do: assert_read(subject(id), repository)
    _project = Fixture.archive_project!(world.project)

    settle()
    for id <- ["ann", "bob", "carl"], do: assert_denied(subject(id), repository)
    assert_read(subject("dana"), repository)
  end

  @spec rev_06() :: term()
  def rev_06 do
    {world, written} = Mediate.Test.changes(&Fixture.world!/0)
    repository = Fixture.repository!(world)

    settle()
    assert_read(subject("ann"), repository)

    {removed, revoked} = Mediate.Test.changes(fn -> Accounts.unassign("ann", world.project.id) end)
    assert removed == 1

    settle()
    assert_denied(subject("ann"), repository)

    assert_kept(world, repository)
    assert_paired(written, revoked)
  end

  # A revoke takes the membership away and leaves the repository and the
  # project where they were.
  defp assert_kept(world, repository) do
    assert %Repository{} = Repo.get(Repository, repository.id, mediate: Fixture.exemption())
    assert %Project{} = Repo.get(Project, world.project.id, mediate: Fixture.exemption())
  end

  # The revoke names the membership the grant created, so the two change
  # events read as one row's life.
  defp assert_paired(written, revoked) do
    assert [%{operation: :delete, target: target}] = memberships(revoked)
    assert Enum.any?(memberships(written), &(&1.operation == :create and &1.target == target))
  end

  defp memberships(changes), do: for(%{schema: Membership} = change <- changes, do: change)

  # The share of the latency the engine's own store took, where there was
  # one to wait for.
  defp drain(:none, _milliseconds), do: nil
  defp drain(:ok, milliseconds), do: milliseconds
end
