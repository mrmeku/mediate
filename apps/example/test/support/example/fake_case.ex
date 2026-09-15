defmodule Example.FakeCase do
  @moduledoc """
  The example's own test case: a sandbox connection, the world, and the
  fake adapter bound for the test process. The contexts then face verdicts
  the test sets and no rule. `allow/4` and `deny/4` set them.
  """

  use Boundary,
    top_level?: true,
    deps: [Example, Example.Fixture, Mediate, Mediate.Test, Mediate.Dev.Sandbox, ExUnit]

  import ExUnit.Callbacks, only: [start_supervised!: 1]

  alias Mediate.Dev.Sandbox
  alias Mediate.Test.Fake

  @doc false
  defmacro __using__(opts) do
    async = Keyword.get(opts, :async, true)

    quote do
      use ExUnit.Case, async: unquote(async)

      import Example.FakeCase

      setup tags do
        Example.FakeCase.setup(tags)
      end
    end
  end

  @doc "The setup: sandbox, fake adapter, and the world."
  @spec setup(map()) :: {:ok, keyword()}
  def setup(tags) when is_map(tags) do
    :ok = Sandbox.setup(Example.Infrastructure.Repo, tags)
    rules = start_supervised!(%{id: Fake, start: {Fake, :start_link, []}})
    :ok = Mediate.Test.with_config(adapter: {Fake, rules: rules})
    {:ok, rules: rules, world: Example.Fixture.world!()}
  end

  @doc "Allow an operation for a subject on an object, or on every object of a type with `:any`."
  @spec allow(pid(), String.t() | :any, atom(), {atom(), term()}) :: :ok
  def allow(rules, subject, operation, object), do: Fake.allow(rules, subject, operation, object)

  @doc "Revoke what `allow/4` gave."
  @spec deny(pid(), String.t() | :any, atom(), {atom(), term()}) :: :ok
  def deny(rules, subject, operation, object), do: Fake.revoke(rules, subject, operation, object)
end
