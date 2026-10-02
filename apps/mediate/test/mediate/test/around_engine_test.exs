defmodule Mediate.Test.AroundEngineTest do
  use ExUnit.Case, async: true

  alias Mediate.Test.AroundEngine
  alias Mediate.Test.Fake

  @subject {:user, "11111111-1111-1111-1111-111111111111"}
  @resource {:thing, "22222222-2222-2222-2222-222222222222"}
  @context %{now: ~U[2026-09-08 00:00:00Z]}

  test "every callback but around_query answers as the fake engine does" do
    assert AroundEngine.options_schema() == Fake.options_schema()
    assert AroundEngine.filter_limit() == Fake.filter_limit()
    args = [@subject, :read, @resource, @context, [effect: :allow]]
    assert apply(AroundEngine, :authorize, args) == apply(Fake, :authorize, args)
    filter_args = [@subject, :read, :thing, @context, []]
    assert apply(AroundEngine, :filter, filter_args) == apply(Fake, :filter, filter_args)
  end

  test "around_query sends the query and the decision to the caller, then runs the call" do
    assert :ran = AroundEngine.around_query(:the_query, :the_decision, fn -> :ran end)
    assert_received {:around_query, :the_query, :the_decision}
  end
end
