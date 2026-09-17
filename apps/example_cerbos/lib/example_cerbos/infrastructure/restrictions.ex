defmodule ExampleCerbos.Infrastructure.Restrictions do
  # Hidden, because what the sidecar reads is an attribute declaration and
  # not this module. What is here is the one derivation the policy language
  # does not carry: which restrictions are effective on a visibility.
  #
  # A restriction is effective when the visibility declares it, or when a sensitive
  # label the visibility names implies it (C3). The derivation is a union
  # over the restriction names, one query per name. Each query selects the row
  # and the name as text. A directory is under embargo while its repository is
  # (C4, C5). The date is on a row the directory does not carry, so the moment
  # arrives as an argument and the test is inside the subquery.
  @moduledoc false

  import Ecto.Query, only: [from: 2, union_all: 2]

  alias Example.Domain.Directory
  alias Example.Domain.Label
  alias Example.Domain.Repository
  alias Example.Domain.Restrictions
  alias Example.Domain.Visibility

  @doc "The restrictions effective on each repository's rollup, declared or implied."
  @spec on_repositories() :: Ecto.Query.t()
  def on_repositories, do: union_of(&repository_restriction/1)

  @doc """
  The restrictions effective on each directory's own visibility, while the repository's
  embargo date is absent or after `at`.
  """
  @spec on_directories(DateTime.t()) :: Ecto.Query.t()
  def on_directories(%DateTime{} = at), do: union_of(&directory_restriction(&1, at))

  defp union_of(member) do
    [first | rest] = Enum.map(Restrictions.all(), member)

    Enum.reduce(rest, first, fn query, combined -> union_all(combined, ^query) end)
  end

  defp repository_restriction(restriction) do
    name = Atom.to_string(restriction)

    from(m in Visibility,
      left_join: c in Label,
      on: c.name in m.labels and c.sensitive,
      where: ^restriction in m.restrictions or ^restriction in c.implied_restrictions,
      distinct: true,
      select: %{id: m.repository_id, value: type(^name, :string)}
    )
  end

  # The directory's own visibility, under the repository's embargo date. A directory
  # carries no date of its own. A restriction the repository has released is
  # effective on none of its directories.
  defp directory_restriction(restriction, at) do
    name = Atom.to_string(restriction)

    from(directory in Directory,
      join: d in Repository,
      on: d.id == directory.repository_id,
      left_join: c in Label,
      on: c.name in directory.labels and c.sensitive,
      where: ^restriction in directory.restrictions or ^restriction in c.implied_restrictions,
      where: is_nil(d.embargo) or d.embargo > ^at,
      distinct: true,
      select: %{id: directory.id, value: type(^name, :string)}
    )
  end
end
