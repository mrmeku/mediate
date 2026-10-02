defmodule Mediate.Conformance.Generators do
  @moduledoc """
  The generators the conformance properties draw from. A world-shaped
  generator takes the world module, or a world, and reaches the module
  through the struct. It asks that module what terms its rule uses. The
  unknown actions, kinds, and subjects that the library must always deny
  are the same for every world.
  """

  use ExUnitProperties

  alias Mediate.Conformance.World
  alias Mediate.Id

  @unknown_actions [:teleport, :frobnicate, :launch]
  @unknown_kinds [:robot, :ghost, :visitor]

  @doc "A world of the world module."
  @spec world(module()) :: StreamData.t(World.t())
  def world(module) when is_atom(module), do: module.generator()

  @doc "A subject the world knows, of any kind the library knows."
  @spec subject(World.t()) :: StreamData.t(Mediate.subject())
  def subject(world) do
    gen all({_kind, id} <- member_of(World.module(world).subjects(world)), kind <- member_of(Mediate.subject_kinds())) do
      {kind, id}
    end
  end

  @doc "A resource the world holds."
  @spec resource(World.t()) :: StreamData.t(Mediate.resource())
  def resource(world), do: member_of(World.module(world).resources(world))

  @doc "An action the world's rule knows."
  @spec action(module()) :: StreamData.t(atom())
  def action(module) when is_atom(module), do: member_of(module.actions())

  @doc "An action no rule knows."
  @spec unknown_action() :: StreamData.t(atom())
  def unknown_action, do: member_of(@unknown_actions)

  @doc "A known subject, one of an unknown kind, and one the world does not know, for deny by default."
  @spec deny_by_default_subjects(World.t()) ::
          StreamData.t(%{known: Mediate.subject(), unknown_kind: Mediate.subject(), unknown: Mediate.subject()})
  def deny_by_default_subjects(world) do
    fixed_map(%{known: subject(world), unknown_kind: unknown_kind_subject(world), unknown: unknown_subject()})
  end

  @doc "A subject of a kind the library does not know."
  @spec unknown_kind_subject(World.t()) :: StreamData.t(Mediate.subject())
  def unknown_kind_subject(world) do
    gen all({_kind, id} <- member_of(World.module(world).subjects(world)), kind <- member_of(@unknown_kinds)) do
      {kind, id}
    end
  end

  @doc "A subject the world does not know."
  @spec unknown_subject() :: StreamData.t(Mediate.subject())
  def unknown_subject do
    gen all(
          suffix <- string(:alphanumeric, min_length: 1, max_length: 6),
          kind <- member_of(Mediate.subject_kinds())
        ) do
      {kind, "nobody-" <> suffix}
    end
  end

  @doc "A subject with a fresh id."
  @spec fresh_subject() :: StreamData.t(Mediate.subject())
  def fresh_subject do
    gen all(id <- repeatedly(&Id.new/0), kind <- member_of(Mediate.subject_kinds())) do
      {kind, id}
    end
  end
end
