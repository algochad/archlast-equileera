# Camera Collision Notes

## Raycast Strategy

Single ray per frame from player eye position to desired third-person camera
position. Early-out on first terrain intersection. No secondary rays or sphere
casts in Phase 2.

## Terrain vs Entity Filtering

Phase 2 collision checks terrain only (node geometry). Entity raycasts are
deferred to Phase 4 when the entity component system provides spatial queries.
`getRayHit()` returns `entity=0` for terrain hits; non-zero entity IDs reserved
for future entity collision.

## Consecutive-Hit Centered Fallback

When the collision ray hits 3+ consecutive frames, the shoulder offset is zeroed
(centered camera) to prevent the camera from being permanently stuck behind thin
geometry. The counter resets on any miss. This avoids oscillation in tight
corridors while preserving the over-shoulder feel in open areas.

## Performance Budget

Target: ≤0.5ms per frame for the entire `CameraManager::update()` call including
collision raycast. The single-ray approach with early terrain exit stays well
within this budget. Smoothing uses a single lerp (no allocations). All state is
stack/cache-friendly.

## Known Limitation

The current `performCollisionRaycast()` is a stub because `Camera` does not
expose its `Client*` pointer needed to access `ClientEnvironment::shootLine()`.
The wiring integration step must either:
1. Pass `Client*` to `CameraManager` constructor, or
2. Add a `setClient(Client*)` method called during lifecycle wiring.

Until then, collision is effectively disabled but the API surface is complete
and the Lua bindings return sensible defaults.