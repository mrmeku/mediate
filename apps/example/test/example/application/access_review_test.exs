defmodule Example.Application.ReviewTest do
  use Example.FakeCase, async: true

  alias Example.Application.AccessReview
  alias Example.Fixture

  @eve {:user, "eve"}

  test "readers and allowed come from Mediate per subject and action", ctx do
    repository = Fixture.repository!(ctx.world)
    globex = Fixture.repository!(ctx.world, project: ctx.world.other_project, team: ctx.world.other_team)
    allow(ctx.fake, "ann", :read, {:repository, repository.id})
    allow(ctx.fake, "ann", :read, {:repository, globex.id})
    allow(ctx.fake, "dana", :change_visibility, {:repository, repository.id})
    readers = AccessReview.readers(@eve, ctx.world.enterprise)
    assert readers[Fixture.subject("ann")] == [repository.id]
    assert readers[Fixture.subject("bob")] == []
    assert map_size(readers) == length(Fixture.account_ids())
    allowed = AccessReview.allowed(@eve, ctx.world.enterprise)
    assert allowed[Fixture.subject("dana")][:change_visibility] == [repository.id]
    assert allowed[Fixture.subject("dana")][:read] == []
    assert allowed[Fixture.subject("ann")][:read] == [repository.id]
    assert allowed[Fixture.subject("ann")][:approve_visibility] == []
  end

  test "the report lists readers and allowed actions per enterprise, then the privileged accounts", ctx do
    repository = Fixture.repository!(ctx.world)
    allow(ctx.fake, "ann", :read, {:repository, repository.id})
    allow(ctx.fake, "dana", :change_visibility, {:repository, repository.id})
    report = AccessReview.report(@eve)

    assert report ==
             Enum.join(
               ["enterprise Acme"] ++
                 for(
                   id <- Fixture.account_ids(),
                   do: "  #{id} reads #{if id == "ann", do: "[#{repository.id}]", else: "[]"}"
                 ) ++
                 for(
                   op <- AccessReview.actions(),
                   do: "  ann may #{op} #{if op == :read, do: "[#{repository.id}]", else: "[]"}"
                 ) ++
                 for(
                   op <- AccessReview.actions(),
                   do: "  dana may #{op} #{if op == :change_visibility, do: "[#{repository.id}]", else: "[]"}"
                 ) ++
                 ["enterprise Globex"] ++
                 for(id <- Fixture.account_ids(), do: "  #{id} reads []") ++
                 ["privileged accounts", "  gil (person gil) holds [override]"],
               "\n"
             ) <> "\n"
  end
end
