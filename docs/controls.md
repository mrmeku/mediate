# Controls

*Which NIST line does each law, guarantee, and scenario answer? For an assessor.*

The lines are NIST SP 800-53 Rev 5 controls as the FedRAMP Rev 5 Moderate baseline selects and parameterizes them. The selections and parameter values come from the OSCAL profile `FedRAMP_rev5_MODERATE-baseline_profile.json`, read on 2026-09-14 in the oscal-compass-lab mirror of GSA's fedramp-automation repository. The control text comes from the csf.tools mirror of the Rev 5 catalog. A control cited with an asterisk in `docs/example.md` is outside the baseline, and no control in the baseline asks for a reference monitor.

A law is a row of `docs/conformance.md` under "The laws", and a guarantee is a row under "The guarantees". A scenario is a row of `docs/example.md` under "The scenarios".

## The parameters

| Parameter | Value | What it means here |
|---|---|---|
| AU-2 `au-02_odp.01` | ends "For Web applications: all administrator activity, authentication checks, authorization checks, data deletions, data access, data changes, and permission changes" | authorization checks are the decision event. Data access is the access event. Data changes, deletions, and permission changes are the change event. Administrator activity is a decision or change whose subject kind is `:privileged`. Authentication checks are the application's, outside the library |
| AU-3(1) `au-03.01_odp` | includes "characteristics that describe or identify the object or resource being acted upon" | every event carries the object type and the ids it acted on |
| AC-2(4) | "Automatically audit account creation, modification, enabling, disabling, and removal actions" | a single-row write to a schema audited as `:user` emits one change event |
| AC-6(9) | "Log the execution of privileged functions" | every decision for a `:privileged` subject carries that kind |

## The controls

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

## The consumer's lines

The library emits what these need, and the deployer's consumer satisfies them.

| Control | What the consumer does |
|---|---|
| AC-2(1), AC-2(5), AC-2(9), AC-2(12) | Automates account management, logs out inactive sessions, manages shared accounts, and monitors for atypical use, over the change and decision events |
| AU-6, AU-6(1), AU-6(3) | Reviews the records weekly and correlates across repositories |
| AU-9, AU-9(4) | Protects the records and restricts access to them |
| AU-11 | Retains the records for the period M-21-31 sets |
| CM-3(4), CM-5(5) | Puts a security representative on the change board and limits who can publish a version |
| AU-5 | Alerts on a handler failure, which telemetry reports as its own event |

A row is complete when it names a law, a guarantee, a scenario, or a consumer responsibility, and the freeze test holds the law ids.
