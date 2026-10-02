defmodule Mediate.ConfigTest do
  use ExUnit.Case, async: false

  alias Mediate.Config
  alias Mediate.Error
  alias Mediate.Test.Fake

  defmodule NoOptions do
    @moduledoc false
    @behaviour Mediate.Engine

    @impl Mediate.Engine
    def filter_limit, do: 100
    @impl Mediate.Engine
    defdelegate authorize(subject, action, resource, context, options), to: Fake
    @impl Mediate.Engine
    defdelegate filter(subject, action, resource_type, context, options), to: Fake
  end

  # The umbrella root starts every application before any suite runs, so a
  # boot config can exist. These tests assume none and put it back after.
  setup do
    booted = :persistent_term.get(Config, nil)
    :persistent_term.erase(Config)
    on_exit(fn -> if booted, do: :persistent_term.put(Config, booted), else: :persistent_term.erase(Config) end)
  end

  test "new/1 validates the engine tuple, its options, and the defaults" do
    assert {:ok, %Config{} = config} = Config.new(engine: {Fake, effect: :allow})
    assert config.engine == {Fake, effect: :allow}
    assert Config.engine(config) == {Fake, effect: :allow}
    assert %DateTime{time_zone: "Etc/UTC"} = config.clock.()
    assert config.caps == [policy_text_bytes: 65_536]
  end

  test "new/1 accepts a bare engine module and fills its option defaults" do
    assert {:ok, %Config{engine: {Fake, effect: :deny}} = config} = Config.new(engine: Fake)
    assert Config.engine(config) == {Fake, effect: :deny}
    assert Config.engine(%{config | engine: Fake}) == {Fake, []}
  end

  test "new/1 rejects a missing field, a wrong option, and a module that is not an engine" do
    assert {:error, %Error{reason: :invalid, message: "invalid config: " <> _rest}} =
             Config.new(clock: &DateTime.utc_now/0)

    assert {:error, %Error{reason: :invalid, message: "invalid engine: " <> message}} =
             Config.new(engine: {Fake, effect: :maybe})

    assert message =~ "effect"

    assert {:error, %Error{reason: :invalid, message: "invalid engine: " <> _rest}} = Config.new(engine: Enum)

    assert {:error, %Error{reason: :invalid, message: "invalid engine: " <> _rest}} =
             Config.new(engine: Mediate.NoSuchEngine)
  end

  test "new/1 rejects options for an engine that declares no schema" do
    assert {:ok, %Config{engine: {NoOptions, []}}} = Config.new(engine: NoOptions)

    assert {:error, %Error{reason: :invalid, message: "invalid engine: " <> message}} =
             Config.new(engine: {NoOptions, x: 1})

    assert message =~ "takes no options"
  end

  test "new!/1 raises the error" do
    assert_raise Error, ~r/invalid config/, fn -> Config.new!([]) end
    assert %Config{} = Config.new!(engine: Fake)
  end

  test "resolve/0 fails when nothing is booted and nothing is overridden" do
    assert {:error, %Error{reason: :invalid, message: "invalid config: nothing booted and no override"}} =
             Config.resolve()
  end

  test "resolve/0 answers from the override alone" do
    Mediate.Test.with_config(engine: Fake)
    assert {:ok, %Config{engine: {Fake, effect: :deny}}} = Config.resolve()
  end

  test "resolve/0 merges the override onto the boot struct and round-trips through to_keyword/1" do
    booted = Config.boot!(engine: Fake, caps: [policy_text_bytes: 512])
    assert Config.new!(Config.to_keyword(booted)) == booted
    assert {:ok, ^booted} = Config.resolve()

    Mediate.Test.with_config([caps: [policy_text_bytes: 8]], fn ->
      assert {:ok, %Config{caps: [policy_text_bytes: 8]}} = Config.resolve()
    end)

    assert {:ok, ^booted} = Config.resolve()
  end

  test "resolve/0 reads the override from the $callers chain" do
    Mediate.Test.with_config(engine: {Fake, effect: :allow})

    assert {:ok, %Config{engine: {Fake, effect: :allow}}} =
             Task.await(Task.async(fn -> Task.await(Task.async(&Config.resolve/0)) end))

    assert {:error, %Error{reason: :invalid}} =
             Task.await(Task.async(fn -> Process.delete(:"$callers") && Config.resolve() end))
  end

  test "with_config/2 restores the previous override even when the function raises" do
    Mediate.Test.with_config(engine: Fake)

    assert_raise RuntimeError, fn ->
      Mediate.Test.with_config([caps: [policy_text_bytes: 8]], fn -> raise "boom" end)
    end

    assert {:ok, %Config{caps: [policy_text_bytes: 65_536]}} = Config.resolve()
  end

  test "override_key/0 names the process dictionary key" do
    assert Config.override_key() == Config
  end
end
