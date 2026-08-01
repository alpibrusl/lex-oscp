# lex-oscp — effectful handler registry + dispatch
#
# Same shape as `route.lex` but with handlers carrying an `[io, time,
# sql]` upper bound. A real CapacityOptimizer persists an incoming
# GroupCapacityForecast via lex-orm, logs via `io.print`, and stamps
# timestamps via `time.now_str` — the pure registry can't host those;
# this module is the effectful sibling.
#
# Caveat: handlers declaring effects outside `[io, time, sql]` (e.g.
# `[fs_read]`, `[net]`, `[random]`) don't fit — same caveat as
# lex-ocpi's route_io.lex, and the same underlying lex-lang limitation
# (no effect polymorphism on function pointers in records).
#
# Effects: handlers run inside `[io, time, sql]` upper bound.

import "std.str" as str

import "std.list" as list

import "lex-schema/json_value" as jv

import "lex-schema/error" as e

import "./error" as oe

import "./route" as route

# ---- Handler types -----------------------------------------------
type IoHandler = (route.OscpRequest) -> [io, time, sql] route.HandlerResult

type IoFallback = (route.OscpRequest) -> [io, time, sql] route.HandlerResult

# ---- Registry datatype -------------------------------------------
type IoRouteEntry = { role :: Str, action :: Str, validator :: Option[(jv.Json) -> Result[jv.Json, List[e.Error]]], handler :: (route.OscpRequest) -> [io, time, sql] route.HandlerResult }

type IoRegistry = { routes :: List[IoRouteEntry], on_unknown :: (route.OscpRequest) -> [io, time, sql] route.HandlerResult }

# ---- Registry construction ---------------------------------------
fn new() -> IoRegistry {
  { routes: [], on_unknown: default_unknown }
}

fn default_unknown(req :: route.OscpRequest) -> [io, time, sql] route.HandlerResult {
  route.fail(oe.not_found(str.concat("no handler for role=", str.concat(req.role, str.concat(" action=", req.action)))))
}

fn with_unknown(reg :: IoRegistry, fb :: IoFallback) -> IoRegistry {
  { routes: reg.routes, on_unknown: fb }
}

fn handler(reg :: IoRegistry, role :: Str, action :: Str, h :: IoHandler) -> IoRegistry {
  add_entry(reg, { role: role, action: action, validator: None, handler: h })
}

fn handler_with_schema(reg :: IoRegistry, role :: Str, action :: Str, validator :: route.Validator, h :: IoHandler) -> IoRegistry {
  add_entry(reg, { role: role, action: action, validator: Some(validator), handler: h })
}

fn add_entry(reg :: IoRegistry, entry :: IoRouteEntry) -> IoRegistry {
  { routes: list.concat(reg.routes, [entry]), on_unknown: reg.on_unknown }
}

# ---- Lookup ------------------------------------------------------
fn find(reg :: IoRegistry, role :: Str, action :: Str) -> Option[IoRouteEntry] {
  list.fold(reg.routes, None, fn (acc :: Option[IoRouteEntry], entry :: IoRouteEntry) -> Option[IoRouteEntry] {
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

# ---- Dispatch ----------------------------------------------------
fn dispatch(reg :: IoRegistry, req :: route.OscpRequest) -> [io, time, sql] route.OscpResponse {
  match find(reg, req.role, req.action) {
    None => response_from_handler(reg.on_unknown(req)),
    Some(entry) => run_entry(entry, req),
  }
}

fn run_entry(entry :: IoRouteEntry, req :: route.OscpRequest) -> [io, time, sql] route.OscpResponse {
  match entry.validator {
    None => response_from_handler(entry.handler(req)),
    Some(vf) => match vf(req.body) {
      Err(es) => response_from_handler(route.fail(oe.from_schema_errors(es))),
      Ok(normalized) => {
        let r2 := route.request(req.role, req.action, req.headers, normalized)
        response_from_handler(entry.handler(r2))
      },
    },
  }
}

fn response_from_handler(hr :: route.HandlerResult) -> route.OscpResponse {
  match hr {
    HAccepted => { status: 204, body: None },
    HOk(payload) => { status: 200, body: Some(payload) },
    HErr(oerr) => { status: oerr.status, body: oerr.detail },
  }
}

