defmodule Mediate.Fixture.Account do
  @moduledoc "An unprotected identity schema with one fact column about the subject."

  use Ecto.Schema
  use Mediate.Schema

  @primary_key {:id, :string, autogenerate: false}

  @type t :: %__MODULE__{}

  schema "mediate_fixture_accounts" do
    field(:clearance, :string)
  end

  identity(:account)
  fact(:clearance, about: :subject, subject: :id)
end
