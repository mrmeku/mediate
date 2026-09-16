defmodule Mediate.Postgres.Coverage do
  @moduledoc """
  Declared-fact coverage for row-level security: every column the policies
  read is a declared fact.

  `check/1` reads the policy expressions from `pg_policy` and the columns
  they reference from `pg_depend`, which records one dependency per column
  an expression names. Then it asks the bound schemas whether each of those
  columns has a declaration. `docs/conformance.md` under "The laws" names this check
  `au12-07`.

  A column counts as declared in four cases:

  - a `fact` declaration on its schema names it as the fact column, the
    subject, or the object
  - a `relationship` declaration names it as the subject, the object, or an
    attribute
  - it is the schema's primary key
  - it is the foreign key of a relation a bound schema carries, through the
    closure of what the carried schemas carry in turn

  A policy that reads a column no declaration names fails with that
  column's name. A decision that depends on such a column rests on a fact
  no record of a change covers. A policy that reads a table no bound schema
  names fails as `{:table, name}`, for the same reason.
  """

  alias Mediate.Postgres.Binding
  alias Mediate.Postgres.Catalog
  alias Mediate.Postgres.Domain.Declared

  @typedoc "An undeclared read: the schema and the column, or a table no bound schema names."
  @type finding :: {module(), String.t()} | {:table, String.t()}

  @doc "`:ok`, or the undeclared reads, sorted and without repeats."
  @spec check(Binding.t()) :: :ok | {:error, [finding()]}
  def check(%Binding{} = binding) do
    case undeclared(binding) do
      [] -> :ok
      findings -> {:error, findings}
    end
  end

  @doc "`check/1`, but it raises with every finding named."
  @spec check!(Binding.t()) :: :ok
  def check!(%Binding{} = binding) do
    case check(binding) do
      :ok -> :ok
      {:error, findings} -> raise ArgumentError, "policies read undeclared columns: " <> Declared.describe(findings)
    end
  end

  @doc "Every undeclared read the bound tables' policies make."
  @spec undeclared(Binding.t()) :: [finding()]
  def undeclared(%Binding{} = binding) do
    %Catalog{columns: columns} = Catalog.read!(binding)
    Declared.findings(binding, columns)
  end
end
