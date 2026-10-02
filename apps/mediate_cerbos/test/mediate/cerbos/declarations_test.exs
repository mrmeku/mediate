defmodule Mediate.Cerbos.DeclarationsTest do
  use ExUnit.Case, async: true

  alias Mediate.Cerbos.Attribute
  alias Mediate.Cerbos.Conformance.Memberships
  alias Mediate.Cerbos.Declarations
  alias Mediate.Error
  alias Mediate.Fixture.Account
  alias Mediate.Fixture.Folder

  defmodule Declared do
    @moduledoc false
    use Declarations

    principal :user, schema: Account do
      attribute :clearance, column: :clearance
    end

    resource :folder, schema: Folder do
      attribute :name, column: :name
      attribute :member_roles, subquery: &Memberships.folder_roles/2
    end

    resource :user, schema: Account do
      attribute :clearance, column: :clearance
    end

    context do
      fact(:reauthenticated_at)
    end
  end

  test "the declarations name the blocks, the side each is on, and the schema behind it" do
    assert Declarations.blocks(Declared) == [
             {:principal, :user, Account},
             {:resource, :folder, Folder},
             {:resource, :user, Account}
           ]

    assert Declarations.principals(Declared) == [:user]
    assert Declarations.resources(Declared) == [:folder, :user]
    assert Declarations.names?(Declared, {:principal, :user})
    assert Declarations.names?(Declared, {:resource, :folder})
    refute Declarations.names?(Declared, {:principal, :folder})
    refute Declarations.names?(Declared, {:resource, :nothing})
    assert Declarations.schema_of(Declared, {:resource, :folder}) == Folder
    assert Declarations.schema_of(Declared, {:principal, :folder}) == nil
  end

  test "the attributes of a block come back in the order they were written" do
    assert [%Attribute{name: :clearance, source: {:column, :clearance}}] =
             Declarations.attributes_of(Declared, {:principal, :user})

    assert [%Attribute{name: :name}, %Attribute{name: :member_roles}] =
             Declarations.attributes_of(Declared, {:resource, :folder})

    assert Declarations.attributes_of(Declared, {:resource, :nothing}) == []

    assert Enum.map(Declarations.attributes(Declared), &elem(&1, 0)) == [
             {:principal, :user},
             {:resource, :folder},
             {:resource, :folder},
             {:resource, :user}
           ]
  end

  test "the context facts the declarations name come back in the order they were written" do
    assert Declarations.facts(Declared) == [:reauthenticated_at]
  end

  test "the name the context facts travel under is not a name a declaration may take" do
    assert Attribute.reserved_name() == :context

    assert {:error, %Error{reason: :invalid, message: "invalid attribute: " <> message}} =
             Attribute.new(:context, column: :context)

    assert message == "attribute context is the name the context facts travel under"
  end

  test "a context block declares a fact and refuses anything else" do
    declaration =
      quote do
        defmodule Nothing do
          @moduledoc false
          use Mediate.Cerbos.Declarations

          context do
            reauthenticated_at()
          end
        end
      end

    assert_raise ArgumentError, ~r/declares a fact with `fact :name`/, fn -> Code.eval_quoted(declaration) end
  end

  test "one attribute is found by its block and its name" do
    assert %Attribute{source: {:subquery, fun}} = Declarations.find(Declared, {:resource, :folder}, :member_roles)
    assert fun == (&Memberships.folder_roles/2)
    assert Declarations.find(Declared, {:resource, :folder}, :nothing) == nil
  end

  test "a module that did not use the declarations does not declare" do
    assert Declarations.declares?(Declared)
    refute Declarations.declares?(Folder)
    refute Declarations.declares?(Mediate.Cerbos.DeclarationsTest.NotAModuleAtAll)
    assert Declarations.block_options_schema().schema[:schema][:required]
  end

  test "an attribute names a column or a subquery, and neither or both is an error" do
    assert {:ok, %Attribute{source: {:column, :clearance}} = column} = Attribute.new(:clearance, column: :clearance)
    assert Attribute.column?(column)

    assert {:ok, %Attribute{} = subquery} = Attribute.new(:roles, subquery: &Memberships.folder_roles/2)
    refute Attribute.column?(subquery)

    assert {:error, %Error{reason: :invalid, message: "invalid attribute: " <> neither}} = Attribute.new(:nothing, [])
    assert neither == "attribute nothing names neither a column nor a subquery"

    both = [column: :clearance, subquery: &Memberships.folder_roles/2]
    assert {:error, %Error{reason: :invalid, message: "invalid attribute: " <> message}} = Attribute.new(:both, both)
    assert message == "attribute both names both a column and a subquery"
  end

  test "an option the schema does not accept is an error naming the attribute" do
    assert {:error, %Error{reason: :invalid, message: "invalid attribute: " <> _rest} = error} =
             Attribute.new(:clearance, column: "clearance")

    assert error.message =~ "attribute clearance invalid value for :column option"
    assert Attribute.options_schema().schema[:column][:type] == :atom

    assert_raise Error, fn -> Attribute.new!(:clearance, column: "clearance") end
    assert %Attribute{} = Attribute.new!(:clearance, column: :clearance)
  end
end
