defmodule MediateTest do
  use ExUnit.Case, async: true

  alias Ecto.Query.DynamicExpr
  alias Mediate.Decision
  alias Mediate.Error
  alias Mediate.Test.Fake

  defmodule Raising do
    @moduledoc false
    @behaviour Mediate.Engine

    @impl Mediate.Engine
    def filter_limit, do: :infinity

    @impl Mediate.Engine
    def authorize(_subject, _action, _resource, _context, _options), do: raise("the engine broke")

    @impl Mediate.Engine
    def filter(_subject, _action, _type, _context, _options), do: raise("the engine broke")
  end

  @user {:user, "acct-a"}
  @service {:service, "svc-a"}
  @robot {:robot, "r2"}
  @folder {:folder, 1}

  setup do
    rules = start_supervised!(%{id: Fake, start: {Fake, :start_link, []}})
    :ok = Fake.allow(rules, "acct-a", :read, {:folder, 1})
    :ok = Mediate.Test.with_config(engine: {Fake, rules: rules})
    handler = :telemetry_test.attach_event_handlers(self(), [Mediate.event()])
    on_exit(fn -> :telemetry.detach(handler) end)
    {:ok, rules: rules}
  end

  test "every function takes empty options by default" do
    assert {:ok, %Decision{effect: :allow}} = Mediate.authorize(@user, :read, @folder)
    assert Mediate.authorized?(@user, :read, @folder)
    assert {_rule, %Decision{effect: :filter}} = Mediate.filter(@user, :read, :folder)
    assert %{@user => {_rule, %Decision{effect: :filter}}} = Mediate.review(@user, [@user], :read, :folder)
  end

  test "a call publishes one decision event carrying who asked, what was answered, and how long it took" do
    assert {:ok, %Decision{effect: :allow} = decision} = Mediate.authorize(@user, :read, @folder, [])

    assert_received {[:mediate, :decision], _ref, %{duration_microseconds: duration}, metadata}
    assert duration >= 0
    assert metadata.decision_id == decision.id
    assert metadata.subject == @user
    assert metadata.subject_kind == :user
    assert metadata.action == :read
    assert metadata.resource == {:folder, 1}
    assert metadata.effect == :allow
    assert metadata.reason == :rule_allowed
    assert metadata.engine == Fake
    assert metadata.context == %{}
    assert metadata.exception == nil
    assert %DateTime{} = metadata.decided_at
    assert is_binary(metadata.correlation_id)

    assert Mediate.authorized?(@service, :read, @folder, context: %{shift: :night}) == false
    assert_received {[:mediate, :decision], _ref, _measurements, %{effect: :deny, subject_kind: :service}}
  end

  test "an unknown subject kind is denied before the engine is asked, and its event says so" do
    assert {:error, %Error{reason: :subject_kind_unknown}} = Mediate.authorize(@robot, :read, @folder, [])

    assert {_rule, %Decision{effect: :deny}} = Mediate.filter(@robot, :read, :folder, [])

    assert_received {[:mediate, :decision], _ref, _measurements,
                     %{subject_kind: :unknown, effect: :deny, reason: :subject_kind_unknown}}
  end

  test "an engine error denies with the engine's message beside the reason", %{rules: rules} do
    :ok = Fake.fail(rules, "engine down")

    assert {:error, %Error{reason: :engine_failed} = error} = Mediate.authorize(@user, :read, @folder, [])

    assert Exception.message(error) ==
             "user acct-a may not read {:folder, 1}: engine_failed " <>
               "(#{inspect(Fake)} failed during authorize: engine down)"
  end

  test "a filter call publishes the rule in the resource's place" do
    assert {_rule, %Decision{effect: :filter}} = Mediate.filter(@user, :read, :folder, [])
    assert_received {[:mediate, :decision], _ref, _measurements, %{effect: :filter, resource: rule}}
    assert %DynamicExpr{} = rule
  end

  test "an engine that raises denies closed, and its event carries the exception" do
    :ok = Mediate.Test.with_config(engine: Raising)

    assert {:error, %Error{reason: :engine_failed} = error} = Mediate.authorize(@user, :read, @folder, [])
    assert Exception.message(error) =~ "#{inspect(Raising)} raised during authorize: the engine broke"

    assert_received {[:mediate, :decision], _ref, _measurements,
                     %{exception: %RuntimeError{}, effect: :deny, reason: :engine_failed}}

    assert Mediate.authorized?(@user, :read, @folder, []) == false
    assert {_rule, %Decision{effect: :deny, reason: :engine_failed}} = Mediate.filter(@user, :read, :folder, [])

    assert_received {[:mediate, :decision], _ref, _measurements,
                     %{exception: %RuntimeError{}, resource: %DynamicExpr{}, reason: :engine_failed}}
  end

  test "review answers a rule and a decision per subject over a type, each its own record under one correlation id" do
    reviewed = Mediate.review(@user, [@user, @service, @robot], :read, :folder, [])
    assert map_size(reviewed) == 3
    assert Enum.all?(reviewed, fn {_subject, {rule, %Decision{}}} -> match?(%DynamicExpr{}, rule) end)

    {_rule, %Decision{effect: :filter, subject: @user, correlation_id: id}} = reviewed[@user]
    assert %Decision{effect: :deny, subject: @robot, correlation_id: ^id} = elem(reviewed[@robot], 1)

    assert_received {[:mediate, :decision], _ref, _measurements,
                     %{subject: @user, effect: :filter, resource: %DynamicExpr{}}}

    assert_received {[:mediate, :decision], _ref, _measurements,
                     %{subject: @robot, effect: :deny, subject_kind: :unknown}}

    assert_received {[:mediate, :decision], _ref, _measurements,
                     %{subject: @user, effect: :filter, resource: {:folder, :all}, correlation_id: ^id}}
  end

  test "the correlation id given is the one every record of the call carries" do
    id = Mediate.Id.new()
    assert {:ok, %Decision{correlation_id: ^id}} = Mediate.authorize(@user, :read, @folder, correlation_id: id)
    assert_received {[:mediate, :decision], _ref, _measurements, %{correlation_id: ^id}}

    assert_raise NimbleOptions.ValidationError, fn ->
      Mediate.authorized?(@user, :read, @folder, correlation_id: 1)
    end
  end
end
