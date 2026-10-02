defmodule Mediate.Postgres.MigrationTest do
  use ExUnit.Case, async: false

  alias Mediate.Error
  alias Mediate.PolicyRelease
  alias Mediate.Postgres.Binding
  alias Mediate.Postgres.Catalog
  alias Mediate.Postgres.Migration
  alias Mediate.Postgres.Probe
  alias Mediate.Postgres.Version
  alias Mediate.TestRepos.Owner

  @moduletag :durable

  @probe "mediate_probe_rows"
  @table "mediate_migration_test_rows"
  @using "current_setting('mediate.probe', true) = label"

  setup do
    _created = Owner.query!("CREATE TABLE #{@table} (id bigserial PRIMARY KEY, label text)")
    on_exit(fn -> Owner.query!("DROP TABLE IF EXISTS #{@table}") end)
    :ok
  end

  test "protect! turns row-level security on and forces it on the table's owner too" do
    assert Migration.protect!(Owner, @table) == :ok
    assert security() == [true, true]
  end

  test "filter! guards the action, so the rule of one action cannot widen another" do
    assert Migration.filter!(Owner, table: @table, action: :read, using: @using) == :ok
    assert Migration.filter!(Owner, table: @table, action: :edit, using: @using) == :ok

    assert [edit, read] = rules()
    assert {read.name, read.command} == {"mediate_filter_read", :select}
    assert read.using =~ "current_setting('mediate.action'::text, true) = 'read'::text"
    assert read.using =~ "label"
    assert read.with_check == nil
    assert {edit.name, edit.command} == {"mediate_filter_edit", :select}
    assert edit.using =~ "'edit'::text"
  end

  test "a gate carries no action guard, so the database refuses the write whether or not anything asked" do
    assert Migration.gate!(Owner, table: @table, action: :edit, using: @using, with_check: @using) == :ok

    assert [gate] = rules()
    assert {gate.name, gate.command} == {"mediate_gate_edit", :update}
    refute gate.using =~ "mediate.action"
    assert gate.with_check == gate.using
  end

  test "an action whose write is an insert has no row to read first, so its gate checks the new row alone" do
    assert Migration.gate!(Owner, table: @table, action: :add, command: :insert, with_check: @using) == :ok

    assert [gate] = rules()
    assert {gate.name, gate.command} == {"mediate_gate_add", :insert}
    assert gate.using == nil
    assert gate.with_check =~ "label"
  end

  test "admit! adds the permissive true rule a command needs under forced row-level security" do
    Enum.each([:insert, :delete, :select, :update], &(:ok = Migration.admit!(Owner, table: @table, command: &1)))

    assert [delete, insert, select, update] = rules()
    assert {delete.name, delete.command, delete.using} == {"mediate_admit_delete", :delete, "true"}
    assert {insert.name, insert.command, insert.with_check} == {"mediate_admit_insert", :insert, "true"}
    assert {select.name, select.command, select.using} == {"mediate_admit_select", :select, "true"}
    assert {update.command, update.using, update.with_check} == {:update, "true", "true"}
  end

  test "exempt! admits the role's statements while no action is in force" do
    assert Migration.exempt!(Owner, table: @table, to: "mediate_app") == :ok

    assert [delete, insert, select, update] = rules()
    assert {select.name, select.command} == {"mediate_exempt_mediate_app_select", :select}
    assert Enum.all?([delete, insert, select, update], &(expression(&1) =~ "mediate_app"))
    assert Enum.all?([delete, insert, select, update], &(expression(&1) =~ "mediate.action"))
    assert {insert.name, insert.using} == {"mediate_exempt_mediate_app_insert", nil}
    assert {delete.name, delete.with_check} == {"mediate_exempt_mediate_app_delete", nil}
    assert update.with_check == update.using
  end

  test "a role whose reads are unfiltered takes the rule that holds always" do
    assert Migration.exempt!(Owner, table: @table, to: "mediate_owner", commands: [:select], always: true) == :ok

    assert [rule] = rules()
    assert rule.name == "mediate_exempt_mediate_owner_select"
    assert rule.using =~ "mediate_owner"
    refute rule.using =~ "mediate.action"
  end

  test "privileges! is what lets the role reach the table at all" do
    refute privilege("SELECT")

    assert Migration.privileges!(Owner, table: @table, to: "mediate_app", commands: [:select, :insert, :update, :delete]) ==
             :ok

    assert Enum.all?(~w(SELECT INSERT UPDATE DELETE), &privilege/1)
  end

  test "release! reads the rules back, carries them as the release's text, and publishes the core's event" do
    :ok = Migration.filter!(Owner, table: @table, action: :read, using: @using)
    :telemetry.attach(inspect(self()), PolicyRelease.event(), &__MODULE__.forward/4, self())

    release =
      Migration.release!(Owner,
        tables: [@table],
        policy_version: 20_260_909_000_001,
        author: "mediate_postgres",
        approval: "the conformance suite"
      )

    assert %PolicyRelease{engine: Mediate.Postgres, policy_version: "20260909000001"} = release
    assert release.text == Version.text(rules())
    assert release.text =~ "#{@table} mediate_filter_read select"
    assert %DateTime{} = release.released_at
    assert_receive {:policy_release, %{release: ^release}}
  after
    :telemetry.detach(inspect(self()))
  end

  test "load reads the rules a migration wrote after the catalog was kept, and resolve answers the kept one" do
    binding = probe_binding()
    kept = Catalog.load!(binding)
    refute Enum.any?(kept.rules, &(&1.name == "mediate_filter_reloaded"))

    on_exit(fn -> Owner.query!("DROP POLICY IF EXISTS mediate_filter_reloaded ON #{@probe}") end)
    :ok = Migration.filter!(Owner, table: @probe, action: :reloaded, using: "true")

    assert Catalog.resolve(binding) == {:ok, kept}
    assert Enum.any?(Catalog.load!(binding).rules, &(&1.name == "mediate_filter_reloaded"))

    Owner.query!("DROP POLICY mediate_filter_reloaded ON #{@probe}")
    assert Catalog.load!(binding) == kept
  end

  test "a name that is not a lowercase identifier never reaches a statement" do
    assert %Error{reason: :invalid, message: "invalid table: " <> _rest} =
             catch_error(Migration.protect!(Owner, "rows; DROP TABLE #{@table}"))

    assert %Error{reason: :invalid, message: "invalid role: " <> _rest} =
             catch_error(Migration.privileges!(Owner, table: @table, to: "a b", commands: []))
  end

  @doc false
  @spec forward([atom()], map(), map(), pid()) :: :ok
  def forward(_event, _measurements, metadata, pid) do
    send(pid, {:policy_release, metadata})
    :ok
  end

  defp rules, do: Catalog.rules(Owner, [@table])

  defp expression(rule), do: rule.using || rule.with_check

  defp probe_binding do
    {:ok, binding} = Binding.new(repo: Owner, schemas: [Probe.Row])
    binding
  end

  defp security do
    %{rows: [row]} =
      Owner.query!("SELECT relrowsecurity, relforcerowsecurity FROM pg_class WHERE relname = $1", [@table])

    row
  end

  defp privilege(command) do
    %{rows: [[granted]]} = Owner.query!("SELECT has_table_privilege('mediate_app', $1, $2)", [@table, command])
    granted
  end
end
