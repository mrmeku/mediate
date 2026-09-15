defmodule ExampleFga.OutboxTest do
  @moduledoc """
  Holds the markers, the mapping, and a store together: what the tables say
  is what the store holds, and it stays that way.
  """

  use Mediate.Fga.OutboxCase,
    async: false,
    repo: Example.Infrastructure.Repo,
    population: ExampleFga.Population,
    sandbox: ExampleFga.OutboxSetup
end
