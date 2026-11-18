extends CharacterBody3D

# Tuned for a deliberately difficult, momentum-based climbing game.
const GRAVITY := 19.0
const MOVE_ACCEL := 8.0
const AIR_STEER := 3.2
const MAX_HORIZONTAL_SPEED := 7.5
const SCYTHE_REACH := 5.0
const HOOK_SPRING := 34.0
const HOOK_DAMPING := 7.5
const MAX_HOOK_ACCEL := 42.0
const PUMP_ACCEL := 13.0
const PLAY_PLANE_Z := 0.0

var hammer_pivot: Node3D
var hammer_head: Node3D
var scythe_contact_valid := false
var scythe_contact_point := Vector3.ZERO
var scythe_contact_collider: Object = null
var scythe_probe := SphereShape3D.new()
var aim_angle := -0.72
var aim_elevation := 0.0
var dragging := false
var pointer_position := Vector2.ZERO
var last_aim_angle := -0.72
var swing_delta := 0.0
var imported_skeleton: Skeleton3D
var posed_bones: Array[int] = []
var hook_feedback := "Веди серп пальцем по экрану. Упирайся лезвием в препятствия, чтобы отталкиваться."

func _ready() -> void:
    global_position.z = PLAY_PLANE_Z
    _make_player_collision()

    # Use the newly uploaded illustrated character-in-a-pot asset.
    # It is a front-facing 2D character plate inside the 3D world; the scythe,
    # collision and climbing physics remain fully 3D.
    var character_texture := load("res://assets/character.svg") as Texture2D
    if character_texture != null:
        var character_sprite := Sprite3D.new()
        character_sprite.name = "UploadedCharacter"
        character_sprite.texture = character_texture
        character_sprite.pixel_size = 0.00335
        character_sprite.position = Vector3(0.0, 0.86, 0.12)
        character_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
        character_sprite.shaded = true
        add_child(character_sprite)
    else:
        push_warning("Uploaded character SVG could not be loaded; using the 3D fallback.")
        var pot_loaded := _add_imported_model("res://assets/models/cauldron.glb", 1.72, "ImportedCauldron")
        if not pot_loaded:
            _make_fallback_pot()
        var human_loaded := _add_imported_model("res://assets/models/male-base-mesh-base_male.glb", 1.58, "ImportedClimber")
        if human_loaded:
            var human := get_node("ImportedClimber") as Node3D
            human.position = Vector3(0.0, -0.08, 0.12)
            human.rotation_degrees = Vector3(0.0, 180.0, 0.0)
            _apply_seated_pose(human)
        else:
            _make_fallback_human()

    scythe_probe.radius = 0.18
    _make_scythe()


func _apply_seated_pose(root: Node) -> void:
    imported_skeleton = _find_skeleton(root)
    if imported_skeleton == null:
        push_warning("Imported climber has no Skeleton3D; using its original bind pose.")
        return

    # Bone names differ between model exporters, so identify common humanoid names.
    for bone_index in range(imported_skeleton.get_bone_count()):
        var bone_name := imported_skeleton.get_bone_name(bone_index).to_lower().replace("_", "").replace(" ", "")
        var pose := Quaternion.IDENTITY
        var matched := false

        if bone_name.contains("leftupperarm") or bone_name.contains("upperarm.l") or bone_name.contains("upperarml") or bone_name.contains("leftarm"):
            pose = Quaternion(Vector3.FORWARD, deg_to_rad(-48.0))
            matched = true
        elif bone_name.contains("rightupperarm") or bone_name.contains("upperarm.r") or bone_name.contains("upperarmr") or bone_name.contains("rightarm"):
            pose = Quaternion(Vector3.FORWARD, deg_to_rad(48.0))
            matched = true
        elif bone_name.contains("leftforearm") or bone_name.contains("lowerarm.l") or bone_name.contains("lowerarml") or bone_name.contains("leftlowerarm"):
            pose = Quaternion(Vector3.FORWARD, deg_to_rad(-72.0))
            matched = true
        elif bone_name.contains("rightforearm") or bone_name.contains("lowerarm.r") or bone_name.contains("lowerarmr") or bone_name.contains("rightlowerarm"):
            pose = Quaternion(Vector3.FORWARD, deg_to_rad(72.0))
            matched = true
        elif bone_name.contains("leftupleg") or bone_name.contains("leftthigh") or bone_name.contains("thigh.l") or bone_name.contains("thighl"):
            pose = Quaternion(Vector3.RIGHT, deg_to_rad(-72.0))
            matched = true
        elif bone_name.contains("rightupleg") or bone_name.contains("rightthigh") or bone_name.contains("thigh.r") or bone_name.contains("thighr"):
            pose = Quaternion(Vector3.RIGHT, deg_to_rad(-72.0))
            matched = true
        elif bone_name.contains("leftleg") or bone_name.contains("calf.l") or bone_name.contains("calfl") or bone_name.contains("leftcalf"):
            pose = Quaternion(Vector3.RIGHT, deg_to_rad(92.0))
            matched = true
        elif bone_name.contains("rightleg") or bone_name.contains("calf.r") or bone_name.contains("calfr") or bone_name.contains("rightcalf"):
            pose = Quaternion(Vector3.RIGHT, deg_to_rad(92.0))
            matched = true

        if matched:
            imported_skeleton.set_bone_pose_rotation(bone_index, pose)
            posed_bones.append(bone_index)

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

func _add_imported_model(path: String, target_size: float, node_name: String) -> bool:
    if not ResourceLoader.exists(path):
        push_warning("Model not found: " + path)
        return false
    var packed := load(path) as PackedScene
    if packed == null:
        push_warning("Could not load model scene: " + path)
        return false
    var instance := packed.instantiate() as Node3D
    if instance == null:
        push_warning("Model root is not Node3D: " + path)
        return false
    instance.name = node_name
    add_child(instance)
    var bounds := _measure_model_bounds(instance, Transform3D.IDENTITY)
    if bounds.size.length() < 0.001:
        instance.queue_free()
        push_warning("Model has no visible mesh bounds: " + path)
        return false
    var largest_horizontal := maxf(bounds.size.x, bounds.size.z)
    var reference_size := largest_horizontal if node_name == "ImportedCauldron" else bounds.size.y
    var scale_factor := target_size / maxf(reference_size, 0.001)
    instance.scale = Vector3.ONE * scale_factor
    if node_name == "ImportedCauldron":
        # Align the imported pot's bottom with the original collision body.
        instance.position.y = -0.30 - bounds.position.y * scale_factor
    else:
        # The model is scaled to a human-sized height; the pot hides the legs.
        instance.position.y = -0.12
    return true

func _measure_model_bounds(node: Node, parent_transform: Transform3D) -> AABB:
    var current_transform := parent_transform
    if node is Node3D:
        current_transform = parent_transform * (node as Node3D).transform
    var combined := AABB()
    var has_bounds := false
    if node is MeshInstance3D and node.mesh != null:
        combined = current_transform * node.mesh.get_aabb()
        has_bounds = true
    for child in node.get_children():
        var child_bounds := _measure_model_bounds(child, current_transform)
        if child_bounds.size.length() > 0.001:
            if has_bounds:
                combined = combined.merge(child_bounds)
            else:
                combined = child_bounds
                has_bounds = true
    return combined

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
    var body_shape := CollisionShape3D.new()
    var shape := CylinderShape3D.new()
    shape.radius = 0.72
    shape.height = 0.9
    body_shape.shape = shape
    body_shape.position.y = 0.15
    add_child(body_shape)

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
    hammer_pivot.position = Vector3(0.42, 0.98, -0.04)
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


func _scythe_sample_points() -> Array[Vector3]:
    return [
        Vector3(0.0, 0.65, 0.0),
        Vector3(0.0, 1.15, 0.0),
        Vector3(0.0, 1.70, 0.0),
        Vector3(0.0, 2.15, 0.0),
        Vector3(0.22, 2.18, 0.0),
        Vector3(0.38, 2.25, 0.0),
        Vector3(0.56, 2.36, 0.0),
        Vector3(0.74, 2.48, 0.0),
        Vector3(0.90, 2.61, 0.0),
        Vector3(1.03, 2.76, 0.0),
        Vector3(1.12, 2.91, 0.0),
        Vector3(1.18, 3.08, 0.0),
        Vector3(1.18, 3.22, 0.0),
        Vector3(1.16, 3.37, 0.0),
        Vector3(0.98, 3.58, 0.0),
        Vector3(0.72, 3.72, 0.0)
    ]

func _query_scythe_collision(angle: float) -> Dictionary:
    var space := get_world_3d().direct_space_state
    var local_basis := Basis(Vector3(0.0, 0.0, 1.0), angle)
    for local_point in _scythe_sample_points():
        var world_point := hammer_pivot.global_position + local_basis * local_point
        var query := PhysicsShapeQueryParameters3D.new()
        query.shape = scythe_probe
        query.transform = Transform3D(Basis.IDENTITY, world_point)
        query.exclude = [get_rid()]
        query.collide_with_bodies = true
        query.collide_with_areas = false
        var overlaps := space.intersect_shape(query, 4)
        if not overlaps.is_empty():
            var contact := space.get_rest_info(query)
            if contact.is_empty():
                var candidate: Dictionary = overlaps[0]
                contact = {"point": world_point, "collider": candidate.get("collider"), "normal": (world_point - hammer_pivot.global_position).normalized()}
            var surface_normal: Vector3 = contact.get("normal", Vector3.ZERO)
            if surface_normal.length_squared() > 0.01:
                return contact
    return {}

func _try_lock_scythe_angle(previous_angle: float, next_angle: float) -> bool:
    var delta_angle := next_angle - previous_angle
    var steps := maxi(1, int(ceil(absf(delta_angle) / 0.045)))
    for step in range(1, steps + 1):
        var sample_angle := lerpf(previous_angle, next_angle, float(step) / float(steps))
        var contact := _query_scythe_collision(sample_angle)
        if not contact.is_empty():
            scythe_contact_valid = true
            scythe_contact_point = contact.get("point", hammer_pivot.global_position)
            scythe_contact_point.z = PLAY_PLANE_Z
            scythe_contact_collider = contact.get("collider")
            return false
    scythe_contact_valid = false
    scythe_contact_collider = null
    return true

func reset_hammer() -> void:
    aim_angle = -0.72
    last_aim_angle = aim_angle
    swing_delta = 0.0
    aim_elevation = 0.0
    dragging = false
    scythe_contact_valid = false
    scythe_contact_collider = null
    hammer_pivot.rotation = Vector3.ZERO
    _update_hammer_pose()

func _input(event: InputEvent) -> void:
    # Read touch globally before GUI controls can consume it.
    if event is InputEventScreenTouch:
        dragging = event.pressed
        if dragging:
            pointer_position = event.position
            _aim_from_pointer(pointer_position)
    elif event is InputEventScreenDrag and dragging:
        pointer_position = event.position
        _aim_from_pointer(pointer_position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        dragging = event.pressed
        if dragging:
            pointer_position = event.position
            _aim_from_pointer(pointer_position)
    elif event is InputEventMouseMotion and dragging:
        pointer_position = event.position
        _aim_from_pointer(pointer_position)

func _aim_from_pointer(screen_position: Vector2) -> void:
    var active_camera := get_viewport().get_camera_3d()
    if active_camera == null or not is_instance_valid(hammer_pivot):
        return
    var pivot_screen := active_camera.unproject_position(hammer_pivot.global_position)
    var pointer_vector := screen_position - pivot_screen
    if pointer_vector.length_squared() < 16.0:
        return
    var next_angle := clampf(atan2(-pointer_vector.y, pointer_vector.x) - PI * 0.5, -PI, PI)
    swing_delta = clampf(swing_delta + wrapf(next_angle - aim_angle, -PI, PI), -0.85, 0.85)
    last_aim_angle = aim_angle
    aim_angle = next_angle
    _update_hammer_pose()

func _update_hammer_pose() -> void:
    if is_instance_valid(hammer_pivot):
        hammer_pivot.rotation = Vector3(0.0, 0.0, aim_angle)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= GRAVITY * delta

    # The held blade pushes against collision surfaces and transfers the reaction force to the cauldron.
    scythe_contact_valid = false
    if dragging and is_instance_valid(hammer_pivot):
        var contact := _query_scythe_collision(aim_angle)
        if not contact.is_empty():
            scythe_contact_valid = true
            scythe_contact_point = contact.get("point", hammer_pivot.global_position)
            var normal: Vector3 = contact.get("normal", (scythe_contact_point - hammer_pivot.global_position).normalized())
            normal.z = 0.0
            normal = normal.normalized()
            if normal.length_squared() > 0.1:
                # Surface reaction lifts or swings the whole cauldron.
                var contact_strength := clampf(1.0 + absf(swing_delta) * 2.4, 1.0, 2.6)
                var lever_arm := scythe_contact_point - global_position
                var torque_direction := Vector3(-lever_arm.y, lever_arm.x, 0.0).normalized()
                var push_direction := normal
                if torque_direction.length_squared() > 0.1 and absf(swing_delta) > 0.015:
                    push_direction = (normal + torque_direction * signf(swing_delta) * 0.42).normalized()
                velocity += push_direction * MAX_HOOK_ACCEL * contact_strength * delta
                if torque_direction.length_squared() > 0.1:
                    velocity += torque_direction * clampf(swing_delta * PUMP_ACCEL, -3.2, 3.2)
                swing_delta = 0.0
                # Keep a small upward component when bracing against a near-vertical wall.
                if absf(normal.y) < 0.28:
                    velocity.y += 5.5 * delta
            hook_feedback = "Есть упор! Веди серп дальше, чтобы подняться."
        else:
            hook_feedback = "Коснись экрана и веди серп к камню."
            swing_delta = move_toward(swing_delta, 0.0, 5.5 * delta)
    else:
        swing_delta = move_toward(swing_delta, 0.0, 5.5 * delta)
    if is_on_floor():
        velocity.x = move_toward(velocity.x, 0.0, 2.4 * delta)
    velocity.x = clampf(velocity.x, -MAX_HORIZONTAL_SPEED, MAX_HORIZONTAL_SPEED)
    velocity.y = clampf(velocity.y, -15.0, 18.0)
    velocity.z = 0.0
    move_and_slide()
    velocity.z = 0.0
    global_position.z = PLAY_PLANE_Z

    for collision_index in range(get_slide_collision_count()):
        var collision := get_slide_collision(collision_index)
        var collider := collision.get_collider()
        if collider is Node and (collider as Node).is_in_group("climb_hazard"):
            velocity += collision.get_normal() * 3.5
            hook_feedback = "Опасное препятствие! Обойди его серпом."
            break
