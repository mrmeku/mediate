defmodule Mediate.Fga.OutboxTest do
  use Mediate.Fga.OutboxCase,
    async: false,
    repo: Mediate.TestRepos.Sandboxed,
    population: Mediate.Fga.Conformance.Population,
    sandbox: Mediate.Fga.Conformance.Setup
end
