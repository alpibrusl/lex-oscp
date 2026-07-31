# lex-oscp — OSCP 2.0 capacity-forecast module
#
# Reconstructed from NOWUM/pyoscp's oscp/json_models.py and
# oscp/{cp,co,fp}_endpoints.py (MIT-licensed reference implementation)
# — not yet checked against the primary OCA spec text, see README
# "Before writing schemas".
#
# GroupCapacityForecast is the core message this whole library exists
# for: a CapacityProvider's time-boxed capacity budget for one group of
# assets, forwarded (optionally through a FlexibilityProvider hub) to
# the CapacityOptimizer that manages those assets — lex-ems, concretely,
# once this is wired up for real.
#
# Confirmed wire routes (pyoscp):
#   POST /co/2.0/update_group_capacity_forecast   body: GroupCapacityForecast
#   POST /fp/2.0/update_group_capacity_forecast   body: GroupCapacityForecast
#   POST /cp/2.0/adjust_group_capacity_forecast   body: GroupCapacityForecast
#   POST /cp/2.0/group_capacity_compliance_error  body: GroupCapacityComplianceError
#
# Effects: none.

import "std.list" as list

import "lex-schema/json_value" as jv

import "lex-schema/schema" as s

import "lex-schema/error" as e

import "./enums" as en

# ---- ForecastedBlock -----------------------------------------------------
# One time-boxed capacity value. capacity's sign/meaning depends on
# `type` (a CONSUMPTION forecast's capacity is a ceiling; a GENERATION
# forecast's is a floor — confirm exact semantics against the primary
# spec before an actual CapacityOptimizer implementation relies on it).
fn forecasted_block_schema() -> s.ModelSchema {
  { title: "ForecastedBlock", description: "OSCP 2.0 — one time-boxed capacity value within a GroupCapacityForecast", fields: [s.required_float("capacity", []), s.required_str("phase", [StrOneOf(en.all_phase_indicator())]), s.required_str("unit", [StrOneOf(en.all_forecasted_block_unit())]), s.required_str("start_time", [StrNonEmpty]), s.required_str("end_time", [StrNonEmpty])] }
}

fn validate_forecasted_block(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(forecasted_block_schema(), j)
}

# ---- GroupCapacityForecast ------------------------------------------------
fn group_capacity_forecast_schema() -> s.ModelSchema {
  { title: "GroupCapacityForecast", description: "OSCP 2.0 — a capacity budget, as a series of ForecastedBlocks, for one asset group", fields: [s.required_str("group_id", [StrNonEmpty]), s.required_str("type", [StrOneOf(en.all_capacity_forecast_type())]), s.required_array("forecasted_blocks", KObject(forecasted_block_schema()), [ListNonEmpty])] }
}

fn validate_group_capacity_forecast(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(group_capacity_forecast_schema(), j)
}

# ---- GroupCapacityComplianceError -----------------------------------------
# Sent CapacityOptimizer -> CapacityProvider when the optimizer cannot
# (or did not) comply with a previously received forecast.
fn group_capacity_compliance_error_schema() -> s.ModelSchema {
  { title: "GroupCapacityComplianceError", description: "OSCP 2.0 — reported when a CapacityOptimizer cannot comply with a GroupCapacityForecast", fields: [s.required_str("message", [StrNonEmpty]), s.required_array("forecasted_blocks", KObject(forecasted_block_schema()), [])] }
}

fn validate_group_capacity_compliance_error(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(group_capacity_compliance_error_schema(), j)
}

