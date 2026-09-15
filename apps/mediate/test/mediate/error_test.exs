defmodule Mediate.ErrorTest do
  use ExUnit.Case, async: true

  alias Mediate.Error

  test "the one error carries a reason and a detail, and the detail is the message" do
    error = %Error{reason: :unsupported, detail: "Mediate.Test.Fake does not support scope"}
    assert Exception.message(error) == "Mediate.Test.Fake does not support scope"
    refute :allowed in Error.reasons()
    assert :unsupported in Error.reasons()
    assert :rule_denied in Error.reasons()
  end

  test "invalid and denied name what was wrong" do
    assert Exception.message(Error.invalid(:config, "x")) == "invalid config: x"

    subject = {:user, Mediate.Id.new()}
    assert Exception.message(Error.denied(subject, :read, {:thing, "1"}, :deny_by_default)) =~ "may not read"

    assert Exception.message(Error.denied(subject, :read, {:thing, "1"}, :engine_unreachable, "down")) =~
             "engine_unreachable (down)"
  end
end
