# Requirements

*The requirement lines that reach this library, where each comes from, and what answers it. One row per applicable line. A person maintains it, and no code reads it.*

## 1. Source

NIST SP 800-53 Rev 5, as the FedRAMP Rev 5 Moderate baseline selects and parameterizes it. A control is one numbered requirement of the catalog, and an enhancement is a numbered part of one, such as AC-2(4). The baseline is the set of controls FedRAMP selects for one impact level. An organization-defined parameter, ODP, is a value the baseline fills into a control's text.

The selections and parameter values below come from the OSCAL profile `FedRAMP_rev5_MODERATE-baseline_profile.json`, read on 2026-09-14 in the oscal-compass-lab mirror of GSA's fedramp-automation repository. The control text comes from the csf.tools mirror of the Rev 5 catalog. FedRAMP 20x key security indicators are a cross-reference and not a source.

**Selected in the Moderate baseline**, of the controls this repository cites: AC-2, AC-2(1), AC-2(2), AC-2(3), AC-2(4), AC-2(5), AC-2(7), AC-2(9), AC-2(12), AC-2(13), AC-3, AC-5, AC-6, AC-6(1), AC-6(2), AC-6(5), AC-6(7), AC-6(9), AC-6(10), AU-2, AU-3, AU-3(1), AU-6, AU-6(1), AU-6(3), AU-9, AU-9(4), AU-11, AU-12, CM-3, CM-3(2), CM-3(4), CM-5, CM-5(1), CM-5(5), IA-11, PS-4, PS-5.

**In no baseline**, and cited by nothing here: AC-3(7), AC-3(8), AC-16, AC-25. No control in the baseline asks for a reference monitor, and this library does not claim one.

**Parameters that bind the library.**

| Parameter | Value | What it means here |
|---|---|---|
| AU-2 `au-02_odp.01` | ends "For Web applications: all administrator activity, authentication checks, authorization checks, data deletions, data access, data changes, and permission changes" | authorization checks are the decision event. Data access is the access event. Data changes, deletions, and permission changes are the change event. Administrator activity is a decision or change whose subject kind is `:privileged`. Authentication checks are the application's, outside the library |
| AU-3(1) `au-03.01_odp` | includes "characteristics that describe or identify the object or resource being acted upon" | every event carries the object type and the ids it acted on |
| AC-2(4) | "Automatically audit account creation, modification, enabling, disabling, and removal actions" | a single-row write to a schema audited as `:user` emits one change event |
| AC-6(9) | "Log the execution of privileged functions" | every decision for a `:privileged` subject carries that kind |

## 2. The table

A law is a Tier 1 conformance test in `Mediate.Conformance.AdapterCase`. Every adapter runs it against its real engine, and `docs/conformance.md` §2 carries the frozen list with each law's sentence. `Mediate.Conformance.RepoCase` asserts a guarantee `E1` to `E5` against a repo, and `docs/conformance.md` §5 carries those. A scenario id names a row of the example's table in `docs/example.md` §4. A scenario shows a domain rule and asserts nothing neutral. The vocabulary of a law is the neutral fixture's: subject `{kind, id}`, object `{type, id}`, operation, grant (a membership row), fact (clearance, role, expiry, kind), decision, event.

| Control | Answered by |
|---|---|
| AC-2, AC-2(4) | `ac2-01` |
| AC-2(2), AC-2(3) | `ac2-02` |
| AC-2(3), PS-5 | `ac2-03` |
| AC-2(7), AC-6(7) | `ac2-04` |
| AC-2(13), PS-4 | `ac2-05` |
| AC-3 | `ac3-01` |
| AC-3 | `ac3-02` |
| AC-3 | `ac3-03` |
| AC-3 | `ac3-04` |
| AC-3 | `ac3-05` |
| AC-6(2) | `ac6-01` |
| AC-6(9) | `au2-01`, for the subject of kind `:privileged` it denies |
| AU-2 | `au2-01` |
| AU-2 | `au2-02` |
| AU-2 | `au2-03` |
| AU-3 | `au3-01` |
| AU-3 | `au3-02` |
| AU-3 | `au3-03` |
| AU-3(1) | `au3-04` |
| AU-12, AC-2(4) | `au12-01`, `E1` |
| AU-12 | `au12-02`, `E2` |
| AU-12 | `au12-03`, `E3` |
| AU-12 | `au12-04` |
| AU-12 | `au12-05` |
| AU-12 | `au12-06`, `E5` |
| AU-12 | `au12-07`, one coverage test per adapter |
| CM-3, CM-5 | `cm3-01` |
| CM-3(2) | `cm3-02` |
| CM-5(1) | `cm3-03` |
| CM-3(2) | `cm3-04` |
| AC-5 | `sod-01` to `sod-03`, separation of duties in the example |
| AC-6, AC-6(1), AC-6(5), AC-6(10) | `lp-01` to `lp-08`, least privilege in the example |
| IA-11 | `ia-01` to `ia-03`, re-authentication in the example |
| AC-6(9), AU-6 | `ovr-01` to `ovr-03`, the audited override in the example |

## 3. The consumer's lines

The library emits what these need. The deployer's system, the consumer that attaches to the events, satisfies them.

| Control | What the consumer does |
|---|---|
| AC-2(1), AC-2(5), AC-2(9), AC-2(12) | Automates account management, logs out inactive sessions, manages shared accounts, and monitors for atypical use, over the change and decision events |
| AU-6, AU-6(1), AU-6(3) | Reviews the records weekly and correlates across repositories |
| AU-9, AU-9(4) | Protects the records and restricts access to them |
| AU-11 | Retains the records for the period M-21-31 sets |
| CM-3(4), CM-5(5) | Puts a security representative on the change board and limits who can publish a version |
| AU-5 | Alerts on a handler failure, which telemetry reports as its own event |

## 4. What keeps a row honest

A row is complete when its control line has a law, a guarantee, an example scenario, or a stated consumer responsibility. Every law id here exists in `Mediate.Conformance.Law.all/0`, which the freeze test holds to `docs/conformance.md`. Check a control number against the catalog before you publish this file. A row that cites a control outside the baseline is a review failure.
