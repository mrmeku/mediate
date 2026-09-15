defmodule ExampleFga.Infrastructure.Guard do
  @moduledoc """
  The precondition the model does not carry: the marking operations require
  a session that re-authenticated inside the window (C8). A session is a
  fact about the call and not about a relationship. So it belongs in a guard
  and not in a tuple condition (`Mediate.Fga.Guard`).

  A condition on `designator` makes every use of the relation demand a
  session, the access review among them. The review asks what a designator
  can do, and not what this caller can do now. So the guard admits the
  operations C7 names for a fresh session alone. It admits every other
  operation and leaves it to the model.

  The window is the example's. `Example.Domain.Sessions` states how long a
  re-authentication lasts.
  """

  @behaviour Mediate.Fga.Guard

  alias Example.Domain.Sessions

  @gated [:change_marking, :set_decontrol, :decontrol]

  @impl Mediate.Fga.Guard
  def admits?(operation, environment) when operation in @gated, do: Sessions.fresh?(environment)
  def admits?(_operation, _environment), do: true
end
