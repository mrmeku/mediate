defmodule Mediate.Dev.TestRepos do
  @moduledoc """
  The repos of this package's own run:

  - `Sandboxed`, the application role on the sandboxed database
  - `Committed`, the application role on the committed database
  - `Owner`, the owner role on the committed database
  - `Dump`, the repo the schema-dump test hands to its own cluster

  They are plain repos. The seam belongs to `mediate`, and this package
  proves the cluster and the dump, not the seam.
  """

  use Boundary,
    top_level?: true,
    deps: [Ecto, Ecto.Adapters.Postgres, Ecto.Adapters.SQL],
    exports: [Committed, Dump, Owner, Sandboxed]
end

defmodule Mediate.Dev.TestRepos.Sandboxed do
  @moduledoc "The application-role repo on the sandboxed database, one transaction per test."
  use Ecto.Repo, otp_app: :mediate_dev, adapter: Ecto.Adapters.Postgres
end

defmodule Mediate.Dev.TestRepos.Committed do
  @moduledoc "The application-role repo on the committed database."
  use Ecto.Repo, otp_app: :mediate_dev, adapter: Ecto.Adapters.Postgres
end

defmodule Mediate.Dev.TestRepos.Owner do
  @moduledoc "The owner-role repo on the committed database."
  use Ecto.Repo, otp_app: :mediate_dev, adapter: Ecto.Adapters.Postgres
end

defmodule Mediate.Dev.TestRepos.Dump do
  @moduledoc "The owner-role repo the schema-dump test names. It runs in the dump's own cluster."
  use Ecto.Repo, otp_app: :mediate_dev, adapter: Ecto.Adapters.Postgres
end
