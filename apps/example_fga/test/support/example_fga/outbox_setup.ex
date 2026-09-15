defmodule ExampleFga.OutboxSetup do
  @moduledoc """
  What `Mediate.Fga.OutboxCase` runs under here: a sandbox connection on the
  example's repo, then a store of the test's own. `ExampleFga.Store` creates
  that store and pins a model in it. The drain writes into that store, so a
  test reads what its own passes wrote and not what another test's did.

  The handler is global, and `ExampleFga.Application` attaches it for the
  whole run. The template attaches and detaches it around each of its own
  tests. So this module puts the application's handler back when the test
  ends. A callback registered here runs after the template's, and a run
  with no handler leaves every later test's writes unmarked.
  """

  use Boundary, top_level?: true, deps: [ExampleFga.Store, Mediate.Fga, Mediate.Dev.Sandbox]

  alias ExampleFga.Store
  alias Mediate.Dev.Sandbox
  alias Mediate.Fga.Outbox

  @doc "Checks the repo out and gives the current process a store of its own."
  @spec setup(module(), map()) :: :ok
  def setup(repo, tags) do
    :ok = Sandbox.setup(repo, tags)
    ExUnit.Callbacks.on_exit(&Outbox.attach/0)

    Store.setup(tags)
  end
end
