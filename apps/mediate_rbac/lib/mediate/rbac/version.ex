defmodule Mediate.Rbac.Version do
  @moduledoc """
  The policy version of roles in code. It is the `version:` the policy
  module gave, or the text hash. The policy's text lists each module a
  rule lives in, with the digest of its bytecode, and the role table. So a
  change to a rule is a new version whether or not anyone said so. The
  release carries the text by value when under the configured cap, and the
  module list as its location otherwise. The events document under "Policy
  release" has the event and the cap.

  `Mediate.Rbac.release/0` builds the release and publishes it, one event
  per call. It stores nothing, so the consumer that keeps a record of
  deployments handles that event.
  """

  alias Mediate.Config
  alias Mediate.PolicyRelease
  alias Mediate.Rbac.Policy

  @doc "The policy version a verdict names: the `version:` option, or the text hash."
  @spec policy_version(Policy.t()) :: String.t()
  def policy_version(policy) when is_atom(policy), do: Policy.options(policy)[:version] || text_hash(policy)

  @doc "The sha256 of `text/1`, in lower-case hex."
  @spec text_hash(Policy.t()) :: String.t()
  def text_hash(policy) when is_atom(policy), do: Base.encode16(:crypto.hash(:sha256, text(policy)), case: :lower)

  @doc "The policy's text: each module with the digest of its bytecode, then the role table."
  @spec text(Policy.t()) :: String.t()
  def text(policy) when is_atom(policy) do
    modules =
      Enum.map_join(Policy.modules(policy), "", fn module ->
        "  #{inspect(module)}: #{Base.encode16(module.module_info(:md5), case: :lower)}\n"
      end)

    roles =
      Enum.map_join(Policy.role_table(policy), "", fn {name, actions} -> "  #{name}: #{Enum.join(actions, ", ")}\n" end)

    "modules:\n" <> modules <> "roles:\n" <> roles
  end

  @doc "The release of `engine` as the event carries it, with the text by value when under the cap."
  @spec release(module(), Policy.t(), Config.t(), DateTime.t()) :: PolicyRelease.t()
  def release(engine, policy, %Config{caps: caps}, %DateTime{} = released_at) when is_atom(engine) and is_atom(policy) do
    options = Policy.options(policy)
    text = text(policy)
    under_cap? = byte_size(text) <= caps[:policy_text_bytes]

    %PolicyRelease{
      engine: engine,
      policy_version: policy_version(policy),
      text_hash: text_hash(policy),
      text: if(under_cap?, do: text),
      text_location: if(under_cap?, do: nil, else: "modules " <> Enum.map_join(Policy.modules(policy), ", ", &inspect/1)),
      author: options[:author],
      approval: options[:approval],
      released_at: released_at
    }
  end
end
