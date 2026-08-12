extends CharacterBody2D

const GameRules = preload("res://scripts/data/game_rules.gd")
const AcidPuddle = preload("res://scripts/world/acid_puddle.gd")

const MAX_LIFE = 2.7
const FALL_GRAVITY = 248.0

var life_left = MAX_LIFE
var direct_damage = 2
var impact_done = false
var visual
var hit_area

func setup(direction_x: float, horizontal_speed: float, upward_speed: float, damage_value: int = 2):
    var dir = -1.0 if direction_x < 0.0 else 1.0
    velocity = Vector2(dir * horizontal_speed, -upward_speed)
    direct_damage = damage_value

func _ready():
    up_direction = Vector2.UP
    collision_layer = 16
    collision_mask = 1

    var collider = CollisionShape2D.new()
    var body_shape = CircleShape2D.new()
    body_shape.radius = 4.0
    collider.shape = body_shape
    add_child(collider)

    visual = Node2D.new()
    add_child(visual)

    var core = Polygon2D.new()
    core.polygon = _circle_points(5.0, 10)
    core.color = Color(0.38, 1.0, 0.06, 0.96)
    visual.add_child(core)

    var inner = Polygon2D.new()
    inner.polygon = _circle_points(2.4, 8)
    inner.color = Color(0.82, 1.0, 0.30, 0.96)
    visual.add_child(inner)

    var trail = Line2D.new()
    trail.points = PackedVector2Array([Vector2(-11, 0), Vector2(-4, 0)])
    trail.width = 2.0
    trail.default_color = Color(0.28, 1.0, 0.05, 0.46)
    visual.add_child(trail)

    hit_area = Area2D.new()
    hit_area.collision_layer = 32
    hit_area.collision_mask = 2
    hit_area.monitoring = true
    var hit_shape = CollisionShape2D.new()
    var area_shape = CircleShape2D.new()
    area_shape.radius = 6.0
    hit_shape.shape = area_shape
    hit_area.add_child(hit_shape)
    add_child(hit_area)
    hit_area.body_entered.connect(_on_hit_player)

func _physics_process(delta):
    if impact_done:
        return

    life_left -= delta
    velocity.y += FALL_GRAVITY * delta
    move_and_slide()

    if visual != null:
        visual.rotation += delta * 4.8 * sign(velocity.x)
        var squash = clamp(abs(velocity.y) / 190.0, 0.0, 0.12)
        visual.scale = Vector2(1.0 + squash, 1.0 - squash * 0.7)

    if get_slide_collision_count() > 0:
        var floor_hit = false
        for index in range(get_slide_collision_count()):
            var collision = get_slide_collision(index)
            if collision != null and collision.get_normal().y < -0.45:
                floor_hit = true
                break
        _impact(floor_hit)
        return

    if global_position.y > 190.0 or life_left <= 0.0:
        queue_free()

func _on_hit_player(body):
    if impact_done:
        return
    if body.is_in_group("players") and body.has_method("take_damage"):
        body.take_damage(direct_damage, global_position)
        _impact(false)

func _impact(make_puddle: bool):
    if impact_done:
        return
    impact_done = true
    collision_layer = 0
    collision_mask = 0
    if hit_area != null:
        hit_area.set_deferred("monitoring", false)
        hit_area.set_deferred("monitorable", false)

    if make_puddle:
        var puddle = AcidPuddle.new()
        get_tree().current_scene.call_deferred("add_child", puddle)
        puddle.call_deferred("set", "global_position", Vector2(global_position.x, global_position.y + 2.0))

    queue_free()

func _circle_points(radius: float, segments: int):
    var points = PackedVector2Array()
    for index in range(segments):
        var angle = TAU * float(index) / float(segments)
        points.append(Vector2(cos(angle), sin(angle)) * radius)
    return points
