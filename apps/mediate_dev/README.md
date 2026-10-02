# Mediate dev

*What is in this package? For a contributor.*

`mediate_dev` holds what a test run of this repository needs and no adopter does: one Postgres cluster per `mix test` run, the sandbox each case template checks out, the Cerbos and OpenFGA servers, the structure dump, the package build, and the layout test. It is never published. The `Mediate.Dev` moduledoc names each, and `Mediate.Dev.Cluster` says what the cluster does.
