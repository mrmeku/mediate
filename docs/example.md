# The example

*What does the example domain protect, and which scenarios prove it? For someone reading or extending the example.*

## The domain

Controlled unclassified information, CUI, is information that law protects below the classified level. A document carries a marking: the categories that say what the information is, and the dissemination controls that say who cannot receive it. An agency designates a document through one of its offices, and a program gives its members a lawful purpose to read it. A designator in the designating office can change the marking, and a different approver approves the change. The example models four controls, one per shape of subject test.

| Control | Registry marking | Test on the subject |
|---|---|---|
| `federal_only` | FED ONLY | employment is federal |
| `no_foreign` | NOFORN | nationality matches the designating agency's |
| `named_list` | DL ONLY | the subject is on the marking's list, a per-object grant |
| `releasable_to` | REL TO | nationality is in the marking's country list |

A portion is one part of a document with a marking of its own, and a document's marking is its banner, the marking under which a subject can read every portion. A redacted read returns the document without the portions the subject cannot read. `Portion` declares its own object type and is not a carried relation of `Document`, so the redacted read is one document decision, one portion `scope`, and a preload under the portion decision. Scope fidelity then holds at portion level. `Example` and the moduledocs under it have the schemas and the contexts.

## The rules

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

Each thin application's README says which mechanism enforces each rule under its binding.

## The scenarios

`Example.Scenarios.Table` holds this table as data, and the freeze test in `example` holds the module to this document row for row. Every row is a test in `Example.Scenarios`, its name is the sentence, and each of the four thin applications runs it. The Tests column names the rule, or `review` for the scenario that shows the port's review verb. An asterisk marks a citation outside the baseline.

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

## What the example decided

- **The portion is its own object type.** A carried relation of the document was the alternative. Then the document's decision would cover every portion, and a redacted read could not filter them.
- **The banner is kept at write time.** Computing it at read time was the alternative. A stored banner is one row the read policy of every adapter tests, and a write that would widen it fails in the transaction that tried.
- **The override is a declared exemption with permission, justification, event, and report in the example's code.** A rule in the adapter was the alternative. No adapter should carry a path around its own rule, and the exemption records who took it.
- **Re-authentication is an environment fact.** A session table the adapters read was the alternative. The identity layer owns the session, and the port stamps the fact on the call.
