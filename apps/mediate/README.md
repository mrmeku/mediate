# Mediate

*What is in this package? For an adopter reading the dependency.*

The port and everything that is the same for every adapter: the four functions an application calls, the `Mediate.Adapter` behaviour, the seam `use Mediate.Repo` and its schema declarations, the events, and the configuration. The suites that hold an adapter to those are `mediate_conformance`, which an adapter author takes in the test environment. The `Mediate` moduledoc says when to use each call, and [Design](design.html) says why each part has its shape. `Mediate.DependenciesTest` asserts the runtime dependencies.
