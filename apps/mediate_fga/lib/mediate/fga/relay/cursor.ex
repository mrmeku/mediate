defmodule Mediate.Fga.Relay.Cursor do
  @moduledoc """
  How far a runner has delivered: one row per runner, which holds the
  position of the last entry that left in a pass that committed.

  The pass advances the row in the same transaction as the delivery it
  records. So a pass that does not commit leaves the cursor where it was,
  and the next pass reads the batch again. A runner no row names stands at
  zero, which is below every position. So a first pass reads from the start
  of the table.

  The table states nothing about a subject or an object. An application
  reads a position from it to see how far behind a runner is.
  """

  use Ecto.Schema

  import Ecto.Query, only: [from: 2]

  @primary_key {:name, :string, autogenerate: false}
  @exemption {:exempt, :library}

  @typedoc "One runner's cursor row."
  @type t :: %__MODULE__{}

  schema "mediate_relay_cursor" do
    field :position, :integer
  end

  @doc "The position the runner has delivered to, zero when no row names it."
  @spec position(module(), atom()) :: non_neg_integer()
  def position(repo, name) when is_atom(repo) and is_atom(name) do
    query = from c in __MODULE__, where: c.name == ^Atom.to_string(name), select: c.position

    repo.one(query, mediate: @exemption) || 0
  end

  @doc "Records the runner as delivered to this position."
  @spec advance(module(), atom(), non_neg_integer()) :: :ok
  def advance(repo, name, position) when is_atom(repo) and is_atom(name) and is_integer(position) do
    entry = %{name: Atom.to_string(name), position: position}
    options = [on_conflict: {:replace, [:position]}, conflict_target: :name, mediate: @exemption]
    {_count, nil} = repo.insert_all(__MODULE__, [entry], options)

    :ok
  end
end
