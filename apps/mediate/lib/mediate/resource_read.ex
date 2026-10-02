defmodule Mediate.ResourceRead do
  @moduledoc """
  The resource read event: one telemetry event for each mediated read of a
  protected schema. The mediated repo publishes it after the read returns,
  at the one site every query function passes through. So it covers `get`,
  `one`, `all`, `exists?`, `aggregate`, `stream`, `preload`, and `reload`
  alike. Only a read that carried a decision publishes. An exempt read, a
  read through the owner-role repo, and a raw query publish nothing.

  [Events](events.html) under "Resource read" has the payload. The one
  measurement is `count`. The library publishes the event and stores
  nothing.
  """

  alias Mediate.Decision
  alias Mediate.Schema

  @event [:mediate, :resource, :read]
  @many [:all, :all_by, :stream, :aggregate]

  @typedoc "What the read answered with: rows of the schema, one scalar, or a stream not yet run."
  @type result_shape :: :rows | :scalar | :stream

  @typedoc "Whether the repo function answers one row or many."
  @type cardinality :: :one | :many

  @doc "The telemetry event a read publishes, which is what a consumer attaches to."
  @spec event() :: [atom()]
  def event, do: @event

  @doc "Publish one read: the result under the decision it ran under, at the moment given."
  @spec publish(module(), module(), {atom(), non_neg_integer()}, term(), Decision.t(), DateTime.t()) :: :ok
  def publish(repo, schema, {name, _arity} = repo_function, result, %Decision{} = decision, %DateTime{} = read_at)
      when is_atom(repo) and is_atom(schema) do
    {shape, primary_keys} = shape(schema, result)
    {kind, _id} = decision.subject

    payload = %{
      resource_type: Schema.resource_type_of(schema),
      schema: schema,
      repo: repo,
      repo_function: repo_function,
      cardinality: cardinality(name),
      primary_keys: primary_keys,
      count: length(primary_keys),
      result_shape: shape,
      subject: decision.subject,
      subject_kind: kind,
      decision_id: decision.id,
      read_at: read_at,
      correlation_id: decision.correlation_id
    }

    :telemetry.execute(@event, %{count: length(primary_keys)}, payload)
  end

  defp cardinality(name) when name in @many, do: :many
  defp cardinality(_name), do: :one

  defp shape(_schema, %Stream{}), do: {:stream, []}
  defp shape(_schema, fun) when is_function(fun), do: {:stream, []}

  defp shape(schema, rows) when is_list(rows),
    do: {:rows, for(%{__struct__: ^schema} = row <- rows, do: Schema.id_of(row))}

  defp shape(schema, %{__struct__: schema} = row), do: {:rows, [Schema.id_of(row)]}
  defp shape(_schema, nil), do: {:rows, []}
  defp shape(_schema, _value), do: {:scalar, []}
end
