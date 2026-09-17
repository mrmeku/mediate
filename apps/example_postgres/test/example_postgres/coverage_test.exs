defmodule ExamplePostgres.CoverageTest do
  @moduledoc """
  Declared-fact coverage over the example's policies: every column the policies of
  this binding read is a declared fact of the example.
  `Mediate.Postgres.Coverage` says how the check reads the policies back,
  and `docs/conformance.md` names it `au12-07`.
  """

  use ExUnit.Case, async: true

  alias Mediate.Dev.Sandbox
  alias Mediate.Postgres.Binding
  alias Mediate.Postgres.Coverage

  setup tags do
    Sandbox.setup(Example.Infrastructure.Repo, tags)
  end

  test "every column the policies read is a declared fact" do
    assert {:ok, %Binding{} = binding} = Binding.resolve()
    assert Coverage.check(binding) == :ok, "the policies read #{inspect(Coverage.undeclared(binding))}"
  end
end
