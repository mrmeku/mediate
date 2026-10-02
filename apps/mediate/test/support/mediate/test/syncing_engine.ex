defmodule Mediate.Test.SyncingEngine do
  @moduledoc """
  The fake engine plus `sync/0`, which an engine with state of its own to
  bring into step declares. Everything else is the fake's. The declaration
  is the point of this module, so a template's cases for such an engine
  have one to run against. Test support only.

  The sync does whatever `bind/1` put in the current process, the way a
  real engine reaches its own state through its binding. It answers
  `:stateless` until something does.
  """

  @behaviour Mediate.Engine

  use Boundary, top_level?: true, deps: [Mediate, Mediate.Test]

  alias Mediate.Error
  alias Mediate.Test.Fake

  @impl Mediate.Engine
  defdelegate options_schema, to: Fake

  @impl Mediate.Engine
  defdelegate filter_limit, to: Fake

  @impl Mediate.Engine
  defdelegate authorize(subject, action, resource, context, options), to: Fake

  @impl Mediate.Engine
  defdelegate filter(subject, action, resource_type, context, options), to: Fake

  @impl Mediate.Engine
  def sync do
    case Process.get(__MODULE__) do
      nil -> :stateless
      syncing -> syncing.()
    end
  end

  @doc "What a sync of this engine does for the rest of the current process."
  @spec bind((-> :ok | {:error, Error.t()})) :: :ok
  def bind(syncing) when is_function(syncing, 0) do
    Process.put(__MODULE__, syncing)
    :ok
  end
end
