defmodule Example.Infrastructure.OCSFTest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [dynamic: 2]

  alias Example.Infrastructure.OCSF

  @now ~U[2026-09-08 12:00:00Z]

  @identity_write %{
    operation: :update,
    identity_kind: :role,
    resource: {:role, 7},
    changes: %{role: {:contributor, :admin}},
    subject: {:privileged, "gil"},
    subject_kind: :privileged,
    decision_id: nil,
    written_at: @now,
    correlation_id: "op-1",
    schema: Example.Domain.Membership
  }

  @decision %{
    subject: {:user, "ann"},
    subject_kind: :user,
    action: :read,
    resource: {:repository, 4},
    effect: :allow,
    reason: :rule_allowed,
    engine: Mediate.Test.Fake,
    policy_version: "fake",
    context: %{},
    exception: nil,
    decision_id: "dec-1",
    decided_at: @now,
    correlation_id: "op-1"
  }

  @resource_read %{
    resource_type: :repository,
    schema: Example.Domain.Repository,
    repo: Example.Infrastructure.Repo,
    repo_function: {:get, 3},
    cardinality: :one,
    primary_keys: [4],
    count: 1,
    result_shape: :rows,
    subject: {:user, "ann"},
    subject_kind: :user,
    decision_id: "dec-1",
    read_at: @now,
    correlation_id: "op-1"
  }

  test "an identity write maps to the OCSF class of its identity kind and the activity of its operation" do
    record = OCSF.identity_write(@identity_write)

    assert {record.category_uid, record.class_uid, record.class_name} == {3, 3005, "User Access Management"}
    assert {record.activity_id, record.activity_name} == {3, "Update"}
    assert record.type_uid == 300_503
    assert record.time == @now
    assert record.actor == %{user: %{uid: "gil", type_id: 2, type: "Admin"}}
    assert record.entity == %{type: "role", uid: "7"}

    assert record.metadata == %{
             version: OCSF.version(),
             product: %{name: "Example", vendor_name: "Mediate"},
             correlation_uid: "op-1"
           }

    assert record.unmapped.changes == %{role: %{before: :contributor, after: :admin}}
    assert record.unmapped.schema == "Example.Domain.Membership"
  end

  test "each identity kind has its class and each operation its activity" do
    for {kind, class} <- [account: 3001, group: 3006, role: 3005, other: 3004] do
      assert OCSF.identity_write(%{@identity_write | identity_kind: kind}).class_uid == class
    end

    for {operation, activity} <- [create: 1, update: 3, delete: 4] do
      assert OCSF.identity_write(%{@identity_write | operation: operation}).activity_id == activity
    end
  end

  test "a decision maps to an API activity whose status is the effect and whose duration is the call's" do
    record = OCSF.decision(@decision, 125)

    assert {record.category_uid, record.class_uid, record.class_name} == {6, 6003, "API Activity"}
    assert {record.activity_id, record.activity_name} == {2, "Read"}
    assert record.type_uid == 600_302
    assert {record.status_id, record.status, record.severity_id} == {1, "Success", 1}
    assert record.duration == 125
    assert record.actor == %{user: %{uid: "ann", type_id: 1, type: "User"}}
    assert record.resource == %{type: "repository", uid: "4"}
    assert record.api == %{operation: "read", response: %{message: "rule_allowed"}}
    assert record.unmapped.engine == "Mediate.Test.Fake"
    assert record.unmapped.policy_version == "fake"
    assert record.unmapped.decision_id == "dec-1"
  end

  test "a deny is a failure of low severity, an unnumbered action is other, and a filter is a query that succeeded" do
    denied = OCSF.decision(%{@decision | effect: :deny, reason: :no_rule_matched, action: :change_visibility}, 1)

    assert {denied.status_id, denied.status, denied.severity_id} == {2, "Failure", 2}
    assert {denied.activity_id, denied.activity_name} == {99, "Other"}
    assert denied.api.operation == "change_visibility"
    assert denied.api.response.message == "no_rule_matched"

    filtered = OCSF.decision(%{@decision | effect: :filter, resource: dynamic([row], row.id == 1)}, 1)
    assert filtered.resource == %{type: "query", uid: nil}
    assert {filtered.status_id, filtered.status, filtered.severity_id} == {1, "Success", 1}

    failed = OCSF.decision(%{@decision | effect: :deny, reason: nil, exception: %RuntimeError{}}, 1)
    assert failed.unmapped.exception == "RuntimeError"
    assert failed.api.response.message == nil
  end

  test "a resource read maps to a datastore activity of the table its resource type names, read or query" do
    record = OCSF.resource_read(@resource_read)

    assert {record.category_uid, record.class_uid, record.class_name} == {6, 6005, "Datastore Activity"}
    assert {record.activity_id, record.activity_name} == {1, "Read"}
    assert record.type_uid == 600_501
    assert {record.status_id, record.status, record.severity_id} == {1, "Success", 1}
    assert record.time == @now
    assert record.actor == %{user: %{uid: "ann", type_id: 1, type: "User"}}
    assert record.database == %{name: "Example.Infrastructure.Repo"}
    assert record.table == %{name: "repository"}
    assert record.metadata.correlation_uid == "op-1"
    assert record.unmapped == %{primary_keys: ["4"], count: 1, decision_id: "dec-1"}

    many = %{@resource_read | repo_function: {:all, 2}, cardinality: :many, primary_keys: [], count: 0}
    queried = OCSF.resource_read(%{many | result_shape: :scalar})
    assert {queried.activity_id, queried.activity_name, queried.type_uid} == {4, "Query", 600_504}
    assert queried.unmapped.primary_keys == []
  end

  test "a resource asked about by its type alone carries no id" do
    record = OCSF.decision(%{@decision | resource: {:repository, nil}}, 1)

    assert record.resource == %{type: "repository", uid: nil}
  end

  test "a subject of a kind the mapping does not know is an unknown user" do
    record = OCSF.decision(%{@decision | subject: {:robot, "r2"}, subject_kind: :robot}, 1)

    assert record.actor == %{user: %{uid: "r2", type_id: 0, type: "Unknown"}}
  end
end
