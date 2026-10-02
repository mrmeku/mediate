defmodule ExampleOpenFGA.Infrastructure.MappingTest do
  @moduledoc """
  Holds `ExampleOpenFGA.Infrastructure.Mapping` to the four things a pass
  relies on. The case asks nothing of a server.
  """

  use Mediate.OpenFGA.MappingCase,
    async: true,
    mapping: ExampleOpenFGA.Infrastructure.Mapping,
    repo: Example.Infrastructure.Repo,
    population: ExampleOpenFGA.Population,
    setup: Mediate.Dev.Sandbox

  import Ecto.Query, only: [from: 2]

  alias Example.Domain.Project
  alias Example.Domain.Repository
  alias Example.Infrastructure.Repo
  alias ExampleOpenFGA.Infrastructure.Mapping
  alias Mediate.OpenFGA.TupleKey

  @exemption {:exempt, "mapping test: the rows a tuple is read from"}

  test "a restriction the rollup carries is the wildcard on the relation named for it, under the repository's embargo" do
    tuples = Mapping.tuples(Repo, "repository:#{repository("restricted")}")
    restrictions = for %TupleKey{user: "user:*"} = tuple <- tuples, do: {tuple.relation, tuple.condition.name}

    assert Enum.sort(restrictions) == [
             {"country_applies", "under_embargo"},
             {"export_applies", "under_embargo"},
             {"invite_applies", "under_embargo"}
           ]
  end

  test "a repository with no embargo date requires its tuples with no condition" do
    tuples = Mapping.tuples(Repo, "repository:#{repository("plain")}")

    assert Enum.all?(tuples, &(&1.condition == nil))
  end

  test "a directory takes the embargo date from the repository it belongs to" do
    id = repository("restricted")
    labels = for %TupleKey{relation: "label"} = tuple <- Mapping.tuples(Repo, "repository:#{id}"), do: tuple
    directories = for object <- Mapping.objects(Repo, "directory"), do: Mapping.tuples(Repo, object)
    conditions = for tuple <- List.flatten(directories), tuple.relation == "label", do: tuple.condition

    assert conditions != []
    assert Enum.all?(conditions, &(&1 == hd(labels).condition))
  end

  test "an archived project requires no tuple, and no membership to it requires one" do
    assert Mapping.tuples(Repo, "project:#{archived()}") == []
  end

  test "an account's country and its employment are each membership of an object of its own" do
    tuples = Mapping.tuples(Repo, "country:FR") ++ Mapping.tuples(Repo, "employment:contractor")

    assert Enum.sort(Enum.map(tuples, & &1.user)) == ["user:bob", "user:carl", "user:ivan"]
    assert Enum.all?(tuples, &(&1.relation == "member"))
  end

  defp repository(name) do
    query = from(repository in Repository, where: repository.name == ^name, select: repository.id)

    Repo.one!(query, authorized_by: @exemption)
  end

  defp archived do
    query = from(project in Project, where: not is_nil(project.archived_at), select: project.id)

    Repo.one!(query, authorized_by: @exemption)
  end
end
