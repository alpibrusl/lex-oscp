# lex-oscp — route dispatch tests

import "std.str" as str

import "std.int" as int

import "std.list" as list

import "lex-schema/json_value" as jv

import "lex-schema/error" as e

import "./../src/error" as oe

import "./../src/headers" as headers

import "./../src/role" as role

import "./../src/module_id" as mid

import "./../src/route" as route

fn pass() -> Result[Unit, Str] {
  Ok(())
}

fn fail(why :: Str) -> Result[Unit, Str] {
  Err(why)
}

fn assert_eq_int(want :: Int, got :: Int, label :: Str) -> Result[Unit, Str] {
  if want == got {
    pass()
  } else {
    fail(str.concat(label, str.concat(": want=", str.concat(int.to_str(want), str.concat(" got=", int.to_str(got))))))
  }
}

# ---- Test fixtures ----------------------------------------------
fn empty_headers() -> headers.OscpHeaders {
  headers.new("", "", "")
}

fn empty_req(r :: Str, action :: Str) -> route.OscpRequest {
  route.request(r, action, empty_headers(), JNull)
}

fn req_with_body(r :: Str, action :: Str, body :: jv.Json) -> route.OscpRequest {
  route.request(r, action, empty_headers(), body)
}

# ---- Handlers ----------------------------------------------------
fn accept_handler(_req :: route.OscpRequest) -> route.HandlerResult {
  route.accepted()
}

fn error_handler(_req :: route.OscpRequest) -> route.HandlerResult {
  route.fail(oe.not_found("no such group"))
}

# ---- Tests -------------------------------------------------------
fn test_dispatch_known_route() -> Result[Unit, Str] {
  let reg := route.handler(route.new(), role.capacity_optimizer(), mid.update_group_capacity_forecast(), accept_handler)
  let res := route.dispatch(reg, empty_req(role.capacity_optimizer(), mid.update_group_capacity_forecast()))
  assert_eq_int(204, res.status, "a registered role+action should reach the handler and return 204")
}

fn test_dispatch_unknown_route() -> Result[Unit, Str] {
  let reg := route.handler(route.new(), role.capacity_optimizer(), mid.update_group_capacity_forecast(), accept_handler)
  let res := route.dispatch(reg, empty_req(role.capacity_optimizer(), mid.update_asset_measurements()))
  assert_eq_int(404, res.status, "an unregistered action under a known role should fall through to on_unknown")
}

fn test_dispatch_role_mismatch() -> Result[Unit, Str] {
  let reg := route.handler(route.new(), role.capacity_optimizer(), mid.update_group_capacity_forecast(), accept_handler)
  let res := route.dispatch(reg, empty_req(role.flexibility_provider(), mid.update_group_capacity_forecast()))
  assert_eq_int(404, res.status, "the same action registered for a different role should not match")
}

fn test_handler_returns_error() -> Result[Unit, Str] {
  let reg := route.handler(route.new(), role.capacity_provider(), mid.adjust_group_capacity_forecast(), error_handler)
  let res := route.dispatch(reg, empty_req(role.capacity_provider(), mid.adjust_group_capacity_forecast()))
  assert_eq_int(404, res.status, "handler-raised errors propagate their own status")
}

# ---- Validator integration --------------------------------------
fn always_fail_validator(_j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  Err([e.error("group_id", e.code_missing(), "group_id is required")])
}

fn always_pass_validator(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  Ok(j)
}

fn test_validator_short_circuits() -> Result[Unit, Str] {
  let reg := route.handler_with_schema(route.new(), role.capacity_optimizer(), mid.update_group_capacity_forecast(), always_fail_validator, accept_handler)
  let res := route.dispatch(reg, req_with_body(role.capacity_optimizer(), mid.update_group_capacity_forecast(), JObj([])))
  assert_eq_int(400, res.status, "validator failure should return 400, not reach the handler")
}

fn test_validator_passes_through() -> Result[Unit, Str] {
  let reg := route.handler_with_schema(route.new(), role.capacity_optimizer(), mid.update_group_capacity_forecast(), always_pass_validator, accept_handler)
  let res := route.dispatch(reg, req_with_body(role.capacity_optimizer(), mid.update_group_capacity_forecast(), JObj([])))
  assert_eq_int(204, res.status, "validator pass should reach the handler")
}

# ---- Suite + runner ---------------------------------------------
fn suite() -> List[Result[Unit, Str]] {
  [test_dispatch_known_route(), test_dispatch_unknown_route(), test_dispatch_role_mismatch(), test_handler_returns_error(), test_validator_short_circuits(), test_validator_passes_through()]
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

