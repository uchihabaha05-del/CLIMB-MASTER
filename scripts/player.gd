extends CharacterBody3D

# ---------------------------------------------------------------------------
# Physics tuning (momentum-based climbing)
# ---------------------------------------------------------------------------
const GRAVITY := 19.0
const MAX_HORIZONTAL_SPEED := 7.5
const MAX_RISE_SPEED := 16.0
const MAX_FALL_SPEED := 15.0
const FLOOR_FRICTION := 14.0      # m/s^2, no more "ice"
const AIR_DRAG := 0.35
const MAX_SWING_SPEED := 10.0     # rad/s the blade can follow the finger
const SCYTHE_STEP := 0.06         # rad per swept collision sub-step
const PUSH_GAIN := 4.2            # m/s per metre of blade-contact travel
const SCRAPE_GRIP := 0.45         # how much dragging along a surface moves the pot
const MAX_PUSH_PER_FRAME := 2.6   # m/s
const HAZARD_KNOCKBACK := 8.0
const HAZARD_COOLDOWN := 0.4
const PLAY_PLANE_Z := 0.0
const START_ANGLE := -0.72
const SCYTHE_Z := -0.08           # scythe is drawn behind the character art, under the fist
const IDLE_HINT := "Веди серп пальцем по экрану. Упирайся лезвием в препятствия, чтобы отталкиваться."

# ---------------------------------------------------------------------------
# Character art (assets/character/*.svg, all authored on a 600x700 canvas)
# ---------------------------------------------------------------------------
const PART_DIR := "res://assets/character/"
const PX := 0.00335
const ART_CENTER := Vector2(300.0, 350.0)
const ART_BASE_Y := 0.755         # pot feet line up with the collision cylinder
const ARM_L1 := 78.0 * PX         # upper arm length
const ARM_L2 := 84.0 * PX         # elbow -> fist centre
const SHOULDER_R := Vector3((378.0 - 300.0) * PX, ART_BASE_Y + (350.0 - 325.0) * PX, 0.0)
const SHOULDER_L := Vector3((222.0 - 300.0) * PX, ART_BASE_Y + (350.0 - 325.0) * PX, 0.0)
const LEFT_HAND_REST := Vector3((140.0 - 300.0) * PX, ART_BASE_Y - (430.0 - 350.0) * PX, 0.0)

var hammer_pivot: Node3D
var hammer_head: Node3D
var scythe_contact_valid := false
var is_gripping_hold := false
var silhouette_mode := false
var hold_anchor_active := false
var hold_anchor := Vector3.ZERO
var hold_rope_length := 0.0
var scythe_contact_point := Vector3.ZERO
var scythe_contact_collider: Object = null
var scythe_probe := SphereShape3D.new()
var scythe_points: Array[Vector3] = [
    Vector3(0.0, 0.65, 0.0), Vector3(0.0, 1.20, 0.0), Vector3(0.0, 1.75, 0.0), Vector3(0.0, 2.30, 0.0),
    Vector3(0.22, 2.60, 0.0), Vector3(0.55, 2.80, 0.0), Vector3(0.90, 3.08, 0.0), Vector3(1.12, 3.45, 0.0),
    Vector3(1.20, 3.80, 0.0), Vector3(1.15, 4.15, 0.0), Vector3(0.95, 4.40, 0.0), Vector3(0.70, 4.50, 0.0)
]
var aim_angle := START_ANGLE       # current blade angle (what you see / collide with)
var target_angle := START_ANGLE    # where the finger points
var dragging := false
var touch_index := -1              # -1 none, -2 mouse, >=0 touch finger
var ui_blockers: Array = []        # Controls that must not start a swing (set by main.gd)
var hazard_cooldown := 0.0
var hook_feedback := IDLE_HINT
var _scythe_query := PhysicsShapeQueryParameters3D.new()
var _time := 0.0
var _arm_r: Dictionary = {}
var _arm_l: Dictionary = {}
var physics_viewport: SubViewport
var physics_world: ClimbPhysics2D

func _ready() -> void:
    global_position.z = PLAY_PLANE_Z
    # The visual rig no longer owns a CharacterBody3D collider; 2D rigid bodies drive it.
    scythe_probe.radius = 0.16
    _scythe_query.shape = scythe_probe
    _scythe_query.collide_with_bodies = true
    _scythe_query.collide_with_areas = false
    _scythe_query.exclude = [get_rid()]

    if not _build_character_art():
        push_warning("Character SVG parts not found in " + PART_DIR + "; using primitive fallback.")
        _make_fallback_pot()
        _make_fallback_human()

    _make_scythe()
    call_deferred("_initialize_2d_physics")
    reset_hammer()


# ---------------------------------------------------------------------------
# Character art + rigged arms
# ---------------------------------------------------------------------------

func _initialize_2d_physics() -> void:
    physics_viewport = SubViewport.new()
    physics_viewport.name = "Physics2DViewport"
    physics_viewport.size = Vector2i(1280, 720)
    physics_viewport.disable_3d = true
    physics_viewport.transparent_bg = true
    physics_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    physics_viewport.world_2d = World2D.new()
    add_child(physics_viewport)

    physics_world = ClimbPhysics2D.new()
    physics_world.name = "ClimbPhysics2D"
    physics_viewport.add_child(physics_world)
    await get_tree().physics_frame
    _mirror_static_3d_colliders()
    physics_world.configure_start(Vector2(global_position.x, -global_position.y))
    physics_world.set_target_world(physics_world.pot.global_position + Vector2(0.5, -2.0))

func _mirror_static_3d_colliders() -> void:
    var scene_root := get_tree().current_scene
    if scene_root == null or physics_world == null:
        return
    var shapes := scene_root.find_children("*", "CollisionShape3D", true, false)
    for item in shapes:
        var source := item as CollisionShape3D
        if source == null or source.disabled or source.shape == null:
            continue
        var owner := source.get_parent()
        if not owner is StaticBody3D:
            continue
        var center := Vector2(source.global_position.x, -source.global_position.y)
        var rotation_2d := -source.global_rotation.z
        var scale_3d := source.global_transform.basis.get_scale()
        var friction := 0.82
        var source_body := owner as StaticBody3D
        var body_name := source_body.name.to_lower()
        if body_name.contains("ice") or body_name.contains("frozen"):
            friction = 0.035
        elif body_name.contains("metal") or body_name.contains("steel") or body_name.contains("pipe"):
            friction = 0.42
        elif body_name.contains("rock") or body_name.contains("boulder") or body_name.contains("cliff"):
            friction = 1.18
        if source_body.physics_material_override != null:
            friction = source_body.physics_material_override.friction
        var shape := source.shape
        if shape is BoxShape3D:
            var box := shape as BoxShape3D
            physics_world.add_static_box(center, Vector2(box.size.x * absf(scale_3d.x), box.size.y * absf(scale_3d.y)), rotation_2d, friction)
        elif shape is SphereShape3D:
            var sphere := shape as SphereShape3D
            physics_world.add_static_circle(center, sphere.radius * maxf(absf(scale_3d.x), absf(scale_3d.y)), friction)
        elif shape is CylinderShape3D:
            var cylinder := shape as CylinderShape3D
            physics_world.add_static_circle(center, cylinder.radius * maxf(absf(scale_3d.x), absf(scale_3d.y)), friction)
        elif shape is CapsuleShape3D:
            var capsule_3d := shape as CapsuleShape3D
            var capsule_2d := CapsuleShape2D.new()
            capsule_2d.radius = capsule_3d.radius * absf(scale_3d.x)
            capsule_2d.height = capsule_3d.height * absf(scale_3d.y)
            var body := StaticBody2D.new()
            body.position = center
            body.rotation = rotation_2d
            var collision := CollisionShape2D.new()
            collision.shape = capsule_2d
            body.add_child(collision)
            physics_world.add_child(body)
        elif shape is ConvexPolygonShape3D:
            var convex := shape as ConvexPolygonShape3D
            var points := PackedVector2Array()
            for point in convex.points:
                points.append(Vector2(point.x * absf(scale_3d.x), -point.y * absf(scale_3d.y)))
            if points.size() >= 3:
                var body := physics_world.add_static_polygon(points, friction)
                body.position = center
                body.rotation = rotation_2d

func _make_part(file: String, origin_px: Vector2, z: float) -> Sprite3D:
    var tex := load(PART_DIR + file) as Texture2D
    if tex == null:
        return null
    var sprite := Sprite3D.new()
    sprite.name = file.get_basename()
    sprite.texture = tex
    sprite.pixel_size = PX
    sprite.centered = false
    sprite.offset = -origin_px         # texture pixel `origin_px` sits on the node origin
    sprite.shaded = false
    sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
    sprite.position.z = z
    return sprite

func _make_arm(sgn: float) -> Dictionary:
    var upper := _make_part("arm_upper.svg", Vector2(24.0, 26.0), 0.0)
    var fore := _make_part("arm_fore.svg", Vector2(18.0, 20.0), 0.002)
    var hand := _make_part("arm_hand.svg", Vector2(26.0, 22.0), 0.002)
    if upper == null or fore == null or hand == null:
        return {}
    var holder := Node3D.new()
    holder.name = "ArmRight" if sgn > 0.0 else "ArmLeft"
    holder.position = (SHOULDER_R if sgn > 0.0 else SHOULDER_L) + Vector3(0.0, 0.0, 0.025)
    holder.scale = Vector3(sgn, 1.0, 1.0)   # left arm is the mirrored right arm
    add_child(holder)
    holder.add_child(upper)
    fore.position = Vector3(ARM_L1, 0.0, 0.002)
    upper.add_child(fore)
    hand.position = Vector3(ARM_L2, 0.0, 0.002)
    fore.add_child(hand)
    return {"upper": upper, "fore": fore, "sgn": sgn}

func _build_character_art() -> bool:
    var layers := [
        ["pot_back.svg", -0.02],
        ["body.svg", 0.0],
        ["pot_front.svg", 0.05]
    ]
    var made: Array[Sprite3D] = []
    for layer in layers:
        var sprite := _make_part(layer[0], ART_CENTER, float(layer[1]))
        if sprite == null:
            return false
        sprite.position.y = ART_BASE_Y
        made.append(sprite)
    _arm_r = _make_arm(1.0)
    _arm_l = _make_arm(-1.0)
    if _arm_r.is_empty() or _arm_l.is_empty():
        return false
    for sprite in made:
        add_child(sprite)
    return true

# Two-bone IK. Everything is solved in the arm's local frame (x along the arm side,
# y up); the left arm lives under a mirrored (scale.x = -1) holder, so `sgn` flips x.
func _solve_arm(arm: Dictionary, shoulder: Vector3, target: Vector3) -> void:
    if arm.is_empty():
        return
    var sgn: float = arm["sgn"]
    var lx := (target.x - shoulder.x) * sgn
    var ly := target.y - shoulder.y
    var d := clampf(Vector2(lx, ly).length(), absf(ARM_L1 - ARM_L2) + 0.01, ARM_L1 + ARM_L2 - 0.005)
    var ang := atan2(ly, lx)
    var cos_a := clampf((ARM_L1 * ARM_L1 + d * d - ARM_L2 * ARM_L2) / (2.0 * ARM_L1 * d), -1.0, 1.0)
    var a1 := ang - acos(cos_a)               # elbow bends downwards
    var elbow := Vector2(cos(a1), sin(a1)) * ARM_L1
    var tip := Vector2(cos(ang), sin(ang)) * d
    var a2 := wrapf((tip - elbow).angle() - a1, -PI, PI)
    (arm["upper"] as Node3D).rotation.z = a1
    (arm["fore"] as Node3D).rotation.z = a2

func _update_arms() -> void:
    _solve_arm(_arm_r, SHOULDER_R, _hand_local(aim_angle))
    var rest := LEFT_HAND_REST + Vector3(0.0, sin(_time * 1.7) * 0.008, 0.0)
    _solve_arm(_arm_l, SHOULDER_L, rest)

# The fist travels on a small ellipse around the shoulder, towards where the blade points.
func _hand_local(angle: float) -> Vector3:
    var dir := Vector2(-sin(angle), cos(angle))
    return SHOULDER_R + Vector3(0.10 + dir.x * 0.30, 0.10 + dir.y * 0.20, 0.0)

func _update_pivot() -> void:
    if is_instance_valid(hammer_pivot):
        hammer_pivot.position = _hand_local(aim_angle) + Vector3(0.0, 0.0, SCYTHE_Z)
        hammer_pivot.rotation = Vector3(0.0, 0.0, aim_angle)

func _make_fallback_pot() -> void:
    var pot := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.82
    mesh.bottom_radius = 0.58
    mesh.height = 0.9
    pot.mesh = mesh
    pot.position.y = 0.15
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.42, 0.46, 0.49)
    mat.metallic = 0.78
    mat.roughness = 0.28
    pot.material_override = mat
    add_child(pot)

    var rim := MeshInstance3D.new()
    var rim_mesh := TorusMesh.new()
    rim_mesh.inner_radius = 0.72
    rim_mesh.outer_radius = 0.88
    rim.mesh = rim_mesh
    rim.position.y = 0.58
    rim.material_override = mat
    add_child(rim)

    var handle_mat := StandardMaterial3D.new()
    handle_mat.albedo_color = Color(0.28, 0.31, 0.34)
    handle_mat.metallic = 0.88
    handle_mat.roughness = 0.24
    for side in [-1.0, 1.0]:
        var handle := MeshInstance3D.new()
        var handle_mesh := TorusMesh.new()
        handle_mesh.inner_radius = 0.105
        handle_mesh.outer_radius = 0.145
        handle.mesh = handle_mesh
        handle.position = Vector3(side * 0.82, 0.25, 0.0)
        handle.rotation.y = PI * 0.5
        handle.material_override = handle_mat
        add_child(handle)

func _make_player_collision() -> void:
    # Collision is owned by ClimbPhysics2D.RigidBody2D.
    pass

func _make_fallback_human() -> void:
    var skin := StandardMaterial3D.new()
    skin.albedo_color = Color(0.78, 0.58, 0.43)
    var head := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.43
    sphere.height = 0.86
    head.mesh = sphere
    head.position = Vector3(0, 0.92, 0)
    head.material_override = skin
    add_child(head)
    var neck := MeshInstance3D.new()
    var neck_mesh := CylinderMesh.new()
    neck_mesh.top_radius = 0.19
    neck_mesh.bottom_radius = 0.23
    neck_mesh.height = 0.34
    neck.mesh = neck_mesh
    neck.position = Vector3(0, 0.66, 0)
    neck.material_override = skin
    add_child(neck)

    var eye_material := StandardMaterial3D.new()
    eye_material.albedo_color = Color(0.055, 0.045, 0.04)
    for side in [-1.0, 1.0]:
        var eye := MeshInstance3D.new()
        var eye_mesh := SphereMesh.new()
        eye_mesh.radius = 0.052
        eye_mesh.height = 0.075
        eye.mesh = eye_mesh
        eye.position = Vector3(side * 0.145, 0.99, 0.365)
        eye.material_override = eye_material
        add_child(eye)

func _make_scythe() -> void:
    hammer_pivot = Node3D.new()
    hammer_pivot.name = "ScythePivot"
    add_child(hammer_pivot)

    # A single tapered ash-wood haft, with a darker end grain and metal collar.
    var wood := StandardMaterial3D.new()
    wood.albedo_color = Color(0.25, 0.13, 0.065)
    wood.roughness = 0.76
    wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
    var shaft := MeshInstance3D.new()
    shaft.name = "AshWoodHaft"
    var shaft_mesh := CylinderMesh.new()
    shaft_mesh.top_radius = 0.047
    shaft_mesh.bottom_radius = 0.073
    shaft_mesh.height = 2.62
    shaft_mesh.radial_segments = 12
    shaft.mesh = shaft_mesh
    shaft.position = Vector3(0.0, 1.20, 0.0)
    shaft.material_override = wood
    hammer_pivot.add_child(shaft)

    var grip_mat := StandardMaterial3D.new()
    grip_mat.albedo_color = Color(0.075, 0.045, 0.028)
    grip_mat.roughness = 0.98
    for band_y in [0.30, 0.40, 0.50, 0.60, 0.70, 0.80]:
        var grip := MeshInstance3D.new()
        var grip_mesh := TorusMesh.new()
        grip_mesh.inner_radius = 0.052
        grip_mesh.outer_radius = 0.078
        grip_mesh.rings = 8
        grip.mesh = grip_mesh
        grip.position = Vector3(0.0, band_y, 0.0)
        grip.rotation.x = PI * 0.5
        grip.material_override = grip_mat
        hammer_pivot.add_child(grip)

    var steel := StandardMaterial3D.new()
    steel.albedo_color = Color(0.68, 0.75, 0.79)
    steel.metallic = 0.94
    steel.roughness = 0.24
    steel.metallic_specular = 0.9

    var collar := MeshInstance3D.new()
    var collar_mesh := CylinderMesh.new()
    collar_mesh.top_radius = 0.105
    collar_mesh.bottom_radius = 0.105
    collar_mesh.height = 0.19
    collar.mesh = collar_mesh
    collar.position = Vector3(0.0, 2.43, 0.0)
    collar.material_override = steel
    hammer_pivot.add_child(collar)

    # Forged crescent blade: one continuous extruded mesh, not a row of boxes.
    var outline := PackedVector2Array([
        Vector2(-0.06, 2.48),
        Vector2(0.28, 2.52),
        Vector2(0.67, 2.69),
        Vector2(1.02, 2.98),
        Vector2(1.27, 3.36),
        Vector2(1.38, 3.77),
        Vector2(1.31, 4.14),
        Vector2(1.08, 4.43),
        Vector2(0.76, 4.57),
        Vector2(0.56, 4.48),
        Vector2(0.84, 4.28),
        Vector2(1.02, 4.02),
        Vector2(1.08, 3.72),
        Vector2(0.98, 3.43),
        Vector2(0.75, 3.17),
        Vector2(0.43, 2.98),
        Vector2(0.10, 2.88)
    ])
    var blade_surface := SurfaceTool.new()
    blade_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Triangulate the concave crescent outline so the blade stays a clean solid shape.
    var triangles := Geometry2D.triangulate_polygon(outline)
    for i in range(0, triangles.size(), 3):
        var a: Vector2 = outline[triangles[i]]
        var b: Vector2 = outline[triangles[i + 1]]
        var d: Vector2 = outline[triangles[i + 2]]
        blade_surface.add_vertex(Vector3(a.x, a.y, 0.075))
        blade_surface.add_vertex(Vector3(b.x, b.y, 0.075))
        blade_surface.add_vertex(Vector3(d.x, d.y, 0.075))
        blade_surface.add_vertex(Vector3(a.x, a.y, -0.075))
        blade_surface.add_vertex(Vector3(d.x, d.y, -0.075))
        blade_surface.add_vertex(Vector3(b.x, b.y, -0.075))

    for i in range(outline.size()):
        var next_i := (i + 1) % outline.size()
        var p0: Vector2 = outline[i]
        var p1: Vector2 = outline[next_i]
        blade_surface.add_vertex(Vector3(p0.x, p0.y, 0.075))
        blade_surface.add_vertex(Vector3(p0.x, p0.y, -0.075))
        blade_surface.add_vertex(Vector3(p1.x, p1.y, -0.075))
        blade_surface.add_vertex(Vector3(p0.x, p0.y, 0.075))
        blade_surface.add_vertex(Vector3(p1.x, p1.y, -0.075))
        blade_surface.add_vertex(Vector3(p1.x, p1.y, 0.075))

    blade_surface.generate_normals()
    var blade := MeshInstance3D.new()
    blade.name = "ForgedCrescentBlade"
    blade.mesh = blade_surface.commit()
    blade.material_override = steel
    hammer_pivot.add_child(blade)

    # A darker sharpened bevel follows the inner crescent edge.
    var edge_material := StandardMaterial3D.new()
    edge_material.albedo_color = Color(0.25, 0.32, 0.35)
    edge_material.metallic = 0.98
    edge_material.roughness = 0.18
    var edge_points := [
        Vector2(0.56, 4.48), Vector2(0.84, 4.28),
        Vector2(1.02, 4.02), Vector2(1.08, 3.72),
        Vector2(0.98, 3.43), Vector2(0.75, 3.17)
    ]
    for i in range(edge_points.size() - 1):
        var p0: Vector2 = edge_points[i]
        var p1: Vector2 = edge_points[i + 1]
        var edge_segment := MeshInstance3D.new()
        var edge_mesh := BoxMesh.new()
        var edge_length := p0.distance_to(p1)
        edge_mesh.size = Vector3(edge_length, 0.035, 0.16)
        edge_segment.mesh = edge_mesh
        edge_segment.position = Vector3((p0.x + p1.x) * 0.5, (p0.y + p1.y) * 0.5, 0.0)
        edge_segment.rotation.z = (p1 - p0).angle()
        edge_segment.material_override = edge_material
        hammer_pivot.add_child(edge_segment)

    # Two visible rivets anchor the blade tang to the haft.
    for rivet_y in [2.58, 2.77]:
        var rivet := MeshInstance3D.new()
        var rivet_mesh := SphereMesh.new()
        rivet_mesh.radius = 0.055
        rivet_mesh.height = 0.11
        rivet.mesh = rivet_mesh
        rivet.position = Vector3(0.16, rivet_y, 0.105)
        rivet.material_override = edge_material
        hammer_pivot.add_child(rivet)

    hammer_head = Node3D.new()
    hammer_head.position = Vector3(1.31, 4.14, 0.0)
    hammer_pivot.add_child(hammer_head)


# ---------------------------------------------------------------------------
# Scythe collision (swept, so the blade can't tunnel through walls)
# ---------------------------------------------------------------------------
func _probe_scythe(angle: float) -> Dictionary:
    var space := get_world_3d().direct_space_state
    var hand := global_position + _hand_local(angle)
    hand.z = PLAY_PLANE_Z + SCYTHE_Z
    var rot := Basis(Vector3.BACK, angle)
    var result := {"hits": 0}
    for local_point in scythe_points:
        var world_point := hand + rot * local_point
        _scythe_query.transform = Transform3D(Basis.IDENTITY, world_point)
        var overlaps := space.intersect_shape(_scythe_query, 1)
        if overlaps.is_empty():
            continue
        result["hits"] = int(result["hits"]) + 1
        if result.has("point"):
            continue
        var info := space.get_rest_info(_scythe_query)
        var normal := (world_point - hand).normalized()
        var point := world_point
        var collider = (overlaps[0] as Dictionary).get("collider")
        if not info.is_empty():
            normal = info.get("normal", normal)
            point = info.get("point", point)
        result["point"] = point
        result["normal"] = normal
        result["collider"] = collider
    return result

func _update_scythe(delta: float) -> void:
    scythe_contact_valid = false
    is_gripping_hold = false
    scythe_contact_collider = null
    if not dragging:
        hold_anchor_active = false
        if hazard_cooldown <= 0.0:
            hook_feedback = IDLE_HINT
        return

    var diff := wrapf(target_angle - aim_angle, -PI, PI)
    var max_step := MAX_SWING_SPEED * delta
    var step_total := clampf(diff, -max_step, max_step)
    var current := _probe_scythe(aim_angle)
    var hits_now: int = current["hits"]
    var contact: Dictionary = {}

    if absf(step_total) < 0.0005:
        if hits_now > 0:
            contact = current
    else:
        var steps := maxi(1, ceili(absf(step_total) / SCYTHE_STEP))
        var sub := step_total / float(steps)
        for i in range(steps):
            var nxt := _probe_scythe(aim_angle + sub)
            var nxt_hits: int = nxt["hits"]
            if nxt_hits > hits_now:
                # Stop on the first colliding sub-step so the rendered blade and
                # the contact point describe the same pose.
                aim_angle += sub
                contact = nxt
                break
            aim_angle += sub
            hits_now = nxt_hits
            contact = nxt if nxt_hits > 0 else {}
        aim_angle = wrapf(aim_angle, -PI, PI)

    _update_pivot()
    if contact.is_empty():
        hold_anchor_active = false
        if hazard_cooldown <= 0.0:
            hook_feedback = "Коснись экрана и веди серп к камню."
        return

    scythe_contact_valid = true
    scythe_contact_point = contact["point"]
    scythe_contact_collider = contact.get("collider")
    var contacted_node := scythe_contact_collider as Node
    if is_instance_valid(contacted_node) and contacted_node.is_in_group("climbable_hold"):
        is_gripping_hold = true
        if not hold_anchor_active:
            hold_anchor = scythe_contact_point
            hold_rope_length = clampf(global_position.distance_to(hold_anchor), 1.0, 5.5)
            hold_anchor_active = true
        hook_feedback = "Зацепился! Раскачивайся и подтягивайся серпом."
    else:
        hold_anchor_active = false
    if is_gripping_hold:
        if absf(step_total) >= 0.0005:
            _apply_scythe_push(contact, step_total)
    elif absf(step_total) < 0.0005:
        hook_feedback = "Упёрся. Веди палец, чтобы оттолкнуться."
    else:
        hook_feedback = "Есть упор! Веди серп дальше, чтобы подняться."
        _apply_scythe_push(contact, step_total)

# Reaction force: the blade can't move into the surface, so the pot is pushed away from it,
# and dragging the blade along a surface pulls the pot the opposite way.
func _apply_scythe_push(contact: Dictionary, step: float) -> void:
    var collider: Object = contact.get("collider")
    if collider is Node and (collider as Node).is_in_group("climb_hazard"):
        return
    var hand := global_position + _hand_local(aim_angle)
    var point: Vector3 = contact["point"]
    var rel := point - hand
    rel.z = 0.0
    var dist := rel.length()
    if dist < 0.05:
        return
    var normal: Vector3 = contact["normal"]
    normal.z = 0.0
    if normal.length_squared() < 0.01:
        normal = -rel
    normal = normal.normalized()
    if normal.dot(-rel) < 0.0:        # make the normal point from the surface back to the hand
        normal = -normal
    var motion := Vector3(-rel.y, rel.x, 0.0).normalized() * signf(step)
    var into := maxf(0.0, -motion.dot(normal))
    var slide := motion - normal * motion.dot(normal)
    var push := normal * into - slide * SCRAPE_GRIP
    var impulse := push * (absf(step) * dist) * PUSH_GAIN
    if impulse.length() > MAX_PUSH_PER_FRAME:
        impulse = impulse.normalized() * MAX_PUSH_PER_FRAME
    velocity += impulse


# Pendulum constraint: the hooked scythe becomes a fixed anchor and the climber
# swings around it under gravity instead of freezing in mid-air.
func _apply_hold_rope_constraint() -> void:
    var offset := global_position - hold_anchor
    offset.z = 0.0
    var distance := offset.length()
    if distance < 0.001:
        return
    if distance > hold_rope_length:
        var radial := offset / distance
        global_position.x = hold_anchor.x + radial.x * hold_rope_length
        global_position.y = hold_anchor.y + radial.y * hold_rope_length
        # Remove only velocity that stretches the rope; tangential speed is preserved
        # so gravity can build a natural pendulum swing.
        var outward_speed := velocity.dot(radial)
        if outward_speed > 0.0:
            velocity -= radial * outward_speed


# ---------------------------------------------------------------------------
# Input: one finger drives the scythe; extra fingers and HUD buttons are ignored
# ---------------------------------------------------------------------------
func release_pointer() -> void:
    dragging = false
    touch_index = -1

func set_silhouette_mode(enabled: bool) -> void:
    silhouette_mode = enabled
    var black := StandardMaterial3D.new()
    black.albedo_color = Color.BLACK
    black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    for node in find_children("*", "", true, false):
        if node is SpriteBase3D:
            (node as SpriteBase3D).modulate = Color.BLACK if enabled else Color.WHITE
        elif node is MeshInstance3D:
            var mesh_node := node as MeshInstance3D
            if enabled:
                mesh_node.material_override = black
            else:
                mesh_node.material_override = null

func reset_hammer() -> void:
    aim_angle = START_ANGLE
    target_angle = START_ANGLE
    release_pointer()
    scythe_contact_valid = false
    scythe_contact_collider = null
    is_gripping_hold = false
    hook_feedback = IDLE_HINT
    if is_instance_valid(physics_world):
        physics_world.reset_to(Vector2(global_position.x, -global_position.y))
    _update_pivot()
    _update_arms()

func _is_over_ui(pos: Vector2) -> bool:
    for c in ui_blockers:
        if is_instance_valid(c) and c is Control:
            var ctrl := c as Control
            if ctrl.is_visible_in_tree() and ctrl.get_global_rect().has_point(pos):
                return true
    return false

func _begin_aim(pos: Vector2, index: int) -> void:
    touch_index = index
    dragging = true
    _aim_from_pointer(pos)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if touch_index == -1 and not _is_over_ui(event.position):
                _begin_aim(event.position, event.index)
        elif event.index == touch_index:
            release_pointer()
    elif event is InputEventScreenDrag:
        if event.index == touch_index:
            _aim_from_pointer(event.position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.device == InputEvent.DEVICE_ID_EMULATION:
            return                      # emulated from touch; the touch event already handled it
        if event.pressed:
            if touch_index == -1 and not _is_over_ui(event.position):
                _begin_aim(event.position, -2)
        elif touch_index == -2:
            release_pointer()
    elif event is InputEventMouseMotion and touch_index == -2:
        _aim_from_pointer(event.position)

func _aim_from_pointer(screen_position: Vector2) -> void:
    var active_camera := get_viewport().get_camera_3d()
    if active_camera == null:
        return
    # Aim from the (fixed) shoulder, so the angle doesn't depend on the moving fist.
    var origin := active_camera.unproject_position(global_position + SHOULDER_R)
    var v := screen_position - origin
    if v.length_squared() < 16.0:
        return
    target_angle = wrapf(atan2(-v.y, v.x) - PI * 0.5, -PI, PI)
    if is_instance_valid(physics_world) and is_instance_valid(physics_world.pot):
        var shoulder_2d := physics_world.pot.global_position + Vector2(0.30, -0.72).rotated(physics_world.pot.rotation)
        var direction_2d := Vector2(v.x, v.y).normalized()
        physics_world.set_target_world(shoulder_2d + direction_2d * ClimbPhysics2D.ARM_REACH)


# ---------------------------------------------------------------------------
# Main physics loop
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
    _time += delta
    if not is_instance_valid(physics_world) or not is_instance_valid(physics_world.pot):
        _update_arms()
        return
    var pot_position := physics_world.sync_visible_position()
    global_position = Vector3(pot_position.x, -pot_position.y, PLAY_PLANE_Z)
    aim_angle = wrapf(-physics_world.hammer.rotation, -PI, PI)
    rotation.z = -physics_world.pot.rotation
    _update_pivot()
    _update_arms()
