# lex-oscp — OSCP module identifier constants
#
# PROVISIONAL: this module list (Handshake, Measurements, Forecasts,
# GroupCapacityForecast, Adjustment, Assets, Reservations) and the
# CapacityProvider/CapacityOptimizer direction of each are corroborated
# from public OSCP explainers, the Open Charge Alliance's own protocol
# page, and the pyoscp reference implementation's endpoint catalogue —
# not yet checked field-by-field against the registration-gated OSCP
# 2.0/2.1 specification text. See README "Before writing schemas"
# before treating these as wire-verified.
#
# Effects: none.
# ---- Registration --------------------------------------------------

fn handshake() -> Str {
  "Handshake"
}

# ---- Functional modules ----------------------------------------------
# CapacityOptimizer -> CapacityProvider: actual usage against assets.
fn measurements() -> Str {
  "Measurements"
}

# CapacityOptimizer -> CapacityProvider: anticipated demand.
fn forecasts() -> Str {
  "VariableCapacityForecast"
}

# CapacityProvider -> CapacityOptimizer: the core push — a time-boxed
# capacity budget per group. This is the message lex-ems needs to
# consume in place of its current solar/scheduled guesses.
fn group_capacity_forecast() -> Str {
  "GroupCapacityForecast"
}

# CapacityOptimizer -> CapacityProvider: how it actually responded to a
# forecast/limit.
fn adjustment() -> Str {
  "Adjustment"
}

# CapacityOptimizer -> CapacityProvider: which physical assets (EVSEs,
# meters) belong to which capacity group.
fn assets() -> Str {
  "Assets"
}

# Newer (post-2.0) extension point — lower priority than the six
# modules above.
fn reservations() -> Str {
  "Reservations"
}

# ---- Bulk catalog ------------------------------------------------------
fn all_modules() -> List[Str] {
  [handshake(), measurements(), forecasts(), group_capacity_forecast(), adjustment(), assets(), reservations()]
}

