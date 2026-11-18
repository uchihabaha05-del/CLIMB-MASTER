# 3D model assets for CLIMB MASTER

Place licensed GLB/ glTF 2.0 assets in this folder.

Expected filenames for the next integration pass:
- `climber.glb` — complete character seated in a metal pot, with the pot and human mesh as one scene or clearly named child nodes.
- `hammer.glb` — separate hammer model, origin at the grip/pivot and forward axis documented.
- `mountain_rocks.glb` — optional modular rock/cliff pieces. Static geometry only; collision will be generated in Godot unless the model includes suitable collision meshes.

## Import requirements
- GLB / glTF 2.0.
- Real-time game-ready mesh; preferably under 50k triangles for the character and under 30k per prop.
- Apply transforms and use meters as units.
- Include PBR textures inside the GLB where possible.
- Keep texture sizes sensible for mobile (1K–2K).
- Do not include copyrighted game/movie character models without permission. Use original or properly licensed assets.

The current project still uses procedural placeholder meshes. These files are integration targets, not assets already included in the repository.
