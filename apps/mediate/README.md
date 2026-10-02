# Mediate

*What is in this package? For an adopter reading the dependency.*

The four functions an application calls, and everything that is the same for every engine: the `Mediate.Engine` behaviour, the mediated repo `use Mediate.Repo` and its schema declarations, the events, and the configuration. The suites that hold an engine to those are `mediate_conformance`, which an engine author takes in the test environment. The `Mediate` moduledoc says when to use each call, [Naming](naming.html) says why each thing has its name, and [Design](design.html) says why each part has its shape. `Mediate.DependenciesTest` asserts the runtime dependencies.
