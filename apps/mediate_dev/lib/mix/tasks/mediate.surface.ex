defmodule Mix.Tasks.Mediate.Surface do
  @shortdoc "Prints every public name of an application"
  @moduledoc """
  Prints the surface of an application, one name per line: each public
  module, each public function with its arity and its spec, each struct
  field, each atom a public type offers as a choice, each option key, and
  each key of a telemetry event.

      mix mediate.surface
      mix mediate.surface mediate_rbac

  With no argument the task reads the application that runs it. The
  naming test of `mediate` reads the same surface through
  `Mediate.Dev.Surface.of/1` and holds every name to `docs/naming.md`, so
  the printout is what that test sees.
  """

  use Boundary, top_level?: true, deps: [Mix, Mediate.Dev.Surface]
  use Mix.Task

  alias Mediate.Dev.Surface

  @requirements ["app.config"]

  @impl Mix.Task
  def run([]), do: run([Atom.to_string(Mix.Project.config()[:app])])

  def run([app]) do
    {:ok, _started} = Application.ensure_all_started(:mediate_dev)
    surface = Surface.of(String.to_existing_atom(app))
    shell = Mix.shell()
    Enum.each(Surface.to_lines(surface), &shell.info/1)
  end

  def run(_args), do: Mix.raise("mix mediate.surface takes one application name or none")
end
