defmodule Mediate.IdentityWrite do
  @moduledoc """
  The identity write event: one telemetry event for each single-row write
  to an identity schema. The mediated repo computes it from the write
  itself and publishes it inside the write's transaction. So a consumer
  that writes to the same repository from its handler joins that
  transaction.

  [Events](events.html) under "Identity write" has the payload. The value
  before a write is the row the caller loaded. A write a second writer made
  between the load and this write is not in the event. The library
  publishes the event and stores nothing. What an attached consumer does
  with it is the consumer's own business.
  """

  alias Mediate.Schema

  @event [:mediate, :identity, :write]
  @library {:service, "mediate"}

  @typedoc "What the write did to the row."
  @type operation :: :create | :update | :delete

  @typedoc "What every event of one write shares: who asked, under which decision, the correlation id, and the moment."
  @type stamp :: %{
          subject: Mediate.subject(),
          decision_id: Mediate.Id.t() | nil,
          correlation_id: Mediate.Id.t(),
          written_at: DateTime.t()
        }

  @doc "The telemetry event a write publishes, which is what a consumer attaches to."
  @spec event() :: [atom()]
  def event, do: @event

  @doc """
  The subject of a write no decision named, which is the library itself: a
  service named `mediate`. A write through the mediated repo under an
  exemption carries this.
  """
  @spec library() :: Mediate.subject()
  def library, do: @library

  @doc "Publish one write. The row before an insert and the row after a delete are `nil`."
  @spec publish(module(), operation(), struct() | nil, struct() | nil, stamp()) :: :ok
  def publish(schema, operation, old, new, stamp) when is_atom(schema) and is_map(stamp) do
    :telemetry.execute(@event, %{}, payload(schema, operation, old, new, stamp))
  end

  defp payload(schema, operation, old, new, stamp) do
    {kind, _id} = stamp.subject

    %{
      operation: operation,
      identity_kind: Schema.identity_of(schema),
      resource: resource(schema, new || old),
      changes: changes(schema, old, new),
      subject: stamp.subject,
      subject_kind: kind,
      decision_id: stamp.decision_id,
      written_at: stamp.written_at,
      correlation_id: stamp.correlation_id,
      schema: schema
    }
  end

  # The type a consumer names the row by. It is the resource type where the
  # schema protects one. Where the schema protects none, it is the identity
  # kind, which is what a subject schema such as an account table declares.
  defp resource(schema, row) do
    type = Schema.resource_type_of(schema) || Schema.identity_of(schema)

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
