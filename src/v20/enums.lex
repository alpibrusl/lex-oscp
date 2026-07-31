# lex-oscp — OSCP 2.0 enum string constants
#
# Reconstructed from the NOWUM/pyoscp reference implementation
# (MIT-licensed, https://github.com/NOWUM/pyoscp/blob/master/oscp/json_models.py),
# not the primary OCA specification text (registration-gated — see
# README "Before writing schemas"). Treat the *existence* and *member
# set* of each enum as high-confidence (an independent, working
# implementation encodes them this way), but cross-check against the
# primary spec before treating this as the final word.
#
# Same StrOneOf-catalog pattern as lex-ocpi's enums.lex: one
# `fn name() -> Str` per member, one `fn all_<enum>()` catalog for
# validators.
#
# Effects: none.

import "std.list" as list

# ---- EnergyMeasurementUnit -----------------------------------------
fn unit_wh() -> Str {
  "WH"
}

fn unit_kwh() -> Str {
  "KWH"
}

fn all_energy_measurement_unit() -> List[Str] {
  [unit_wh(), unit_kwh()]
}

# ---- InstantaneousMeasurementUnit -----------------------------------
fn unit_a() -> Str {
  "A"
}

fn unit_w() -> Str {
  "W"
}

fn unit_kw() -> Str {
  "KW"
}

fn all_instantaneous_measurement_unit() -> List[Str] {
  [unit_a(), unit_w(), unit_kw(), unit_wh(), unit_kwh()]
}

# ---- ForecastedBlockUnit --------------------------------------------
fn unit_eur() -> Str {
  "EUR"
}

fn unit_eur_per_kwh() -> Str {
  "EUR/KWH"
}

fn all_forecasted_block_unit() -> List[Str] {
  [unit_a(), unit_w(), unit_kw(), unit_wh(), unit_kwh(), unit_eur(), unit_eur_per_kwh()]
}

# ---- EnergyFlowDirection ---------------------------------------------
fn direction_net() -> Str {
  "NET"
}

fn direction_import() -> Str {
  "IMPORT"
}

fn direction_export() -> Str {
  "EXPORT"
}

fn all_energy_flow_direction() -> List[Str] {
  [direction_net(), direction_import(), direction_export()]
}

# ---- EnergyType --------------------------------------------------------
fn energy_type_flexible() -> Str {
  "FLEXIBLE"
}

fn energy_type_nonflexible() -> Str {
  "NONFLEXIBLE"
}

fn energy_type_total() -> Str {
  "TOTAL"
}

fn all_energy_type() -> List[Str] {
  [energy_type_flexible(), energy_type_nonflexible(), energy_type_total()]
}

# ---- MeasurementConfiguration ------------------------------------------
fn measurement_configuration_continuous() -> Str {
  "CONTINUOUS"
}

fn measurement_configuration_intermittent() -> Str {
  "INTERMITTENT"
}

fn all_measurement_configuration() -> List[Str] {
  [measurement_configuration_continuous(), measurement_configuration_intermittent()]
}

# ---- PhaseIndicator ------------------------------------------------------
fn phase_unknown() -> Str {
  "UNKNOWN"
}

fn phase_one() -> Str {
  "ONE"
}

fn phase_two() -> Str {
  "TWO"
}

fn phase_three() -> Str {
  "THREE"
}

fn phase_all() -> Str {
  "ALL"
}

fn all_phase_indicator() -> List[Str] {
  [phase_unknown(), phase_one(), phase_two(), phase_three(), phase_all()]
}

# ---- AssetCategory ---------------------------------------------------
fn asset_charging() -> Str {
  "CHARGING"
}

fn asset_consumption() -> Str {
  "CONSUMPTION"
}

fn asset_generation() -> Str {
  "GENERATION"
}

fn asset_storage() -> Str {
  "STORAGE"
}

fn all_asset_category() -> List[Str] {
  [asset_charging(), asset_consumption(), asset_generation(), asset_storage()]
}

# ---- CapacityForecastType -----------------------------------------------
fn forecast_type_consumption() -> Str {
  "CONSUMPTION"
}

fn forecast_type_generation() -> Str {
  "GENERATION"
}

fn forecast_type_fallback_consumption() -> Str {
  "FALLBACK_CONSUMPTION"
}

fn forecast_type_fallback_generation() -> Str {
  "FALLBACK_GENERATION"
}

fn forecast_type_optimum() -> Str {
  "OPTIMUM"
}

fn all_capacity_forecast_type() -> List[Str] {
  [forecast_type_consumption(), forecast_type_generation(), forecast_type_fallback_consumption(), forecast_type_fallback_generation(), forecast_type_optimum()]
}

