defmodule Example.Domain.Reauthentication do
  @moduledoc """
  Re-authentication (C8). The window is the organization's parameter for
  IA-11. A session is fresh when the context's `reauthenticated_at` fact is
  within the window of Mediate's clock. The caller supplies the fact from
  the identity layer, and the engine reads it. The engines that compute in
  code call this module.
  """

  @window 900

  @doc "The re-authentication window in seconds."
  @spec window() :: pos_integer()
  def window, do: @window

  @doc "Whether the context's `reauthenticated_at` fact is within the window of its clock, so the session is fresh."
  @spec fresh?(Mediate.context()) :: boolean()
  def fresh?(%{now: %DateTime{} = now} = context) do
    case context[:reauthenticated_at] do
      %DateTime{} = at -> DateTime.diff(now, at, :second) in 0..@window
      _absent -> false
    end
  end
end
