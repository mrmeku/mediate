defmodule Mediate.OpenFGA.OutboxTest do
  use Mediate.OpenFGA.OutboxCase,
    async: false,
    repo: Mediate.TestRepos.Sandboxed,
    population: Mediate.OpenFGA.Conformance.Population,
    setup: Mediate.OpenFGA.Conformance.Setup
end
