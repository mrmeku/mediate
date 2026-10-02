defmodule Example.Domain.Label do
  @moduledoc "A label a visibility names. A sensitive label implies restrictions, read at every decision and never copied."

  use Ecto.Schema
  use Mediate.Schema

  alias Example.Domain.Restrictions

  @primary_key {:name, :string, autogenerate: false}

  @type t :: %__MODULE__{}

  schema "labels" do
    field(:sensitive, :boolean, default: false)
    field(:implied_restrictions, {:array, Ecto.Enum}, values: Restrictions.kinds(), default: [])
  end

  resource_type(:label)
  identity(:other)
  fact(:sensitive, about: :resource, resource: :name)
  fact(:implied_restrictions, about: :resource, resource: :name, element: :restriction)
end
