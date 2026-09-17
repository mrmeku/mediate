defmodule Example.Scenarios.Support do
  @moduledoc "What the scenario bodies share: the subject, port shorthands, the fresh and stale facts, and the latency report."

  use Boundary, top_level?: true, deps: [Example, Example.Fixture, Mediate, Mediate.Test, ExUnit]

  import ExUnit.Assertions

  alias Example.Application.Repositories
  alias Example.Domain.Repository
  alias Example.Domain.Sessions
  alias Example.Fixture
  alias Mediate.Error

  @doc "The world and the subject of an account."
  @spec subject(String.t()) :: Mediate.subject()
  defdelegate subject(id), to: Fixture

  @doc "Whether the port allows `read` on the repository."
  @spec reads?(Mediate.subject(), Repository.t()) :: boolean()
  def reads?({_kind, _account} = subject, %Repository{id: id}), do: Mediate.check(subject, :read, Repositories.object(id))

  @doc "Assert the context read the repository."
  @spec assert_read(Mediate.subject(), Repository.t(), keyword()) :: Repository.t()
  def assert_read({_kind, _account} = subject, %Repository{id: id}, opts \\ []) do
    assert {:ok, %Repository{id: ^id} = read} = Repositories.read(subject, id, opts)
    read
  end

  @doc "Assert the context refused the read with the port's error."
  @spec assert_denied(Mediate.subject(), Repository.t(), keyword()) :: Error.t()
  def assert_denied({_kind, _account} = subject, %Repository{id: id}, opts \\ []) do
    error = assert_refused(Repositories.read(subject, id, opts), :read)
    refute reads?(subject, %Repository{id: id})
    error
  end

  @doc "Assert the port refused the call the result came from, and name the operation it refused."
  @spec assert_refused(term(), atom()) :: Error.t()
  def assert_refused(result, operation) when is_atom(operation) do
    assert {:error, %Error{} = error} = result
    assert Exception.message(error) =~ "may not #{operation}"
    error
  end

  @doc "The port options of a session that re-authenticated now."
  @spec fresh() :: keyword()
  def fresh, do: [env: %{reauthenticated_at: DateTime.utc_now()}]

  @doc "The port options of a session that re-authenticated before the window."
  @spec stale() :: keyword()
  def stale, do: [env: %{reauthenticated_at: DateTime.shift(DateTime.utc_now(), second: -(Sessions.window() + 60))}]

  @doc """
  Wait until every fact the tests wrote has reached the engine, where the
  bound adapter keeps state of its own. It answers `:none` where there is
  nothing to wait for, so a scenario body calls it under any binding.
  """
  @spec settle() :: :ok | :none
  defdelegate settle(), to: Mediate.Test

  @doc """
  The revocation-latency report. It goes to the log, and no test asserts it.
  It has the total, the commit, the drain, the poll, and the floor. The
  `drain` part is the milliseconds the engine's copy of the facts took to
  catch up, or `nil` where the bound adapter keeps no copy.
  """
  @spec latency_report(keyword()) :: :ok
  def latency_report(parts) when is_list(parts) do
    report("""
    revocation latency, #{adapter_name()}: total #{parts[:total]} ms
      commit #{parts[:commit]} ms
      #{drained(parts[:drain])}
      poll #{parts[:poll]} ms, floor #{Mediate.Test.poll_interval()} ms
      replica_lag not measured
      cache not measured
    """)
  end

  @doc "The adapter module as text, for a report."
  @spec adapter_name() :: String.t()
  def adapter_name do
    {:ok, config} = Mediate.Config.resolve()
    {adapter, _options} = Mediate.Config.adapter(config)
    inspect(adapter)
  end

  # An adapter that answers from its bound tables keeps no state of its own.
  # `Mediate.Test.settle/0` answers `:none` there. The line says so,
  # because a zero reads like a measurement.
  defp drained(nil), do: "settle not needed"
  defp drained(milliseconds) when is_integer(milliseconds), do: "settle #{milliseconds} ms"

  # credo:disable-for-next-line Credo.Check.Refactor.IoPuts
  defp report(text), do: IO.puts("\n" <> text)
end
