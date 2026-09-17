defmodule Example.Domain.Rollup do
  @moduledoc """
  Rule C4 at the domain's face: a row's visibility, the rollup over a set of
  rows, and whether a rollup covers a visibility.

  A repository's rollup is the visibility that admits no subject a directory of it
  denies. The labels and the restrictions are the union of the directories'.
  The REGIONS country list is the intersection of the lists of the directories
  that carry that restriction. So no rollup releases a country one directory
  withholds. The repositories context keeps the rollup at write time and
  refuses a visibility change that drops a directory's restriction.

  The arithmetic reads visibilities as values and holds nothing, so a property
  covers these laws and not examples. `Example.Domain.Restrictions` names the
  vocabulary.
  """

  alias Example.Domain.Restrictions

  @fields [:labels, :restrictions, :releasable_to]

  @doc "The visibility fields of a row or a map, with each list sorted and without repeats."
  @spec visibility(map()) :: Restrictions.visibility()
  def visibility(row) when is_map(row) do
    Map.new(@fields, fn field -> {field, values(row, field)} end)
  end

  @doc """
  The rollup over a set of rows, each read as the visibility it carries. It is
  the visibility that admits no subject any of them denies, and admits every
  subject all of them admit.

  A label or a restriction restricts when a visibility carries it, so the rollup
  carries every one any visibility carries. REGIONS admits by its list, so the
  rollup releases to the countries every visibility that carries the restriction
  releases to. A visibility without the restriction narrows nothing. Where no
  visibility carries `releasable_to`, the list is empty and the restriction is
  absent with it. That releases the rollup to everyone and not to no one.
  """
  @spec of([map()]) :: Restrictions.visibility()
  def of(rows) when is_list(rows) do
    visibilities = Enum.map(rows, &visibility/1)

    %{
      labels: union(visibilities, :labels),
      restrictions: union(visibilities, :restrictions),
      releasable_to: releases(visibilities)
    }
  end

  @doc """
  Whether the rollup covers the visibility: every subject the rollup admits,
  the visibility admits too.

  The rollup carries every label and every restriction of the visibility. Where
  the visibility carries `releasable_to`, the rollup releases to no country
  outside the visibility's list.
  """
  @spec covers?(map(), map()) :: boolean()
  def covers?(rollup, visibility) when is_map(rollup) and is_map(visibility) do
    rollup = visibility(rollup)
    visibility = visibility(visibility)

    Enum.all?([:labels, :restrictions], fn field -> visibility[field] -- rollup[field] == [] end) and
      releases_within?(rollup, visibility)
  end

  defp values(row, field) do
    row
    |> Map.get(field, [])
    |> List.wrap()
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp union(visibilities, field) do
    visibilities
    |> Enum.flat_map(& &1[field])
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp releases(visibilities) do
    case Enum.filter(visibilities, &(:releasable_to in &1.restrictions)) do
      [] ->
        []

      [first | rest] ->
        rest
        |> Enum.reduce(MapSet.new(first.releasable_to), &MapSet.intersection(&2, MapSet.new(&1.releasable_to)))
        |> Enum.sort()
    end
  end

  defp releases_within?(rollup, visibility) do
    :releasable_to not in visibility.restrictions or rollup.releasable_to -- visibility.releasable_to == []
  end
end
