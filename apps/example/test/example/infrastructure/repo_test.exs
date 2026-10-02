defmodule Example.Infrastructure.RepoTest do
  use Mediate.Conformance.RepoCase, repo: Example.Infrastructure.Repo, specimen: Example.Fixture.Specimen, async: true
end
