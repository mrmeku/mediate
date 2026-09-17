defmodule Example.Domain.AccountRole do
  @moduledoc """
  A role an account holds outside any project or team. `override` is the
  permission the audited override needs. A privileged account holds it, and
  an ordinary one never does. The role is a subject attribute, so the table
  declares no object type. Role administration writes it under a declared
  exemption.
  """

  use Ecto.Schema
  use Mediate.Schema

  @type t :: %__MODULE__{}

  schema "account_roles" do
    field(:user_id, :string)
    field(:role, Ecto.Enum, values: [:override])
  end

  audited(:role)
  fact(:role, kind: :subject_attribute, subject: :user_id)
end
