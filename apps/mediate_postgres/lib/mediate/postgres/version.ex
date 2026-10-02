defmodule Mediate.Postgres.Version do
  @moduledoc """
  The policy version of row-level security: the migration number. A
  migration that changes a rule appends its own version in the same
  transaction as its DDL. So the rules and the record of what they became
  commit together or not at all, and a decision after it names that
  number. The events document under "Policy release" has the event and
  the cap.

  The text is the rules as `pg_policy` renders them. The release carries
  it by value when under the cap the caller gives, and the tables as its
  location otherwise. The text hash is the sha256 of that text either way.
  `Mediate.Postgres.Migration.release!/2` builds the release and publishes
  it, in the migration's transaction.
  """

  alias Mediate.PolicyRelease
  alias Mediate.Postgres.Rule

  @doc "The policy's text: each rule as `Mediate.Postgres.Rule.to_text/1` renders it."
  @spec text([Rule.t()]) :: String.t()
  def text(rules) when is_list(rules), do: Enum.map_join(rules, "", &Rule.to_text/1)

  @doc "The sha256 of `text/1`, in lower-case hex."
  @spec text_hash([Rule.t()]) :: String.t()
  def text_hash(rules) when is_list(rules), do: Base.encode16(:crypto.hash(:sha256, text(rules)), case: :lower)

  @doc """
  The release of `engine` as the event carries it, with the text by value
  when under the cap. Requires `policy_version:`, `author:`, `approval:`,
  `released_at:`, and `policy_text_bytes:`.
  """
  @spec release(module(), [Rule.t()], keyword()) :: PolicyRelease.t()
  def release(engine, rules, options) when is_atom(engine) and is_list(rules) and is_list(options) do
    text = text(rules)
    under_cap? = byte_size(text) <= Keyword.fetch!(options, :policy_text_bytes)

    %PolicyRelease{
      engine: engine,
      policy_version: to_string(Keyword.fetch!(options, :policy_version)),
      text_hash: text_hash(rules),
      text: if(under_cap?, do: text),
      text_location: if(under_cap?, do: nil, else: location(rules)),
      author: Keyword.fetch!(options, :author),
      approval: Keyword.fetch!(options, :approval),
      released_at: Keyword.fetch!(options, :released_at)
    }
  end

  defp location(rules) do
    tables =
      rules
      |> Enum.map(& &1.table)
      |> Enum.uniq()
      |> Enum.sort()

    "policies on " <> Enum.join(tables, ", ")
  end
end
