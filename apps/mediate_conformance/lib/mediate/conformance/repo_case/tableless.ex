defmodule Mediate.Conformance.RepoCase.Tableless do
  @moduledoc """
  A protected schema with no table, for `Mediate.Conformance.RepoCase`:
  every refusal it drives happens before SQL, so the table is never
  touched. It covers nothing and belongs to itself through `parent`,
  which gives `preload` an association to ask for.
  """

  use Ecto.Schema
  use Mediate.Schema

  @typedoc "The schema struct. No refusal this drives reaches the table."
  @type t :: %__MODULE__{}

  schema "mediate_conformance_protected" do
    field(:name, :string)
    belongs_to(:parent, __MODULE__)
  end

  resource_type(:protected)
end
