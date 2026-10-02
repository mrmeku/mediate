defmodule Mediate.Test.Fake do
  @moduledoc """
  The engine the conformance cases run first and the mediated repo's
  tests bind. Its rules are a table in an `Agent`, one per test. A test
  binds it through the configuration override as
  `{Mediate.Test.Fake, rules: pid}`. An entry allows one holder one
  action on one resource or on every resource of a type. A holder is one
  subject, an account whatever its kind, or any subject. The fake allows
  nothing else.

  Without a table the fake answers with the `effect` option, which is
  `:deny` unless the test says otherwise.

  It returns a value of the real type everywhere the real engines do.
  `filter` returns a real `dynamic`. A table told to `fail/2` answers every
  call with the reason `:engine_failed`, so the library's fail-closed path
  runs against it. A table told to `release/2` reports that policy version
  from then on and publishes the release, so the change-management
  procedures run against it.
  """

  @behaviour Mediate.Engine

  import Ecto.Query, only: [dynamic: 2]

  alias Mediate.Config
  alias Mediate.Error
  alias Mediate.PolicyRelease
  alias Mediate.Verdict

  @policy_version "fake"
  @boot %{entries: MapSet.new(), failure: nil, policy_version: @policy_version}

  @schema NimbleOptions.new!(
            rules: [type: :pid, doc: "The rule table from `start_link/0`."],
            effect: [
              type: {:in, [:allow, :deny]},
              default: :deny,
              doc: "The effect of every verdict when no rule table is bound."
            ]
          )

  @typedoc "A holder, an action, and a resource whose id can be `:any`."
  @type entry :: {holder(), atom(), {atom(), Mediate.Id.t() | term() | :any}}

  @typedoc "Who an entry allows: one subject, an account whatever kind asks, or anyone."
  @type holder :: Mediate.subject() | Mediate.Id.t() | :any

  @typep state :: %{entries: MapSet.t(entry()), failure: String.t() | nil, policy_version: String.t()}

  @doc "Starts an empty rule table, unnamed."
  @spec start_link() :: Agent.on_start()
  def start_link, do: Agent.start_link(fn -> @boot end)

  @doc "Allow the holder to perform `action` on the resource, whose id can be `:any`."
  @spec allow(pid(), holder(), atom(), {atom(), term()}) :: :ok
  def allow(rules, subject, action, {type, _id} = resource) when is_pid(rules) and is_atom(action) and is_atom(type) do
    Agent.update(rules, fn state -> %{state | entries: MapSet.put(state.entries, {subject, action, resource})} end)
  end

  @doc "Remove one entry."
  @spec revoke(pid(), holder(), atom(), {atom(), term()}) :: :ok
  def revoke(rules, subject, action, {type, _id} = resource) when is_pid(rules) and is_atom(action) and is_atom(type) do
    Agent.update(rules, fn state -> %{state | entries: MapSet.delete(state.entries, {subject, action, resource})} end)
  end

  @doc "Empty the table, clear any failure, and put the boot policy version back."
  @spec reset(pid()) :: :ok
  def reset(rules) when is_pid(rules), do: Agent.update(rules, fn _state -> @boot end)

  @doc "Make every call fail with the detail. `nil` makes the calls answer again."
  @spec fail(pid(), String.t() | nil) :: :ok
  def fail(rules, detail) when is_pid(rules) and (is_binary(detail) or is_nil(detail)) do
    Agent.update(rules, fn state -> %{state | failure: detail} end)
  end

  @doc "The entries, sorted."
  @spec entries(pid()) :: [entry()]
  def entries(rules) when is_pid(rules), do: Agent.get(rules, &Enum.sort(&1.entries))

  @doc """
  Release a policy version on the table. Every verdict the table gives
  from then on reports it. The release carries the entries as its text,
  the hash of that text, and the moment of the configured clock, and
  `Mediate.PolicyRelease.publish/1` publishes it.
  """
  @spec release(pid(), String.t()) :: {:ok, PolicyRelease.t()}
  def release(rules, policy_version) when is_pid(rules) and is_binary(policy_version) do
    {:ok, %Config{clock: clock}} = Config.resolve()
    :ok = Agent.update(rules, fn state -> %{state | policy_version: policy_version} end)
    text = inspect(entries(rules), limit: :infinity)

    release = %PolicyRelease{
      engine: __MODULE__,
      policy_version: policy_version,
      text: text,
      text_hash: Base.encode16(:crypto.hash(:sha256, text), case: :lower),
      author: "the fake",
      approval: "the test",
      released_at: clock.()
    }

    :ok = PolicyRelease.publish(release)
    {:ok, release}
  end

  @impl Mediate.Engine
  def options_schema, do: @schema

  @impl Mediate.Engine
  def filter_limit, do: :infinity

  @impl Mediate.Engine
  def authorize({_kind, _account} = subject, action, {_type, _id} = resource, %{now: _now}, options)
      when is_atom(action) do
    with {:ok, state} <- state(options, :authorize) do
      {:ok, authorized(state, subject, action, resource)}
    end
  end

  @impl Mediate.Engine
  def filter({_kind, _account} = subject, action, resource_type, %{now: _now}, options)
      when is_atom(action) and is_atom(resource_type) do
    with {:ok, state} <- state(options, :filter) do
      {:ok, filtered(state, subject, action, resource_type)}
    end
  end

  @doc "The verdict the fake gives with no table bound."
  @spec verdict(keyword()) :: Verdict.t()
  def verdict(options) when is_list(options), do: verdict_for(Keyword.get(options, :effect, :deny), @policy_version)

  defp verdict_for(:allow, policy_version) do
    %Verdict{effect: :allow, reason: :rule_allowed, policy_version: policy_version, meta: %{rule: "fake"}}
  end

  defp verdict_for(:deny, policy_version) do
    %Verdict{effect: :deny, reason: :no_rule_matched, policy_version: policy_version}
  end

  # The table's state, the constant effect as a table with one wildcard or
  # none, or the failure the table was told to give.
  @spec state(keyword(), atom()) :: {:ok, state() | :allow | :deny} | {:error, Error.t()}
  defp state(options, function) do
    case Keyword.fetch(options, :rules) do
      {:ok, rules} -> read(Agent.get(rules, & &1), function)
      :error -> {:ok, Keyword.get(options, :effect, :deny)}
    end
  end

  defp read(%{failure: nil} = state, _function), do: {:ok, state}

  defp read(%{failure: detail}, function) do
    {:error, %Error{reason: :engine_failed, message: "#{inspect(__MODULE__)} failed during #{function}: #{detail}"}}
  end

  defp authorized(effect, _subject, _action, _resource) when is_atom(effect), do: verdict_for(effect, @policy_version)

  defp authorized(%{entries: entries, policy_version: version}, subject, action, {type, resource_id}) do
    candidates =
      for holder <- holders(subject), id <- [resource_id, :any], do: {holder, action, {type, id}}

    if Enum.any?(candidates, &MapSet.member?(entries, &1)),
      do: verdict_for(:allow, version),
      else: verdict_for(:deny, version)
  end

  # The holders an entry can name that cover the subject.
  defp holders({_kind, id} = subject), do: [subject, id, :any]

  defp filtered(:allow, _subject, _action, _type), do: {dynamic([_row], true), verdict_for(:allow, @policy_version)}
  defp filtered(:deny, _subject, _action, _type), do: {dynamic([_row], false), verdict_for(:deny, @policy_version)}

  defp filtered(%{entries: entries, policy_version: version}, subject, action, type) do
    holders = holders(subject)

    matching =
      Enum.filter(entries, fn
        {holder, ^action, {^type, _resource_id}} -> holder in holders
        _entry -> false
      end)

    ids = Enum.map(matching, fn {_subject, _action, {_type, resource_id}} -> resource_id end)

    cond do
      :any in ids -> {dynamic([_row], true), verdict_for(:allow, version)}
      ids == [] -> {dynamic([_row], false), verdict_for(:deny, version)}
      true -> {dynamic([row], row.id in ^ids), verdict_for(:allow, version)}
    end
  end
end
