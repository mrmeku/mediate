defmodule ExampleOpenFGA.OutboxStore do
  @moduledoc """
  What `Mediate.OpenFGA.OutboxCase` runs under here: a sandbox connection on
  the example's repo, then a store of the test's own. `ExampleOpenFGA.Store`
  creates that store and pins a model in it. A pass writes into that store,
  so a test reads what its own passes wrote and not what another test's did.

  The handler is global, and `ExampleOpenFGA.Application` attaches it for
  the whole run. The case attaches and detaches it around each of its own
  tests. So this module puts the application's handler back when the test
  ends. A callback registered here runs after the case's, and a run with no
  handler leaves every later test's writes unmarked.
  """

  use Boundary, top_level?: true, deps: [ExampleOpenFGA.Store, Mediate.OpenFGA, Mediate.Dev.Sandbox]

  alias ExampleOpenFGA.Store
  alias Mediate.Dev.Sandbox
  alias Mediate.OpenFGA.Outbox

  @doc "Checks the repo out and gives the current process a store of its own."
  @spec setup(module(), map()) :: :ok
  def setup(repo, tags) do
    :ok = Sandbox.setup(repo, tags)
    ExUnit.Callbacks.on_exit(&Outbox.attach/0)

    Store.setup(tags)
  end
end
