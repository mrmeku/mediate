# Mediate Credo checks

*Where does a query reach the database around the mediated repo? For the adopter who runs Credo.*

Two checks, one for each path around the mediated repo. `Mediate.Credo.Check.Warning.RawSQL` flags a call to `Ecto.Adapters.SQL` or `Postgrex`, and `Mediate.Credo.Check.Warning.UnmediatedRepo` flags a repo that `use Ecto.Repo` without `use Mediate.Repo`. Add the package to the `:dev` and `:test` dependencies and name both checks in `.credo.exs`:

```elixir
{Mediate.Credo.Check.Warning.RawSQL, excluded_namespaces: ["MyApp.Outbox"]},
{Mediate.Credo.Check.Warning.UnmediatedRepo, []}
```

`mix credo explain Mediate.Credo.Check.Warning.RawSQL` prints what a check flags and what to do about it. A check reads source text. `Mediate.Conformance.RepoCase` proves at run time what the mediated repo refuses.
