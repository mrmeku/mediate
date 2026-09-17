defmodule ExampleCerbos.CoverageTest do
  @moduledoc """
  Declared-fact coverage, `au12-07` in `docs/conformance.md`, over the example's rules:
  every column the rules of this binding read is a declared fact of the
  example.

  The rules reach the database as the `dynamic` a scope answers with. So the
  case asks for that `dynamic` for every account and for every object type a
  scope runs over, and gives it to `Mediate.Cerbos.Coverage`. A column no
  declaration covers fails the case with the column's name. A decision that
  depends on such a column rests on a fact no record of a change covers.
  """

  use ExUnit.Case, async: true

  import Ecto.Query, only: [from: 2]

  alias Example.Domain.Directory
  alias Example.Domain.Label
  alias Example.Domain.Membership
  alias Example.Domain.Repository
  alias Example.Domain.TeamRole
  alias Example.Domain.Visibility
  alias Example.Fixture
  alias ExampleCerbos.Infrastructure.Attributes
  alias Mediate.Cerbos.Coverage
  alias Mediate.Dev.Sandbox

  @scopes [{:read, :repository, Repository}, {:set_embargo, :repository, Repository}, {:read, :directory, Directory}]

  setup tags do
    :ok = Sandbox.setup(Example.Infrastructure.Repo, tags)
    world = Fixture.world!()

    repository =
      Fixture.repository!(world,
        labels: ["secrets"],
        restrictions: [:employees_only, :export_controlled, :invite_only, :releasable_to],
        releasable_to: ["US"],
        invited: ["ann"],
        directories: [
          %{name: "open", contents: "open"},
          %{name: "employees", contents: "employees", restrictions: [:employees_only]}
        ]
      )

    {:ok, world: world, repository: repository}
  end

  test "every column the rule of a scope reads is a declared fact" do
    for subject <- Fixture.subjects(), {operation, kind, schema} <- @scopes do
      {rule, _decision} = Mediate.scope(subject, operation, kind, fresh())
      query = from(row in schema, where: ^rule)

      assert Coverage.check(Attributes, query) == :ok,
             "#{elem(subject, 1)} #{operation} #{kind} reads #{inspect(Coverage.undeclared(Attributes, query))}"
    end
  end

  test "the walk reaches the columns the declared subqueries read" do
    {rule, _decision} = Mediate.scope(Fixture.subject("bob"), :read, :repository, fresh())
    query = from(d in Repository, where: ^rule)
    reads = Coverage.reads(query)

    assert {Membership, :role} in reads
    assert {TeamRole, :role} in reads
    assert {Visibility, :restrictions} in reads
    assert {Label, :implied_restrictions} in reads
    assert {Repository, :embargo} in reads
  end

  test "a column no declaration covers fails the case with the column's name" do
    query = from(d in Repository, where: d.name == "repository")

    assert Coverage.check(Attributes, query) == {:error, [{Repository, :name}]}
    assert_raise ArgumentError, ~r/name of Example.Domain.Repository/, fn -> Coverage.check!(Attributes, query) end
  end

  defp fresh, do: [env: %{reauthenticated_at: DateTime.utc_now()}]
end
