extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
var player: CharacterBody3D
var camera: Camera3D
var height_label: Label
var status_label: Label
var restart_button: Button
var start_y := 0.0
var peak_y := 0.0
var game_over := false
var checkpoint_positions: Array[Vector3] = []
var active_checkpoint := 0
var checkpoint_label: Label

func _ready() -> void:
    _build_world()
    _build_checkpoints()
    _build_player()
    _build_camera()
    _build_hud()
    start_y = player.global_position.y
    peak_y = start_y

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY

    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.055, 0.12, 0.22)
    sky_material.sky_horizon_color = Color(0.48, 0.58, 0.68)
    sky_material.ground_bottom_color = Color(0.055, 0.065, 0.075)
    sky_material.ground_horizon_color = Color(0.26, 0.30, 0.34)
    sky_material.sun_angle_max = 18.0
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.62, 0.70, 0.82)
    environment.ambient_light_energy = 0.72
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.42, 0.52, 0.62)
    environment.fog_density = 0.012
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.name = "MountainSun"
    sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    sun.light_color = Color(1.0, 0.86, 0.69)
    sun.light_energy = 1.35
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 55.0
    add_child(sun)

    var fill := DirectionalLight3D.new()
    fill.name = "ColdSkyFill"
    fill.rotation_degrees = Vector3(-22.0, 145.0, 0.0)
    fill.light_color = Color(0.42, 0.62, 0.9)
    fill.light_energy = 0.38
    add_child(fill)

    _add_platform(Vector3(0, -0.7, 0), Vector3(9, 1.2, 9), Color(0.25, 0.29, 0.32))
    _add_platform(Vector3(2.5, 2.2, 0.0), Vector3(3.2, 0.6, 2.6), Color(0.35, 0.31, 0.26))
    _add_platform(Vector3(-1.8, 5.0, 0.0), Vector3(2.8, 0.55, 2.4), Color(0.32, 0.36, 0.39))
    _add_platform(Vector3(1.5, 7.8, 0.0), Vector3(2.6, 0.55, 2.3), Color(0.42, 0.34, 0.27))
    _add_platform(Vector3(-2.0, 10.7, 0.0), Vector3(2.8, 0.55, 2.3), Color(0.32, 0.38, 0.34))
    _add_platform(Vector3(1.2, 13.7, 0.0), Vector3(3.0, 0.55, 2.4), Color(0.39, 0.34, 0.31))
    _add_platform(Vector3(-1.2, 16.8, 0.0), Vector3(3.0, 0.55, 2.4), Color(0.31, 0.36, 0.42))
    _add_platform(Vector3(1.5, 20.0, 0.0), Vector3(3.5, 0.65, 3.0), Color(0.43, 0.36, 0.29))

    # Climbable rock pillars now have matching physics colliders.
    for i in range(12):
        var rock_body := StaticBody3D.new()
        var rock_mesh := MeshInstance3D.new()
        var mesh := CylinderMesh.new()
        var top_radius := randf_range(0.45, 0.95)
        var bottom_radius := randf_range(0.75, 1.35)
        var rock_height := randf_range(3.0, 7.0)
        mesh.top_radius = top_radius
        mesh.bottom_radius = bottom_radius
        mesh.height = rock_height
        mesh.radial_segments = 9
        rock_mesh.mesh = mesh
        var mat := StandardMaterial3D.new()
        var rock_tone := randf_range(-0.025, 0.035)
        mat.albedo_color = Color(0.17 + rock_tone, 0.21 + rock_tone, 0.25 + rock_tone)
        mat.roughness = 0.96
        mat.metallic = 0.03
        rock_mesh.material_override = mat
        rock_body.add_child(rock_mesh)

        # Angular boulders break up the repeated pillar silhouette.
        for chunk_index in range(4):
            var chunk := MeshInstance3D.new()
            var chunk_mesh := SphereMesh.new()
            chunk_mesh.radius = randf_range(0.45, 0.9)
            chunk_mesh.height = chunk_mesh.radius * 1.65
            chunk.mesh = chunk_mesh
            chunk.scale = Vector3(randf_range(0.8, 1.4), randf_range(0.65, 1.15), randf_range(0.75, 1.25))
            chunk.position = Vector3(
                randf_range(-bottom_radius * 0.72, bottom_radius * 0.72),
                randf_range(-rock_height * 0.38, rock_height * 0.38),
                randf_range(-bottom_radius * 0.5, bottom_radius * 0.5)
            )
            chunk.material_override = mat
            rock_body.add_child(chunk)

        var rock_collision := CollisionShape3D.new()
        var rock_shape := CylinderShape3D.new()
        rock_shape.radius = maxf(top_radius, bottom_radius)
        rock_shape.height = rock_height
        rock_collision.shape = rock_shape
        rock_body.add_child(rock_collision)

        # Broken stone plates and metallic climbing anchors add readable silhouettes.
        for ledge_index in range(3):
            var ledge := MeshInstance3D.new()
            var ledge_mesh := BoxMesh.new()
            ledge_mesh.size = Vector3(randf_range(0.65, 1.25), 0.16, 0.55)
            ledge.mesh = ledge_mesh
            ledge.position = Vector3(randf_range(-0.35, 0.35), randf_range(-rock_height * 0.35, rock_height * 0.35), bottom_radius * 0.72)
            ledge.rotation.z = randf_range(-0.18, 0.18)
            var stone_edge := StandardMaterial3D.new()
            stone_edge.albedo_color = Color(0.34, 0.35, 0.36)
            stone_edge.roughness = 0.9
            ledge.material_override = stone_edge
            rock_body.add_child(ledge)

        for bolt_index in range(2):
            var bolt := MeshInstance3D.new()
            var bolt_mesh := CylinderMesh.new()
            bolt_mesh.top_radius = 0.075
            bolt_mesh.bottom_radius = 0.075
            bolt_mesh.height = 0.22
            bolt.mesh = bolt_mesh
            bolt.rotation.z = PI * 0.5
            bolt.position = Vector3(randf_range(-0.45, 0.45), randf_range(-rock_height * 0.3, rock_height * 0.3), bottom_radius * 0.88)
            var steel := StandardMaterial3D.new()
            steel.albedo_color = Color(0.22, 0.27, 0.30)
            steel.metallic = 0.92
            steel.roughness = 0.24
            bolt.material_override = steel
            rock_body.add_child(bolt)

        rock_body.position = Vector3(randf_range(-5.5, 5.5), randf_range(1.0, 19.0), randf_range(-3.2, -1.8))
        rock_body.rotation.z = randf_range(-0.2, 0.2)
        add_child(rock_body)

func _build_checkpoints() -> void:
    # Checkpoints sit safely above the third and fifth ledges.
    checkpoint_positions = [
        Vector3(1.5, 8.75, 0.0),
        Vector3(1.2, 14.45, 0.0)
    ]
    for i in range(checkpoint_positions.size()):
        var marker := Node3D.new()
        marker.position = checkpoint_positions[i]
        add_child(marker)

        var ring := MeshInstance3D.new()
        var ring_mesh := TorusMesh.new()
        ring_mesh.inner_radius = 0.65
        ring_mesh.outer_radius = 0.82
        ring.mesh = ring_mesh
        ring.rotation.x = PI * 0.5
        var ring_mat := StandardMaterial3D.new()
        ring_mat.albedo_color = Color(0.15, 0.85, 0.62)
        ring_mat.emission_enabled = true
        ring_mat.emission = Color(0.05, 0.65, 0.42)
        ring_mat.emission_energy_multiplier = 1.4
        ring.material_override = ring_mat
        marker.add_child(ring)

        var beacon := MeshInstance3D.new()
        var beacon_mesh := CylinderMesh.new()
        beacon_mesh.top_radius = 0.035
        beacon_mesh.bottom_radius = 0.12
        beacon_mesh.height = 1.7
        beacon.mesh = beacon_mesh
        beacon.position.y = 0.9
        var beacon_mat := StandardMaterial3D.new()
        beacon_mat.albedo_color = Color(0.1, 0.75, 0.55, 0.28)
        beacon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        beacon_mat.emission_enabled = true
        beacon_mat.emission = Color(0.02, 0.35, 0.22)
        beacon.material_override = beacon_mat
        marker.add_child(beacon)

func _add_platform(pos: Vector3, size: Vector3, color: Color) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.92
    mesh_instance.material_override = mat
    body.add_child(mesh_instance)
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    shape_node.shape = shape
    body.add_child(shape_node)
    add_child(body)

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Climber"
    player.set_script(PLAYER_SCRIPT)
    player.position = Vector3(0, 1.0, 0)
    add_child(player)

func _build_camera() -> void:
    camera = Camera3D.new()
    camera.position = Vector3(0, 4.8, 12.5)
    camera.rotation_degrees = Vector3(-12, 0, 0)
    camera.fov = 48.0
    camera.current = true
    add_child(camera)

func _build_hud() -> void:
    var hud := CanvasLayer.new()
    add_child(hud)

    var panel := PanelContainer.new()
    panel.position = Vector2(18, 16)
    panel.custom_minimum_size = Vector2(300, 82)
    hud.add_child(panel)
    var vbox := VBoxContainer.new()
    panel.add_child(vbox)

    height_label = Label.new()
    height_label.text = "ВЫСОТА: 0 м"
    height_label.add_theme_font_size_override("font_size", 23)
    vbox.add_child(height_label)

    status_label = Label.new()
    status_label.text = "Веди молот пальцем и отпусти для зацепа. Нажми ещё раз, чтобы отпустить."
    vbox.add_child(status_label)

    var controls := HBoxContainer.new()
    controls.anchor_left = 0.5
    controls.anchor_right = 0.5
    controls.anchor_top = 1.0
    controls.anchor_bottom = 1.0
    controls.offset_left = -170
    controls.offset_right = 170
    controls.offset_top = -92
    controls.offset_bottom = -18
    controls.alignment = BoxContainer.ALIGNMENT_CENTER
    controls.add_theme_constant_override("separation", 18)
    hud.add_child(controls)

    for item in [["◀", "left"], ["▲", "up"], ["▶", "right"], ["↻", "reset"]]:
        var button := Button.new()
        button.text = item[0]
        button.custom_minimum_size = Vector2(72, 66)
        button.add_theme_font_size_override("font_size", 27)
        controls.add_child(button)
        if item[1] == "reset":
            button.pressed.connect(_reset_player)
        else:
            button.button_down.connect(func(): player.set_mobile_input(item[1], true))
            button.button_up.connect(func(): player.set_mobile_input(item[1], false))

    restart_button = Button.new()
    restart_button.text = "Начать заново"
    restart_button.position = Vector2(18, 112)
    restart_button.visible = false
    restart_button.pressed.connect(_reset_player)
    hud.add_child(restart_button)

func _process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    var h := maxf(0.0, player.global_position.y - start_y)
    _check_checkpoint()
    peak_y = maxf(peak_y, h)
    height_label.text = "ВЫСОТА: %d м  |  РЕКОРД: %d м" % [int(h), int(peak_y)]
    # Fixed, slightly elevated chase camera: it follows the climber but does not orbit.
    var target_camera := Vector3(player.global_position.x * 0.18, player.global_position.y + 4.2, player.global_position.z + 12.5)
    camera.global_position = camera.global_position.lerp(target_camera, 1.0 - exp(-4.2 * delta))
    camera.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)
    if player.global_position.y < -8.0 and not game_over:
        game_over = true
        status_label.text = "Падение! Возврат к контрольной точке."
        restart_button.visible = true

func _check_checkpoint() -> void:
    for i in range(active_checkpoint, checkpoint_positions.size()):
        if player.global_position.distance_to(checkpoint_positions[i]) < 1.45:
            active_checkpoint = i + 1
            status_label.text = "Контрольная точка %d сохранена!" % active_checkpoint

func _reset_player() -> void:
    var respawn := Vector3(0, 1.0, 0)
    if active_checkpoint > 0:
        respawn = checkpoint_positions[active_checkpoint - 1] + Vector3(0, 0.65, 0)
    player.global_position = respawn
    player.velocity = Vector3.ZERO
    player.reset_hammer()
    game_over = false
    restart_button.visible = false
    status_label.text = "Веди молот пальцем и отпусти для зацепа. Нажми ещё раз, чтобы отпустить."
