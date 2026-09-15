defmodule Mediate.Conformance.RepoCaseTest do
  use Mediate.Conformance.RepoCase,
    repo: Mediate.TestRepos.Sandboxed,
    rows: Mediate.Fixture.Rows,
    async: true
end
