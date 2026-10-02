defmodule ExampleOpenFGA.Infrastructure.Guard do
  @moduledoc """
  The precondition the model does not carry: the visibility actions require
  a session that re-authenticated inside the window (C8). A session is a
  context fact about the call and not a relationship. So it belongs in a
  guard and not in a tuple condition (`Mediate.OpenFGA.Guard`).

  A condition on `admin` makes every use of the relation demand a session,
  the access review among them. The review asks what an admin can do, and
  not what this caller can do now. So the guard admits the actions C7
  names for a fresh session alone. It admits every other action and leaves
  it to the model.

  The window is the example's. `Example.Domain.Reauthentication` states
  how long a re-authentication lasts.
  """

  @behaviour Mediate.OpenFGA.Guard

  alias Example.Domain.Reauthentication

  @fresh_session_actions [:change_visibility, :set_embargo, :lift_embargo]

  @impl Mediate.OpenFGA.Guard
  def admits?(action, context) when action in @fresh_session_actions, do: Reauthentication.fresh?(context)
  def admits?(_action, _context), do: true
end
