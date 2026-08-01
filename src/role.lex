# lex-oscp — OSCP role constants
#
# OSCP has (at least) three roles, confirmed via the NOWUM/pyoscp
# reference implementation's namespace routing (/cp/2.0, /co/2.0,
# /fp/2.0 — not yet cross-checked against the primary OCA spec text,
# see README "Before writing schemas"):
#
#   - CapacityProvider — owns the grid constraint (a DSO/TSO, or an
#     aggregator standing in for one). Receives: adjust_group_capacity_
#     forecast, group_capacity_compliance_error, update_group_measurements,
#     update_asset_measurements (routed here per the documented standard
#     direction, not pyoscp's own apparently inconsistent /co/2.0/
#     routing for this one action — see measurements.lex's header
#     comment).
#   - CapacityOptimizer — manages assets behind the constraint (a
#     CPO/EMS — lex-ems, concretely, in this fleet). Receives:
#     update_group_capacity_forecast.
#   - FlexibilityProvider — an optional intermediary/hub a
#     CapacityProvider can forward a GroupCapacityForecast through
#     rather than talking to every CapacityOptimizer directly. The
#     rough OSCP analogue of OCPI's Hub role. Also receives
#     update_group_capacity_forecast, on its own /fp/2.0 route.
#
# Effects: none.

fn capacity_provider() -> Str {
  "CapacityProvider"
}

fn capacity_optimizer() -> Str {
  "CapacityOptimizer"
}

fn flexibility_provider() -> Str {
  "FlexibilityProvider"
}

fn all_roles() -> List[Str] {
  [capacity_provider(), capacity_optimizer(), flexibility_provider()]
}

