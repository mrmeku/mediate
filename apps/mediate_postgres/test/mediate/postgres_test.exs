defmodule Mediate.PostgresTest do
  use ExUnit.Case, async: true

  alias Ecto.Adapters.SQL.Sandbox
  alias Mediate.Decision
  alias Mediate.Error
  alias Mediate.Fixture.Account
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Item
  alias Mediate.Fixture.Membership
  alias Mediate.Id
  alias Mediate.Postgres
  alias Mediate.Postgres.Binding
  alias Mediate.Postgres.Catalog
  alias Mediate.Postgres.Conformance.Reference
  alias Mediate.Postgres.Domain.Settings
  alias Mediate.Postgres.Infrastructure.Session
  alias Mediate.TestRepos.Sandboxed
  alias Mediate.Verdict

  @schemas [Account, Folder, Item, Membership]
  @subject {:user, "account-1"}
  @resource {:folder, 1}

  test "the declaration: no filter limit, and a replica lag the engine does not measure" do
    assert Postgres.filter_limit() == :infinity
    assert Postgres.replica_lag() == "not measured"
  end

  test "with nothing bound every callback answers an engine failure naming the callback" do
    assert {:error, %Error{reason: :engine_failed, message: message}} =
             Postgres.authorize(@subject, :read, @resource, context(), [])

    assert message ==
             "#{inspect(Postgres)} failed during authorize: invalid binding: nothing bound and no override; " <>
               "call Mediate.Postgres.Binding.bind!/1 at boot"

    assert {:error, %Error{reason: :engine_failed, message: "Mediate.Postgres failed during filter" <> _rest}} =
             Postgres.filter(@subject, :read, :folder, context(), [])

    assert {:error, %Error{reason: :invalid}} = Postgres.load_catalog()
    assert_raise Error, fn -> Postgres.load_catalog!() end
  end

  test "load_catalog reads the catalog and keeps it, and a call on the request path reads nothing" do
    bind()

    assert {:ok, %Catalog{policy_version: policy_version, rules: [_rule | _rest]}} = Postgres.load_catalog()
    assert policy_version == to_string(Reference.version())
    assert Postgres.load_catalog!() == Postgres.load_catalog!()
  end

  test "a catalog the engine cannot read is an engine failure naming the callback" do
    bind(migration_source: "mediate_no_such_table")

    assert {:error, %Error{reason: :engine_failed, message: message}} =
             Postgres.authorize(@subject, :read, @resource, context(), [])

    assert message =~ "Mediate.Postgres failed during authorize: catalog read failed"
    assert message =~ "mediate_no_such_table"
  end

  test "a resource type no bound schema declares matches no rule, and the verdict names the type" do
    bind()

    assert {:ok, %Verdict{effect: :deny, reason: :no_rule_matched, meta: %{resource_type: :no_such_type}}} =
             Postgres.authorize(@subject, :read, {:no_such_type, 1}, context(), [])
  end

  test "an action with no filter rule on the type is unknown to the filter" do
    bind()

    assert {:ok, {_rule, %Verdict{effect: :deny, reason: :action_unknown}}} =
             Postgres.filter(@subject, :publish, :folder, context(), [])
  end

  test "a filter names the rule and the hash of the settings the database will read" do
    bind()
    settings = Settings.new(@subject, :read, context())

    assert {:ok, {_rule, %Verdict{effect: :allow} = verdict}} = Postgres.filter(@subject, :read, :folder, context(), [])

    assert verdict.reason == :rule_allowed
    assert verdict.meta == %{rule: "mediate_filter_read", settings_hash: Settings.hash(settings)}
    assert Session.recall(@subject, :read) == settings
  end

  test "around_query runs the settings of the call that produced the decision" do
    bind()
    settings = Settings.new(@subject, :read, context())
    :ok = Session.remember(@subject, :read, settings)

    assert Postgres.around_query(Folder, decision(), fn -> setting("mediate.subject_id") end) == "account-1"
  end

  test "the session keeps one slot per subject and action, so a review recalls every subject's call" do
    bind()
    other = {:user, "account-2"}
    facts = Map.put(context(), :clearance, "cleared")
    mine = Settings.new(@subject, :read, facts)
    theirs = Settings.new(other, :read, facts)
    :ok = Session.remember(@subject, :read, mine)
    :ok = Session.remember(other, :read, theirs)

    assert Session.recall(@subject, :read) == mine
    assert Session.recall(other, :read) == theirs
    assert Session.recall(@subject, :publish) == nil
  end

  test "around_query with the call out of reach sets what the decision alone determines" do
    bind()

    assert Postgres.around_query(Folder, decision(), fn -> setting("mediate.action") end) == "read"
  end

  test "around_query with nothing bound runs the function and sets nothing" do
    assert Postgres.around_query(Folder, decision(), fn -> :ran end) == :ran
  end

  test "a mediated call inside another leaves behind the settings of the call around it" do
    bind()
    inner = {:user, "account-2"}

    read =
      Postgres.around_query(Folder, decision(), fn ->
        nested = Postgres.around_query(Folder, decision(inner), fn -> setting("mediate.subject_id") end)
        {nested, setting("mediate.subject_id")}
      end)

    assert read == {"account-2", "account-1"}
    assert setting("mediate.subject_id") == ""
  end

  defp context(facts \\ %{}) do
    Map.put(facts, :now, ~U[2026-09-08 12:00:00Z])
  end

  defp decision(subject \\ @subject) do
    %Decision{
      id: Id.new(),
      subject: subject,
      resource: {:folder, 1},
      action: :read,
      effect: :allow,
      reason: :rule_allowed,
      engine: Postgres,
      policy_version: nil,
      correlation_id: Id.new(),
      decided_at: ~U[2026-09-08 12:00:00Z]
    }
  end

  defp setting(name) do
    %{rows: [[value]]} =
      Sandboxed.query!("SELECT current_setting($1, true)", [name], authorized_by: {:exempt, "test"})

    value
  end

  defp bind(overrides \\ []) do
    :ok = Sandbox.checkout(Sandboxed)
    Binding.override(Keyword.merge([repo: Sandboxed, schemas: @schemas], overrides))
  end
end
