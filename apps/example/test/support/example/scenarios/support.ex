defmodule Example.Scenarios.Support do
  @moduledoc "What the scenario bodies share: the subject, shorthands for the calls, the fresh and stale sessions, and the latency report."

  use Boundary, top_level?: true, deps: [Example, Example.Fixture, Mediate, Mediate.Test, ExUnit]

  import ExUnit.Assertions

  alias Example.Application.Repositories
  alias Example.Domain.Reauthentication
  alias Example.Domain.Repository
  alias Example.Fixture
  alias Mediate.Error

  @doc "The subject of an account of the world."
  @spec subject(String.t()) :: Mediate.subject()
  defdelegate subject(id), to: Fixture

  @doc "Whether `authorize` allows `read` on the repository."
  @spec reads?(Mediate.subject(), Repository.t()) :: boolean()
  def reads?({_kind, _account} = subject, %Repository{id: id}),
    do: Mediate.authorized?(subject, :read, Repositories.resource(id))

  @doc "Assert the application module read the repository."
  @spec assert_read(Mediate.subject(), Repository.t(), keyword()) :: Repository.t()
  def assert_read({_kind, _account} = subject, %Repository{id: id}, opts \\ []) do
    assert {:ok, %Repository{id: ^id} = read} = Repositories.read(subject, id, opts)
    read
  end

  @doc "Assert the application module refused the read with Mediate's error."
  @spec assert_denied(Mediate.subject(), Repository.t(), keyword()) :: Error.t()
  def assert_denied({_kind, _account} = subject, %Repository{id: id}, opts \\ []) do
    error = assert_refused(Repositories.read(subject, id, opts), :read)
    refute reads?(subject, %Repository{id: id})
    error
  end

  @doc "Assert Mediate refused the call the result came from, and name the action it refused."
  @spec assert_refused(term(), atom()) :: Error.t()
  def assert_refused(result, action) when is_atom(action) do
    assert {:error, %Error{} = error} = result
    assert Exception.message(error) =~ "may not #{action}"
    error
  end

  @doc "The options of a fresh session: one that re-authenticated now."
  @spec fresh_session() :: keyword()
  def fresh_session, do: [context: %{reauthenticated_at: DateTime.utc_now()}]

  @doc "The options of a stale session: one that re-authenticated before the window."
  @spec stale_session() :: keyword()
  def stale_session do
    [context: %{reauthenticated_at: DateTime.shift(DateTime.utc_now(), second: -(Reauthentication.window() + 60))}]
  end

  @doc """
  Bring the engine's own state into step with the tables, where the bound
  engine keeps state of its own. It answers `:stateless` where there is
  nothing to sync, so a scenario body calls it under any deployment.
  """
  @spec sync() :: :ok | :stateless
  defdelegate sync(), to: Mediate.Test

  @doc """
  The revocation-latency report. It goes to the log, and no test asserts
  it. It has the total, the commit, the catch-up, the poll, and the floor.
  The catch-up is the milliseconds the engine's copy of the facts took to
  catch up, or `nil` where the bound engine keeps no copy.
  """
  @spec latency_report(keyword()) :: :ok
  def latency_report(parts) when is_list(parts) do
    report("""
    revocation latency, #{engine_name()}: total #{parts[:total]} ms
      commit #{parts[:commit]} ms
      #{catch_up(parts[:catch_up])}
      poll #{parts[:poll]} ms, floor #{Mediate.Test.poll_interval()} ms
      replica lag not measured
    """)
  end

  @doc "The engine module as text, for a report."
  @spec engine_name() :: String.t()
  def engine_name do
    {:ok, config} = Mediate.Config.resolve()
    {engine, _options} = Mediate.Config.engine(config)
    inspect(engine)
  end

  # An engine that answers from its bound tables keeps no state of its own,
  # and `Mediate.Test.sync/0` answers `:stateless` there. The line says so,
  # because a zero reads like a measurement.
  defp catch_up(nil), do: "catch-up not needed"
  defp catch_up(milliseconds) when is_integer(milliseconds), do: "catch-up #{milliseconds} ms"

  # credo:disable-for-next-line Credo.Check.Refactor.IoPuts
  defp report(text), do: IO.puts("\n" <> text)
end
