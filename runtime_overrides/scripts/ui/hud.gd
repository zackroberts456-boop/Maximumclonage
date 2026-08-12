extends CanvasLayer

var player
var root
var health_segments = []
var portrait
var name_label
var lives_label
var score_label
var combo_label
var weapon_label

func setup(target_player):
    player = target_player

func _ready():
    layer = 20
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    _make_panel(root, Vector2(3, 3), Vector2(96, 30))
    _make_panel(root, Vector2(100, 3), Vector2(47, 22))
    _make_panel(root, Vector2(148, 3), Vector2(89, 25))

    portrait = TextureRect.new()
    portrait.position = Vector2(7, 7)
    portrait.size = Vector2(19, 19)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(portrait)

    name_label = _make_label(root, Vector2(29, 5), Vector2(65, 9), "", 7)
    lives_label = _make_label(root, Vector2(29, 15), Vector2(65, 8), "", 6)
    weapon_label = _make_label(root, Vector2(102, 7), Vector2(43, 12), "", 5)
    weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    score_label = _make_label(root, Vector2(152, 5), Vector2(81, 9), "", 7)
    score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    combo_label = _make_label(root, Vector2(152, 15), Vector2(81, 8), "", 6)
    combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

    for i in range(16):
        var segment = ColorRect.new()
        segment.position = Vector2(29 + i * 4, 25)
        segment.size = Vector2(3, 4)
        segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(segment)
        health_segments.append(segment)

func _process(_delta):
    if player == null:
        return

    var data = player.character_data
    name_label.text = str(data.get("display_name", "PLAYER"))
    lives_label.text = "LIVES %d" % GameState.lives
    score_label.text = "%06d" % GameState.score
    combo_label.text = "x%d COMBO" % GameState.combo_multiplier if GameState.combo_multiplier > 1 else ""
    var special = player.get_special_weapon()
    weapon_label.text = special.to_upper() if special != "" else "DEFAULT"

    if portrait.texture == null and data.has("portrait"):
        portrait.texture = load(data["portrait"])

    for i in range(health_segments.size()):
        var segment = health_segments[i]
        segment.visible = i < GameState.max_hp
        if i < GameState.current_hp:
            var ratio = float(i + 1) / max(1.0, float(GameState.max_hp))
            segment.color = Color(0.78, 1.0 - ratio * 0.18, 0.12, 0.96)
        else:
            segment.color = Color(0.09, 0.14, 0.11, 0.78)

func _make_panel(parent, pos: Vector2, panel_size: Vector2):
    var panel = Panel.new()
    panel.position = pos
    panel.size = panel_size
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.01, 0.025, 0.02, 0.66)
    style.border_color = Color(0.36, 0.88, 0.32, 0.48)
    style.set_border_width_all(1)
    style.corner_radius_top_left = 2
    style.corner_radius_top_right = 2
    style.corner_radius_bottom_left = 2
    style.corner_radius_bottom_right = 2
    panel.add_theme_stylebox_override("panel", style)
    parent.add_child(panel)
    return panel

func _make_label(parent, pos: Vector2, label_size: Vector2, text_value: String, font_size: int):
    var label = Label.new()
    label.position = pos
    label.size = label_size
    label.text = text_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color(0.86, 1.0, 0.77))
    label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 1)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    return label
