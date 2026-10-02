defmodule Example.Domain.Enterprise do
  @moduledoc "The tenant. Its country is what EXPORT compares a subject's country with."

  use Ecto.Schema
  use Mediate.Schema

  @type t :: %__MODULE__{}

  schema "enterprises" do
    field(:name, :string)
    field(:country, :string)
  end

  resource_type(:enterprise)
  identity(:other)
  fact(:country, about: :resource, resource: :id)
end
