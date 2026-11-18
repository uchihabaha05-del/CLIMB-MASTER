extends CharacterBody3D

# Tuned for a deliberately difficult, momentum-based climbing game.
const GRAVITY := 19.0
const MOVE_ACCEL := 8.0
const AIR_STEER := 3.2
const MAX_HORIZONTAL_SPEED := 7.5
const HAMMER_REACH := 3.15
const HOOK_SPRING := 34.0
const HOOK_DAMPING := 7.5
const MAX_HOOK_ACCEL := 42.0
const PUMP_ACCEL := 13.0

var mobile := {"left": false, "right": false, "up": false}
var hammer_pivot: Node3D
var hammer_head: Node3D
var aim_angle := -0.72
var aim_elevation := 0.0
var dragging := false
var release_tap := false
var anchored := false
var anchor_point := Vector3.ZERO
var rope_length := 0.0
var previous_hook_vector := Vector3.ZERO
var hook_cooldown := 0.0

func _ready() -> void:
    _make_pot()
    _make_hammer()

func _make_pot() -> void:
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

    var body_shape := CollisionShape3D.new()
    var shape := CylinderShape3D.new()
    shape.radius = 0.72
    shape.height = 0.9
    body_shape.shape = shape
    body_shape.position.y = 0.15
    add_child(body_shape)

    var head := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.43
    sphere.height = 0.86
    head.mesh = sphere
    head.position = Vector3(0, 0.92, 0)
    var skin := StandardMaterial3D.new()
    skin.albedo_color = Color(0.78, 0.58, 0.43)
    head.material_override = skin
    add_child(head)

func _make_hammer() -> void:
    hammer_pivot = Node3D.new()
    hammer_pivot.position = Vector3(0.48, 0.95, 0)
    add_child(hammer_pivot)

    var handle := MeshInstance3D.new()
    var rod := CylinderMesh.new()
    rod.top_radius = 0.065
    rod.bottom_radius = 0.09
    rod.height = 2.05
    handle.mesh = rod
    handle.position = Vector3(0, 1.0, 0)
    handle.rotation.z = -0.12
    var wood := StandardMaterial3D.new()
    wood.albedo_color = Color(0.25, 0.12, 0.055)
    wood.roughness = 0.82
    handle.material_override = wood
    hammer_pivot.add_child(handle)

    hammer_head = Node3D.new()
    hammer_head.position = Vector3(0, 2.02, 0)
    hammer_pivot.add_child(hammer_head)

    var head_mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.92, 0.34, 0.42)
    head_mesh.mesh = box
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color(0.55, 0.59, 0.62)
    metal.metallic = 0.92
    metal.roughness = 0.2
    head_mesh.material_override = metal
    hammer_head.add_child(head_mesh)

    var cap := MeshInstance3D.new()
    var cap_mesh := BoxMesh.new()
    cap_mesh.size = Vector3(0.2, 0.43, 0.46)
    cap.mesh = cap_mesh
    cap.position.x = 0.48
    cap.material_override = metal
    hammer_head.add_child(cap)

func set_mobile_input(key: String, pressed: bool) -> void:
    if mobile.has(key):
        mobile[key] = pressed

func reset_hammer() -> void:
    aim_angle = -0.72
    aim_elevation = 0.0
    anchored = false
    dragging = false
    hammer_pivot.rotation = Vector3.ZERO
    hook_cooldown = 0.0
    _update_hammer_pose()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if anchored:
                _release_hook()
                release_tap = true
                dragging = false
            else:
                dragging = true
        else:
            if release_tap:
                release_tap = false
            elif dragging:
                _try_hook()
            dragging = false
    elif event is InputEventScreenDrag and dragging:
        _aim_from_drag(event.relative)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            if anchored:
                _release_hook()
                release_tap = true
                dragging = false
            else:
                dragging = true
        else:
            if release_tap:
                release_tap = false
            elif dragging:
                _try_hook()
            dragging = false
    elif event is InputEventMouseMotion and dragging:
        _aim_from_drag(event.relative)

func _aim_from_drag(relative: Vector2) -> void:
    aim_angle = clampf(aim_angle + relative.x * 0.009, -PI * 0.92, PI * 0.92)
    aim_elevation = clampf(aim_elevation - relative.y * 0.006, -0.85, 0.85)
    _update_hammer_pose()

func _update_hammer_pose() -> void:
    if is_instance_valid(hammer_pivot):
        hammer_pivot.rotation = Vector3(aim_elevation, 0.0, aim_angle)

func _physics_process(delta: float) -> void:
    hook_cooldown = maxf(0.0, hook_cooldown - delta)

    var horizontal := Input.get_axis("ui_left", "ui_right")
    if mobile["left"]:
        horizontal = -1.0
    if mobile["right"]:
        horizontal = 1.0

    var steer := AIR_STEER if not is_on_floor() else MOVE_ACCEL
    velocity.x = move_toward(velocity.x, horizontal * MAX_HORIZONTAL_SPEED, steer * delta)

    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif mobile["up"] or Input.is_action_just_pressed("ui_accept"):
        velocity.y = 7.2

    if anchored:
        _apply_hook_physics(delta, horizontal)

    move_and_slide()

    # A hook remains attached to the world point, never to the moving player.
    if anchored and global_position.distance_to(anchor_point) > HAMMER_REACH * 2.6:
        _release_hook()

func _apply_hook_physics(delta: float, horizontal: float) -> void:
    var offset := anchor_point - global_position
    var distance := offset.length()
    if distance < 0.001:
        return

    var direction := offset / distance
    var stretch := distance - rope_length
    var radial_speed := velocity.dot(direction)
    var spring_accel := maxf(0.0, stretch) * HOOK_SPRING - radial_speed * HOOK_DAMPING
    spring_accel = clampf(spring_accel, 0.0, MAX_HOOK_ACCEL)
    velocity += direction * spring_accel * delta

    # Tangential input pumps the swing instead of applying a generic jump.
    var tangent := Vector3(-direction.y, direction.x, 0.0).normalized()
    if mobile["left"]:
        velocity += tangent * PUMP_ACCEL * delta
    elif mobile["right"]:
        velocity -= tangent * PUMP_ACCEL * delta
    if mobile["up"]:
        velocity += direction * 8.0 * delta

func _try_hook() -> void:
    if hook_cooldown > 0.0:
        return
    _update_hammer_pose()
    var origin := hammer_head.global_position
    var direction := (hammer_pivot.global_transform.basis * Vector3(0, 1, 0)).normalized()
    var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * HAMMER_REACH)
    query.exclude = [get_rid()]
    query.collide_with_areas = false
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit:
        anchor_point = hit.position
        rope_length = maxf(1.05, global_position.distance_to(anchor_point))
        anchored = true
        hook_cooldown = 0.18
    else:
        anchored = false

func _release_hook() -> void:
    anchored = false
    hook_cooldown = 0.12
