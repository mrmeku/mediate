defmodule Example.Scenarios.Identity do
  @moduledoc "The re-authentication and emergency-override scenarios, ia-01 to ia-03 and ovr-01 to ovr-03."

  use Boundary,
    top_level?: true,
    deps: [Example, Example.Fixture, Example.Scenarios.Support, Mediate, Mediate.Test, ExUnit]

  import Example.Scenarios.Support
  import ExUnit.Assertions

  alias Example.Application.Repositories
  alias Example.Domain.Repository
  alias Example.Domain.Visibility
  alias Example.Fixture
  alias Mediate.Id

  @export %{restrictions: [:export_controlled]}

  @spec ia_01() :: term()
  def ia_01 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    settle()

    assert {:ok, %Visibility{restrictions: [:export_controlled]}} =
             Repositories.change_visibility(subject("dana"), repository.id, @export, fresh())
  end

  @spec ia_02() :: term()
  def ia_02 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    settle()
    assert_refused(Repositories.change_visibility(subject("dana"), repository.id, @export, stale()), :change_visibility)

    assert {:ok, %Repository{visibility: %{restrictions: []}}} =
             Repositories.read(subject("dana"), repository.id, stale())

    assert {:ok, %Visibility{restrictions: [:export_controlled]}} =
             Repositories.change_visibility(subject("dana"), repository.id, @export, fresh())
  end

  @spec ia_03() :: term()
  def ia_03 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    settle()
    assert_refused(Repositories.change_visibility(subject("dana"), repository.id, @export), :change_visibility)
    assert_refused(Repositories.change_visibility(subject("dana"), repository.id, @export, env: %{}), :change_visibility)
    assert {:ok, %Repository{visibility: %{restrictions: []}}} = Repositories.read(subject("dana"), repository.id)
  end

  @spec ovr_01() :: term()
  def ovr_01 do
    world = Fixture.world!()
    repository = Fixture.repository!(world, restrictions: [:invite_only], invited: ["frank"])
    gil = subject("gil")

    settle()
    assert_denied(gil, repository)
    operation_id = Id.new()
    _ref = :telemetry_test.attach_event_handlers(self(), [Repositories.override_event()])

    assert {:ok, %Repository{id: id}} =
             Repositories.override_read(gil, repository.id, "incident 12", operation_id: operation_id)

    assert id == repository.id
    event = Repositories.override_event()
    assert_received {^event, _ref, %{}, %{subject: %{id: "gil", type: "privileged"}, report: report}}
    assert report.operation_id == operation_id
    assert report.justification == "incident 12"

    assert [%{user_id: "gil", repository_id: ^id, justification: "incident 12"}] =
             Repositories.override_reports(world.team.id)

    assert Repositories.override_reports(world.other_team.id) == []
  end

  @spec ovr_02() :: term()
  def ovr_02 do
    world = Fixture.world!()
    repository = Fixture.repository!(world, restrictions: [:invite_only], invited: ["frank"])
    gil = subject("gil")

    settle()

    assert {:error, %Repositories.OverrideRefused{reason: :no_justification}} =
             Repositories.override_read(gil, repository.id, "")

    assert {:error, %Repositories.OverrideRefused{reason: :no_justification}} =
             Repositories.override_read(gil, repository.id, nil)

    assert Repositories.override_reports(world.team.id) == []
  end

  @spec ovr_03() :: term()
  def ovr_03 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)
    gil = subject("gil")

    settle()
    assert {:ok, %Repository{}} = Repositories.override_read(gil, repository.id, "incident 12")
    assert_refused(Repositories.change_visibility(gil, repository.id, @export, fresh()), :change_visibility)
    assert_refused(Repositories.lift_embargo(gil, repository.id, fresh()), :lift_embargo)
    refute Mediate.check(gil, :change_visibility, Repositories.object(repository.id), fresh())
    assert {:ok, %Repository{visibility: %{restrictions: []}}} = Repositories.read(subject("dana"), repository.id)
  end
end
