defmodule Example.Domain.Program do
  @moduledoc "A program of an office. Assignment to it is lawful purpose. When it closes, every assignment's purpose ends."

  use Ecto.Schema
  use Mediate.Schema

  alias Example.Domain.Office

  @type t :: %__MODULE__{}

  schema "programs" do
    field(:name, :string)
    field(:closed_at, :utc_datetime)
    belongs_to(:office, Office)
  end

  object_type(:program)
  audited(:entity)
  fact(:closed_at, kind: :object_attribute, object: :id)
end
