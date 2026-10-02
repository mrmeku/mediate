defmodule Example.Domain.Permission do
  @moduledoc """
  A permission an account holds outside any project or team. `override`
  is the one the audited override needs. A privileged account holds it,
  and an ordinary one never does. The permission is a subject fact, so the
  schema declares no resource type. Membership administration writes it
  under a declared exemption.
  """

  use Ecto.Schema
  use Mediate.Schema

  @type t :: %__MODULE__{}

  schema "permissions" do
    field(:account_id, :string)
    field(:permission, Ecto.Enum, values: [:override])
  end

  identity(:role)
  fact(:permission, about: :subject, subject: :account_id)
end
