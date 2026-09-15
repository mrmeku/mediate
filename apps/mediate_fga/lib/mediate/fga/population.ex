defmodule Mediate.Fga.Population do
  @moduledoc """
  What `Mediate.Fga.TupleMappingCase` and `Mediate.Fga.OutboxCase` write
  and take away: the one thing a template cannot know. Which rows a mapping
  states tuples about is the application's.

  `write/1` and `clear/1` go through the seam, a row at a time. What the
  templates hold is the change each row publishes and what a drain then
  does with it. A population large enough to page a read is worth the
  rows, since one page proves less than the template claims.
  """

  @doc "Writes rows the mapping states tuples about, through the seam, from empty tables."
  @callback write(repo :: module()) :: :ok

  @doc "Takes every row `write/1` wrote away again, through the seam."
  @callback clear(repo :: module()) :: :ok

  @doc "An object of this type that no row names."
  @callback absent(type :: String.t()) :: String.t()

  @doc """
  Changes one row the mapping states a tuple about, and leaves the object
  that tuple belongs to in the tables. What a drain can put right is what
  the tables still name. So a disturbance that takes the object away as
  well is a rebuild's to answer and not a drain's.
  """
  @callback disturb(repo :: module()) :: :ok
end
