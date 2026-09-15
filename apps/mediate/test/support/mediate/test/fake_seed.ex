defmodule Mediate.Test.FakeSeed do
  @moduledoc """
  The fake adapter's conformance hooks. `seed/1` rewrites the fake's rule
  table from a world, one entry per grant the world's rule allows.
  `outage/0` makes every call to the fake fail for the rest of the test.
  Both find the table through the configuration in force. The bound
  adapter can be the fake or a module of its own that answers from it.
  """

  @behaviour Mediate.Conformance.Seed

  use Boundary, top_level?: true, deps: [Mediate, Mediate.Conformance, Mediate.Fixture, Mediate.Test]

  alias Mediate.Config
  alias Mediate.Conformance.Seed
  alias Mediate.Fixture.World
  alias Mediate.Test.Fake

  @impl Seed
  def seed(%World{} = world) do
    rules = rules!()
    :ok = Fake.reset(rules)
    Enum.each(World.grants(world), fn {subject, operation, ref} -> Fake.allow(rules, subject, operation, ref) end)
  end

  @impl Seed
  def outage, do: Fake.fail(rules!(), "the fake's engine is down")

  defp rules! do
    {:ok, %Config{} = config} = Config.resolve()
    {_adapter, options} = Config.adapter(config)
    Keyword.fetch!(options, :rules)
  end
end
