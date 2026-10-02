defmodule Mediate.Test.AroundEngine do
  @moduledoc """
  The fake engine plus `around_query/3`, which sends the test process the
  query or changeset and the decision the mediated repo handed it, then
  runs the call. Test support only.
  """

  @behaviour Mediate.Engine

  use Boundary, top_level?: true, deps: [Mediate, Mediate.Test]

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
  def around_query(query_or_changeset, decision, fun) when is_function(fun, 0) do
    send(self(), {:around_query, query_or_changeset, decision})
    fun.()
  end
end
