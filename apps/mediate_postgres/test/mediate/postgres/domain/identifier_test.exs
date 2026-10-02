defmodule Mediate.Postgres.Domain.IdentifierTest do
  use ExUnit.Case, async: true

  alias Mediate.Error
  alias Mediate.Postgres.Domain.Identifier

  test "a lowercase identifier passes, as an atom or as text" do
    assert Identifier.check!("mediate_fixture_folders", :table) == "mediate_fixture_folders"
    assert Identifier.check!(:read, :action) == "read"
    assert Identifier.check!("a1_2", :table) == "a1_2"
  end

  test "anything that would need quoting is refused, and the error names what kind of name it was" do
    for refused <- ["Folders", "folders; drop table x", "folder-1", "1folder", "", "folders\"x"] do
      assert_raise Error, fn -> Identifier.check!(refused, :table) end
    end

    assert %Error{reason: :invalid, message: message} = catch_error(Identifier.check!("A", :policy))
    assert message == "invalid policy: \"A\" is not a lowercase identifier of at most 63 bytes"
  end

  test "a name longer than the identifier limit is refused" do
    assert_raise Error, fn -> Identifier.check!(String.duplicate("a", 64), :table) end
    assert Identifier.check!(String.duplicate("a", 63), :table) == String.duplicate("a", 63)
  end
end
