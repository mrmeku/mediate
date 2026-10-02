defmodule Mediate.Test.FakeTest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [from: 2, where: 2]

  alias Mediate.Test.Fake
  alias Mediate.Verdict

  @subject {:user, "11111111-1111-1111-1111-111111111111"}
  @resource {:thing, "22222222-2222-2222-2222-222222222222"}
  @context %{now: ~U[2026-09-08 00:00:00Z]}

  test "it denies by default because no rule matched, under the fake policy version" do
    assert {:ok, %Verdict{effect: :deny, reason: :no_rule_matched, policy_version: "fake"} = verdict} =
             Fake.authorize(@subject, :read, @resource, @context, [])

    assert verdict.meta == %{}
  end

  test "it allows under effect: :allow with a rule_allowed reason naming the fake rule" do
    assert {:ok, %Verdict{effect: :allow, reason: :rule_allowed, meta: %{rule: "fake"}}} =
             Fake.authorize(@subject, :read, @resource, @context, effect: :allow)
  end

  test "filter returns a real dynamic that composes into a query" do
    assert {:ok, {rule, %Verdict{effect: :allow}}} = Fake.filter(@subject, :read, :thing, @context, effect: :allow)

    query = where(from(row in "things", select: row.id), ^rule)
    assert %Ecto.Query{} = query
    assert {:ok, {denied, %Verdict{}}} = Fake.filter(@subject, :read, :thing, @context, [])
    assert %Ecto.Query{} = where(from(row in "things", select: row.id), ^denied)
  end

  test "it declares no filter limit and its options schema" do
    assert Fake.filter_limit() == :infinity
    assert {:ok, [effect: :deny]} = NimbleOptions.validate([], Fake.options_schema())
    assert %Verdict{effect: :deny} = Fake.verdict([])
    assert %Verdict{effect: :allow} = Fake.verdict(effect: :allow)
  end
end

defmodule Mediate.Test.FakeTableTest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [from: 2, where: 2]

  alias Mediate.Error
  alias Mediate.PolicyRelease
  alias Mediate.Test.Fake
  alias Mediate.Verdict

  @user {:user, "acct-a"}
  @other {:user, "acct-b"}
  @folder {:folder, 1}
  @context %{now: ~U[2026-09-08 00:00:00Z]}

  setup do
    rules = start_supervised!(%{id: Fake, start: {Fake, :start_link, []}})
    {:ok, rules: rules, options: [rules: rules]}
  end

  test "an entry allows one subject one action on one resource and nothing else", %{rules: rules, options: options} do
    :ok = Fake.allow(rules, "acct-a", :read, {:folder, 1})
    assert {:ok, %Verdict{effect: :allow}} = Fake.authorize(@user, :read, @folder, @context, options)
    assert {:ok, %Verdict{effect: :deny}} = Fake.authorize(@user, :edit, @folder, @context, options)
    assert {:ok, %Verdict{effect: :deny}} = Fake.authorize(@other, :read, @folder, @context, options)
    assert {:ok, %Verdict{effect: :deny}} = Fake.authorize(@user, :read, {:folder, 2}, @context, options)
    assert Fake.entries(rules) == [{"acct-a", :read, {:folder, 1}}]
    :ok = Fake.revoke(rules, "acct-a", :read, {:folder, 1})
    assert Fake.entries(rules) == []
    assert {:ok, %Verdict{effect: :deny}} = Fake.authorize(@user, :read, @folder, @context, options)
  end

  test "an entry naming a whole subject allows that kind and not another of the same account",
       %{rules: rules, options: options} do
    :ok = Fake.allow(rules, {:privileged, "acct-a"}, :edit, {:folder, 1})

    assert {:ok, %Verdict{effect: :allow}} =
             Fake.authorize({:privileged, "acct-a"}, :edit, @folder, @context, options)

    assert {:ok, %Verdict{effect: :deny}} = Fake.authorize(@user, :edit, @folder, @context, options)

    assert {:ok, {rule, %Verdict{effect: :allow}}} =
             Fake.filter({:privileged, "acct-a"}, :edit, :folder, @context, options)

    assert inspect(rule) =~ "row.id in"
    assert {:ok, {_none, %Verdict{effect: :deny}}} = Fake.filter(@user, :edit, :folder, @context, options)
  end

  test "any as the subject or the resource id is a wildcard", %{rules: rules, options: options} do
    :ok = Fake.allow(rules, :any, :read, {:folder, 1})
    :ok = Fake.allow(rules, "acct-b", :edit, {:folder, :any})
    assert {:ok, %Verdict{effect: :allow}} = Fake.authorize(@other, :read, @folder, @context, options)
    assert {:ok, %Verdict{effect: :allow}} = Fake.authorize(@other, :edit, {:folder, 9}, @context, options)
    assert {:ok, %Verdict{effect: :deny}} = Fake.authorize(@user, :edit, @folder, @context, options)
  end

  test "filter narrows to the ids allowed, everything under a wildcard, nothing without", %{
    rules: rules,
    options: options
  } do
    query = from(row in "folders", select: row.id)

    assert {:ok, {none, %Verdict{effect: :deny}}} = Fake.filter(@user, :read, :folder, @context, options)

    assert %Ecto.Query{} = where(query, ^none)

    :ok = Fake.allow(rules, "acct-a", :read, {:folder, 1})

    assert {:ok, {some, %Verdict{effect: :allow}}} = Fake.filter(@user, :read, :folder, @context, options)

    assert inspect(some) =~ "row.id in"

    :ok = Fake.allow(rules, :any, :read, {:folder, :any})

    assert {:ok, {all, %Verdict{effect: :allow}}} = Fake.filter(@other, :read, :folder, @context, options)

    assert inspect(all) =~ "true"
  end

  test "a failing table answers every call with an engine error until told otherwise", %{
    rules: rules,
    options: options
  } do
    :ok = Fake.allow(rules, "acct-a", :read, {:folder, 1})
    :ok = Fake.fail(rules, "down")

    assert {:error, %Error{reason: :engine_failed, message: message}} =
             Fake.authorize(@user, :read, @folder, @context, options)

    assert message == "#{inspect(Fake)} failed during authorize: down"
    assert_down(Fake.filter(@user, :read, :folder, @context, options), :filter)
    :ok = Fake.fail(rules, nil)
    assert {:ok, %Verdict{effect: :allow}} = Fake.authorize(@user, :read, @folder, @context, options)
    :ok = Fake.reset(rules)
    assert Fake.entries(rules) == []
    assert {:ok, %Verdict{effect: :deny}} = Fake.authorize(@user, :read, @folder, @context, options)
  end

  test "a release changes the version every verdict reports, carries the entries, and is published", %{
    rules: rules,
    options: options
  } do
    :ok = Mediate.Test.with_config(engine: {Fake, rules: rules})
    event = PolicyRelease.event()
    handler = :telemetry_test.attach_event_handlers(self(), [event])
    on_exit(fn -> :telemetry.detach(handler) end)
    :ok = Fake.allow(rules, @user, :read, @folder)
    assert {:ok, %Verdict{policy_version: "fake"}} = Fake.authorize(@user, :read, @folder, @context, options)

    assert {:ok, %PolicyRelease{engine: Fake, policy_version: "v2", text: text, released_at: %DateTime{}} = release} =
             Fake.release(rules, "v2")

    assert text == inspect([{@user, :read, @folder}])
    assert release.text_hash == Base.encode16(:crypto.hash(:sha256, text), case: :lower)
    assert_receive {^event, ^handler, %{}, %{release: ^release}}

    assert {:ok, %Verdict{effect: :allow, policy_version: "v2"}} =
             Fake.authorize(@user, :read, @folder, @context, options)

    assert {:ok, {_dynamic, %Verdict{policy_version: "v2"}}} = Fake.filter(@user, :read, :folder, @context, options)
    :ok = Fake.reset(rules)

    assert {:ok, %Verdict{effect: :deny, policy_version: "fake"}} =
             Fake.authorize(@user, :read, @folder, @context, options)
  end

  # Every callback of a failed table answers the same engine error, and the error names the callback.
  defp assert_down(result, function) do
    assert {:error, %Error{reason: :engine_failed, message: message}} = result
    assert message =~ "during #{function}"
  end
end
