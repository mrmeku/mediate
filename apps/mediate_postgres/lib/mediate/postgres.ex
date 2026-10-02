defmodule Mediate.Postgres do
  @moduledoc """
  Row-level security as the engine: the rules are Postgres policies on the
  tables themselves. Migrations write the rules. The database enforces
  them on every statement, with the statements this library never sees
  among them. The engine takes no options, so its entry in
  `Mediate.Config` is the bare module. It finds the repo and the schemas
  through the binding `Mediate.Postgres.Binding.bind/1` makes at boot
  beside the configuration.

  Three mechanisms.

  *Session settings.* `around_query/3` runs `set_config(name, value, true)`
  for the length of the call. It sets `mediate.subject_id`,
  `mediate.subject_kind`, `mediate.action`, `mediate.now`, and one name
  per fact the caller supplied. A call outside a transaction opens one, so
  the settings leave with the call. Two subjects in one transaction each
  set their own. A rule reads a setting with `current_setting(name, true)`.

  *Verdicts.* `authorize` runs one statement under those settings. A row
  the action's filter rule does not admit is a denial. Where the action
  has a gate rule, the same statement reads the gate's `USING` expression.
  So a verdict given before a write agrees with what `WITH CHECK` does to
  the write. `filter` runs no statement and answers the rule `true`,
  because the filter rule narrows the query when the repo runs it. Its
  `meta` names the rule and the sha256 of the settings the database reads,
  which together are what it enforced. The filter limit is `:infinity`.

  *Policy versions.* The version is the migration number.
  `Mediate.Postgres.Migration.release!/2` reads the rules back from
  `pg_policy` and publishes the release in the same transaction as the
  DDL. The events document under "Policy release" has the event.

  The database does not report which rule admitted a row, so a verdict
  names the rule of the action and nothing further. A row the filter
  hides and a row that does not exist deny the same way. The engine
  reports the replica-lag component of revocation latency as "not
  measured", because every statement goes to the primary.

  The application's role must carry `NOBYPASSRLS`, because a role with
  `BYPASSRLS` is not subject to the rules. The package carries no driver:
  `ecto_sql` and `postgrex` serve its tests alone, and Boundary holds
  `lib` to that.
  """

  @behaviour Mediate.Engine

  use Boundary,
    deps: [Mediate, Ecto, NimbleOptions],
    check: [apps: [:ecto_sql, :postgrex]],
    exports: [Binding, Catalog, Facts, Migration, Rule, Version]

  import Ecto.Query, only: [dynamic: 2]

  alias Mediate.Decision
  alias Mediate.Error
  alias Mediate.Postgres.Binding
  alias Mediate.Postgres.Catalog
  alias Mediate.Postgres.Domain.Settings
  alias Mediate.Postgres.Infrastructure.Decide
  alias Mediate.Postgres.Infrastructure.Session
  alias Mediate.Verdict

  @doc """
  Reads the rules and the policy version through the bound binding and
  keeps them, so no call on the request path pays for the read. An
  application calls this at boot, after the binding, and again after a
  migration that runs under a live VM.
  """
  @spec load_catalog() :: {:ok, Catalog.t()} | {:error, Error.t()}
  def load_catalog do
    with {:ok, %Binding{} = binding} <- Binding.resolve() do
      Catalog.load(binding)
    end
  end

  @doc "`load_catalog/0`, and it raises the error."
  @spec load_catalog!() :: Catalog.t()
  def load_catalog! do
    case load_catalog() do
      {:ok, catalog} -> catalog
      {:error, error} -> raise error
    end
  end

  @doc "The component of revocation latency this engine does not measure."
  @spec replica_lag() :: String.t()
  def replica_lag, do: "not measured"

  @impl Mediate.Engine
  def filter_limit, do: :infinity

  @impl Mediate.Engine
  def authorize({_kind, _account} = subject, action, {_type, _id} = resource, %{now: _now} = context, _options)
      when is_atom(action) do
    with {:ok, binding, catalog} <- ready(:authorize) do
      Decide.one(binding, catalog, subject, action, resource, context)
    end
  end

  @impl Mediate.Engine
  def filter({_kind, _account} = subject, action, resource_type, %{now: _now} = context, _options)
      when is_atom(action) and is_atom(resource_type) do
    with {:ok, binding, catalog} <- ready(:filter) do
      settings = Settings.new(subject, action, context)
      :ok = Session.remember(subject, action, settings)
      {:ok, filtered(Decide.filter(binding, catalog, action, resource_type, settings))}
    end
  end

  @impl Mediate.Engine
  def around_query(_query_or_changeset, %Decision{} = decision, fun) when is_function(fun, 0) do
    case Binding.resolve() do
      {:ok, %Binding{repo: repo}} -> Session.run(repo, settings_of(decision), fun)
      {:error, _unbound} -> fun.()
    end
  end

  defp filtered(%Verdict{effect: :allow} = verdict), do: {dynamic([_row], true), verdict}
  defp filtered(%Verdict{effect: :deny} = verdict), do: {dynamic([_row], false), verdict}

  defp settings_of(%Decision{subject: subject, action: action, decided_at: decided_at}) do
    Session.recall(subject, action) || Settings.new(subject, action, decided_at)
  end

  defp ready(callback) do
    with {:ok, %Binding{} = binding} <- Binding.resolve(),
         {:ok, %Catalog{} = catalog} <- Catalog.resolve(binding) do
      {:ok, binding, catalog}
    else
      {:error, %Error{message: message}} -> failed(message, callback)
    end
  end

  defp failed(text, callback) when is_binary(text) do
    {:error, %Error{reason: :engine_failed, message: "#{inspect(__MODULE__)} failed during #{callback}: #{text}"}}
  end
end
