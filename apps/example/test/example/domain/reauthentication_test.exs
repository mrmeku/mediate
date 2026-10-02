defmodule Example.Domain.ReauthenticationTest do
  use ExUnit.Case, async: true

  alias Example.Domain.Reauthentication

  @now ~U[2026-09-08 12:00:00Z]

  test "a session is fresh within the window of the clock and stale outside it" do
    assert Reauthentication.window() == 900
    assert Reauthentication.fresh?(%{now: @now, reauthenticated_at: @now})
    assert Reauthentication.fresh?(%{now: @now, reauthenticated_at: DateTime.shift(@now, minute: -15)})
    refute Reauthentication.fresh?(%{now: @now, reauthenticated_at: DateTime.shift(@now, second: -901)})
    refute Reauthentication.fresh?(%{now: @now, reauthenticated_at: DateTime.shift(@now, second: 1)})
  end

  test "an absent or malformed fact is stale" do
    refute Reauthentication.fresh?(%{now: @now})
    refute Reauthentication.fresh?(%{now: @now, reauthenticated_at: "yesterday"})
  end
end
