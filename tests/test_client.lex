# lex-oscp — client request-builder tests
#
# Pure tests only — we exercise `base_request`, `with_token`,
# `with_json_body`, `action_url`, and the backoff math, never
# `client.send` (which would need `[net]`). Send-loop tests would need
# a fake HTTP server fixture; deferred.

import "std.str" as str

import "std.list" as list

import "std.map" as map

import "./../src/client" as client

import "./../src/headers" as h

import "./../src/role" as role

fn pass() -> Result[Unit, Str] {
  Ok(())
}

fn fail(why :: Str) -> Result[Unit, Str] {
  Err(why)
}

fn assert_eq_str(want :: Str, got :: Str, label :: Str) -> Result[Unit, Str] {
  if want == got {
    pass()
  } else {
    fail(str.concat(label, str.concat(": want=", str.concat(want, str.concat(" got=", got)))))
  }
}

fn assert_eq_int(want :: Int, got :: Int, label :: Str) -> Result[Unit, Str] {
  if want == got {
    pass()
  } else {
    fail(label)
  }
}

# ---- base_request -----------------------------------------------
fn test_base_request_method() -> Result[Unit, Str] {
  let r := client.base_request("POST", "https://provider.example.com/cp/2.0/x")
  assert_eq_str("POST", r.method, "method")
}

# ---- with_token sets Authorization (Token <x>, not Bearer) ------
fn test_with_token() -> Result[Unit, Str] {
  let r := client.with_token(client.base_request("POST", "https://x"), "shared-secret")
  match map.get(r.headers, h.h_authorization()) {
    None => fail("authorization header missing"),
    Some(v) => assert_eq_str("Token shared-secret", v, "authorization matches pyoscp's confirmed \"Token \" + token scheme"),
  }
}

# ---- with_request_id ---------------------------------------------
fn test_with_request_id() -> Result[Unit, Str] {
  let r := client.with_request_id(client.base_request("POST", "https://x"), "req-1")
  match map.get(r.headers, h.h_request_id()) {
    None => fail("X-Request-ID missing"),
    Some(v) => assert_eq_str("req-1", v, "X-Request-ID"),
  }
}

# ---- with_json_body sets Content-Type ----------------------------
fn test_with_json_body_sets_ct() -> Result[Unit, Str] {
  let r := client.with_json_body(client.base_request("POST", "https://x"), "{\"group_id\":\"site-1\"}")
  match map.get(r.headers, "content-type") {
    None => fail("content-type missing"),
    Some(v) => assert_eq_str("application/json", v, "content-type"),
  }
}

# ---- role_path / action_url ---------------------------------------
fn test_role_path_capacity_provider() -> Result[Unit, Str] {
  assert_eq_str("cp/2.0", client.role_path(role.capacity_provider()), "CapacityProvider's namespace, confirmed via pyoscp's cp_endpoints.py")
}

fn test_role_path_capacity_optimizer() -> Result[Unit, Str] {
  assert_eq_str("co/2.0", client.role_path(role.capacity_optimizer()), "CapacityOptimizer's namespace, confirmed via pyoscp's co_endpoints.py")
}

fn test_role_path_flexibility_provider() -> Result[Unit, Str] {
  assert_eq_str("fp/2.0", client.role_path(role.flexibility_provider()), "FlexibilityProvider's namespace, confirmed via pyoscp's fp_endpoints.py")
}

fn test_action_url_shape() -> Result[Unit, Str] {
  let url := client.action_url("https://optimizer.example.com", role.capacity_optimizer(), client.path_update_group_capacity_forecast())
  assert_eq_str("https://optimizer.example.com/co/2.0/update_group_capacity_forecast", url, "action_url composes base + role namespace + action path, matching pyoscp's confirmed route")
}

# ---- Retry classifier ---------------------------------------------
fn test_is_retryable_transport_failure() -> Result[Unit, Str] {
  if client.is_retryable(HttpFailed("connection refused")) {
    pass()
  } else {
    fail("a transport failure should be retryable")
  }
}

fn test_is_retryable_5xx() -> Result[Unit, Str] {
  if client.is_retryable(HttpStatus({ code: 503, body: "", retry_after_ms: None })) {
    pass()
  } else {
    fail("a 503 should be retryable")
  }
}

fn test_not_retryable_404() -> Result[Unit, Str] {
  if client.is_retryable(HttpStatus({ code: 404, body: "", retry_after_ms: None })) {
    fail("a 404 (caller bug / unknown resource) should not be retried")
  } else {
    pass()
  }
}

# ---- Backoff math (mirrors lex-ocpi's confirmed sequence) ----------
fn test_exp_backoff_sequence() -> Result[Unit, Str] {
  let policy := client.default_retry_policy()
  match assert_eq_int(200, client.exp_backoff_ms(1, policy), "attempt 1") {
    Err(e) => Err(e),
    Ok(_) => match assert_eq_int(400, client.exp_backoff_ms(2, policy), "attempt 2") {
      Err(e) => Err(e),
      Ok(_) => match assert_eq_int(800, client.exp_backoff_ms(3, policy), "attempt 3") {
        Err(e) => Err(e),
        Ok(_) => assert_eq_int(30000, client.exp_backoff_ms(10, policy), "attempt 10 clamps to max_delay_ms"),
      },
    },
  }
}

# ---- Suite + runner ---------------------------------------------
fn suite() -> List[Result[Unit, Str]] {
  [test_base_request_method(), test_with_token(), test_with_request_id(), test_with_json_body_sets_ct(), test_role_path_capacity_provider(), test_role_path_capacity_optimizer(), test_role_path_flexibility_provider(), test_action_url_shape(), test_is_retryable_transport_failure(), test_is_retryable_5xx(), test_not_retryable_404(), test_exp_backoff_sequence()]
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

