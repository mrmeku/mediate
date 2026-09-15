defmodule Mediate.Postgres.Infrastructure.Session do
  @moduledoc false
  # Where the settings meet the connection. `set_config(name, value, true)`
  # is local to a transaction. So a call outside a transaction opens one for
  # the length of the call, and the settings leave with it. A call inside a
  # transaction sets them there. The next call in that transaction sets its
  # own over them, so two subjects in one transaction never read each
  # other's.
  #
  # Every call puts back what it found. Each name it wrote returns to the
  # value the call around it holds, whether the function returned or
  # raised. Where no call is around it, that value is the empty string. A
  # transaction the adapter did not open outlives the call. So does one the
  # adapter opens inside another, which the database keeps as a savepoint
  # whose settings survive its release.
  #
  # Consider a later statement in the same transaction that the seam admits
  # outside a decision. Without the put-back, it runs under the settings of
  # the decision before it. A policy written for "no operation in force"
  # then does not hold. A mediated read inside a mediated write is the other side of the
  # same coin. The read sets the settings the call gave it, and the write
  # after it needs them still there. So the read leaves the outer call's
  # settings behind, not an empty string.
  #
  # The put-back runs through the repo channel that does not raise, so a
  # transaction the function already aborted keeps the error the function
  # raised. Each statement runs through the bound repo's raw channel under
  # the library exemption, and each is one query in the shape counts.

  alias Mediate.Postgres.Infrastructure.Settings

  @exemption {:exempt, :library}
  @stash {__MODULE__, :settings}
  @in_force {__MODULE__, :in_force}

  @doc "Run the function with the settings in force on the connection it uses."
  @spec around(module(), Settings.t(), (-> result)) :: result when result: term()
  def around(repo, %Settings{} = settings, fun) when is_atom(repo) and is_function(fun, 0) do
    if repo.in_transaction?() do
      set(repo, settings, Process.get(@in_force), fun)
    else
      {:ok, value} = repo.transaction(fn -> set(repo, settings, nil, fun) end)
      value
    end
  end

  @doc """
  Keep the settings a call ran under, so a query the seam mediates with
  that call's decision runs under the same ones. The process holds one
  slot per subject and operation, because a decision names those two. The
  next call for the same pair overwrites the last. The slots are not one,
  because a review decides for every subject before the reviewer runs a
  query under any of them.
  """
  @spec remember(Mediate.subject(), atom(), Settings.t()) :: :ok
  def remember({_kind, _account} = subject, operation, %Settings{} = settings) when is_atom(operation) do
    Process.put(@stash, Map.put(Process.get(@stash, %{}), key(subject, operation), settings))
    :ok
  end

  @doc "The kept settings for a subject and an operation, or `nil` when no call for the pair ran here."
  @spec recall(Mediate.subject(), atom()) :: Settings.t() | nil
  def recall({_kind, _account} = subject, operation) when is_atom(operation) do
    Map.get(Process.get(@stash, %{}), key(subject, operation))
  end

  defp key({_kind, id}, operation), do: {id, operation}

  defp set(repo, settings, outer, fun) do
    {statement, params} = Settings.statement(settings)
    _result = repo.query!(statement, params, mediate: @exemption)
    Process.put(@in_force, settings)

    try do
      fun.()
    after
      Process.put(@in_force, outer)
      put_back(repo, settings, outer)
    end
  end

  defp put_back(repo, settings, outer) do
    {statement, params} = Settings.statement(back(settings, outer))
    _result = repo.query(statement, params, mediate: @exemption)
    :ok
  end

  defp back(settings, nil), do: Settings.cleared(settings)
  defp back(settings, %Settings{} = outer), do: Settings.restored(settings, outer)
end
