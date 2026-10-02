defmodule ExamplePostgres.Infrastructure.PolicyTest do
  @moduledoc """
  Every column a rule of this deployment reads is a declared fact of the
  example. `Mediate.Postgres.Facts` says how the check reads the rules back,
  and `docs/conformance.md` names it `au12-07`.
  """

  use ExUnit.Case, async: true

  alias Example.Infrastructure.Repo
  alias ExamplePostgres.Infrastructure.Policy
  alias Mediate.Config
  alias Mediate.Dev.Sandbox
  alias Mediate.Postgres.Binding
  alias Mediate.Postgres.Catalog
  alias Mediate.Postgres.Facts

  setup tags do
    Sandbox.setup(Repo, tags)
  end

  test "every column a rule reads is a declared fact of the example" do
    assert {:ok, %Binding{} = binding} = Binding.resolve()
    assert Facts.check(binding) == :ok, "the rules read #{inspect(Facts.undeclared(binding))}"
  end

  test "the boot names the engine, the policy module's schemas and the repo" do
    assert {:ok, %Config{} = config} = Config.resolve()
    assert Config.engine(config) == {Mediate.Postgres, []}
    assert {:ok, %Binding{repo: Repo, schemas: schemas}} = Binding.resolve()
    assert schemas == Policy.schemas()
  end

  test "the catalog holds the policy version the policy migration declares" do
    assert {:ok, %Binding{} = binding} = Binding.resolve()
    assert {:ok, %Catalog{policy_version: "20260909000005"}} = Catalog.resolve(binding)
  end
end
