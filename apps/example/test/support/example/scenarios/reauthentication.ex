defmodule Example.Scenarios.Reauthentication do
  @moduledoc "The re-authentication scenarios, ia-01 to ia-03."

  use Boundary,
    top_level?: true,
    deps: [Example, Example.Fixture, Example.Scenarios.Support, Mediate, Mediate.Test, ExUnit]

  import Example.Scenarios.Support
  import ExUnit.Assertions

  alias Example.Application.Repositories
  alias Example.Domain.Repository
  alias Example.Domain.Visibility
  alias Example.Fixture

  @export %{restrictions: [:export_controlled]}

  @spec ia_01() :: term()
  def ia_01 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    sync()

    assert {:ok, %Visibility{restrictions: [:export_controlled]}} =
             Repositories.change_visibility(subject("dana"), repository.id, @export, fresh_session())
  end

  @spec ia_02() :: term()
  def ia_02 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    sync()

    assert_refused(
      Repositories.change_visibility(subject("dana"), repository.id, @export, stale_session()),
      :change_visibility
    )

    assert {:ok, %Repository{visibility: %{restrictions: []}}} =
             Repositories.read(subject("dana"), repository.id, stale_session())

    assert {:ok, %Visibility{restrictions: [:export_controlled]}} =
             Repositories.change_visibility(subject("dana"), repository.id, @export, fresh_session())
  end

  @spec ia_03() :: term()
  def ia_03 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    sync()
    assert_refused(Repositories.change_visibility(subject("dana"), repository.id, @export), :change_visibility)

    assert_refused(
      Repositories.change_visibility(subject("dana"), repository.id, @export, context: %{}),
      :change_visibility
    )

    assert {:ok, %Repository{visibility: %{restrictions: []}}} = Repositories.read(subject("dana"), repository.id)
  end
end
