defmodule Mediate.Domain.ConfigSchema do
  @moduledoc false
  # The NimbleOptions schema behind `Mediate.Config`, in its own module so
  # the config's moduledoc can render it. The field docs here say what each
  # field means. `Mediate.Config` builds the struct from what this validates.

  @schema NimbleOptions.new!(
            engine: [
              type: {:or, [:atom, {:tuple, [:atom, :keyword_list]}]},
              required: true,
              doc: "The module implementing `Mediate.Engine`, bare or with its options."
            ],
            clock: [
              type: {:fun, 0},
              doc: "A zero-arity function that answers the current time in UTC. `&DateTime.utc_now/0` when absent."
            ],
            caps: [
              type: :keyword_list,
              default: [policy_text_bytes: 65_536],
              keys: [
                policy_text_bytes: [type: :pos_integer, default: 65_536, doc: "Policy text kept by value."]
              ],
              doc: "The caps on what a record carries by value."
            ]
          )

  @doc false
  @spec schema() :: NimbleOptions.t()
  def schema, do: @schema
end
