# Mediate

*What is in this package? For an adopter reading the dependency.*

The port and everything that is the same for every adapter: the four functions an application calls, the `Mediate.Adapter` behaviour, the seam `use Mediate.Repo` and its schema declarations, the events, the configuration, and the conformance suites. The `Mediate` moduledoc says when to use each call, and `docs/design.md` says why each part has its shape. The runtime dependencies are asserted by `dependencies_test.exs`.
