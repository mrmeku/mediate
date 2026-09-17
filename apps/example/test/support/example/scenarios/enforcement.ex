defmodule Example.Scenarios.Enforcement do
  @moduledoc "The enforcement scenarios, enf-01 to enf-18."

  use Boundary,
    top_level?: true,
    deps: [
      Example,
      Example.Fixture,
      Example.Scenarios.Support,
      Mediate,
      Mediate.Test,
      ExUnit
    ]

  import Example.Scenarios.Support
  import ExUnit.Assertions

  alias Example.Application.Repositories
  alias Example.Domain.Repository
  alias Example.Fixture
  alias Mediate.Test.Clock

  @spec enf_01() :: term()
  def enf_01 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    settle()
    assert_read(subject("ann"), repository)
  end

  @spec enf_02() :: term()
  def enf_02 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    settle()
    assert_denied(subject("frank"), repository)
  end

  @spec enf_03() :: term()
  def enf_03 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    settle()
    assert_read(subject("dana"), repository)
  end

  @spec enf_04() :: term()
  def enf_04 do
    world = Fixture.world!()
    repository = Fixture.repository!(world, restrictions: [:employees_only])

    settle()
    assert_read(subject("ann"), repository)
    assert_denied(subject("bob"), repository)
  end

  @spec enf_05() :: term()
  def enf_05 do
    world = Fixture.world!()
    repository = Fixture.repository!(world, restrictions: [:export_controlled])

    settle()
    assert_read(subject("ann"), repository)
    assert_denied(subject("carl"), repository)
  end

  @spec enf_06() :: term()
  def enf_06 do
    world = Fixture.world!()
    repository = Fixture.repository!(world, restrictions: [:releasable_to], releasable_to: ["FR", "GB"])

    settle()
    assert_read(subject("carl"), repository)
    assert_denied(subject("ann"), repository)
  end

  @spec enf_07() :: term()
  def enf_07 do
    world = Fixture.world!()
    repository = Fixture.repository!(world, restrictions: [:invite_only], invited: ["ann"])

    settle()
    assert_read(subject("ann"), repository)
    assert_denied(subject("bob"), repository)
  end

  @spec enf_08() :: term()
  def enf_08 do
    world = Fixture.world!()
    repository = Fixture.repository!(world, restrictions: [:employees_only, :export_controlled])

    settle()
    assert_read(subject("ann"), repository)
    assert_denied(subject("carl"), repository)
    assert_denied(subject("bob"), repository)
  end

  @spec enf_09() :: term()
  def enf_09 do
    world = Fixture.world!()
    repository = Fixture.repository!(world, labels: ["secrets"])
    assert repository.visibility.restrictions == []

    settle()
    assert_read(subject("ann"), repository)
    assert_denied(subject("bob"), repository)
    not_sensitive = Fixture.repository!(world, labels: ["docs"])

    settle()
    assert_read(subject("bob"), not_sensitive)
  end

  @spec enf_10() :: term()
  def enf_10 do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    settle()
    for id <- ["ann", "bob", "carl"], do: assert_read(subject(id), repository)
  end

  @spec enf_11() :: term()
  def enf_11 do
    world = Fixture.world!()

    repository =
      Fixture.repository!(world,
        directories: [
          %{name: "open", contents: "open"},
          %{name: "export", contents: "export", restrictions: [:export_controlled]}
        ]
      )

    [open, export] = repository.directories

    settle()
    assert_denied(subject("carl"), repository)
    assert {:ok, %Repository{directories: directories}} = Repositories.checkout(subject("carl"), repository.id)
    assert Enum.map(directories, & &1.id) == [open.id]
    assert {:ok, %Repository{directories: directories}} = Repositories.checkout(subject("ann"), repository.id)
    assert Enum.map(directories, & &1.id) == [open.id, export.id]
    assert_refused(Repositories.checkout(subject("frank"), repository.id), :checkout)
  end

  @spec enf_12() :: term()
  def enf_12 do
    world = Fixture.world!()

    repository =
      Fixture.repository!(world, directories: [%{name: "export", contents: "export", restrictions: [:export_controlled]}])

    dropped = %{restrictions: []}

    settle()

    assert {:error, %Repositories.RollupViolation{directories: %{restrictions: [:export_controlled]}}} =
             Repositories.change_visibility(subject("dana"), repository.id, dropped, fresh())

    assert {:ok, %Repository{visibility: %{restrictions: [:export_controlled]}}} =
             Repositories.read(subject("dana"), repository.id)

    wider = %{restrictions: [:export_controlled, :employees_only]}

    assert {:ok, %Example.Domain.Visibility{restrictions: restrictions}} =
             Repositories.change_visibility(subject("dana"), repository.id, wider, fresh())

    assert Enum.sort(restrictions) == [:employees_only, :export_controlled]
  end

  @spec enf_13() :: term()
  def enf_13 do
    world = Fixture.world!()
    past = DateTime.shift(DateTime.utc_now(), hour: -1)
    repository = Fixture.repository!(world, restrictions: [:employees_only], embargo: past)

    settle()
    assert_read(subject("bob"), repository)
  end

  @spec enf_14() :: term()
  def enf_14 do
    world = Fixture.world!()
    embargo = DateTime.utc_now(:second)
    repository = Fixture.repository!(world, restrictions: [:employees_only], embargo: embargo)
    _at = Clock.set(DateTime.shift(embargo, second: -1))

    settle()
    assert_denied(subject("bob"), repository)
    _at = Clock.set(DateTime.shift(embargo, second: 1))
    assert_read(subject("bob"), repository)
  end

  @spec enf_15() :: term()
  def enf_15 do
    world = Fixture.world!()
    past = DateTime.shift(DateTime.utc_now(), hour: -1)
    repository = Fixture.repository!(world, restrictions: [:employees_only], embargo: past)

    settle()
    assert_denied(subject("frank"), repository)
  end

  @spec enf_16() :: term()
  def enf_16 do
    world = Fixture.world!()
    repository = Fixture.repository!(world, restrictions: [:invite_only], invited: ["frank"])

    settle()
    assert_denied(subject("frank"), repository)
  end

  @spec enf_17() :: term()
  def enf_17 do
    world = Fixture.world!()
    acme = Fixture.repository!(world)
    globex = Fixture.repository!(world, project: world.other_project, team: world.other_team)

    settle()
    assert invited(subject("ann")) == [acme.id]
    refute reads?(subject("ann"), globex)
    assert invited(subject("ivan")) == [globex.id]
    assert_read(subject("ivan"), globex)
  end

  @spec enf_18() :: term()
  def enf_18 do
    world = Fixture.world!()

    repository =
      Fixture.repository!(world,
        directories: [
          %{name: "worldwide", contents: "worldwide", restrictions: [:releasable_to], releasable_to: ["FR", "US"]},
          %{name: "us_only", contents: "us_only", restrictions: [:releasable_to], releasable_to: ["US"]}
        ]
      )

    [worldwide, us_only] = repository.directories

    settle()
    assert_denied(subject("carl"), repository)
    assert {:ok, %Repository{directories: directories}} = Repositories.checkout(subject("carl"), repository.id)
    assert Enum.map(directories, & &1.id) == [worldwide.id]
    assert_read(subject("ann"), repository)
    assert {:ok, %Repository{directories: directories}} = Repositories.checkout(subject("ann"), repository.id)
    assert Enum.map(directories, & &1.id) == [worldwide.id, us_only.id]
  end

  defp invited(subject) do
    subject
    |> Repositories.list()
    |> Enum.map(& &1.id)
  end
end
