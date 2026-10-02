defmodule Example.Infrastructure.OCSF do
  @moduledoc false
  # Hidden, because the format a security log takes is the consumer's and
  # not this package's surface. What is here is the mapping from the
  # library's three events to OCSF records, against schema version 1.3.0.
  #
  # The library carries what an event means, and this module carries the
  # format. The class, category, severity, and type identifiers, the
  # product metadata, and the shape of the actor are the consumer's. Each
  # depends on the schema version, and the identifiers move between
  # versions.

  @version "1.3.0"
  @product %{name: "Example", vendor_name: "Mediate"}

  @classes %{
    account: {3, 3001, "Account Change"},
    group: {3, 3006, "Group Management"},
    role: {3, 3005, "User Access Management"},
    other: {3, 3004, "Entity Management"}
  }

  @operations %{create: {1, "Create"}, update: {3, "Update"}, delete: {4, "Delete"}}
  @actions %{create: {1, "Create"}, read: {2, "Read"}, update: {3, "Update"}, delete: {4, "Delete"}}
  @other {99, "Other"}
  @api {6, 6003, "API Activity"}
  @datastore {6, 6005, "Datastore Activity"}
  @cardinalities %{one: {1, "Read"}, many: {4, "Query"}}

  @subject_kinds %{user: {1, "User"}, privileged: {2, "Admin"}, service: {3, "System"}}
  @unknown_user {0, "Unknown"}

  @doc "The schema version this mapping targets."
  @spec version() :: String.t()
  def version, do: @version

  @doc "An identity write event as the record of a managed entity that changed."
  @spec identity_write(map()) :: map()
  def identity_write(payload) when is_map(payload) do
    {category, class, name} = Map.fetch!(@classes, payload.identity_kind)
    {activity, activity_name} = Map.fetch!(@operations, payload.operation)

    %{
      category_uid: category,
      class_uid: class,
      class_name: name,
      activity_id: activity,
      activity_name: activity_name,
      type_uid: class * 100 + activity,
      severity_id: 1,
      time: payload.written_at,
      actor: actor(payload.subject, payload.subject_kind),
      entity: reference(payload.resource),
      metadata: metadata(payload.correlation_id),
      unmapped: %{changes: changes(payload.changes), schema: inspect(payload.schema)}
    }
  end

  @doc "A decision event as the record of an API activity, with its duration in microseconds."
  @spec decision(map(), non_neg_integer()) :: map()
  def decision(payload, duration) when is_map(payload) and is_integer(duration) do
    {category, class, name} = @api
    {activity, activity_name} = Map.get(@actions, payload.action, @other)

    record = %{
      category_uid: category,
      class_uid: class,
      class_name: name,
      activity_id: activity,
      activity_name: activity_name,
      type_uid: class * 100 + activity,
      time: payload.decided_at,
      duration: duration,
      actor: actor(payload.subject, payload.subject_kind),
      resource: reference(payload.resource),
      api: %{operation: Atom.to_string(payload.action), response: %{message: text(payload.reason)}},
      metadata: metadata(payload.correlation_id),
      unmapped: decided(payload)
    }

    Map.merge(record, outcome(payload.effect))
  end

  @doc "A resource read event as the record of a datastore activity: a read of one row or a query of the type's table."
  @spec resource_read(map()) :: map()
  def resource_read(payload) when is_map(payload) do
    {category, class, name} = @datastore
    {activity, activity_name} = Map.fetch!(@cardinalities, payload.cardinality)

    %{
      category_uid: category,
      class_uid: class,
      class_name: name,
      activity_id: activity,
      activity_name: activity_name,
      type_uid: class * 100 + activity,
      status_id: 1,
      status: "Success",
      severity_id: 1,
      time: payload.read_at,
      actor: actor(payload.subject, payload.subject_kind),
      database: %{name: inspect(payload.repo)},
      table: %{name: text(payload.resource_type)},
      metadata: metadata(payload.correlation_id),
      unmapped: %{
        primary_keys: Enum.map(payload.primary_keys, &identifier/1),
        count: payload.count,
        decision_id: payload.decision_id
      }
    }
  end

  # An effect is a status and a severity, which is what a security log
  # sorts and alerts on. A filter answers a rule and not a yes or a no. It
  # refuses nothing, so the record says success.
  defp outcome(:allow), do: %{status_id: 1, status: "Success", severity_id: 1}
  defp outcome(:filter), do: %{status_id: 1, status: "Success", severity_id: 1}
  defp outcome(:deny), do: %{status_id: 2, status: "Failure", severity_id: 2}

  # What OCSF names no field for: which engine answered, under which
  # policy version, from which context, and what it raised.
  defp decided(payload) do
    %{
      engine: inspect(payload.engine),
      policy_version: payload.policy_version,
      context: payload.context,
      decision_id: payload.decision_id,
      exception: exception(payload.exception)
    }
  end

  defp metadata(correlation_id) do
    %{version: @version, product: @product, correlation_uid: correlation_id}
  end

  defp actor({_kind, id}, kind) do
    {type, type_name} = Map.get(@subject_kinds, kind, @unknown_user)

    %{user: %{uid: identifier(id), type_id: type, type: type_name}}
  end

  # A filter call answers about a query and not a row. The query is a rule
  # over fact values, which no record of this example carries.
  defp reference({type, id}) when is_atom(type), do: %{type: text(type), uid: identifier(id)}
  defp reference(_rule), do: %{type: "query", uid: nil}

  defp changes(changes) do
    Map.new(changes, fn {field, {old, new}} -> {field, %{before: old, after: new}} end)
  end

  defp exception(nil), do: nil
  defp exception(exception), do: inspect(exception.__struct__)

  defp text(nil), do: nil
  defp text(atom), do: Atom.to_string(atom)

  defp identifier(nil), do: nil
  defp identifier(id), do: to_string(id)
end
