defmodule Mediate.Rbac.Conformance.Assignment do
  @moduledoc """
  A relationship that declares two attributes. A grant over a relationship
  with one attribute needs no `role:`. A grant over a wider relationship
  must name its role column, and this schema is the test case for that
  rule.
  """

  use Ecto.Schema
  use Mediate.Schema

  alias Mediate.Fixture.Folder

  @type t :: %__MODULE__{}

  schema "mediate_code_assignments" do
    field(:account_id, :string)
    field(:role, Ecto.Enum, values: [:reader, :editor])
    field(:scope, :string)
    belongs_to(:folder, Folder)
  end

  audited(:role)
  relationship(subject: :account_id, object: :folder_id, attributes: [:role, :scope])
end
