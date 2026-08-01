# lex-oscp — OSCP error helpers
#
# Unlike OCPI's numeric status-code catalog (1000/2000/3000/4000
# bands), pyoscp's confirmed endpoints just use plain HTTP status
# codes: 204 (accepted, no body), 400 ("Cant comply"), 404 ("Not
# found"). No evidence of an OCPI-style structured error envelope —
# see README "Before trusting these schemas further". `message` is
# free text; `detail` is an optional Json payload for cases where a
# handler wants to attach structured context (e.g. a
# GroupCapacityComplianceError body), not a confirmed wire
# requirement.
#
# Effects: none.

import "std.list" as list

import "lex-schema/json_value" as jv

type OscpError = { status :: Int, message :: Str, detail :: Option[jv.Json] }

fn err(status :: Int, message :: Str) -> OscpError {
  { status: status, message: message, detail: None }
}

fn err_with(status :: Int, message :: Str, detail :: jv.Json) -> OscpError {
  { status: status, message: message, detail: Some(detail) }
}

# ---- Common helpers -------------------------------------------------
# 400 — pyoscp's own "Cant comply" case (a CapacityOptimizer that
# cannot honor a forecast/adjustment).
fn cannot_comply(description :: Str) -> OscpError {
  err(400, description)
}

# 404 — no registered handler / unknown resource.
fn not_found(description :: Str) -> OscpError {
  err(404, description)
}

# 401 — pyoscp's _check_access_token: missing Authorization header.
fn unauthorized() -> OscpError {
  err(401, "Unauthorized")
}

# 403 — pyoscp's _check_access_token: token present but not registered.
fn forbidden() -> OscpError {
  err(403, "invalid token")
}

fn server_error(description :: Str) -> OscpError {
  err(500, description)
}

# ---- Schema-error adapter ---------------------------------------------
fn from_schema_errors(es :: List[{ path :: Str, code :: Str, message :: Str }]) -> OscpError {
  let entries := list.map(es, fn (e :: { path :: Str, code :: Str, message :: Str }) -> jv.Json {
    JObj([("path", JStr(e.path)), ("code", JStr(e.code)), ("message", JStr(e.message))])
  })
  err_with(400, "request payload failed schema validation", JObj([("violations", JList(entries))]))
}

