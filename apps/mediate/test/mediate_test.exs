defmodule MediateTest do
  use ExUnit.Case, async: true

  alias Mediate.Decision
  alias Mediate.Test.Fake

  @user {:user, "acct-a"}
  @folder {:folder, 1}

  setup do
    rules = start_supervised!(%{id: Fake, start: {Fake, :start_link, []}})
    :ok = Fake.allow(rules, "acct-a", :read, {:folder, 1})
    :ok = Mediate.Test.with_config(adapter: {Fake, rules: rules})
    :ok
  end

  test "every function delegates to the port with empty options by default" do
    assert {:ok, %Decision{verdict: :allow}} = Mediate.authorize(@user, :read, @folder)
    assert Mediate.check(@user, :read, @folder)
    assert {_rule, %Decision{verdict: :scoped}} = Mediate.scope(@user, :read, :folder)
    assert %{@user => {_rule, %Decision{verdict: :scoped}}} = Mediate.review(@user, [@user], :read, :folder)
  end
end
