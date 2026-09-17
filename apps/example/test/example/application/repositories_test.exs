defmodule Example.Application.RepositoriesTest do
  use Example.FakeCase, async: true

  alias Example.Application.Repositories
  alias Example.Domain.Directory
  alias Example.Domain.Repository
  alias Example.Domain.Visibility
  alias Example.Fixture
  alias Mediate.Error

  @ann {:user, "ann"}
  @dana {:user, "dana"}
  @gil {:privileged, "gil"}

  setup %{world: world} do
    repository =
      Fixture.repository!(world,
        directories: [
          %{name: "open", contents: "open"},
          %{name: "export", contents: "export", restrictions: [:export_controlled]}
        ]
      )

    {:ok, repository: repository}
  end

  test "read returns the repository with its visibility under an allow, and the refusal under a deny", ctx do
    assert {:error, %Error{detail: "user ann may not read" <> _rest}} = Repositories.read(@ann, ctx.repository.id)
    allow(ctx.rules, "ann", :read, {:repository, ctx.repository.id})

    assert {:ok, %Repository{visibility: %Visibility{restrictions: [:export_controlled]}}} =
             Repositories.read(@ann, ctx.repository.id)

    assert {:error, %Error{detail: "user ann may not read" <> _rest}} = Repositories.read(@ann, ctx.repository.id + 1000)
    allow(ctx.rules, "ann", :read, {:repository, :any})
    assert {:error, :not_found} = Repositories.read(@ann, ctx.repository.id + 1000)
  end

  test "checkout returns the directories the directory scope admits", ctx do
    [open, export] = ctx.repository.directories
    allow(ctx.rules, "ann", :checkout, {:repository, ctx.repository.id})
    allow(ctx.rules, "ann", :read, {:directory, open.id})
    assert {:ok, %Repository{directories: [%Directory{id: id}]}} = Repositories.checkout(@ann, ctx.repository.id)
    assert id == open.id
    allow(ctx.rules, "ann", :read, {:directory, export.id})
    assert {:ok, %Repository{directories: [_open, _domestic]}} = Repositories.checkout(@ann, ctx.repository.id)
  end

  test "list returns what the repository scope admits, oldest first", ctx do
    other = Fixture.repository!(ctx.world, name: "other")
    assert Repositories.list(@ann) == []
    allow(ctx.rules, "ann", :read, {:repository, other.id})
    assert [%Repository{id: id, visibility: %Visibility{}}] = Repositories.list(@ann)
    assert id == other.id
    allow(ctx.rules, "ann", :read, {:repository, :any})
    assert Enum.map(Repositories.list(@ann), & &1.id) == [ctx.repository.id, other.id]
  end

  test "change_visibility keeps the rollup over the directories", ctx do
    allow(ctx.rules, "dana", :change_visibility, {:repository, ctx.repository.id})

    assert {:error, %Repositories.RollupViolation{directories: %{restrictions: [:export_controlled]}}} =
             Repositories.change_visibility(@dana, ctx.repository.id, %{restrictions: []})

    assert {:ok, %Visibility{restrictions: restrictions, labels: ["crypto"]}} =
             Repositories.change_visibility(@dana, ctx.repository.id, %{
               restrictions: [:employees_only, :export_controlled],
               labels: ["crypto"]
             })

    assert Enum.sort(restrictions) == [:employees_only, :export_controlled]

    assert {:error, %Error{detail: "user ann may not change_visibility" <> _rest}} =
             Repositories.change_visibility(@ann, ctx.repository.id, %{restrictions: []})
  end

  test "set_embargo and lift_embargo write the date under their own operations", ctx do
    at = ~U[2026-01-01 00:00:00.123456Z]

    assert {:error, %Error{detail: "user dana may not set_embargo" <> _rest}} =
             Repositories.set_embargo(@dana, ctx.repository.id, at)

    allow(ctx.rules, "dana", :set_embargo, {:repository, ctx.repository.id})

    assert {:ok, %Repository{embargo: ~U[2026-01-01 00:00:00Z]}} =
             Repositories.set_embargo(@dana, ctx.repository.id, at)

    assert {:error, %Error{detail: "user dana may not lift_embargo" <> _rest}} =
             Repositories.lift_embargo(@dana, ctx.repository.id)

    allow(ctx.rules, "dana", :lift_embargo, {:repository, ctx.repository.id})
    assert {:ok, %Repository{embargo: %DateTime{} = now}} = Repositories.lift_embargo(@dana, ctx.repository.id)
    assert DateTime.diff(DateTime.utc_now(), now, :second) in 0..5

    assert {:ok, _repository} = Repositories.set_embargo(@dana, ctx.repository.id, at)
    assert {:error, :not_found} = missing(ctx, at)
  end

  defp missing(ctx, at) do
    allow(ctx.rules, "dana", :set_embargo, {:repository, :any})
    allow(ctx.rules, "dana", :lift_embargo, {:repository, :any})
    assert {:error, :not_found} = Repositories.lift_embargo(@dana, ctx.repository.id + 1000)
    Repositories.set_embargo(@dana, ctx.repository.id + 1000, at)
  end

  test "change_directory_visibility needs the directory's and the repository's operation and recomputes the rollup",
       ctx do
    [open, _domestic] = ctx.repository.directories
    attrs = %{restrictions: [:employees_only]}

    assert {:error, %Error{detail: "user dana may not change_visibility {:directory," <> _rest}} =
             Repositories.change_directory_visibility(@dana, open.id, attrs)

    allow(ctx.rules, "dana", :change_visibility, {:directory, open.id})

    assert {:error, %Error{detail: "user dana may not change_visibility {:repository," <> _rest}} =
             Repositories.change_directory_visibility(@dana, open.id, attrs)

    allow(ctx.rules, "dana", :change_visibility, {:repository, ctx.repository.id})

    assert {:ok, %Directory{restrictions: [:employees_only]}} =
             Repositories.change_directory_visibility(@dana, open.id, attrs)

    allow(ctx.rules, "dana", :read, {:repository, ctx.repository.id})

    assert {:ok, %Repository{visibility: %Visibility{restrictions: restrictions}}} =
             Repositories.read(@dana, ctx.repository.id)

    assert Enum.sort(restrictions) == [:employees_only, :export_controlled]
    allow(ctx.rules, "dana", :change_visibility, {:directory, :any})
    assert {:error, :not_found} = Repositories.change_directory_visibility(@dana, open.id + 1000, attrs)
  end

  test "change_directory_visibility narrows the rollup to the countries every directory releases to", ctx do
    repository =
      Fixture.repository!(ctx.world,
        restrictions: [:releasable_to],
        releasable_to: ["FR", "US"],
        directories: [%{name: "open", contents: "open", restrictions: [:releasable_to], releasable_to: ["FR", "US"]}]
      )

    [directory] = repository.directories
    allow(ctx.rules, "dana", :change_visibility, {:directory, directory.id})
    allow(ctx.rules, "dana", :change_visibility, {:repository, repository.id})
    allow(ctx.rules, "dana", :read, {:repository, repository.id})
    attrs = %{restrictions: [:releasable_to], releasable_to: ["US"]}
    assert {:ok, %Directory{}} = Repositories.change_directory_visibility(@dana, directory.id, attrs)
    assert {:ok, %Repository{visibility: %Visibility{releasable_to: ["US"]}}} = Repositories.read(@dana, repository.id)
  end

  test "change_visibility refuses a rollup that releases to a country a directory withholds", ctx do
    repository =
      Fixture.repository!(ctx.world,
        restrictions: [:releasable_to],
        releasable_to: ["US"],
        directories: [%{name: "open", contents: "open", restrictions: [:releasable_to], releasable_to: ["US"]}]
      )

    allow(ctx.rules, "dana", :change_visibility, {:repository, repository.id})
    wider = %{restrictions: [:releasable_to], releasable_to: ["FR", "US"]}

    assert {:error, %Repositories.RollupViolation{directories: %{releasable_to: ["US"]}}} =
             Repositories.change_visibility(@dana, repository.id, wider)

    narrower = %{restrictions: [:releasable_to], releasable_to: []}
    assert {:ok, %Visibility{releasable_to: []}} = Repositories.change_visibility(@dana, repository.id, narrower)
  end

  test "override_read needs a privileged kind, a justification, and the permission, and reports itself", ctx do
    id = ctx.repository.id
    assert {:error, %Repositories.OverrideRefused{reason: :not_privileged}} = Repositories.override_read(@ann, id, "why")
    assert {:error, %Repositories.OverrideRefused{reason: :no_justification}} = Repositories.override_read(@gil, id, "")
    hana = {:privileged, "hana"}
    assert {:error, %Repositories.OverrideRefused{reason: :no_permission}} = Repositories.override_read(hana, id, "why")
    assert {:error, :not_found} = Repositories.override_read(@gil, id + 1000, "why")
    _ref = :telemetry_test.attach_event_handlers(self(), [Repositories.override_event()])

    assert {:ok, %Repository{id: ^id, visibility: %Visibility{}}} =
             Repositories.override_read(@gil, id, "why", operation_id: "op-1")

    assert_received {[:example, :override, :read], _ref, %{}, %{subject: %{id: "gil"}, report: report}}
    assert report.operation_id == "op-1"

    assert [%{user_id: "gil", justification: "why", operation_id: "op-1"}] =
             Repositories.override_reports(ctx.world.team.id)
  end

  test "operations and object references are as declared" do
    assert Repositories.operations() == [
             :read,
             :checkout,
             :change_visibility,
             :set_embargo,
             :lift_embargo,
             :propose_visibility
           ]

    assert Repositories.object(3) == {:repository, 3}
    assert Repositories.object(:directory, 4) == {:directory, 4}
    assert Repositories.override_event() == [:example, :override, :read]
  end
end
