defmodule Mediate.Conformance.RepoCaseTest.ExtraRepo do
  @moduledoc false
  use Ecto.Repo, otp_app: :mediate, adapter: Ecto.Adapters.Postgres
  use Mediate.Repo

  @doc false
  @spec extra(term()) :: term()
  def extra(x), do: x
end

defmodule Mediate.Conformance.RepoCaseTest.ReadOnlyRepo do
  @moduledoc false
  use Ecto.Repo, otp_app: :mediate, adapter: Ecto.Adapters.Postgres, read_only: true
  use Mediate.Repo
end

defmodule Mediate.Conformance.RepoCaseTest do
  use Mediate.Conformance.RepoCase,
    repo: Mediate.TestRepos.Sandboxed,
    rows: Mediate.Conformance.Fixture.Rows,
    async: true
end

defmodule Mediate.Conformance.RepoCaseTest.ReadOnly do
  @moduledoc false
  use Mediate.Conformance.RepoCase, repo: Mediate.Conformance.RepoCaseTest.ReadOnlyRepo, async: true

  alias Mediate.Conformance.RepoCase
  alias Mediate.Conformance.RepoCaseTest.ReadOnlyRepo

  setup_all do
    config = Application.get_env(:mediate, Mediate.TestRepos.Sandboxed)
    start_supervised!({ReadOnlyRepo, config})
    :ok
  end

  test "a read-only repo exports a subset of the surface and passes the surface assertion" do
    refute function_exported?(ReadOnlyRepo, :insert, 2)
    assert :ok = RepoCase.assert_surface(ReadOnlyRepo)
  end
end

defmodule Mediate.Conformance.RepoCase.SurfaceTest do
  use ExUnit.Case, async: true

  alias Mediate.Conformance.RepoCase
  alias Mediate.Conformance.RepoCaseTest.ExtraRepo

  test "a repo exporting a function outside the surface fails with the function's name and arity" do
    assert_raise ExUnit.AssertionError,
                 ~r/exports extra\/1, which the surface this build was written against does not classify/,
                 fn ->
                   RepoCase.assert_surface(ExtraRepo)
                 end
  end

  test "a repo without the seam fails the surface assertion" do
    assert_raise ExUnit.AssertionError, ~r/does not use Mediate.Repo/, fn -> RepoCase.assert_surface(Enum) end
  end
end
