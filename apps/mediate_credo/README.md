# Mediate Credo checks

Two Credo checks that find the two ways a query leaves the seam. `Mediate.Credo.NoRawSQL` flags raw SQL. `Mediate.Credo.UnmediatedRepo` flags an Ecto repo without `use Mediate.Repo`. Both read source text, and both are advisory. `Mediate.Conformance.RepoCase` is what proves the seam covers the surface. Add the package to the `:dev` and `:test` dependencies, and name the checks in `.credo.exs`:

```elixir
{Mediate.Credo.NoRawSQL, [allow: ["MyApp.Outbox"]]},
{Mediate.Credo.UnmediatedRepo, []}
```
