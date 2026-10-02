defmodule Mediate.TestRepos do
  @moduledoc """
  The repos of this repository's own runs:

  - the app role on the sandboxed database
  - the app role on the durable database
  - the owner role on the durable database

  A deployment runs its own repos instead.
  """

  use Boundary,
    top_level?: true,
    deps: [Ecto, Ecto.Adapters.Postgres, Ecto.Adapters.SQL, Mediate],
    exports: [Durable, Owner, Sandboxed]
end

defmodule Mediate.TestRepos.Sandboxed do
  @moduledoc "The app-role repo on the sandboxed database, one transaction per test."
  use Ecto.Repo, otp_app: :mediate, adapter: Ecto.Adapters.Postgres
  use Mediate.Repo
end

defmodule Mediate.TestRepos.Durable do
  @moduledoc "The app-role repo on the durable database, for tests that need real commits."
  use Ecto.Repo, otp_app: :mediate, adapter: Ecto.Adapters.Postgres
  use Mediate.Repo
end

defmodule Mediate.TestRepos.Owner do
  @moduledoc "The owner-role repo on the durable database, for the library's own writes and truncation."
  use Ecto.Repo, otp_app: :mediate, adapter: Ecto.Adapters.Postgres
  use Mediate.Repo, role: :owner
end
