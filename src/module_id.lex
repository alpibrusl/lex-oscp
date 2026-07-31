# lex-oscp — OSCP 2.0 message/endpoint identifier constants
#
# Reconstructed from NOWUM/pyoscp's oscp/{registration,cp,co,fp}_endpoints.py
# (MIT-licensed reference implementation), which gives concrete HTTP
# routes and message names — a real step up from the earlier pure
# secondary-source guess, but still not cross-checked against the
# primary OCA spec text. See README "Before writing schemas".
#
# Unlike OCPI's lowercase module ids used directly in URL paths, OSCP's
# message/type names in pyoscp are PascalCase (matching the JSON model
# titles in src/v20/*.lex); the *routes* themselves are lowercase
# snake_case action names under a role-scoped namespace
# (/cp/2.0/adjust_group_capacity_forecast, /co/2.0/update_asset_
# measurements, /fp/2.0/update_group_capacity_forecast). The constants
# below name the messages, not the URL paths — the paths belong in
# client.lex/route.lex once those exist.
#
# pyoscp also exposes /ep and /epc namespaces for a capacity-price
# negotiation extension (GroupCapacityPrice, request_capacity_price,
# ExtForecastedBlock) not corroborated elsewhere as a core OSCP module —
# treated as an implementation-specific extension, deliberately left
# out of the catalog below until confirmed against the primary spec.
#
# Effects: none.
# ---- Registration / liveness --------------------------------------------

fn register() -> Str {
  "Register"
}

fn handshake() -> Str {
  "Handshake"
}

fn handshake_acknowledgement() -> Str {
  "HandshakeAcknowledgement"
}

fn heartbeat() -> Str {
  "Heartbeat"
}

# ---- Functional modules ----------------------------------------------
# CapacityOptimizer -> CapacityProvider: actual usage against assets.
fn update_group_measurements() -> Str {
  "UpdateGroupMeasurements"
}

fn update_asset_measurements() -> Str {
  "UpdateAssetMeasurements"
}

# CapacityProvider (optionally via a FlexibilityProvider hub) ->
# CapacityOptimizer: the core push — a time-boxed capacity budget per
# group. This is the message lex-ems needs to consume in place of its
# current solar/scheduled guesses.
fn update_group_capacity_forecast() -> Str {
  "UpdateGroupCapacityForecast"
}

# CapacityOptimizer -> CapacityProvider: an adjusted/counter-proposed
# forecast, or a report of non-compliance.
fn adjust_group_capacity_forecast() -> Str {
  "AdjustGroupCapacityForecast"
}

fn group_capacity_compliance_error() -> Str {
  "GroupCapacityComplianceError"
}

# ---- Bulk catalog ------------------------------------------------------
fn all_modules() -> List[Str] {
  [register(), handshake(), handshake_acknowledgement(), heartbeat(), update_group_measurements(), update_asset_measurements(), update_group_capacity_forecast(), adjust_group_capacity_forecast(), group_capacity_compliance_error()]
}

