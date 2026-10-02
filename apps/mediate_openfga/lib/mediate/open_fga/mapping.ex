defmodule Mediate.OpenFGA.Mapping do
  @moduledoc """
  What a deployment states about its tables, in the terms the store
  keeps:

  - which object types it writes
  - which objects of a type there are
  - which objects one identity write can have affected
  - which tuples an object requires

  The mapping reads every answer from the tables through the repo it
  gets. A tuple can rest on several rows at once. So the mapping reads
  what an object requires from the rows as they stand, and computes
  nothing from the write that arrived. A marker says which object to look
  at, and the rows say what it needs.

  `tuples/2` is total. For an object whose rows are there it answers
  every tuple that object requires. For an object whose rows are gone it
  answers none. That is what makes a pass a difference and not a
  translation of writes into tuples. It is what makes a marker that
  arrives twice cost a read and no write. It is what lets a deletion be a
  pass of the same kind as a creation.

  `affected/2` can name more objects than a write strictly affects. A pass
  over an object that needed nothing writes nothing. So an answer that is
  too wide costs a read. An answer that is too narrow leaves the store
  behind the tables until a reconcile reports it.
  """

  alias Mediate.OpenFGA.TupleKey

  @typedoc "An object as the store names it: the type and the id joined by a colon."
  @type object :: String.t()

  @doc "Every object type this mapping writes tuples for, which is what a reconcile reads by."
  @callback object_types() :: [String.t()]

  @doc "Every object of one type the tables hold, which a rebuild and `Mediate.OpenFGA.mark_all/0` read."
  @callback objects(repo :: module(), type :: String.t()) :: [object()]

  @doc "The objects whose required tuples this identity write can have affected."
  @callback affected(repo :: module(), write :: map()) :: [object()]

  @doc "Every tuple the object requires in the state the tables hold."
  @callback tuples(repo :: module(), object()) :: [TupleKey.t()]
end
