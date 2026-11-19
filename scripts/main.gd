extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
var player: CharacterBody3D
var camera: Camera3D
var height_label: Label
var hud_title_label: Label
var status_label: Label
var restart_button: Button
var pause_button: Button
const ROUTE_LEDGE_POSITIONS := [
    Vector2(-1.35, 2.0),
    Vector2(1.35, 4.35),
    Vector2(-1.35, 6.70),
    Vector2(1.35, 9.05),
    Vector2(-1.35, 11.40),
    Vector2(1.35, 13.75),
    Vector2(-1.35, 16.10),
    Vector2(1.35, 18.45),
    Vector2(-1.35, 20.80),
    Vector2(1.35, 23.15)
]
const LEDGE_SIZE := Vector3(2.75, 0.56, 2.35)
const TOP_HEIGHT := 22.75
const SAVE_PATH := "user://climb_master.cfg"
var start_y := 0.0
var best_height := 0.0
var finished := false
var finish_position := Vector3.ZERO
var reset_button: Button
var win_overlay: Control
var win_label: Label
var game_over := false
var checkpoint_positions: Array[Vector3] = []
var active_checkpoint := 0
var checkpoint_label: Label
var record_label: Label
var climb_progress: ProgressBar
var coin_count_label: Label
var coin_count := 0
var collectible_nodes: Array[Node3D] = []
var pause_overlay: Control
var moving_obstacles: Array[AnimatableBody3D] = []
var obstacle_phases: Array[float] = []
var obstacle_clock := 0.0
var last_player_feedback := ""
var lang := "ru"
var start_overlay: Control
var intro_overlay: Control
var language_selectors: Array[OptionButton] = []
var pause_title_label: Label
var pause_subtitle_label: Label
var resume_button_ref: Button
var reset_menu_ref: Button
var win_again_ref: Button
var win_stay_ref: Button
var current_level := 1
var level_two_start := Vector3(1.35, 24.55, 0.0)
var level_two_finish := Vector3(-1.35, 49.58, 0.0)
const LANGS := ["ru", "en", "es", "fr"]
const LANG_NAMES := ["Русский", "English", "Español", "Français"]
const T := {
"ru":{"height":"ВЫСОТА","record":"РЕКОРД  %d м","checkpoint":"СТАРТ  •  КП 0","checkpoint_n":"КОНТРОЛЬНАЯ ТОЧКА  •  %d","touch":"КАСАЙСЯ ЭКРАНА И ВЕДИ СЕРП  •  ЦЕПЛЯЙСЯ ЗА КРАЯ","reset":"СБРОС","pause":"Пауза","resume":"ПРОДОЛЖИТЬ ПОДЪЁМ","to_cp":"К КОНТРОЛЬНОЙ ТОЧКЕ","pause_title":"ПЕРЕДЫШКА","pause_sub":"Подумай над следующим движением","restart":"ВЕРНУТЬСЯ К КОНТРОЛЬНОЙ ТОЧКЕ","again":"НАЧАТЬ ЗАНОВО","stay":"ОСТАТЬСЯ НА ВЕРШИНЕ","continue":"ПРОДОЛЖИТЬ","language":"ЯЗЫК","welcome":"ПОКОРИ СВОЮ ВЕРШИНУ","hint":"Коснись экрана и веди серп к камню.","push":"Упёрся. Веди палец, чтобы оттолкнуться.","grip":"Есть упор! Веди серп дальше, чтобы подняться.","hazard":"Опасное препятствие! Обойди его серпом.","fall":"Падение! Нажми СБРОС, чтобы вернуться к контрольной точке.","win":"ВЕРШИНА!\nРекорд: %d м"},
"en":{"height":"HEIGHT","record":"BEST  %d m","checkpoint":"START  •  CP 0","checkpoint_n":"CHECKPOINT  •  %d","touch":"DRAG THE SCYTHE  •  HOOK ONTO EDGES","reset":"RESET","pause":"Pause","resume":"CONTINUE CLIMBING","to_cp":"TO CHECKPOINT","pause_title":"TAKE A BREATHER","pause_sub":"Plan your next move","restart":"RETURN TO CHECKPOINT","again":"PLAY AGAIN","stay":"STAY AT THE SUMMIT","continue":"CONTINUE","language":"LANGUAGE","welcome":"CONQUER YOUR SUMMIT","hint":"Touch the screen and guide the scythe to a rock.","push":"Blocked. Keep dragging to push away.","grip":"Hooked! Keep moving the scythe to climb.","hazard":"Dangerous obstacle! Swing around it.","fall":"You fell! Press RESET to return to the checkpoint.","win":"SUMMIT REACHED!\nBest: %d m"},
"es":{"height":"ALTURA","record":"RÉCORD  %d m","checkpoint":"INICIO  •  CP 0","checkpoint_n":"PUNTO DE CONTROL  •  %d","touch":"DESLIZA LA HOZ  •  ENGÁNCHATE A LOS BORDES","reset":"REINICIAR","pause":"Pausa","resume":"CONTINUAR ESCALANDO","to_cp":"IR AL PUNTO DE CONTROL","pause_title":"TOMA UN RESPIRO","pause_sub":"Piensa en tu siguiente movimiento","restart":"VOLVER AL PUNTO DE CONTROL","again":"JUGAR DE NUEVO","stay":"QUEDARSE EN LA CIMA","continue":"CONTINUAR","language":"IDIOMA","welcome":"CONQUISTA LA CIMA","hint":"Toca la pantalla y guía la hoz hacia una roca.","push":"Bloqueado. Sigue deslizando para impulsarte.","grip":"¡Enganchado! Sigue moviendo la hoz para subir.","hazard":"¡Obstáculo peligroso! Rodéalo con la hoz.","fall":"¡Has caído! Pulsa REINICIAR para volver al punto de control.","win":"¡HAS LLEGADO A LA CIMA!\nRécord: %d m"},
"fr":{"height":"HAUTEUR","record":"RECORD  %d m","checkpoint":"DÉPART  •  CP 0","checkpoint_n":"POINT DE CONTRÔLE  •  %d","touch":"FAIS GLISSER LA FAUCILLE  •  ACCROCHE-TOI AUX REBORDS","reset":"RÉINITIALISER","pause":"Pause","resume":"CONTINUER L’ASCENSION","to_cp":"RETOUR AU POINT DE CONTRÔLE","pause_title":"PETITE PAUSE","pause_sub":"Prépare ton prochain mouvement","restart":"RETOURNER AU POINT DE CONTRÔLE","again":"REJOUER","stay":"RESTER AU SOMMET","continue":"CONTINUER","language":"LANGUE","welcome":"CONQUIERS TON SOMMET","hint":"Touche l’écran et guide la faucille vers un rocher.","push":"Bloqué. Continue à glisser pour te repousser.","grip":"Accroché ! Continue à bouger la faucille pour grimper.","hazard":"Obstacle dangereux ! Contourne-le avec la faucille.","fall":"Chute ! Appuie sur RÉINITIALISER pour revenir au point de contrôle.","win":"SOMMET ATTEINT !\nRecord : %d m"}
}

func _ready() -> void:
    _build_world()
    # One coherent route system: footholds, scanned rock faces and timed hazards.
    # The old imported pack and second asset course duplicated the same climbing lane.
    _build_photogrammetry_boulders()
    _build_industrial_structures()
    _build_checkpoints()
    _build_obstacles()
    _build_collectibles()
    _build_atmosphere()
    _build_player()
    _build_camera()
    _build_hud()
    start_y = player.global_position.y
    _load_record()
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) == OK:
        lang = str(cfg.get_value("settings", "language", "ru"))
    if not LANGS.has(lang):
        lang = "ru"
    _apply_language()
    record_label.text = _t("record") % int(best_height)
    _build_start_flow()
    get_tree().paused = true
    call_deferred("_play_intro")

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY

    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    # Warm sunset palette: violet upper sky, rose cloud-light and a bright orange horizon.
    sky_material.sky_top_color = Color(0.105, 0.105, 0.25)
    sky_material.sky_horizon_color = Color(0.96, 0.36, 0.19)
    sky_material.ground_bottom_color = Color(0.075, 0.055, 0.10)
    sky_material.ground_horizon_color = Color(0.56, 0.19, 0.16)
    sky_material.sun_angle_max = 12.0
    sky_material.energy_multiplier = 1.15
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.92, 0.55, 0.43)
    environment.ambient_light_energy = 0.82
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.78, 0.34, 0.27)
    environment.fog_density = 0.012
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.name = "MountainSun"
    sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    sun.light_color = Color(1.0, 0.57, 0.34)
    sun.light_energy = 1.55
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 55.0
    add_child(sun)

    var fill := DirectionalLight3D.new()
    fill.name = "ColdSkyFill"
    fill.rotation_degrees = Vector3(-22.0, 145.0, 0.0)
    fill.light_color = Color(0.42, 0.62, 0.9)
    fill.light_energy = 0.38
    add_child(fill)

    _add_platform(Vector3(0.0, -0.7, 0.0), Vector3(5.2, 1.2, 9.0), Color(0.25, 0.29, 0.32))
    # One authored route drives every ledge, checkpoint, pickup and the summit.
    # The 2.35 m vertical rhythm keeps each next foothold within the scythe's reach.
    var ledge_colors := [
        Color(0.35, 0.31, 0.26), Color(0.32, 0.36, 0.39),
        Color(0.42, 0.34, 0.27), Color(0.32, 0.38, 0.34),
        Color(0.39, 0.34, 0.31), Color(0.31, 0.36, 0.42)
    ]
    for i in range(ROUTE_LEDGE_POSITIONS.size()):
        var point: Vector2 = ROUTE_LEDGE_POSITIONS[i]
        var tilt := -0.035 if i % 2 == 0 else 0.035
        _add_platform(Vector3(point.x, point.y, 0.0), LEDGE_SIZE, ledge_colors[i % ledge_colors.size()], tilt)

    _build_climbable_rock_holds()

    # Level 2: the same mountain backdrop continues above the first summit.
    _build_shadow_level_course()

    # Keep the central climbing lane readable. Natural cliff outcrops frame
    # the route from the far left and right instead of spawning in front of it.
    for side in [-1.0, 1.0]:
        for level in range(8):
            var outcrop := StaticBody3D.new()
            outcrop.name = "CliffOutcrop_%s_%d" % ["L" if side < 0.0 else "R", level]
            var rock := MeshInstance3D.new()
            var rock_mesh := SphereMesh.new()
            rock_mesh.radius = 1.0
            rock_mesh.height = 1.65
            rock.mesh = rock_mesh
            rock.scale = Vector3(1.1, randf_range(1.0, 1.7), 0.75)
            var rock_mat := StandardMaterial3D.new()
            rock_mat.albedo_color = Color(0.16, 0.19, 0.22)
            rock_mat.roughness = 0.98
            rock.material_override = rock_mat
            outcrop.add_child(rock)
            var collision := CollisionShape3D.new()
            var shape := SphereShape3D.new()
            shape.radius = 0.9
            collision.shape = shape
            collision.scale = Vector3(1.1, 1.3, 0.85)
            outcrop.add_child(collision)
            outcrop.position = Vector3(side * 5.0, 1.5 + float(level) * 3.15, -0.25)
            add_child(outcrop)

    _build_mountain_backdrop()




func _build_climbable_rock_holds() -> void:
    # Natural, collidable handholds sit on the playable Z plane.
    # They add alternative hook points between the broad route platforms.
    var rock_palette := [
        Color(0.30, 0.32, 0.33), Color(0.36, 0.32, 0.27),
        Color(0.25, 0.29, 0.32), Color(0.39, 0.35, 0.30)
    ]
    for i in range(20):
        var side := -1.0 if i % 2 == 0 else 1.0
        var tier := float(i)
        var hold := StaticBody3D.new()
        hold.name = "ClimbableRockHold_%02d" % i
        hold.add_to_group("climbable_hold")
        hold.position = Vector3(side * (2.55 + float(i % 3) * 0.22), 1.15 + tier * 1.12, -0.18)
        hold.collision_layer = 1
        hold.collision_mask = 1

        var rock := MeshInstance3D.new()
        var rock_mesh := SphereMesh.new()
        rock_mesh.radius = 1.0
        rock_mesh.height = 1.65
        rock.mesh = rock_mesh
        var radius := 0.42 + float(i % 4) * 0.055
        rock.scale = Vector3(radius * 1.28, radius, 0.48)
        rock.rotation = Vector3(float(i % 3) * 0.11, float(i % 5) * 0.17, float(i % 4) * 0.09)
        var material := StandardMaterial3D.new()
        material.albedo_color = rock_palette[i % rock_palette.size()]
        material.roughness = 0.97
        rock.material_override = material
        hold.add_child(rock)

        var collision := CollisionShape3D.new()
        var shape := SphereShape3D.new()
        shape.radius = radius
        collision.shape = shape
        collision.scale = Vector3(1.28, 1.0, 0.85)
        hold.add_child(collision)
        add_child(hold)

func _build_mountain_backdrop() -> void:
    # One continuous, triangulated cliff face replaces the old tiled sphere backdrop.
    # Vertex displacement and color variation create broad natural rock strata.
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var columns := 48
    var rows := 112
    var width := 30.0
    var height := 70.0
    var vertices: Array[Vector3] = []
    var colors: Array[Color] = []
    for row in range(rows + 1):
        var v := float(row) / float(rows)
        var y := -4.0 + v * height
        for column in range(columns + 1):
            var u := float(column) / float(columns)
            var x := -width * 0.5 + u * width
            var broad_ridge := sin(x * 0.42 + y * 0.16) * 0.72
            var broken_ridge := sin(x * 1.13 - y * 0.31) * 0.24
            var strata := sin(y * 1.65 + x * 0.22) * 0.12
            var z := -4.65 + broad_ridge + broken_ridge + strata
            vertices.append(Vector3(x, y, z))
            var shade := 0.15 + 0.035 * sin(x * 0.8 + y * 0.37) + 0.025 * cos(y * 1.4 - x * 0.3)
            colors.append(Color(shade * 0.92, shade, shade * 1.08, 1.0))

    for row in range(rows):
        for column in range(columns):
            var i := row * (columns + 1) + column
            var a := vertices[i]
            var b := vertices[i + 1]
            var c := vertices[i + columns + 1]
            var d := vertices[i + columns + 2]
            surface.set_color(colors[i])
            surface.add_vertex(a)
            surface.set_color(colors[i + 1])
            surface.add_vertex(b)
            surface.set_color(colors[i + columns + 1])
            surface.add_vertex(c)
            surface.set_color(colors[i + 1])
            surface.add_vertex(b)
            surface.set_color(colors[i + columns + 2])
            surface.add_vertex(d)
            surface.set_color(colors[i + columns + 1])
            surface.add_vertex(c)

    surface.generate_normals()
    var cliff := MeshInstance3D.new()
    cliff.name = "ContinuousMountainMassif"
    cliff.mesh = surface.commit()
    var cliff_material := StandardMaterial3D.new()
    cliff_material.vertex_color_use_as_albedo = true
    cliff_material.roughness = 1.0
    cliff_material.metallic = 0.0
    cliff.material_override = cliff_material
    add_child(cliff)

    # Distant side ridges frame the playable lane without hiding the footholds.
    var ridge_material := StandardMaterial3D.new()
    ridge_material.albedo_color = Color(0.12, 0.145, 0.17)
    ridge_material.roughness = 1.0
    for side in [-1.0, 1.0]:
        for tier in range(5):
            var ridge := MeshInstance3D.new()
            var ridge_mesh := SphereMesh.new()
            ridge_mesh.radius = 1.0
            ridge_mesh.height = 2.0
            ridge.mesh = ridge_mesh
            ridge.scale = Vector3(2.4 + float(tier % 2) * 0.7, 3.0, 1.15)
            ridge.position = Vector3(side * (9.0 + float(tier % 2) * 1.2), 1.0 + float(tier) * 7.2, -3.65)
            ridge.material_override = ridge_material
            add_child(ridge)

    # Broad, solid valley floor: the player can land safely below the first ledge.
    var valley_floor := StaticBody3D.new()
    valley_floor.name = "MountainValleyFloor"
    valley_floor.position = Vector3(0.0, -1.82, 0.0)
    var floor_visual := MeshInstance3D.new()
    var floor_box := BoxMesh.new()
    floor_box.size = Vector3(120.0, 0.7, 80.0)
    floor_visual.mesh = floor_box
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color(0.20, 0.22, 0.23)
    floor_material.roughness = 1.0
    floor_visual.material_override = floor_material
    valley_floor.add_child(floor_visual)
    var floor_collision := CollisionShape3D.new()
    var floor_shape := BoxShape3D.new()
    floor_shape.size = floor_box.size
    floor_collision.shape = floor_shape
    valley_floor.add_child(floor_collision)
    add_child(valley_floor)


func _build_photogrammetry_boulders() -> void:
    # Real photogrammetry scan; convex collision keeps the mobile physics cost manageable.
    var boulder_scene := load("res://assets/models/namaqualand_boulder_05_2k.gltf") as PackedScene
    if boulder_scene == null:
        push_warning("Photogrammetry boulder could not be loaded.")
        return

    # Scanned boulders sit just outside alternating footholds. Their edges are
    # reachable with the scythe, while the middle of the route stays readable.
    var placements: Array[Dictionary] = [
        {"position": Vector3(-3.85, 2.65, -0.22), "rotation": Vector3(0.12, 0.35, -0.18), "scale": 1.85},
        {"position": Vector3(3.85, 6.10, -0.22), "rotation": Vector3(-0.16, 1.15, 0.22), "scale": 1.88},
        {"position": Vector3(-3.85, 9.55, -0.22), "rotation": Vector3(0.08, 2.1, -0.12), "scale": 1.85},
        {"position": Vector3(3.85, 13.00, -0.22), "rotation": Vector3(-0.1, 0.55, 0.16), "scale": 1.88},
        {"position": Vector3(-3.85, 16.45, -0.22), "rotation": Vector3(0.14, 1.65, -0.2), "scale": 1.85},
        {"position": Vector3(3.85, 19.90, -0.22), "rotation": Vector3(-0.12, 2.55, 0.14), "scale": 1.88},
        {"position": Vector3(-3.85, 22.80, -0.22), "rotation": Vector3(0.10, 0.85, -0.15), "scale": 1.82}
    ]

    for placement in placements:
        var boulder := boulder_scene.instantiate() as Node3D
        if boulder == null:
            continue
        boulder.position = placement["position"]
        boulder.rotation = placement["rotation"]
        boulder.scale = Vector3.ONE * float(placement["scale"])
        add_child(boulder)
        _add_boulder_convex_collisions(boulder)


func _add_boulder_convex_collisions(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            mesh_instance.create_convex_collision(true, true)
    for child in node.get_children():
        if child is not StaticBody3D:
            _add_boulder_convex_collisions(child)


func _build_imported_obstacles() -> void:
    # Authored obstacle pack: textured rock, rusty pipe and stone ledge.
    var obstacle_scene := load("res://assets/models/obstacles.gltf") as PackedScene
    if obstacle_scene == null:
        push_warning("Could not load assets/models/obstacles.gltf")
        return

    var source_root := obstacle_scene.instantiate() as Node3D
    if source_root == null:
        push_warning("Obstacle asset root is not Node3D")
        return
    add_child(source_root)

    var source_rock := _find_obstacle_mesh(source_root, "Rock")
    var source_pipe := _find_obstacle_mesh(source_root, "Pipe")
    var source_ledge := _find_obstacle_mesh(source_root, "Ledge")

    if source_rock == null or source_pipe == null or source_ledge == null:
        push_warning("Obstacle pack is missing Rock, Pipe or Ledge mesh")
        source_root.queue_free()
        return

    # Stagger the imported pieces along the route so they form a deliberate climbing line.
    var placements: Array[Dictionary] = [
        {"source": source_rock, "position": Vector3(-1.35, 3.15, 0.1), "rotation": -0.18, "scale": 1.35, "name": "TexturedRock_A"},
        {"source": source_pipe, "position": Vector3(1.35, 6.15, 0.15), "rotation": 0.10, "scale": 1.0, "name": "RustPipe_A"},
        {"source": source_ledge, "position": Vector3(-1.35, 8.95, 0.0), "rotation": -0.12, "scale": 1.15, "name": "StoneLedge_A"},
        {"source": source_rock, "position": Vector3(1.35, 12.0, 0.1), "rotation": 0.22, "scale": 1.28, "name": "TexturedRock_B"},
        {"source": source_pipe, "position": Vector3(-1.35, 15.0, 0.15), "rotation": -0.14, "scale": 1.05, "name": "RustPipe_B"},
        {"source": source_ledge, "position": Vector3(1.35, 17.9, 0.0), "rotation": 0.15, "scale": 1.18, "name": "StoneLedge_B"}
    ]

    for item in placements:
        var source := item["source"] as MeshInstance3D
        if source.mesh == null:
            continue
        var body := StaticBody3D.new()
        body.name = item["name"]
        body.position = item["position"]
        body.rotation.z = float(item["rotation"])
        body.scale = Vector3.ONE * float(item["scale"])
        body.add_to_group("imported_obstacle")

        var visual := MeshInstance3D.new()
        visual.name = "TexturedMesh"
        visual.mesh = source.mesh
        visual.material_override = source.material_override
        # Preserve the imported orientation, but center each piece at its placement.
        visual.transform = Transform3D(source.transform.basis, Vector3.ZERO)
        body.add_child(visual)

        var collision := CollisionShape3D.new()
        collision.name = "GeneratedConvexCollision"
        collision.shape = source.mesh.create_convex_shape()
        body.add_child(collision)
        add_child(body)

    source_root.queue_free()


func _find_obstacle_mesh(node: Node, target_name: String) -> MeshInstance3D:
    if node is MeshInstance3D and (node as MeshInstance3D).name.to_lower().contains(target_name.to_lower()):
        return node as MeshInstance3D
    for child in node.get_children():
        var found := _find_obstacle_mesh(child, target_name)
        if found != null:
            return found
    return null


func _build_asset_course() -> void:
    # The route is a clear zig-zag. Obstacles are attached to the cliff edges,
    # leaving the center open so the player can read each next move.
    var placements: Array[Dictionary] = [
        {"file": "fallen_log", "position": Vector3(-3.15, 1.15, -0.58), "rotation": Vector3(0.0, 0.12, 0.24), "scale": 0.78},
        {"file": "crate_stack", "position": Vector3(3.1, 4.1, -0.58), "rotation": Vector3(0.0, -0.18, -0.08), "scale": 0.72},
        {"file": "rock_arch", "collision": "trimesh", "position": Vector3(-3.25, 7.05, -0.62), "rotation": Vector3(0.0, 0.0, 0.0), "scale": 0.70},
        {"file": "tire_stack", "collision": "trimesh", "position": Vector3(3.15, 10.0, -0.58), "rotation": Vector3(0.0, 0.25, 0.06), "scale": 0.72},
        {"file": "pipe_cluster", "collision": "trimesh", "position": Vector3(-3.2, 12.95, -0.58), "rotation": Vector3(0.0, 0.0, 0.10), "scale": 0.68},
        {"file": "broken_bridge", "collision": "trimesh", "position": Vector3(3.1, 15.85, -0.62), "rotation": Vector3(0.0, 0.0, -0.12), "scale": 0.70},
        {"file": "ice_boulder", "position": Vector3(-3.15, 18.75, -0.58), "rotation": Vector3(0.0, 0.55, -0.10), "scale": 0.70},
        {"file": "giant_chain", "collision": "trimesh", "position": Vector3(3.1, 19.2, -0.60), "rotation": Vector3(0.0, 0.0, 0.0), "scale": 0.58}
    ]

    for item in placements:
        var asset_path := "res://assets/" + str(item["file"]) + ".gltf"
        var packed := load(asset_path) as PackedScene
        if packed == null:
            push_warning("Could not load course asset: " + asset_path)
            continue
        var instance := packed.instantiate() as Node3D
        if instance == null:
            push_warning("Course asset root is not Node3D: " + asset_path)
            continue
        instance.name = "Course_" + str(item["file"])
        instance.position = item["position"]
        instance.rotation = item["rotation"]
        instance.scale = Vector3.ONE * float(item["scale"])
        add_child(instance)
        _add_asset_collisions(instance, str(item.get("collision", "convex")) == "trimesh")


func _add_asset_collisions(node: Node, trimesh := false) -> void:
    # Convex hulls are cheap, but fill in arches, holes and chains, so those assets
    # use an exact (static) triangle-mesh collider instead.
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            if trimesh:
                mesh_instance.create_trimesh_collision()
            else:
                mesh_instance.create_convex_collision(true, true)
    for child in node.get_children():
        if child is not StaticBody3D:
            _add_asset_collisions(child, trimesh)


func _build_industrial_structures() -> void:
    # Weathered steel frames make the climb feel like an abandoned quarry.
    var steel := StandardMaterial3D.new()
    steel.albedo_color = Color(0.16, 0.21, 0.24)
    steel.metallic = 0.88
    steel.roughness = 0.34
    var rust := StandardMaterial3D.new()
    rust.albedo_color = Color(0.34, 0.19, 0.11)
    rust.metallic = 0.62
    rust.roughness = 0.78

    for side in [-1.0, 1.0]:
        for level in range(4):
            var frame := Node3D.new()
            frame.position = Vector3(side * 4.8, 2.0 + float(level) * 6.0, -0.2)
            add_child(frame)
            _add_steel_beam(frame, Vector3(-0.85, -2.6, 0), Vector3(-0.85, 2.6, 0), 0.13, steel)
            _add_steel_beam(frame, Vector3(0.85, -2.6, 0), Vector3(0.85, 2.6, 0), 0.13, steel)
            _add_steel_beam(frame, Vector3(-0.85, 2.35, 0), Vector3(0.85, 2.35, 0), 0.16, rust)
            _add_steel_beam(frame, Vector3(-0.85, -2.3, 0), Vector3(0.85, 2.2, 0), 0.075, steel)
            _add_steel_beam(frame, Vector3(0.85, -2.3, 0), Vector3(-0.85, 2.2, 0), 0.075, steel)

            for post_x in [-0.85, 0.85]:
                var foot := MeshInstance3D.new()
                var foot_mesh := BoxMesh.new()
                foot_mesh.size = Vector3(0.48, 0.18, 0.48)
                foot.mesh = foot_mesh
                foot.position = Vector3(post_x, -2.58, 0)
                foot.material_override = rust
                frame.add_child(foot)

func _add_steel_beam(parent: Node3D, start: Vector3, finish: Vector3, width: float, material: Material) -> void:
    var beam := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(width, start.distance_to(finish), width)
    beam.mesh = mesh
    beam.position = (start + finish) * 0.5
    beam.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
    beam.material_override = material
    parent.add_child(beam)

func _build_shadow_level_course() -> void:
    # A harder upper route: narrow alternating ledges, extra hook points and
    # black moving silhouettes. The continuous mountain material is untouched.
    var shadow_ledge := Color(0.035, 0.035, 0.045)
    _add_platform(Vector3(level_two_start.x, 24.0, 0.0), Vector3(2.7, 0.5, 2.3), shadow_ledge)
    for i in range(10):
        var x := -1.35 if i % 2 == 0 else 1.35
        var y := 25.50 + float(i) * 2.35
        _add_platform(Vector3(x, y, 0.0), Vector3(2.35, 0.48, 2.2), shadow_ledge, -0.045 if i % 2 == 0 else 0.045)

        var hold := StaticBody3D.new()
        hold.name = "ShadowClimbHold_%02d" % i
        hold.add_to_group("climbable_hold")
        hold.position = Vector3(-x * 1.55, y + 0.72, -0.12)
        var rock := MeshInstance3D.new()
        var rock_mesh := SphereMesh.new()
        rock_mesh.radius = 0.42
        rock_mesh.height = 0.64
        rock.mesh = rock_mesh
        rock.scale = Vector3(1.25, 0.72, 0.7)
        var dark := StandardMaterial3D.new()
        dark.albedo_color = Color.BLACK
        dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        rock.material_override = dark
        hold.add_child(rock)
        var hit := CollisionShape3D.new()
        var hit_shape := SphereShape3D.new()
        hit_shape.radius = 0.48
        hit.shape = hit_shape
        hold.add_child(hit)
        add_child(hold)

    # A final safe foothold makes the summit reachable by the same hook-and-swing rules.
    _add_platform(Vector3(level_two_finish.x, level_two_finish.y - 0.58, 0.0), Vector3(2.65, 0.5, 2.25), shadow_ledge)

    # Visible checkpoint sigils match the silhouette language of this level.
    for checkpoint_pos in [Vector3(1.35, 30.15, 0.0), Vector3(-1.35, 37.20, 0.0), Vector3(1.35, 44.25, 0.0)]:
        var checkpoint_ring := MeshInstance3D.new()
        var checkpoint_mesh := TorusMesh.new()
        checkpoint_mesh.inner_radius = 0.52
        checkpoint_mesh.outer_radius = 0.66
        checkpoint_ring.mesh = checkpoint_mesh
        checkpoint_ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
        var checkpoint_black := StandardMaterial3D.new()
        checkpoint_black.albedo_color = Color.BLACK
        checkpoint_black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        checkpoint_ring.material_override = checkpoint_black
        checkpoint_ring.position = checkpoint_pos
        add_child(checkpoint_ring)

    var summit_shadow := MeshInstance3D.new()
    var summit_ring := TorusMesh.new()
    summit_ring.inner_radius = 0.72
    summit_ring.outer_radius = 0.94
    summit_shadow.mesh = summit_ring
    summit_shadow.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    var summit_black := StandardMaterial3D.new()
    summit_black.albedo_color = Color.BLACK
    summit_black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    summit_shadow.material_override = summit_black
    summit_shadow.position = level_two_finish
    add_child(summit_shadow)

    # Distinct silhouette hazards: black pendulum weights and bars with real collision.
    for i in range(6):
        var hazard := AnimatableBody3D.new()
        hazard.name = "ShadowPendulum_%02d" % i
        hazard.position = Vector3(0.0, 27.0 + float(i) * 3.75, 0.0)
        hazard.add_to_group("climb_hazard")
        hazard.sync_to_physics = true
        var black := StandardMaterial3D.new()
        black.albedo_color = Color.BLACK
        black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        var bar := MeshInstance3D.new()
        var bar_mesh := BoxMesh.new()
        bar_mesh.size = Vector3(0.22, 2.1, 0.28)
        bar.mesh = bar_mesh
        bar.position.y = -0.95
        bar.material_override = black
        hazard.add_child(bar)
        var weight := MeshInstance3D.new()
        var weight_mesh := SphereMesh.new()
        weight_mesh.radius = 0.52
        weight_mesh.height = 1.04
        weight.mesh = weight_mesh
        weight.position.y = -2.0
        weight.material_override = black
        hazard.add_child(weight)
        var collision := CollisionShape3D.new()
        var capsule := CapsuleShape3D.new()
        capsule.radius = 0.34
        capsule.height = 2.9
        collision.shape = capsule
        collision.position.y = -1.35
        hazard.add_child(collision)
        moving_obstacles.append(hazard)
        obstacle_phases.append(float(i) * 1.05 + 0.5)
        add_child(hazard)

func _build_checkpoints() -> void:
    # Respawn points are centered over the third, sixth and ninth safe ledges.
    checkpoint_positions.clear()
    for route_index in [2, 5, 8]:
        var ledge: Vector2 = ROUTE_LEDGE_POSITIONS[route_index]
        checkpoint_positions.append(Vector3(ledge.x, ledge.y + 0.58, 0.0))
    for i in range(checkpoint_positions.size()):
        var marker := Node3D.new()
        marker.position = checkpoint_positions[i]
        add_child(marker)

        var ring := MeshInstance3D.new()
        var ring_mesh := TorusMesh.new()
        ring_mesh.inner_radius = 0.65
        ring_mesh.outer_radius = 0.82
        ring.mesh = ring_mesh
        # Keep the checkpoint ring facing the side-on camera.
        ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
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

    _build_finish_marker()

func _build_finish_marker() -> void:
    var summit: Vector2 = ROUTE_LEDGE_POSITIONS[ROUTE_LEDGE_POSITIONS.size() - 1]
    finish_position = Vector3(summit.x, summit.y + 0.58, 0.0)
    var marker := Node3D.new()
    marker.name = "SummitMarker"
    marker.position = finish_position
    add_child(marker)
    var gold := StandardMaterial3D.new()
    gold.albedo_color = Color(1.0, 0.78, 0.22)
    gold.metallic = 0.8
    gold.roughness = 0.3
    gold.emission_enabled = true
    gold.emission = Color(0.9, 0.55, 0.05)
    gold.emission_energy_multiplier = 1.3
    var ring := MeshInstance3D.new()
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.72
    ring_mesh.outer_radius = 0.95
    ring.mesh = ring_mesh
    ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    ring.material_override = gold
    marker.add_child(ring)

func _build_obstacles() -> void:
    # Compact edge-mounted pendulums: hazards challenge timing without sealing
    # the whole climbing lane like a flat wall across the screen.
    var hazard_material := StandardMaterial3D.new()
    hazard_material.albedo_color = Color(0.28, 0.095, 0.055)
    hazard_material.metallic = 0.72
    hazard_material.roughness = 0.34

    var warning_material := StandardMaterial3D.new()
    warning_material.albedo_color = Color(0.95, 0.34, 0.08)
    warning_material.metallic = 0.4
    warning_material.emission_enabled = true
    warning_material.emission = Color(0.8, 0.12, 0.015)
    warning_material.emission_energy_multiplier = 1.1

    # Pendulums guard the gaps between safe ledges, never the landing zones.
    var hazard_data := [
        {"x": 0.0, "y": 3.20, "phase": 0.0},
        {"x": 0.0, "y": 7.90, "phase": 1.4},
        {"x": 0.0, "y": 12.60, "phase": 2.8},
        {"x": 0.0, "y": 17.30, "phase": 4.2},
        {"x": 0.0, "y": 22.00, "phase": 5.4}
    ]
    for i in range(hazard_data.size()):
        var data: Dictionary = hazard_data[i]
        var obstacle := AnimatableBody3D.new()
        obstacle.name = "EdgePendulum_%d" % i
        obstacle.position = Vector3(float(data["x"]), float(data["y"]), 0.0)
        obstacle.sync_to_physics = true
        obstacle.add_to_group("climb_hazard")

        var pivot: Node3D = obstacle   # arm, weight and collision are children of the body itself
        var arm := MeshInstance3D.new()
        var arm_mesh := CylinderMesh.new()
        arm_mesh.top_radius = 0.075
        arm_mesh.bottom_radius = 0.11
        arm_mesh.height = 1.8
        arm.mesh = arm_mesh
        arm.position = Vector3(0.0, -0.9, 0.0)
        arm.material_override = hazard_material
        pivot.add_child(arm)

        var weight := MeshInstance3D.new()
        var weight_mesh := SphereMesh.new()
        weight_mesh.radius = 0.32
        weight_mesh.height = 0.64
        weight.mesh = weight_mesh
        weight.position = Vector3(0.0, -1.82, 0.0)
        weight.material_override = warning_material
        pivot.add_child(weight)

        var collision := CollisionShape3D.new()
        var shape := CapsuleShape3D.new()
        shape.radius = 0.24
        shape.height = 2.0
        collision.shape = shape
        collision.position = Vector3(0.0, -0.95, 0.0)
        pivot.add_child(collision)

        moving_obstacles.append(obstacle)
        obstacle_phases.append(float(data["phase"]))
        add_child(obstacle)


func _build_collectibles() -> void:
    # Optional skill pickups sit beside the main footholds, not in the required path.
    var pickup_positions: Array[Vector3] = []
    for i in range(ROUTE_LEDGE_POSITIONS.size()):
        var ledge: Vector2 = ROUTE_LEDGE_POSITIONS[i]
        # Tokens sit on the inside of the zig-zag, visible but not required to land on.
        pickup_positions.append(Vector3(-ledge.x * 0.55, ledge.y + 0.82, 0.0))
    for i in range(pickup_positions.size()):
        var pickup := Area3D.new()
        pickup.name = "SummitToken_%02d" % i
        pickup.position = pickup_positions[i]
        pickup.collision_layer = 0
        pickup.collision_mask = 1
        pickup.monitoring = true
        pickup.monitorable = false

        var token := MeshInstance3D.new()
        var ring_mesh := TorusMesh.new()
        ring_mesh.inner_radius = 0.20
        ring_mesh.outer_radius = 0.34
        ring_mesh.rings = 12
        ring_mesh.ring_segments = 8
        token.mesh = ring_mesh
        token.rotation_degrees = Vector3(90.0, 0.0, 0.0)
        var gold := StandardMaterial3D.new()
        gold.albedo_color = Color(1.0, 0.72, 0.20)
        gold.metallic = 0.82
        gold.roughness = 0.22
        gold.emission_enabled = true
        gold.emission = Color(0.95, 0.48, 0.08)
        gold.emission_energy_multiplier = 1.25
        token.material_override = gold
        pickup.add_child(token)

        var core := MeshInstance3D.new()
        var core_mesh := SphereMesh.new()
        core_mesh.radius = 0.12
        core_mesh.height = 0.24
        core.mesh = core_mesh
        core.material_override = gold
        pickup.add_child(core)

        var trigger := CollisionShape3D.new()
        var sphere := SphereShape3D.new()
        sphere.radius = 0.62
        trigger.shape = sphere
        pickup.add_child(trigger)
        pickup.body_entered.connect(_on_collectible_body_entered.bind(pickup))
        add_child(pickup)
        collectible_nodes.append(pickup)


func _on_collectible_body_entered(body: Node3D, pickup: Node3D) -> void:
    if body != player or not is_instance_valid(pickup):
        return
    coin_count += 1
    if is_instance_valid(coin_count_label):
        coin_count_label.text = "✦ %d" % coin_count
    status_label.text = "МОНЕТА ПОЛУЧЕНА!  +1"
    pickup.queue_free()
    collectible_nodes.erase(pickup)


func _build_atmosphere() -> void:
    # Low-cost ambient motes add depth to the quarry without blocking the climbing lane.
    var dust := GPUParticles3D.new()
    dust.name = "QuarryDust"
    dust.position = Vector3(0.0, 9.0, -2.2)
    dust.amount = 36
    dust.lifetime = 7.0
    dust.visibility_aabb = AABB(Vector3(-7.0, -12.0, -2.0), Vector3(14.0, 24.0, 4.0))
    var particle_mesh := SphereMesh.new()
    particle_mesh.radius = 0.025
    particle_mesh.height = 0.05
    var particle_material := StandardMaterial3D.new()
    particle_material.albedo_color = Color(0.88, 0.70, 0.48, 0.42)
    particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    particle_mesh.material = particle_material
    dust.draw_pass_1 = particle_mesh
    var process := ParticleProcessMaterial.new()
    process.direction = Vector3(0.18, 0.7, 0.0)
    process.spread = 38.0
    process.initial_velocity_min = 0.08
    process.initial_velocity_max = 0.28
    process.gravity = Vector3(0.0, 0.015, 0.0)
    process.scale_min = 0.55
    process.scale_max = 1.35
    process.color = Color(1.0, 0.82, 0.62, 0.48)
    dust.process_material = process
    add_child(dust)


func _add_platform(pos: Vector3, size: Vector3, color: Color, tilt := 0.0) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    body.rotation.z = tilt
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
    camera.position = Vector3(0, 2.0, 18.0)
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 10.2
    camera.current = true
    add_child(camera)

func _build_hud() -> void:
    var hud := CanvasLayer.new()
    hud.name = "GameHUD"
    hud.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(hud)

    # Top-left climbing telemetry: height, personal best and route progress.
    var info_panel := PanelContainer.new()
    info_panel.position = Vector2(22, 18)
    info_panel.custom_minimum_size = Vector2(330, 116)
    info_panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.035, 0.055, 0.075, 0.92)))
    hud.add_child(info_panel)

    var info := VBoxContainer.new()
    info.add_theme_constant_override("separation", 3)
    info_panel.add_child(info)

    var title := Label.new()
    title.text = "CLIMB MASTER   /   " + _t("height")
    hud_title_label = title
    title.add_theme_font_size_override("font_size", 13)
    title.add_theme_color_override("font_color", Color(0.52, 0.82, 0.83))
    info.add_child(title)

    height_label = Label.new()
    height_label.text = "0 м"
    height_label.add_theme_font_size_override("font_size", 34)
    height_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.72))
    info.add_child(height_label)

    record_label = Label.new()
    record_label.text = _t("record") % 0
    record_label.add_theme_font_size_override("font_size", 12)
    record_label.add_theme_color_override("font_color", Color(0.70, 0.76, 0.81))
    info.add_child(record_label)

    coin_count_label = Label.new()
    coin_count_label.text = "✦ 0"
    coin_count_label.add_theme_font_size_override("font_size", 15)
    coin_count_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30))
    info.add_child(coin_count_label)

    climb_progress = ProgressBar.new()
    climb_progress.custom_minimum_size = Vector2(0, 8)
    climb_progress.min_value = 0
    climb_progress.max_value = TOP_HEIGHT
    climb_progress.value = 0
    climb_progress.show_percentage = false
    climb_progress.add_theme_stylebox_override("background", _hud_panel_style(Color(0.12, 0.17, 0.20)))
    var progress_fill := StyleBoxFlat.new()
    progress_fill.bg_color = Color(0.20, 0.82, 0.70)
    progress_fill.corner_radius_top_left = 5
    progress_fill.corner_radius_top_right = 5
    progress_fill.corner_radius_bottom_left = 5
    progress_fill.corner_radius_bottom_right = 5
    climb_progress.add_theme_stylebox_override("fill", progress_fill)
    info.add_child(climb_progress)

    # Compact checkpoint badge.
    checkpoint_label = Label.new()
    checkpoint_label.text = _t("checkpoint")
    checkpoint_label.position = Vector2(22, 148)
    checkpoint_label.add_theme_font_size_override("font_size", 14)
    checkpoint_label.add_theme_color_override("font_color", Color(0.72, 0.94, 0.86))
    hud.add_child(checkpoint_label)

    # Top-right controls.
    var controls := HBoxContainer.new()
    controls.anchor_left = 1.0
    controls.anchor_right = 1.0
    controls.offset_left = -200
    controls.offset_right = -22
    controls.offset_top = 20
    controls.offset_bottom = 82
    controls.add_theme_constant_override("separation", 10)
    hud.add_child(controls)

    pause_button = Button.new()
    pause_button.text = "II"
    pause_button.tooltip_text = _t("pause")
    pause_button.custom_minimum_size = Vector2(62, 58)
    pause_button.add_theme_font_size_override("font_size", 24)
    _style_hud_button(pause_button, Color(0.08, 0.15, 0.18, 0.96))
    pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
    pause_button.pressed.connect(_toggle_pause)
    controls.add_child(pause_button)

    reset_button = Button.new()
    reset_button.text = _t("reset")
    reset_button.tooltip_text = "Вернуться к контрольной точке"
    reset_button.custom_minimum_size = Vector2(96, 58)
    reset_button.add_theme_font_size_override("font_size", 15)
    _style_hud_button(reset_button, Color(0.20, 0.11, 0.09, 0.96))
    reset_button.process_mode = Node.PROCESS_MODE_ALWAYS
    reset_button.pressed.connect(_reset_player)
    controls.add_child(reset_button)

    # Bottom instruction strip stays clear of the character and touch area.
    var hint_panel := PanelContainer.new()
    hint_panel.anchor_left = 0.5
    hint_panel.anchor_right = 0.5
    hint_panel.anchor_top = 1.0
    hint_panel.anchor_bottom = 1.0
    hint_panel.offset_left = -250
    hint_panel.offset_right = 250
    hint_panel.offset_top = -66
    hint_panel.offset_bottom = -18
    hint_panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.035, 0.055, 0.075, 0.82)))
    hud.add_child(hint_panel)

    status_label = Label.new()
    status_label.text = _t("touch")
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.add_theme_font_size_override("font_size", 14)
    status_label.add_theme_color_override("font_color", Color(0.88, 0.93, 0.92))
    hint_panel.add_child(status_label)

    restart_button = Button.new()
    restart_button.text = _t("restart")
    restart_button.anchor_left = 0.5
    restart_button.anchor_right = 0.5
    restart_button.anchor_top = 0.5
    restart_button.anchor_bottom = 0.5
    restart_button.offset_left = -190
    restart_button.offset_right = 190
    restart_button.offset_top = 115
    restart_button.offset_bottom = 165
    restart_button.visible = false
    restart_button.process_mode = Node.PROCESS_MODE_ALWAYS
    _style_hud_button(restart_button, Color(0.55, 0.20, 0.10, 0.98))
    restart_button.pressed.connect(_reset_player)
    hud.add_child(restart_button)

    # Pause screen with a clear resume action.
    pause_overlay = Control.new()
    pause_overlay.name = "PauseOverlay"
    pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pause_overlay.visible = false
    pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
    hud.add_child(pause_overlay)

    var dim := ColorRect.new()
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.color = Color(0.008, 0.018, 0.028, 0.78)
    pause_overlay.add_child(dim)

    var pause_card := PanelContainer.new()
    pause_card.anchor_left = 0.5
    pause_card.anchor_right = 0.5
    pause_card.anchor_top = 0.5
    pause_card.anchor_bottom = 0.5
    pause_card.offset_left = -190
    pause_card.offset_right = 190
    pause_card.offset_top = -145
    pause_card.offset_bottom = 145
    pause_card.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.045, 0.075, 0.09, 0.99)))
    pause_overlay.add_child(pause_card)

    var pause_content := VBoxContainer.new()
    pause_content.alignment = BoxContainer.ALIGNMENT_CENTER
    pause_content.add_theme_constant_override("separation", 15)
    pause_card.add_child(pause_content)

    var pause_title := Label.new()
    pause_title.text = _t("pause_title")
    pause_title_label = pause_title
    pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pause_title.add_theme_font_size_override("font_size", 28)
    pause_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.60))
    pause_content.add_child(pause_title)

    var pause_subtitle := Label.new()
    pause_subtitle.text = _t("pause_sub")
    pause_subtitle_label = pause_subtitle
    pause_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pause_subtitle.add_theme_font_size_override("font_size", 14)
    pause_subtitle.add_theme_color_override("font_color", Color(0.72, 0.82, 0.84))
    pause_content.add_child(pause_subtitle)

    var resume_button := Button.new()
    resume_button.text = _t("resume")
    resume_button_ref = resume_button
    resume_button.custom_minimum_size = Vector2(300, 54)
    _style_hud_button(resume_button, Color(0.08, 0.42, 0.36, 1.0))
    resume_button.pressed.connect(_toggle_pause)
    pause_content.add_child(resume_button)

    var menu_reset := Button.new()
    menu_reset.text = _t("to_cp")
    reset_menu_ref = menu_reset
    menu_reset.custom_minimum_size = Vector2(300, 48)
    _style_hud_button(menu_reset, Color(0.22, 0.14, 0.11, 1.0))
    menu_reset.pressed.connect(_reset_player)
    pause_content.add_child(menu_reset)

    _build_win_overlay(hud)
    _add_language_selector(pause_content)
    # Touches that start on these controls must not swing the scythe.
    player.ui_blockers = [pause_button, reset_button, restart_button, win_overlay]



func _localized_feedback(source: String) -> String:
    if source.contains("Коснись"):
        return _t("hint")
    if source.contains("Упёрся"):
        return _t("push")
    if source.contains("Есть упор"):
        return _t("grip")
    if source.contains("Опасное"):
        return _t("hazard")
    return _t("touch")

func _t(key: String) -> String:
    return str(T.get(lang, T["ru"]).get(key, key))

func _add_language_selector(parent: Control) -> void:
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    parent.add_child(row)
    var caption := Label.new()
    caption.text = _t("language") + ":"
    row.add_child(caption)
    var picker := OptionButton.new()
    picker.custom_minimum_size = Vector2(210, 44)
    for item in LANG_NAMES:
        picker.add_item(item)
    picker.select(maxi(0, LANGS.find(lang)))
    picker.item_selected.connect(_on_language_selected.bind(picker))
    row.add_child(picker)
    language_selectors.append(picker)

func _on_language_selected(index: int, picker: OptionButton) -> void:
    if index < 0 or index >= LANGS.size():
        return
    lang = LANGS[index]
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    cfg.set_value("settings", "language", lang)
    cfg.save(SAVE_PATH)
    _apply_language()

func _apply_language() -> void:
    if is_instance_valid(height_label):
        height_label.text = "0 m" if lang != "ru" else "0 м"
    if is_instance_valid(hud_title_label):
        hud_title_label.text = "CLIMB MASTER   /   " + _t("height")
    if is_instance_valid(record_label):
        record_label.text = _t("record") % int(best_height)
    if is_instance_valid(checkpoint_label):
        checkpoint_label.text = _t("checkpoint")
    if is_instance_valid(status_label):
        status_label.text = _t("touch")
    if is_instance_valid(reset_button):
        reset_button.text = _t("reset")
        reset_button.tooltip_text = _t("reset")
    if is_instance_valid(pause_button):
        pause_button.tooltip_text = _t("pause")
    if is_instance_valid(pause_title_label):
        pause_title_label.text = _t("pause_title")
    if is_instance_valid(pause_subtitle_label):
        pause_subtitle_label.text = _t("pause_sub")
    if is_instance_valid(resume_button_ref):
        resume_button_ref.text = _t("resume")
    if is_instance_valid(reset_menu_ref):
        reset_menu_ref.text = _t("to_cp")
    if is_instance_valid(restart_button):
        restart_button.text = _t("restart")
    if is_instance_valid(win_again_ref):
        win_again_ref.text = _t("again")
    if is_instance_valid(win_stay_ref):
        win_stay_ref.text = _t("stay")
    for picker in language_selectors:
        if is_instance_valid(picker):
            picker.select(maxi(0, LANGS.find(lang)))
    if is_instance_valid(start_overlay):
        var c := start_overlay.get_node_or_null("CenterCard/Content/ContinueButton") as Button
        var w := start_overlay.get_node_or_null("CenterCard/Content/WelcomeLabel") as Label
        if c:
            c.text = _t("continue")
        if w:
            w.text = _t("welcome")

func _build_start_flow() -> void:
    var hud := get_node("GameHUD") as CanvasLayer
    intro_overlay = Control.new()
    intro_overlay.name = "PublisherIntro"
    intro_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    intro_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    intro_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
    hud.add_child(intro_overlay)
    var dark := ColorRect.new()
    dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dark.color = Color(0.012, 0.018, 0.03, 1.0)
    intro_overlay.add_child(dark)
    var peak := TextureRect.new()
    peak.texture = load("res://assets/summit_forge_logo.svg") as Texture2D
    peak.set_anchors_preset(Control.PRESET_CENTER)
    peak.position = Vector2(-250, -205)
    peak.size = Vector2(500, 410)
    peak.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    peak.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
    peak.mouse_filter = Control.MOUSE_FILTER_IGNORE
    intro_overlay.add_child(peak)
    var brand := Label.new()
    brand.text = "SUMMIT FORGE"
    brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    brand.set_anchors_preset(Control.PRESET_CENTER)
    brand.position = Vector2(-300, 20)
    brand.size = Vector2(600, 80)
    brand.add_theme_font_size_override("font_size", 42)
    brand.add_theme_color_override("font_color", Color(0.94, 0.76, 0.42))
    intro_overlay.add_child(brand)

    start_overlay = Control.new()
    start_overlay.name = "StartMenu"
    start_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    start_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    start_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
    start_overlay.visible = false
    hud.add_child(start_overlay)
    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.025, 0.045, 0.07, 1.0)
    start_overlay.add_child(bg)
    var splash_art := TextureRect.new()
    splash_art.texture = load("res://assets/start_screen.jpg") as Texture2D
    splash_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    splash_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    splash_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    splash_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    start_overlay.add_child(splash_art)
    var summit := Label.new()
    summit.text = ""
    summit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    summit.set_anchors_preset(Control.PRESET_CENTER_TOP)
    summit.position = Vector2(-180, 22)
    summit.size = Vector2(360, 205)
    summit.add_theme_font_size_override("font_size", 180)
    summit.add_theme_color_override("font_color", Color(0.84, 0.70, 0.48))
    start_overlay.add_child(summit)
    var card := PanelContainer.new()
    card.name = "CenterCard"
    card.anchor_left = 0.5
    card.anchor_right = 0.5
    card.anchor_top = 0.5
    card.anchor_bottom = 0.5
    card.offset_left = -245
    card.offset_right = 245
    card.offset_top = -145
    card.offset_bottom = 185
    card.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.025, 0.045, 0.065, 0.96)))
    start_overlay.add_child(card)
    var content := VBoxContainer.new()
    content.name = "Content"
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation", 18)
    card.add_child(content)
    var game_name := Label.new()
    game_name.text = "CLIMB MASTER"
    game_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    game_name.add_theme_font_size_override("font_size", 34)
    game_name.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
    content.add_child(game_name)
    var welcome := Label.new()
    welcome.name = "WelcomeLabel"
    welcome.text = _t("welcome")
    welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    welcome.add_theme_font_size_override("font_size", 17)
    content.add_child(welcome)
    _add_language_selector(content)
    var go := Button.new()
    go.name = "ContinueButton"
    go.text = _t("continue")
    go.custom_minimum_size = Vector2(330, 62)
    _style_hud_button(go, Color(0.58, 0.34, 0.08, 1.0))
    go.pressed.connect(_start_game)
    content.add_child(go)

func _play_intro() -> void:
    await get_tree().create_timer(2.4, true, false, true).timeout
    if is_instance_valid(intro_overlay):
        intro_overlay.visible = false
    if is_instance_valid(start_overlay):
        start_overlay.visible = true

func _start_game() -> void:
    if is_instance_valid(start_overlay):
        start_overlay.visible = false
    get_tree().paused = false

func _hud_panel_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = Color(0.28, 0.58, 0.58, 0.72)
    style.set_border_width_all(1)
    style.set_corner_radius_all(14)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    return style


func _style_hud_button(button: Button, color: Color) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = color
    normal.border_color = Color(0.42, 0.76, 0.72, 0.8)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(12)
    normal.content_margin_left = 12
    normal.content_margin_right = 12
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = color.lightened(0.16)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = color.darkened(0.18)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_color_override("font_color", Color(0.96, 0.98, 0.95))
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _toggle_pause() -> void:
    player.release_pointer()
    get_tree().paused = not get_tree().paused
    if is_instance_valid(pause_button):
        pause_button.text = ">" if get_tree().paused else "II"
    if is_instance_valid(pause_overlay):
        pause_overlay.visible = get_tree().paused

func _physics_process(delta: float) -> void:
    obstacle_clock += delta
    for i in range(moving_obstacles.size()):
        var obstacle := moving_obstacles[i]
        if is_instance_valid(obstacle):
            var phase := obstacle_phases[i] if i < obstacle_phases.size() else float(i) * 1.7
            obstacle.rotation.z = sin(obstacle_clock * (0.82 + float(i) * 0.13) + phase) * 0.48
    for i in range(collectible_nodes.size()):
        var pickup := collectible_nodes[i]
        if is_instance_valid(pickup):
            pickup.rotation.y += delta * 1.35
            pickup.position.y += sin(obstacle_clock * 2.0 + float(i)) * delta * 0.12

func _process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    var h := maxf(0.0, player.global_position.y - start_y)
    _check_checkpoint()
    if player.hook_feedback != last_player_feedback:
        last_player_feedback = player.hook_feedback
        status_label.text = _localized_feedback(last_player_feedback)
    if h > best_height:
        var old_best := int(best_height)
        best_height = h
        if int(best_height) != old_best:
            _save_record()
    height_label.text = ("%d m" % int(h)) if lang != "ru" else "%d м" % int(h)
    record_label.text = _t("record") % int(best_height)
    climb_progress.value = clampf(h, 0.0, TOP_HEIGHT)
    _check_finish()
    # Fixed, slightly elevated chase camera: it follows the climber but does not orbit.
    # Fixed side-on camera: no orbit, depth travel, or perspective drift.
    var target_camera := Vector3(player.global_position.x, player.global_position.y + 2.25, 18.0)
    camera.global_position = camera.global_position.lerp(target_camera, 1.0 - exp(-4.2 * delta))
    camera.look_at(player.global_position + Vector3(0, 2.25, 0), Vector3.UP)
    if player.global_position.y < -8.0 and not game_over:
        _fall_back_to_start()

func _check_checkpoint() -> void:
    for i in range(active_checkpoint, checkpoint_positions.size()):
        if player.global_position.distance_to(checkpoint_positions[i]) < 1.45:
            active_checkpoint = i + 1
            status_label.text = "КОНТРОЛЬНАЯ ТОЧКА %d СОХРАНЕНА!" % active_checkpoint
            checkpoint_label.text = _t("checkpoint") if active_checkpoint == 0 else _t("checkpoint_n") % active_checkpoint

func _reset_player() -> void:
    get_tree().paused = false
    player.release_pointer()
    finished = false
    if is_instance_valid(win_overlay):
        win_overlay.visible = false
    if is_instance_valid(pause_button):
        pause_button.text = "II"
    if is_instance_valid(pause_overlay):
        pause_overlay.visible = false
    var respawn := Vector3(0, 1.0, 0) if current_level == 1 else level_two_start
    if active_checkpoint > 0:
        respawn = checkpoint_positions[active_checkpoint - 1] + Vector3(0, 0.65, 0)
    respawn.z = 0.0
    player.global_position = respawn
    player.velocity = Vector3.ZERO
    player.set_physics_process(true)
    player.reset_hammer()
    game_over = false
    restart_button.visible = false
    status_label.text = "ТЕНЬ НАЧИНАЕТСЯ. ЦЕПЛЯЙСЯ ЗА ЧЁРНЫЕ ВЫСТУПЫ." if current_level == 2 else _t("touch")



func _fall_back_to_start() -> void:
    # Falling below the playable area returns the climber to the actual start platform.
    # Checkpoints remain available for manual reset, but a fall always restarts at the beginning.
    player.release_pointer()
    player.velocity = Vector3.ZERO
    player.global_position = Vector3(0.0, 1.0, 0.0) if current_level == 1 else level_two_start
    player.reset_hammer()
    active_checkpoint = 0
    game_over = false
    finished = false
    restart_button.visible = false
    checkpoint_label.text = "ТЕНЕВОЙ УРОВЕНЬ  •  КП 0" if current_level == 2 else _t("checkpoint")
    status_label.text = "ТЕНЬ НАЧИНАЕТСЯ. ЦЕПЛЯЙСЯ ЗА ЧЁРНЫЕ ВЫСТУПЫ." if current_level == 2 else _t("touch")

func _on_win_primary_action() -> void:
    if current_level == 1:
        _advance_to_shadow_level()
    else:
        _restart_run()

func _advance_to_shadow_level() -> void:
    current_level = 2
    finished = false
    game_over = false
    active_checkpoint = 0
    checkpoint_positions = [
        Vector3(1.35, 30.15, 0.0),
        Vector3(-1.35, 37.20, 0.0),
        Vector3(1.35, 44.25, 0.0)
    ]
    finish_position = level_two_finish
    start_y = level_two_start.y
    player.set_silhouette_mode(true)
    player.global_position = level_two_start
    player.velocity = Vector3.ZERO
    player.reset_hammer()
    win_overlay.visible = false
    restart_button.visible = false
    checkpoint_label.text = "ТЕНЕВОЙ УРОВЕНЬ  •  КП 0"
    status_label.text = "ТЕНЬ НАЧИНАЕТСЯ. ЦЕПЛЯЙСЯ ЗА ЧЁРНЫЕ ВЫСТУПЫ."
    get_tree().paused = false

func _restart_run() -> void:
    active_checkpoint = 0
    if current_level == 2:
        checkpoint_label.text = "ТЕНЕВОЙ УРОВЕНЬ  •  КП 0"
    else:
        checkpoint_label.text = "СТАРТ  •  КП 0"
    _reset_player()

func _check_finish() -> void:
    if finished:
        return
    if player.global_position.distance_to(finish_position) < 1.1:
        finished = true
        player.release_pointer()
        win_label.text = ("УРОВЕНЬ 1 ПРОЙДЕН!" if current_level == 1 else "ТЕНЕВОЙ УРОВЕНЬ ПРОЙДЕН!") + "\\n" + ("Рекорд: %d м" % int(best_height))
        if is_instance_valid(win_again_ref):
            win_again_ref.text = "ПЕРЕЙТИ НА УРОВЕНЬ 2" if current_level == 1 else "ИГРАТЬ СНОВА"
        win_overlay.visible = true
        _save_record()

func _build_win_overlay(hud: CanvasLayer) -> void:
    win_overlay = Control.new()
    win_overlay.name = "WinOverlay"
    win_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    win_overlay.visible = false
    win_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    hud.add_child(win_overlay)

    var dim := ColorRect.new()
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.color = Color(0.008, 0.018, 0.028, 0.72)
    win_overlay.add_child(dim)

    var card := PanelContainer.new()
    card.anchor_left = 0.5
    card.anchor_right = 0.5
    card.anchor_top = 0.5
    card.anchor_bottom = 0.5
    card.offset_left = -190
    card.offset_right = 190
    card.offset_top = -145
    card.offset_bottom = 145
    card.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.045, 0.075, 0.09, 0.99)))
    win_overlay.add_child(card)

    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 15)
    card.add_child(box)

    win_label = Label.new()
    win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    win_label.add_theme_font_size_override("font_size", 28)
    win_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.60))
    box.add_child(win_label)

    var again := Button.new()
    again.text = _t("again")
    win_again_ref = again
    again.custom_minimum_size = Vector2(300, 54)
    _style_hud_button(again, Color(0.08, 0.42, 0.36, 1.0))
    again.pressed.connect(_on_win_primary_action)
    box.add_child(again)

    var stay := Button.new()
    stay.text = _t("stay")
    win_stay_ref = stay
    stay.custom_minimum_size = Vector2(300, 48)
    _style_hud_button(stay, Color(0.22, 0.14, 0.11, 1.0))
    stay.pressed.connect(func(): win_overlay.visible = false)
    box.add_child(stay)

func _load_record() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) == OK:
        best_height = float(cfg.get_value("progress", "best_height", 0.0))

func _save_record() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("progress", "best_height", best_height)
    cfg.save(SAVE_PATH)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
        _save_record()
