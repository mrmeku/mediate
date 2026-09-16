# Mediate Credo checks

*What is in this package? For an adopter configuring Credo.*

Two advisory checks that find the two ways a query leaves the seam. `Mediate.Credo.NoRawSQL` flags raw SQL, and `Mediate.Credo.UnmediatedRepo` flags an Ecto repo without `use Mediate.Repo`. Add the package to the `:dev` and `:test` dependencies and name both checks in `.credo.exs`. `Mediate.Conformance.RepoCase` is what proves the seam covers the surface.
