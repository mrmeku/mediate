defmodule Mediate.Test.SettlingAdapter do
  @moduledoc """
  The fake adapter plus `settle/0`, which an adapter with state of its own
  to bring into step declares. Everything else is the fake's. The
  declaration is the point of this module, so a template's cases for such
  an adapter have one to run against. Test support only.

  The settle does whatever `bind/1` put in the current process, the way a
  real adapter reaches its own state through its binding. It answers
  `:none` until something does.
  """

  @behaviour Mediate.Adapter

  use Boundary, top_level?: true, deps: [Mediate, Mediate.Test]

  alias Mediate.Error
  alias Mediate.Test.Fake

  @impl Mediate.Adapter
  defdelegate options_schema, to: Fake

  @impl Mediate.Adapter
  defdelegate scope_cap, to: Fake

  @impl Mediate.Adapter
  defdelegate decide(subject, operation, object, environment, options), to: Fake

  @impl Mediate.Adapter
  defdelegate scope(subject, operation, object_type, environment, options), to: Fake

  @impl Mediate.Adapter
  def settle do
    case Process.get(__MODULE__) do
      nil -> :none
      settling -> settling.()
    end
  end

  @doc "What a settle of this adapter does for the rest of the current process."
  @spec bind((-> :ok | {:error, Error.t()})) :: :ok
  def bind(settling) when is_function(settling, 0) do
    Process.put(__MODULE__, settling)
    :ok
  end
end
