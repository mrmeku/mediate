defmodule Mediate.Conformance.Law do
  @moduledoc """
  The law table of `docs/conformance.md` §2 as data. Each row has an id, a
  sentence, and the controls it answers. `Mediate.Conformance.AdapterCase`
  names each test from a row here. The freeze test in `mediate` holds this
  table to the document row for row, so a change to one needs a commit
  that changes both.

  The bodies are in `Mediate.Conformance.AdapterCase.Laws` and its modules.
  """

  @laws [
    {"ac2-01",
     "A single-row write of an account through the seam emits one change event with the actor, the target, " <>
       "and the clearance before and after", ["AC-2", "AC-2(4)"]},
    {"ac2-02",
     "By the configured clock and not the database's, a grant that expires one second later allows and one " <>
       "that expired one second earlier denies", ["AC-2(2)", "AC-2(3)"]},
    {"ac2-03",
     "When an account fact no longer satisfies the rule, the next check denies the subject with no other " <>
       "change", ["AC-2(3)", "PS-5"]},
    {"ac2-04",
     "Review answers every subject with exactly the objects check allows, and emits one decision per " <>
       "subject and one for the reviewer under one operation id", ["AC-2(7)", "AC-6(7)"]},
    {"ac2-05",
     "After a revocation the next check denies, and the test prints the latency from revocation to denial " <>
       "and never asserts it", ["AC-2(13)", "PS-4"]},
    {"ac3-01", "check agrees with the world's own rule for every subject, operation, and object drawn", ["AC-3"]},
    {"ac3-02",
     "The seam denies an ungranted object, an unknown operation, and an unknown subject, and denies an " <>
       "unknown subject kind before it calls the adapter", ["AC-3"]},
    {"ac3-03",
     "scope returns exactly the rows check allows for every protected schema, and a denied scope admits no " <>
       "row", ["AC-3"]},
    {"ac3-04", "scope over a thousand rows is one decision and one query beyond setup", ["AC-3"]},
    {"ac3-05",
     "An unreachable engine denies every call and emits one decision event per call that carries the " <>
       "exception", ["AC-3"]},
    {"ac6-01",
     "check allows the user that holds a grant and denies the privileged subject of the same account on " <>
       "the same object", ["AC-6(2)"]},
    {"au2-01",
     "Every authorize and check emits exactly one decision event with subject, kind, operation, object, " <>
       "verdict, reason, version, operation id, and time", ["AU-2", "AC-6(9)"]},
    {"au2-02", "A denial's decision event carries the reason for it", ["AU-2"]},
    {"au2-03", "scope and review emit decisions with a scoped verdict", ["AU-2"]},
    {"au3-01", "No decision event carries a value the rule reads from the world", ["AU-3"]},
    {"au3-02",
     "A change event carries operation, kind, target, actor, time, operation id, and the old and new value " <>
       "of every fact column that changed", ["AU-3"]},
    {"au3-03", "An access event carries object type, ids, decision id, subject, operation id, and time", ["AU-3"]},
    {"au3-04",
     "The decision, change, and access events of one operation each carry its operation id and its " <>
       "decision id", ["AU-3(1)"]},
    {"au12-01", "A single-row write to an audited schema emits its change event inside the write's transaction",
     ["AU-12", "AC-2(4)"]},
    {"au12-02", "A bulk write to an audited schema raises and changes nothing", ["AU-12"]},
    {"au12-03", "A write that goes around the seam emits nothing", ["AU-12"]},
    {"au12-04", "A write the database refuses leaves no row and no event", ["AU-12"]},
    {"au12-05", "The repo refuses an unmediated read or write of a protected schema", ["AU-12"]},
    {"au12-06",
     "Every mediated read of a protected schema emits one access event, and a read under an exemption " <>
       "emits none", ["AU-12"]},
    {"cm3-01",
     "When the adapter publishes a version, it emits its version event, and the version names its author " <>
       "and its approval", ["CM-3", "CM-5"]},
    {"cm3-02",
     "A decision reports the version in force when the adapter took it, before and after the adapter " <>
       "publishes a new version", ["CM-3(2)"]},
    {"cm3-03",
     "A tightened rule is a policy version that names its artifact as content or as a pointer, and denies " <>
       "the reader it excludes", ["CM-5(1)"]},
    {"cm3-04",
     "After the adapter publishes a tightened rule, check denies the reader it excludes, and the test " <>
       "prints the propagation latency and never asserts it", ["CM-3(2)"]}
  ]

  @enforce_keys [:id, :sentence, :controls]
  defstruct @enforce_keys

  @type t :: %__MODULE__{id: String.t(), sentence: String.t(), controls: [String.t()]}

  @doc "Every law, in the order of the document."
  @spec all() :: [t()]
  def all,
    do: Enum.map(@laws, fn {id, sentence, controls} -> %__MODULE__{id: id, sentence: sentence, controls: controls} end)

  @doc "The law ids, in the order of the document."
  @spec ids() :: [String.t()]
  def ids, do: Enum.map(@laws, &elem(&1, 0))

  @doc "The law with this id. Raises for an id the table does not hold."
  @spec fetch!(String.t()) :: t()
  def fetch!(id) when is_binary(id) do
    Enum.find(all(), &(&1.id == id)) || raise ArgumentError, "no law #{id} in Mediate.Conformance.Law"
  end

  @doc "The test name of a law, its id and its sentence."
  @spec name(String.t()) :: String.t()
  def name(id) when is_binary(id) do
    law = fetch!(id)
    "#{law.id} #{law.sentence}"
  end
end
