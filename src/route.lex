# lex-oscp — handler registry + dispatch
#
# OSCP is HTTP-based, same broad shape as lex-ocpi's route.lex, but
# simpler in one real way: pyoscp's confirmed endpoints are all POST,
# all role-scoped (a message is registered once per role namespace —
# /cp/2.0/..., /co/2.0/..., /fp/2.0/...), and all answer success with
# a bare 204 (no envelope, no body) — see README "Before trusting
# these schemas further" for what's still unconfirmed (error body
# shape in particular).
#
# Routes are keyed by (role, action) rather than OCPI's (method,
# module): OSCP doesn't vary the HTTP verb per action the way OCPI's
# REST resources do, but a given action (e.g.
# UpdateGroupCapacityForecast) is registered under a *different* role
# namespace depending on who's receiving it (co or fp).
#
#   handler  :: (OscpRequest) -> HandlerResult
#   dispatch :: (Registry, OscpRequest) -> OscpResponse
#
# Effects: none. Layer a `[net, io, time]` adapter on top (route_io.lex,
# not yet written) to drive the dispatcher from a real HTTP server.

import "std.str" as str

import "std.list" as list

import "lex-schema/json_value" as jv

import "lex-schema/error" as e

import "./error" as oe

import "./headers" as headers

# ---- OscpRequest -----------------------------------------------------
type OscpRequest = { role :: Str, action :: Str, headers :: headers.OscpHeaders, body :: jv.Json }

fn request(role :: Str, action :: Str, hdrs :: headers.OscpHeaders, body :: jv.Json) -> OscpRequest {
  { role: role, action: action, headers: hdrs, body: body }
}

# ---- Handler types -----------------------------------------------
# Every confirmed pyoscp action is a fire-and-forget push: on success
# there's nothing to return but "accepted". HOk carries an optional
# body only for the handful of cases (none confirmed as core OSCP
# today — see README) that might need one.
type HandlerResult = HAccepted | HOk(jv.Json) | HErr(oe.OscpError)

type Handler = (OscpRequest) -> HandlerResult

type Validator = (jv.Json) -> Result[jv.Json, List[e.Error]]

type Fallback = (OscpRequest) -> HandlerResult

# ---- Registry datatype -------------------------------------------
# Field types are written as inline arrow types rather than the
# Handler/Validator/Fallback aliases above — matching lex-ocpi's
# route.lex, which does the same to sidestep a type-alias/record-field
# asymmetry with calling a field access directly.
type RouteEntry = { role :: Str, action :: Str, validator :: Option[(jv.Json) -> Result[jv.Json, List[e.Error]]], handler :: (OscpRequest) -> HandlerResult }

type Registry = { routes :: List[RouteEntry], on_unknown :: (OscpRequest) -> HandlerResult }

fn new() -> Registry {
  { routes: [], on_unknown: default_unknown }
}

fn default_unknown(req :: OscpRequest) -> HandlerResult {
  HErr(oe.not_found(str.concat("no handler for role=", str.concat(req.role, str.concat(" action=", req.action)))))
}

fn with_unknown(reg :: Registry, fb :: Fallback) -> Registry {
  { routes: reg.routes, on_unknown: fb }
}

fn handler(reg :: Registry, role :: Str, action :: Str, h :: Handler) -> Registry {
  add_entry(reg, { role: role, action: action, validator: None, handler: h })
}

fn handler_with_schema(reg :: Registry, role :: Str, action :: Str, validator :: Validator, h :: Handler) -> Registry {
  add_entry(reg, { role: role, action: action, validator: Some(validator), handler: h })
}

fn add_entry(reg :: Registry, entry :: RouteEntry) -> Registry {
  { routes: list.concat(reg.routes, [entry]), on_unknown: reg.on_unknown }
}

# ---- Lookup ------------------------------------------------------
fn find(reg :: Registry, role :: Str, action :: Str) -> Option[RouteEntry] {
  list.fold(reg.routes, None, fn (acc :: Option[RouteEntry], entry :: RouteEntry) -> Option[RouteEntry] {
    match acc {
      Some(_) => acc,
      None => if entry.role == role and entry.action == action {
        Some(entry)
      } else {
        None
      },
    }
  })
}

fn routes(reg :: Registry) -> List[(Str, Str)] {
  list.map(reg.routes, fn (entry :: RouteEntry) -> (Str, Str) {
    (entry.role, entry.action)
  })
}

# ---- Dispatch ----------------------------------------------------
type OscpResponse = { status :: Int, body :: Option[jv.Json] }

fn dispatch(reg :: Registry, req :: OscpRequest) -> OscpResponse {
  match find(reg, req.role, req.action) {
    None => response_from_handler(reg.on_unknown(req)),
    Some(entry) => run_entry(entry, req),
  }
}

fn run_entry(entry :: RouteEntry, req :: OscpRequest) -> OscpResponse {
  match entry.validator {
    None => response_from_handler(entry.handler(req)),
    Some(vf) => match vf(req.body) {
      Err(es) => response_from_handler(HErr(oe.from_schema_errors(es))),
      Ok(normalized) => {
        let r2 := request(req.role, req.action, req.headers, normalized)
        response_from_handler(entry.handler(r2))
      },
    },
  }
}

fn response_from_handler(hr :: HandlerResult) -> OscpResponse {
  match hr {
    HAccepted => { status: 204, body: None },
    HOk(payload) => { status: 200, body: Some(payload) },
    HErr(oerr) => { status: oerr.status, body: oerr.detail },
  }
}

# ---- Convenience builders for HandlerResult ----------------------
fn accepted() -> HandlerResult {
  HAccepted
}

fn ok(payload :: jv.Json) -> HandlerResult {
  HOk(payload)
}

fn fail(oerr :: oe.OscpError) -> HandlerResult {
  HErr(oerr)
}

fn fail_with(status :: Int, message :: Str) -> HandlerResult {
  HErr(oe.err(status, message))
}

