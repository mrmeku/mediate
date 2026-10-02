defmodule Mediate.Dev.TestRepos do
  @moduledoc """
  The repos of this package's own run:

  - `Sandboxed`, the app role on the sandboxed database
  - `Durable`, the app role on the durable database
  - `Owner`, the owner role on the durable database
  - `Dump`, the repo the structure test hands to its own cluster

  They are plain repos. The mediated repo belongs to `mediate`, and this
  package proves the cluster and the dump, not the mediated repo.
  """

  use Boundary,
    top_level?: true,
    deps: [Ecto, Ecto.Adapters.Postgres, Ecto.Adapters.SQL],
    exports: [Dump, Durable, Owner, Sandboxed]
end

defmodule Mediate.Dev.TestRepos.Sandboxed do
  @moduledoc "The app-role repo on the sandboxed database, one transaction per test."
  use Ecto.Repo, otp_app: :mediate_dev, adapter: Ecto.Adapters.Postgres
end

defmodule Mediate.Dev.TestRepos.Durable do
  @moduledoc "The app-role repo on the durable database."
  use Ecto.Repo, otp_app: :mediate_dev, adapter: Ecto.Adapters.Postgres
end

defmodule Mediate.Dev.TestRepos.Owner do
  @moduledoc "The owner-role repo on the durable database."
  use Ecto.Repo, otp_app: :mediate_dev, adapter: Ecto.Adapters.Postgres
end

defmodule Mediate.Dev.TestRepos.Dump do
  @moduledoc "The owner-role repo the structure test names. It runs in the dump's own cluster."
  use Ecto.Repo, otp_app: :mediate_dev, adapter: Ecto.Adapters.Postgres
end
