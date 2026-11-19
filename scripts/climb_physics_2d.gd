extends Node2D
class_name ClimbPhysics2D

# Physical units are metres. Screen/world conversion is handled by the Node3D view.
const POT_MASS := 12.0
const POT_LINEAR_DAMP := 0.12
const POT_ANGULAR_DAMP := 0.28
const POT_FRICTION := 1.15
const HAMMER_MASS := 0.85
const HAMMER_FRICTION := 0.9
const ARM_REACH := 3.95
const MOTOR_TORQUE := 95.0
const MOTOR_KP := 155.0
const MOTOR_KD := 18.0
const MAX_HAMMER_ANGULAR_SPEED := 8.5
const MAX_HAMMER_LINEAR_SPEED := 24.0
const POT_RADIUS := 0.72
const HAMMER_SHAFT_LENGTH := 2.65
const HAMMER_HEAD_RADIUS := 0.24
const DEFAULT_TARGET_ANGLE := -0.72

var pot: RigidBody2D
var hammer: RigidBody2D
var shoulder_joint: PinJoint2D
var target_angle := DEFAULT_TARGET_ANGLE
var target_world := Vector2.ZERO
var initialized := false
var last_contact := false

func _ready() -> void:
    _build_bodies()

func _build_bodies() -> void:
    pot = RigidBody2D.new()
    pot.name = "PotBody"
    pot.mass = POT_MASS
    pot.linear_damp = POT_LINEAR_DAMP
    pot.angular_damp = POT_ANGULAR_DAMP
    pot.can_sleep = false
    pot.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
    pot.physics_material_override = _material(POT_FRICTION, 0.02)
    add_child(pot)

    var pot_shape := CollisionShape2D.new()
    var pot_circle := CircleShape2D.new()
    pot_circle.radius = POT_RADIUS
    pot_shape.shape = pot_circle
    pot_shape.position = Vector2(0.0, -0.28)
    pot.add_child(pot_shape)

    var pot_visual_shape := CollisionShape2D.new()
    var pot_base := RectangleShape2D.new()
    pot_base.size = Vector2(1.22, 0.28)
    pot_visual_shape.shape = pot_base
    pot_visual_shape.position = Vector2(0.0, 0.30)
    pot.add_child(pot_visual_shape)

    hammer = RigidBody2D.new()
    hammer.name = "HammerBody"
    hammer.mass = HAMMER_MASS
    hammer.linear_damp = 0.025
    hammer.angular_damp = 0.12
    hammer.can_sleep = false
    hammer.contact_monitor = true
    hammer.max_contacts_reported = 8
    hammer.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
    hammer.physics_material_override = _material(HAMMER_FRICTION, 0.0)

    var shaft_shape := CollisionShape2D.new()
    var shaft := RectangleShape2D.new()
    shaft.size = Vector2(0.16, HAMMER_SHAFT_LENGTH)
    shaft_shape.shape = shaft
    shaft_shape.position = Vector2(0.0, -HAMMER_SHAFT_LENGTH * 0.5)
    hammer.add_child(shaft_shape)

    var head_shape := CollisionShape2D.new()
    var head := CircleShape2D.new()
    head.radius = HAMMER_HEAD_RADIUS
    head_shape.shape = head
    head_shape.position = Vector2(0.88, -HAMMER_SHAFT_LENGTH - 0.48)
    hammer.add_child(head_shape)
    # The tool is gripped at its body origin; keep its centre of mass there
    # so the shoulder pin does not orbit around the shaft's geometric centroid.
    hammer.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
    hammer.center_of_mass = Vector2.ZERO
    add_child(hammer)

    initialized = true

func _material(friction: float, bounce: float) -> PhysicsMaterial:
    var result := PhysicsMaterial.new()
    result.friction = friction
    result.bounce = bounce
    return result

func configure_start(world_position: Vector2, rotation: float = 0.0) -> void:
    if not initialized:
        return
    target_angle = DEFAULT_TARGET_ANGLE
    pot.global_position = world_position
    pot.rotation = rotation
    pot.linear_velocity = Vector2.ZERO
    pot.angular_velocity = 0.0
    hammer.global_position = pot.global_position + Vector2(0.30, -0.72).rotated(rotation)
    hammer.rotation = target_angle
    hammer.linear_velocity = Vector2.ZERO
    hammer.angular_velocity = 0.0
    # Flush both teleports to the physics server before the joint captures its anchors.
    pot.force_update_transform()
    hammer.force_update_transform()
    _rebuild_shoulder_joint()
    target_world = hammer.global_position + Vector2.UP.rotated(target_angle) * ARM_REACH

func _rebuild_shoulder_joint() -> void:
    # Recreate the constraint after positioning both bodies. This makes the
    # initial local anchors unambiguous on reset and prevents a stale origin pin.
    if is_instance_valid(shoulder_joint):
        shoulder_joint.free()
    shoulder_joint = PinJoint2D.new()
    shoulder_joint.name = "ShoulderPin"
    # Configure the complete joint before entering the scene tree so the physics
    # server captures the already-positioned bodies and their correct local anchors.
    shoulder_joint.position = pot.global_position + Vector2(0.30, -0.72).rotated(pot.rotation)
    shoulder_joint.node_a = pot.get_path()
    shoulder_joint.node_b = hammer.get_path()
    shoulder_joint.disable_collision = true
    add_child(shoulder_joint)

func set_target_world(world_point: Vector2) -> void:
    target_world = world_point
    var shoulder := pot.global_position + Vector2(0.30, -0.72).rotated(pot.rotation)
    var aim := world_point - shoulder
    if aim.length() > ARM_REACH:
        aim = aim.normalized() * ARM_REACH
    if aim.length_squared() > 0.0001:
        target_angle = aim.angle() + PI * 0.5

func _physics_process(_delta: float) -> void:
    if not initialized:
        return
    shoulder_joint.global_position = pot.global_position + Vector2(0.30, -0.72).rotated(pot.rotation)
    # A bounded PD torque motor turns the hammer. The pin joint transfers
    # all reaction forces to the pot; there are no contact impulses by hand.
    var error := wrapf(target_angle - hammer.rotation, -PI, PI)
    var torque := clampf(error * MOTOR_KP - hammer.angular_velocity * MOTOR_KD,
        -MOTOR_TORQUE, MOTOR_TORQUE)
    hammer.apply_torque(torque)
    if hammer.angular_velocity > MAX_HAMMER_ANGULAR_SPEED:
        hammer.angular_velocity = MAX_HAMMER_ANGULAR_SPEED
    elif hammer.angular_velocity < -MAX_HAMMER_ANGULAR_SPEED:
        hammer.angular_velocity = -MAX_HAMMER_ANGULAR_SPEED
    if hammer.linear_velocity.length() > MAX_HAMMER_LINEAR_SPEED:
        hammer.linear_velocity = hammer.linear_velocity.normalized() * MAX_HAMMER_LINEAR_SPEED
    if pot.linear_velocity.length() > 32.0:
        pot.linear_velocity = pot.linear_velocity.normalized() * 32.0

func add_static_polygon(points: PackedVector2Array, friction: float = 0.85, bounce: float = 0.0) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.physics_material_override = _material(friction, bounce)
    var shape := CollisionShape2D.new()
    var polygon := ConvexPolygonShape2D.new()
    polygon.points = points
    shape.shape = polygon
    body.add_child(shape)
    add_child(body)
    return body

func add_static_box(center: Vector2, size: Vector2, rotation: float = 0.0,
        friction: float = 0.85, bounce: float = 0.0) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.position = center
    body.rotation = rotation
    body.physics_material_override = _material(friction, bounce)
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = size
    shape.shape = rectangle
    body.add_child(shape)
    add_child(body)
    return body

func add_static_circle(center: Vector2, radius: float, friction: float = 0.85) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.position = center
    body.physics_material_override = _material(friction, 0.0)
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = radius
    shape.shape = circle
    body.add_child(shape)
    add_child(body)

    return body

func add_static_capsule(center: Vector2, radius: float, height: float, rotation: float = 0.0,
        friction: float = 0.85) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.position = center
    body.rotation = rotation
    body.physics_material_override = _material(friction, 0.0)
    var shape := CollisionShape2D.new()
    var capsule := CapsuleShape2D.new()
    capsule.radius = radius
    capsule.height = maxf(height, radius * 2.0)
    shape.shape = capsule
    body.add_child(shape)
    add_child(body)
    return body

func sync_visible_position() -> Vector2:
    return pot.global_position

func reset_to(world_position: Vector2) -> void:
    configure_start(world_position)
