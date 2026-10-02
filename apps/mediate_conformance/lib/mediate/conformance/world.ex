defmodule Mediate.Conformance.World do
  @moduledoc """
  The rows an engine case run writes and the rule over them, which the
  caller supplies. `use Mediate.Conformance.EngineCase, world: MyApp.World`
  hands the case a module. That module answers what a world holds, what
  the rule over it says, and how to write one through the mediated repo.
  The properties and the procedures ask it for everything they need. The
  core package names no schema and no rule of its own. So an engine
  outside this repository proves itself against its own tables.

  A world is a struct of the module that implements this behaviour. So a
  procedure that gets one reaches the module through the struct and
  carries no second argument. `module/1` is that step.
  """

  @typedoc "A world: a struct of the module that implements this behaviour."
  @type t :: struct()

  @typedoc "What a grant sits on, in the terms the world keeps it in. `resource/1` turns it into a resource."
  @type target :: term()

  @doc "Every protected schema the properties filter over."
  @callback protected_schemas() :: [module()]

  @doc "The schema the budget tests fill with rows and filter over. It is one of `protected_schemas/0`."
  @callback budget_schema() :: module()

  @doc "The actions the rule knows."
  @callback actions() :: [atom()]

  @doc "The exemption every write of a world declares to the mediated repo, as its `authorized_by:` value."
  @callback exemption() :: term()

  @doc "The resource a grant on this target covers."
  @callback resource(target()) :: Mediate.resource()

  @doc "A random world, for the properties."
  @callback generator() :: StreamData.t(t())

  @doc "One subject, one resource, one grant: the world the fail-closed and latency procedures run over."
  @callback granted() :: t()

  @doc "`granted/0` with the grant taken out, for the procedure that writes one grant and counts the queries."
  @callback ungranted() :: t()

  @doc "`granted/0` with more resources in the budget schema than the grant covers, for the budget tests."
  @callback one_grant_among_many() :: t()

  @doc "The subject the fixed worlds grant to, which is a user, and the target they grant it on."
  @callback grantee(t()) :: {Mediate.subject(), target()}

  @doc "Every subject the world knows, one of kind `:privileged` among them."
  @callback subjects(t()) :: [Mediate.subject()]

  @doc "Every resource the world holds."
  @callback resources(t()) :: [Mediate.resource()]

  @doc """
  Every fact value the world holds that a rule reads: the clearances, the
  roles, the expiries, and whatever else a fact column carries. The list
  holds nothing a decision event carries of its own, such as a subject
  kind. A requirement asserts that no decision event carries one of these
  values. So a value here that is also a subject id, a resource id, or an
  effect fails that requirement for the wrong reason.
  """
  @callback fact_values(t()) :: [term()]

  @doc "The rule: what the world says about one subject, action, and resource."
  @callback allows?(t(), Mediate.subject(), atom(), Mediate.resource()) :: boolean()

  @doc "Delete every row of the world through the mediated repo, one row at a time, so it records each."
  @callback delete(module()) :: :ok

  @doc "Write the world through the mediated repo."
  @callback write(module(), t()) :: :ok

  @doc "Take the subject's grant on the target away, through the mediated repo, and answer the world it leaves."
  @callback revoke(module(), t(), Mediate.subject(), target()) :: t()

  @doc """
  Write one grant to the subject on the target through the mediated repo
  and nothing else, with the options given, and answer the world it
  leaves. The procedures set `expires_at:`, and `authorized_by:`, which
  the write carries and which is the world's exemption when absent. One
  write, so the budget test of a grant write can count it.
  """
  @callback grant(module(), t(), Mediate.subject(), target(), keyword()) :: t()

  @doc "Change the account fact the rule reads so the subject no longer satisfies it, and answer the world."
  @callback disqualify(module(), t(), Mediate.subject()) :: t()

  @doc """
  Bring the budget schema up to that many rows, none of them granted,
  after the world is in the tables. The world knows which rows it holds,
  and this callback must not read them. A read goes through the mediated
  repo, and an engine that binds the database itself answers a read with
  no decision with nothing.
  """
  @callback fill(module(), t(), pos_integer()) :: :ok

  @doc "The module behind a world."
  @spec module(t()) :: module()
  def module(%module{}), do: module
end
