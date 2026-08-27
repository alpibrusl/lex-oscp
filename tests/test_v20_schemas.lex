# lex-oscp — OSCP 2.0 schema validator tests

import "std.list" as list

import "lex-schema/json_value" as jv

import "lex-schema/error" as e

import "../src/v20/handshake" as hs

import "../src/v20/forecasts" as fc

import "../src/v20/measurements" as ms

fn pass() -> Result[Unit, Str] {
  Ok(())
}

fn fail(why :: Str) -> Result[Unit, Str] {
  Err(why)
}

fn assert_ok(r :: Result[jv.Json, List[e.Error]], label :: Str) -> Result[Unit, Str] {
  match r {
    Ok(_) => pass(),
    Err(_) => fail(label),
  }
}

fn assert_err(r :: Result[jv.Json, List[e.Error]], label :: Str) -> Result[Unit, Str] {
  match r {
    Err(_) => pass(),
    Ok(_) => fail(label),
  }
}

# ---- RequiredBehaviour / Handshake / HandshakeAcknowledgement ----------
fn valid_required_behaviour() -> jv.Json {
  JObj([("heartbeat_interval", JInt(60)), ("measurement_configuration", JList([JStr("CONTINUOUS")]))])
}

fn test_required_behaviour_valid() -> Result[Unit, Str] {
  assert_ok(hs.validate_required_behaviour(valid_required_behaviour()), "valid required_behaviour rejected")
}

fn test_required_behaviour_bad_enum() -> Result[Unit, Str] {
  let bad := JObj([("heartbeat_interval", JInt(60)), ("measurement_configuration", JList([JStr("SOMETIMES")]))])
  assert_err(hs.validate_required_behaviour(bad), "unknown measurement_configuration value should error")
}

fn test_handshake_valid() -> Result[Unit, Str] {
  let good := JObj([("required_behaviour", valid_required_behaviour())])
  assert_ok(hs.validate_handshake(good), "valid handshake rejected")
}

fn test_handshake_missing_required_behaviour() -> Result[Unit, Str] {
  assert_err(hs.validate_handshake(JObj([])), "missing required_behaviour should error")
}

fn test_handshake_acknowledgement_valid() -> Result[Unit, Str] {
  let good := JObj([("required_behaviour", valid_required_behaviour())])
  assert_ok(hs.validate_handshake_acknowledgement(good), "valid handshake_acknowledgement rejected")
}

# ---- Register / VersionUrl ---------------------------------------------
fn test_register_valid() -> Result[Unit, Str] {
  let good := JObj([("token", JStr("shared-secret")), ("version_url", JList([JObj([("version", JStr("2.0")), ("base_url", JStr("https://provider.example.com/cp/2.0"))])]))])
  assert_ok(hs.validate_register(good), "valid register rejected")
}

fn test_register_empty_version_url_errors() -> Result[Unit, Str] {
  let bad := JObj([("token", JStr("shared-secret")), ("version_url", JList([]))])
  assert_err(hs.validate_register(bad), "empty version_url list should error (ListNonEmpty)")
}

# ---- Heartbeat ------------------------------------------------------------
fn test_heartbeat_valid() -> Result[Unit, Str] {
  assert_ok(hs.validate_heartbeat(JObj([("offline_mode_at", JStr("2026-08-01T00:00:00Z"))])), "valid heartbeat rejected")
}

fn test_heartbeat_missing_field_errors() -> Result[Unit, Str] {
  assert_err(hs.validate_heartbeat(JObj([])), "missing offline_mode_at should error")
}

# ---- ForecastedBlock / GroupCapacityForecast -----------------------------
fn valid_forecasted_block() -> jv.Json {
  JObj([("capacity", JFloat(50.0)), ("phase", JStr("ALL")), ("unit", JStr("KW")), ("start_time", JStr("2026-08-01T00:00:00Z")), ("end_time", JStr("2026-08-01T01:00:00Z"))])
}

fn test_forecasted_block_valid() -> Result[Unit, Str] {
  assert_ok(fc.validate_forecasted_block(valid_forecasted_block()), "valid forecasted_block rejected")
}

fn test_forecasted_block_bad_unit_errors() -> Result[Unit, Str] {
  let bad := JObj([("capacity", JFloat(50.0)), ("phase", JStr("ALL")), ("unit", JStr("LITERS")), ("start_time", JStr("2026-08-01T00:00:00Z")), ("end_time", JStr("2026-08-01T01:00:00Z"))])
  assert_err(fc.validate_forecasted_block(bad), "unknown unit should error")
}

fn test_group_capacity_forecast_valid() -> Result[Unit, Str] {
  let good := JObj([("group_id", JStr("site-1")), ("type", JStr("CONSUMPTION")), ("forecasted_blocks", JList([valid_forecasted_block()]))])
  assert_ok(fc.validate_group_capacity_forecast(good), "valid group_capacity_forecast rejected")
}

fn test_group_capacity_forecast_empty_blocks_errors() -> Result[Unit, Str] {
  let bad := JObj([("group_id", JStr("site-1")), ("type", JStr("CONSUMPTION")), ("forecasted_blocks", JList([]))])
  assert_err(fc.validate_group_capacity_forecast(bad), "empty forecasted_blocks should error (ListNonEmpty)")
}

fn test_group_capacity_compliance_error_valid() -> Result[Unit, Str] {
  let good := JObj([("message", JStr("cannot curtail below floor")), ("forecasted_blocks", JList([valid_forecasted_block()]))])
  assert_ok(fc.validate_group_capacity_compliance_error(good), "valid group_capacity_compliance_error rejected")
}

# ---- EnergyMeasurement / InstantaneousMeasurement / AssetMeasurement -----
fn valid_energy_measurement() -> jv.Json {
  JObj([("value", JFloat(12.4)), ("phase", JStr("ALL")), ("unit", JStr("KWH")), ("energy_type", JStr("TOTAL")), ("direction", JStr("IMPORT")), ("measure_time", JStr("2026-08-01T00:00:00Z")), ("initial_measure_time", JStr("2026-08-01T00:00:00Z"))])
}

fn test_energy_measurement_valid() -> Result[Unit, Str] {
  assert_ok(ms.validate_energy_measurement(valid_energy_measurement()), "valid energy_measurement rejected")
}

fn test_energy_measurement_bad_direction_errors() -> Result[Unit, Str] {
  let bad := JObj([("value", JFloat(12.4)), ("phase", JStr("ALL")), ("unit", JStr("KWH")), ("energy_type", JStr("TOTAL")), ("direction", JStr("SIDEWAYS")), ("measure_time", JStr("2026-08-01T00:00:00Z")), ("initial_measure_time", JStr("2026-08-01T00:00:00Z"))])
  assert_err(ms.validate_energy_measurement(bad), "unknown direction should error")
}

fn valid_instantaneous_measurement() -> jv.Json {
  JObj([("value", JFloat(7.4)), ("phase", JStr("ONE")), ("unit", JStr("KW")), ("measure_time", JStr("2026-08-01T00:00:00Z"))])
}

fn test_instantaneous_measurement_valid() -> Result[Unit, Str] {
  assert_ok(ms.validate_instantaneous_measurement(valid_instantaneous_measurement()), "valid instantaneous_measurement rejected")
}

fn test_asset_measurement_valid_with_energy_only() -> Result[Unit, Str] {
  let good := JObj([("asset_id", JStr("EVSE-01")), ("asset_category", JStr("CHARGING")), ("energy_measurement", valid_energy_measurement())])
  assert_ok(ms.validate_asset_measurement(good), "asset_measurement carrying only energy_measurement should be valid (both measurement fields are optional)")
}

fn test_asset_measurement_bad_category_errors() -> Result[Unit, Str] {
  let bad := JObj([("asset_id", JStr("EVSE-01")), ("asset_category", JStr("UNKNOWN_CATEGORY")), ("energy_measurement", valid_energy_measurement())])
  assert_err(ms.validate_asset_measurement(bad), "unknown asset_category should error")
}

fn test_update_group_measurements_valid() -> Result[Unit, Str] {
  let good := JObj([("group_id", JStr("site-1")), ("measurements", JList([valid_energy_measurement()]))])
  assert_ok(ms.validate_update_group_measurements(good), "valid update_group_measurements rejected")
}

fn test_update_asset_measurements_valid() -> Result[Unit, Str] {
  let good := JObj([("group_id", JStr("site-1")), ("measurements", JList([JObj([("asset_id", JStr("EVSE-01")), ("asset_category", JStr("CHARGING")), ("instantaneous_measurement", valid_instantaneous_measurement())])]))])
  assert_ok(ms.validate_update_asset_measurements(good), "valid update_asset_measurements rejected")
}

# ---- Suite + runner ---------------------------------------------
fn suite() -> List[Result[Unit, Str]] {
  [test_required_behaviour_valid(), test_required_behaviour_bad_enum(), test_handshake_valid(), test_handshake_missing_required_behaviour(), test_handshake_acknowledgement_valid(), test_register_valid(), test_register_empty_version_url_errors(), test_heartbeat_valid(), test_heartbeat_missing_field_errors(), test_forecasted_block_valid(), test_forecasted_block_bad_unit_errors(), test_group_capacity_forecast_valid(), test_group_capacity_forecast_empty_blocks_errors(), test_group_capacity_compliance_error_valid(), test_energy_measurement_valid(), test_energy_measurement_bad_direction_errors(), test_instantaneous_measurement_valid(), test_asset_measurement_valid_with_energy_only(), test_asset_measurement_bad_category_errors(), test_update_group_measurements_valid(), test_update_asset_measurements_valid()]
}

fn run_all_count() -> Int {
  list.fold(suite(), 0, fn (n :: Int, r :: Result[Unit, Str]) -> Int {
    match r {
      Ok(_) => n,
      Err(_) => n + 1,
    }
  })
}

# `lex test` calls `run_all` and DISCARDS what it returns (lex-lang#757), so a
# returned failure count reports `ok` however many assertions failed. Only a
# raise fails a file — the same idiom lex-ems, lex-web and lex-guard use.
# Run `run_all_count` directly to see which assertions failed.
fn run_all() -> Unit {
  if run_all_count() == 0 {
    ()
  } else {
    let __boom := 1 / 0
    ()
  }
}

