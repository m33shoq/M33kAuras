Run `lua5.1 tests/run.lua` or `luajit tests/run.lua` from the repository root.

These regression tests load the real addon source with minimal WoW stubs.
They cover animation scheduling, sandbox lookups, nested aura environment activation, restricted aura lookups by name and ID,
options validation, cooldown subscriptions and readiness events, raid assignments, group roles, talent caching, load conditions, talent triggers, taxi/vehicle conditions, PvP flags, ruleset migration, instance filters, restricted character stats, threat filters, and display-only health and absorb overlays with secret values.
They also cover cached never-secret spell classifications and their searchable reference popup. UI checks
use stubbed frames; in-game rendering still needs manual verification.
Adapted from WeakAuras upstream sandbox tests (9069a62d).
