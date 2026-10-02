defmodule Mediate.Cerbos.Request do
  @moduledoc """
  The bodies the server reads: one for a decision over resources, one for
  a plan. Both carry the principal with the attributes the declarations
  name, and the subject kind as its one role. So a policy says which kinds
  it answers for when it names roles. Nothing else about the subject
  travels.

  A request body is an edge, so it is the one map here and not a struct.
  This module is the only place that builds it. Each body carries a
  request id of its own, which the verdict names, so a server's audit log
  and a decision event meet on it.
  """

  alias Mediate.Cerbos.Attribute
  alias Mediate.Id

  @doc """
  A decision for one action over resources, each with the attribute
  values read for it: the body of `POST /api/check/resources`.
  """
  @spec check(Mediate.subject(), atom(), Attribute.values(), [{Mediate.resource(), Attribute.values()}]) :: map()
  def check({_kind, _account} = subject, action, principal, resources)
      when is_atom(action) and is_map(principal) and is_list(resources) do
    %{
      requestId: Id.new(),
      includeMeta: true,
      principal: principal(subject, principal),
      resources: Enum.map(resources, fn {resource, attributes} -> resource(resource, action, attributes) end)
    }
  end

  @doc "A plan for one action over a resource type: the body of `POST /api/plan/resources`."
  @spec plan(Mediate.subject(), atom(), atom(), Attribute.values()) :: map()
  def plan({_kind, _account} = subject, action, type, principal)
      when is_atom(action) and is_atom(type) and is_map(principal) do
    %{
      requestId: Id.new(),
      includeMeta: true,
      principal: principal(subject, principal),
      resource: %{kind: Atom.to_string(type)},
      action: Atom.to_string(action)
    }
  end

  @doc """
  A decision body from a principal and a resource already in the server's
  shape, with their attributes inline, so the question needs no row.
  """
  @spec inline(map(), map(), [String.t()]) :: map()
  def inline(principal, resource, actions) when is_map(principal) and is_map(resource) and is_list(actions) do
    %{requestId: Id.new(), includeMeta: true, principal: principal, resources: [%{resource: resource, actions: actions}]}
  end

  @doc "The principal as the server reads it: the subject's id, its kind as a role, and its attributes."
  @spec principal(Mediate.subject(), Attribute.values()) :: map()
  def principal({kind, id}, attributes) when is_map(attributes) do
    %{id: to_string(id), roles: [Atom.to_string(kind)], attr: attributes}
  end

  defp resource({type, id}, action, attributes) do
    %{
      resource: %{kind: Atom.to_string(type), id: to_string(id), attr: attributes},
      actions: [Atom.to_string(action)]
    }
  end
end
