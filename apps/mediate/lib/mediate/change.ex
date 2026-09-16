defmodule Mediate.Change do
  @moduledoc """
  The change event: one telemetry event for each single-row write to an
  audited schema. The seam computes it from the write itself and publishes
  it inside the write's transaction. So a consumer that writes to the same
  repository from its handler joins that transaction.

  `docs/events.md` under "Change" has the payload. The value before a change is the row
  the caller loaded. A change a second writer made between the load and the
  write is not in the event. The library publishes the event and stores
  nothing. What an attached handler does with it is the handler's own
  business.
  """

  alias Mediate.Schema

  @event [:mediate, :change]
  @library {:non_person_entity, "00000000-0000-0000-0000-000000000000"}

  @typedoc "What the write did to the row."
  @type operation :: :create | :update | :delete

  @typedoc "What every event of one operation shares: who asked, under which decision, the identifier, and the moment."
  @type stamp :: %{
          by: Mediate.subject(),
          decision_id: Mediate.Id.t() | nil,
          operation_id: Mediate.Id.t(),
          at: DateTime.t()
        }

  @doc "The telemetry event a change publishes, which is what a consumer attaches to."
  @spec event() :: [atom()]
  def event, do: @event

  @doc """
  The actor of a change no decision named, which is the library itself: a
  non-person entity with the nil identifier. A write through the seam under
  an exemption carries this.
  """
  @spec library() :: Mediate.subject()
  def library, do: @library

  @doc "Publish one change. The row before an insert and the row after a delete are `nil`."
  @spec publish(module(), operation(), struct() | nil, struct() | nil, stamp()) :: :ok
  def publish(schema, operation, old, new, stamp) when is_atom(schema) and is_map(stamp) do
    :telemetry.execute(@event, %{}, payload(schema, operation, old, new, stamp))
  end

  defp payload(schema, operation, old, new, stamp) do
    {kind, _id} = stamp.by

    %{
      operation: operation,
      kind: Schema.kind_of(schema),
      target: target(schema, new || old),
      changes: changes(schema, old, new),
      actor: stamp.by,
      actor_kind: kind,
      decision_id: stamp.decision_id,
      time: stamp.at,
      operation_id: stamp.operation_id,
      schema: schema
    }
  end

  # The type a consumer names the row by. It is the object type where the
  # schema protects one. Where the schema protects none, it is the audited
  # kind, which is what a subject schema such as an account table declares.
  defp target(schema, row) do
    type = Schema.object_type_of(schema) || Schema.kind_of(schema)

    {type, Schema.id_of(row)}
  end

  defp changes(schema, old, new) do
    schema
    |> Schema.fact_columns()
    |> Enum.flat_map(&changed(&1, value(old, &1), value(new, &1)))
    |> Map.new()
  end

  defp changed(_column, same, same), do: []
  defp changed(column, before, now), do: [{column, {before, now}}]

  defp value(nil, _column), do: nil
  defp value(row, column), do: Map.get(row, column)
end
