defmodule ExampleFga do
  @moduledoc """
  The example bound to a relationship graph. Nothing of the domain lives
  here.

  The package holds:

  - the model the boot publishes into the store
  - the mapping that turns the example's tables into tuples
  - the guard that holds the re-authentication window outside the graph
  - the boot, which binds them to `Example.Infrastructure.Repo`
  - the migrations, which create the example's tables and the marker outbox
    the drain works from

  The version identifier is the id the server gives a model on its publish.
  A model is immutable and the server names it by id, so no configuration
  states the version. A boot that publishes leaves a model behind whether
  or not the text changed. An id belongs to the store that issued it, so
  the same text published to a second store gets an id of its own.

  What two stores share is the text, and the version event carries its
  digest. A published version carries the text as its content under the
  cap. The text of `priv/fga/model.fga` is the artifact under review, and
  every question runs under the id the publish returned.

  The store this binding keeps is a copy of the example's own tables. A
  change to a row leaves a marker in the transaction that made it. The
  drain brings the store to what those rows require, object by object.
  """

  use Boundary,
    deps: [Example, Mediate, Mediate.Fga, Mediate.Fga.Relay, Ecto],
    exports: [Application, Infrastructure.Guard, Infrastructure.TupleMapping]

  @author "example_fga"
  @approval "priv/fga/model.fga, as the model under review"
  @model "priv/fga/model.fga"

  @doc "Who wrote the rules, as the record of a policy version carries it."
  @spec author() :: String.t()
  def author, do: @author

  @doc "What approved them, as the record of a policy version carries it."
  @spec approval() :: String.t()
  def approval, do: @approval

  @doc """
  The model file the binding names. A relative path resolves under this
  application's priv directory, so a release finds the text where the
  install put it.
  """
  @spec model() :: Path.t()
  def model do
    case Path.type(@model) do
      :absolute -> @model
      _relative -> Application.app_dir(:example_fga, @model)
    end
  end
end
