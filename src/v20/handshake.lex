# lex-oscp — OSCP 2.0 registration / handshake module
#
# Reconstructed from NOWUM/pyoscp (MIT-licensed reference
# implementation) — oscp/json_models.py (Register, Handshake,
# HandshakeAcknowledgement, Heartbeat, RequiredBehaviour, VersionUrl)
# and oscp/registration.py (the handshake sequence). Not yet checked
# against the primary OCA spec text — see README "Before writing
# schemas".
#
# Registration flow (per pyoscp's registration.py):
#   1. One-time, out-of-band token exchange between the two parties
#      (registration) — happens before any handshake traffic.
#   2. The initiating party (typically the CapacityProvider) POSTs a
#      Handshake to the other party.
#   3. The receiving party replies 204 and separately POSTs back a
#      HandshakeAcknowledgement.
#   4. The initiator acks that with 204. No verify_url reachability
#      check was found in pyoscp — earlier README language assuming
#      one (modeled after OCPI's async credentials flow) is NOT
#      confirmed; correct on the next spec cross-check.
#
# Effects: none.

import "std.list" as list

import "lex-schema/json_value" as jv

import "lex-schema/schema" as s

import "lex-schema/error" as e

import "./enums" as en

# ---- RequiredBehaviour ----------------------------------------------
# Carried inside both Handshake and HandshakeAcknowledgement: the
# heartbeat cadence and measurement style each party expects of the
# other going forward.
fn required_behaviour_schema() -> s.ModelSchema {
  { title: "RequiredBehaviour", description: "OSCP 2.0 — heartbeat interval + measurement configuration expected of the peer", fields: [s.required_int("heartbeat_interval", [IntPositive]), s.required_array("measurement_configuration", KStr([StrOneOf(en.all_measurement_configuration())]), [ListNonEmpty])] }
}

fn validate_required_behaviour(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(required_behaviour_schema(), j)
}

# ---- VersionUrl --------------------------------------------------------
fn version_url_schema() -> s.ModelSchema {
  { title: "VersionUrl", description: "OSCP 2.0 — a supported protocol version and its base URL", fields: [s.required_str("version", [StrNonEmpty]), s.required_str("base_url", [StrUrl])] }
}

# ---- Register ------------------------------------------------------------
# The one-time registration payload: a shared token plus the URLs the
# sender supports.
fn register_schema() -> s.ModelSchema {
  { title: "Register", description: "OSCP 2.0 — one-time registration payload", fields: [s.required_str("token", [StrNonEmpty]), s.required_array("version_url", KObject(version_url_schema()), [ListNonEmpty])] }
}

fn validate_register(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(register_schema(), j)
}

# ---- Handshake / HandshakeAcknowledgement -------------------------------
fn handshake_schema() -> s.ModelSchema {
  { title: "Handshake", description: "OSCP 2.0 — handshake initiation", fields: [s.required_object("required_behaviour", required_behaviour_schema())] }
}

fn validate_handshake(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(handshake_schema(), j)
}

fn handshake_acknowledgement_schema() -> s.ModelSchema {
  { title: "HandshakeAcknowledgement", description: "OSCP 2.0 — handshake acknowledgement, sent back by the receiving party", fields: [s.required_object("required_behaviour", required_behaviour_schema())] }
}

fn validate_handshake_acknowledgement(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(handshake_acknowledgement_schema(), j)
}

# ---- Heartbeat -----------------------------------------------------------
fn heartbeat_schema() -> s.ModelSchema {
  { title: "Heartbeat", description: "OSCP 2.0 — liveness signal; offline_mode_at marks when the sender will stop sending if not renewed", fields: [s.required_str("offline_mode_at", [StrNonEmpty])] }
}

fn validate_heartbeat(j :: jv.Json) -> Result[jv.Json, List[e.Error]] {
  s.validate(heartbeat_schema(), j)
}

