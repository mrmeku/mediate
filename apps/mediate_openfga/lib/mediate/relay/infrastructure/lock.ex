defmodule Mediate.Relay.Infrastructure.Lock do
  @moduledoc false
  # The advisory lock one pass acquires, so that two nodes with the same
  # runner do not read and deliver the same batch at once.
  #
  # The lock is transaction-scoped. Postgres releases it when the pass's
  # transaction ends, however it ends, so a node that stops holds nothing.
  # The pass tries the lock and waits on nothing. A runner that finds
  # another node in delivery has no use for the wait. It steps aside and
  # tries again after its idle interval, and by then the other node has
  # usually delivered those rows.

  import Ecto.Query, only: [from: 2]

  alias Mediate.Relay.Domain.Key

  @exemption {:exempt, :library}

  @doc "Acquires the lock for the rest of the current transaction. Answers whether it got the lock."
  @spec acquired?(module(), atom()) :: boolean()
  def acquired?(repo, name) when is_atom(repo) and is_atom(name) do
    {class, key} = Key.of(name)

    query =
      from(lock in fragment("SELECT pg_try_advisory_xact_lock(?::int, ?::int) AS acquired", ^class, ^key),
        select: lock.acquired
      )

    repo.one(query, authorized_by: @exemption)
  end
end
