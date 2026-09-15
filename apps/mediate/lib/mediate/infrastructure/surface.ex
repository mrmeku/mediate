defmodule Mediate.Infrastructure.Surface do
  @moduledoc false
  # Every function `use Ecto.Repo` defines, by name and arity, in exactly one
  # of four buckets. The list holds for Ecto 3.14 and ecto_sql 3.14.
  # `Mediate.Conformance.RepoCase` diffs it against a compiled Repo's
  # exports, so a release that adds a function fails that test by name.
  #
  # - *query*: `prepare_query/3` judges it, and the seam wraps it.
  # - *write*: the seam overrides it. It judges, records, and wraps.
  # - *raw*: the seam wraps it to demand an exemption.
  # - *plumbing*: it touches no rows, and the seam leaves it alone.
  #
  # The list also holds the shorter arities that default arguments generate.
  # So an override that redeclares `opts \\ []` covers every arity the Repo
  # exports.

  @query [
    aggregate: 2,
    aggregate: 3,
    aggregate: 4,
    all: 1,
    all: 2,
    all_by: 2,
    all_by: 3,
    delete_all: 1,
    delete_all: 2,
    exists?: 1,
    exists?: 2,
    get: 2,
    get: 3,
    get!: 2,
    get!: 3,
    get_by: 2,
    get_by: 3,
    get_by!: 2,
    get_by!: 3,
    one: 1,
    one: 2,
    one!: 1,
    one!: 2,
    preload: 2,
    preload: 3,
    reload: 1,
    reload: 2,
    reload!: 1,
    reload!: 2,
    stream: 1,
    stream: 2,
    update_all: 2,
    update_all: 3
  ]

  @write [
    delete: 1,
    delete: 2,
    delete!: 1,
    delete!: 2,
    insert: 1,
    insert: 2,
    insert!: 1,
    insert!: 2,
    insert_all: 2,
    insert_all: 3,
    insert_or_update: 1,
    insert_or_update: 2,
    insert_or_update!: 1,
    insert_or_update!: 2,
    update: 1,
    update: 2,
    update!: 1,
    update!: 2
  ]

  @raw [
    query: 1,
    query: 2,
    query: 3,
    query!: 1,
    query!: 2,
    query!: 3,
    query_many: 1,
    query_many: 2,
    query_many: 3,
    query_many!: 1,
    query_many!: 2,
    query_many!: 3
  ]

  @plumbing [
    __adapter__: 0,
    __mediate__: 1,
    checked_out?: 0,
    checkout: 1,
    checkout: 2,
    child_spec: 1,
    config: 0,
    default_options: 1,
    disconnect_all: 1,
    disconnect_all: 2,
    explain: 2,
    explain: 3,
    get_dynamic_repo: 0,
    in_transaction?: 0,
    load: 2,
    prepare_query: 3,
    prepare_transaction: 2,
    put_dynamic_repo: 1,
    rollback: 1,
    start_link: 0,
    start_link: 1,
    stop: 0,
    stop: 1,
    to_sql: 2,
    to_sql: 3,
    transact: 1,
    transact: 2,
    transaction: 1,
    transaction: 2
  ]

  @type entry :: {atom(), non_neg_integer()}
  @type bucket :: :query | :write | :raw | :plumbing

  @doc "The functions `prepare_query/3` judges."
  @spec query() :: [entry()]
  def query, do: @query

  @doc "The functions the seam overrides."
  @spec write() :: [entry()]
  def write, do: @write

  @doc "The functions the seam wraps to demand an exemption."
  @spec raw() :: [entry()]
  def raw, do: @raw

  @doc "The functions that touch no rows."
  @spec plumbing() :: [entry()]
  def plumbing, do: @plumbing

  @doc "Every entry, with its bucket."
  @spec all() :: [{atom(), non_neg_integer(), bucket()}]
  def all do
    Enum.map(@query, &bucketed(&1, :query)) ++
      Enum.map(@write, &bucketed(&1, :write)) ++
      Enum.map(@raw, &bucketed(&1, :raw)) ++
      Enum.map(@plumbing, &bucketed(&1, :plumbing))
  end

  @doc "The bucket of one name and arity, or `nil` when the list does not classify it."
  @spec bucket(atom(), non_neg_integer()) :: bucket() | nil
  def bucket(name, arity) when is_atom(name) and is_integer(arity) do
    Enum.find_value(all(), fn {n, a, bucket} -> if n == name and a == arity, do: bucket end)
  end

  defp bucketed({name, arity}, bucket), do: {name, arity, bucket}
end
