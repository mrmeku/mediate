defmodule Example.Domain.Label do
  @moduledoc "A label a visibility names. A sensitive label implies restrictions, read at every check and never copied."

  use Ecto.Schema
  use Mediate.Schema

  alias Example.Domain.Restrictions

  @primary_key {:name, :string, autogenerate: false}

  @type t :: %__MODULE__{}

  schema "labels" do
    field(:sensitive, :boolean, default: false)
    field(:implied_restrictions, {:array, Ecto.Enum}, values: Restrictions.all(), default: [])
  end

  object_type(:label)
  audited(:entity)
  fact(:sensitive, kind: :object_attribute, object: :name)
  fact(:implied_restrictions, kind: :object_attribute, object: :name, element: :restriction)
end
