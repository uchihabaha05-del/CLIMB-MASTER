extends CharacterBody3D

const MOVE_SPEED := 5.2
const GRAVITY := 18.0
const REACH := 3.2

var mobile := {"left": false, "right": false, "up": false}
var hammer_pivot: Node3D
var aim_angle := -0.7
var dragging := false
var anchor_point := Vector3.ZERO
var anchored := false

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
    rod.top_radius = 0.07
    rod.bottom_radius = 0.09
    rod.height = 2.15
    handle.mesh = rod
    handle.position = Vector3(0, 1.0, 0)
    handle.rotation.z = -0.45
    var wood := StandardMaterial3D.new()
    wood.albedo_color = Color(0.31, 0.17, 0.09)
    handle.material_override = wood
    hammer_pivot.add_child(handle)

    var hammer_head := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.95, 0.32, 0.38)
    hammer_head.mesh = box
    hammer_head.position = Vector3(0.48, 2.02, 0)
    hammer_head.rotation.z = -0.45
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color(0.55, 0.59, 0.62)
    metal.metallic = 0.9
    metal.roughness = 0.22
    hammer_head.material_override = metal
    hammer_pivot.add_child(hammer_head)

func set_mobile_input(key: String, pressed: bool) -> void:
    if mobile.has(key):
        mobile[key] = pressed

func reset_hammer() -> void:
    aim_angle = -0.7
    anchored = false
    hammer_pivot.rotation = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            dragging = true
        else:
            if dragging:
                _try_hook()
            dragging = false
    elif event is InputEventScreenDrag and dragging:
        aim_angle += event.relative.x * 0.012
        hammer_pivot.rotation.z = aim_angle
        hammer_pivot.rotation.x = -event.relative.y * 0.008
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            dragging = true
        else:
            if dragging:
                _try_hook()
            dragging = false
    elif event is InputEventMouseMotion and dragging:
        aim_angle += event.relative.x * 0.012
        hammer_pivot.rotation.z = aim_angle
        hammer_pivot.rotation.x = -event.relative.y * 0.008

func _physics_process(delta: float) -> void:
    var horizontal := Input.get_axis("ui_left", "ui_right")
    if mobile["left"]:
        horizontal = -1.0
    if mobile["right"]:
        horizontal = 1.0
    velocity.x = move_toward(velocity.x, horizontal * MOVE_SPEED, 18.0 * delta)

    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif mobile["up"] or Input.is_action_just_pressed("ui_accept"):
        velocity.y = 7.0

    if anchored:
        var pull := anchor_point - global_position
        velocity += pull.normalized() * 16.0 * delta
        if pull.length() < 1.1:
            anchored = false

    move_and_slide()

func _try_hook() -> void:
    var direction := Vector3(cos(aim_angle), sin(aim_angle), 0).normalized()
    var ray_start := hammer_pivot.global_position
    var ray_end := ray_start + direction * REACH
    var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
    query.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit:
        anchor_point = hit.position
        anchored = true
