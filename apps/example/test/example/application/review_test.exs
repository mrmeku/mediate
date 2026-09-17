defmodule Example.Application.ReviewTest do
  use Example.FakeCase, async: true

  alias Example.Application.Review
  alias Example.Fixture

  @eve {:user, "eve"}

  test "readers and permissions come from the port per subject and operation", ctx do
    repository = Fixture.repository!(ctx.world)
    globex = Fixture.repository!(ctx.world, project: ctx.world.other_project, team: ctx.world.other_team)
    allow(ctx.rules, "ann", :read, {:repository, repository.id})
    allow(ctx.rules, "ann", :read, {:repository, globex.id})
    allow(ctx.rules, "dana", :change_visibility, {:repository, repository.id})
    readers = Review.readers(@eve, ctx.world.enterprise)
    assert readers[Fixture.subject("ann")] == [repository.id]
    assert readers[Fixture.subject("bob")] == []
    assert map_size(readers) == length(Fixture.account_ids())
    permissions = Review.permissions(@eve, ctx.world.enterprise)
    assert permissions[Fixture.subject("dana")][:change_visibility] == [repository.id]
    assert permissions[Fixture.subject("dana")][:read] == []
    assert permissions[Fixture.subject("ann")][:read] == [repository.id]
    assert permissions[Fixture.subject("ann")][:approve_visibility] == []
  end

  test "the report lists readers and permissions per enterprise, then the privileged accounts", ctx do
    repository = Fixture.repository!(ctx.world)
    allow(ctx.rules, "ann", :read, {:repository, repository.id})
    allow(ctx.rules, "dana", :change_visibility, {:repository, repository.id})
    report = Review.report(@eve)

    assert report ==
             Enum.join(
               ["enterprise Acme"] ++
                 for(
                   id <- Fixture.account_ids(),
                   do: "  #{id} reads #{if id == "ann", do: "[#{repository.id}]", else: "[]"}"
                 ) ++
                 for(
                   op <- Review.operations(),
                   do: "  ann may #{op} #{if op == :read, do: "[#{repository.id}]", else: "[]"}"
                 ) ++
                 for(
                   op <- Review.operations(),
                   do: "  dana may #{op} #{if op == :change_visibility, do: "[#{repository.id}]", else: "[]"}"
                 ) ++
                 ["enterprise Globex"] ++
                 for(id <- Fixture.account_ids(), do: "  #{id} reads []") ++
                 ["privileged accounts", "  gil (person gil) holds [override]"],
               "\n"
             ) <> "\n"
  end
end
