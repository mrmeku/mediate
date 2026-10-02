defmodule Mediate.Rbac.FactsTest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [dynamic: 2, from: 2, subquery: 1]

  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Membership
  alias Mediate.Rbac.Conformance.Reference
  alias Mediate.Rbac.Facts
  alias Mediate.Rbac.Policy

  defmodule Reads do
    @moduledoc false
    @spec name(Mediate.subject(), Mediate.context()) :: Ecto.Query.dynamic_expr()
    def name(_subject, _context), do: dynamic([row], row.name == "public")

    @spec joined(Mediate.subject(), Mediate.context()) :: Ecto.Query.dynamic_expr()
    def joined({_kind, id}, _context) do
      dynamic([row], row.id in subquery(from(m in Membership, where: m.account_id == ^id, select: m.folder_id)))
    end

    @spec raw(Mediate.subject(), Mediate.context()) :: Ecto.Query.dynamic_expr()
    def raw(_subject, _context), do: dynamic([row], fragment("? = 'public'", row.name))

    @spec mapped(Mediate.subject(), Mediate.context()) :: Ecto.Query.dynamic_expr()
    def mapped({_kind, id}, _context) do
      members = from(m in Membership, where: m.account_id == ^id, select: %{folder: m.folder_id})
      dynamic([_row], exists(from(s in subquery(members), select: s.folder)))
    end

    @spec parent(Mediate.subject(), Mediate.context()) :: Ecto.Query.dynamic_expr()
    def parent(_subject, _context), do: dynamic([row], not is_nil(row.folder_id))

    @spec grandparent(Mediate.subject(), Mediate.context()) :: Ecto.Query.dynamic_expr()
    def grandparent(_subject, _context) do
      notes = from(n in Mediate.Rbac.FactsTest.Note, where: not is_nil(n.folder_id), select: n.id)
      dynamic([row], row.note_id in subquery(notes))
    end
  end

  defmodule Note do
    @moduledoc false
    use Ecto.Schema
    use Mediate.Schema

    resource_type(:note)
    covers([:folder])

    schema "mediate_facts_test_notes" do
      belongs_to(:folder, Folder)
    end
  end

  defmodule NamePolicy do
    @moduledoc false
    use Policy

    role :reader, [:read]

    resource Folder do
      grant :membership, Membership, role_column: :role
      predicate :named, &Reads.name/2
    end
  end

  defmodule SubqueryPolicy do
    @moduledoc false
    use Policy

    role :reader, [:read]

    resource Folder do
      grant :membership, Membership, role_column: :role
      predicate :joined, &Reads.joined/2
    end
  end

  defmodule MappedPolicy do
    @moduledoc false
    use Policy

    role :reader, [:read]

    resource Folder do
      grant :membership, Membership, role_column: :role
      predicate :mapped, &Reads.mapped/2
    end
  end

  defmodule Remark do
    @moduledoc false
    use Ecto.Schema
    use Mediate.Schema

    resource_type(:remark)
    covers([:note])

    schema "mediate_facts_test_remarks" do
      belongs_to(:note, Note)
    end
  end

  defmodule ClosurePolicy do
    @moduledoc false
    use Policy

    role :reader, [:read]

    resource Remark do
      predicate :grandparent, &Reads.grandparent/2
    end
  end

  defmodule CoveredPolicy do
    @moduledoc false
    use Policy

    role :reader, [:read]

    resource Note do
      predicate :parent, &Reads.parent/2
    end
  end

  defmodule FragmentPolicy do
    @moduledoc false
    use Policy

    role :reader, [:read]

    resource Folder do
      predicate :raw, &Reads.raw/2
    end
  end

  test "every column the conformance rules read is a declared fact" do
    assert Facts.check(Reference) == :ok
    assert Facts.check!(Reference) == :ok
  end

  test "a finding names the undeclared column and its schema" do
    assert Facts.check(NamePolicy) == {:error, [{Folder, :name}]}

    assert_raise ArgumentError, ~r/NamePolicy reads undeclared columns: name of Mediate.Fixture.Folder/, fn ->
      Facts.check!(NamePolicy)
    end
  end

  test "the walk follows subqueries, where every column the world reads is declared" do
    assert Facts.check(SubqueryPolicy) == :ok
    reads = Facts.reads(SubqueryPolicy)
    assert {Membership, :account_id} in reads
    assert {Membership, :folder_id} in reads
  end

  test "a fragment cannot be walked, so it is a finding" do
    assert Facts.check(FragmentPolicy) == {:error, [{:fragment, "? = 'public'"}]}
    assert_raise ArgumentError, ~r/fragment "\? = 'public'"/, fn -> Facts.check!(FragmentPolicy) end
  end

  test "a field of a subquery source counts as declared, since the subquery's reads are walked" do
    assert Facts.check(MappedPolicy) == :ok
    assert {Membership, :folder_id} in Facts.reads(MappedPolicy)
  end

  test "the foreign key of a covered belongs_to is declared on the schema that holds it" do
    assert Facts.check(CoveredPolicy) == :ok
  end

  test "the closure of covered relations counts: a covered schema's own covered key is declared" do
    assert Facts.check(ClosurePolicy) == :ok
    assert {Note, :folder_id} in Facts.reads(ClosurePolicy)
  end
end
