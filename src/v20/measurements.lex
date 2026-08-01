# lex-oscp — OSCP 2.0 measurements module
#
# Reconstructed from NOWUM/pyoscp's oscp/json_models.py and
# oscp/{cp,co}_endpoints.py (MIT-licensed reference implementation) —
# not yet checked against the primary OCA spec text, see README
# "Before writing schemas".
#
# Two measurement shapes exist: EnergyMeasurement (a metered quantity
# over an interval — has both a measure_time and an
# initial_measure_time) and InstantaneousMeasurement (a single reading
# at one instant — measure_time only, no energy_type/direction).
# AssetMeasurement's exact optionality between the two (whether an
# instance carries one or the other, or both) is not confirmed from
# the fetched source — treat both fields on AssetMeasurement as
# optional until checked against pyoscp's literal source or the
# primary spec.
#
# Confirmed wire route (pyoscp):
#   POST /cp/2.0/update_group_measurements  body: UpdateGroupMeasurements
#
# pyoscp's own routing puts UpdateAssetMeasurements under
# /co/2.0/update_asset_measurements — the CapacityOptimizer's own
# namespace, even though it documents the same "CapacityOptimizer
# reports actual usage against assets to the CapacityProvider"
# direction as UpdateGroupMeasurements (see module_id.lex's catalog).
# Read as an inconsistency in the reference implementation rather than
# a real protocol distinction — client.lex routes both messages to
# role.capacity_provider() (POST /cp/2.0/update_asset_measurements),
# following the documented standard direction rather than pyoscp's
# routing quirk. Flag this for correction if the primary OCA spec text
# ever becomes available to check against.
#
# Effects: none.

import "std.list" as list

import "lex-schema/json_value" as jv

import "lex-schema/schema" as s

import "lex-schema/error" as e

import "./enums" as en

# ---- EnergyMeasurement -----------------------------------------------------
fn energy_measurement_schema() -> s.ModelSchema {
  { title: "EnergyMeasurement", description: "OSCP 2.0 — a metered energy quantity over an interval", fields: [s.required_float("value", []), s.required_str("phase", [StrOneOf(en.all_phase_indicator())]), s.required_str("unit", [StrOneOf(en.all_energy_measurement_unit())]), s.required_str("energy_type", [StrOneOf(en.all_energy_type())]), s.required_str("direction", [StrOneOf(en.all_energy_flow_direction())]), s.required_str("measure_time", [StrNonEmpty]), s.required_str("initial_measure_time", [StrNonEmpty])] }
}

fn validate_energy_measurement(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(energy_measurement_schema(), j)
}

# ---- InstantaneousMeasurement -----------------------------------------------
fn instantaneous_measurement_schema() -> s.ModelSchema {
  { title: "InstantaneousMeasurement", description: "OSCP 2.0 — a single point-in-time reading", fields: [s.required_float("value", []), s.required_str("phase", [StrOneOf(en.all_phase_indicator())]), s.required_str("unit", [StrOneOf(en.all_instantaneous_measurement_unit())]), s.required_str("measure_time", [StrNonEmpty])] }
}

fn validate_instantaneous_measurement(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(instantaneous_measurement_schema(), j)
}

# ---- AssetMeasurement --------------------------------------------------------
fn asset_measurement_schema() -> s.ModelSchema {
  { title: "AssetMeasurement", description: "OSCP 2.0 — a measurement tied to one physical asset (an EVSE, in lex-ems terms)", fields: [s.required_str("asset_id", [StrNonEmpty]), s.required_str("asset_category", [StrOneOf(en.all_asset_category())]), s.optional(s.required_object("energy_measurement", energy_measurement_schema())), s.optional(s.required_object("instantaneous_measurement", instantaneous_measurement_schema()))] }
}

fn validate_asset_measurement(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(asset_measurement_schema(), j)
}

# ---- UpdateGroupMeasurements / UpdateAssetMeasurements -----------------------
fn update_group_measurements_schema() -> s.ModelSchema {
  { title: "UpdateGroupMeasurements", description: "OSCP 2.0 — CapacityOptimizer -> CapacityProvider, aggregate measurements for a group", fields: [s.required_str("group_id", [StrNonEmpty]), s.required_array("measurements", KObject(energy_measurement_schema()), [])] }
}

fn validate_update_group_measurements(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(update_group_measurements_schema(), j)
}

fn update_asset_measurements_schema() -> s.ModelSchema {
  { title: "UpdateAssetMeasurements", description: "OSCP 2.0 — per-asset measurements for a group", fields: [s.required_str("group_id", [StrNonEmpty]), s.required_array("measurements", KObject(asset_measurement_schema()), [])] }
}

fn validate_update_asset_measurements(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(update_asset_measurements_schema(), j)
}

