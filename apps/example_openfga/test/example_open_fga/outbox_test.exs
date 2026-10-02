defmodule ExampleOpenFGA.OutboxTest do
  @moduledoc """
  Holds the markers, the mapping, and a store together: what the tables
  require is what the store holds, and it stays that way.
  """

  use Mediate.OpenFGA.OutboxCase,
    async: false,
    repo: Example.Infrastructure.Repo,
    population: ExampleOpenFGA.Population,
    setup: ExampleOpenFGA.OutboxStore
end
