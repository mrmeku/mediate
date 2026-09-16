defmodule Mediate.Access do
  @moduledoc """
  The access event: one telemetry event for each mediated read of a
  protected schema. The seam publishes it after the read returns, at the
  one site every query function passes through. So it covers `get`, `one`,
  `all`, `exists?`, `aggregate`, `stream`, `preload`, and `reload` alike.
  Only a read that carried a decision publishes. An exempt read, a read
  through the owner-role repo, and a raw query publish nothing.

  `docs/events.md` under "Access" has the payload. The one measurement is `count`. The
  library publishes the event and stores nothing.
  """

  alias Mediate.Decision
  alias Mediate.Schema

  @event [:mediate, :access]
  @queries [:all, :all_by, :stream, :aggregate]

  @typedoc "What the read answered with: rows of the schema, one value, or a stream not yet run."
  @type shape :: :rows | :value | :stream

  @doc "The telemetry event an access publishes, which is what a consumer attaches to."
  @spec event() :: [atom()]
  def event, do: @event

  @doc "Publish one access: the read's result under the decision it ran under, at the moment given."
  @spec publish(module(), module(), {atom(), non_neg_integer()}, term(), Decision.t(), DateTime.t()) :: :ok
  def publish(repo, schema, {name, _arity} = call, result, %Decision{} = decision, %DateTime{} = at)
      when is_atom(repo) and is_atom(schema) do
    {shape, ids} = shape(schema, result)
    {kind, _id} = decision.subject

    payload = %{
      object_type: Schema.object_type_of(schema),
      schema: schema,
      repo: repo,
      call: call,
      activity: activity(name),
      ids: ids,
      count: length(ids),
      shape: shape,
      subject: decision.subject,
      subject_kind: kind,
      decision_id: decision.id,
      time: at,
      operation_id: decision.operation_id
    }

    :telemetry.execute(@event, %{count: length(ids)}, payload)
  end

  defp activity(name) when name in @queries, do: :query
  defp activity(_name), do: :read

  defp shape(_schema, %Stream{}), do: {:stream, []}
  defp shape(_schema, fun) when is_function(fun), do: {:stream, []}

  defp shape(schema, rows) when is_list(rows),
    do: {:rows, for(%{__struct__: ^schema} = row <- rows, do: Schema.id_of(row))}

  defp shape(schema, %{__struct__: schema} = row), do: {:rows, [Schema.id_of(row)]}
  defp shape(_schema, nil), do: {:rows, []}
  defp shape(_schema, _value), do: {:value, []}
end
