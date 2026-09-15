defmodule Mediate.Postgres do
  @moduledoc """
  Row-level security as the adapter: the rules are Postgres policies on the
  tables themselves.

  Migrations write the policies. The database enforces them on every
  statement, with the statements this library never sees among them. The
  configuration entry is the bare module, because the adapter takes no
  options (`docs/design.md` §7). The adapter finds the repo and the schemas
  through the binding that `Mediate.Postgres.Binding.bind/1` makes at boot.

  Three mechanisms.

  *Session settings.* `around_query/3` runs `set_config(name, value, true)`
  for the length of the call. It sets `mediate.subject_id`,
  `mediate.subject_kind`, `mediate.operation`, `mediate.now`, and one name
  per fact the caller supplied. A call outside a transaction opens one, so
  the settings leave with the call. Two subjects in one transaction each
  set their own. A policy reads a setting with `current_setting(name, true)`.

  *Answers.* `decide` runs one statement under those settings. A row the
  operation's `SELECT` policy does not admit is a denial. Where the
  operation has an `UPDATE` gate, the same statement reads the gate's
  `USING` expression. So an answer given before a write agrees with what
  `WITH CHECK` does to the write.

  `scope` runs no statement and answers the rule `true`, because the policy
  narrows the query when the repo runs it. Its reason names the policy and
  the SHA-256 of the settings the database reads, which together are what
  it enforced. The scope cap is `:none`.

  *Policy versions.* The version is the migration number.
  `Mediate.Postgres.Migration.publish!/2` reads the policies back from
  `pg_policy` and emits the version in the same transaction as the DDL.
  `docs/events.md` §4 has the event.

  The database does not report which policy admitted a row, so an answer
  names the policy of the operation and nothing further. The adapter
  reports the replica-lag component of revocation latency as "not
  measured", because every statement goes to the primary.

  The application's role must carry `NOBYPASSRLS`, because a role with
  `BYPASSRLS` is not subject to the policies. The package carries no
  driver: `ecto_sql` and `postgrex` serve its tests alone, and Boundary
  holds `lib` to that.
  """

  @behaviour Mediate.Adapter

  use Boundary,
    deps: [Mediate, Ecto, NimbleOptions],
    check: [apps: [:ecto_sql, :postgrex]],
    exports: [Binding, Catalog, Coverage, Migration, Policy, Version]

  import Ecto.Query, only: [dynamic: 2]

  alias Mediate.Answer
  alias Mediate.Decision
  alias Mediate.Error
  alias Mediate.Postgres.Binding
  alias Mediate.Postgres.Catalog
  alias Mediate.Postgres.Infrastructure.Decide
  alias Mediate.Postgres.Infrastructure.Session
  alias Mediate.Postgres.Infrastructure.Settings

  @doc """
  Read the policies and the version once, so no call on the request path
  pays for the read. An application calls this at boot, after the binding.
  """
  @spec load!() :: Catalog.t()
  def load! do
    case Binding.resolve() do
      {:ok, %Binding{} = binding} -> Catalog.load!(binding)
      {:error, error} -> raise error
    end
  end

  @doc """
  Read the policies and the version again, for an application that ran a
  migration after boot. Every call after this one reads what the database
  now holds.
  """
  @spec reload!() :: Catalog.t()
  def reload! do
    case Binding.resolve() do
      {:ok, %Binding{} = binding} -> Catalog.reload!(binding)
      {:error, error} -> raise error
    end
  end

  @doc "The component of revocation latency this adapter cannot measure."
  @spec replica_lag() :: String.t()
  def replica_lag, do: "not measured"

  @impl Mediate.Adapter
  def scope_cap, do: :none

  @impl Mediate.Adapter
  def decide({_kind, _account} = subject, operation, {_type, _id} = object, %{now: _now} = environment, _options)
      when is_atom(operation) do
    with {:ok, binding, catalog} <- ready(:decide) do
      Decide.one(binding, catalog, subject, operation, object, environment)
    end
  end

  @impl Mediate.Adapter
  def scope({_kind, _account} = subject, operation, object_type, %{now: _now} = environment, _options)
      when is_atom(operation) and is_atom(object_type) do
    with {:ok, binding, catalog} <- ready(:scope) do
      settings = Settings.of(subject, operation, environment)
      :ok = Session.remember(subject, operation, settings)
      {:ok, scoped(Decide.scope(binding, catalog, operation, object_type, settings))}
    end
  end

  @impl Mediate.Adapter
  def around_query(_query_or_changeset, %Decision{} = decision, fun) when is_function(fun, 0) do
    case Binding.resolve() do
      {:ok, %Binding{repo: repo}} -> Session.around(repo, settings_of(decision), fun)
      {:error, _unbound} -> fun.()
    end
  end

  defp scoped(%Answer{verdict: :allow} = answer), do: {dynamic([_row], true), answer}
  defp scoped(%Answer{verdict: :deny} = answer), do: {dynamic([_row], false), answer}

  defp settings_of(%Decision{subject: subject, operation: operation, at: at}) do
    Session.recall(subject, operation) || Settings.of(subject, operation, at)
  end

  defp ready(operation) do
    with {:ok, %Binding{} = binding} <- bound(operation) do
      loaded(binding, operation)
    end
  end

  defp loaded(binding, operation) do
    {:ok, binding, Catalog.current!(binding)}
  rescue
    error -> {:error, engine(operation, Exception.message(error))}
  end

  defp bound(operation) do
    case Binding.resolve() do
      {:ok, %Binding{} = binding} -> {:ok, binding}
      {:error, %Error{reason: :invalid, detail: detail}} -> {:error, engine(operation, detail)}
    end
  end

  defp engine(operation, detail),
    do: %Error{reason: :engine_unreachable, detail: "#{inspect(__MODULE__)} failed during #{operation}: #{detail}"}
end
