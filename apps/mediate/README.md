# Mediate

The port and everything that is the same for every adapter:

- the four functions an application calls
- the behaviour an adapter implements
- the seam that keeps the log complete
- the three events
- the conformance suites

`docs/design.md` says why each has the shape it has. The moduledocs say what each does.

This package's `lib` depends on `ecto`, `nimble_options`, and `stream_data`. The generators are a product an adopter runs, so `stream_data` is a runtime dependency. `ecto_sql` and `postgrex` serve this package's own tests only, and Boundary checks that no call from `lib` reaches them. The Postgres cluster the tests start lives in `mediate_dev`.

## The configuration of an application

```elixir
config :mediate,
  adapter: MyApp.Adapter,
  clock: &DateTime.utc_now/0,
  caps: [policy_content_bytes: 65_536]
```

The adapter is a module or a `{module, keyword}` pair. The adapter's `options_schema/0` validates the keyword. The caller supplies every environment fact beyond `now` in `opts`, under `env:`. The caller supplies an operation id under `operation_id:`, and the port makes one when the caller does not.
