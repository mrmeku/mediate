defmodule Example.FakeCase do
  @moduledoc """
  The example's own test case: a sandbox connection, the world, and the
  fake engine bound for the test process. The application modules then
  face decisions the test sets and no clause. `allow/4` and `revoke/4`
  set them.
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

  @doc "The setup: sandbox, fake engine, and the world."
  @spec setup(map()) :: {:ok, keyword()}
  def setup(tags) when is_map(tags) do
    :ok = Sandbox.setup(Example.Infrastructure.Repo, tags)
    fake = start_supervised!(%{id: Fake, start: {Fake, :start_link, []}})
    :ok = Mediate.Test.with_config(engine: {Fake, rules: fake})
    {:ok, fake: fake, world: Example.Fixture.world!()}
  end

  @doc "Allow an action for a subject on a resource, or on every resource of a type with `:any`."
  @spec allow(pid(), String.t() | :any, atom(), {atom(), term()}) :: :ok
  def allow(fake, subject, action, resource), do: Fake.allow(fake, subject, action, resource)

  @doc "Revoke what `allow/4` gave."
  @spec revoke(pid(), String.t() | :any, atom(), {atom(), term()}) :: :ok
  def revoke(fake, subject, action, resource), do: Fake.revoke(fake, subject, action, resource)
end
