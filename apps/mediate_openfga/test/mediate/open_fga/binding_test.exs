defmodule Mediate.OpenFGA.BindingTest.Guarded do
  @moduledoc false
  @behaviour Mediate.OpenFGA.Guard

  @impl Mediate.OpenFGA.Guard
  def admits?(_action, _context), do: true
end

defmodule Mediate.OpenFGA.BindingTest do
  use ExUnit.Case, async: false

  alias Mediate.Error
  alias Mediate.Fixture.Folder
  alias Mediate.OpenFGA.Binding
  alias Mediate.OpenFGA.BindingTest.Guarded
  alias Mediate.OpenFGA.Conformance.Reference
  alias Mediate.TestRepos.Sandboxed

  @options [repo: Sandboxed, model_file: "priv/conformance/model.fga", mapping: Reference]

  setup do
    :persistent_term.erase(Binding)
    Process.put(Binding, [])
    on_exit(fn -> :persistent_term.erase(Binding) end)
  end

  test "the binding is the repo, the model file, the mapping, the guard, and who stands behind it" do
    assert {:ok, %Binding{} = binding} = Binding.new(@options)
    assert binding.repo == Sandboxed
    assert binding.model_file == "priv/conformance/model.fga"
    assert binding.mapping == Reference
    assert binding.guard == nil
    assert binding.author == nil
    assert binding.approval == nil

    assert Binding.to_keyword(binding) == [
             repo: Sandboxed,
             model_file: "priv/conformance/model.fga",
             mapping: Reference,
             guard: nil,
             author: nil,
             approval: nil
           ]

    assert {:ok, %Binding{guard: Guarded}} = Binding.new(put_in(@options[:guard], Guarded))
  end

  test "options the schema does not accept are an invalid binding" do
    assert {:error, %Error{reason: :invalid, message: "invalid binding: " <> _rest} = error} =
             Binding.new(Keyword.delete(@options, :model_file))

    assert error.message =~ "required :model_file option not found"
    assert Binding.options_schema().schema[:repo][:required]
  end

  test "a module that is no mapping is an invalid binding" do
    assert {:error, %Error{reason: :invalid, message: "invalid binding: " <> message}} =
             Binding.new(put_in(@options[:mapping], Folder))

    assert message == "#{inspect(Folder)} is no Mediate.OpenFGA.Mapping"
  end

  test "a module that is no guard is an invalid binding" do
    assert {:error, %Error{reason: :invalid, message: "invalid binding: " <> message}} =
             Binding.new(put_in(@options[:guard], Folder))

    assert message == "#{inspect(Folder)} is no Mediate.OpenFGA.Guard"
  end

  test "what is bound at boot is what resolve answers, under the calling process's override" do
    assert %Binding{mapping: Reference} = Binding.bind!(@options)
    assert {:ok, %Binding{mapping: Reference, author: nil}} = Binding.resolve()

    :ok = Binding.override(model_file: "priv/conformance/other.fga", author: "someone")

    assert {:ok, %Binding{model_file: "priv/conformance/other.fga", author: "someone", repo: Sandboxed}} =
             Binding.resolve()
  end

  test "an override around a function is put back after it" do
    _bound = Binding.bind!(@options)

    assert Binding.override([author: "inside"], fn ->
             {:ok, binding} = Binding.resolve()
             binding.author
           end) == "inside"

    assert {:ok, %Binding{author: nil}} = Binding.resolve()
  end

  test "an override is read from the chain of callers, nearest first" do
    :ok = Binding.override(@options)
    task = Task.async(fn -> Binding.resolve() end)

    assert {:ok, %Binding{mapping: Reference}} = Task.await(task)
  end

  test "nothing bound and no override is an invalid binding" do
    assert Binding.resolve() ==
             {:error, %Error{reason: :invalid, message: "invalid binding: nothing bound and no override"}}
  end

  test "a binding that cannot be validated cannot be bound" do
    assert {:error, %Error{reason: :invalid}} = Binding.bind(Keyword.delete(@options, :repo))
    assert_raise Error, fn -> Binding.bind!(Keyword.delete(@options, :repo)) end
  end
end
