defmodule Mediate.Rbac.Conformance.Assignment do
  @moduledoc """
  A grant schema that declares two attributes. A grant rule over a grant
  with one attribute needs no `role_column:`. A grant rule over a wider
  grant must name its role column, and this schema is the test case for
  that rule.
  """

  use Ecto.Schema
  use Mediate.Schema

  alias Mediate.Fixture.Folder

  @type t :: %__MODULE__{}

  schema "mediate_rbac_assignments" do
    field(:account_id, :string)
    field(:role, Ecto.Enum, values: [:reader, :editor])
    field(:scope, :string)
    belongs_to(:folder, Folder)
  end

  identity(:role)
  grant(subject: :account_id, resource: :folder_id, attributes: [:role, :scope])
end
