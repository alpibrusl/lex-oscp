# lex-oscp — OSCP role constants
#
# OSCP is a peer-to-peer protocol between two roles: whichever party
# owns the grid constraint (the CapacityProvider — a DSO/TSO, or an
# aggregator standing in for one) and whichever party manages assets
# behind that constraint (the CapacityOptimizer — a CPO/EMS, concretely
# lex-ems in this fleet).
#
# PROVISIONAL: these wire spellings ("CapacityProvider",
# "CapacityOptimizer") are corroborated from public OSCP explainers and
# the Open Charge Alliance's own protocol page, not yet checked against
# the registration-gated OSCP 2.0/2.1 specification text. Confirm the
# exact casing/spelling before shipping a real handshake against a
# non-lex-oscp peer — see README "Before writing schemas".
#
# Effects: none.

fn capacity_provider() -> Str {
  "CapacityProvider"
}

fn capacity_optimizer() -> Str {
  "CapacityOptimizer"
}

fn all_roles() -> List[Str] {
  [capacity_provider(), capacity_optimizer()]
}

