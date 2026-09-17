defmodule ExampleFga.Infrastructure.TupleMappingTest do
  @moduledoc """
  Holds `ExampleFga.Infrastructure.TupleMapping` to the four things a pass
  relies on. The case asks nothing of a server.
  """

  use Mediate.Fga.TupleMappingCase,
    async: true,
    mapping: ExampleFga.Infrastructure.TupleMapping,
    repo: Example.Infrastructure.Repo,
    population: ExampleFga.Population,
    sandbox: Mediate.Dev.Sandbox

  import Ecto.Query, only: [from: 2]

  alias Example.Domain.Project
  alias Example.Domain.Repository
  alias Example.Infrastructure.Repo
  alias ExampleFga.Infrastructure.TupleMapping
  alias Mediate.Fga.TupleKey

  @exemption {:exempt, "tuple mapping test: the rows a tuple is read from"}

  test "a restriction the rollup carries is the wildcard on the relation named for it, under the repository's embargo" do
    tuples = TupleMapping.tuples(Repo, "repository:#{repository("restricted")}")
    flags = for %TupleKey{user: "user:*"} = tuple <- tuples, do: {tuple.relation, tuple.condition.name}

    assert Enum.sort(flags) == [
             {"export_applies", "under_embargo"},
             {"invite_applies", "under_embargo"},
             {"regions_applies", "under_embargo"}
           ]
  end

  test "a repository with no embargo date states its tuples plain" do
    tuples = TupleMapping.tuples(Repo, "repository:#{repository("plain")}")

    assert Enum.all?(tuples, &(&1.condition == nil))
  end

  test "a directory carries the embargo date of the repository it belongs to" do
    id = repository("restricted")
    carried = for %TupleKey{relation: "label"} = tuple <- TupleMapping.tuples(Repo, "repository:#{id}"), do: tuple
    directories = for object <- TupleMapping.objects(Repo, "directory"), do: TupleMapping.tuples(Repo, object)
    conditions = for tuple <- List.flatten(directories), tuple.relation == "label", do: tuple.condition

    assert conditions != []
    assert Enum.all?(conditions, &(&1 == hd(carried).condition))
  end

  test "an archived project requires no tuple, and every membership to it stops holding one" do
    assert TupleMapping.tuples(Repo, "project:#{archived()}") == []
  end

  test "an account's country and its employment are membership of objects of their own" do
    tuples = TupleMapping.tuples(Repo, "country:FR") ++ TupleMapping.tuples(Repo, "employment:contractor")

    assert Enum.sort(Enum.map(tuples, & &1.user)) == ["user:bob", "user:carl", "user:ivan"]
    assert Enum.all?(tuples, &(&1.relation == "member"))
  end

  defp repository(name) do
    query = from(repository in Repository, where: repository.name == ^name, select: repository.id)

    Repo.one!(query, mediate: @exemption)
  end

  defp archived do
    query = from(project in Project, where: not is_nil(project.archived_at), select: project.id)

    Repo.one!(query, mediate: @exemption)
  end
end
