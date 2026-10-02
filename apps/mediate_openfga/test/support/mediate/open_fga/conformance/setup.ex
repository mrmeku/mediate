defmodule Mediate.OpenFGA.Conformance.Setup do
  @moduledoc """
  What the cases of this package run under:

  - a sandbox checkout
  - a fake with a store of the test's own
  - the configuration entry that points at it
  - the binding that names the repo of the checkout and the reference
    mapping

  A case calls this first in every test, before it writes a population.
  """

  alias Mediate.Dev.Sandbox
  alias Mediate.OpenFGA
  alias Mediate.OpenFGA.Binding
  alias Mediate.OpenFGA.Client.Fake
  alias Mediate.OpenFGA.Conformance.Reference
  alias Mediate.OpenFGA.Model
  alias Mediate.Test

  @doc "Checks the repo out, stands a fake up, and binds this process to both."
  @spec setup(module(), map()) :: :ok
  def setup(repo, tags) do
    :ok = Sandbox.setup(repo, tags)
    agent = ExUnit.Callbacks.start_supervised!(Fake)
    {:ok, store_id} = Fake.create_store(agent, "case")
    {:ok, model_id} = Fake.write_authorization_model(agent, store_id, Model.read!(Reference.model()))

    :ok = Test.with_config(engine: {OpenFGA, address: agent, store_id: store_id, client: Fake, model_id: model_id})

    Binding.override(repo: repo, model_file: Reference.model(), mapping: Reference)
  end
end
