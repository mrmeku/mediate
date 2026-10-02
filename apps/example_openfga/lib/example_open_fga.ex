defmodule ExampleOpenFGA do
  @moduledoc """
  The example under OpenFGA. Nothing of the domain lives here.

  The deployment holds five things:

  - the model file under `priv/policies`, which the boot releases into the
    store
  - `ExampleOpenFGA.Infrastructure.Mapping`, the example's tables as tuples
  - `ExampleOpenFGA.Infrastructure.Guard`, which holds the re-authentication
    window outside the graph
  - `ExampleOpenFGA.Application`, the boot that binds them to
    `Example.Infrastructure.Repo`
  - the migrations, which raise the example's tables, the outbox, and the
    relay's cursor

  The policy version is the model id the server answers on a release. A
  model is immutable and the server names it by id, so no configuration
  states the version. A boot that releases leaves a model behind whether or
  not the text changed. An id belongs to the store that issued it, so the
  same text released into a second store gets an id of its own.

  What two stores share is the text, and the version event carries its
  digest. The policy release carries the text as its content, under the
  cap. Every check runs under the model id the release answered.

  The store this deployment keeps is a copy of the example's tables. A
  change to a row leaves a marker in the transaction that made it. A pass
  brings the store to what those rows require, object by object.
  """

  use Boundary,
    deps: [Example, Mediate, Mediate.OpenFGA, Mediate.Relay, Ecto],
    exports: [Application, Infrastructure.Guard, Infrastructure.Mapping]

  @author "the Mediate maintainers"
  @approval "the thirteen clauses of docs/example.md"
  @model_file "priv/policies/model.fga"

  @doc "Who wrote the policy, as the policy release carries it."
  @spec author() :: String.t()
  def author, do: @author

  @doc "What approved it, as the policy release carries it."
  @spec approval() :: String.t()
  def approval, do: @approval

  @doc """
  The model file the binding names. A relative path resolves under this
  application's priv directory, so a release finds the text where the
  install put it.
  """
  @spec model_file() :: Path.t()
  def model_file do
    case Path.type(@model_file) do
      :absolute -> @model_file
      _relative -> Application.app_dir(:example_openfga, @model_file)
    end
  end
end
