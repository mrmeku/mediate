defmodule Mediate.OpenFGA.GuardTest.Cleared do
  @moduledoc "A guard that admits what the context says is cleared and nothing else."

  @behaviour Mediate.OpenFGA.Guard

  @impl Mediate.OpenFGA.Guard
  def admits?(action, context) when action in [:read, :edit] do
    Map.get(context, :cleared) == true
  end

  def admits?(_action, _context), do: false
end

defmodule Mediate.OpenFGA.GuardTest do
  # What every callback relies on when it asks a guard. It answers a
  # boolean about every action under every context, and the same answer
  # twice. It admits nothing beyond what the test told it to admit, because
  # a guard that cannot tell is a guard that does not admit.
  use ExUnit.Case, async: true

  alias Mediate.OpenFGA.GuardTest.Cleared

  @now ~U[2026-09-09 12:00:00.000000Z]
  @admitted %{now: @now, cleared: true}
  @refused %{now: @now, cleared: false}
  @undeclared :mediate_openfga_guard_test_undeclared_action

  @actions [:read, :edit]
  @contexts [%{}, @admitted, @refused]

  test "every action under every context answers a boolean" do
    answers = for action <- [@undeclared | @actions], context <- @contexts, do: ask(action, context)

    assert answers != []
    assert Enum.all?(answers, &is_boolean/1)
  end

  test "a guard asked twice about the same call answers the same" do
    for action <- [@undeclared | @actions], context <- @contexts do
      assert ask(action, context) == ask(action, context)
    end
  end

  test "a context the deployment says is admitted admits every action" do
    for action <- @actions, do: assert(ask(action, @admitted), "#{inspect(action)} under #{inspect(@admitted)}")
  end

  test "a context the deployment says is refused refuses every action" do
    for action <- @actions, do: refute(ask(action, @refused), "#{inspect(action)} under #{inspect(@refused)}")
  end

  test "an action the deployment never declared is not admitted, whatever the context" do
    for context <- @contexts, do: refute(ask(@undeclared, context))
  end

  defp ask(action, context), do: Cleared.admits?(action, context)
end
