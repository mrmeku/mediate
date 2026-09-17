defmodule Mediate.Infrastructure.SurfaceTest.ExtraRepo do
  @moduledoc false
  use Ecto.Repo, otp_app: :mediate, adapter: Ecto.Adapters.Postgres
  use Mediate.Repo

  @doc false
  @spec extra(term()) :: term()
  def extra(x), do: x
end

defmodule Mediate.Infrastructure.SurfaceTest.ReadOnlyRepo do
  @moduledoc false
  use Ecto.Repo, otp_app: :mediate, adapter: Ecto.Adapters.Postgres, read_only: true
  use Mediate.Repo
end

defmodule Mediate.Infrastructure.SurfaceTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Mediate.Infrastructure.Surface
  alias Mediate.Infrastructure.SurfaceTest.ExtraRepo
  alias Mediate.Infrastructure.SurfaceTest.ReadOnlyRepo
  alias Mediate.TestRepos.Owner
  alias Mediate.TestRepos.Sandboxed

  test "every surface entry sits in exactly one bucket and the buckets cover the pinned Ecto's exports" do
    all = Surface.all()
    assert Enum.uniq_by(all, fn {name, arity, _bucket} -> {name, arity} end) == all
    exported = Enum.sort(Sandboxed.__info__(:functions))

    assert exported ==
             all
             |> Enum.map(fn {n, a, _b} -> {n, a} end)
             |> Enum.sort()

    assert Surface.bucket(:all, 2) == :query
    assert Surface.bucket(:insert, 2) == :write
    assert Surface.bucket(:query, 3) == :raw
    assert Surface.bucket(:transaction, 2) == :plumbing
    assert Surface.bucket(:extra, 1) == nil
  end

  test "the seam overrides what a repo defines, so a repo answers the surface Ecto gave it" do
    assert Enum.sort(ExtraRepo.__info__(:functions)) -- [{:extra, 1}] == Enum.sort(Sandboxed.__info__(:functions))
    refute function_exported?(ReadOnlyRepo, :insert, 2)
    assert function_exported?(ReadOnlyRepo, :all, 2)
  end

  test "use Mediate.Repo before use Ecto.Repo raises at compile time" do
    assert_raise ArgumentError, ~r/use Mediate.Repo must follow use Ecto.Repo/, fn ->
      Code.compile_quoted(
        quote do
          defmodule Mediate.Infrastructure.SurfaceTest.WrongOrder do
            @moduledoc false
            use Mediate.Repo
            use Ecto.Repo, otp_app: :mediate, adapter: Ecto.Adapters.Postgres
          end
        end
      )
    end
  end

  test "use Mediate.Repo validates its role" do
    assert_raise NimbleOptions.ValidationError, fn ->
      Code.compile_quoted(
        quote do
          defmodule Mediate.Infrastructure.SurfaceTest.BadRole do
            @moduledoc false
            use Ecto.Repo, otp_app: :mediate, adapter: Ecto.Adapters.Postgres
            use Mediate.Repo, role: :tenant
          end
        end
      )
    end
  end

  test "the bucket readers partition the surface and bucket/2 answers by name and arity" do
    listed = Surface.query() ++ Surface.write() ++ Surface.raw() ++ Surface.plumbing()
    assert Enum.sort(listed) == Enum.sort(Enum.map(Surface.all(), fn {n, a, _b} -> {n, a} end))
    assert Surface.bucket(:all, 2) == :query
    assert Surface.bucket(:insert, 2) == :write
    assert Surface.bucket(:query, 3) == :raw
    assert Surface.bucket(:transaction, 2) == :plumbing
    assert Surface.bucket(:extra, 1) == nil
  end

  property "the classifier gives a function the surface lists one bucket, and a function it does not list none" do
    listed = Map.new(Surface.all(), fn {name, arity, bucket} -> {{name, arity}, bucket} end)
    arities = Enum.group_by(Map.keys(listed), &elem(&1, 0), &elem(&1, 1))

    check all({name, arity} <- one_of([member_of(Map.keys(listed)), outside(arities)])) do
      case Map.fetch(listed, {name, arity}) do
        {:ok, bucket} ->
          assert Surface.bucket(name, arity) == bucket
          assert holding(name, arity) == [bucket]

        :error ->
          assert Surface.bucket(name, arity) == nil
          assert holding(name, arity) == []
      end
    end
  end

  test "the repos answer their role" do
    assert Sandboxed.__mediate__(:role) == :app
    assert Owner.__mediate__(:role) == :owner
  end

  # The buckets whose own reader holds this name and arity, which is one
  # bucket for a function of the surface and none for anything else.
  defp holding(name, arity) do
    [query: Surface.query(), write: Surface.write(), raw: Surface.raw(), plumbing: Surface.plumbing()]
    |> Enum.filter(fn {_bucket, entries} -> {name, arity} in entries end)
    |> Enum.map(fn {bucket, _entries} -> bucket end)
  end

  # A name and arity the surface does not list. It is one of the surface's
  # names at an arity it does not list, or a name of its own.
  defp outside(arities), do: one_of([wrong_arity(arities), unknown_name(arities)])

  defp wrong_arity(arities) do
    gen all(name <- member_of(Map.keys(arities)), arity <- integer(0..9), arity not in Map.fetch!(arities, name)) do
      {name, arity}
    end
  end

  defp unknown_name(arities) do
    gen all(name <- atom(:alphanumeric), arity <- integer(0..9), not is_map_key(arities, name)) do
      {name, arity}
    end
  end
end
