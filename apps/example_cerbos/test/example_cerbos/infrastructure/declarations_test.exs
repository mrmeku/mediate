defmodule ExampleCerbos.Infrastructure.DeclarationsTest do
  @moduledoc """
  Every column a plan of this deployment reads is a declared fact of the
  example. `Mediate.Cerbos.Facts` says how the check walks a plan, and
  `docs/conformance.md` names it `au12-07`.

  A plan reaches the database as the `dynamic` a filter answers with. So
  the test asks for that `dynamic` for every account and for every
  resource type a filter runs over, and gives it to the check. A column no
  declaration covers fails with the column's name. A decision that depends
  on such a column rests on a fact no record of a change covers.
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
  alias Example.Infrastructure.Repo
  alias ExampleCerbos.Infrastructure.Declarations
  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Facts
  alias Mediate.Cerbos.Version
  alias Mediate.Config
  alias Mediate.Dev.Sandbox

  @filters [{:read, :repository, Repository}, {:set_embargo, :repository, Repository}, {:read, :directory, Directory}]

  setup tags do
    :ok = Sandbox.setup(Repo, tags)
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

  test "every column a plan reads is a declared fact of the example" do
    {:ok, binding} = Binding.resolve()

    for subject <- Fixture.subjects(), {action, type, schema} <- @filters do
      {rule, _decision} = Mediate.filter(subject, action, type, fresh_session())
      query = from(row in schema, where: ^rule)

      assert Facts.check(binding, query) == :ok,
             "#{elem(subject, 1)} #{action} #{type} reads #{inspect(Facts.undeclared(binding, query))}"
    end
  end

  test "the check follows a subquery attribute into the columns it reads" do
    {rule, _decision} = Mediate.filter(Fixture.subject("bob"), :read, :repository, fresh_session())
    query = from(r in Repository, where: ^rule)
    reads = Facts.reads(query)

    assert {Membership, :role} in reads
    assert {TeamRole, :role} in reads
    assert {Visibility, :restrictions} in reads
    assert {Label, :implied_restrictions} in reads
    assert {Repository, :embargo} in reads
  end

  test "a column no declaration covers fails with the declarations module and the column named" do
    {:ok, binding} = Binding.resolve()
    query = from(r in Repository, where: r.name == "repository")

    assert Facts.check(binding, query) == {:error, [{Repository, :name}]}
    assert_raise ArgumentError, ~r/name of Example.Domain.Repository/, fn -> Facts.check!(binding, query) end
  end

  test "the boot names the engine, the declarations, the policy directory and the commit" do
    assert {:ok, %Config{} = config} = Config.resolve()
    assert {Mediate.Cerbos, address: _address} = Config.engine(config)
    assert {:ok, %Binding{repo: Repo, declarations: Declarations} = binding} = Binding.resolve()
    assert File.dir?(binding.policy_dir)
    assert Version.policy_version(binding) == Application.fetch_env!(:example_cerbos, :commit)
  end

  defp fresh_session, do: [context: %{reauthenticated_at: DateTime.utc_now()}]
end
