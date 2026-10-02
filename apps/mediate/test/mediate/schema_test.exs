defmodule Mediate.SchemaTest do
  use ExUnit.Case, async: true

  alias Mediate.Schema.Fact
  alias Mediate.Schema.Grant

  defmodule Declared do
    @moduledoc false
    use Mediate.Schema

    resource_type(:thing)
    covers([:parts, :notes])
    identity(:other)
    fact(:owner_id, about: :subject, subject: :owner_id)
    fact(:labels, about: :resource, resource: :id, element: :label)
    grant(subject: :user_id, resource: :thing_id, attributes: [:role])
  end

  defmodule Empty do
    @moduledoc false
    use Mediate.Schema
  end

  test "a schema records its declarations in order" do
    assert Declared.__mediate__(:resource_type) == :thing
    assert Declared.__mediate__(:covers) == [:parts, :notes]
    assert Declared.__mediate__(:identity) == :other

    assert Declared.__mediate__(:facts) == [
             %Fact{column: :owner_id, about: :subject, subject: :owner_id, resource: nil, element: nil},
             %Fact{column: :labels, about: :resource, subject: nil, resource: :id, element: :label}
           ]

    assert Declared.__mediate__(:grant) == %Grant{subject: :user_id, resource: :thing_id, attributes: [:role]}
  end

  test "a schema without declarations answers nil and empty" do
    assert Empty.__mediate__(:resource_type) == nil
    assert Empty.__mediate__(:covers) == []
    assert Empty.__mediate__(:identity) == nil
    assert Empty.__mediate__(:facts) == []
    assert Empty.__mediate__(:grant) == nil
  end

  test "a schema is an identity schema when it declares what kind of identity its rows are" do
    assert Mediate.Schema.identity_of(Declared) == :other
    assert Mediate.Schema.identity?(Declared)
    refute Mediate.Schema.identity?(Empty)
    assert Mediate.Schema.identity_of(Empty) == nil
  end

  test "the readers answer the declarations and the fact columns each once" do
    assert Mediate.Schema.resource_type_of(Declared) == :thing
    assert Mediate.Schema.covers_of(Declared) == [:parts, :notes]
    assert Mediate.Schema.fact_columns(Declared) == [:owner_id, :labels, :user_id, :thing_id, :role]
    assert Mediate.Schema.fact_schema?(Declared)
    refute Mediate.Schema.fact_schema?(Empty)
    assert Mediate.Schema.resource_type_of(Enum) == nil
    assert Mediate.Schema.covers_of(nil) == []
  end

  test "an identity kind the write event does not carry is refused, and a second one raises" do
    assert_raise ArgumentError, ~r/identity expects one of/, fn ->
      defmodule BadIdentity do
        @moduledoc false
        use Mediate.Schema

        identity(:machine)
      end
    end

    assert_raise ArgumentError, ~r/already declares identity :account/, fn ->
      defmodule TwiceIdentity do
        @moduledoc false
        use Mediate.Schema

        identity(:account)
        identity(:role)
      end
    end
  end

  test "a second resource_type, covers, or grant raises" do
    assert_raise ArgumentError, ~r/already declares resource_type/, fn ->
      defmodule TwoTypes do
        @moduledoc false
        use Mediate.Schema

        resource_type(:a)
        resource_type(:b)
      end
    end

    assert_raise ArgumentError, ~r/already covers \[:a\]/, fn ->
      defmodule TwoCovers do
        @moduledoc false
        use Mediate.Schema

        covers([:a])
        covers([:b, :a])
      end
    end

    assert_raise ArgumentError, ~r/already declares a grant/, fn ->
      defmodule TwoGrants do
        @moduledoc false
        use Mediate.Schema

        grant(subject: :a, resource: :b)
        grant(subject: :c, resource: :d)
      end
    end
  end

  test "a fact about an unknown party or a grant without a resource is refused" do
    assert_raise NimbleOptions.ValidationError, fn ->
      defmodule BadAbout do
        @moduledoc false
        use Mediate.Schema

        fact(:x, about: :other)
      end
    end

    assert_raise NimbleOptions.ValidationError, fn ->
      defmodule BadGrant do
        @moduledoc false
        use Mediate.Schema

        grant(subject: :a)
      end
    end
  end
end
