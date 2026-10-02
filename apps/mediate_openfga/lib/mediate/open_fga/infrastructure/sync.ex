defmodule Mediate.OpenFGA.Infrastructure.Sync do
  @moduledoc false
  # The sync, which runs in the current process: pass after pass until one
  # delivers nothing. A runner in a supervision tree passes on its own
  # interval. This is the same passes without the wait, for a caller that
  # has written facts and wants to ask about them.
  #
  # A pass that did not take the lock is a pass another node runs. A second
  # deliverer of the same cursor delivers the same markers twice for no
  # gain. So the loop stops there.
  #
  # The count of passes has a cap. A pass delivers at most one batch. So a
  # loop that finds markers every time is a table with writes faster than
  # the relay. A caller that waits on that has something worse than a store
  # behind its tables.

  alias Mediate.Error
  alias Mediate.OpenFGA.Binding
  alias Mediate.OpenFGA.Client
  alias Mediate.OpenFGA.Outbox
  alias Mediate.Relay
  alias Mediate.Relay.Pass

  @passes 1_000

  @doc "Passes until one delivers nothing, and answers when there is nothing left."
  @spec run() :: :ok | {:error, Error.t()}
  def run do
    with {:ok, %Binding{} = binding} <- Binding.resolve(), do: loop(runner(binding), @passes)
  end

  defp loop(options, 0) do
    {:error, Error.invalid(:outbox, "#{inspect(options[:name])} still had markers after #{@passes} passes")}
  end

  defp loop(options, left) do
    case Relay.pass(options) do
      {:ok, %Pass{delivered: 0}} -> :ok
      {:ok, %Pass{held?: false}} -> :ok
      {:ok, %Pass{}} -> loop(options, left - 1)
      {:error, reason} -> {:error, failure(reason)}
    end
  end

  defp runner(%Binding{} = binding) do
    [name: Outbox.runner(), repo: binding.repo, job: Outbox, batch: Client.max_tuples_per_write()]
  end

  defp failure(%Error{} = error), do: error

  defp failure(other) do
    %Error{reason: :engine_failed, message: "the sync of #{inspect(Outbox.runner())} failed: #{inspect(other)}"}
  end
end
