extends Control

const CharacterDatabase = preload("res://scripts/data/character_database.gd")

var order = []
var cards = []
var selected_index = 0
var info_label

func _ready():
    order = CharacterDatabase.get_order()
    selected_index = max(0, order.find(GameState.selected_character))
    _build_ui()
    _refresh_selection()

func _process(_delta):
    if InputRouter.is_action_just_pressed_mc("move_left"):
        selected_index = wrapi(selected_index - 1, 0, order.size())
        _refresh_selection()
    if InputRouter.is_action_just_pressed_mc("move_right"):
        selected_index = wrapi(selected_index + 1, 0, order.size())
        _refresh_selection()
    if InputRouter.is_action_just_pressed_mc("fire") or InputRouter.is_action_just_pressed_mc("jump") or InputRouter.is_action_just_pressed_mc("start"):
        _deploy_selected()
    if InputRouter.is_action_just_pressed_mc("pause"):
        get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _build_ui():
    var background = TextureRect.new()
    background.texture = load("res://assets/environment/lab_panel_240x160.png")
    background.position = Vector2.ZERO
    background.size = Vector2(240, 160)
    background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)

    var shade = ColorRect.new()
    shade.position = Vector2.ZERO
    shade.size = Vector2(240, 160)
    shade.color = Color(0.0, 0.0, 0.0, 0.30)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(shade)

    var title = Label.new()
    title.text = "CHARACTER SELECT"
    title.position = Vector2(0, 4)
    title.size = Vector2(240, 15)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 11)
    title.add_theme_color_override("font_color", Color(0.58, 1.0, 0.18))
    add_child(title)

    for i in range(order.size()):
        var character_id = order[i]
        var data = CharacterDatabase.get_character(character_id)
        var card = Button.new()
        card.position = Vector2(5 + i * 39, 24)
        card.size = Vector2(36, 93)
        card.text = ""
        card.focus_mode = Control.FOCUS_NONE
        card.pressed.connect(_on_card_pressed.bind(i))
        add_child(card)
        cards.append(card)

        var portrait = TextureRect.new()
        portrait.texture = load(data["portrait"])
        portrait.position = Vector2(2, 4)
        portrait.size = Vector2(32, 64)
        portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(portrait)

        var label = Label.new()
        label.text = data["display_name"]
        label.position = Vector2(0, 72)
        label.size = Vector2(36, 14)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 6)
        label.add_theme_color_override("font_color", Color(0.78, 1.0, 0.55))
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(label)

    info_label = Label.new()
    info_label.position = Vector2(4, 124)
    info_label.size = Vector2(232, 31)
    info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info_label.add_theme_font_size_override("font_size", 7)
    info_label.add_theme_color_override("font_color", Color(0.86, 1.0, 0.72))
    add_child(info_label)

func _on_card_pressed(index):
    if index == selected_index:
        _deploy_selected()
    else:
        selected_index = index
        _refresh_selection()

func _refresh_selection():
    for i in range(cards.size()):
        var style = StyleBoxFlat.new()
        style.bg_color = Color(0.02, 0.04, 0.03, 0.88)
        style.border_color = Color(0.55, 1.0, 0.12, 1.0) if i == selected_index else Color(0.15, 0.32, 0.16, 0.85)
        style.set_border_width_all(2 if i == selected_index else 1)
        cards[i].add_theme_stylebox_override("normal", style)
        cards[i].add_theme_stylebox_override("hover", style)
        cards[i].add_theme_stylebox_override("pressed", style)
    var selected_id = order[selected_index]
    var data = CharacterDatabase.get_character(selected_id)
    info_label.text = "%s  //  HP %d  //  STANDARDIZED JUMP + HITBOX\nFIRE: HOLD  //  8-WAY AIM  //  ENTER/FIRE TO DEPLOY" % [data["display_name"], GameState.DIFFICULTIES[GameState.difficulty]["hp"]]

func _deploy_selected():
    GameState.selected_character = order[selected_index]
    get_tree().change_scene_to_file("res://scenes/stage1_killing_floor.tscn")
