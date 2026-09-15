defmodule Mediate.Fga.Conformance.Setup do
  @moduledoc """
  What the case templates of this package run under:

  - a sandbox checkout
  - a fake with a store of the test's own
  - the configuration entry that points at it
  - the binding that names the repo of the checkout and the conformance
    mapping

  A template calls this first in every test, before it writes a population.
  """

  alias Mediate.Dev.Sandbox
  alias Mediate.Fga
  alias Mediate.Fga.Binding
  alias Mediate.Fga.Client.Fake
  alias Mediate.Fga.Conformance.Mapping
  alias Mediate.Fga.Model
  alias Mediate.Test

  @model "priv/conformance/model.fga"

  @doc "Checks the repo out, stands a fake up, and binds this process to both."
  @spec setup(module(), map()) :: :ok
  def setup(repo, tags) do
    :ok = Sandbox.setup(repo, tags)
    agent = ExUnit.Callbacks.start_supervised!(Fake)
    {:ok, store} = Fake.create_store(agent, "case")
    {:ok, model} = Fake.write_model(agent, store, Model.read!(@model))

    :ok = Test.with_config(adapter: {Fga, endpoint: agent, store_id: store, client: Fake, model_id: model})

    Binding.override(repo: repo, model: @model, mapping: Mapping)
  end
end
