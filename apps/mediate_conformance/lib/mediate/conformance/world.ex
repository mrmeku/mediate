defmodule Mediate.Conformance.World do
  @moduledoc """
  The population a Tier 1 run writes, which the caller supplies.
  `use Mediate.Conformance.AdapterCase, world: MyApp.World` hands the
  template a module. That module answers what a population holds, what the
  rule over it says, and how to write one through the seam. The properties
  and the laws ask it for everything they need. The core package names no
  schema and no rule of its own. So an adapter outside this repository
  proves itself against its own tables.

  A population is a struct of the module that implements this behaviour.
  So a law that gets one reaches the module through the struct and carries
  no second argument. `module/1` is that step.
  """

  @typedoc "A population: a struct of the module that implements this behaviour."
  @type t :: struct()

  @typedoc "What a grant sits on, in the terms the world keeps it in."
  @type grantable :: term()

  @doc "Every protected schema the properties scope over."
  @callback schemas() :: [module()]

  @doc "The schema the shape cases fill with rows and scope over. It is one of `schemas/0`."
  @callback scope_schema() :: module()

  @doc "The operations the rule knows."
  @callback operations() :: [atom()]

  @doc "The exemption every write of a population declares through the seam."
  @callback exemption() :: term()

  @doc "The object a grant on this thing covers."
  @callback object_of(grantable()) :: Mediate.object()

  @doc "A random population, for the properties."
  @callback generator() :: StreamData.t(t())

  @doc "One subject, one object, one grant: the world the fail-closed and latency cases run over."
  @callback granted() :: t()

  @doc "The same population with the grant taken out, for the case that writes one fact and counts the queries."
  @callback ungranted() :: t()

  @doc "`granted/0` with more objects in the scope schema than the grant covers, for the shape cases."
  @callback scoped() :: t()

  @doc "The subject the fixed worlds grant to, which is a user, and what they grant it on."
  @callback focus(t()) :: {Mediate.subject(), grantable()}

  @doc "Every subject the population knows, one of kind `:privileged` among them."
  @callback subjects(t()) :: [Mediate.subject()]

  @doc "Every object the population holds."
  @callback objects(t()) :: [Mediate.object()]

  @doc """
  Every attribute value the population holds that a rule reads: the
  clearances, the roles, the expiries, and whatever else a fact column
  carries. The list holds nothing a decision event carries of its own,
  such as a subject kind. A law asserts that no decision event carries one
  of these values. So a value here that is also a subject id, an object
  id, or a verdict fails that law for the wrong reason.
  """
  @callback facts(t()) :: [term()]

  @doc "The rule: what the population says about one subject, operation, and object."
  @callback allowed?(t(), Mediate.subject(), atom(), Mediate.object()) :: boolean()

  @doc "Delete every row of the population through the seam, one row at a time, so the seam records each."
  @callback clear(module()) :: :ok

  @doc "Write the population through the seam."
  @callback insert(module(), t()) :: :ok

  @doc "Take the subject's grant away, through the seam, and answer the population it leaves."
  @callback revoke(module(), t(), Mediate.subject(), grantable()) :: t()

  @doc """
  Write one grant to the subject on the grantable through the seam and
  nothing else, with the attributes given, and answer the population it
  leaves. The laws set `expires_at`, and `mediation`, which is the
  `mediate:` option the write carries and the world's exemption when
  absent. One write, so the case that counts the queries a fact write costs
  can count it.
  """
  @callback insert_grant(module(), t(), Mediate.subject(), grantable(), keyword()) :: t()

  @doc "Change the account fact the rule reads so the subject no longer satisfies it, and answer the population."
  @callback disqualify(module(), t(), Mediate.subject()) :: t()

  @doc """
  Bring the scope schema up to that many rows, none of them granted, after
  the population is in the tables. The population knows which rows it
  holds, and this callback must not read them. A read goes through the
  seam, and an adapter that binds the database itself answers a read with
  no decision with nothing.
  """
  @callback fill(module(), t(), pos_integer()) :: :ok

  @doc "The module behind a population."
  @spec module(t()) :: module()
  def module(%module{}), do: module
end
