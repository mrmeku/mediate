defmodule Example.Domain.Restrictions do
  @moduledoc """
  The restrictions and the visibility values, as the domain's own vocabulary:
  the four restriction kinds and the fields a visibility carries.

  EXPORT and REGIONS both sound geographic, and they are two tests. EXPORT
  denies every subject whose country is not the owning enterprise's. REGIONS
  asks for the subject's country in a list the visibility names. A visibility that
  carries both admits the subject that passes both.

  Every schema that holds a visibility reads its restriction values from here.
  `Example.Domain.Rollup` is where a set of visibilities adds up to a rollup (C4).
  """

  @restrictions [:employees_only, :export_controlled, :invite_only, :releasable_to]
  @fields [:labels, :restrictions, :releasable_to]

  @typedoc "One restriction: a test on the subject below the default of the access path."
  @type restriction :: :employees_only | :export_controlled | :invite_only | :releasable_to

  @typedoc "The visibility fields a directory carries and a repository's rollup combines."
  @type visibility :: %{labels: [String.t()], restrictions: [restriction()], releasable_to: [String.t()]}

  @doc "Every restriction kind, in the order the example states them."
  @spec all() :: [restriction()]
  def all, do: @restrictions

  @doc "The visibility fields."
  @spec fields() :: [atom()]
  def fields, do: @fields
end
