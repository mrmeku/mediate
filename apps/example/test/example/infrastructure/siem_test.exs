defmodule Example.Infrastructure.SiemTest do
  use Example.FakeCase, async: true

  alias Example.Application.Repositories
  alias Example.Fixture
  alias Example.Infrastructure.Siem

  test "an attached consumer maps the decision, the access, and the changes of one operation, oldest first, and answers by correlation id",
       ctx do
    siem = start_supervised!({Siem, [attach: true]})
    repository = Fixture.repository!(ctx.world)
    allow(ctx.rules, "dana", :change_visibility, {:repository, repository.id})
    dana = Fixture.subject("dana")
    visibility = %{labels: ["secrets"], restrictions: [:employees_only]}

    assert {:ok, _visibility} = Repositories.change_visibility(dana, repository.id, visibility, operation_id: "op-9")

    assert [decision, got, preloaded, visibility, %{entity: %{type: "repository"}}] = Siem.records(siem, "op-9")
    assert {decision.class_uid, decision.status} == {6003, "Success"}
    assert decision.api.operation == "change_visibility"
    assert {got.class_uid, got.activity_name, got.table.name} == {6005, "Read", "repository"}
    assert got.unmapped.ids == [to_string(repository.id)]
    assert preloaded.unmapped == got.unmapped
    assert {visibility.class_uid, visibility.activity_name} == {3004, "Update"}
    assert visibility.entity.type == "visibility"
    assert visibility.actor == %{user: %{uid: "dana", type_id: 1, type: "User"}}
    assert Map.has_key?(visibility.unmapped.changes, :labels)
    assert decision.metadata.version == Siem.schema_version()
    assert Enum.take(Siem.records(siem), -5) == Siem.records(siem, "op-9")
    assert Siem.records(siem, "op-3") == []
    :ok = stop_supervised!(Siem)
  end
end
