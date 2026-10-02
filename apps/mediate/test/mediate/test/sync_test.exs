defmodule Mediate.Test.SyncTest do
  use ExUnit.Case, async: true

  alias Mediate.Error
  alias Mediate.Test
  alias Mediate.Test.Fake
  alias Mediate.Test.SyncingEngine

  test "an engine that keeps no state of its own is stateless" do
    :ok = Test.with_config(engine: {Fake, rules: self()})

    assert Test.sync() == :stateless
  end

  test "an engine that declares the callback and has nothing to sync answers stateless" do
    :ok = Test.with_config(engine: {SyncingEngine, rules: self()})

    assert Test.sync() == :stateless
  end

  test "syncing is the engine's own, and its answer is the answer" do
    :ok =
      bound(fn ->
        send(self(), :synced)

        :ok
      end)

    assert Test.sync() == :ok
    assert_received :synced
  end

  test "a sync that fails raises what it failed with" do
    :ok = bound(fn -> {:error, Error.invalid(:outbox, "the store is out of reach")} end)

    assert_raise Error, ~r/the store is out of reach/, fn -> Test.sync() end
  end

  defp bound(syncing) do
    :ok = Test.with_config(engine: {SyncingEngine, rules: self()})
    SyncingEngine.bind(syncing)
  end
end
