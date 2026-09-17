defmodule ExamplePostgres.WriteGateTest do
  @moduledoc """
  The defense-in-depth property this binding has and no other: the database
  refuses a visibility change that C7 refuses, whether or not the application
  asked. A gate carries no operation guard, so it holds whoever writes and
  whatever they asked first. The property is the binding's and not a rule of
  the example, so no scenario tests it.

  The write goes through the owner-role repo as a statement, not through the
  port. So nothing of the seam stands between it and the table.
  """

  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Example.Fixture
  alias Example.Infrastructure.OwnerRepo

  @update "UPDATE visibilities SET restrictions = ARRAY['employees_only'] WHERE repository_id = $1"

  setup do
    :ok = Sandbox.checkout(Example.Infrastructure.Repo, sandbox: false)
    :ok = Fixture.truncate!(OwnerRepo)
    on_exit(fn -> Fixture.truncate!(OwnerRepo) end)
    :ok
  end

  test "a C7-violating visibility change is refused by the database whether or not the application asked" do
    world = Fixture.world!()
    repository = Fixture.repository!(world)

    error = assert_raise Postgrex.Error, fn -> OwnerRepo.query!(@update, [repository.id]) end

    assert error.postgres.code == :insufficient_privilege
    assert error.postgres.message =~ "row-level security policy"
  end
end
