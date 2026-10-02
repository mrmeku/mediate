defmodule Mediate.ErrorTest do
  use ExUnit.Case, async: true

  alias Mediate.Error

  test "the one error carries a reason and a message, and the message is what it prints" do
    error = %Error{reason: :unsupported, message: "Mediate.Test.Fake does not support filter"}
    assert Exception.message(error) == "Mediate.Test.Fake does not support filter"
    refute :rule_allowed in Error.reasons()
    assert :unsupported in Error.reasons()
    assert :rule_denied in Error.reasons()
    assert :decision_missing in Error.reasons()
  end

  test "invalid and denied name what was wrong" do
    assert Exception.message(Error.invalid(:config, "x")) == "invalid config: x"

    subject = {:user, Mediate.Id.new()}
    assert Exception.message(Error.denied(subject, :read, {:thing, "1"}, :no_rule_matched)) =~ "may not read"

    assert Exception.message(Error.denied(subject, :read, {:thing, "1"}, :engine_failed, "down")) =~
             "engine_failed (down)"
  end
end
