# lex-oscp — outbound HTTP client
#
# A CapacityProvider pushing a GroupCapacityForecast to a
# CapacityOptimizer (or a FlexibilityProvider forwarding one), a
# CapacityOptimizer reporting Measurements back, or either side
# running the Register/Handshake sequence — all of it is outbound
# HTTP. This module bundles `std.http` with OSCP's header pattern
# (`Authorization: Token <token>`, `X-Request-ID`,
# `X-Correlation-ID`) confirmed via NOWUM/pyoscp's
# RegistrationManager.py.
#
# Unlike lex-ocpi's client.lex, there's no envelope to decode: every
# confirmed pyoscp action answers success with a bare 204 (no body).
# `send` therefore returns `Result[Unit, ClientError]`, not
# `Result[jv.Json, ClientError]` — see README "Before trusting these
# schemas further" for what's still open about the error body shape.
#
# Effects: `[net]` (wire ops only). Pure builders for assembling the
# request.

import "std.str" as str

import "std.list" as list

import "std.map" as map

import "std.http" as http

import "std.bytes" as bytes

import "std.time" as time

import "std.int" as int

import "lex-schema/json_value" as jv

import "./headers" as h

import "./role" as role

# ---- Role-scoped base paths -----------------------------------------
# Confirmed pyoscp namespace prefixes. A message is POSTed under
# whichever role is *receiving* it (see src/module_id.lex's routing
# table), not the sender's own role.
fn role_path(r :: Str) -> Str {
  if r == role.capacity_provider() {
    "cp/2.0"
  } else {
    if r == role.capacity_optimizer() {
      "co/2.0"
    } else {
      "fp/2.0"
    }
  }
}

# ---- Confirmed action URL segments (snake_case, distinct from
# module_id.lex's PascalCase message names) ---------------------------
fn path_register() -> Str {
  "register"
}

fn path_handshake() -> Str {
  "handshake"
}

fn path_handshake_acknowledgement() -> Str {
  "handshake_acknowledgement"
}

fn path_heartbeat() -> Str {
  "heartbeat"
}

fn path_update_group_capacity_forecast() -> Str {
  "update_group_capacity_forecast"
}

fn path_adjust_group_capacity_forecast() -> Str {
  "adjust_group_capacity_forecast"
}

fn path_group_capacity_compliance_error() -> Str {
  "group_capacity_compliance_error"
}

fn path_update_group_measurements() -> Str {
  "update_group_measurements"
}

fn path_update_asset_measurements() -> Str {
  "update_asset_measurements"
}

fn action_url(base :: Str, receiving_role :: Str, action_path :: Str) -> Str {
  str.concat(base, str.concat("/", str.concat(role_path(receiving_role), str.concat("/", action_path))))
}

# ---- ClientError ---------------------------------------------------
type ClientError = HttpFailed(Str) | HttpStatus({ code :: Int, body :: Str, retry_after_ms :: Option[Int] })

fn base_request(method :: Str, url :: Str) -> HttpRequest {
  { method: method, url: url, headers: map.new(), body: None, timeout_ms: Some(30000) }
}

fn with_token(req :: HttpRequest, token :: Str) -> HttpRequest {
  http.with_header(req, h.h_authorization(), str.concat(h.token_prefix(), token))
}

fn with_request_id(req :: HttpRequest, request_id :: Str) -> HttpRequest {
  http.with_header(req, h.h_request_id(), request_id)
}

fn with_correlation_id(req :: HttpRequest, correlation_id :: Str) -> HttpRequest {
  http.with_header(req, h.h_correlation_id(), correlation_id)
}

fn with_json_body(req :: HttpRequest, body :: Str) -> HttpRequest {
  let with_ct := http.with_header(req, "content-type", "application/json")
  { method: with_ct.method, url: with_ct.url, headers: with_ct.headers, body: Some(bytes.from_str(body)), timeout_ms: with_ct.timeout_ms }
}

# ---- Send ------------------------------------------------------------
# Every confirmed pyoscp action answers success with a bare 204 — the
# meaningful return value is "it worked," not a decoded body.
fn send(req :: HttpRequest) -> [net] Result[Unit, ClientError] {
  match http.send(req) {
    Err(_) => Err(HttpFailed("http.send transport error")),
    Ok(resp) => if resp.status >= 200 and resp.status < 300 {
      Ok(())
    } else {
      Err(HttpStatus({ code: resp.status, body: body_str(resp.body), retry_after_ms: parse_retry_after_ms(resp.headers) }))
    },
  }
}

fn body_str(raw :: Bytes) -> Str {
  match bytes.to_str(raw) {
    Err(_) => "",
    Ok(s) => s,
  }
}

fn parse_retry_after_ms(headers :: Map[Str, Str]) -> Option[Int] {
  match map.get(headers, "retry-after") {
    None => None,
    Some(s) => match str.to_int(s) {
      None => None,
      Some(n) => if n >= 0 {
        Some(n * 1000)
      } else {
        None
      },
    },
  }
}

# ---- Convenience: POST a JSON body against a receiving role's action -
fn post_action(base :: Str, receiving_role :: Str, action_path :: Str, body :: Str, token :: Str, request_id :: Str) -> [net] Result[Unit, ClientError] {
  let url := action_url(base, receiving_role, action_path)
  let req0 := with_token(base_request("POST", url), token)
  let req1 := with_request_id(req0, request_id)
  let req2 := with_json_body(req1, body)
  send(req2)
}

# ---- Convenience: named per-action senders --------------------------
fn send_group_capacity_forecast(base :: Str, receiving_role :: Str, body :: jv.Json, token :: Str, request_id :: Str) -> [net] Result[Unit, ClientError] {
  post_action(base, receiving_role, path_update_group_capacity_forecast(), jv.stringify(body), token, request_id)
}

fn send_adjust_group_capacity_forecast(base :: Str, body :: jv.Json, token :: Str, request_id :: Str) -> [net] Result[Unit, ClientError] {
  post_action(base, role.capacity_provider(), path_adjust_group_capacity_forecast(), jv.stringify(body), token, request_id)
}

fn send_group_capacity_compliance_error(base :: Str, body :: jv.Json, token :: Str, request_id :: Str) -> [net] Result[Unit, ClientError] {
  post_action(base, role.capacity_provider(), path_group_capacity_compliance_error(), jv.stringify(body), token, request_id)
}

fn send_update_group_measurements(base :: Str, body :: jv.Json, token :: Str, request_id :: Str) -> [net] Result[Unit, ClientError] {
  post_action(base, role.capacity_provider(), path_update_group_measurements(), jv.stringify(body), token, request_id)
}

# CapacityOptimizer -> CapacityProvider, same as send_update_group_
# measurements above — module_id.lex's own catalog already documents
# both UpdateGroupMeasurements and UpdateAssetMeasurements as
# "actual usage against assets," reported by the optimizer to the
# provider. Routed to role.capacity_provider() to match that standard
# direction, not pyoscp's apparently inconsistent /co/2.0/ namespacing
# for this one action (see measurements.lex's header comment and
# README "Before trusting these schemas further" for the discrepancy)
# — an academic reference implementation's routing quirk isn't reason
# enough to misroute a message whose own documented direction is
# unambiguous.
fn send_update_asset_measurements(base :: Str, body :: jv.Json, token :: Str, request_id :: Str) -> [net] Result[Unit, ClientError] {
  post_action(base, role.capacity_provider(), path_update_asset_measurements(), jv.stringify(body), token, request_id)
}

fn send_heartbeat(base :: Str, receiving_role :: Str, body :: jv.Json, token :: Str, request_id :: Str) -> [net] Result[Unit, ClientError] {
  post_action(base, receiving_role, path_heartbeat(), jv.stringify(body), token, request_id)
}

# ---- Registration / handshake ----------------------------------------
# NOT a synchronous swap like OCPI's credentials flow: Register is a
# one-time, out-of-band token exchange (no HTTP call modeled here —
# it happens outside the protocol per pyoscp's own docs); Handshake is
# a one-way POST, and the HandshakeAcknowledgement comes back later as
# a *separate*, independently-routed inbound POST to our own
# registered endpoint, not as this call's return value. Don't build a
# `handshake()` convenience that "returns" the acknowledgement the way
# lex-ocpi's does — that would misrepresent the flow.
fn send_handshake(base :: Str, receiving_role :: Str, body :: jv.Json, token :: Str, request_id :: Str) -> [net] Result[Unit, ClientError] {
  post_action(base, receiving_role, path_handshake(), jv.stringify(body), token, request_id)
}

fn send_handshake_acknowledgement(base :: Str, receiving_role :: Str, body :: jv.Json, token :: Str, request_id :: Str) -> [net] Result[Unit, ClientError] {
  post_action(base, receiving_role, path_handshake_acknowledgement(), jv.stringify(body), token, request_id)
}

# ---- Retry policy + classifier (same shape as lex-ocpi's client.lex —
# this logic is protocol-agnostic) --------------------------------------
type RetryPolicy = { max_attempts :: Int, initial_delay_ms :: Int, max_delay_ms :: Int, multiplier_x100 :: Int, jitter :: Bool, respect_retry_after :: Bool }

fn default_retry_policy() -> RetryPolicy {
  { max_attempts: 5, initial_delay_ms: 200, max_delay_ms: 30000, multiplier_x100: 200, jitter: true, respect_retry_after: true }
}

fn no_retry_policy() -> RetryPolicy {
  { max_attempts: 1, initial_delay_ms: 0, max_delay_ms: 0, multiplier_x100: 100, jitter: false, respect_retry_after: false }
}

fn is_retryable(e :: ClientError) -> Bool {
  match e {
    HttpFailed(_) => true,
    HttpStatus(info) => is_retryable_status(info.code),
  }
}

fn is_retryable_status(code :: Int) -> Bool {
  if code == 408 {
    true
  } else {
    if code == 429 {
      true
    } else {
      if code >= 500 and code < 600 {
        true
      } else {
        false
      }
    }
  }
}

fn retry_after_hint(e :: ClientError) -> Option[Int] {
  match e {
    HttpStatus(info) => match info.code {
      429 => info.retry_after_ms,
      503 => info.retry_after_ms,
      _ => None,
    },
    HttpFailed(_) => None,
  }
}

# ---- Backoff math (pure) — identical to lex-ocpi's client.lex --------
fn exp_backoff_ms(attempt :: Int, policy :: RetryPolicy) -> Int {
  let raw := scale_up(policy.initial_delay_ms, policy.multiplier_x100, attempt - 1, policy.max_delay_ms)
  min_i(raw, policy.max_delay_ms)
}

fn scale_up(acc :: Int, mult_x100 :: Int, n :: Int, cap :: Int) -> Int {
  if n <= 0 {
    acc
  } else {
    if acc >= cap {
      cap
    } else {
      scale_up(acc * mult_x100 / 100, mult_x100, n - 1, cap)
    }
  }
}

fn min_i(a :: Int, b :: Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

fn apply_jitter_ms(ms :: Int) -> [time] Int {
  let spread := ms * 20 / 100
  if spread == 0 {
    ms
  } else {
    let offset := time.mono_ns() % (2 * spread + 1)
    ms - spread + offset
  }
}

fn compute_backoff_ms(attempt :: Int, policy :: RetryPolicy, hint :: Option[Int]) -> [time] Int {
  let base := match hint {
    Some(ra) => if policy.respect_retry_after {
      min_i(ra, policy.max_delay_ms)
    } else {
      exp_backoff_ms(attempt, policy)
    },
    None => exp_backoff_ms(attempt, policy),
  }
  if policy.jitter {
    apply_jitter_ms(base)
  } else {
    base
  }
}

# ---- Retry events ----------------------------------------------
type RetryEvent = Attempt({ n :: Int, delay_ms :: Int, reason :: Str }) | GaveUp({ attempts :: Int, last_error :: ClientError })

fn reason_of(e :: ClientError) -> Str {
  match e {
    HttpFailed(m) => str.concat("transport: ", m),
    HttpStatus(info) => str.concat("http-", int.to_str(info.code)),
  }
}

# ---- Retry loop ------------------------------------------------
fn send_with_retry(req :: HttpRequest, policy :: RetryPolicy) -> [net, time] Result[Unit, ClientError] {
  retry_loop(req, policy, 1)
}

fn retry_loop(req :: HttpRequest, policy :: RetryPolicy, attempt :: Int) -> [net, time] Result[Unit, ClientError] {
  match send(req) {
    Ok(_) => Ok(()),
    Err(e) => if is_retryable(e) == false or attempt >= policy.max_attempts {
      Err(e)
    } else {
      let delay := compute_backoff_ms(attempt, policy, retry_after_hint(e))
      let __lex_discard_1 := time.sleep_ms(delay)
      retry_loop(req, policy, attempt + 1)
    },
  }
}

fn send_with_events(req :: HttpRequest, policy :: RetryPolicy, observer :: (RetryEvent) -> [io] Unit) -> [net, time, io] Result[Unit, ClientError] {
  retry_loop_events(req, policy, observer, 1)
}

fn retry_loop_events(req :: HttpRequest, policy :: RetryPolicy, observer :: (RetryEvent) -> [io] Unit, attempt :: Int) -> [net, time, io] Result[Unit, ClientError] {
  match send(req) {
    Ok(_) => Ok(()),
    Err(e) => if is_retryable(e) == false or attempt >= policy.max_attempts {
      let __lex_discard_2 := observer(GaveUp({ attempts: attempt, last_error: e }))
      Err(e)
    } else {
      let delay := compute_backoff_ms(attempt, policy, retry_after_hint(e))
      let __lex_discard_3 := observer(Attempt({ n: attempt + 1, delay_ms: delay, reason: reason_of(e) }))
      let __lex_discard_4 := time.sleep_ms(delay)
      retry_loop_events(req, policy, observer, attempt + 1)
    },
  }
}

