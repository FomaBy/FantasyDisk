extends SceneTree

## FAN-2515 — канонический weapon-ultimate как единственная правда UI.
##
## Оракул проверяет три вещи и падает на каждой отдельно:
##   1. реестр отдаёт РОВНО 51 запись с непустым уникальным title/mechanics;
##   2. валидатор таблицы отвергает пропуск, лишнюю пару, пустое поле и дубль;
##   3. HUD, Кодекс и досье паузы показывают ОДИН И ТОТ ЖЕ текст выбранной
##      ульты (живой виджет + живое досье, а не пересказ источника).
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/canonical_ultimate_text_test.gd

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Text := preload("res://scripts/ultimates/registry/weapon_ultimate_text.gd")
const CodexData := preload("res://scripts/codex_data.gd")
const HudAdapter := preload("res://scripts/ui/ultimate_hud/ultimate_hud_runtime_adapter.gd")
const MAIN_SCENE := preload("res://scenes/Main.tscn")
const MANIFEST_ROOT := "res://docs/design/references/weapon_ultimates"

# Выборка для живых UI-поверхностей: базовый кит, призывной кит и класс,
# у которого канонический титул появился только в этой карточке.
const LIVE_SELECTIONS := [
	{"class_id": "berserk", "weapon_id": "sword"},
	{"class_id": "druid", "weapon_id": "summon_amulet"},
	{"class_id": "engineer", "weapon_id": "engineer_sentry_wrench"},
]

var _errors: Array[String] = []


## Минимальный источник выбора для HUD-адаптера: он читает только идентичность
## и заряд, поэтому полноценный Player живому виджету здесь не нужен.
class HudPlayerFixture extends Node2D:
	var character_id := ""
	var weapon_id := ""
	var ultimate_charge := 100.0
	var ultimate_max_charge := 100.0
	var _ultimate_active := false

	func attack_aim_mode() -> String:
		return "nearest"


func _initialize() -> void:
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_assert_registry_records(registry)
	_assert_manifest_titles(registry)
	_assert_validator_rejections(registry)
	await _assert_live_surfaces(registry)

	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	print("FAN-2515: 51 canonical weapon ultimates resolve; HUD, Codex and pause dossier agree.")
	quit(0)


func _assert_registry_records(registry) -> void:
	_expect(registry.is_valid(), "registry must be valid: %s" % str(registry.validation_errors()))
	_expect(
		registry.text_validation_errors().is_empty(),
		"canonical text must satisfy the catalog: %s" % str(registry.text_validation_errors())
	)
	var keys: Array[String] = registry.profile_keys()
	_expect(keys.size() == 51, "registry must expose exactly 51 profiles, got %d" % keys.size())
	var titles := {}
	var resolved := 0
	for key in keys:
		var parts := str(key).split("/", false, 1)
		var text: Dictionary = registry.ultimate_text(parts[0], parts[1])
		if str(text.get("title", "")).strip_edges().is_empty() \
				or str(text.get("description", "")).strip_edges().is_empty():
			_errors.append("%s must resolve a non-empty canonical title and mechanics" % key)
			continue
		var title := str(text["title"])
		if titles.has(title):
			_errors.append("%s duplicates the title of %s" % [key, str(titles[title])])
			continue
		titles[title] = key
		resolved += 1
	_expect(resolved == 51, "exactly 51 canonical records must resolve, got %d" % resolved)


## Принятые art-манифесты и каноническая таблица не имеют права разойтись:
## титул ульты у пары ровно один.
func _assert_manifest_titles(registry) -> void:
	var checked := 0
	for class_id in registry.class_ids():
		var path := "%s/%s/manifest.json" % [MANIFEST_ROOT, class_id]
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			_errors.append("%s must parse as a presentation manifest" % path)
			continue
		for raw_weapon in (parsed as Dictionary).get("weapons", []):
			var weapon := raw_weapon as Dictionary
			var weapon_id := str(weapon.get("weapon_id", ""))
			var canonical := str(registry.ultimate_text(class_id, weapon_id).get("title", ""))
			if str(weapon.get("title", "")) != canonical:
				_errors.append(
					"%s/%s manifest title '%s' must equal canonical '%s'"
					% [class_id, weapon_id, str(weapon.get("title", "")), canonical]
				)
				continue
			checked += 1
	_expect(checked == 51, "all 51 manifest titles must be unified, got %d" % checked)


## Фальсификация валидатора: каждый дефект таблицы обязан быть отвергнут.
func _assert_validator_rejections(registry) -> void:
	var keys: Array[String] = registry.profile_keys()
	var baseline := Text.records()
	_expect(
		Text.validate_records(keys, baseline).is_empty(),
		"live table must validate clean against the catalog"
	)
	_expect(not Text.validate_records(keys, {}).is_empty(), "an absent table must be rejected")

	var missing := baseline.duplicate(true)
	missing.erase(str(keys[0]))
	_expect(not Text.validate_records(keys, missing).is_empty(), "a missing pair must be rejected")

	var extra := baseline.duplicate(true)
	extra["berserk/not_a_weapon"] = {"title": "X", "description": "Y"}
	_expect(not Text.validate_records(keys, extra).is_empty(), "an unknown pair must be rejected")

	var empty := baseline.duplicate(true)
	(empty[str(keys[0])] as Dictionary)["description"] = "  "
	_expect(not Text.validate_records(keys, empty).is_empty(), "an empty mechanics line must be rejected")

	var duplicated := baseline.duplicate(true)
	(duplicated[str(keys[1])] as Dictionary)["title"] = str((baseline[str(keys[0])] as Dictionary)["title"])
	_expect(not Text.validate_records(keys, duplicated).is_empty(), "a duplicated title must be rejected")


func _assert_live_surfaces(registry) -> void:
	var codex_by_pair := {}
	for character in CodexData.characters():
		for weapon in (character as Dictionary)["weapons"]:
			var key := "%s/%s" % [str((character as Dictionary)["id"]), str((weapon as Dictionary)["id"])]
			codex_by_pair[key] = (weapon as Dictionary).get("ultimate", {})
	_expect(codex_by_pair.size() == 51, "Codex must carry 51 weapon ultimates, got %d" % codex_by_pair.size())

	for selection in LIVE_SELECTIONS:
		var class_id := str((selection as Dictionary)["class_id"])
		var weapon_id := str((selection as Dictionary)["weapon_id"])
		var canonical: Dictionary = registry.ultimate_text(class_id, weapon_id)
		var key := "%s/%s" % [class_id, weapon_id]
		_expect(
			codex_by_pair.get(key, {}) == canonical,
			"Codex %s must show the canonical ultimate, got %s" % [key, str(codex_by_pair.get(key, {}))]
		)
		await _assert_hud(class_id, weapon_id, canonical)
		await _assert_pause_dossier(class_id, weapon_id, canonical)


func _assert_hud(class_id: String, weapon_id: String, canonical: Dictionary) -> void:
	var input_manager := root.get_node_or_null("InputDeviceManager")
	if input_manager != null and input_manager.has_method("set_input_mode"):
		input_manager.call("set_input_mode", "keyboard")
	var game := Node.new()
	var hud_root := Control.new()
	hud_root.size = Vector2(1280.0, 720.0)
	game.add_child(hud_root)
	root.add_child(game)
	var player := HudPlayerFixture.new()
	player.character_id = class_id
	player.weapon_id = weapon_id
	game.add_child(player)
	var adapter := HudAdapter.new()
	hud_root.add_child(adapter)
	adapter.mount(hud_root, player)
	await process_frame
	await process_frame

	var context := "%s/%s" % [class_id, weapon_id]
	var title := hud_root.find_child("TooltipUltimateTitle", true, false) as Label
	var description := hud_root.find_child("TooltipUltimateDescription", true, false) as Label
	if title == null or description == null:
		_errors.append("%s: HUD widget must expose the ultimate tooltip labels." % context)
	else:
		if title.text != str(canonical.get("title", "")):
			_errors.append("%s: HUD title '%s' must be canonical '%s'." % [context, title.text, str(canonical.get("title", ""))])
		if description.text != str(canonical.get("description", "")):
			_errors.append("%s: HUD mechanics '%s' must be canonical." % [context, description.text])
	game.queue_free()
	await process_frame


func _assert_pause_dossier(class_id: String, weapon_id: String, canonical: Dictionary) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	main.set("selected_character_id", class_id)
	main.set("selected_weapon_id", weapon_id)
	main.set("route_stage", 2)
	main.call("_start_combat")
	await _settle()
	main.ui._show_pause_menu(true)
	await _settle()

	var context := "%s/%s pause dossier" % [class_id, weapon_id]
	var pause := main.find_child("PauseStatsMenuRoot", true, false) as Control
	if pause == null:
		_errors.append("%s: dossier did not open." % context)
	else:
		var kind := pause.find_child("ArsenalUltimateKind", true, false) as Label
		var body := pause.find_child("ArsenalUltimateBody", true, false) as Label
		if kind == null or body == null:
			_errors.append("%s: arsenal must expose the ultimate entry labels." % context)
		else:
			if not kind.text.contains(str(canonical.get("title", ""))):
				_errors.append("%s: arsenal title '%s' must carry '%s'." % [context, kind.text, str(canonical.get("title", ""))])
			if body.text != str(canonical.get("description", "")):
				_errors.append("%s: arsenal mechanics '%s' must be canonical." % [context, body.text])
		var summary := pause.find_child("RunBuildSummaryLabel", true, false) as Label
		if summary != null and not summary.text.contains(str(canonical.get("title", ""))):
			_errors.append("%s: build summary '%s' must name the selected weapon ultimate." % [context, summary.text])
	main.queue_free()
	viewport.queue_free()
	for _frame in range(4):
		await process_frame


func _settle() -> void:
	for _frame in range(6):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
