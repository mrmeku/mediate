# Naming

*Which word names each thing in the API, and why that word? For anyone who adds or renames a module, function, field, atom, or event key.*

This document is the ledger. A name in the code is a name in a table below, and a new thing gets its row here in the same commit. Each row carries the alternative it rejected, as `docs/design.md` does for a shape. The moduledocs say what each thing does.

## How a name is chosen

The rules, in the order they apply.

1. **One word per thing, and one thing per word.** A word in the ledger means one thing in every module, struct, event, and document. A second word for the same thing is the drift this ledger exists to stop.
2. **The standard's word when the standards and the engines agree, and the engines' word when they split.** NIST SP 800-162, XACML, Cerbos, and OpenFGA all say subject, so the API says subject. Resource is XACML's word and every engine's, so it wins over 800-162's object. Action is XACML's word and every engine's, so it wins over 800-162's operation. Context is what OpenFGA, Absinthe, and Plug say, so it wins over both standards' environment, which an Elixir reader hears as `Mix.env`. Each row gives the standard's word beside the chosen one, so an assessor can map the API to the control. An acronym is not a name: the engine is the policy decision point and the mediated repo is the policy enforcement point, and the ledger says so once.
3. **A closed list is a kind, and an open list is a type.** A subject kind and an identity kind are lists this library fixes. A resource type is a list the application extends. The word says whether a value can be added.
4. **A payload key reads alone.** No bare `type`, `kind`, `id`, or `at` in an event. A classification carries its noun, an id carries what it identifies, and a moment carries what happened then.
5. **A struct field and its event key are one name.** The `id` of a struct is `decision_id` in an event, because the event has no other id for it to be confused with.
6. **`reason` is an atom from one fixed list.** Free text is `justification` on an exemption and `message` on an exception.
7. **A policy is the versioned whole, and a rule is one line of it.** A reason says which rule spoke. A version says which policy was in force.
8. **An engine callback has the public function's name.** The library adds the context and the engine's options as arguments and changes nothing else, so an engine author learns four words, not eight.
9. **A predicate ends in `?` and shares its verb's root.** `authorized?` is the boolean twin of `authorize`.
10. **A moment is named for what happened.** `decided_at`, `written_at`, `read_at`, `released_at`. The one exception is `now`, the clock stamp the engine reads from the context, because a rule says `context.now` and means the present.
11. **The library's own writes run as a subject.** It is a service, and its id is the package name, so an event under an exemption names who acted in the same shape as every other event.
12. **A name teaches from the call site.** `Mediate.authorize(subject, :read, {:document, id})` and `Repo.get(Document, id, authorized_by: decision)` are the sentences a reader meets first, and every other name follows from the words in them.

## Where the rules came from

Seven independent namings of this API, from a description of what each thing means and with no sight of the code, reached most of these names and all of these rules without being asked for them. Each naming took one lens: the assessor, the Elixir idiom, the spoken sentence, the well-known engines, the audit consumer, the smallest vocabulary, and the newcomer. Where the lenses agreed, the ledger takes their word. Where they split, the ledger picks, and the row names the rival. The design entry on vocabulary in `docs/design.md` cites this document.

## The request

| Name | Shape | Standard's word | Rejected | Why |
|---|---|---|---|---|
| `subject` | `{kind, id}` | subject (800-162, XACML) | `actor`, `principal` | both standards say it, and the assessor reads AC-3 |
| `subject_kind` | `:user`, `:service`, `:privileged` | account type (AC-2) | `subject_type` | a list the library fixes, so kind |
| `:user` | a human | user (800-53) | `:person` | the identity kinds say `:account`, so `user` collides with nothing |
| `:service` | software acting alone | non-person entity (800-53, 800-63) | `:non_person_entity` | the standard's term is a phrase, and service account is what engineers say |
| `:privileged` | a human with elevated rights | privileged user (AC-6) | `:admin` | admin is an application role, and this is a classification |
| `resource` | `{type, id}` | resource (XACML), object (800-162) | `object`, `target` | XACML and every engine say resource, and object is a word for any value in a program |
| `resource_type` | the atom a schema declares | | `object_type` | follows `resource` |
| `{type, :all}` | the resource of a type-level decision | | `{type, nil}` | `:all` reads as intent in a log, and `nil` reads as a missing id |
| `action` | an application atom, `:read` or `:approve` | action (XACML), operation (800-162) | `operation` | every engine says action, and it frees `operation` for what a write did |
| `context` | a map of the caller's facts, with `now` stamped | environment (800-162, XACML) | `environment`, `env` | OpenFGA, Absinthe, and Plug say context, and an Elixir reader hears `env` as `Mix.env` |
| `now` | the clock stamp in `context` | current-dateTime (XACML) | `current_time`, `asked_at` | a rule says `context.now` and means the present |

The two-tuple for a subject and a resource stays. A struct was the alternative, and a tuple is what a rule matches on and what an event prints.

## The four calls

| Name | Returns | Rejected | Why |
|---|---|---|---|
| `Mediate.authorize/4` | `{:ok, %Decision{}}` or `{:error, %Error{}}` | `check`, `decide` | AC-3 says enforce approved authorizations, and Bodyguard, Pundit, and Oso say authorize |
| `Mediate.authorized?/4` | `true` or `false`, and fails closed | `allowed?`, `permitted?`, `can?` | the boolean twin shares its verb's root, and the lenses split four ways |
| `Mediate.filter/4` | `{dynamic, %Decision{}}` | `scope`, `restrict` | a filter can only remove rows, which is the one promise the call makes, and Phoenix generates `current_scope` |
| `Mediate.review/5` | a map from each subject to its filter result | `review_access` | AC-2(7) and AC-6(7) say review |

The options are `context:` and `correlation_id:`, the same words as the fields they fill. `env:` and `operation_id:` were the alternative, and a key that abbreviates its field is a second name for it.

The module the four calls live on, and its other functions.

| Name | Is | Rejected | Why |
|---|---|---|---|
| `Mediate` | the module an application calls, and the one word it learns first | `Authz`, `Mediate.Authorization` | the library's name, and a second segment repeats it |
| `Mediate.subject_kinds/0` | `:user`, `:service`, `:privileged` | `kinds/0`, `subject_types/0` | a closed list is a kind, by rule 3 |
| `Mediate.event/0` | `[:mediate, :decision]` | `event_name/0`, `telemetry_event/0` | a module that publishes one event answers its name under one word, and `IdentityWrite`, `ResourceRead`, and `PolicyRelease` do the same |
| `Mediate.options_schema/0` | the schema of the four calls' options | `schema/0` | the engine callback's name for a schema |

## The engine

| Name | Is | Rejected | Why |
|---|---|---|---|
| `Mediate.Engine` | the behaviour, which is 800-162's policy decision point | `Adapter`, `Backend`, `Decider` | an application's config block already carries Ecto's `adapter:`, and adapter says how a module plugs in where engine says what it does |

Cerbos and OPA call themselves policy engines, and Oban calls its pluggable core an engine. The callbacks, one per public function and two for the engine's own state.

| Callback | Returns | Rejected | Why |
|---|---|---|---|
| `authorize/5` | `{:ok, %Verdict{}}` or `{:error, %Error{}}` | `decide`, `check` | the public function's name, by rule 8 |
| `filter/5` | `{:ok, {dynamic, %Verdict{}}}` or `{:error, %Error{}}` | `scope`, `plan` | the public function's name |
| `around_query/3` | what the function returns | `with_session`, `around_repo_call` | says when it runs and what it wraps |
| `options_schema/0` | a `NimbleOptions` schema | `config_schema` | the NimbleOptions convention |
| `filter_limit/0` | `pos_integer` or `:infinity` | `scope_cap`, `:unlimited`, `:none` | names what is limited, and `:infinity` is the Elixir word for no limit |
| `sync/0` | `:ok`, `:stateless`, or `{:error, %Error{}}` | `settle`, `:none` | sync is what everyone calls bringing two stores into step, and `:stateless` says why nothing happened |

## The structs

| Struct | Fields | Rejected | Why |
|---|---|---|---|
| `Mediate.Verdict` | `effect`, `reason`, `policy_version`, `meta` | `Answer`, `Engine.Result` | the engine's finding before the library records it, as a jury's verdict precedes the court's decision |
| `Mediate.Decision` | `id`, `subject`, `resource`, `action`, `effect`, `reason`, `engine`, `policy_version`, `correlation_id`, `decided_at` | `AccessDecision`, `Receipt` | 800-162 and XACML call the output an access decision, and a denied decision is the ordinary case |
| `Mediate.Exemption` | `source`, `caller`, `justification`, `declared_by` | `Waiver`, `Bypass` | an assessor knows an exemption is named and justified, and bypass reads as a finding |
| `Mediate.PolicyRelease` | `engine`, `policy_version`, `text`, `text_hash`, `text_location`, `author`, `approval`, `released_at` | `PolicyVersion` | a struct named `PolicyVersion` collides with the string field of that name |
| `Mediate.Error` | `reason`, `message` | `AuthorizationError`, `detail` | one exception, and `message` is what an Elixir exception carries |
| `Mediate.Config` | `engine`, `clock`, `caps` | `Configuration` | the word every Elixir library uses |
| `Mediate.Id` | a UUID string | `uuid` | id names the role, and uuid names the format |

The fields, one by one.

| Field | On | Values | Rejected | Why |
|---|---|---|---|---|
| `effect` | Verdict, Decision | `:allow`, `:deny`, and `:filter` on a Decision | `verdict`, `outcome`, `decision` | XACML and Cerbos call the allow-or-deny the effect, which leaves verdict and decision for the structs |
| `:allow`, `:deny` | `effect` | | `:permit`, `:allowed` | Cerbos, OpenFGA, Casbin, and IAM say allow |
| `:filter` | `effect` on a Decision from `filter` or `review` | | `:scoped`, `:conditional` | named for the call that produced it, by rule 1 |
| `reason` | Verdict, Decision, Error | the reasons below | `basis`, `code` | the Elixir word for a tagged cause |
| `policy_version` | Verdict, Decision, PolicyRelease | string or `nil` | `version`, `rules_version` | Cerbos says policyVersion, and one name on all three structs lets a reviewer join them by equality |
| `meta` | Verdict | a map | `metadata`, `notes` | short, and not the telemetry word |
| `engine` | Decision, PolicyRelease | module | `adapter`, `decider` | the same word as the behaviour |
| `correlation_id` | Decision | a `Mediate.Id` | `operation_id`, `request_id`, `trace_id` | AU-6(3) speaks of correlating records, request is too narrow for a job, and trace promises OpenTelemetry |
| `decided_at` | Decision | `DateTime` | `at`, `time` | rule 10 |
| `source` | Exemption | a schema, a table name, or `nil` | `on`, `root` | Ecto's word for the root source, with Ecto's meaning |
| `justification` | Exemption | string | `reason` | rule 6 |
| `declared_by` | Exemption | `:caller` or `:library` | `kind`, `:declared`, `:application` | reads as a sentence with either value, and `:caller` names the field that holds the module |
| `text`, `text_hash`, `text_location` | PolicyRelease | string or `nil` | `content`, `pointer` | one root for the three fields about the policy text |
| `released_at` | PolicyRelease | `DateTime` | `at`, `deployed_at` | rule 10 |
| `policy_text_bytes` | `caps` on Config | integer | `policy_content_bytes` | follows `text` |

The functions on the structs.

| Function | Answers | Rejected | Why |
|---|---|---|---|
| `Mediate.Config.new/1`, and `new/1` with the mark | the struct from a keyword list, as a tuple, and raising | `from_options/1`, `validate/1` | the Elixir shape for a constructor |
| `boot/1` with the mark, on `Mediate.Config` | validates once at boot and keeps the struct for `resolve/0` | `install/1`, `init/1` | boot is the moment it runs, and the mark says it raises |
| `Mediate.Config.resolve/0` | the boot struct under the process's overrides | `current/0`, `get/0` | resolve says an override may win |
| `Mediate.Config.to_keyword/1`, `engine/1` | the keyword list `new/1` accepts, and the engine module with its options | `to_options/1`, `adapter/1` | Elixir's `to_` convention, and engine by rule 1 |
| `Decision.effects/0`, `Verdict.reasons/0`, `Error.reasons/0` | each closed list, in the order its type lists it | `all/0`, `values/0` | the plural of the field |
| `Error.denied/5`, `invalid/2` | the error a denial makes, and the error a value at an edge makes | `forbidden/5`, `validation_error/2` | each says the reason it carries |
| `Id.new/0` | a fresh identifier | `generate/0` | the Elixir constructor |
| `IdentityWrite.publish/5`, `ResourceRead.publish/6`, `PolicyRelease.publish/1` | one event each | `emit`, `release/1` | the core's verb for emitting any event, which the roles-in-code section argues |
| `IdentityWrite.event/0`, `ResourceRead.event/0`, `PolicyRelease.event/0` | the event name a consumer attaches to | `event_name/0`, `topic/0` | one word, as `Mediate.event/0` |
| `IdentityWrite.library/0` | `{:service, "mediate"}` | `service/0`, `self/0` | the library is who acts, by rule 11 |

## The reasons

One grammatical form: the noun, then what it did. `rule_denied` reads as a sentence, and so does every other row.

| Reason | Means | Rejected | Why |
|---|---|---|---|
| `:rule_allowed` | a rule allowed it | `:allowed`, `:explicit_allow` | the form |
| `:no_rule_matched` | no rule named the request, the default | `:deny_by_default`, `:not_applicable` | XACML's NotApplicable said as what happened |
| `:rule_denied` | a rule denied it | `:explicit_deny` | the form |
| `:engine_failed` | the engine was unreachable or raised | `:engine_unreachable`, `:indeterminate` | covers both, where unreachable covers one |
| `:fact_missing` | a fact the rule needs was absent | `:missing_fact`, `:missing_attribute` | the form, and fact is the schema's word |
| `:action_unknown` | the rules do not know this action | `:unknown_operation` | follows `action` |
| `:subject_kind_unknown` | the kind is not one of the three | `:unknown_subject_kind` | follows `subject_kind` |
| `:decision_missing` | a mediated call carried no decision and no exemption | `:unmediated`, `:authorization_missing` | names what the call lacked, in the form |
| `:unsupported` | what an engine or a configuration cannot do, on an error alone | `:not_implemented`, `:unavailable` | names the capability, and a verdict never carries it |
| `:invalid` | a value at an edge that did not validate, on an error alone | `:validation_failed`, `:bad_option` | one word for every edge, and the message names which |

## The mediated repo

The concept is the mediated repo, and the module is `Mediate.Repo`, which an application uses after `use Ecto.Repo`. Seam was the alternative in prose, and a second word for the repo is drift. Enforcer, Gate, and EnforcedRepo were the alternatives for the module, and an Elixir developer uses a Repo. The mediated repo is 800-162's policy enforcement point.

| Option | On | Values | Rejected | Why |
|---|---|---|---|---|
| `authorized_by:` | every mediated call | a `%Decision{}`, `{:exempt, justification}`, or `{:exempt, :library}` | `mediate:`, `decision:`, `authorization:` | `decision: exemption` misnames its value, authorization reads as the ATO to a FedRAMP reader, and `authorized_by: {:exempt, "report"}` is a true sentence |
| `role:` | `use Mediate.Repo` | `:app`, the application's repo, or `:owner`, the library's own channel | `connect_as:`, `channel:` | the Postgres word, and the cluster's option |

The mediated repo turns the exempt tuple into an `Exemption` that records the caller, so the caller writes the justification and never the struct.

The modules behind the repo, under `Mediate`, which no application names.

| Module | Does | Rejected | Why |
|---|---|---|---|
| `Infrastructure.Enforcement` | judges each repo call, runs it, and publishes its event | `Seam`, `Gate` | the mediated repo is the enforcement point, so the module that enforces says so |
| `Mediate.IdentityWrite` | publishes the identity write event | `Change` | the event's name, by rule 1 |
| `Mediate.ResourceRead` | publishes the resource read event | `Access` | the event's name |
| `Mediation.covered` | the schemas a decision covers, from the root's `covers` | `carried` | follows `covers` |

The library's own writes run as `{:service, "mediate"}`, which `Mediate.IdentityWrite.library/0` answers, by rule 11.

## The schema declarations

`Mediate.Schema` provides them, used after `use Ecto.Schema`.

| Macro | Declares | Rejected | Why |
|---|---|---|---|
| `resource_type :document` | the resource type, which protects the schema | `object_type`, `protect` | names what it sets |
| `covers [:comments]` | the associations a parent's decision covers | `carries` | a decision covers an association, and carries says the association moves |
| `identity :account` | that a row is an identity, from `:account`, `:group`, `:role`, `:other` | `audited`, `:user`, `:entity` | identity is what the identity store holds, and account is AC-2's word |
| `fact :clearance, about: :subject` | a column a rule may read, about `:subject`, `:resource`, or `:grant` | `attribute`, `kind:` | a fact is what a rule reads, and about says whose |
| `grant subject: :user_id, resource: :document_id` | that a row is itself a grant | `relationship`, `privilege` | a grant is what the row does, and relationship is Zanzibar's shape |

What the declarations record, and the reads over a module.

| Name | Is | Rejected | Why |
|---|---|---|---|
| `Mediate.Schema` | the module the declarations come from, used after `use Ecto.Schema` | `Mediate.Declarations`, `Protected` | Ecto's word, one segment deeper |
| `Mediate.Schema.Fact` | one fact column: `column`, `about`, `subject`, `resource`, `element` | `Attribute`, `FactColumn` | the declaration's name, and column is what it records |
| `Mediate.Schema.Grant` | one grant declaration: `subject`, `resource`, `attributes` | `Relationship` | the declaration's name |
| `Schema.resource_type_of/1`, `covers_of/1`, `identity_of/1`, `facts_of/1`, `grant_of/1` | what a module declared, one read per declaration, with `nil` or `[]` for none | `get_resource_type/1`, `resource_type/1` | `of` says it reads a module, and the bare name is the macro |
| `Schema.fact_columns/1` | the names of the fact columns | `fact_names/1` | a fact is a column |
| `Schema.id_of/1` | a row's primary key, one value or a map of several | `primary_key/1`, `pk/1` | follows the `_of` reads |
| `Schema.declares?/1`, `identity?/1`, `fact_schema?/1` | whether a module used the declarations, declares an identity, and declares a fact or a grant | `protected?/1`, `audited?/1`, `has_facts?/1` | predicates by rule 9, each on the declaration's word |

## The events

The atoms after `:mediate` name the record the event carries. Every key is a struct field's name or carries its noun, by rules 4 and 5.

| Event | Fires | Rejected |
|---|---|---|
| `[:mediate, :decision]` | after every one of the four calls, even when the call raised | `[:mediate, :authorize, :stop]` |
| `[:mediate, :identity, :write]` | inside the transaction of a single-row write to an identity schema | `[:mediate, :change]`, `[:mediate, :account_management]` |
| `[:mediate, :resource, :read]` | after a mediated read of a protected schema returns | `[:mediate, :access]` |
| `[:mediate, :policy, :release]` | when an engine deploys a policy version | `[:mediate, <engine>, :policy_version]` |

The keys, by event.

| Key | On | Value | Rejected | Why |
|---|---|---|---|---|
| `subject`, `subject_kind`, `action`, `resource`, `effect`, `reason`, `engine`, `policy_version`, `context` | decision | the decision's fields, and the context the call carried | `decider`, `env`, `version` | rule 5 |
| `decision_id`, `correlation_id` | every event but the release | the decision's `id`, and its correlation | `id`, `decision` | rule 4 and rule 5 |
| `decided_at` | decision | `DateTime` | `at`, `time` | rule 10 |
| `exception` | decision | what the call raised, or `nil` | `error` | the Elixir word for what a raise carries, and error is the struct |
| `duration_microseconds` | decision, as the measurement | integer | `duration` | a unit in the key survives a reader who never saw the code |
| `operation` | identity write | `:create`, `:update`, `:delete` | `action`, `verb` | action is what a subject asks for, and operation is what the repo did |
| `identity_kind` | identity write | `:account`, `:group`, `:role`, `:other` | `kind`, `identity` | carries its noun by rule 4, and a bare identity reads as the row |
| `changes` | identity write | the map of changed columns | `diff`, `delta` | Ecto's word |
| `written_at`, `read_at` | identity write, resource read | `DateTime` | `at`, `time` | rule 10 |
| `schema` | identity write, resource read | the schema module | `source`, `target` | Ecto's word, and source is the exemption's field |
| `repo`, `repo_function` | resource read | the repo module, and `{name, arity}` | `call`, `function` | the function carries its noun, by rule 4 |
| `resource_type` | resource read | the declared resource type | `type` | rule 4 |
| `cardinality` | resource read | `:one` or `:many` | `shape`, `arity` | Ecto's own word for one or many |
| `result_shape` | resource read | `:rows`, `:scalar`, or `:stream` | `shape`, `kind` | says what the function answered, with its noun |
| `primary_keys`, `count` | resource read, and count as the measurement | the ids the read returned, and how many | `ids`, `rows` | each reads alone |
| `release` | policy release | a `Mediate.PolicyRelease` | `policy_release`, `version` | the event's own word |

Under an exemption the subject of an identity write is `{:service, "mediate"}`, by rule 11.

## The test helpers

`Mediate.Test` is what a test of an application or an engine calls.

| Function | Does | Rejected | Why |
|---|---|---|---|
| `with_config/1,2` | puts a configuration override in the process | `set_config` | the Elixir shape for a scoped override |
| `sync/0` | calls the engine's `sync/0`, or answers `:stateless` | `settle` | the callback's name, by rule 1 |
| `writes/1` | runs a function and collects its identity write events | `changes` | the event's name |
| `reads/1` | runs a function and collects its resource read events | `accesses` | the event's name |
| `queries/2` | runs a function and collects the queries the repo ran | | |

| Name | Is | Rejected | Why |
|---|---|---|---|
| `Mediate.Test` | the module the helpers live on | `Mediate.TestHelpers`, `Mediate.Testing` | ExUnit's word, and the shortest |
| `Test.poll/2`, `poll_interval/0` | calls until truthy or the timeout, and the interval between calls | `wait_until/2`, `eventually/2`, `tick/0` | the one place the suite sleeps, named for what it does |
| `Mediate.Test.Fake` | the engine a test binds | `Stub`, `InMemory`, `TestEngine` | fake is the test double with a working implementation |
| `Fake.start_link/0` | an empty rule table | `new_table/0` | OTP's verb |
| `Fake.verdict/1` | the verdict the fake gives with no table bound | `default_verdict/1` | the struct's name |
| `Mediate.Test.Clock` | the clock a test sets | `FrozenTime`, `Time` | the configuration's `clock:` |
| `Clock.set/1` | puts a fixed moment in the process and answers it | `freeze/1`, `travel_to/1` | one verb, and the moment it answers is the one it set |

The fake's rule table has these functions.

| Function | Does | Rejected | Why |
|---|---|---|---|
| `Fake.allow/4`, `revoke/4` | puts one entry in the table, and takes one out | `grant`, `permit` | an entry is what the fake allows, and a grant is what a world holds |
| `Fake.fail/2` | makes every call answer `:engine_failed` until told otherwise | `disconnect`, `break` | says the effect, and leaves disconnect to the outage |
| `Fake.release/2` | releases a policy version on the table and publishes it | `version`, `bump` | the event's name, by rule 1 |
| `Fake.reset/1`, `entries/1` | puts the boot state back, and lists the entries | `clear`, `rules` | the rules are the table itself |

## The conformance kit

`mediate_conformance` is what an engine author runs. Its words follow the core's, and these are its own. Seven independent namings of the kit, by the same method as the API's, reached these names.

| Name | Is | Rejected | Why |
|---|---|---|---|
| `Mediate.Conformance.EngineCase` | the test module an engine runs | `AdapterCase`, `Suite`, `Template` | engine by rule 1, and case is ExUnit's word for a test module |
| `Mediate.Conformance.RepoCase` | the test module a mediated repo runs | `SeamCase` | the same |
| `Mediate.Conformance.Requirement` | one row of a table: `id`, `text`, `controls` | `Law`, `Guarantee` | the assessor's word, and one struct serves both tables |
| `Requirement.all/1`, `ids/1`, `test_name/1`, and the fetch that raises | the rows of one table, `:engine` or `:repo`, and one row by id | one module per table | one struct, two tables |
| `repo-01` to `repo-05` | the ids of the repo table | `E1` to `E5` | reads as the engine ids do, and says which table |
| `Mediate.Conformance.Procedure` and its modules | the bodies, one function per requirement, named by its id | `Laws`, `Bodies` | ISO 17025's word for the steps a test takes |
| `Mediate.Conformance.World` | the behaviour: the rows a run writes and the rule over them | `Population`, `Fixture` | the rows and the rule together, which a fixture is not |
| `World.grantee/1` | the subject and target the fixed worlds grant to | `focus` | says what it is |
| `World.target` | what a grant sits on, in the world's own terms | `grantable` | follows grant |
| `World.write/2`, `delete/1`, `grant/5`, `revoke/4`, `disqualify/3`, `fill/3` | the writes through the mediated repo | `insert`, `clear`, `insert_grant` | plain verbs, and grant by rule 1 |
| `World.allows?/4` | the rule | `allowed?` | the world is the subject of the verb |
| `World.fact_values/1` | every value the rule reads | `facts` | a fact is a column, and these are values |
| `World.budget_schema/0`, `one_grant_among_many/0` | what the budget tests fill and filter | `scope_schema`, `scoped` | follows filter, and says what the world holds |
| `Mediate.Conformance.Generators` | the StreamData generators over a world | `Gen`, `Random` | the library's word, unabbreviated |
| `Mediate.Conformance.Mirror` | the behaviour that makes an engine with state of its own agree with the world | `Seed`, `Sync` | seed says once, and sync is the engine callback |
| `Mediate.Conformance.Outage` | the behaviour that makes an engine unreachable | `Seed.outage`, `Chaos` | one thing per module |
| `Mediate.Conformance.Policy` | the behaviour that tightens a rule and restores it | `Versions` | the policy is what changes, by rule 7 |
| `Policy.tighten/0`, `restore/0` | release a stricter version, and put the original back | `publish` | the event is a release |
| `Mediate.Conformance.Specimen` | what the repo case writes | `Rows`, `Fixture` | the rows under test, in the laboratory's word |
| `Specimen.identity_row/0`, `fact_changeset/1`, `authorized_by/0`, `write_around/1`, `protected_row/0`, `read_decision/1` | its callbacks | `row`, `change`, `mediation`, `around`, `protected`, `decision` | each names its noun, and `authorized_by` is the repo option |
| `RepoCase.Tableless` | the protected schema with no table | `Protected` | says why it has no table |
| `RepoCase.assert_mediated/1`, `exports/1`, `run/3` | the case's assertions | `assert_surface`, `swept`, `assert_guarantee` | mediated is the contract, exports is what it sweeps, and run takes an id |
| `Mediate.Conformance.Reference` | this repository's own world, specimen, mirror, and outage | `Fixture` | the reference implementation an engine author reads |
| `engine:`, `setup:`, `mirror:`, `outage:`, `durable:`, `policy:`, `queries_per_call:` | the engine case options | `adapter:`, `sandbox:`, `seed:`, `committed:`, `versions:`, `setup_queries:` | each names the behaviour it takes, and durable says what the repo keeps |
| `conformance` | the context key that carries the case's configuration | `case` | case is ExUnit's word |
| `@tag :durable` | the tag of a test that runs on the durable repo, which `Mediate.Dev.Sandbox` leaves out of the sandbox | `:committed` | names what the repo keeps, as the option does |

## The development tools

`mediate_dev` is what a test run of this repository starts, and no adopter sees it. Its words follow the core's, and these are its own. Seven independent namings of the package, by the same method as the API's, reached these names.

| Name | Is | Rejected | Why |
|---|---|---|---|
| `Mediate.Dev.Cluster` | one Postgres cluster per `mix test` run | `Postgres`, `Enclave` | Postgres's own word for what `initdb` makes |
| `Cluster.start/1`, `stop/1`, `stop_all/1`, `current/0` | starts it, stops one, stops every one at exit, and answers the one started last | `provision`, `info`, `start_for_run` | OTP's verbs, and current says which one |
| `otp_app:`, `repos:`, `migrate:` | the start options | none | Ecto's words |
| `role: :owner`, `role: :app` | which Postgres role a repo connects as | `connect_as:`, `:table_owner` | the owner owns the tables, and the app is the application |
| `database: :sandboxed`, `database: :durable` | which database a repo connects to: one that rolls every test back, one that keeps what a test commits | `:sandbox`, `:committed`, `tier:` | pairs with the `:durable` tag and the durable repo, and both words are adjectives |
| `mediate_owner`, `mediate_app`, `mediate_sandboxed`, `mediate_durable` | the Postgres names of the roles and the databases | `mediate_test`, `mediate_committed` | each carries its atom, so a `psql` prompt reads as the option does |
| `Cluster.database_name/1`, `role_name/1` | the Postgres name of a database atom and a role atom | `database/1`, `role/1` | says it answers a string, not a struct |
| `Cluster.config/3` | the keyword list a repo starts with, for a role and a database | `connection/3`, `connect_opts/3` | Ecto's word, as in `Repo.config/0` |
| the cluster's `psql/3`, with the mark | runs a statement as the superuser | `sql/3` | the program it runs, and the mark says it raises |
| `dir`, `socket_dir`, `data_dir`, `log_file`, `repos`, `supervisor` | the struct | `root`, `log`, `log_path` | each says what kind of path it is, and `log_file` pairs with the server's `config_file` |
| `Mediate.Dev.Sandbox.setup/2` | checks the test out of the sandbox, unless the test is `:durable` | none | the conformance kit's `setup(repo, tags)` fixes it |
| `Mediate.Dev.Cerbos`, `Mediate.Dev.OpenFGA` | the modules that start one server per run | `Fga`, `CerbosSidecar`, `Launcher` | the product's own name, and nothing but the product in it |
| `Cerbos.start/1`, `OpenFGA.start/1` | the run's server, started on the first call and returned on every call after it | `start_shared`, `start_run` with the mark, `provision` | the cluster's verb, and the run is what a test helper means |
| the server module's `start_supervised/1`, with ExUnit's mark | a server of one test's own, through ExUnit's supervisor | `start_link`, `start_for_test` | ExUnit's name for what it does, with ExUnit's mark |
| `current/0` with the mark | the run's server, raising when none was started | `info/0`, and `fetch/0` or `for_run/0` with the mark | the cluster's word, and the mark says it raises |
| `stop/1`, `stop_all/1`, `healthy?/1`, `options_schema/0` | stop one, stop the run's, ask the health endpoint, and the options | `stop_shared`, `up?`, `options/0` | the cluster's verbs, a predicate by rule 9, and the engine callback's name for a schema |
| `policy_dir:`, `dir:`, `watch:`, `timeout:` | the Cerbos options, and `dir:` and `timeout:` the OpenFGA ones | `policies:`, `watch_policies:`, `poll_timeout:` | a directory is named as one, and the rest are plain |
| `http`, `grpc`, `dir`, `policy_dir`, `config_file`, `daemon` | the server structs | `address`, `grpc_address`, `config`, `daemon_pid` | each address is named by its protocol, so neither is the address |
| `Mediate.Dev.Structure.dump/1` | runs the migrations on a cluster of its own and writes the structure file | `SchemaDump.dump`, `Schema.dump`, `Baseline.capture` | Ecto's `mix ecto.dump` writes `structure.sql`, and this is that dump on the run's cluster |
| `otp_app:`, `repo:`, `file:`, `migrations:` | the dump options | `output:`, `to:`, `path:` | the file is what it writes |
| `mix mediate.dump`, `mediate: [dump: [...]]` | the task, and the key it reads from `mix.exs` | `mediate.schema_dump`, `mediate.schema.dump`, `mediate.baseline` | one word, as `mix ecto.dump` is |
| `Mediate.Dev.Package` | builds the tarball of every published package and checks each | `Release` | Hex's word |
| `Package.published/0`, `build/2`, `check/2` | the published packages, their tarballs, and the problems | `inventory`, `assess`, `problems` | check pairs with the task's `--check` |
| `mix mediate.package --check` | the task | `mediate.build`, `mediate.release` | the module's name, and the flag says what more it does |
| `Mediate.Dev.poll/1,2` with the mark | calls until truthy, and raises at the timeout | `poll/2`, `wait_until` | the mark says it raises, which `Mediate.Test.poll/2` does not |
| `Mediate.Dev.Surface` | every public name of an application: `app`, `modules`, `functions`, `fields`, `atoms`, `options`, `events` | `Inventory`, `Api`, `Exports` | the surface is what a package shows, and exports is the repo case's word |
| `Surface.of/1,2`, `to_lines/1`, and `modules:` | the surface of an application or of the modules named, and one line per name | `collect/1`, `print/1`, `dump/1`, `only:` | `of` reads the application, and dump is the structure's word |
| `mix mediate.surface` | the task that prints the surface | `mediate.inventory`, `mediate.api` | the module's name |
| `Mediate.NamingTest` | the core's test that every public name is a row of this ledger | `LedgerTest`, `VocabularyTest` | the document's name |
| `Mediate.Dev.WordsTest` | the test that runs this document's gate over the tree | `BannedWordsTest`, `SynonymTest` | the words in prose are what it holds |
| `Mediate.Dev.LayoutTest` | the test that holds every package to the layers | `StructureTest`, `BoundaryTest`, `LayerTest` | structure is the dump's word, and the layout is what the test reads |
| `@effects`, `@erlang_effects`, `@waivers` | the modules whose calls reach outside the call, and the files the path rule excuses | `@world`, `@exceptions`, `@exempt`, `@ignored` | exemption is the core's word for a declared bypass, and a waiver is what a file gets |
| `Mediate.TestRepos.Sandboxed`, `Durable`, `Owner` | the core's own repos, and `Mediate.Dev.TestRepos` adds `Dump` | `Committed`, `TableOwner`, `DumpOwner` | each names its database or its role, and durable by rule 1 |
| `Mediate.Dev.TestRepos.Migration` | the one migration this package's cluster runs | `TestMigration`, `CreateIssues` | named under the repos it migrates |

One objection the namings raised stays open for a later sweep: `Mediate.Test.poll/2` answering a boolean, which stays because a test asserts on it.

## Roles in code

`mediate_rbac` is the engine whose policy is an Elixir module. Its words follow the core's, and these are its own. Seven independent namings of the package, by the same method as the API's, reached these names.

| Name | Is | Rejected | Why |
|---|---|---|---|
| `mediate_rbac`, `Mediate.Rbac` | the package and the engine | `mediate_roles`, `Mediate.RBAC` | the acronym an assessor greps for, and the prose says roles in code |
| `Mediate.Rbac.Binding` | the policy module and the repo its rules read through, kept at boot beside the configuration | `Wiring`, `Setup`, `Enforcer` | a deployment binds an engine, and this is the rest of that binding |
| `Binding.bind/1`, `override/1,2`, `resolve/0`, `new/1`, `to_keyword/1`, `options_schema/0`, and `bind/1` with the mark | keeps the pair for the VM, puts one in the process, reads it, and the shapes `Mediate.Config` has | `install`, `wire`, `current/0`, `in_effect/0` | the configuration's own verbs, so a reader learns them once |
| `policy`, `repo` | the binding's fields and options | `rules`, `module`, `through` | the policy is the versioned whole, by rule 7, and repo is Ecto's word |
| `Mediate.Rbac.release/0` | builds the bound policy's release and publishes it | `publish/0`, `deploy/0` | the event is a release, by rule 1 |
| `Mediate.Rbac.Policy` | what a policy module uses | `Rules`, `Roles` | the versioned whole, by rule 7 |
| `version:`, `author:`, `approval:` | the `use` options | `policy_version:`, `approved_by:` | inside the policy, version needs no noun, and the other two are the release's fields |
| `role/2` | one row of the role table: the role and the actions it permits | `permit/2`, `allow/2` | the table's noun |
| `resource/2` | a protected schema and, in the block, its rules | `object/2`, `protect/2` | the core's noun for what a decision is about |
| `grant/2,3` | a rule that reads grant rows: the grant schema whose rows hold a role on the protected row | `membership/2`, `relation/2` | the schema declaration's word, by rule 1 |
| `on:`, `role_column:`, `role:`, `through:` | the grant rule's options: the protected column the grant's resource column names, the column that holds the role, a role every row holds, and the hops out to the row the grant names | `references:`, `role_from:`, `as:`, `default_role:` | each says what the value is, and `role:` names a role where `role_column:` names a column |
| `where:` | the capture that narrows one hop | `filter:` | Ecto's word at the place it sits |
| `predicate/2,3` | a rule that runs a function of the subject and the context, which returns a `dynamic` over the row or a boolean | `condition/2,3`, `check/2,3` | a predicate is a function that answers yes or no, and condition is Cerbos's word for its own |
| `actions:` | the actions a predicate rule applies to | `only:`, `for:` | the core's noun, and `only:` says less |
| `Policy.roles/1`, `resources/1`, `actions/1`, `roles_for/2`, `role_table/1`, `modules/1`, `options/1`, `options_schema/0` | the reads of a policy module | `objects/1`, `operations/1`, `permissions/1`, `table/1`, `use_schema/0` | each follows its declaration, and `options_schema/0` is the engine callback's name for a schema |
| `__mediate_policy__/1` with `:roles`, `:resources`, `:options` | the function the policy module answers its declarations with | `__mediate_code__/1`, `__policy__/1` | the core's `__mediate__/1` pattern, with the package's noun |
| `Policy.Role` | one row of the role table: `name`, `actions` | `permissions` | the core's noun, and 800-162 calls a permission the pair of an action and a resource |
| `Policy.Resource` | a protected schema and its rules: `schema`, `rules` | `Object`, `Protected`, `Protection` | follows `resource/2` |
| `Policy.Rule` | one line of a resource block: `name`, `kind`, `grant`, `on`, `role_column`, `role`, `through`, `predicate`, `actions` | `Clause`, `source`, `as`, `only` | a rule is one line, by rule 7, and the reasons `:rule_allowed` and `:rule_denied` name one line |
| `:grant`, `:predicate` | a rule's kind | `:membership`, `:condition` | the macros' names, by rule 1 |
| `Mediate.Rbac.Version` | the policy version of a policy module | `PolicyVersion`, `Release` | the module answers the version, and the release is the core's struct |
| `Mediate.Rbac.Version.policy_version/1`, `text/1`, `text_hash/1`, `release/4` | the identifier a decision carries, the policy as text, its hash, and the `Mediate.PolicyRelease` | `ref/1`, `content/1`, `content_hash/1`, `of/4` | the release's field names, by rule 5 |
| `Mediate.Rbac.Facts` | the check that every column a policy reads is a declared fact | `Coverage`, `FactCoverage`, `DeclaredFacts` | a reader hears coverage as test coverage, and the module is about the facts |
| `Facts.check/1`, `undeclared/1`, `reads/1`, and `check/1` with the mark | ok or the findings, the findings, every read before the declared ones are removed, and the raise | `verify/1`, `violations/1`, `columns/1` | check is the verb a CI step runs, and a finding is what a reviewer records |
| `finding` | one undeclared read: `{schema, column}` or `{:fragment, text}` | `violation`, `undeclared_read` | the reviewer's word, before any judgment of severity |
| `Domain.Rules` | builds and checks each rule a policy declares | `Clauses` | follows `Policy.Rule` |
| `Infrastructure.Plan` | one resource's rules for one subject and action, compiled to `dynamic` expressions: `policy`, `schema`, `action`, `roles`, `grants`, `predicates`, `policy_version` | `Rule`, `Matcher`, `Query` | a rule is one line, and the compiled whole is what a query planner calls a plan |
| `Infrastructure.Decide.one/5` | one query that selects each rule for the row asked about | `Check.one`, `Authorize.one` | the engine decides, and the library authorizes |
| `Infrastructure.Release.publish/1` | builds the bound policy's release and publishes it | `Mediate.Rbac.Version.publish/1`, `Emit.release/1` | the struct's name, and the core's verb for an event |
| `rule`, `matched` | the verdict's `meta`: the rule that allowed or denied, and every rule that held, as names | `clause`, `deciding_clause`, `decided_by`, `held` | the core's keys |
| `Mediate.Rbac.Conformance` | this package's own answers to the conformance kit | `Fixture`, `Support` | the kit's name |
| `Conformance.Reference`, `Tightened` | the policy module over the reference world, and the same under a role table where an editor no longer reads | `Roles`, `ReferencePolicy`, `TightenedRoles` | the core's word for its own answer, and the kit's verb |
| `Conformance.Policy` | the `Mediate.Conformance.Policy` that binds `Tightened` and releases, then binds `Reference` again | `Versions`, `Releases`, `PolicySwitch` | the behaviour's name, as `Mediate.Conformance.Reference.Policy` does |
| `Conformance.Predicates` | the predicate functions of both policy modules | `Conditions` | follows `predicate/2,3` |
| `Conformance.Seat`, `Assignment` | a grant schema with one attribute, and one with two | `RoleGrant`, `OneAttribute`, `ScopedAssignment` | a seat holds one role, and an assignment says which role where |

The engine's own event is gone. `Mediate.Rbac.release/0` publishes the core's `[:mediate, :policy, :release]` with a `Mediate.PolicyRelease`, whose `text` lists the role table and each module with its bytecode digest, so a change to a predicate is a new text and a new hash. Four of the seven namings asked that `Mediate.PolicyRelease.publish/1` be `release/1`, because the prose says release and never publish. The ledger keeps `publish/1`: in the core, publish is the verb for emitting any event, as `Mediate.IdentityWrite.publish/5` and `Mediate.ResourceRead.publish/6` show, and release is the act of putting a policy version in force. A deployment releases, and the library publishes the event that says so.

Two of the namings asked for a reason `:resource_type_unknown` beside `:action_unknown`, because `:no_rule_matched` covers both a subject with no grant and a policy with no resource block for the type, which are different deficiencies for an assessor. That is a reason and not a name, and it stays open for the core.

## Row-level security

`mediate_postgres` is the engine whose rules are Postgres policies on the tables themselves. Its words follow the core's and roles in code's, and these are its own. Seven independent namings of the package, by the same method, reached these names.

| Name | Is | Rejected | Why |
|---|---|---|---|
| `mediate_postgres`, `Mediate.Postgres` | the package and the engine | `mediate_rls`, `Mediate.RowLevelSecurity` | the database's name, as the other engines carry theirs |
| `Mediate.Postgres.Binding` | the repo, the schemas, and the migration source, kept at boot beside the configuration | `Wiring`, `Setup` | roles in code's word for the rest of a binding |
| `repo`, `schemas`, `migration_source` | the binding's fields and options | `migrations_table`, `version_table`, `tables` | Ecto's words, and the schemas name the tables |
| `Binding.tables/1`, `table_of/2`, `schema_of/2` | the bound tables, the table and primary key of a resource type, and the schema that owns a table | `target/2`, `lookup/2`, `type_table/2` | each says what it answers |
| `Mediate.Postgres.Rule` | one row of `pg_policy`: `name`, `table`, `command`, `using`, `with_check` | `Policy`, `PgPolicy` | a rule is one line of the policy, by rule 7, and `pg_policy` lists the lines |
| `mediate_filter_<action>`, `mediate_gate_<action>` | the two rule names the helpers write: the `SELECT` rule that narrows the rows of an action, and the write rule an answer reads before the write meets it | `mediate_scope_`, `mediate_check_`, `mediate_write_` | the filter rule is what `filter` leans on, and a write gate is roles in code's phrase |
| `Rule.filter_name/1`, `gate_name/1`, `kind/1` | the two names from an action, and `{:filter, action}`, `{:gate, action}`, or `:other` from a rule | `scope_name/1`, `parse_name/1` | the two prefixes, and a rule has a kind as a line has |
| `Rule.command/1`, `to_text/1`, `from_text/1`, `to_sql/1` | the `polcmd` letter as an atom, the text a release carries, the rules read back from it, and the statement that writes one | `cmd/1`, `render/1`, `parse/1`, `to_ddl/1` | the settled pair `to_text/1` and `from_text/1`, and SQL is what a `CREATE POLICY` is |
| `mediate.subject_id`, `mediate.subject_kind`, `mediate.action`, `mediate.now`, `mediate.<fact>` | the settings every call sets, and one per fact in the context | `mediate.operation`, `mediate.fact.<name>`, `mediate.context.<name>` | the request's words, and one level because a rule reads `current_setting` by one name |
| `Domain.Settings` | the settings a call runs under, as `pairs` | `Session`, `Guc`, `Variables` | Postgres's `set_config` sets a setting, and the struct runs no statement, so it is domain |
| `Settings.new/3`, `cleared/1`, `restored/2`, `to_sql/1`, `hash/1` | the settings of a subject, action, and context or moment; the same names emptied; the names put back to an outer call's values; the one statement; and the sha256 a filter verdict carries | `of/3`, `at/3`, `statement/1`, `digest/1` | the constructor's conventional name, and `to_sql/1` as `Rule.to_sql/1` |
| `Infrastructure.Session` | where the settings meet the connection | `Connection`, `Scope`, `Transaction` | the stretch of `around_query/3` is a session, and the module holds nothing itself |
| `Session.run/3`, `remember/3`, `recall/2` | runs the function with the settings in force, keeps a call's settings for the query that follows it, and reads them back | `around/3`, `with_settings/3`, `stash/3`, `fetch/2` | run says what happens to the function, and remember and recall are one verb pair |
| `rule`, `settings_hash` | the verdict's `meta`: the rule's name, and the sha256 of the settings the database read | `policy`, `rule: "<name> settings sha256:<hash>"` | the core's key, and two values in two keys where one string held both |
| `Mediate.Postgres.Catalog` | what the database says its rules are: `policy_version`, `rules`, `reads` | `Registry`, `Snapshot`, `Cache`, `columns` | Postgres's own word for its system tables, and reads are what the coverage check counts |
| `Catalog.read/1`, `load/1`, `resolve/1`, `rules/2`, `filter_rule/3`, `gate_rule/3`, and `load/1` with the mark | reads it now, reads and keeps it, answers the kept one, the rules on some tables for a caller with no binding, and the two rules of an action on a table | `fetch/1`, `reload/1`, `current/1`, `policies/2`, `scope/3`, `gate/3` | the binding's verbs, and no reload because a load reads |
| `Mediate.Postgres.load_catalog/0`, and with the mark | the root's load, with the bound binding resolved, at boot and again after a migration under a live VM | `load/0`, `reload/0`, `warm/0` | the root says what it loads, and one call serves both moments |
| `Mediate.Postgres.replica_lag/0` | the component of revocation latency the engine does not measure | `replication_lag/0`, `revocation_latency/0` | the prose word, and the function names the quantity, not the answer |
| `Mediate.Postgres.Migration` | the helpers a migration calls, the only DDL the package writes | `DDL`, `Policies`, `Rls` | Ecto's word for where DDL lives |
| `Migration.protect/2`, `filter/2`, `gate/2`, `admit/2`, `exempt/2`, `privileges/2`, `release/2`, each with the mark | forces row-level security on a table; writes the filter rule, the gate rule, a permissive `true` rule for one command, and the rule that admits a role's statements; grants a role its table privileges; and reads the rules back and releases the policy version in the migration's transaction | `enable_rls`, `policy`, `scope`, `allow_all`, `grant`, `publish` | the mark on each, because a migration raises; grant is the core's word for a row, where SQL's `GRANT` gives privileges; and the event is a release, by rule 1 |
| `table:`, `action:`, `using:`, `with_check:`, `command:`, `to:`, `commands:`, `always:` | the helpers' options | `operation:`, `role:`, `for:`, `outside_decision:` | the request's word, SQL's clause names, and `always:` for an exempt rule that holds whatever action is in force |
| `tables:`, `policy_version:`, `author:`, `approval:`, `released_at:`, `policy_text_bytes:` | the release helper's options | `version:`, `at:`, `content_bytes:` | the release's field names and the configuration's cap, by rule 5 |
| `Domain.Identifier.check/2` with the mark | the name or a raise that says what the name was for | `Name.check/2`, `quote_ident/1` | the manual's chapter is "Identifiers", and quoting would let one name be spelled three ways |
| `Mediate.Postgres.Version` | the policy version of row-level security: the migration number, and the rules as text | `PolicyVersion`, `Release` | roles in code's module |
| `Mediate.Postgres.Version.text/1`, `text_hash/1`, `release/3` | the rules as text, its sha256, and the `Mediate.PolicyRelease` of an engine, some rules, and the release options | `of/3`, `content/1`, `pointer/1`, `publish/1` | the release's field names, and the core publishes |
| `Mediate.Postgres.Facts` | the check that every column the rules read is a declared fact | `Coverage`, `Declared` | roles in code's module |
| `Facts.check/1`, `undeclared/1`, and `check/1` with the mark | ok or the findings, the findings, and the raise | `verify/1`, `violations/1` | roles in code's verbs |
| `finding` | `{schema, column}` or `{:table, name}`: an undeclared column, or a table no bound schema owns | `{:unbound_table, name}`, `{:unbound, name}` | roles in code's shape, where the tag names the kind of thing found |
| `Domain.Coverage.undeclared/2`, `describe/1` | the findings among the catalog's reads against the bound schemas, and the findings as the message body | `Declared.findings/2`, `message/1` | the brief's own heading is declared-fact coverage, and an adjective is no module name |
| `Infrastructure.Decide.one/6`, `filter/5` | the one statement that decides a row, and the verdict a filter gets | `scope/5`, `authorize/6` | roles in code's name, and the core's name for the type-level call |
| `Mediate.Postgres.Conformance` | this package's own answers to the conformance kit | `Fixture`, `Support` | the kit's name |
| `Conformance.Reference`, `Reference.folder_read_using/1` | the migration that writes the reference world's rules, and the `USING` of the folder read rule with or without a role | `Rules`, `Migration`, `folder_read/1` | roles in code's name for its policy over the reference world, and the function says which clause it answers |
| `Conformance.Policy` | the `Mediate.Conformance.Policy` that swaps the folder read rule, records a migration, and releases | `Versions` | the behaviour's name |
| `Mediate.Postgres.Probe`, `Probe.Row`, `Item`, `Folder`, `Shelf` | tables and schemas of its own for the cases the fixture cannot carry, and `create/1` with the mark, `empty_migrations/0` | `Carried`, `Covered`, `empty_versions/0` | one test-only module, and the empty table is a migration source |

The engine's own event is gone, as roles in code's is. `Migration.release/2`, with the mark, publishes the core's `[:mediate, :policy, :release]` with a `Mediate.PolicyRelease` whose `text` is the rules as `pg_policy` renders them, in the transaction that wrote them. The package has no release at boot, because a release at boot could commit apart from the rule change it records.

The database does not report which rule admitted a row. A denial under a filter rule names that rule and nothing further, and a row the filter hides and a row that does not exist deny the same way. Three of the namings asked that the verdict's `meta` carry the table beside the rule; the decision already carries the resource type, so the table stays out.

Four objections stay open beyond the two roles in code recorded. `Mediate.PolicyRelease.text_hash` names no algorithm where this package's `settings_hash` is a sha256 too. `Mediate.<Engine>.Version` shadows Elixir's `Version` under an alias, so no file in this repository aliases it. A reader of Ecto hears a query binding in `Binding`, which the README's first use says it is not. And `meta` keys that span engines, `rule` and `matched`, are a convention the core could name.

## Policy files

`mediate_cerbos` is the engine whose rules are policy files a Cerbos server reads. Its words follow the core's, roles in code's, and row-level security's, and these are its own. Seven independent namings of the package, by the same method, reached these names.

| Name | Is | Rejected | Why |
|---|---|---|---|
| `mediate_cerbos`, `Mediate.Cerbos` | the package and the engine | `mediate_pdp`, `Mediate.CerbosEngine` | the product's name, as the other engines carry theirs |
| `address:` | the engine's one option: the host and port the server answers on | `url:`, `endpoint:`, `sidecar:` | no scheme travels, and a topology is no option |
| `Mediate.Cerbos.Binding` | the repo, the declarations, the policy directory, the commit, the author, and the approval, kept at boot beside the configuration | `Wiring`, `Setup` | roles in code's word |
| `repo`, `declarations`, `policy_dir`, `commit`, `author`, `approval` | the binding's fields and options | `attributes`, `policies`, `ref`, `directory` | the declarations are a module and not values, `policy_dir` is the dev tools' name for the same directory, and a commit is what a reviewer finds |
| `Binding.schema_and_key/2` | the schema and the one primary key of `{:principal, kind}` or `{:resource, type}`, or `nil` for a block no declaration names | `target/2`, `schema_of/2`, `lookup/2` | it says both things it answers, and it takes the tagged pair because a deployment may declare `principal :user` and `resource :user` |
| `Mediate.Cerbos.Declarations` | the module a deployment writes: what the engine sends the server, and what a plan compiles over | `Attributes`, `Schema`, `Mapping` | it declares principals, resources, attributes, and context facts, and `Attribute` is the struct |
| `principal/3`, `resource/3`, `attribute/2`, `context/1`, `fact/1` | the block of a subject kind, the block of a resource type, one attribute of the block it stands in, the block of context facts, and one fact in it | `environment/1`, `kind/3`, `field/2` | principal and resource are Cerbos's names for the two sides, and context is the core's word for what travels with the request |
| `schema:` | a block's one option | `on:`, `table:` | Ecto's word |
| `context` | the reserved attribute the context facts travel under, so a policy reads `request.principal.attr.context.now` | `environment`, `request`, `mediate` | the core's word |
| `Declarations.declares?/1`, `blocks/1`, `principals/1`, `resources/1`, `facts/1`, `attributes/1`, `names?/2`, `schema_of/2`, `attributes_of/2`, `find/3`, `block_options_schema/0` | whether a module used it; the blocks as `{side, name, schema}`; each side's names; the facts; every attribute with its block; whether a block is declared; its schema; its attributes; one attribute by name; and the options a block takes | `kinds/1`, `declared?/2`, `all/1`, `kind_options_schema/0` | a block is one side's declaration, and kind stays the subject's word |
| `Mediate.Cerbos.Attribute` with `name`, `source` | one declaration: the name a policy reads, and where its value comes from | `Mapping`, `Field` | Cerbos's word for what a principal or a resource carries |
| `column:`, `subquery:`, and `{:column, atom}`, `{:subquery, fun}` | the two sources, as the option and as the tag | `field:`, `query:`, `from:` | the tag is the option's key, so nothing translates |
| `Attribute.new/2`, `new/2` with the mark, `column?/1`, `reserved_name/0`, `options_schema/0` | the declaration or why it is none, the raise, whether it reads a column, the name no declaration may take, and the options | `reserved/0`, `source_of/1` | `reserved_name/0` says what is reserved |
| `Mediate.Cerbos.Client` with `check_resources/2`, `plan_resources/2`, `server_info/1`, `healthy?/1` | one function per endpoint the engine asks, named as Cerbos names the endpoint, and the health question as `Mediate.Dev.Cerbos` asks it | `check/2`, `plan/2`, `serving?/1` | the endpoint's name, and one word for health across the repository |
| `[:mediate, :cerbos, :request]`, `Client.event/0` | the one event the engine owns, one per call to the server, with `duration`, and `address`, `path`, `outcome` | `[:mediate, :cerbos, :call]`, `telemetry_event/0` | a request is what the client sends, the budget test counts them, and the core's name for the function |
| `Mediate.Cerbos.Request` with `check/4`, `plan/4`, `principal/2`, `inline/3` | the bodies the server reads: a decision over resources, a plan over a type, the principal both carry, and a body from values already in the server's shape | `Body`, `logged/3` | inline attributes is Cerbos's own phrase |
| `:rule_allowed` with `policy`, `request_id`; `:no_rule_matched` with `policy` or `nil`, and `request_id` | the verdict of an allow and of every denial, with the policy the server evaluated and the request id it logged | `:rule_denied`, `rule`, `matched` | the server does not say whether a rule denied or nothing allowed, so one denial reason claims what is known; a policy is a file and not a rule, so it takes its own key; and the request id is what the server's audit log is searched by |
| `plan: :always_allowed`, `:always_denied`, `:conditional` | the filter verdict's meta beside `request_id`, with `:rule_allowed` for the first and the third and `:no_rule_matched` for the second | `kind`, `filter` | the plan's three shapes, as the server names them without its prefix |
| `:engine_failed` for a resource the server did not answer | the error, not a verdict | `:no_rule_matched` | a missing answer is a fault and not a rule |
| `:subject_kind_unknown` with `subject_kind`, and `:no_rule_matched` with `resource_type` | an undeclared subject kind, and an undeclared resource type | `:resource_type_unknown` | the core's reason for the kind, and row-level security's answer for the type |
| `Domain.Plan.compile/1` over `subject`, `action`, `context`, `plan`, `declarations`, `type`, `schema`, `key` | the plan the server answered, as a `dynamic`, `:denied`, or the sentence that refuses it | `Infrastructure.Plan.dynamic/5`, `translate/1`, `lower/1` | compiling touches nothing, so it is domain, and the struct is the whole input |
| `Infrastructure.Values.principal/3`, `context/2`, `resources/5`, `by_ids/5` | the subject's attributes with the context facts beside them, the context facts alone, the attributes of some resources, and the attributes of some ids of one block | `environment/2`, `of/5` | the request's word, and `by_ids` says what differs from `resources/5` |
| `Domain.Codec.encode/1`, `to_second/1` | a value as JSON carries it, and a moment cut to the second first | `Infrastructure.Codec`, `moment/1` | it says what it does to the moment, and it touches nothing |
| `Infrastructure.Decide.one/6`, `filter/6` | the verdict of one resource, and the rule and verdict of a type | `scoped/6` | the siblings' names |
| `Mediate.Cerbos.Facts` with `check/2`, `check/2` with the mark, `undeclared/2`, `reads/1` | the fact check over a query, given the binding | `Coverage` | roles in code's module, and the binding first as the siblings take it |
| `finding` | `{schema, column}` or `{:fragment, text}` | `{:undeclared, schema, column}` | roles in code's shape |
| `Mediate.Cerbos.Version` with `policy_version/1`, `files/1`, `text/1`, `from_text/1`, `text_hash/1`, `release/4` | the commit, the policy files by path, the files as one text, the text read back, its sha256, and the `Mediate.PolicyRelease` | `ref/1`, `content/1`, `to_text/1`, `content_hash/1`, `of/4` | the release's field names, and the settled pair `text/1` and `from_text/1` |
| `Infrastructure.Release.publish/1`, `Mediate.Cerbos.release/0` | builds the release and publishes the core's event | `publish/0`, `Mediate.Cerbos.Version.publish/1` | roles in code's pair |
| `policy files in <dir> at commit <sha>` | the text location over the cap | `policies in <dir> at <sha>` | the prose words |
| `invalid policy_dir: <path> could not be read: <reason>` | the error of a file the release cannot read | `invalid policies: ...` | the option's name |
| `Mediate.Cerbos.Conformance.Reference`, `Memberships`, `Policy`, `Server`, `Outage`, `PolicyFiles` | the declarations over the reference world; the two subqueries; the `Mediate.Conformance.Policy`; a server of one test's own; the `Mediate.Conformance.Outage`; and the file swap the policy makes | `Attributes`, `Versions`, `Sidecar`, `Propagation` | the siblings' names, and the measurer is gone |
| `Memberships.folder_roles/2`, `item_roles/2` | the roles a subject holds live on a folder, and on an item's folder | `folder_roles_for/2`, `item_roles_for/2` | the suffix added nothing |
| `Server.start/0` and `start/1`, each with the mark, and `files/0` | a server over a copy of the conformance policy files, one over the files given, and those files | `own/0`, `over/1`, `conformance/0` | the dev tools' verb |
| `user`, `service`, `privileged` | the roles the conformance policy files name | `non_person_entity` | the core's subject kinds, as the roles the request sends |

The engine's own events are gone. `Mediate.Cerbos.release/0` publishes the core's `[:mediate, :policy, :release]` with a `Mediate.PolicyRelease` whose `text` is the policy files, each preceded by its path, and a plan the compiler refuses is an `:engine_failed` error that the decision event already records. `Propagation` leaves the library: the kit's `cm3-04` prints the release latency from `tighten/0` and `Mediate.Test.poll/2`, and the file swap lives in test support.

Five of the seven namings call the Cerbos process the server. The development tools' section said service, and the word collides with the `:service` subject kind in every sentence that puts a subject near the process. One process gets one word, so the ledger says server for the dev tools too, and PDP and sidecar stay out: the first is Cerbos's jargon, and the second is a topology this repository happens to use.

Two objections join the open ones. `Mediate.Dev.Cerbos` takes `dir:` beside `policy_dir:`, and a reader must learn that the first is where the configuration file goes. And fact names a column a rule reads and an entry of the context both, which the phrase context facts keeps apart only while the adjective stays.

## OpenFGA

`mediate_openfga` is the engine whose rules are a relationship model in a store an OpenFGA server holds. Its words follow the core's and the siblings', and these are its own. Seven independent namings of the package, by the same method, reached these names.

| Name | Is | Rejected | Why |
|---|---|---|---|
| `mediate_openfga`, `Mediate.OpenFGA` | the package and the engine | `mediate_fga`, `Mediate.Fga`, `Mediate.Zanzibar` | the product's name, as the siblings carry theirs, and FGA alone is a category |
| `address:`, `store_id:`, `model_id:`, `client:` | the engine's options: where the server answers, the store the tuples live in, the model every question runs under, and the client that asks | `endpoint:`, `store:`, `model:`, `transport:` | the sibling's word for the address, and the product's names for the ids |
| `Mediate.OpenFGA.Binding` with `repo`, `model_file`, `mapping`, `guard`, `author`, `approval` | what the deployment keeps at boot beside the configuration | `model`, `tuple_mapping`, `path` | roles in code's word, and `model_file` beside `policy_dir` says it is a path |
| `Mediate.OpenFGA.Client` with `create_store/2`, `write_authorization_model/3`, `check/3`, `list_objects/3`, `read/3`, `write/3` | one function per endpoint the engine asks, named as OpenFGA names the endpoint | `write_model/3`, `list/3`, `query/3` | the endpoint's name, as the Cerbos client takes its endpoints' names |
| `Client.HTTP`, `Client.Fake` | the client over HTTP, and the one on an agent a test owns | `Http`, `Agent`, `Memory` | the protocol as it is written, and fake is the kit's word |
| `[:mediate, :openfga, :request]`, `Client.HTTP.event/0` | the one event the engine owns, one per call to the server, with `duration`, and `address`, `path`, `outcome` | `[:mediate, :fga, :request]`, `telemetry_event/0` | the sibling's event and the core's name for the function |
| `Check`, `ListObjects`, `Read`, `Write`, `Page` with `tuple_key`, `model_id`, `context`, `consistency`, `user`, `relation`, `type`, `object_type`, `object_id`, `continuation_token`, `page_size`, `writes`, `deletes`, `tuples` | the request each endpoint takes, and the page a read answers, with the API's own field names | `model`, `continuation`, `limit` | a field named as the API names it needs no translation in the codec |
| `Mediate.OpenFGA.TupleKey` with `user`, `relation`, `object`, `condition`, and `triple/1`, `object_type/1`, `String.Chars` | one tuple as the store holds it, the three strings that identify it, its object's type, and the sentence a message prints | `Tuple`, `key/1`, `describe/1` | the product's name for the three, and a triple is what `key/1` answered |
| `Mediate.OpenFGA.Condition` with `name`, `context` | the condition a tuple carries | `Clause` | the product's word |
| `Mediate.OpenFGA.Consistency` | the type of the three consistency words | `Preference` | the API's word |
| `Mediate.OpenFGA.Model` with `read/1`, `compile/1`, `schema_version/0`, `parameter_types/0`, each read and compile with the mark too | the model file as text, and as the JSON the server takes | `Dsl`, `parse/1`, `to_json/1` | the product's verb, and read says it opens a file |
| `Mediate.OpenFGA.Mapping` with `object_types/0`, `objects/2`, `affected/2`, `tuples/2` | what a deployment writes: the types, the objects of one, the objects a write affected, and what one object's rows require | `TupleMapping`, `changed/2`, `required/2` | the one mapping the package has needs no adjective, and affected says the objects and not the row |
| `Mediate.OpenFGA.MappingCase` with `mapping:`, `repo:`, `population:`, `setup:`, `async:` | the case template that holds a mapping to what a sync relies on | `TupleMappingCase`, `sandbox:` | the kit's name for the option that answers `setup(repo, tags)` |
| `Mediate.OpenFGA.Population` with `write/1`, `clear/1`, `absent/1`, `change/1` | the rows the case templates hold a mapping to: write them, take them away, name an object no row names, and make one change | `disturb/1`, `Fixture` | a change is what the outbox misses, and the word was free |
| `Mediate.OpenFGA.Guard` with `admits?/2` | the precondition a deployment holds outside the graph, asked before the server with the action and the context | `Precondition`, `Gate`, `permits?/2` | the word the README already had, and the core's words for the two arguments |
| `:rule_denied` with `rule: "guard"` | the verdict of a refusal by the guard | `:guard_refused` | the core's reason, and the guard is the rule that denied |
| `Mediate.OpenFGA.Outbox` with `attach/0`, `detach/0`, `mark/2`, `runner/0`, `table/0`, `event/0` | the markers a sync works from: the handler on the identity write event, a mark by hand, the runner's name, the table, and the event of a write the handler did not mark | `Markers`, `unmarked_event/0`, `__change__/4` | the pattern's name, and the core's name for the one event a module owns |
| `mediate_openfga_outbox`, `:mediate_openfga` | the outbox table and the runner's name | `mediate_fga_outbox`, `:mediate_fga` | the package's name |
| `[:mediate, :openfga, :unmarked]` | the event of a write the handler could not mark | `[:mediate, :openfga, :outbox, :failed]` | the only event the outbox owns, named for what happened |
| `Mediate.OpenFGA.OutboxCase` with `repo:`, `population:`, `setup:`, `async:` | the case template that holds the outbox, the mapping, and the store together | `DrainCase`, `SyncCase` | the thing under test is the outbox |
| `Mediate.Relay` with `start_link/1`, `pass/1`, `wake/1`, `options_schema/0` | batched, ordered delivery from a Postgres table, as a package of its own inside this one: the supervisor over the runners, one pass by hand, and the wake-up | `Mediate.OpenFGA.Relay`, `drain_once/1`, `run_once/1`, `Outbox.Relay` | nothing in it knows a tuple, so it stands beside the engine and not under it, and a pass is what the event is named |
| `Relay.Job` with `read/4`, `deliver/3`, `options_schema/0` | what a runner delivers | `Source`, `Handler` | Oban's word for the module that does the work |
| `Relay.Cursor` with `position/2`, `advance/3`, and `mediate_relay_cursor` | how far a runner has delivered | `Offset`, `Checkpoint` | the word the table already carried |
| `Relay.Entry` with `position`, `payload` | one row on its way out | `Row`, `Record` | a row is Ecto's word for something else |
| `Relay.Pass` with `name`, `held?`, `delivered`, `position`, `more?`, `at` | what one pass did | `Result`, `Report` | the event's word |
| `Relay.Options` with `schema/0`, `validate/1` with the mark | the options one runner takes | `Config` | the core's word is taken |
| `Relay.Migration.up/1`, `down/0` | the cursor table, in a deployment's own migration | `cursor_up/1`, `cursor_down/0` | Ecto's verbs, and the module says which table |
| `Relay.Domain.Backoff.wait/3`, `failures/2`, `Relay.Domain.Key.of/1` | the arithmetic of the next tick, and the advisory lock's pair | none | they touch nothing |
| `Relay.Infrastructure.Delivery.pass/1`, `event/0`, `Relay.Infrastructure.Lock.acquired?/2`, `Relay.Infrastructure.Runner` | one pass in one transaction, the event it emits, the advisory lock, and the process that ticks | `Drain.once/1`, `taken?/2`, `Worker` | a delivery is what a pass does, and acquired is Postgres's word for a lock |
| `[:mediate, :relay, :pass]` | the event every pass emits | `[:mediate, :relay, :drain]` | the pass is the unit |
| `Mediate.OpenFGA.Migration.up/1`, `down/0` | the outbox table, in a deployment's own migration | `outbox_up/1`, `outbox_down/0` | Ecto's verbs, and the module says which table |
| `Mediate.OpenFGA.sync/0`, `mark_all/0`, `reconcile/0`, `rebuild/1` | the engine's sync: pass until no marker is left; mark every object; the drift between the tables and the store; and a store of its own with every tuple the tables require | `settle/0`, `drain/0`, `converge/0`, `diff/0` | the core's callback, and one verb for the store coming into step |
| `Mediate.OpenFGA.Drift` with `missing`, `extra`, `position`, `empty?/1` | what reconcile answers: the tuples the tables require and the store lacks, the tuples it holds and nothing requires, the cursor the comparison ran at, and whether there is none | `checked_to`, `clean?/1` | position is the cursor's word, and empty says what the lists are |
| `Infrastructure.Store` with `client`, `address`, `store_id`, `mapping`, `repo`, `batch`, and `resolve/1`, `configured/0`, `objects/1`, `sync/2`, `drift/2`, `create/3`, `held/2`, `present/1` | the store a pass writes, from the configuration and the binding, and what it does to it | `endpoint`, `store`, `converge/2`, `created/3` | the option names, and one verb for the sync |
| `Infrastructure.Sync.run/0` | the sync: a pass of the outbox runner until a pass delivers nothing | `Settle.now/0` | the callback's name |
| `Domain.Difference.between/2`, `writes/3`, `sorted/1` | the tuples to delete and to write between what the tables require and what the store holds, the calls that carry them, and a stable order | `Drain.difference/2`, `calls/3` | a difference is what it computes, and it touches nothing |
| `Infrastructure.Decide.one/4`, `filter/4`, `entry/3`, `refused/1`, `refused_filter/1` | the verdict of one resource, the rule and verdict of a type, what the configuration entry names, and the guard's refusal in each shape | `scoped/4`, `refused_scope/1` | the siblings' names |
| `Decide.relation/1`, `user/1`, `object/1`, `time_key/0`, `kind_key/0`, `consistency/1`, `limit/0` | an action as a relation, a subject as a user, a resource as an object, the two context keys, which consistency each callback asks, and the filter limit | `named/1`, `time_fact/0`, `kind_fact/0`, `scope_cap/0` | the product's three words, and a key is what the context map has |
| `current_time`, `subject_kind` | the two keys every question's context carries, which a condition reads | `now`, `kind` | the model's parameter names |
| `:rule_allowed` with `rule`; `:no_rule_matched` with nothing | the verdict of a check that allowed, naming the relation, and of one that did not | `:allowed`, `:deny_by_default`, `matched` | the core's reasons, and the server says nothing about a path |
| `filter_limit/0` of `1_000` | the most objects one listing answers | `scope_cap/0` | the core's callback |
| `:engine_failed` at the limit | a filter the listing cannot answer in full | `:filter_limited`, a short list | a list short of the truth is a fault and not a verdict |
| `Mediate.OpenFGA.Version` with `text/1`, `text_hash/1`, `release/5` | the model file read through the binding, its sha256, and the `Mediate.PolicyRelease` for a model id | `content/1`, `of/4`, `telemetry_event/0` | the release's field names, and the sibling's module |
| `Infrastructure.Release.publish/1`, `Mediate.OpenFGA.release/0` | writes the model to the store and publishes the core's event | `publish/0`, `Mediate.OpenFGA.Version.publish/1` | roles in code's pair |
| `the model file <path>` | the text location over the cap, and the file an error names | `the model in <path>` | the binding's word |
| `Mediate.OpenFGA.Conformance.Reference`, `Population`, `Setup`, `Mirror`, `Policy`, `Outage` | the mapping over the reference world; the rows the templates write; what the templates run under; the `Mediate.Conformance.Mirror`; the `Mediate.Conformance.Policy`; and the `Mediate.Conformance.Outage` | `Mapping`, `Seed`, `Versions`, `Unreachable` | the siblings' names, and the reference mapping names items, so the mirror is a mark of everything and a sync |
| `Mediate.OpenFGA.TestMigrations`, `Mediate.Relay.TestJob`, `FlakyJob`, `TestTables` | this package's own migration, and the job the relay proves itself over | none | each under the module it serves |

The engine's own events go but two. `Mediate.OpenFGA.release/0` publishes the core's `[:mediate, :policy, :release]` with a `Mediate.PolicyRelease` whose version is the model id the server answered, and a filter at the limit is an `:engine_failed` error the decision event records. What stays is the client's request event, which the budget tests count, and the outbox's unmarked event, which says a store fell behind in silence.

Six of the seven namings put the relay beside the engine and not under it. It knows a cursor, a lock, and a job, and nothing of a tuple. The seventh kept it under the engine because the engine is its only caller, which is a fact about today and not about the module. It stays in the package, under its own boundary, until a sibling needs it.

`mediate_fga` as `mediate_openfga`, which the development tools' sweep left open, is settled here by every lens. FGA is a category of system, and the package is one product's.

Four objections join the open ones. `Mediate.Dev.OpenFGA` names its address `http` where the engine names it `address`, and one thing should have one name. A filter at the limit answers an error that the caller cannot tell from a server that is down, and a reason of its own would say so. `Binding` collides with Ecto's bindings in any sentence about a query. And the relay is a package of its own once a sibling needs it.

## Credo checks

`mediate_credo` is the two checks an adopter names in `.credo.exs`. A check reads source text, so it is static, and `Mediate.Conformance.RepoCase` is what proves the mediated repo at run time. Seven independent namings of the package, by the same method, reached these names.

| Name | Is | Rejected | Why |
|---|---|---|---|
| `Mediate.Credo.Check.Warning.RawSQL` | the check that flags a call to `Ecto.Adapters.SQL` or `Postgrex`, which reaches the database around the mediated repo | `NoRawSQL`, `Mediate.Credo.RawSQL`, `UnmediatedQuery` | Credo names the thing found and not the rule, and the reader meets the name in `.credo.exs` beside `Credo.Check.Warning.UnsafeExec`, so it has that shape |
| `Mediate.Credo.Check.Warning.UnmediatedRepo` | the check that flags a repo that `use Ecto.Repo` without `use Mediate.Repo` | `BareRepo`, `PlainEctoRepo`, `UnenforcedRepo`, `MissingMediateRepo` | the settled word negated, which names what is missing and not what the module is |
| `"ME5001"`, `"ME5002"` | the ids: `ME` for Mediate, Credo's category digit, and a counter | `"TS0001"`, `"MD5001"`, `"MD0001"` | the shape of Credo's `EX5001`, so `ME5` reads as a warning without a table, and `MD5` is a digest |
| `:warning`, `:high` | the category and the priority of both | `:higher`, `:design` | a path nothing checks is a fault and not a style, and a check that reads text must not outrank one that proves |
| `excluded_namespaces:` | the module name prefixes the raw SQL check skips: the modules the mediated repo itself rests on | `allow:`, `allowed_namespaces:`, `exempt:` | Credo's own key for the same list on `Design.AliasUsage`, and an exemption is the repo call's word |
| the message: the trigger, what was found, the fix, in two sentences | what a check prints at a line | "around the seam", a third sentence that names the parameter | the reader opens the trigger first and acts without `mix credo explain`, and the exclusion is the rare fix |
| no `@moduledoc` on a check | `use Credo.Check` builds the page from the explanation, so hexdocs and `mix credo explain` print one text | `@moduledoc false`, a one-line pointer | one source for the text |
| `Mediate.Credo.Check.Warning.RawSQLTest`, `UnmediatedRepoTest`, `Mediate.CredoTest` | the proof of each check, and of the package's requirement on Credo | none | the check's name with the suffix |

The module's shape split the lenses three ways. Three put `Check.Warning` between the root and the name, three put nothing, and one put `Check` alone. The full shape wins by rule 12: the name is typed once, in `.credo.exs`, under the heading `## Warning Checks` and beside Credo's own, and a reader who knows one Credo check reads this one at sight. The root `Mediate.Credo` already says Credo, and so does `CredoNaming` before its `Check.Consistency`, which is the convention of every package that adds a check.

The parameter split four ways. `allow:` answers "allow what?" with nothing, and `allowed_namespaces:` is a key no Credo user has typed. `exempt:` would make the one word the repo call reserves mean a second thing, and six of seven lenses kept it out of this package for that reason. `excluded_namespaces:` is the key Credo's `AliasUsage` takes for the same list, and the description says who belongs in it.

Every lens found the same drift. The root `.credo.exs`, the README, the mix description, both explanations, and both messages said seam, and one test named the repo option by its old key. All of it is rewritten in this sweep. No objection joins the open ones.

## The example

`example` is the code-hosting domain every engine is measured against: the schemas, the application modules, the SIEM consumer, the fixture, and the scenario suite each deployment runs. It has no engine of its own. Seven independent namings of the package, by the same method, reached these names.

| Name | Is | Rejected | Why |
|---|---|---|---|
| clause | one of the thirteen numbered lines C1 to C13 that the domain holds every engine to | rule, requirement, control, invariant, constraint, criterion | a rule is one line of a policy by rule 7, and a control is a FedRAMP word; a clause is a numbered line of a contract, and the thirteen are the contract the engines sign |
| C13 Filter fidelity | the clause that `filter` admits exactly the rows `authorize` allows | Scope fidelity | the call's name, by rule 1 |
| `Example.Domain.Account`, table `accounts`, `account_id` | the row a person signs in as, which the core calls the `:account` kind | `User`, `users`, `user_id` | one word per thing: the core says account for the row and `:user` only for the ordinary kind, so the schema says the same |
| `Example.Domain.Permission`, table `permissions`, field `permission` | the row that gives an account the audited override, with `identity(:role)` and `fact(:permission, about: :subject)` | `AccountRole`, `Role`, `Entitlement`, `Capability` | a role is a kind in the core, and the row holds one permission; the reader asks "has gil the override permission?" and the query says so |
| `identity(:account)`, `identity(:group)`, `identity(:role)`, `identity(:other)` | the kind of each schema's rows: accounts, teams, permissions, and all the rest | `audited(:user)`, `audited(:entity)`, `identity(:entity)` | the core's four kinds by rule 2, a team is what OCSF calls a group, and `:other` is the core's word for a row that is none of the three |
| `grant/1` on Membership, TeamRole, Proposal | the declaration of a row that is a grant: a subject column and a resource column | `relationship/1`, `edge/1` | the core's word |
| `Example.Domain.OverrideReport` with `account_id`, `justification`, `correlation_id`, `read_at` | the row an override read leaves | `user_id`, `operation_id`, `at`, `reason` | rule 5: the report copies the decision event's keys, so one grep finds both; `reason` is an atom by rule 6 and the justification is free text |
| `fact(:invited, about: :grant, element: :account)` | the invited list on a Visibility, one account per element | `element: :user` | the kind the element is |
| `Example.Domain.Rollup.includes?/2` | whether a repository's rollup includes a directory's visibility | `covers?/2`, `within?/2`, `dominates?/2` | `covers/1` is the schema declaration's verb, and a rollup includes what it was built from |
| `Example.Domain.Reauthentication`, `window/0`, `fresh?/1` | the re-authentication window and whether a context's `reauthenticated_at` is inside it | `Sessions`, `Session`, `StepUp` | the module holds the window and not a session; a session is the thing the window measures |
| `Example.Domain.Restrictions.kinds/0`, `fields/0` | the closed list of restriction kinds, and the fact fields they map to | `all/0`, `names/0` | rule 3: a closed list is a kind |
| table `proposals` | the Proposal rows | `visibility_proposals` | the schema is `Proposal`, by rule 1 |
| `Example.Application.Repositories.actions/0`, `resource/1`, `resource/2`, `visibility_changeset/2` | the closed list of actions, the `{type, id}` of a row, and the changeset of a visibility change | `operations/0`, `object/1`, `visibility_change/2` | the core's words: action and resource; a function that returns a changeset says so |
| `Example.Application.AccessReview`, `readers/3`, `allowed/3`, `report/2`, `actions/0` | the application module behind `Mediate.review/5`: who can read, what an account is allowed, and the report | `Review`, `permissions/3`, `entitlements/3` | rule 12: the call site reads the standard's term, AC-2(j) access review; permission is now the override row's word, and allowed is what `authorize` says |
| `Example.Application.Accounts.add_membership/3`, `remove_membership/2`, `add_team_role/3` | the writes that add and remove a grant row | `assign/3`, `unassign/2`, `grant_membership/3`, `revoke_membership/2`, `set_team_role/3` | a grant is the row's kind, so the verb must not reuse it; add and remove say what happens to the row, and the clause reads the same |
| `grant_override/1`, `override_permitted?/1`, `privileged/0` | the write of the override permission, the check behind the override read, and the privileged accounts | `enable_override/1`, `may_override?/1` | rule 9: the predicate shares its noun with the row it reads |
| `RollupViolation`, `OverrideRefused` with `reason: :not_privileged \| :no_permission \| :no_justification` | what an application module returns when a clause refuses | `RollupError`, `OverrideDenied` | a deny is the engine's word and these are the application module's; `reason` is an atom by rule 6 |
| `Example.Infrastructure.AccountQuery.override_permission/1`, `RepositoryQuery.filtered/1`, `override_reports/1`, `AccessReviewQuery` | the queries an application module runs | `override_role/1`, `scoped/1`, `admitted/1`, `reports/1`, `ReviewQuery` | each follows the name it serves: the permission row, the `filter` call, the report row, the access review |
| `Example.Infrastructure.SIEM`, `ocsf_version/0`, `records/1`, `records/2` | the consumer that turns the three events into OCSF records and holds them | `Siem`, `SecurityLog`, `schema_version/0` | the acronym cased as `Mediate.RBAC` is, and the call site says which schema's version it reads |
| `Example.Infrastructure.OCSF`, `version/0`, `identity_write/1`, `decision/2`, `resource_read/1` | the mapping of each event to its OCSF class | `Ocsf`, `change/1`, `access/1` | rule 1 with the event names |
| `Example.Fixture.Specimen` | the conformance kit's specimen of the example's schemas | `Fixture.Rows`, `RepoSpecimen` | the kit's word |
| `Example.Fixture` world and `exemption/0` | the rows every scenario starts from, inserted by the bang function named world, and the exemption its writes carry | insert, seed | world is the prose word for the rows, and the fixture inserts the world |
| `Example.FakeCase`, context keys `world` and `fake`, `allow/4`, `revoke/4` | the case that binds the fake engine and inserts the world | `rules`, `deny/4` | the fake's own verbs, and the key names what it holds |
| `Example.Scenarios.Durable`, tag `:durable` | the scenarios that commit, so one deployment runs them outside the sandbox | `Committed`, `Persisted` | durable is what a committed write is, and the tag reads alone on a test by rule 4 |
| `scenario/4` with `clause:`, `Row.clauses` | which clauses a scenario proves | `rule:`, `tests:` | the noun the thirteen have |
| `Example.Scenarios.Enforcement`, `Privilege`, `Revocation`, `AccessReview`, `Reauthentication` | the five scenario bodies, by group | `Identity`, `Review`, `LeastPrivilege` | each body is named for its group; the override scenarios are a privilege question and sit with least privilege |
| `Example.Scenarios.Support.sync/0`, `engine_name/0`, `fresh_session/0`, `stale_session/0`, `reads?/2` | the helpers a scenario calls | `settle/0`, `adapter_name/0`, `fresh/0`, `stale/0`, `can_read?/2` | the core's `Mediate.Test.sync/0` and the engine word; a bare `fresh/0` says fresh what |
| the latency header "revocation latency, <engine>: total, commit, catch-up, poll, floor; replica lag not measured" | one line per run | drained, replica_lag, "cache not measured" | each word is one the prose uses |

The noun for the thirteen split three ways. Constraint reads as a database word, and criterion as a grading word. Clause is what a numbered line of a contract is called, and the thirteen are the contract every engine signs. Rule stays the policy's word by rule 7.

The override row split five to two. Role in the core is the subject kind the engine sees, so a schema named `AccountRole` whose only value is `:override` said kind where it meant permission. The newcomer reads "has gil the override permission?" and the query `override_permission/1` answers it.

The review module split. The core's call is `review/5`, after the control's verb, and four lenses kept `Review`. `AccessReview` wins by rule 12: a reader who opens the module from the call site meets AC-2(j) by its name, and the scenario body `AccessReview` no longer collides with an application module of the same last word. The function behind it had been `permissions/3`, which the new row's name takes; it is `allowed/3`, since it answers what `authorize` would allow.

The verbs on memberships split three ways. Grant is the row's kind, so `grant_membership/3` said the noun twice. Assign and unassign had no object in the name. Add and remove say what happens to the row.

The identity scenarios split. The ia rows are about re-authentication and the ovr rows about the override, which is a privilege question. One body per group puts the ovr rows beside least privilege and separation of duties, and the ia rows alone under `Reauthentication`.

Every lens found the same drift: port, seam, adapter, thin application, operation, object, scope, check, verdict, change event, access event, environment, context, rule, and relationship, across the moduledocs, the two documents, the scenario table, and the test names. All of it is rewritten in this sweep. The core's `Mediate.Schema` moduledoc example said `element: :user` on the invited fact and says `:account` now. Four objections join the open ones: `identity(:other)` on seven of twelve schemas reads as a shrug and wants a definition in the core's doc; the subject kind `:user` sits beside the prose word account; `Mediate.review/5` is named after the control's verb while the module behind it says access review; and `Mediate.Test.Fake.revoke/4` beside `allow/4` wants its own doc line.

## The example under roles in code

`example_rbac` is the deployment that binds `Mediate.Rbac` to the example. Seven independent namings of the package, by the same method as the API's, reached these names.

| Name | Is | Rejected | Why |
|---|---|---|---|
| `example_rbac`, `ExampleRbac` | the package and its root | `example_roles`, `ExampleRoles` | a deployment's last segment is its engine's last segment, so a line of test output names the engine under assessment |
| `ExampleRbac.Application`, `ExampleRbac.Supervisor` | the boot, and the tree it starts | `Boot`, `Tree` | OTP's names |
| `release/1`, `repos/0` | the application's privates: publishes the policy release when this tree started the repos, and the repos it starts | `publish_release/1`, `repo_children/0` | the core's verb, and the thing the function answers |
| `ExampleRbac.Infrastructure.Policy` | the policy module | `ExampleRbac.Policy`, `Rules` | the example's three layers, and a policy is how the deployment reaches the engine |
| `author: "the Mediate maintainers"`, `approval: "the thirteen clauses of docs/example.md"` | the release's two change-control strings | `"example_rbac"`, `"the rules in docs/example.md"` | the author is the party accountable, which the event does not carry elsewhere, and the document states clauses |
| `:membership`, `:team_role` | the grant rules, named for the grant schema each reads | `:team`, `:project` | one word per thing, and `Team` is a schema the rule hops past |
| `:restrictions`, `:fresh_session`, `:another_reviewer` | the predicate rules, named for the condition each asserts | `:session`, `:reauthentication`, `:visibility` | the rule tests that the session is fresh, in the example's word |
| `ExampleRbac.Infrastructure.Predicates` | the hidden module of predicate functions and the hop filter | `Conditions`, `Policy.Predicates` | follows `predicate/2,3` |
| `not_archived/0` | the hop filter of every membership grant rule | `open/0`, `active/0` | on a code host open means open to the public, and the filter tests archival |
| `repository_restrictions/2`, `directory_restrictions/2`, `fresh_session/2`, `another_reviewer/2` | the predicate functions, each named for its rule | `restrictions/2`, `session/2` | the pair is symmetric, and a reader moving from the README to a stack trace never translates |
| `join_facts/3`, `under_embargo/1`, `blocked/1`, `blocks/2`, `in_effect/1` | the privates: joins the account row, the enterprise and the sensitive labels; the embargo has not lifted by the context's `now`; the `or` of every kind; one kind blocks the subject; the kind is declared on the visibility or implied by a label | `joined/3`, `restricted/1`, `failed/1`, `fails/2`, `effective/1` | a restriction blocks a row where failing is ambiguous with an error, restricted collides with `Restrictions`, and `in_effect(kind)` reads at the call site |
| `:account`, `:invited_list` | the query aliases for the subject's row and the visibility row that carries the invited list | `:subject`, `:invited` | the core's subject is `{kind, id}` and the row is an account, and the list is the example's noun |
| `blocked` | the subquery variable | `restricted`, `denied` | the prose says blocked rows, and deny is a decision |
| `ExampleRbac.Migrations.Domain`, `ExampleRbac.Migrations.Policy` | the migration that raises the example's tables, and the one that holds nothing because the policy is a module | `ExampleRbac.Repo.Migrations.*`, `Rules` | no `ExampleRbac.Repo` exists, and a rule is one line |
| `priv/repo/structure.sql` | the structure file | `priv/schema/rbac.sql` | Ecto's own default beside the migrations, and schema means an Ecto schema in this package |
| `ExampleRbac.ScenariosTest`, `ExampleRbac.ApplicationTest`, `ExampleRbac.Infrastructure.PolicyTest` | the tests, each its module under test and `Test` | `SuiteTest`, `BootTest` | the output names what failed |
| `Clause`, `Mechanism`, `Scenario group` | the README's column headers | `Rule`, `Enforced by`, `Test group` | `docs/example.md` asks which mechanism enforces each clause, and the groups are scenario groups |

The acronym is permitted in the package, module and file names, where a reader must type it, and forbidden in prose, which says roles in code. The structure file moves to Ecto's default path, so the development tools' examples name `priv/repo/structure.sql` and the CI step diffs that file.

Two of the namings asked that the author string stay the package name, because a person's name goes stale. The string names the maintainers and no person. Three asked that `effective/1` become `effective_visibility/1`, which names the visibility where the function tests whether one kind is in effect for it.

The example under roles in code, in prose:

- **deployment** for the package, never binding, thin application or harness
- **states** for what `docs/example.md` does to a clause, and **enforces** for what the policy module does, through the engine at the mediated repo call; never implements, covers or models
- **grant rule**, **predicate rule**, **hop filter**, **role table**, never permission, condition, join filter or matrix
- **blocked rows** for what the subquery answers, never denied, excluded or restricted rows
- **structure file**, never schema file, committed schema or the dump
- **the boot** for the configuration's boot and the binding's bind at application start, never startup or wiring
- **the policy release** in full, never bare release, which the release workflow owns, and never publish as a noun
- **context fact** for what `context` carries and **declared fact** for what `Mediate.Rbac.Facts.check/1` requires, never bare fact
- **mechanism** for what enforces a clause, never control, which is the assessor's word for the NIST item on the other side of the mapping

## The example under row-level security

`example_postgres` is the deployment that binds `Mediate.Postgres` to the example. Seven independent namings of the package, by the same method as the API's, reached these names.

| Name | Is | Rejected | Why |
|---|---|---|---|
| `example_postgres`, `ExamplePostgres`, `ExamplePostgres.Application`, `ExamplePostgres.Supervisor` | the package, its root, the boot, and the tree it starts | `ExampleRls`, `Boot` | a deployment's last segment is its engine's last segment, and OTP's names |
| `author/0`, `approval/0`, `policy_text_bytes/0` | the root's three functions, which answer the release's change-control strings and the cap on the policy text the release carries | `publish/0`, `published/1`, `content_bytes/0` | the policy migration releases the policy in its own transaction, so there is nothing for the root to publish, and the option is named for what the engine calls it |
| `load_catalog/1`, `repos/0` | the application's privates: loads the catalog when this tree started the repos, and the repos it starts | `ready/1`, `repo_children/0` | the engine's verb, and the thing the function answers |
| `ExamplePostgres.Infrastructure.Policy` | the module of the rules' expressions | `Policies`, `Expressions`, `Predicates`, `Rules` | the example's three layers, and the module is to this deployment what the policy module is to roles in code: the clauses as the engine reads them |
| **expression** | what one function of the policy module answers: the `USING` or `WITH CHECK` of one rule | predicate, condition, clause, SQL | Postgres's word |
| `repository_read/0`, `repository_checkout/0`, `directory_read/0`, `directory_change_visibility/0`, `proposal_propose_visibility/0`, `proposal_approve_visibility/0` | the expressions of the filter rules, each named table then action | `read_repositories/0`, `visible/1` | the call site in the migration reads `filter(repo, @repositories, :read, Policy.repository_read())` |
| `proposal_propose_visibility_check/0`, `change_visibility_check/0`, `approve_visibility_check/0` | the expressions a gate rule reads alone, as its `WITH CHECK` | `_gate/0`, `_with_check/0`, `_insert/0` | the suffix is the rule's own keyword, and the two on `visibilities` carry no table because that table has no filter rule to collide with |
| `admin_of_owning_team/0`, `reviewer_of_owning_team/0`, `admin_in_fresh_session/0` | the expressions several rules of `repositories` share, each named for the condition it asserts | `owning_team_admin/0`, `writes/0`, `session/0` | an expression a rule shares is named for its condition, and one a single rule owns for its rule |
| `protected_tables/0`, `reader_roles/0`, `lookup_functions/0`, `lookup_drops/0`, `schemas/0`, `app_role/0`, `owner_role/0` | what the migration and the binding read from the policy module | `tables/0`, `roles/0`, `functions/0`, `helpers/0` | each names the thing the migration hands on |
| `membership/2`, `team_role/2`, `repository_blocked/0`, `directory_blocked/0`, `blocked/2`, `blocks/3`, `in_effect/2`, `literals/1` | the privates: an `EXISTS` over `memberships`, one over `team_roles`, the blocked rows of a repository and of a directory, the `or` of every kind, one kind blocks the subject, the kind is declared or implied, and a list of SQL literals | `member/2`, `restricted/0`, `fails/3`, `quote/1` | the same five words as roles in code, and `literals/1` says what it answers |
| `@subject_id`, `@now`, `@reauthenticated_at`, `@fresh_session` | the attributes, spelled as the settings they read | `@uid`, `@clock`, `@session` | the setting's name, so a reader finds `mediate.subject_id` from `@subject_id` |
| `example_repository_project`, `example_repository_owning_team`, `example_repository_embargo` | the three SQL functions a rule on `directories` reads its repository through | `repository_project`, `mediate_lookup_project` | the application's prefix, because the function is the example's and no `mediate_` object may be the example's |
| **lookup function** | one of those three in prose | helper, security definer function, accessor | named for the job, where `SECURITY DEFINER` is how it does it |
| `a`, `e`, `v`, `l`, `t`, `m`, `p`, `r` | the SQL aliases: `accounts`, `enterprises`, `visibilities`, `labels`, `teams`, `memberships`, `projects` or `proposals`, `team_roles` | `u`, `acct`, `vis` | the table's first letter, and `r` because `t` is taken |
| `ExamplePostgres.Migrations.Domain`, `ExamplePostgres.Migrations.Policy` | the migration that raises the example's tables, and the one that writes the rules and releases the policy | `ExamplePostgres.Repo.Migrations.*`, `Rules` | no `ExamplePostgres.Repo` exists, and a rule is one line |
| `repositories/1`, `visibilities/1`, `directories/1`, `proposals/1`, `filter/4`, `gate/4`, `exempt/3`, `release_options/0` | the policy migration's privates: the rules of one table each, one rule of each kind, and the release's options | `rules_for/2`, `policy/4`, `grant/3`, `publish_options/0` | the table, or the engine's own verb for the rule |
| `priv/repo/structure.sql` | the structure file, which carries the rules as the database prints them | `priv/schema/postgres.sql` | Ecto's default path, and the same path in every deployment |
| `ExamplePostgres.ScenariosTest`, `ExamplePostgres.Infrastructure.PolicyTest`, `ExamplePostgres.GateRuleTest` | the tests: the scenario suite, the policy module's three checks, and the one property of this deployment no clause states | `CoverageTest`, `WriteGateTest`, `FactsTest` | the module under test, and the rule under test |
| `Clause`, `Mechanism`, `Scenario group` | the README's column headers | `Rule`, `Enforced by`, `Test group` | the headers of every deployment |

The module's name split the namings three ways: three said `Policy`, two `Expressions`, one each `Predicates` and `Rules`. `Policy` holds because the module is what the policy release describes, and because a reader of the roles-in-code deployment finds the same path. Five said the blocked rows are restricted, in the SQL and in the privates. Blocked holds, because the roles-in-code deployment says blocked, and one word per thing crosses deployments.

Four namings objected that `mediate_exempt_mediate_app_update` repeats the engine's prefix, once as the rule's and once as the role's. The grammar of the rule names belongs to the engine, and its row records the objection, so the deployment prints the name as the engine writes it. The same four carried forward the objections of the engine's own naming: the declared-facts check sits beside `WITH CHECK`, `Catalog.reads` could be the columns read, admit and exempt could be one rule kind, and `Binding` is the one struct whose name prose may not use for the package.

The example under row-level security, in prose:

- **deployment** for the package, never binding, thin application or harness
- **states** for what `docs/example.md` does to a clause, **enforces** for what a rule does, and **answers** for what an expression does; never implements, covers or models
- **expression** for what a function of the policy module answers, never predicate, condition or SQL
- **filter rule**, **gate rule**, **admit rule**, **exempt rule**, as the engine says them, never policy for one of them
- **blocked rows** for what the subquery answers, never restricted, denied or hidden rows
- **owner role** and **application role** for `mediate_owner` and `mediate_app`, where the code says `app_role:` because the engine does
- **admits** for what an exempt rule or an admit rule does to a statement, never allows, permits or grants
- **the boot** for the configuration's boot and the binding's bind at application start, and **loads the catalog** for what follows once the tree is up
- **the policy release** in full, which the policy migration publishes in its own transaction, never at the boot
- **structure file** for `priv/repo/structure.sql`, never schema file or the dump
- **lookup function** for the three `example_` functions, never helper or accessor
- **mechanism** for what enforces a clause, never control

## The example under policy files

`example_cerbos` is the deployment that binds `Mediate.Cerbos` to the example. Seven independent namings of the package, by the same method as the API's, reached these names.

| Name | Is | Rejected | Why |
|---|---|---|---|
| `example_cerbos`, `ExampleCerbos`, `ExampleCerbos.Application`, `ExampleCerbos.Supervisor` | the package, its root, the boot, and the tree it starts | `ExamplePolicyFiles`, `Boot` | a deployment's last segment is its engine's, so the siblings read alike |
| `author/0`, `approval/0` | the root's two functions, which answer the release's change-control strings | `@author` alone, `maintainer/0`, `approved_by/0` | the binding's option names, so a reader sees the key and the function side by side |
| `policy_dir/0`, `release/1`, `repos/0` | the application's privates: the policy directory resolved under the application, the policy release when this tree started the repos, and the repos it starts | `policies_path/0`, `publish/1`, `ready/1`, `repo_children/0` | the binding's key, the engine's verb, and the thing the function answers |
| `address:`, `policy_dir:`, `commit:`, `start_repos:`, `POLICY_COMMIT` | the configuration: the server's address, the policy directory, the commit of that directory, whether the tree starts the repos, and the variable the commit arrives in | `cerbos_url:`, `policies:`, `policy_version:`, `POLICY_SHA` | the engine's keys, spelled the same in configuration and in the binding; the commit is a commit until the engine names it the policy version |
| `ExampleCerbos.Infrastructure.Declarations` | the module that says what a policy file can read | `Attributes`, `Policy`, `Schema`, `Model` | the engine's word, from `use Mediate.Cerbos.Declarations`; and `Policy` is wrong here because the policy of this deployment is the directory of files, which no module holds |
| `employment`, `country` | the two column attributes of a principal of every kind | `employment_status`, `nationality` | the account's column names, so a policy reads the fact by the name the domain gives it |
| `project_roles`, `team_roles`, `effective_restrictions`, `releasable_to`, `enterprise_countries`, `invited`, `embargo`, `proposer_id` | the resource attributes | `rollup_countries`, `invited_list`, `embargo_until`, `restrictions` | the domain's words, with `effective` on the restrictions because the value is the derived set and not the declared column, and the plural on the countries because a rollup can hold more than one |
| **subquery attribute**, **column attribute**, **context fact** | the three things a declaration names: a value a subquery answers per subject, a value the row carries, and a value the call carries | subquery-backed attribute, dynamic attribute, static attribute, environment | the engine's `subquery:` and `column:` keys, and the core's `context` |
| `ExampleCerbos.Infrastructure.Subqueries` | the module of the subqueries behind the subquery attributes | `Facts`, `Attributes`, `Queries`, `Resolvers`, one module per resource | named for what each function answers; `Facts` was the module's name and is also the engine's check, which is one word for two things |
| `repository_project_roles/2`, `repository_team_roles/2`, `repository_effective_restrictions/2`, `repository_releasable_to/2`, `repository_enterprise_countries/2`, `repository_invited/2`, `directory_project_roles/2`, `directory_team_roles/2`, `directory_effective_restrictions/2`, `directory_releasable_to/2`, `directory_enterprise_countries/2`, `directory_invited/2`, `proposal_team_roles/2` | the thirteen subqueries, each named resource then attribute | bare attribute names on the repository, `for_directory/1` variants, a module per resource | every function reads the same way, and a declaration reads `subquery: &Subqueries.directory_invited/2` with no second lookup; the same shape as the policy module of the example under row-level security |
| `ExampleCerbos.Infrastructure.EffectiveRestrictions`, `on_repositories/0`, `on_directories/1` | the hidden module of the one derivation the policy language does not carry, and its two queries | `Restrictions`, `all/0`, `for_directories/1`, folding it into the subqueries | the example has a `Restrictions` module already; the two functions say which rows they derive over |
| `union_of/1`, `repository_restriction/1`, `directory_restriction/2` | the derivation's privates: the union over the kinds, and one kind's query per resource | `restriction_union/1`, `member/1` | the function's shape and the resource it reads |
| `access_path`, `employees_only`, `export_controlled`, `releasable_to`, `invite_only`, `admin_in_fresh_session`, `admin_of_owning_team`, `another_reviewer` | the `name:` of each rule in the policy files | `c1_access`, `deny_employees_only`, `allow_read`, `verdict_*`, numbered rules | named for the condition the rule asserts, or for the restriction kind it enforces by that kind's own name; `admin_in_fresh_session` and `admin_of_owning_team` are the shared expressions of the example under row-level security, and `another_reviewer` is the predicate rule of the example under roles in code |
| `ExampleCerbos.Migrations.Domain`, `ExampleCerbos.Migrations.Policy` | the migration that raises the example's tables, and the one that writes nothing because the policy lives in the files | `ExampleCerbos.Repo.Migrations.*`, `Rules`, dropping the second migration | the deployments' set of migrations reads alike, and the empty one is how the structure file proves the policy lives outside the database |
| `priv/repo/structure.sql` | the structure file, which carries the example's tables alone | `priv/schema/cerbos.sql` | Ecto's default path, and the same path in every deployment |
| **run directory**, **policy directory** | the directory under `tmp/` a run of the suite makes, and the directory of policy files inside it the server reads; the binding's `policy_dir` is the second | tmp dir, sandbox, workdir, the copy | two directories, two names, and the second is the engine's key read as words |
| `ExampleCerbos.ScenariosTest`, `ExampleCerbos.Infrastructure.DeclarationsTest` | the tests: the scenario suite, and the check that every column a plan reads is a declared fact | `CoverageTest`, `FactsTest`, `AttributesTest` | named for the module under test, where coverage says nothing about which property holds |
| `Clause`, `Mechanism`, `Scenario group` | the README's column headers | `Rule`, `Enforced by`, `Test group` | the headers of every deployment |

The declarations module's name split six to one: six namings said `Declarations`, one `Policy`. Six hold, because the policy of this deployment is the directory of files and a reader who finds a `Policy` module expects the policy in it. For the same reason the README's title is "The example under policy files" and not "The example under a policy server", which six of seven namings offered: the ledger's section on the engine is "Policy files", and a deployment is named for what its engine section is named.

The subqueries split three ways: three namings wanted one module per resource, two a flat module with the attribute names bare on the repository and prefixed elsewhere, two a flat module with every name prefixed. The last holds. A declaration reads the function's full name, so the function carries the resource, and the thirteen names then read like the expressions of the example under row-level security, `<resource>_<attribute>` beside `<table>_<action>`.

The rule names split between the condition and the clause: four namings named a rule for what it asserts, two for the clause it enforces, one for its verdict. The condition holds. A clause can take several rules and a rule can serve several clauses, so a clause name on a rule is a cross-reference that goes stale, and the verdict is already the rule's `effect`. A deny rule for a restriction kind takes the kind's own name, so the four deny rules and `Example.Domain.Restrictions.kinds/0` are one list.

`releasable_to` as both an attribute and a rule name split four to three. The name holds in both places, because the attribute is the list and the rule is the kind, and the two are one word in the domain already.

Six namings objected that `Mediate.Cerbos.Facts` is named for what the check reads and not for what it does, where the module checks that a plan reads declared columns only; the ledger's engine section carries that objection. Four objected to `daemon` as the key of what `Mediate.Dev.Cerbos` starts, where every sentence says server, and to `dir:` beside `policy_dir:`, where the words say run directory; both belong to `mediate_dev`. One asked for `commit:` to be `policy_version:`, which the engine's `Mediate.Cerbos.Version` answers from the commit, and the two stay two because a commit is a fact of the files and the policy version is what the engine makes of it. One asked for `embargo` to be `embargoed_until`, which is the domain's column. One noted that `roles` in a policy file carries the subject kinds and `roles` in the example carries project and team roles, which the engine's section records.

The example under policy files, in prose:

- **deployment** for the package, never binding, thin application or harness
- **states** for what `docs/example.md` does to a clause, **enforces** for what a policy file does, and **answers** for what a subquery does; never implements, covers or models
- **declarations** for the module and for what it holds, never attributes module or schema
- **subquery attribute**, **column attribute** and **context fact** for the three things a declaration names, never dynamic attribute, static attribute or environment
- **plan** for what the server answers a filter with, never query plan, AST or condition
- **server** for the Cerbos process the engine asks, never sidecar, daemon, PDP or service
- **commit** for the configured string, and **policy version** for what the engine makes of it
- **policy directory** for the directory of policy files the server reads, and **run directory** for the directory under `tmp/` that holds a run's copy of it
- **the boot** for the configuration's boot and the binding's bind at application start, and **the policy release** in full for what follows once the tree is up, never publish
- **structure file** for `priv/repo/structure.sql`, never schema file or the dump
- **mechanism** for what enforces a clause, never control

## The example under OpenFGA

`example_openfga` is the deployment that binds `Mediate.OpenFGA` to the example. Seven independent namings of the package, by the same method as the API's, reached these names.

| Name | Is | Rejected | Why |
|---|---|---|---|
| `example_openfga`, `ExampleOpenFGA`, `ExampleOpenFGA.Application`, `ExampleOpenFGA.Supervisor` | the package, its root, the boot, and the tree it starts | `example_fga`, `ExampleFga`, `ExampleGraph`, `ExampleRelationshipGraph` | a deployment's last segment is its engine's, spelled as the engine spells it; bare `fga` is a category and not the product |
| `author/0`, `approval/0`, `model_file/0` | the root's three functions: the release's two change-control strings, and the model file's path resolved under the application | `model/0`, `model_path/0`, `@model` alone | the binding's option names, so a reader sees the key and the function side by side; the model is what the server holds, the model file is the path |
| `"the Mediate maintainers"`, `"the thirteen clauses of docs/example.md"` | the author and the approval | `"example_openfga"`, `"priv/openfga/model.fga, as the model under review"` | the same strings in every deployment; a package name is not a person, and the approval names the standard the policy answers to |
| `engine/0`, `release/1`, `children/0`, `relay/0` | the application's privates: the value of the `engine:` key, the policy release when this tree started the repos, the children the tree starts, and the relay's child spec | `entry/0`, `engine_options/0`, `publish/1`, `started/0`, `drain/0`, `runner/0` | the option key, the engine's verb, the thing the function answers, and the module the spec starts; a past participle names a moment, not a list |
| `address:`, `store_id:`, `start_repos:`, `OPENFGA_ADDRESS`, `OPENFGA_STORE_ID` | the configuration: the server's address, the store, whether the tree starts the repos, and the variables the first two arrive in | `api_url:`, `FGA_API_URL`, `FGA_STORE_ID`, `url:` | the engine's keys, spelled the same in configuration and in the boot; the variables carry the engine's name |
| `"example-openfga"`, `"example-openfga-boot"`, `"example-openfga-<n>"` | the default store id, the boot store's name, and the name of a test's own store | `"mediate-example"`, `"example-fga-boot"` | the deployment's name, so a store on a shared server says which deployment made it |
| `priv/policies/model.fga` | the model file | `priv/fga/model.fga`, `priv/openfga/model.fga`, `priv/policy/model.fga`, `priv/model.fga` | every deployment keeps its policy under `priv/policies`, the directory the example under policy files already uses |
| `ExampleOpenFGA.Infrastructure.Guard`, `@fresh_session_actions` | the guard, and the closed list of actions it admits in a fresh session alone | `SessionGuard`, `@gated`, `@guarded`, `@requires_fresh_session` | the engine behaviour's name; the list is named for what its members have in common, and `gated` was a second word for guard |
| `ExampleOpenFGA.Infrastructure.Mapping`, `object_types/0`, `objects/2`, `affected/2`, `tuples/2` | the half of the mapping that reads rows, and the engine's four callbacks | `TupleMapping`, `Graph`, `Projection` | the engine behaviour's name; the callbacks have the names the behaviour gives them |
| `<type>_tuples/2`, `required/3`, `ids/2`, `held_by_accounts/2`, `repository_links/2`, `directory_links/2`, `enterprise_link/2`, `team_link/3`, `proposer_link/2`, `carried/4`, `invited/2`, `visibility/2`, `embargo/2`, `from_repository/4`, `held/4`, `moved/2`, `row/3`, `rows/2`, `@object_types`, `@employee_object` | the mapping's privates and attributes | `structure_tuples/2`, `ownership_tuples/2`, `of_repository/4`, `rows_for_repository/4`, `all/2`, `embargo_of/2`, `@employee` | one function per object type named for the type; the links form one family; `rows/2` is the plural of `row/3` and does not collide with the repo's `all/2`; the model's own word for what a directory takes is `from` |
| `ExampleOpenFGA.Infrastructure.Tuples` | the hidden half of the mapping that reads no row | `TupleKeys`, `Shapes`, a merge into `Mapping` | what a row requires once fetched, which a test holds without a database; hidden because the binding names the mapping and not this |
| `object/2`, `key/3`, `under_embargo/1`, `roles/2`, `members/2`, `implied/2`, `invited/2`, `visibility/3`, `labels/3`, `countries/2`, `restrictions/3` | the functions of that half | `named/2`, `tuple/3`, `lapsing/1`, `embargo/1`, `releases/2`, `flags/3`, `wildcards/2` | `object` is the tuple key's own field; `key/3` answers a `Mediate.OpenFGA.TupleKey`; the condition's name in the model is `under_embargo`; release is the policy release and flag is a second word for restriction |
| `@condition`, `@applies`, `@implied` | the condition's name, the relation each restriction kind applies through, and the relations a sensitive label implies | `@lapse`, `@relations`, `@wildcards` | each attribute is named for the one thing it maps to |
| `employee_applies`, `export_applies`, `country_applies`, `invite_applies`, `employee_clear`, `export_clear`, `country_clear`, `blocked_by_<stem>`, `blocked`, `access_path`, `can_<action>`, `under_embargo`, `lifts_at` | the model file's relations and condition | `regions_applies`, `regions_clear`, `blocked_by_regions`, `release_applies` | every stem names what the subject must be or hold, and the objects of the fourth kind are of type `country`; `regions` was the only word for them anywhere in the package, and `release` is the policy release |
| `ExampleOpenFGA.Migrations.Domain`, `ExampleOpenFGA.Migrations.Outbox`, `20260909000001_domain.exs`, `20260909000005_outbox.exs` | the two migrations: the example's tables, and the outbox with the relay's cursor | `ExampleFga.Repo.Migrations.Rules`, `_rules.exs`, `_policy.exs`, `_relay.exs` | the sibling scheme without the `Repo` segment; the second migration is named for what it creates, and this deployment's policy is the model the server holds, so no policy migration exists |
| `priv/repo/structure.sql` | the structure file, which carries the example's tables, the outbox, and the cursor | `priv/schema/fga.sql`, `priv/schema/openfga.sql` | Ecto's default path, and the same path in every deployment |
| `ExampleOpenFGA.Store`, `setup/1` | the module that gives a test a store of its own with the boot model in it | `StoreSetup`, `OwnStore`, `TestStore` | named for what it gives, and the function for what the case asks of it |
| `ExampleOpenFGA.OutboxStore`, `setup/2` | the module that gives an outbox test the sandbox, the application's handler back, and a store of its own | `OutboxSetup`, `OutboxSandbox` | a module is not named for its own function; it is the store an outbox test runs under |
| `ExampleOpenFGA.Population`, `write/1`, `clear/1`, `absent/1`, `change/1` | the world the cases hold the mapping to, and the engine's four callbacks | `World`, `Fixtures`, `disturb/1` | the engine behaviour's name and its callbacks |
| `ExampleOpenFGA.ScenariosTest`, `ExampleOpenFGA.OutboxTest`, `ExampleOpenFGA.Infrastructure.MappingTest`, `ExampleOpenFGA.Infrastructure.TuplesTest` | the four test modules | `ConformanceTest`, `RelayTest`, `GraphTest` | the settled scheme: one scenario suite at the root, and one test per infrastructure module; the outbox test stays at the root because it holds the engine's outbox against the mapping |
| `{:exempt, "mapping: the rows an object's tuples are read from"}`, `{:exempt, "population: the world a mapping is held to"}`, `{:exempt, "mapping test: the rows a tuple is read from"}` | the three exemptions | `"tuple mapping: ..."`, `"fga population: ..."` | the settled word is mapping, and a reason names the package by its words, not its abbreviation |
| `# The example under OpenFGA`, `Clause`, `Mechanism`, `Scenario group` | the README's title and the headers of its table | `The example on a relationship graph`, `Rule`, `Test group` | the sibling scheme, with the engine section's name; a clause is one of the thirteen, a rule is one line of a policy |

The guard's attribute split four ways, with no majority: three namings named it for what its actions require, two for the requirement itself, one for the guard's verb. The actions hold. The list is the closed set of actions C7 names, and `action in @fresh_session_actions` reads at the call site, where `@requires_fresh_session` reads as a predicate and `@gated` as a second word for guard.

The second migration departs from the siblings' `_policy.exs`, six to one. The sibling file is named for what it creates, and this one creates no policy table: the policy is the model the server holds and names by id. What it creates is the outbox and the cursor, so it is the outbox migration.

The model file's place split five ways. `priv/policies` holds, against every lens, because the example under policy files already keeps its policy there and one place for the policy in every deployment is worth more than a directory named for the engine.

Two namings asked that `Mediate.OpenFGA.Population.change/1` be `missed/1` or `unmarked/1`, because every callback changes something and this one is the change the outbox does not mark; the engine's section carries that objection. Two asked for `Mediate.OpenFGA.Version.text_hash/1` to be `digest/1`, the word the prose already uses. One asked for `reconcile/0` to be `drift/0` and `absent/1` to be `absences/1`, because each answers a thing and repairs nothing. One asked for `Guard.admits?/2` to be `holds?/2` and `Relay.pass/1` to be `deliver/1`. One asked for `address:` to be `api_url:` after the OpenFGA SDKs, and for no default `store_id` at all. One noted that `Mediate.Rbac` and `Mediate.OpenFGA` capitalise their acronyms by different rules, so the deployments inherit the difference; that the relay's `job:` key is the one word in the delivery path with no twin in prose; and that the engine's gloss for `release/0` says publishes, the verb the same list forbids. One asked for `Mediate.OpenFGA.Binding` to be `Policy`, so that no sentence about the deployment needs the word binding. All of those belong to the engine and the core, and none is settled here.

The example under OpenFGA, in prose:

- **deployment** for the package, never binding, thin application, adapter or integration
- **states** for what `docs/example.md` does to a clause and what a tuple does to a fact, **enforces** for what a mechanism does to a clause, and **requires** for what a row does to its tuples; never implements, covers or models
- **the tables as tuples** for what the mapping is, never translation, projection or tuple mapping
- **the half that reads rows** for the mapping module and **the half that reads none** for the hidden one, never layer, side or stage
- **guard** for the precondition held outside the graph, never gate, check, filter or hook
- **context fact** for `reauthenticated_at`, never environment or attribute
- **restriction** for what `Example.Domain.Restrictions.kinds/0` names and what `<kind>_applies` carries, never flag
- **object** for a thing in the store, and **resource** for a thing in the example; the two meet in the mapping and nowhere else
- **the test's own store** for what `ExampleOpenFGA.Store` creates, and **the boot store** for the one the test helper creates to read a model id from; never scratch store, shared store or sandbox store
- **marker** for one outbox row, **outbox** for the table of them, **runner** for the process that delivers, **pass** for one delivery, and **sync** for passing until no marker is left; never drain, settle, flush, queue, worker or job
- **the policy release** for what follows once the tree is up, and **model id** for its version; never publish, push or deploy
- **model** for what the server holds and **model file** for the path the binding names
- **structure file** for `priv/repo/structure.sql`, never schema file or the dump
- **mechanism** for what enforces a clause, never control

## Words in prose

The same rules hold in a document, a moduledoc, and a comment.

- **Engine**, never adapter, provider, backend, or decider.
- **Mediated repo**, never seam.
- **Policy** for the versioned whole, **rule** for one line of it.
- **Fact** for a column a rule reads, **grant** for a row that gives a subject something on a resource.
- **Consumer** for the handler a deployer attaches to the events.
- **Subject**, **resource**, **action**, **context** for the four parts of the question.
- **Requirement** for one conformance test, never law or guarantee.
- **Fail closed** for no when the system cannot decide, never deny by default, which is a rule's answer.
- **Filter fidelity** for `filter` returning the rows `authorized?` allows and no others.
- **Grantee** for the subject a fixed world grants to, never focus.
- **Protected schema** for a schema that declares a resource type, which the mediated repo refuses to read or write without a decision, never secured or object schema.
- **Deployment** for the binding of one domain to one engine, never thin application.
- **Durable repo** for the repo whose writes commit, which the latency and change-management requirements write on and whose owner repo truncates between tests, never committed repo.
- **Budget test** for a test that counts queries and events, never shape test.
- **Revocation latency** and **release latency**, never propagation latency.
- **Cluster** for the Postgres the run starts, never enclave or server, and **one cluster per run** with no adjective, never ephemeral or throwaway.
- **Sandboxed database** and **durable database**, **owner role** and **app role**, as the atoms read.
- **Server** for the Cerbos or OpenFGA process a run starts, never service, sidecar, PDP, or launcher.
- **Start** and **stop** for the cluster and the servers, never raise, provision, or launch.
- **Structure file** for what `mix mediate.dump` writes, never schema dump, snapshot, or baseline.
- **Layer** for `domain/`, `application/`, and `infrastructure/`, never place or interior.
- **Problem** for one sentence `Package.check/2` answers, never violation or finding, and **tarball** for what it builds, never deployable or artifact.
- **Roles in code** for the kind of engine `mediate_rbac` is, never RBAC in code, static RBAC, or code-based RBAC in prose, though the package keeps its name.
- **Policy module** for the module an application writes its rules in, never rules module, policy file, or ruleset.
- **Role table** for the rows `role/2` declares, and **actions** for what a role lists, never permissions, operations, or privileges.
- **Protected schema**, the core's word, for the schema a policy's `resource/2` names, never object, entity, or target.
- **Grant rule** and **predicate rule** for the two kinds of line, and **predicate** alone for the captured function.
- **Hop** for one step of a grant rule's `through:` chain, and **hop filter** for the `where:` capture that narrows it, never join, link, or hop condition.
- **Row-level security** for the mechanism `mediate_postgres` is, never RLS or Postgres policies.
- **Rule** for one row of `pg_policy` in that package's prose, and **Postgres policy** only where the SQL object is meant.
- **Filter rule**, **gate rule**, **admit rule**, and **exempt rule** for the four rules the migration helpers write, never scope policy, write policy, allow-all policy, or bypass.
- **Settings** for the `current_setting` values a call runs under, and **session settings** on first mention, never GUCs, session variables, or parameters.
- **In force** for the action a connection currently carries, never active or current.
- **Catalog** for what the database says its rules are, never snapshot, cache, or registry.
- **Action guard** for the `current_setting('mediate.action', true) = '<action>'` clause, never operation guard or predicate.
- **Protected table** for a table under forced row-level security, never secured or RLS-enabled.
- **Privileges** for what SQL's `GRANT` gives a role, never a grant.
- **Session** for the stretch of `around_query/3` the settings are in force for, never connection.
- **Replica lag** for the component of revocation latency `mediate_postgres` does not measure, never replication delay.
- **Binding** for the policy module and repo kept at boot, and **bind** for keeping it, never wiring, setup, install, or register.
- **The fact check** for what `Mediate.Rbac.Facts` does, and **a finding** for one thing it reports, never coverage, lint, audit, or violation.
- **Policy files** for the YAML a Cerbos server reads, never resource policies or bare policies.
- **Declarations** for the module a deployment writes with `use Mediate.Cerbos.Declarations`, never attribute module or mapping.
- **Attribute** for a value that travels with the request to the server, never fact or field.
- **Server** for the OpenFGA process, **store** for the tuples it holds under one id, and **address** for where it answers, never endpoint or instance.
- **Model** for the file and the id the server gives its text, never schema or DSL.
- **Tuple** for one row of the store, with its **user**, **relation**, and **object**, and **subject** and **resource** for the same things on the API's side.
- **Mapping** for the module that states tables as tuples, never tuple mapping or translation.
- **Marker** for one outbox row, and **mark** for writing one, never flag or dirty.
- **Sync** for bringing the store into step with the tables, never settle, drain, or converge.
- **Pass** for one transaction of the relay, **runner** for the process that ticks, and **cursor** and **position** for how far it has delivered, never worker, offset, or checkpoint.
- **Reconcile** and **drift** for the comparison and what it finds, never audit or diff.
- **Rebuild** for a store of its own from the tables, never backfill or seed.
- **Guard** for the precondition a deployment holds outside the graph, never gate or precondition.
- **Pinned model** for the id the configuration names, never active model or current model.
- **Relay** for the delivery from a table through a job, never outbox worker or queue.
- **Context facts** for the caller's facts that travel beside `now`, never environment or request-time facts.
- **Plan** for what the server answers for a type, never query plan or filter.
- **Compile** for turning a plan into a `dynamic`, never translate or lower, and **refused plan** for one the compiler cannot, never fallback or unsupported plan.
- **Commit** for the policy version of policy files, never ref, digest, or hash.
- **Role** for the subject kind as the server sees it, never derived role.
- **Check** for one of the modules `mediate_credo` holds, and **flags** for what a check does to a line, never lint, rule, or warns.
- **Static** for a check, which reads source text, never advisory; `Mediate.Conformance.RepoCase` is what proves at run time.
- **Unmediated repo** for a repo that `use Ecto.Repo` without `use Mediate.Repo`, never bare, plain, or unenforced repo.
- **Reaches the database around the mediated repo** for what raw SQL does, never bypasses, leaves, or escapes.
- **Excluded namespaces** for the module prefixes the raw SQL check skips, never allow list, and never exempt, which is the repo call's word.
- **Mediate** for the thing the example asks, never port, core, API, gateway, or the check.
- **Application module** for `Example.Application.*`, never context, service, use case, or boundary.
- **Clause** for one of C1 to C13, never rule, requirement, control, invariant, or constraint.
- **Scenario** for one row of the scenario table, **group** for its heading, **sentence** for its text, and **scenario suite** for a whole run, never test case, spec, story, family, or title.
- **World** for the rows every scenario starts from and **fixture** for the module that inserts them, never seed, baseline, or test data.
- **Audited override** for the mechanism, **override permission** for the row, **override read** for the call, **justification** for its text, **override report** for the row it leaves, and **override event** for what it emits, never break-glass, emergency access, bypass, or reason.
- **Rollup**, **visibility**, **restriction**, **label**, **directory**, **checkout**, **embargo**, **access path**, and **invited list** for the domain's own things, never classification, marking, clearance, aggregate, folder, clone, hold, entitlement, or allowlist; an embargo lifts.
- **Re-authentication window** for the 900 seconds, **fresh session** for a context inside it and **stale session** for one outside, never step-up, MFA, expired, timeout, or reauth.
- **Account** for the row and in every sentence, **ordinary account** for kind `:user` and **privileged account** for kind `:privileged`, and **person** only for the holder of two accounts; user is the atom and nothing else.
- **SIEM** for the consumer, **OCSF record** for one record it holds, and **security log** for the whole, never audit log, sink, exporter, or handler.
- **Admits** for what `filter` does to a row, and **allows** or **denies** for what `authorize` says, never scope, check, can, or permit.
- At boot a deployment binds the policy module and the repo, then releases the policy version. That is the sentence a README prints.

## The gate

Run this from the repository root. It must print `exit=1`. This file is the one exception, because it lists the words. `Mediate.Dev.WordsTest` reads the command from this section and runs it under `mix quality`, so a banned word fails the build, and `Mediate.NamingTest` holds every public name of the core to the tables above. A word in the list is one the prose rules above ban and no engine, library, or standard the code meets uses for something of its own, which is why actor, adapter, offset, and seed stay out of it.

```
grep -rniE --exclude=naming.md "\b(GUCs?|PDP|PEP|RLS|RBAC in code|static RBAC|code-based|active model|current model|allow list|allowlist|allow-all|attribute module|backend|backfill|break[ -]glass|checkpoint|committed repo|converge|decider|derived role|drain|emergency access|enclave|entitlement|ephemeral|exporter|hop condition|launcher|operation guard|outbox worker|permit|propagation latency|provider|query plan|reauth|replication delay|rules module|ruleset|scope policy|session variables?|settle|shape test|sidecar|sink|snapshot|step[ -]up|test case|thin application|throwaway|wiring|write policy)\b" README.md CONTRIBUTING.md CHANGELOG.md docs apps/*/README.md apps/*/lib; echo "exit=$?"
```
