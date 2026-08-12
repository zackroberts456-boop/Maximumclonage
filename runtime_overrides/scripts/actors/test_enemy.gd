extends CharacterBody2D

const HealthComponent = preload("res://scripts/components/health_component.gd")
const GameRules = preload("res://scripts/data/game_rules.gd")
const Projectile = preload("res://scripts/weapons/projectile.gd")

const WALK_ATLAS = "res://assets/enemies/clone_grunt_walk8_clean.png"
const WALK_FRAME_SIZE = Vector2i(192, 176)
const PATROL_RADIUS = 64.0
const ACTIVATION_RANGE = 196.0
const SHOOT_MIN_RANGE = 62.0
const SHOOT_MAX_RANGE = 132.0
const RETREAT_RANGE = 42.0

var spawn_x = 0.0
var patrol_direction = -1
var speed = 29.0
var fire_interval = 1.0
var projectile_speed = 118.0
var shoot_timer = 0.35
var dead = false
var health
var sprite
var damage_area
var current_state = "patrol"

func _ready():
    add_to_group("enemies")
    collision_layer = 4
    collision_mask = 1
    spawn_x = global_position.x
    var difficulty = GameRules.difficulty_data(GameState.difficulty)
    speed *= float(difficulty["enemy_speed_scale"])
    fire_interval *= float(difficulty["enemy_fire_interval_scale"])
    projectile_speed *= float(difficulty["enemy_projectile_speed_scale"])

    var collider = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(18, 30)
    collider.shape = shape
    collider.position = Vector2(0, -3)
    add_child(collider)

    sprite = AnimatedSprite2D.new()
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = Vector2(0, -18)
    sprite.scale = Vector2(0.46, 0.46)
    sprite.sprite_frames = _build_sprite_frames(load(WALK_ATLAS))
    add_child(sprite)
    sprite.play("walk")

    health = HealthComponent.new()
    health.configure(4, 0.10)
    add_child(health)
    health.died.connect(_on_died)

    damage_area = Area2D.new()
    damage_area.collision_layer = 32
    damage_area.collision_mask = 2
    var damage_shape = CollisionShape2D.new()
    var area_shape = RectangleShape2D.new()
    area_shape.size = Vector2(20, 31)
    damage_shape.shape = area_shape
    damage_shape.position = Vector2(0, -3)
    damage_area.add_child(damage_shape)
    add_child(damage_area)
    damage_area.body_entered.connect(_on_damage_area_body_entered)

func _physics_process(delta):
    if dead:
        return

    shoot_timer = max(0.0, shoot_timer - delta)
    if not is_on_floor():
        velocity.y += GameRules.GRAVITY * delta

    var player = get_tree().get_first_node_in_group("players")
    var desired_x = patrol_direction * speed

    if player != null and not player.dead:
        var dx = player.global_position.x - global_position.x
        var distance_x = abs(dx)
        if distance_x <= ACTIVATION_RANGE:
            var target_dir = int(sign(dx))
            if target_dir == 0:
                target_dir = patrol_direction
            sprite.flip_h = target_dir < 0

            if distance_x < RETREAT_RANGE:
                current_state = "retreat"
                desired_x = -target_dir * speed * 0.82
            elif distance_x < SHOOT_MIN_RANGE:
                current_state = "hold"
                desired_x = 0.0
                _try_shoot(player)
            elif distance_x <= SHOOT_MAX_RANGE:
                current_state = "strafe"
                desired_x = target_dir * speed * 0.35
                _try_shoot(player)
            else:
                current_state = "chase"
                desired_x = target_dir * speed
        else:
            current_state = "patrol"
            desired_x = _patrol_velocity()
    else:
        current_state = "patrol"
        desired_x = _patrol_velocity()

    var move_dir = int(sign(desired_x))
    if move_dir != 0 and is_on_floor() and not _has_floor_ahead(move_dir):
        if current_state == "patrol":
            patrol_direction *= -1
        desired_x = 0.0

    velocity.x = desired_x
    move_and_slide()

    if is_on_wall() and abs(velocity.x) > 0.01:
        patrol_direction *= -1

    if current_state == "patrol" and abs(global_position.x - spawn_x) > PATROL_RADIUS:
        patrol_direction = -1 if global_position.x > spawn_x else 1

    if abs(velocity.x) > 1.0:
        if sprite.animation != "walk":
            sprite.play("walk")
        sprite.speed_scale = clamp(abs(velocity.x) / max(1.0, speed), 0.7, 1.25)
        sprite.flip_h = velocity.x < 0.0
    else:
        sprite.speed_scale = 0.45

    if global_position.y > 190.0:
        queue_free()
    if GameState.debug_collision_visible:
        queue_redraw()

func _patrol_velocity():
    if patrol_direction == 0:
        patrol_direction = -1
    return patrol_direction * speed * 0.72

func _has_floor_ahead(direction: int):
    var space_state = get_world_2d().direct_space_state
    var from = global_position + Vector2(direction * 12.0, -2.0)
    var to = from + Vector2(0.0, 30.0)
    var query = PhysicsRayQueryParameters2D.create(from, to, 1)
    query.exclude = [get_rid()]
    return not space_state.intersect_ray(query).is_empty()

func _try_shoot(player):
    if shoot_timer > 0.0:
        return
    shoot_timer = fire_interval
    var direction = (player.global_position + Vector2(0, -9) - (global_position + Vector2(0, -10))).normalized()
    var projectile = Projectile.new()
    projectile.setup(direction, projectile_speed, 1, "enemy")
    get_tree().current_scene.add_child(projectile)
    projectile.global_position = global_position + Vector2(sign(direction.x) * 18.0, -10)

func _build_sprite_frames(texture):
    var frames = SpriteFrames.new()
    if frames.has_animation("default"):
        frames.remove_animation("default")
    frames.add_animation("walk")
    frames.set_animation_loop("walk", true)
    frames.set_animation_speed("walk", 10.0)
    for index in range(8):
        var atlas = AtlasTexture.new()
        atlas.atlas = texture
        atlas.region = Rect2(index * WALK_FRAME_SIZE.x, 0, WALK_FRAME_SIZE.x, WALK_FRAME_SIZE.y)
        frames.add_frame("walk", atlas)
    return frames

func take_damage(amount, source_position = Vector2.ZERO):
    if dead:
        return false
    if health.damage(amount):
        var knock = sign(global_position.x - source_position.x)
        if knock == 0.0:
            knock = -1.0 if sprite.flip_h else 1.0
        velocity.x = knock * 38.0
        sprite.modulate = Color(1.0, 1.0, 1.0, 0.52)
        var tween = create_tween()
        tween.tween_property(sprite, "modulate", Color.WHITE, 0.10)
        return true
    return false

func _on_damage_area_body_entered(body):
    if body.is_in_group("players") and body.has_method("take_damage"):
        body.take_damage(1, global_position)

func _on_died():
    dead = true
    collision_layer = 0
    collision_mask = 0
    if damage_area != null:
        damage_area.set_deferred("monitoring", false)
        damage_area.set_deferred("monitorable", false)
    GameState.register_enemy_kill(100)
    var tween = create_tween()
    tween.tween_property(sprite, "modulate", Color(0.35, 1.0, 0.35, 0.0), 0.28)
    tween.finished.connect(queue_free)

func _draw():
    if GameState.debug_collision_visible:
        draw_rect(Rect2(Vector2(-9, -18), Vector2(18, 30)), Color(1.0, 0.2, 0.2, 0.55), false, 1.0)
