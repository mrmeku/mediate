defmodule Example.Domain.User do
  @moduledoc """
  An account. A person can hold two, an ordinary one and a privileged one.
  `person_id` joins them, and no permission does. Employment and nationality
  are the subject attributes the controls test.
  """

  use Ecto.Schema
  use Mediate.Schema

  @primary_key {:id, :string, autogenerate: false}

  @type t :: %__MODULE__{}

  schema "users" do
    field(:name, :string)
    field(:kind, Ecto.Enum, values: [:user, :privileged])
    field(:person_id, :string)
    field(:employment, Ecto.Enum, values: [:federal, :contractor])
    field(:nationality, :string)
  end

  audited(:user)
  fact(:employment, kind: :subject_attribute, subject: :id)
  fact(:nationality, kind: :subject_attribute, subject: :id)
end
