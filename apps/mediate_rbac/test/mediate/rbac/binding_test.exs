defmodule Mediate.Rbac.BindingTest do
  use ExUnit.Case, async: false

  alias Mediate.Error
  alias Mediate.Rbac.Binding
  alias Mediate.Rbac.Conformance.Reference
  alias Mediate.TestRepos.Durable
  alias Mediate.TestRepos.Sandboxed

  # The umbrella root starts every application before any suite runs, so a
  # boot binding can exist. These tests assume none and put it back after.
  setup do
    bound = :persistent_term.get(Binding, nil)
    :persistent_term.erase(Binding)
    on_exit(fn -> if bound, do: :persistent_term.put(Binding, bound), else: :persistent_term.erase(Binding) end)
  end

  test "without a binding every call is an engine error, so the core fails closed" do
    ann = {:user, "ann"}
    context = %{now: DateTime.utc_now()}

    assert {:error, %Error{reason: :engine_failed, message: message}} =
             Mediate.Rbac.filter(ann, :read, :folder, context, [])

    assert message =~ "Mediate.Rbac failed during filter: invalid binding: nothing bound and no override"
    assert message =~ "call Mediate.Rbac.Binding.bind!/1 at boot"
  end

  test "an override in the calling process resolves without a boot binding" do
    assert {:error, %Error{reason: :invalid, message: "invalid binding: " <> _rest}} = Binding.resolve()
    :ok = Binding.override(policy: Reference, repo: Sandboxed)
    assert Binding.resolve() == {:ok, %Binding{policy: Reference, repo: Sandboxed}}
  end

  test "the boot binding resolves under the calling process's overrides" do
    assert {:ok, %Binding{} = bound} = Binding.bind(policy: Reference, repo: Sandboxed)
    assert Binding.resolve() == {:ok, bound}
    assert Binding.to_keyword(bound) == [policy: Reference, repo: Sandboxed]
    :ok = Binding.override(repo: Durable)
    assert Binding.resolve() == {:ok, %Binding{policy: Reference, repo: Durable}}
    assert Binding.bind!(policy: Reference, repo: Durable) == %Binding{policy: Reference, repo: Durable}
    assert_raise Error, fn -> Binding.bind!(policy: Durable, repo: Durable) end
    assert %NimbleOptions{} = Binding.options_schema()
  end

  test "the override is read through the callers chain, so a task sees its caller's binding" do
    :ok = Binding.override(policy: Reference, repo: Sandboxed)
    task = Task.async(fn -> Binding.resolve() end)
    assert Task.await(task) == {:ok, %Binding{policy: Reference, repo: Sandboxed}}
  end

  test "a caller that has exited contributes nothing" do
    {:ok, pid} = Task.start(fn -> :ok end)
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
    Process.put(:"$callers", [pid])
    assert {:error, %Error{reason: :invalid}} = Binding.resolve()
  after
    Process.delete(:"$callers")
  end

  test "an override around a function is undone after it" do
    :ok = Binding.override(policy: Reference, repo: Sandboxed)
    Binding.override([repo: Durable], fn -> assert {:ok, %Binding{repo: Durable}} = Binding.resolve() end)
    assert {:ok, %Binding{repo: Sandboxed}} = Binding.resolve()
  end

  test "a module that is not a policy module is invalid, and the message names it" do
    assert {:error, %Error{reason: :invalid, message: message}} = Binding.new(policy: Sandboxed, repo: Sandboxed)
    assert message =~ "invalid binding: Mediate.TestRepos.Sandboxed is not a policy module"
    assert message =~ "use Mediate.Rbac.Policy"
    assert {:error, %Error{reason: :invalid, message: message}} = Binding.new(repo: Sandboxed)
    assert message =~ "policy"
  end
end
