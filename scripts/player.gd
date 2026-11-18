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
var imported_skeleton: Skeleton3D
var posed_bones: Array[int] = []
var hook_feedback := "Веди серп пальцем по экрану. Упирайся лезвием в препятствия, чтобы отталкиваться."

func _ready() -> void:
    global_position.z = PLAY_PLANE_Z
    var pot_loaded := _add_imported_model("res://assets/models/cauldron.glb", 1.72, "ImportedCauldron")
    if not pot_loaded:
        _make_fallback_pot()
    _make_player_collision()
    var human_loaded := _add_imported_model("res://assets/models/male-base-mesh-base_male.glb", 1.58, "ImportedClimber")
    if human_loaded:
        var human := get_node("ImportedClimber") as Node3D
        # Keep the lower body inside the pot; the upper torso and head remain visible.
        human.position = Vector3(0.0, -0.08, 0.12)
        human.rotation_degrees = Vector3(0.0, 180.0, 0.0)
        _apply_seated_pose(human)
    else:
        _make_fallback_human()
    scythe_probe.radius = 0.22
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
    hammer_pivot.position = Vector3(0.48, 0.95, 0.0)
    add_child(hammer_pivot)

    var wood := StandardMaterial3D.new()
    wood.albedo_color = Color(0.19, 0.105, 0.055)
    wood.roughness = 0.82
    var shaft := MeshInstance3D.new()
    var shaft_mesh := CylinderMesh.new()
    shaft_mesh.top_radius = 0.055
    shaft_mesh.bottom_radius = 0.085
    shaft_mesh.height = 2.55
    shaft.mesh = shaft_mesh
    shaft.position = Vector3(0.0, 1.20, 0.0)
    shaft.material_override = wood
    hammer_pivot.add_child(shaft)

    var grip_mat := StandardMaterial3D.new()
    grip_mat.albedo_color = Color(0.095, 0.055, 0.032)
    grip_mat.roughness = 0.95
    for band_y in [0.35, 0.47, 0.59, 0.71]:
        var grip := MeshInstance3D.new()
        var grip_mesh := TorusMesh.new()
        grip_mesh.inner_radius = 0.058
        grip_mesh.outer_radius = 0.082
        grip.mesh = grip_mesh
        grip.position = Vector3(0.0, band_y, 0.0)
        grip.rotation.x = PI * 0.5
        grip.material_override = grip_mat
        hammer_pivot.add_child(grip)

    var steel := StandardMaterial3D.new()
    steel.albedo_color = Color(0.72, 0.79, 0.83)
    steel.metallic = 0.96
    steel.roughness = 0.17
    steel.metallic_specular = 0.95

    # Large crescent blade assembled from overlapping tapered-looking metal segments.
    var blade_points: Array[Vector2] = [
        Vector2(0.00, 2.12),
        Vector2(0.34, 2.22),
        Vector2(0.72, 2.43),
        Vector2(1.02, 2.72),
        Vector2(1.18, 3.04),
        Vector2(1.17, 3.34),
        Vector2(0.99, 3.58),
        Vector2(0.72, 3.72)
    ]
    for i in range(blade_points.size() - 1):
        var start := blade_points[i]
        var finish := blade_points[i + 1]
        var segment := MeshInstance3D.new()
        var segment_mesh := BoxMesh.new()
        var length := start.distance_to(finish)
        segment_mesh.size = Vector3(length + 0.08, 0.30 - float(i) * 0.012, 0.12)
        segment.mesh = segment_mesh
        segment.position = Vector3((start.x + finish.x) * 0.5, (start.y + finish.y) * 0.5, 0.0)
        segment.rotation.z = (finish - start).angle()
        segment.material_override = steel
        hammer_pivot.add_child(segment)

    # Dark inner cutting edge gives the crescent a readable silhouette.
    for i in range(1, blade_points.size() - 1):
        var point := blade_points[i]
        var edge := MeshInstance3D.new()
        var edge_mesh := BoxMesh.new()
        edge_mesh.size = Vector3(0.22, 0.045, 0.135)
        edge.mesh = edge_mesh
        edge.position = Vector3(point.x - 0.10, point.y - 0.12, 0.0)
        edge.rotation.z = (blade_points[i + 1] - blade_points[i - 1]).angle()
        var dark_steel := StandardMaterial3D.new()
        dark_steel.albedo_color = Color(0.22, 0.29, 0.33)
        dark_steel.metallic = 0.9
        dark_steel.roughness = 0.25
        edge.material_override = dark_steel
        hammer_pivot.add_child(edge)

    hammer_head = Node3D.new()
    hammer_head.position = Vector3(0.72, 3.72, 0.0)
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
                contact = {"position": world_point, "collider": candidate.get("collider")}
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
            scythe_contact_point = contact.get("position", hammer_pivot.global_position)
            scythe_contact_point.z = PLAY_PLANE_Z
            scythe_contact_collider = contact.get("collider")
            return false
    scythe_contact_valid = false
    scythe_contact_collider = null
    return true

func reset_hammer() -> void:
    aim_angle = -0.72
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
    aim_angle = clampf(atan2(-pointer_vector.y, pointer_vector.x) - PI * 0.5, -PI, PI)
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
            scythe_contact_point = contact.get("position", hammer_pivot.global_position)
            var normal: Vector3 = contact.get("normal", (hammer_pivot.global_position - scythe_contact_point).normalized())
            normal.z = 0.0
            normal = normal.normalized()
            if normal.length_squared() > 0.1:
                velocity += normal * 28.0 * delta
                var tangent := Vector3(-normal.y, normal.x, 0.0)
                velocity += tangent * clampf(aim_angle * 0.7, -0.8, 0.8) * delta
            hook_feedback = "Есть упор! Веди серп дальше, чтобы подняться."
        else:
            hook_feedback = "Коснись экрана и веди серп к камню."

    velocity.x = clampf(velocity.x, -MAX_HORIZONTAL_SPEED, MAX_HORIZONTAL_SPEED)
    velocity.y = clampf(velocity.y, -13.0, 15.0)
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
