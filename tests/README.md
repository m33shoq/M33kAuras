Run `lua5.1 tests/run.lua` or `luajit tests/run.lua` from the repository root.

These regression tests load the real addon source with minimal WoW stubs.
They cover animation scheduling, sandbox lookups, nested aura environment activation, restricted aura lookups by name and ID,
options validation, cooldown subscriptions and readiness events, raid assignments, group roles, talent caching, load conditions, talent triggers, taxi/vehicle conditions, PvP flags, ruleset migration, instance filters, restricted character stats, threat filters, and display-only health and absorb overlays with secret values.
Cooldown checks include shared GCD events, deferred refreshes, and the recovery-presence fallback for restricted readiness. These simulate API responses and event ordering; restricted readiness still needs in-game verification.
They also cover cached never-secret spell classifications and their searchable reference popup. UI checks
use stubbed frames; in-game rendering still needs manual verification.
Progress texture tests load the real linear/circular renderers and smoothing mixin, checking native
secret-value and duration dispatch, inversion, bounds, subscriptions, overlays, and region reuse.
They check configuration of the circular renderer's integer-width source and readout scale,
and forwarding of its resulting fraction; native normalization still needs in-game validation.
Secret fractions pass directly to native radial clipping without Lua arithmetic. Circular artwork
uses canonical UVs and public inverse-transform vertices, with a static region mask and direct
aura rotation. Equal X/Y crop is required; unequal crop hides the secret circular foreground and
adds an aura warning until corrected. Ordinary and linear rendering retain independent crop controls.
Mode transitions and reuse must restore linear readout units, clear radial clipping, and stop circular updates.
Native circular progress uses the existing FrameTick lifecycle for both numeric and duration sources;
RegionPrototype controls global ticking while the aura is hidden or shown.
Repeated value and duration updates must preserve geometry, artwork, and subscriptions; source inversion,
orientation, size, and appearance changes must still refresh the affected rendering state.
RGB-only color animations must use the same default alpha in ordinary and native rendering,
including when entering native mode and resetting the animation.
Native call counts check that animated color and desaturation leave dormant ordinary foregrounds
untouched; returning to ordinary rendering restores their current appearance. Aura rotation updates only
the affected state; scale changes preserve source progress and texture assets. Circular ticks read
one width and forward one percent. Linear artwork and masks use direct rotation; uncompressed masks
use a fixed corner and public anchor offsets to preserve the artwork's rotation center as progress changes.
Rotation creates no animation objects or extra Lua tick. These operations create no frames, textures,
or animations in the fixtures; the tests make no heap-allocation or frame-time claim.
Public geometry checks compare native masks and artwork coordinates with the existing coordinate renderer
across linear directions, inversion, compression, slant modes, and empty through full progress.
A focused rotated vertical inverse case compares the native mask against ordinary vertices at quarter,
half, and three-quarter progress, then checks a size and angle change. Its bottom-up rotation-pivot Y
convention was identified from the user's recorded drift and the correction was confirmed in-game
for the reported case; these model checks alone cannot validate that API behavior.
These checks cannot establish native layout, mask rendering, or WoW secret taint behavior.
Hostile userdata catch arithmetic but cannot emulate every forbidden secret comparison in Lua 5.1.
Adapted from WeakAuras upstream sandbox tests (9069a62d).
