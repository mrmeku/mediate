# The example

*What does the example domain protect, and which scenarios prove it? For someone reading or extending the example.*

## The domain

A code host holds repositories. An enterprise owns projects and teams, a project holds repositories, and one team of the enterprise owns each repository. A repository carries a visibility: the labels that say what the code is, and the restrictions that say who cannot read it. A membership in the project, or a role in the owning team, is an account's access path to the repository. An admin of the owning team can change the visibility, and a different reviewer approves the change. The example models four restrictions, one per shape of subject test.

| Restriction | Shown as | Test on the subject |
|---|---|---|
| `employees_only` | EMPLOYEE ONLY | employment is employee |
| `export_controlled` | EXPORT | country matches the owning enterprise's |
| `invite_only` | INVITE ONLY | the subject is on the visibility's invited list, a per-object grant |
| `releasable_to` | REGIONS | country is in the visibility's country list |

EXPORT and REGIONS both read a country, and they ask two questions. EXPORT bars every subject whose country differs from the enterprise's. REGIONS requires the subject's country to be in a list the visibility carries. A subject passes both or the repository denies the read.

A directory is one part of a repository with a visibility of its own, and a repository's visibility is its rollup, the visibility under which a subject can read every directory. A checkout returns the repository without the directories the subject cannot read. `Directory` declares its own object type and is not a carried relation of `Repository`, so the checkout is one repository decision, one directory `scope`, and a preload under the directory decision. Scope fidelity then holds at directory level. `Example` and the moduledocs under it have the schemas and the contexts.

## The rules

| Rule | Statement |
|---|---|
| **C1 Access path** | `read` on a Repository requires a Membership in its Project or a TeamRole in its owning Team. |
| **C2 Restrictions, all of** | Every Restriction on the effective visibility is a test on the subject, and all must pass. |
| **C3 Sensitive labels** | A sensitive Label adds its implied Restrictions. The effective restrictions are the union of the declared and the implied. The domain copies nothing. |
| **C4 Rollup** | A Repository's rollup admits no subject that a Directory of it denies. Its Labels and Restrictions are the union of the Directories' own. Its REGIONS country list is the intersection of the lists of the Directories that carry that restriction. So no rollup releases a country one Directory withholds. A change to a Directory's visibility recomputes the rollup in one transaction, and the domain refuses a rollup that admits a subject a Directory denies. A scenario tests this at write time. |
| **C5 Embargo** | After the embargo lifts, C2 to C4 no longer apply. C1 still applies. The current time is an environment fact the port supplies. |
| **C6 Invite is a direct grant** | `invite_only` membership is per Repository per User and combines with nothing. It never overrides C1. |
| **C7 Visibility gates** | To change a visibility, to set an embargo, or to lift one, a subject must hold an `admin` role in the owning Team. |
| **C8 Re-authentication** | A C7 operation also requires a session that re-authenticated within the configured window. |
| **C9 Separation of duties** | A different reviewer must approve a visibility change that one admin proposes. |
| **C10 Audited override** | A privileged user that holds the override permission can read a Repository outside C1 with a justification. The read succeeds, always emits its own event, and reports to the owning Team. The override is never unconditional. |
| **C11 Continuous evaluation** | Every check evaluates Memberships, invited lists, employment, and country. A change deletes nothing. |
| **C12 Revocation clock** | The system enforces a revoked fact within the configured maximum delay. The test records the measured latency beside the configured maximum, and no test asserts it. |
| **C13 Scope fidelity** | `scope` returns exactly the rows for which `check` is true, for Repositories and for Directories. |

Each thin application's README says which mechanism enforces each rule under its binding.

## The scenarios

`Example.Scenarios.Table` holds this table as data, and the freeze test in `example` holds the module to this document row for row. Every row is a test in `Example.Scenarios`, its name is the sentence, and each of the four thin applications runs it. The Tests column names the rule, or `review` for the scenario that shows the port's review verb. An asterisk marks a citation outside the baseline.

| Id | Sentence | Group | Controls cited | Tests |
|---|---|---|---|---|
| `enf-01` | A User with a Membership in a Repository's Project reads it | enforcement | AC-3 | C1 |
| `enf-02` | The Repository denies a User with neither a Membership nor a TeamRole | enforcement | AC-3 | C1 |
| `enf-03` | A User with a TeamRole in the owning Team reads a Repository of that Team's Project without a Membership | enforcement | AC-3 | C1 |
| `enf-04` | An EMPLOYEE ONLY Repository denies a contractor with a Membership in its Project | enforcement | AC-3, AC-16* | C2 |
| `enf-05` | An EXPORT Repository denies a User whose country is not the owning Enterprise's | enforcement | AC-3 | C2 |
| `enf-06` | A REGIONS Repository denies a User whose country is outside its list | enforcement | AC-3 | C2 |
| `enf-07` | An INVITE ONLY Repository admits a User on its invited list and denies a User not on it | enforcement | AC-3 | C2, C6 |
| `enf-08` | A Repository with two restrictions denies a User who passes only one of them | enforcement | AC-3 | C2 |
| `enf-09` | A sensitive Label's implied restriction denies a User that the declared restrictions allow | enforcement | AC-3 | C3 |
| `enf-10` | Any User with an access path reads a Repository with no restrictions | enforcement | AC-3 | C2 |
| `enf-11` | A User outside the Enterprise's country gets a checkout that omits an EXPORT Directory and returns the rest of the Repository | enforcement | AC-3 | C4, C13 |
| `enf-12` | The domain refuses at write time a Repository visibility that drops a Directory's restriction | enforcement | AC-3, AC-16* | C4 |
| `enf-13` | After the embargo lifts a contractor with a Membership reads an EMPLOYEE ONLY Repository | enforcement | AC-3 | C5 |
| `enf-14` | Before the embargo lifts, by the port's clock, the same Repository denies the contractor | enforcement | AC-3 | C5 |
| `enf-15` | A Repository whose embargo lifted still denies a User with no access path | enforcement | AC-3 | C5, C1 |
| `enf-16` | A place on the invited list without a Membership does not grant the read | enforcement | AC-3 | C6 |
| `enf-17` | `scope` does not return a Repository of another Enterprise, and `check` does not allow it | enforcement | AC-3 | C1, C13 |
| `enf-18` | The whole Repository denies a User that one Directory releases to and another does not | enforcement | AC-3, AC-16* | C4, C2 |
| `lp-01` | A Project member without a TeamRole cannot change a Repository's visibility | least privilege | AC-6, AC-6(1) | C7 |
| `lp-02` | An admin of another Team cannot change the visibility | least privilege | AC-6(1) | C7 |
| `lp-03` | An admin of the owning Team changes the visibility | least privilege | AC-6(1) | C7 |
| `lp-04` | Only an admin sets an embargo date or lifts an embargo | least privilege | AC-6(1) | C7 |
| `lp-05` | A Directory's visibility change needs an admin of the Repository's owning Team | least privilege | AC-6(1) | C7, C4 |
| `lp-06` | An ordinary account cannot invoke the override | least privilege | AC-6(10) | C10 |
| `lp-07` | A privileged account is a separate account, and the same person's ordinary account cannot override | least privilege | AC-6(2) | C10 |
| `lp-08` | The access review lists every privileged account and every permission a role holds | least privilege | AC-6(5), AC-2(7) | C7, C10 |
| `sod-01` | A different reviewer approves the visibility change an admin proposes | separation of duties | AC-5 | C9 |
| `sod-02` | The proposer, who is also a reviewer, cannot approve their own proposal | separation of duties | AC-5 | C9 |
| `sod-03` | A proposal without approval does not change the visibility | separation of duties | AC-5, CM-5 | C9 |
| `rev-01` | A revoked Membership denies the next check, and the test records the latency and its components and never asserts them | revocation and expiry | AC-2, PS-4, AC-3(8)* | C11, C12 |
| `rev-02` | Removal from an INVITE ONLY list denies the next read | revocation and expiry | AC-2, AC-2(1) | C11 |
| `rev-03` | A change of employment from employee to contractor denies an EMPLOYEE ONLY read at the next check | revocation and expiry | AC-2, PS-5 | C11 |
| `rev-04` | A corrected country applies at the next check | revocation and expiry | AC-2, AC-16* | C11 |
| `rev-05` | An archived Project revokes every Membership's access path at the next check | revocation and expiry | AC-2, AC-2(3) | C11 |
| `rev-06` | A revocation deletes only the fact, the Repository and the Project remain, and the grant and the revoke each emit a change event | revocation and expiry | AC-2(4) | C11 |
| `rvw-01` | The access review lists who can read what today, per Enterprise | access review | AC-2, AC-6(7) | `review` |
| `ia-01` | An admin whose session re-authenticated within the window changes a visibility | re-authentication | IA-11 | C8 |
| `ia-02` | An admin whose session is older than the window cannot change a visibility until re-authentication | re-authentication | IA-11 | C8 |
| `ia-03` | The port refuses a visibility change that has no re-authentication fact | re-authentication | IA-11 | C8 |
| `ovr-01` | A privileged user with the override permission reads outside C1 with a justification, and the read emits an event and reports to the owning Team | emergency override | AC-6(9), AU-6 | C10 |
| `ovr-02` | The override refuses a call without a justification | emergency override | AC-6(9) | C10 |
| `ovr-03` | The override never reaches C7, and a privileged user cannot change a visibility through it | emergency override | AC-6(9), AC-6(1) | C10, C7 |

## What the example decided

- **The directory is its own object type.** A carried relation of the repository was the alternative. Then the repository's decision would cover every directory, and a checkout could not filter them.
- **The rollup is kept at write time.** Computing it at read time was the alternative. A stored rollup is one row the read policy of every adapter tests, and a write that would widen it fails in the transaction that tried.
- **The override is a declared exemption with permission, justification, event, and report in the example's code.** A rule in the adapter was the alternative. No adapter should carry a path around its own rule, and the exemption records who took it.
- **Re-authentication is an environment fact.** A session table the adapters read was the alternative. The identity layer owns the session, and the port stamps the fact on the call.
