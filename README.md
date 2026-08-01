# lex-oscp

OSCP (Open Smart Charging Protocol) library for the
[Lex language](https://github.com/alpibrusl/lex-lang):
grid-capacity signaling between a **Capacity Provider** (a DSO/grid
operator, or any party that owns a network constraint) and a
**Capacity Optimizer** (a CPO/EMS, or any party that manages load behind
that constraint).

**Status: early, but the core schemas are real code, not just a
plan.** This repo mirrors
[lex-ocpi](https://github.com/alpibrusl/lex-ocpi)'s proven shape, which
covers the sibling CPO↔eMSP roaming protocol from the same standards
lineage (both OSCP and OCPI come out of the Open Charge Alliance
ecosystem and share the same wire-level conventions: JSON over HTTPS, a
token-based handshake, versioned module registries).

**On sourcing**: the primary OSCP 2.0/2.1 specification document is
registration-gated at
[openchargealliance.org](https://openchargealliance.org/protocols/open-smart-charging-protocol/)
— registering for it would require a real identity/company commitment
(and possibly OCA membership) that isn't something to do silently on
someone else's behalf, and its confirmation flow needs email access
this tool doesn't have anyway. Instead, `src/v20/*.lex`'s schemas below
are reconstructed from
[NOWUM/pyoscp](https://github.com/NOWUM/pyoscp) — a real, MIT-licensed,
working OSCP 2.0 implementation (an academic project, not OCA itself)
whose Flask-RestX models and endpoint routes give concrete field names,
types, and HTTP routes, not just prose descriptions. That's a large
step up from guessing plausible field names, but it is still one
implementation's reading of the spec, not the primary text — see
"Before trusting these schemas further" below for what's still open.

Companion libraries: [lex-ocpp](https://github.com/alpibrusl/lex-ocpp)
covers the CP↔CSMS side of EV charging (WebSocket-based);
[lex-ocpi](https://github.com/alpibrusl/lex-ocpi) covers the CPO↔eMSP
roaming side (HTTP/REST-based, credentials handshake, push model).
lex-oscp covers the CPO/EMS↔DSO grid-capacity side — also
HTTP/REST-based, also a handshake + push model, so the two libraries
should end up structurally close to identical.

## Role in the fleet

Today, `lex-ems` (this fleet's site-level smart-charging controller)
picks EVSE power limits with ad-hoc heuristics — an `equal` split, a
`priority` greedy fill, a hardcoded "10:00-15:00 UTC is peak PV" window
for `solar`, and a manually-configured time-window `scheduled` profile.
None of those reflect an actual, external grid constraint; they're
guesses baked into `lex-ems` itself.

lex-oscp's job is to replace that guessing with a real signal: a
Capacity Provider (a DSO, or a stand-in twin of one) pushes a
`GroupCapacityForecast` — a real, time-boxed capacity budget — into
`lex-ems`, which then uses its **existing** `equal`/`priority`
allocators to split that real budget across its EVSEs, instead of
splitting a hardcoded number. lex-oscp doesn't replace `lex-ems`'s
optimizer; it replaces the *input* to it.

## What it ships

### Roles (`src/role.lex`)

Confirmed via `pyoscp`'s namespace routing (`/cp/2.0`, `/co/2.0`,
`/fp/2.0`), not just prose:

- **`CapacityProvider`** — owns the grid constraint (a DSO/TSO, or an
  aggregator standing in for one).
- **`CapacityOptimizer`** — manages assets behind the constraint (a
  CPO/EMS — `lex-ems`, concretely, in this fleet).
- **`FlexibilityProvider`** — an optional intermediary/hub a
  CapacityProvider can forward a forecast through instead of talking to
  every CapacityOptimizer directly (the OSCP analogue of OCPI's Hub
  role). Missed in the first pass at this README, before the real
  routing was checked.

### Modules (`src/module_id.lex`, `src/v20/*.lex`)

| Module | Direction | Route (pyoscp) | Body |
|---|---|---|---|
| Register | one-time, out-of-band token exchange | — | `Register` |
| Handshake | initiator → peer | `/{cp,co,fp}/2.0/handshake` | `Handshake` |
| HandshakeAcknowledgement | peer → initiator | `/{cp,co,fp}/2.0/handshake_acknowledgement` | `HandshakeAcknowledgement` |
| Heartbeat | either → other | `/{cp,co,fp}/2.0/heartbeat` | `Heartbeat` |
| UpdateGroupCapacityForecast | CapacityProvider → CapacityOptimizer (optionally via FlexibilityProvider) | `POST /co/2.0/update_group_capacity_forecast`, `POST /fp/2.0/update_group_capacity_forecast` | `GroupCapacityForecast` — **the message `lex-ems` needs to consume** |
| AdjustGroupCapacityForecast | CapacityOptimizer → CapacityProvider | `POST /cp/2.0/adjust_group_capacity_forecast` | `GroupCapacityForecast` |
| GroupCapacityComplianceError | CapacityOptimizer → CapacityProvider | `POST /cp/2.0/group_capacity_compliance_error` | `GroupCapacityComplianceError` |
| UpdateGroupMeasurements | CapacityOptimizer → CapacityProvider | `POST /cp/2.0/update_group_measurements` | `UpdateGroupMeasurements` |
| UpdateAssetMeasurements | CapacityOptimizer → CapacityProvider | `POST /co/2.0/update_asset_measurements` | `UpdateAssetMeasurements` |

`pyoscp` also exposes `/ep` and `/epc` namespaces for a
capacity-*price* negotiation extension (`GroupCapacityPrice`,
`request_capacity_price`, `ExtForecastedBlock`) that isn't corroborated
anywhere else as a core OSCP module — left out of the table above as an
implementation-specific extension, not confirmed base spec.

### Schemas (`src/v20/enums.lex`, `handshake.lex`, `forecasts.lex`, `measurements.lex`)

Real `lex-schema` `ModelSchema` validators for every module above except
plain `Register`/`Heartbeat` wrappers (which are trivial) — 9 enum
families (`PhaseIndicator`, `AssetCategory`, `CapacityForecastType`,
etc.) and the full object graph: `RequiredBehaviour`, `VersionUrl`,
`Register`, `Handshake`, `HandshakeAcknowledgement`, `Heartbeat`,
`ForecastedBlock`, `GroupCapacityForecast`,
`GroupCapacityComplianceError`, `EnergyMeasurement`,
`InstantaneousMeasurement`, `AssetMeasurement`,
`UpdateGroupMeasurements`, `UpdateAssetMeasurements`. Covered by
`tests/test_v20_schemas.lex` (21 tests, valid + invalid-enum +
missing-required-field cases per schema).

## Before trusting these schemas further

`pyoscp`'s source gives real field names and types, which is a large
step up from the plausible-guess starting point this README shipped
with initially — but it's still one academic reference
implementation's reading of the spec, fetched through an AI
summarization tool rather than read as literal source text, so treat
the following as open until someone reads the primary OCA spec (or the
literal `pyoscp` source file) directly:

- **The Handshake flow's exact semantics.** The first version of this
  README assumed (by analogy with OCPI's async credentials flow) that
  OSCP's handshake requires the initiator to expose a `verify_url` for
  a reachability check. `pyoscp`'s registration flow, as fetched, shows
  no such step — just Handshake → 204 + HandshakeAcknowledgement → 204.
  That claim has been removed; it may still be real and simply
  unexercised by this reference implementation, or it may never have
  been accurate.
- **`AssetMeasurement`'s exact optionality** between
  `energy_measurement` and `instantaneous_measurement` (one-of, both
  optional, or something else) — currently modeled as "both optional,
  either or both present," which is a reasonable default but not
  confirmed.
- **The response envelope shape.** `pyoscp`'s endpoints return bare
  `204`/`200` with a typed body on success, or `400`/`404` — there's no
  evidence of an OCPI-style `{data, status_code, status_message,
  timestamp}` wrapper. `route.lex`'s `OscpResponse` is deliberately
  just `{status, body}`, not a generic envelope type — if the primary
  spec turns out to define one, that's a real (if smallish) design
  change to `route.lex`, `route_io.lex`, and `client.lex`'s `send`.
- **OSCP 2.1** — no deltas from 2.0 have been checked at all; don't
  create a `v21/` directory until a real diff is confirmed.

## Repository layout

Mirrors lex-ocpi's file-by-file split (pure core / effect edge, one
schema module per spec version). **Shipped** files are real, tested
code; **planned** files are not written yet.

```
lex.toml
src/
  role.lex           CapacityProvider / CapacityOptimizer /
                     FlexibilityProvider                        [shipped]
  module_id.lex      Register / Handshake / HandshakeAcknowledgement /
                     Heartbeat / UpdateGroupCapacityForecast /
                     AdjustGroupCapacityForecast /
                     GroupCapacityComplianceError /
                     UpdateGroupMeasurements / UpdateAssetMeasurements  [shipped]
  v20/
    enums.lex          9 enum families (PhaseIndicator, AssetCategory,
                       CapacityForecastType, ...)                [shipped]
    handshake.lex      RequiredBehaviour, VersionUrl, Register,
                       Handshake, HandshakeAcknowledgement, Heartbeat [shipped]
    forecasts.lex      ForecastedBlock, GroupCapacityForecast,
                       GroupCapacityComplianceError               [shipped]
    measurements.lex   EnergyMeasurement, InstantaneousMeasurement,
                       AssetMeasurement, UpdateGroupMeasurements,
                       UpdateAssetMeasurements                    [shipped]
  headers.lex        Authorization/X-Request-ID/X-Correlation-ID,
                     confirmed via pyoscp's RegistrationManager.py [shipped]
  error.lex          OscpError ADT — plain HTTP status codes (204/400/
                     404/401/403), not an OCPI-style numeric catalog [shipped]
  route.lex          Pure handler registry + dispatch, keyed by
                     (role, action) rather than OCPI's (method, module) [shipped]
  client.lex         Outbound HTTP client ([net]) + retry/backoff
                     ([net, time]) + role-scoped URL builders       [shipped]
  route_io.lex       Effectful registry ([io, time, sql] upper bound),
                     mirrors lex-ocpi's route_io.lex                [shipped]
  group.lex          Capacity-group identifier (OSCP's grouping concept
                     — the rough equivalent of OCPI's PartyId)     [planned]
  v21/               Only once a real spec diff from 2.0 is confirmed —
                     don't create speculatively.
tests/
  test_v20_schemas.lex   21 tests: valid + invalid-enum +
                         missing-required-field cases              [shipped]
  test_route.lex         6 tests: dispatch, role mismatch, validator
                         short-circuit                              [shipped]
  test_client.lex        12 tests: header builders, role_path/
                         action_url, retry classifier, backoff math [shipped]
                         (route_io.lex has no dedicated test file —
                         its dispatch logic mirrors route.lex's,
                         already covered; lex-ocpi doesn't test its
                         own route_io.lex separately either)
examples/
  capacity_provider.lex           Minimal Capacity Provider over HTTP —
                                  the "external DSO" stand-in a twin
                                  could drive against               [planned]
  capacity_optimizer_client.lex   eMS-side: pushes Measurements, pulls
                                  GroupCapacityForecast, using
                                  src/client.lex                    [planned]
```

## Design (carried over from lex-ocpi, apply the same way here)

- **Pure-core, effect-edge.** `route.lex`'s dispatcher and `v20/*.lex`'s
  validation never touch `[io]`/`[net]`/`[time]`; those live at the
  transport boundary (`route_io.lex`, `client.lex`, the example
  `main()` entry points, not yet written). Matches lex-ocpi's
  `route`/`route_io` split and lex-ocpp's `route`/`route_io` split.
- **No response envelope.** OCPI wraps every response in
  `{data, status_code, status_message, timestamp}`; OSCP, per every
  confirmed `pyoscp` endpoint, does not — success is a bare `204`, and
  `route.OscpResponse` is just `{status, body}`. Don't retrofit an
  envelope type here just because the sibling library has one — see
  "Before trusting these schemas further" above.
- **Routes keyed by (role, action), not (method, action).** Every
  confirmed `pyoscp` endpoint is POST — the HTTP verb doesn't
  distinguish anything the way it does in OCPI's REST resources. What
  *does* vary is which role namespace a message is registered under
  (the same `UpdateGroupCapacityForecast` message is a real, distinct
  route under both `/co/2.0` and `/fp/2.0`), so `route.lex` keys on
  `(role, action)` instead.
- **Handshake is asymmetric, not modeled as a client convenience.**
  `lex-ocpi`'s `client.handshake` runs the whole OCPI credentials swap
  as one synchronous call because OCPI's flow *is* synchronous.
  OSCP's Handshake → HandshakeAcknowledgement is two independent POSTs
  in opposite directions; `client.lex` deliberately has
  `send_handshake` and `send_handshake_acknowledgement` as two separate
  functions rather than one blocking round trip, so as not to
  misrepresent the actual flow.
- **Constraints as variants, not closures**, for the same three payoffs
  lex-schema/lex-ocpi's README documents: `lex audit` inspectability,
  codegen-friendliness, and cheaper runtime representation than a
  closure.
- **Validators accumulate, not short-circuit** — a malformed
  `GroupCapacityForecast` should report every failing field at once,
  matching lex-schema's `PropertyConstraintViolation` shape used
  throughout lex-ocpi.

## Effect system

| Function                                      | Effects | Status |
|------------------------------------------------|---------|--------|
| `role.*` / `module_id.*`                        | none | shipped |
| `v20/*.validate_*`                              | none | shipped |
| `headers.*` (parse/build)                       | none | shipped |
| `error.*`                                       | none | shipped |
| `route.dispatch`                                | none | shipped |
| `client.base_request` / `with_*` / `role_path` / `action_url` | none | shipped |
| `client.send` / `client.send_*` / `send_with_retry` | `[net]` (`[net, time]` for retry) | shipped |
| `route_io.dispatch`                             | `[io, time, sql]` | shipped |
| `examples/capacity_provider.main`               | `[net, io, time]` | planned |
| `examples/capacity_optimizer_client.main`       | `[net, io]` | planned |

## Pairing with lex-ems and lex-csms

- `lex-ems` is the natural CapacityOptimizer-side consumer: its
  rebalance poller would fetch (or receive a push of) a
  `GroupCapacityForecast` and feed the resulting `available_kw` into its
  existing `equal`/`priority` optimizer — no change to
  `src/optimizer.lex` itself, just a real number in place of the
  `solar`/`scheduled` guesses.
- On the CapacityProvider side, there is no real DSO to talk to in this
  fleet — a **twin** (in `lex-twin`, following the same "stand in for
  the outside world" pattern as the OCPP charge-point and eMSP
  driver-signup twins) would be the natural way to exercise
  `lex-ems`'s new OSCP client end-to-end without a live external grid
  operator: a small server built on `lex-oscp`'s `route_io` that
  periodically pushes a synthetic (but realistic) `GroupCapacityForecast`.

## Follow-ups

- If someone with access reads the primary OCA spec (or the literal,
  non-summarized `pyoscp` source) directly, resolve the three open
  items in "Before trusting these schemas further" and remove the
  hedging language from `src/v20/*.lex`'s headers.
- Wire a `lex-ems` OSCP client (using `src/client.lex`'s
  `send_group_capacity_forecast` / `send_update_group_measurements` /
  etc.) and a `lex-twin` "grid operator" twin (using
  `route.lex`/`route_io.lex` to receive them) as the first real
  consumer/producer pair — the same way `lex-ocpi`'s `client.lex` +
  `lex-csms`'s `ocpi_server.lex` proved out that library end-to-end.

## License

[EUPL-1.2](LICENSE) — to match the parent lex-lang ecosystem.
