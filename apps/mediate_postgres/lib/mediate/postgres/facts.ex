defmodule Mediate.Postgres.Facts do
  @moduledoc """
  The fact check for row-level security: every column the rules read is a
  declared fact. `check/1` reads the rules' expressions from `pg_policy`
  and the columns they reference from `pg_depend`, which records one
  dependency per column an expression names. Then it asks the bound
  schemas whether each of those columns has a declaration. The
  conformance document under "The engine requirements" names this check
  `au12-07`. A column counts as declared in one of these cases:

  - the schema's `fact` names it as the column, the subject, or the
    resource
  - the schema's `grant` names it as the subject, the resource, or an
    attribute
  - it is the primary key
  - it is the foreign key of a relation some bound schema covers, through
    the closure of what the covered schemas cover in turn

  A rule that reads a column no declaration names fails with that column's
  name. A decision that depends on such a column rests on a fact no record
  of a change covers. A rule that reads a table no bound schema owns fails
  as `{:table, name}`, for the same reason.
  """

  alias Mediate.Postgres.Binding
  alias Mediate.Postgres.Catalog
  alias Mediate.Postgres.Domain.Coverage

  @typedoc "An undeclared read: the schema and the column, or a table no bound schema owns."
  @type finding :: {module(), String.t()} | {:table, String.t()}

  @doc "Ok, or the undeclared reads, sorted and without repeats."
  @spec check(Binding.t()) :: :ok | {:error, [finding()]}
  def check(%Binding{} = binding) do
    case undeclared(binding) do
      [] -> :ok
      findings -> {:error, findings}
    end
  end

  @doc "`check/1`, and it raises with every finding in the message."
  @spec check!(Binding.t()) :: :ok
  def check!(%Binding{} = binding) do
    case check(binding) do
      :ok ->
        :ok

      {:error, findings} ->
        raise ArgumentError,
              "the policies on #{Enum.join(Binding.tables(binding), ", ")} read undeclared columns: " <>
                Coverage.describe(findings) <>
                "; declare each as a fact or a grant column, cover its key, or bind the schema that owns the table"
    end
  end

  @doc "Every undeclared read the bound tables' rules make."
  @spec undeclared(Binding.t()) :: [finding()]
  def undeclared(%Binding{} = binding) do
    case Catalog.read(binding) do
      {:ok, %Catalog{reads: reads}} -> Coverage.undeclared(binding, reads)
      {:error, error} -> raise error
    end
  end
end
