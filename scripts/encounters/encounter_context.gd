extends RefCounted
## EncounterContext — versioned read-обёртка боевого состояния для битов
## (EncounterFeature API v1). Бит НЕ обращается к `game`/`combat` напрямую: он
## читает всё нужное отсюда. Это держит фичи изолированными и тестируемыми через
## versioned-контракт fixtures без скрытых зависимостей на sibling-реализацию.
##
## Детерминизм: `aspect_rng(salt)` создаёт независимый RandomNumberGenerator из
## node seed и соли (game.node_aspect_rng), НЕ расходуя глобальный `game.rng`.

const API_VERSION := 1

var game
var combat
var node_seed := 0
var combat_type := "battle"
var event_active := false
var boss_active := false
var round_duration := 0.0
# Секунды активного (не поставленного на паузу) боя с момента begin директора.
var elapsed := 0.0
# Мир-родитель для презентации бита (узел директора, process_mode = PAUSABLE):
# маркеры-дети замерзают на паузе вместе с ним и гибнут при shutdown.
var presentation_parent: Node = null


func api_version() -> int:
	return API_VERSION


func aspect_rng(salt: int) -> RandomNumberGenerator:
	return game.node_aspect_rng(node_seed, salt)


func is_normal_battle() -> bool:
	return combat_type == "battle" and not boss_active and not event_active


func player() -> Node:
	if game != null and game.current_player != null and is_instance_valid(game.current_player):
		return game.current_player
	return null


func player_position() -> Vector2:
	var live := player() as Node2D
	if live != null:
		return live.global_position
	if game != null:
		return game.ARENA_CENTER
	return Vector2.ZERO


# Живые обычные враги на арене (без элиток, мини-элиток и боссов).
func alive_normal_enemies() -> Array:
	var result: Array = []
	if game == null or game.get_tree() == null:
		return result
	for node in game.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.is_queued_for_deletion():
			continue
		if enemy.is_in_group("bosses") or enemy.is_in_group("elite_enemies"):
			continue
		result.append(enemy)
	return result


# Живой корень боевого HUD (для экранного таймера бита). null, если HUD снят.
func hud_root() -> Control:
	if game == null or game.hud_layer == null or not is_instance_valid(game.hud_layer):
		return null
	return game.hud_layer.find_child("CombatHudRoot", true, false) as Control
