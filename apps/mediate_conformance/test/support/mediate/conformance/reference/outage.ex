defmodule Mediate.Conformance.Reference.Outage do
  @moduledoc """
  The fake engine's outage. `disconnect/0` makes every call to the fake
  fail for the rest of the test. It finds the rule table the way the
  mirror does.
  """

  @behaviour Mediate.Conformance.Outage

  alias Mediate.Conformance.Outage
  alias Mediate.Conformance.Reference.Mirror
  alias Mediate.Test.Fake

  @impl Outage
  def disconnect, do: Fake.fail(Mirror.rules!(), "the fake's engine is down")
end
