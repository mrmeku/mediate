defmodule Mediate.Conformance.Reference.Mirror do
  @moduledoc """
  The fake engine's mirror. `mirror/1` rewrites the fake's rule table from
  a world, one entry per grant the world's rule allows. It finds the table
  through the configuration in force. The bound engine can be the fake or
  a module of its own that answers from it.
  """

  @behaviour Mediate.Conformance.Mirror

  alias Mediate.Config
  alias Mediate.Conformance.Mirror
  alias Mediate.Conformance.Reference.World
  alias Mediate.Test.Fake

  @impl Mirror
  def mirror(%World{} = world) do
    rules = rules!()
    :ok = Fake.reset(rules)
    Enum.each(World.grants(world), fn {subject, action, resource} -> Fake.allow(rules, subject, action, resource) end)
  end

  @doc "The fake's rule table, from the configuration in force."
  @spec rules!() :: pid()
  def rules! do
    {:ok, %Config{} = config} = Config.resolve()
    {_engine, options} = Config.engine(config)
    Keyword.fetch!(options, :rules)
  end
end
