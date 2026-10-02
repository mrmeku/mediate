defmodule Mediate.Cerbos.BindingTest do
  use ExUnit.Case, async: false

  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Conformance.Reference
  alias Mediate.Error
  alias Mediate.Fixture.Folder
  alias Mediate.TestRepos.Sandboxed

  defmodule Pair do
    @moduledoc false
    use Ecto.Schema

    @primary_key false

    @type t :: %__MODULE__{}

    schema "mediate_cerbos_binding_test_pairs" do
      field(:left, :string, primary_key: true)
      field(:right, :string, primary_key: true)
    end
  end

  defmodule Composite do
    @moduledoc false
    use Mediate.Cerbos.Declarations

    resource :pair, schema: Pair do
      attribute :left, column: :left
    end
  end

  @options [repo: Sandboxed, declarations: Reference, policy_dir: "priv/conformance", commit: "conformance"]

  setup do
    :persistent_term.erase(Binding)
    Process.put(Binding, [])
    on_exit(fn -> :persistent_term.erase(Binding) end)
  end

  test "the binding is the repo, the declarations, the policy directory, and the commit" do
    assert {:ok, %Binding{} = binding} = Binding.new(@options)
    assert binding.repo == Sandboxed
    assert binding.declarations == Reference
    assert binding.policy_dir == "priv/conformance"
    assert binding.commit == "conformance"
    assert binding.author == nil
    assert binding.approval == nil

    assert Binding.to_keyword(binding) == [
             repo: Sandboxed,
             declarations: Reference,
             policy_dir: "priv/conformance",
             commit: "conformance",
             author: nil,
             approval: nil
           ]
  end

  test "options the schema does not accept are an invalid binding" do
    assert {:error, %Error{reason: :invalid, message: "invalid binding: " <> _rest} = error} =
             Binding.new(Keyword.delete(@options, :commit))

    assert error.message =~ "required :commit option not found"
    assert Binding.options_schema().schema[:repo][:required]
  end

  test "a module that did not use the declarations is an invalid binding" do
    assert {:error, %Error{reason: :invalid, message: "invalid binding: " <> message}} =
             Binding.new(put_in(@options[:declarations], Folder))

    assert message ==
             "Mediate.Fixture.Folder did not use Mediate.Cerbos.Declarations; " <>
               "add use Mediate.Cerbos.Declarations or bind the module that does"
  end

  test "a block whose schema has no single primary key is an invalid binding" do
    assert {:error, %Error{reason: :invalid, message: "invalid binding: " <> message}} =
             Binding.new(put_in(@options[:declarations], Composite))

    assert message ==
             "Mediate.Cerbos.BindingTest.Composite declares resource :pair on Mediate.Cerbos.BindingTest.Pair, " <>
               "whose primary key is not one column; Mediate.Cerbos names a row by one key column"
  end

  test "what is bound at boot is what resolve answers, under the calling process's override" do
    assert %Binding{commit: "conformance"} = Binding.bind!(@options)
    assert {:ok, %Binding{commit: "conformance", author: nil}} = Binding.resolve()

    :ok = Binding.override(commit: "later", author: "someone")
    assert {:ok, %Binding{commit: "later", author: "someone", repo: Sandboxed}} = Binding.resolve()
  end

  test "an override around a function is put back after it" do
    _bound = Binding.bind!(@options)

    assert Binding.override([commit: "inside"], fn ->
             {:ok, binding} = Binding.resolve()
             binding.commit
           end) == "inside"

    assert {:ok, %Binding{commit: "conformance"}} = Binding.resolve()
  end

  test "an override is read from the chain of callers, nearest first" do
    :ok = Binding.override(@options)
    task = Task.async(fn -> Binding.resolve() end)

    assert {:ok, %Binding{commit: "conformance"}} = Task.await(task)
  end

  test "nothing bound and no override is an invalid binding" do
    assert Binding.resolve() ==
             {:error,
              %Error{
                reason: :invalid,
                message: "invalid binding: nothing bound and no override; call Mediate.Cerbos.Binding.bind!/1 at boot"
              }}
  end

  test "the schema and the key of a block, and nil for a block no declaration names" do
    {:ok, binding} = Binding.new(@options)

    assert Binding.schema_and_key(binding, {:resource, :folder}) == {Folder, :id}
    assert Binding.schema_and_key(binding, {:principal, :user}) == {Mediate.Fixture.Account, :id}
    assert Binding.schema_and_key(binding, {:resource, :user}) == nil
    assert Binding.schema_and_key(binding, {:resource, :nothing}) == nil
  end

  test "a binding that cannot be validated cannot be bound" do
    assert {:error, %Error{reason: :invalid}} = Binding.bind(Keyword.delete(@options, :repo))
    assert_raise Error, fn -> Binding.bind!(Keyword.delete(@options, :repo)) end
  end
end
