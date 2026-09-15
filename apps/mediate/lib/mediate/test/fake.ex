defmodule Mediate.Test.Fake do
  @moduledoc """
  The adapter Tier 1 runs first and the seam's tests bind. Its rules are a
  table in an `Agent`, one per test. A test binds it through the
  configuration override as `{Mediate.Test.Fake, rules: pid}`. An entry
  allows one holder one operation on one object or on any object of a
  type. A holder is one subject, an account whatever its kind, or any
  subject. The fake allows nothing else.

  Without a table the fake answers with the `verdict` option, which is
  `:deny` unless the test says otherwise.

  It returns a value of the real type everywhere the real adapters do.
  `scope` returns a real `dynamic`. A table told to `fail/2` answers every
  call with the reason `:engine_unreachable`, so the port's fail-closed
  path runs against it.
  """

  @behaviour Mediate.Adapter

  import Ecto.Query, only: [dynamic: 2]

  alias Mediate.Answer
  alias Mediate.Error

  @version "fake"

  @schema NimbleOptions.new!(
            rules: [type: :pid, doc: "The rule table from `start_link/0`."],
            verdict: [
              type: {:in, [:allow, :deny]},
              default: :deny,
              doc: "The answer to everything when no rule table is bound."
            ]
          )

  @typedoc "A holder, an operation, and an object reference whose id can be `:any`."
  @type entry :: {holder(), atom(), {atom(), Mediate.Id.t() | term() | :any}}

  @typedoc "Who an entry allows: one subject, an account whatever kind asks, or anyone."
  @type holder :: Mediate.subject() | Mediate.Id.t() | :any

  @typep state :: %{entries: MapSet.t(entry()), failure: String.t() | nil}

  @doc "Starts an empty rule table, unnamed."
  @spec start_link() :: Agent.on_start()
  def start_link, do: Agent.start_link(fn -> %{entries: MapSet.new(), failure: nil} end)

  @doc "Allow the holder to perform `operation` on the object reference, whose id can be `:any`."
  @spec allow(pid(), holder(), atom(), {atom(), term()}) :: :ok
  def allow(rules, subject, operation, {type, _id} = object)
      when is_pid(rules) and is_atom(operation) and is_atom(type) do
    Agent.update(rules, fn state -> %{state | entries: MapSet.put(state.entries, {subject, operation, object})} end)
  end

  @doc "Remove one entry."
  @spec revoke(pid(), holder(), atom(), {atom(), term()}) :: :ok
  def revoke(rules, subject, operation, {type, _id} = object)
      when is_pid(rules) and is_atom(operation) and is_atom(type) do
    Agent.update(rules, fn state -> %{state | entries: MapSet.delete(state.entries, {subject, operation, object})} end)
  end

  @doc "Empty the table and clear any failure."
  @spec reset(pid()) :: :ok
  def reset(rules) when is_pid(rules), do: Agent.update(rules, fn _state -> %{entries: MapSet.new(), failure: nil} end)

  @doc "Make every call fail with the detail. `nil` makes the calls answer again."
  @spec fail(pid(), String.t() | nil) :: :ok
  def fail(rules, detail) when is_pid(rules) and (is_binary(detail) or is_nil(detail)) do
    Agent.update(rules, fn state -> %{state | failure: detail} end)
  end

  @doc "The entries, sorted."
  @spec entries(pid()) :: [entry()]
  def entries(rules) when is_pid(rules), do: Agent.get(rules, &Enum.sort(&1.entries))

  @impl Mediate.Adapter
  def options_schema, do: @schema

  @impl Mediate.Adapter
  def scope_cap, do: :none

  @impl Mediate.Adapter
  def decide({_kind, _account} = subject, operation, {_type, _id} = object, %{now: _now}, options)
      when is_atom(operation) do
    with {:ok, state} <- state(options, :decide) do
      {:ok, answered(state, subject, operation, object)}
    end
  end

  @impl Mediate.Adapter
  def scope({_kind, _account} = subject, operation, object_type, %{now: _now}, options)
      when is_atom(operation) and is_atom(object_type) do
    with {:ok, state} <- state(options, :scope) do
      {:ok, scoped(state, subject, operation, object_type)}
    end
  end

  @doc "The answer the fake gives with no table bound."
  @spec answer(keyword()) :: Answer.t()
  def answer(options) when is_list(options), do: answer_for(Keyword.get(options, :verdict, :deny))

  defp answer_for(:allow) do
    %Answer{verdict: :allow, reason: :allowed, version: @version, meta: %{rule: "fake"}}
  end

  defp answer_for(:deny), do: %Answer{verdict: :deny, reason: :deny_by_default, version: @version}

  # The table's state, the constant verdict as a table with one wildcard or
  # none, or the failure the table was told to give.
  @spec state(keyword(), atom()) :: {:ok, state() | :allow | :deny} | {:error, Error.t()}
  defp state(options, operation) do
    case Keyword.fetch(options, :rules) do
      {:ok, rules} -> read(Agent.get(rules, & &1), operation)
      :error -> {:ok, Keyword.get(options, :verdict, :deny)}
    end
  end

  defp read(%{failure: nil} = state, _operation), do: {:ok, state}

  defp read(%{failure: detail}, operation) do
    {:error, %Error{reason: :engine_unreachable, detail: "#{inspect(__MODULE__)} failed during #{operation}: #{detail}"}}
  end

  defp answered(verdict, _subject, _operation, _object) when is_atom(verdict), do: answer_for(verdict)

  defp answered(%{entries: entries}, subject, operation, {type, object_id}) do
    candidates =
      for holder <- holders(subject), id <- [object_id, :any], do: {holder, operation, {type, id}}

    if Enum.any?(candidates, &MapSet.member?(entries, &1)), do: answer_for(:allow), else: answer_for(:deny)
  end

  # The holders an entry can name that cover the subject.
  defp holders({_kind, id} = subject), do: [subject, id, :any]

  defp scoped(:allow, _subject, _operation, _type), do: {dynamic([_row], true), answer_for(:allow)}
  defp scoped(:deny, _subject, _operation, _type), do: {dynamic([_row], false), answer_for(:deny)}

  defp scoped(%{entries: entries}, subject, operation, type) do
    holders = holders(subject)

    matching =
      Enum.filter(entries, fn
        {holder, ^operation, {^type, _object_id}} -> holder in holders
        _entry -> false
      end)

    ids = Enum.map(matching, fn {_subject, _operation, {_type, object_id}} -> object_id end)

    cond do
      :any in ids -> {dynamic([_row], true), answer_for(:allow)}
      ids == [] -> {dynamic([_row], false), answer_for(:deny)}
      true -> {dynamic([row], row.id in ^ids), answer_for(:allow)}
    end
  end
end
