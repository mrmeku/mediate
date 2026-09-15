# The example

*The CUI domain the four thin applications share, its thirteen rules, and the scenario table every binding runs. This document shows how an application expresses its needs through the port under each adapter. `docs/conformance.md` holds what the suite asserts about the port itself.*

## 1. The domain

Controlled unclassified information, CUI, is information that law protects below the classified level. A document carries a marking. The marking has the categories that say what the information is, and the dissemination controls that say who cannot receive it. An agency designates a document through one of its offices. A program gives its members a lawful purpose to read the document. A designator in the designating office is the person who can change its marking.

| Term | Meaning |
|---|---|
| Document | The protected record: a title, a designating office, a program, a decontrol date, a marking, portions, and proposals |
| Portion | One part of a document, with a marking of its own. The redacted read returns the portions the subject can read |
| Marking | The categories, the controls, and the releasable-to list that a portion carries and that a document's banner combines |
| Banner | A document's marking. It admits no subject that a portion of the document denies, and the domain keeps it at write time (C4) |
| Control | One dissemination control: `federal_only`, `no_foreign`, `named_list`, or `releasable_to`. Each is a test on the subject (C2) |
| Category | A CUI category. A specified category implies controls that count as declared (C3) |
| Decontrol | The date after which C2 to C4 no longer apply to a document. C1 still applies (C5) |
| Named list | The users a marking names directly. Membership grants nothing beyond C1 (C6) |
| Program | The unit an assignment belongs to. An open program gives lawful purpose to its members (C1) |
| Assignment | A user's role in a program: `member` or `lead` |
| Office role | A user's role in an office: `designator` or `approver` (C7, C9) |
| Designating office | The office that designated a document. It receives the document's override reports |
| Designating agency | The agency the designating office belongs to |
| Proposal | A marking change that one designator proposes and a different approver approves (C9) |
| Override | A privileged read outside C1, with a justification, its own event, and a report (C10) |
| Privileged account | An account of kind `:privileged`, separate from the person's user account, that can hold the override permission |
| Re-authentication | The `reauthenticated_at` fact the identity layer supplies |
| Window | How recent the re-authentication must be for a C7 operation (C8). It is the organization's IA-11 parameter |
| Redacted read | The document without the portions the subject cannot read |
| SIEM | The consumer of the library's three events. It holds one OCSF record per decision, change, and access in memory |
| Access review | The report of who can do what on each agency's documents, and of every privileged account |
| Fixture | The world every scenario starts from: two agencies, offices, programs, categories, and one account per role |
| Scenario | One row of §4. A thin application's test module defines it with `use Example.Scenarios` |
| Thin application | The binding of this domain to one adapter: `example_rbac`, `example_postgres`, `example_cerbos`, or `example_fga` |

## 2. Dissemination controls and the portion

A category says what the information is. A control says who cannot receive it, below the default that anyone with a lawful government purpose can. The Registry allows a fixed set of controls. A document can carry several, and all of them must hold. The example models four, one per shape of subject test. FEDCON, NOCON, DISPLAY ONLY, and the attorney markings are the same shapes with other values.

| Control | Registry marking | Test on the subject |
|---|---|---|
| `federal_only` | FED ONLY | employment is federal |
| `no_foreign` | NOFORN | nationality matches the designating agency's |
| `named_list` | DL ONLY | the subject is on the marking's list, a per-object grant |
| `releasable_to` | REL TO | nationality is in the marking's country list |

**The portion.** `Portion(document_id, marking: Marking)` is a row under `Document`, and a document can have no portions. The document's marking is its banner, the marking under which a subject can read every one of its portions. Rule C4 says so, and the domain enforces it at write time. `Portion` declares its own object type and is not a carried relation of `Document`. Its `marking` is a fact field of kind `:object_attribute`.

A document has two read operations. `read` returns the whole document under the banner. It is one Document decision under C1 and C2 over the banner. `read_redacted` returns the document without the portions the subject cannot read. It takes three steps:

- a Document decision under C1, `authorize(subject, :read_redacted, document)`
- a Portion `scope`, `scope(subject, :read, Portion)`
- a preload that applies the scope's `dynamic` to the portions query, `Repo.preload(document, :portions, mediate: portion_decision)`

`Portion` is not carried, so the seam refuses a preload without a decision of its own (`docs/design.md` §4). Scope fidelity, C13, holds at portion level. The portions the read returns are exactly those for which `check(subject, :read, portion)` is true. Each adapter filters portions as rows of their own under a policy of their own:

| Adapter | Portion mechanism |
|---|---|
| `mediate_rbac` | a `read` operation on `Portion` whose predicates are the document predicates over the portion's marking |
| `mediate_postgres` | a second row-level security policy on the `portions` table. Postgres does not consult the `documents` policy for portion rows |
| `mediate_cerbos` | a `portion` resource kind with its own policy. The adapter answers `scope` over portions with derived markings per portion |
| `mediate_fga` | a `portion` type with a `document` parent, the control flags on the portion, and `can_read: lawful_purpose from document but not blocked` |

## 3. The rules

The thirteen rules of the example's domain, as a person wrote them. §1 defines the words they use.

| Rule | Statement |
|---|---|
| **C1 Lawful purpose** | `read` on a Document requires an Assignment to its Program or an OfficeRole in its designating Office. |
| **C2 Controls, all of** | Every Control on the effective marking is a test on the subject, and all must pass. |
| **C3 Specified categories** | A Specified category adds its implied Controls. The effective controls are the union of the declared and the implied. The domain copies nothing. |
| **C4 Banner** | A Document's banner admits no subject that a Portion of it denies. Its Categories and Controls are the union of the Portions' own. Its REL TO country list is the intersection of the lists of the Portions that carry that control. So no banner releases a country one Portion withholds. A change to a Portion's marking recomputes the banner in one transaction, and the domain refuses a banner that admits a subject a Portion denies. A scenario tests this at write time. |
| **C5 Decontrol** | After the decontrol date or event, C2 to C4 no longer apply. C1 still applies. The current time is an environment fact the port supplies. |
| **C6 Named list is a direct grant** | `named_list` membership is per Document per User and combines with nothing. It never overrides C1. |
| **C7 Marking gates** | To change a marking, to set a decontrol, or to decontrol, a subject must hold a `designator` role in the designating Office. |
| **C8 Re-authentication** | A C7 operation also requires a session that re-authenticated within the configured window. |
| **C9 Separation of duties** | A different approver must approve a marking change that one designator proposes. |
| **C10 Audited override** | A privileged user that holds the override permission can read a Document outside C1 with a justification. The read succeeds, always emits its own event, and reports to the designating Office. The override is never unconditional. |
| **C11 Continuous evaluation** | Every check evaluates Assignments, list membership, employment, and nationality. A change deletes nothing. |
| **C12 Revocation clock** | The system enforces a revoked fact within the configured maximum delay. The test records the measured latency beside the configured maximum, and no test asserts it. |
| **C13 Scope fidelity** | `scope` returns exactly the rows for which `check` is true, for Documents and for Portions. |

**What enforces each rule.** Each thin application's README carries a table of the rules against what enforces each under that binding. That is the engine, the seam, the adapter, or the application's own code. A person writes and keeps that table, and no code reads it. The `scenario` macro tags each test with its scenario id, the rule it tests, and the controls §4 cites for that id. So a control id appears once, in §4, and a run reports from the tags.

**Where the adapters differ.**

- Write gates without application code: Postgres only. The database refuses a marking change that violates C7 whether or not the application asked. That is a property of Postgres and not a rule, and no scenario tests it.
- Rules that non-developers own, versioned and tested as an artifact of their own: Cerbos only.
- What an answer names: Cerbos names the policy it matched, code names the clause, and OpenFGA names the relation. Postgres names the policy of the operation, because the database does not report which policy admitted a row.
- Derived markings, C3 and C4 through portions: Cerbos plans over the attributes the adapter sends alone. So the derivation lives in the subquery a declaration names and not in the policy. OpenFGA walks them as a tuple-to-userset. Neither copies anything.
- Request-time facts, C5 and C8: every adapter answers them. Postgres threads them through session settings. OpenFGA takes C5 as a tuple condition with the moment in the check context, and its adapter takes C8 from the environment before the call.
- OpenFGA alone: C9 is `approver from office but not proposer`, and `scope` is `ListObjects` under a cap. `apps/example_fga/priv/fga/model.fga` has the model, and the `example_fga` README has the tuple mapping.

## 4. The scenarios

`Example.Scenarios.Table` holds this table as data. The freeze test in `example` holds the module to this document row for row. Every row is a test in `Example.Scenarios`, and its name is the sentence. The `scenario` macro writes it, `scenario "enf-01", "<sentence>", rule: :c1 do ... end`, and each of the four thin applications runs it.

The Tests column names the C-rule, or `review` for the scenario that shows the port's review verb. An asterisk marks a citation outside the baseline. No scenario tests the events, the seam, or a policy version, because the laws of `docs/conformance.md` assert those for every adapter.

| Id | Sentence | Group | Controls cited | Tests |
|---|---|---|---|---|
| `enf-01` | A User with an Assignment to a Document's Program reads it | enforcement | AC-3 | C1 |
| `enf-02` | The Document denies a User with neither an Assignment nor an OfficeRole | enforcement | AC-3 | C1 |
| `enf-03` | A User with an OfficeRole in the designating Office reads a Document of that Office's Program without an Assignment | enforcement | AC-3 | C1 |
| `enf-04` | A FED ONLY Document denies a contractor with an Assignment to its Program | enforcement | AC-3, AC-16* | C2 |
| `enf-05` | A NOFORN Document of a domestic Agency denies a foreign national | enforcement | AC-3 | C2 |
| `enf-06` | A REL TO Document denies a User whose nationality is outside its list | enforcement | AC-3 | C2 |
| `enf-07` | A DL ONLY Document admits a User on its list and denies a User not on it | enforcement | AC-3 | C2, C6 |
| `enf-08` | A Document with two controls denies a User who passes only one of them | enforcement | AC-3 | C2 |
| `enf-09` | A Specified category's implied control denies a User that the declared controls allow | enforcement | AC-3 | C3 |
| `enf-10` | Any User with a lawful purpose reads a Document with no controls | enforcement | AC-3 | C2 |
| `enf-11` | A foreign national's redacted read omits a NOFORN Portion and returns the rest of the Document | enforcement | AC-3 | C4, C13 |
| `enf-12` | The domain refuses at write time a Document marking that drops a Portion's control | enforcement | AC-3, AC-16* | C4 |
| `enf-13` | After the decontrol date a contractor with an Assignment reads a FED ONLY Document | enforcement | AC-3 | C5 |
| `enf-14` | Before the decontrol date, by the port's clock, the same Document denies the contractor | enforcement | AC-3 | C5 |
| `enf-15` | A decontrolled Document still denies a User with no lawful purpose | enforcement | AC-3 | C5, C1 |
| `enf-16` | DL ONLY membership without an Assignment does not grant the read | enforcement | AC-3 | C6 |
| `enf-17` | `scope` does not return a Document of another Agency, and `check` does not allow it | enforcement | AC-3 | C1, C13 |
| `enf-18` | The whole Document denies a User that one Portion releases to and another does not | enforcement | AC-3, AC-16* | C4, C2 |
| `lp-01` | A Program member without an OfficeRole cannot change a Document's marking | least privilege | AC-6, AC-6(1) | C7 |
| `lp-02` | A designator of another Office cannot change the marking | least privilege | AC-6(1) | C7 |
| `lp-03` | A designator of the designating Office changes the marking | least privilege | AC-6(1) | C7 |
| `lp-04` | Only a designator sets a decontrol date or decontrols a Document | least privilege | AC-6(1) | C7 |
| `lp-05` | A Portion's marking change needs a designator of the Document's designating Office | least privilege | AC-6(1) | C7, C4 |
| `lp-06` | An ordinary account cannot invoke the override | least privilege | AC-6(10) | C10 |
| `lp-07` | A privileged account is a separate account, and the same person's ordinary account cannot override | least privilege | AC-6(2) | C10 |
| `lp-08` | The access review lists every privileged account and every permission a role holds | least privilege | AC-6(5), AC-2(7) | C7, C10 |
| `sod-01` | A different approver approves the marking change a designator proposes | separation of duties | AC-5 | C9 |
| `sod-02` | The proposer, who is also an approver, cannot approve their own proposal | separation of duties | AC-5 | C9 |
| `sod-03` | A proposal without approval does not change the marking | separation of duties | AC-5, CM-5 | C9 |
| `rev-01` | A revoked Assignment denies the next check, and the test records the latency and its components and never asserts them | revocation and expiry | AC-2, PS-4, AC-3(8)* | C11, C12 |
| `rev-02` | Removal from a DL ONLY list denies the next read | revocation and expiry | AC-2, AC-2(1) | C11 |
| `rev-03` | A change of employment from federal to contractor denies a FED ONLY read at the next check | revocation and expiry | AC-2, PS-5 | C11 |
| `rev-04` | A corrected nationality applies at the next check | revocation and expiry | AC-2, AC-16* | C11 |
| `rev-05` | A closed Program revokes every Assignment's lawful purpose at the next check | revocation and expiry | AC-2, AC-2(3) | C11 |
| `rev-06` | A revocation deletes only the fact, the Document and the Program remain, and the grant and the revoke each emit a change event | revocation and expiry | AC-2(4) | C11 |
| `rvw-01` | The access review lists who can read what today, per Agency | access review | AC-2, AC-6(7) | `review` |
| `ia-01` | A designator whose session re-authenticated within the window changes a marking | re-authentication | IA-11 | C8 |
| `ia-02` | A designator whose session is older than the window cannot change a marking until re-authentication | re-authentication | IA-11 | C8 |
| `ia-03` | The port refuses a marking change that has no re-authentication fact | re-authentication | IA-11 | C8 |
| `ovr-01` | A privileged user with the override permission reads outside C1 with a justification, and the read emits an event and reports to the designating Office | emergency override | AC-6(9), AU-6 | C10 |
| `ovr-02` | The override refuses a call without a justification | emergency override | AC-6(9) | C10 |
| `ovr-03` | The override never reaches C7, and a privileged user cannot change a marking through it | emergency override | AC-6(9), AC-6(1) | C10, C7 |

## 5. What each binding says

Each thin application's README carries two tables: what enforces each rule under that binding, and the translation from this domain's words to the adapter's. A person keeps those tables, and no code reads them.
