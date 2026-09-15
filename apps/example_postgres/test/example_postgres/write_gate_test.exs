defmodule ExamplePostgres.WriteGateTest do
  @moduledoc """
  The defense-in-depth property this binding has and no other: the database
  refuses a marking change that C7 refuses, whether or not the application
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

  @update "UPDATE markings SET controls = ARRAY['federal_only'] WHERE document_id = $1"

  setup do
    :ok = Sandbox.checkout(Example.Infrastructure.Repo, sandbox: false)
    :ok = Fixture.truncate!(OwnerRepo)
    on_exit(fn -> Fixture.truncate!(OwnerRepo) end)
    :ok
  end

  test "a C7-violating marking change is refused by the database whether or not the application asked" do
    world = Fixture.world!()
    document = Fixture.document!(world)

    error = assert_raise Postgrex.Error, fn -> OwnerRepo.query!(@update, [document.id]) end

    assert error.postgres.code == :insufficient_privilege
    assert error.postgres.message =~ "row-level security policy"
  end
end
