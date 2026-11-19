# Plugin integration plan — Climb Master

Target engine: Godot 4.3.0, GL Compatibility renderer, Android export.

This project is intentionally pinned to Godot 4.3 for the current Android build. Do not install the newest plugin releases blindly: some now require Godot 4.4+.

## Approved compatibility pins

| Plugin | Pinned release | Purpose | Integration status |
|---|---|---|---|
| Phantom Camera | [v0.9.3](https://github.com/ramokz/phantom-camera/releases/tag/v0.9.3) | Camera follow, damping and third-person framing | Candidate; must test its 4.3 3D classes against the existing Camera3D |
| Debug Draw 3D | [1.6.0](https://github.com/DmitriySalnikov/godot_debug_draw_3d/releases/tag/1.6.0) | Visualize raycasts, collision shapes, hook contact and route debugging | Candidate; release explicitly targets Godot 4.3 |
| Terrain3D | [v1.0.0-stable](https://github.com/TokisanGames/Terrain3D/releases/tag/v1.0.0-stable) | Sculpted mountain terrain, LOD and texture painting | Deferred pending Android/GL Compatibility device test; Android support is described as experimental |

## Safety rules

1. Keep the current Godot 4.3 version and GL Compatibility renderer until a separate engine-upgrade decision is made.
2. Keep the existing hand-built climbing route and Camera3D as fallbacks.
3. Do not enable a plugin in project.godot until its files are present and the headless import/smoke test passes.
4. Run the Android export after each plugin is introduced. A plugin that works in the editor is not automatically safe for Android.
5. Terrain3D must be evaluated separately on a real Android device before replacing the current rock/ledge route.
6. Do not merge this integration branch into main. The current baseline remains unchanged.

## Integration order

1. Phantom Camera: install the Godot 4.3-compatible v0.9.3 release, create a test camera rig, compare with the current camera, and retain fallback.
2. Debug Draw 3D: install v1.6.0 and use it only in debug builds to inspect scythe probes, contact points and climb route collision.
3. Terrain3D: evaluate v1.0.0-stable in a separate terrain test scene; do not replace the production route until Android performance and compatibility are verified.

References:
- Phantom Camera current minimum supported engine version: Godot 4.4; therefore this project pins the older v0.9.3 release, which requires Godot 4.3+.
- Debug Draw 3D release 1.6.0 is marked for Godot 4.3+.
- Terrain3D v1.0.0 supports Godot 4.3 and describes mobile/web support as experimental.
