defmodule Mediate.Infrastructure.Caller do
  @moduledoc false
  # The module that called the Repo, read from the stack of the process
  # that made the call. It is the first frame that belongs neither to the
  # Repo, nor to the seam, nor to Ecto and the libraries beneath it. The
  # seam records a declared exemption against it. The seam accepts a
  # library exemption only when it is a `Mediate.*` module.

  @skipped_prefixes ~w(Elixir.Ecto. Elixir.DBConnection Elixir.Postgrex) ++
                      ~w(Elixir.Enum Elixir.Stream Elixir.Task Elixir.Agent Elixir.GenServer Elixir.Process Elixir.Kernel)
  # The seam's own modules by name, so this file depends on none of them.
  @seam Enum.map(
          ~w(Repo Facts Domain.Matching Domain.Mediation Domain.Source Infrastructure.Caller Infrastructure.Option Infrastructure.Seam),
          &("Elixir.Mediate." <> &1)
        )

  @doc "The module that made the call, or `:any` when no frame qualifies."
  @spec module(repo :: module()) :: module() | :any
  def module(repo) when is_atom(repo) do
    {:current_stacktrace, frames} = Process.info(self(), :current_stacktrace)

    Enum.find_value(frames, :any, fn
      {module, _function, _arity, _location} when is_atom(module) ->
        if skipped?(module, repo), do: nil, else: module

      _frame ->
        nil
    end)
  end

  @doc "Whether a module is the library's own: `Mediate` or under it."
  @spec library?(module() | :any) :: boolean()
  def library?(Mediate), do: true
  def library?(:any), do: false
  def library?(module) when is_atom(module), do: String.starts_with?(Atom.to_string(module), "Elixir.Mediate.")

  defp skipped?(module, repo) do
    name = Atom.to_string(module)

    module == repo or name in @seam or
      not String.starts_with?(name, "Elixir.") or
      Enum.any?(@skipped_prefixes, &String.starts_with?(name, &1))
  end
end
