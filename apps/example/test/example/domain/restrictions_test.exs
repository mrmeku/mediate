defmodule Example.Domain.RestrictionsTest do
  use ExUnit.Case, async: true

  alias Example.Domain.Restrictions

  test "the restrictions and the fields are the committed lists" do
    assert Restrictions.all() == [:employees_only, :export_controlled, :invite_only, :releasable_to]
    assert Restrictions.fields() == [:labels, :restrictions, :releasable_to]
  end
end
