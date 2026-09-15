defmodule Example.Infrastructure.RepoTest do
  use Mediate.Conformance.RepoCase, repo: Example.Infrastructure.Repo, rows: Example.Fixture.Rows, async: true
end
