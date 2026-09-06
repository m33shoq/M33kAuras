Run `lua5.1 tests/run.lua` or `luajit tests/run.lua` from the repository root.

These regression tests load the real addon source with minimal WoW stubs.
They cover animation scheduling, sandbox lookups, nested aura environment activation,
and options validation, not in-game rendering.
Adapted from WeakAuras upstream sandbox tests (9069a62d).
