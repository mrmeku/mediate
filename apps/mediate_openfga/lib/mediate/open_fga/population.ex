defmodule Mediate.OpenFGA.Population do
  @moduledoc """
  What `Mediate.OpenFGA.MappingCase` and `Mediate.OpenFGA.OutboxCase`
  write and clear: the one thing a case template cannot know. Which rows
  a mapping states tuples about is the deployment's.

  `write/1` and `clear/1` go through the mediated repo, a row at a time.
  What the templates hold is the identity write each row publishes and
  what a sync then does with it. A population large enough to page a
  read is worth the rows, since one page proves less than the template
  claims.
  """

  @doc "Writes rows the mapping states tuples about, through the mediated repo, from empty tables."
  @callback write(repo :: module()) :: :ok

  @doc "Takes every row `write/1` wrote away again, through the mediated repo."
  @callback clear(repo :: module()) :: :ok

  @doc "An object of this type that no row names."
  @callback absent(type :: String.t()) :: String.t()

  @doc """
  Changes one row the mapping states a tuple about, and leaves the object
  that tuple belongs to in the tables. What a sync can put right is what
  the tables still name. So a change that takes the object away as well
  is a rebuild's to answer and not a sync's.
  """
  @callback change(repo :: module()) :: :ok
end
