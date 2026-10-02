defmodule Mediate.Conformance.RepoCase.Arguments do
  @moduledoc false
  # The arguments `Mediate.Conformance.RepoCase` sweeps each exported
  # function with, on the tableless schema.

  alias Mediate.Conformance.RepoCase.Tableless

  @row %Tableless{id: 1, parent_id: 2}

  @doc "The arguments to sweep one exported function with."
  @spec args(atom(), non_neg_integer()) :: [term()]
  def args(:aggregate, 4), do: [Tableless, :avg, :id, []]

  def args(name, arity) do
    name
    |> full()
    |> Enum.take(arity)
  end

  defp full(:aggregate), do: [Tableless, :count, []]
  defp full(:preload), do: [@row, :parent, []]
  defp full(:reload), do: [@row, []]
  defp full(:reload!), do: [@row, []]
  defp full(:update_all), do: [Tableless, [set: [name: "renamed"]], []]
  defp full(:insert_all), do: [Tableless, [%{name: "new"}], []]
  defp full(name) when name in [:get, :get!], do: [Tableless, 1, []]
  defp full(name) when name in [:get_by, :get_by!, :all_by], do: [Tableless, [id: 1], []]
  defp full(name) when name in [:insert, :insert!], do: [%Tableless{name: "new"}, []]
  defp full(name) when name in [:update, :update!], do: [Ecto.Changeset.change(@row, name: "renamed"), []]
  defp full(name) when name in [:insert_or_update, :insert_or_update!], do: [Ecto.Changeset.change(@row), []]
  defp full(name) when name in [:delete, :delete!], do: [@row, []]
  defp full(name) when name in [:query, :query!, :query_many, :query_many!], do: ["SELECT 1", [], []]
  defp full(_name), do: [Tableless, []]
end
