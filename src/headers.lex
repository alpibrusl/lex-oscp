# lex-oscp — OSCP request headers
#
# Confirmed via NOWUM/pyoscp's oscp/RegistrationManager.py
# (createOscpHeader / _check_access_token) — not yet cross-checked
# against the primary OCA spec text, see README "Before trusting these
# schemas further".
#
#   Authorization:     "Token " + <token>   (required)
#   X-Request-ID:      <unique per-request id>   (required)
#   X-Correlation-ID:  <unique per-correlation id>   (optional)
#
# Unlike OCPI, OSCP has no `OCPI-from-/to-{country-code,party-id}`
# quartet — a peer is scoped by which role-namespaced URL you call
# (/cp/2.0/..., /co/2.0/..., /fp/2.0/...), not by header.
#
# Effects: none.

import "std.str" as str

import "std.map" as map

# ---- Datatype ----------------------------------------------------
type OscpHeaders = { authorization :: Str, request_id :: Str, correlation_id :: Str }

fn new(authorization :: Str, request_id :: Str, correlation_id :: Str) -> OscpHeaders {
  { authorization: authorization, request_id: request_id, correlation_id: correlation_id }
}

# ---- Header-name constants -----------------------------------------
fn h_authorization() -> Str {
  "authorization"
}

fn h_request_id() -> Str {
  "x-request-id"
}

fn h_correlation_id() -> Str {
  "x-correlation-id"
}

fn token_prefix() -> Str {
  "Token "
}

# ---- Parsing -----------------------------------------------------
fn from_map(headers :: Map[Str, Str]) -> OscpHeaders {
  new(get_or_empty(headers, h_authorization()), get_or_empty(headers, h_request_id()), get_or_empty(headers, h_correlation_id()))
}

fn get_or_empty(headers :: Map[Str, Str], key :: Str) -> Str {
  match map.get(headers, key) {
    None => "",
    Some(v) => v,
  }
}

# ---- Building ----------------------------------------------------
fn to_map(h :: OscpHeaders) -> Map[Str, Str] {
  let m0 := map.new()
  let m1 := map.set(m0, h_authorization(), h.authorization)
  let m2 := map.set(m1, h_request_id(), h.request_id)
  if str.is_empty(h.correlation_id) {
    m2
  } else {
    map.set(m2, h_correlation_id(), h.correlation_id)
  }
}

# ---- Token extraction ---------------------------------------------
fn strip_token_prefix(authz :: Str) -> Option[Str]
  examples {
    strip_token_prefix("Token abc") => Some("abc"),
    strip_token_prefix("Bearer abc") => None,
    strip_token_prefix("") => None
  }
{
  if str.len(authz) <= str.len(token_prefix()) {
    None
  } else {
    if str.slice(authz, 0, str.len(token_prefix())) == token_prefix() {
      Some(str.slice(authz, str.len(token_prefix()), str.len(authz)))
    } else {
      None
    }
  }
}

# ---- Predicates --------------------------------------------------
fn is_authenticated(h :: OscpHeaders) -> Bool {
  not str.is_empty(h.authorization)
}

