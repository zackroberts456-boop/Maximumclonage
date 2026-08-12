extends Area2D

const KIND_SMALL = "small"
const KIND_LARGE = "large"
const KIND_FULL = "full"

var pickup_kind = KIND_SMALL
var heal_amount = 2
var collected = false
var visual_root
var base_y = 0.0
var bob_phase = 0.0

func setup(kind: String):
    pickup_kind = kind
    match pickup_kind:
        KIND_LARGE:
            heal_amount = 5
        KIND_FULL:
            heal_amount = 999
        _:
            pickup_kind = KIND_SMALL
            heal_amount = 2

func _ready():
    collision_layer = 0
    collision_mask = 2
    monitoring = true
    monitorable = true
    base_y = position.y

    var collider = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(12, 16) if pickup_kind == KIND_SMALL else Vector2(16, 20)
    collider.shape = shape
    add_child(collider)

    visual_root = Node2D.new()
    add_child(visual_root)
    _build_visual()

    body_entered.connect(_on_body_entered)

func _process(delta):
    if collected or visual_root == null:
        return
    bob_phase += delta * 3.8
    visual_root.position.y = sin(bob_phase) * 1.5
    var pulse = 0.96 + sin(bob_phase * 1.7) * 0.04
    visual_root.scale = Vector2(pulse, pulse)

func _build_visual():
    var width = 8.0 if pickup_kind == KIND_SMALL else 11.0
    var height = 12.0 if pickup_kind == KIND_SMALL else 16.0

    var shadow = Polygon2D.new()
    shadow.polygon = PackedVector2Array([
        Vector2(-width * 0.7, height * 0.58), Vector2(width * 0.7, height * 0.58),
        Vector2(width * 0.45, height * 0.78), Vector2(-width * 0.45, height * 0.78)
    ])
    shadow.color = Color(0.0, 0.0, 0.0, 0.42)
    shadow.z_index = -1
    visual_root.add_child(shadow)

    var casing = Polygon2D.new()
    casing.polygon = PackedVector2Array([
        Vector2(-width * 0.45, -height * 0.50), Vector2(width * 0.45, -height * 0.50),
        Vector2(width * 0.60, -height * 0.34), Vector2(width * 0.60, height * 0.40),
        Vector2(width * 0.42, height * 0.56), Vector2(-width * 0.42, height * 0.56),
        Vector2(-width * 0.60, height * 0.40), Vector2(-width * 0.60, -height * 0.34)
    ])
    casing.color = Color(0.06, 0.12, 0.10, 0.96)
    visual_root.add_child(casing)

    var fluid = Polygon2D.new()
    fluid.polygon = PackedVector2Array([
        Vector2(-width * 0.36, -height * 0.30), Vector2(width * 0.36, -height * 0.30),
        Vector2(width * 0.36, height * 0.36), Vector2(-width * 0.36, height * 0.36)
    ])
    fluid.color = _fluid_color()
    visual_root.add_child(fluid)

    var cross_h = Polygon2D.new()
    cross_h.polygon = PackedVector2Array([
        Vector2(-width * 0.28, -1.2), Vector2(width * 0.28, -1.2),
        Vector2(width * 0.28, 1.2), Vector2(-width * 0.28, 1.2)
    ])
    cross_h.color = Color(0.94, 1.0, 0.82, 0.92)
    visual_root.add_child(cross_h)

    var cross_v = Polygon2D.new()
    cross_v.polygon = PackedVector2Array([
        Vector2(-1.2, -width * 0.28), Vector2(1.2, -width * 0.28),
        Vector2(1.2, width * 0.28), Vector2(-1.2, width * 0.28)
    ])
    cross_v.color = Color(0.94, 1.0, 0.82, 0.92)
    visual_root.add_child(cross_v)

    if pickup_kind == KIND_FULL:
        var ring = Line2D.new()
        ring.points = PackedVector2Array([
            Vector2(-8, -10), Vector2(8, -10), Vector2(10, -8), Vector2(10, 8),
            Vector2(8, 10), Vector2(-8, 10), Vector2(-10, 8), Vector2(-10, -8),
            Vector2(-8, -10)
        ])
        ring.width = 1.0
        ring.default_color = Color(0.75, 1.0, 0.36, 0.76)
        visual_root.add_child(ring)

func _fluid_color():
    match pickup_kind:
        KIND_LARGE:
            return Color(0.18, 1.0, 0.36, 0.92)
        KIND_FULL:
            return Color(0.68, 1.0, 0.20, 0.96)
        _:
            return Color(0.30, 0.92, 1.0, 0.90)

func _on_body_entered(body):
    if collected or not body.is_in_group("players") or not body.has_method("heal"):
        return
    collected = true
    monitoring = false
    if pickup_kind == KIND_FULL:
        body.heal(GameState.max_hp)
    else:
        body.heal(heal_amount)

    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(visual_root, "scale", Vector2(1.5, 1.5), 0.16)
    tween.tween_property(visual_root, "modulate", Color(0.75, 1.0, 0.45, 0.0), 0.16)
    tween.finished.connect(queue_free)
