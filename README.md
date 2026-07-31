# lex-oscp

OSCP (Open Smart Charging Protocol) library for the
[Lex language](https://github.com/alpibrusl/lex-lang):
grid-capacity signaling between a **Capacity Provider** (a DSO/grid
operator, or any party that owns a network constraint) and a
**Capacity Optimizer** (a CPO/EMS, or any party that manages load behind
that constraint).

**Status: scaffold.** This repo captures the architecture and file
layout this library should have — mirroring
[lex-ocpi](https://github.com/alpibrusl/lex-ocpi)'s proven shape, which
covers the sibling CPO↔eMSP roaming protocol from the same standards
lineage (both OSCP and OCPI come out of the EVRoaming
Foundation / Open Charge Alliance ecosystem and share the same
wire-level conventions: JSON over HTTPS, a token-based handshake,
versioned module registries). The module list and role names below are
corroborated from multiple public secondary sources (Open Charge
Alliance's own protocol page, vendor explainers, and the `pyoscp`
reference implementation) — **the exact per-field JSON shapes are not
yet verified against the full OSCP 2.0/2.1 specification**, which is
registration-gated on the Open Charge Alliance site. See "Before writing
schemas" below; that's the first real implementation task, not this one.

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

## What it should ship (planned)

Modules and roles per publicly available OSCP documentation (Open
Charge Alliance's OSCP protocol page, and the `pyoscp` reference
implementation's endpoint catalogue):

- **Roles**: `CapacityProvider` (supplies flexibility/capacity
  information — e.g. a DSO/TSO) and `CapacityOptimizer` (consumes
  capacity signals and manages load behind them — e.g. a CPO or EMS).
  Unlike OCPI's CPO/eMSP split (a business-role distinction), OSCP's
  split is about *which side owns the grid constraint* vs *which side
  manages assets behind it* — a CPO's EMS is typically the
  CapacityOptimizer, a DSO (or an aggregator standing in for one) is
  typically the CapacityProvider.
- **Handshake** — registration between the two parties. Like OCPI's
  credentials exchange, but OSCP's handshake additionally requires the
  initiating party to expose a `verify_url` the other side calls back
  to confirm bidirectional reachability before the registration is
  considered complete — a step OCPI's simpler async credentials flow
  doesn't have.
- **Measurements** — the CapacityOptimizer reports actual energy usage
  against its assets, so the CapacityProvider can validate that
  forecasts/limits are being respected.
- **Forecasts / VariableCapacityForecast** — the CapacityOptimizer
  submits its own anticipated demand; the CapacityProvider can use this
  to plan constraints ahead of time rather than reacting to Measurements
  alone.
- **GroupCapacityForecast** — the core push: the CapacityProvider sends
  the CapacityOptimizer a time-boxed capacity budget (a group id + a
  series of `{start_time, duration, capacity}` blocks) for the assets in
  that group. This is the message `lex-ems` needs to consume.
- **Adjustment** — the CapacityOptimizer reports back how it actually
  responded to a forecast/limit (what it curtailed, when), closing the
  loop for the CapacityProvider.
- **Assets** — the CapacityOptimizer registers which physical assets
  (EVSEs, meters — `lex-ems`'s EVSEs, concretely) belong to which
  capacity group, so a `GroupCapacityForecast` for that group maps onto
  the right EVSEs.
- **Reservations** — a newer OSCP extension point (post-2.0) for
  coordinating capacity reservations ahead of a known event; lower
  priority than the six modules above.

## Before writing schemas

The module list and roles above are corroborated from several
independent public sources, but none of them give field-level JSON
shapes — the actual OSCP 2.0/2.1 specification document is
registration-gated at
[openchargealliance.org](https://openchargealliance.org/protocols/open-smart-charging-protocol/).
**The first real implementation task is registering for that spec (or
sourcing the JSON Schema/OpenAPI files the `pyoscp` project references)
and writing `src/v20/*.lex`'s `ModelSchema` validators against the
actual field names** — the same way `lex-ocpi`'s `v221/*.lex` schemas
were written directly against OCPI's published JSON Schema docs via
`tools/gen.lex`. Don't hand-wave plausible field names into a validator
and call it done; that's exactly the kind of ad-hoc-dressed-as-standard
gap this library exists to avoid.

## Planned repository layout

Mirrors lex-ocpi's file-by-file split (pure core / effect edge, one
frames-and-schema module per spec version):

```
lex.toml
src/
  envelope.lex       Response envelope — verify against the real spec
                     before assuming it matches OCPI's
                     {data, status_code, status_message, timestamp}
                     shape; OSCP's REST endpoints may just return the
                     resource directly with an HTTP status code.
  status.lex         Status/response code constants + predicates
  error.lex          OscpError ADT
  role.lex           CapacityProvider / CapacityOptimizer
  module_id.lex      Handshake / Measurements / Forecasts /
                     GroupCapacityForecast / Adjustment / Assets /
                     Reservations
  headers.lex        Auth header (Bearer token) + any request/
                     correlation id headers OSCP defines
  group.lex          Capacity-group identifier (OSCP's grouping concept
                     — the rough equivalent of OCPI's PartyId)
  versions.lex       Version discovery, if OSCP has one (OCPI-style)
  handshake.lex       Handshake request/response types + the
                     verify_url reachability confirmation step
  route.lex          Pure handler registry + dispatch (mirrors
                     lex-ocpi's route.lex)
  route_io.lex       Effectful registry ([io, time, sql] upper bound)
  client.lex         Outbound HTTP client ([net]) + retry/backoff
                     ([net, time]), mirrors lex-ocpi's client.lex
  v20/
    enums.lex
    measurements.lex
    forecasts.lex
    group_capacity_forecast.lex
    adjustment.lex
    assets.lex
  v21/               Only once a real spec diff from 2.0 is confirmed —
                     don't duplicate v20/ speculatively.
tests/
  test_envelope.lex
  test_status.lex
  test_role.lex
  test_handshake.lex
  test_route.lex
  test_client.lex
  test_v20_schemas.lex
examples/
  capacity_provider.lex           Minimal Capacity Provider over HTTP —
                                  the "external DSO" stand-in a twin
                                  could drive against
  capacity_optimizer_client.lex   eMS-side: pushes Measurements, pulls
                                  GroupCapacityForecast, using
                                  src/client.lex
```

## Design (carried over from lex-ocpi, apply the same way here)

- **Pure-core, effect-edge.** The dispatcher, envelope construction,
  and validation never touch `[io]`/`[net]`/`[time]`; those live at the
  transport boundary (`route_io.lex`, `client.lex`, the example
  `main()` entry points). Matches lex-ocpi's `route`/`route_io` split
  and lex-ocpp's `route`/`route_io` split.
- **Constraints as variants, not closures**, for the same three payoffs
  lex-schema/lex-ocpi's README documents: `lex audit` inspectability,
  codegen-friendliness, and cheaper runtime representation than a
  closure.
- **Validators accumulate, not short-circuit** — a malformed
  `GroupCapacityForecast` should report every failing field at once,
  matching lex-schema's `PropertyConstraintViolation` shape used
  throughout lex-ocpi.

## Effect system (planned)

| Function                                     | Effects |
|-----------------------------------------------|---------|
| `envelope.encode` / `envelope.parse`          | none |
| `route.dispatch`                              | none (timestamp is an arg) |
| `v20/*.validate_*`                            | none |
| `route_io.dispatch`                           | `[io, time, sql]` |
| `client.send` / `client.get_with_token` / ... | `[net]` |
| `client.handshake`                            | `[net]` |
| `examples/capacity_provider.main`             | `[net, io, time]` |
| `examples/capacity_optimizer_client.main`     | `[net, io]` |

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

- Register for / source the actual OSCP 2.0 (and 2.1, if the deltas
  turn out to matter) specification and replace every "verify against
  spec" note above with a citation to the real field list.
- Once `envelope.lex`/`role.lex`/`module_id.lex`/`route.lex` are solid,
  wire a `lex-ems` OSCP client and a `lex-twin` "grid operator" twin as
  the first real consumer/producer pair, the same way
  `lex-ocpi`'s `client.lex` + `lex-csms`'s `ocpi_server.lex` proved out
  that library end-to-end.

## License

[EUPL-1.2](LICENSE) — to match the parent lex-lang ecosystem.
