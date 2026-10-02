defmodule Example.Infrastructure.SIEMTest do
  use Example.FakeCase, async: true

  alias Example.Application.Repositories
  alias Example.Fixture
  alias Example.Infrastructure.SIEM

  test "an attached consumer maps the decision, the reads, and the identity writes of one correlation id, oldest first",
       ctx do
    siem = start_supervised!({SIEM, [attach: true]})
    repository = Fixture.repository!(ctx.world)
    allow(ctx.fake, "dana", :change_visibility, {:repository, repository.id})
    dana = Fixture.subject("dana")
    visibility = %{labels: ["secrets"], restrictions: [:employees_only]}

    assert {:ok, _visibility} = Repositories.change_visibility(dana, repository.id, visibility, correlation_id: "op-9")

    assert [decision, got, preloaded, visibility, %{entity: %{type: "repository"}}] = SIEM.records(siem, "op-9")
    assert {decision.class_uid, decision.status} == {6003, "Success"}
    assert decision.api.operation == "change_visibility"
    assert {got.class_uid, got.activity_name, got.table.name} == {6005, "Read", "repository"}
    assert got.unmapped.primary_keys == [to_string(repository.id)]
    assert preloaded.unmapped == got.unmapped
    assert {visibility.class_uid, visibility.activity_name} == {3004, "Update"}
    assert visibility.entity.type == "visibility"
    assert visibility.actor == %{user: %{uid: "dana", type_id: 1, type: "User"}}
    assert Map.has_key?(visibility.unmapped.changes, :labels)
    assert decision.metadata.version == SIEM.ocsf_version()
    assert Enum.take(SIEM.records(siem), -5) == SIEM.records(siem, "op-9")
    assert SIEM.records(siem, "op-3") == []
    :ok = stop_supervised!(SIEM)
  end
end
