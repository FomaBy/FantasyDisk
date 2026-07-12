extends SceneTree

const Meta := preload("res://scripts/meta_progression.gd")
const Schema6 := preload("res://scripts/constellation_schema6_data.gd")
const Formatter := preload("res://scripts/constellation_description_formatter.gd")

var errors := PackedStringArray()


func _initialize() -> void:
	var class_nodes := []
	for raw_node in Meta.node_list():
		var node: Dictionary = raw_node
		if str(node.get("class_affinity", "")) != "":
			class_nodes.append(node)
	_check(class_nodes.size() == 357, "expected exact schema-6 class inventory 357, got %d" % class_nodes.size())

	var final_texts := {}
	var final_mechanics := {}
	var prefinal_identities := {}
	for raw_node in class_nodes:
		var node: Dictionary = raw_node
		var node_id := str(node.get("id", ""))
		var dossier: Dictionary = node.get("dossier", {})
		_check(not dossier.is_empty(), "%s has no fail-closed dossier contract" % node_id)
		_check(bool(node.get("dossier_valid", false)), "%s is not marked as a valid dossier" % node_id)
		if dossier.is_empty():
			continue
		var full_text := str(dossier.get("full_text", ""))
		_check(full_text == str(node.get("desc", "")), "%s runtime desc diverges from dossier" % node_id)
		_check(full_text.contains("Ось:"), "%s omits affected axis" % node_id)
		_check(full_text.contains("Охват:"), "%s omits explicit scope" % node_id)
		_check(full_text.contains("→"), "%s omits exact before→after value/progress" % node_id)
		_check(_has_digit(full_text), "%s omits numeric change" % node_id)
		_check(full_text.contains("Прогресс") or full_text.contains("Путь ") or full_text.contains("Ответвление"), "%s omits path progress" % node_id)
		for forbidden in ["Усиление пути.", "Финал оружия.", "TODO", "TBD", "placeholder", "неизвест"]:
			_check(not full_text.contains(forbidden), "%s contains generic/placeholder copy: %s" % [node_id, forbidden])

		var role := str(node.get("role", ""))
		if role == "core":
			_check(full_text.contains("все три оружия"), "%s core scope must name all three weapons" % node_id)
		else:
			var weapon_title := str(node.get("weapon_title", ""))
			_check(weapon_title != "" and full_text.contains("«%s»" % weapon_title), "%s omits exact owning weapon" % node_id)
			_check(full_text.contains("только это оружие"), "%s scope is not owning-weapon-only" % node_id)

		if role != "weapon_final":
			var effect_text := str(dossier.get("effect_text", ""))
			_check(effect_text.contains("→") and _has_digit(effect_text), "%s ordinary effect block lacks its own exact before→after numeric value" % node_id)
			var profile: Dictionary = node.get("effect_profile", {})
			if str(profile.get("effect_key", "")) == "weapon_prefinal_identity_mult":
				var identity_text := str(dossier.get("identity_text", ""))
				_check(identity_text != "" and effect_text.contains("Приём: %s" % identity_text), "%s omits localized weapon identity" % node_id)
				_check(not _has_ascii_letter(identity_text), "%s localized identity leaks ASCII: %s" % [node_id, identity_text])
				_check(not prefinal_identities.has(identity_text), "%s duplicates localized identity used by %s" % [node_id, str(prefinal_identities.get(identity_text, ""))])
				prefinal_identities[identity_text] = node_id
			continue
		var mechanic_id := str(node.get("mechanic_id", ""))
		_check(str(dossier.get("final_callout", "")) == "УНИКАЛЬНЫЙ ФИНАЛ", "%s final callout hierarchy is wrong" % node_id)
		_check(str(dossier.get("mechanic_id", "")) == mechanic_id, "%s dossier mechanic id mismatch" % node_id)
		_check(Formatter.FINAL_MECHANIC_RU.has(mechanic_id), "%s has no localized mechanic copy" % node_id)
		var schema_final: Dictionary = Schema6.mechanic(mechanic_id)
		var params: Dictionary = (schema_final.get("effect_profile", {}) as Dictionary).get("params", {})
		for raw_key in params.keys():
			var key := str(raw_key)
			for token in key.split("_"):
				_check(Formatter.PARAM_WORD_RU.has(token), "%s parameter %s leaks unmapped ASCII token %s" % [node_id, key, token])
			var parameter_title := Formatter._parameter_title(key)
			_check(not parameter_title.contains("_") and not _has_ascii_letter(parameter_title), "%s parameter %s leaks raw key in localized copy: %s" % [node_id, key, parameter_title])
		_check(full_text.contains("Триггер и механика:"), "%s omits trigger/mechanic block" % node_id)
		_check(full_text.contains("Ограничители:"), "%s omits exact caps block" % node_id)
		_check(full_text.contains("Против босса:"), "%s omits boss behavior" % node_id)
		_check(full_text.contains("5/6 → 6/6"), "%s omits final path progress" % node_id)
		_check(full_text.contains("переключателя активации нет"), "%s implies a forbidden activation toggle" % node_id)
		_check(float(node.get("gain_over_order_5_min", 0.0)) >= 1.20, "%s final floor is below 1.20" % node_id)
		_check(full_text.contains("не менее +20%"), "%s does not expose the +20%% floor" % node_id)
		_check(not final_texts.has(full_text), "%s duplicates another final description" % node_id)
		_check(not final_mechanics.has(mechanic_id), "%s duplicates mechanic_id %s" % [node_id, mechanic_id])
		final_texts[full_text] = node_id
		final_mechanics[mechanic_id] = node_id

	_check(final_texts.size() == 51, "expected 51 unique final descriptions, got %d" % final_texts.size())
	_check(final_mechanics.size() == 51, "expected 51 unique final mechanic ids, got %d" % final_mechanics.size())
	_check(prefinal_identities.size() == 51, "expected 51 distinct localized order-5 identity texts, got %d" % prefinal_identities.size())
	_check(Schema6.all_mechanics_by_id().size() == final_mechanics.size(), "runtime manifest/final dossier mechanic parity drift")
	_check_adversarial_fail_closed(class_nodes)

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1091 Atlas descriptions passed 357 exact dossiers, 51 unique finals and >=1.20 floor.")
	quit(0)


func _check_adversarial_fail_closed(class_nodes: Array) -> void:
	var boon := _find_role(class_nodes, "weapon_boon")
	var prefinal := _find_effect(class_nodes, "weapon_prefinal_identity_mult")
	var core := _find_role(class_nodes, "core")
	var final_node := _find_role(class_nodes, "weapon_final")
	_check(not boon.is_empty() and not prefinal.is_empty() and not core.is_empty() and not final_node.is_empty(), "adversarial fixtures could not find core/boon/prefinal/final")
	if boon.is_empty() or prefinal.is_empty() or core.is_empty() or final_node.is_empty():
		return

	var empty_params := boon.duplicate(true)
	var empty_profile: Dictionary = empty_params.get("effect_profile", {})
	empty_profile["params"] = {}
	empty_params["effect_profile"] = empty_profile
	_check(Formatter.build(empty_params).is_empty(), "boon with empty params must fail closed")
	_check_safe_failure_propagation(empty_params, "boon with empty params")

	var wrong_scope := boon.duplicate(true)
	var wrong_scope_profile: Dictionary = wrong_scope.get("effect_profile", {})
	wrong_scope_profile["scope"] = "owning_class"
	wrong_scope["effect_profile"] = wrong_scope_profile
	_check(Formatter.build(wrong_scope).is_empty(), "weapon boon with class-wide scope must fail closed")
	_check_safe_failure_propagation(wrong_scope, "weapon boon with class-wide scope")

	var stale_identity := prefinal.duplicate(true)
	var stale_identity_profile: Dictionary = stale_identity.get("effect_profile", {})
	var stale_identity_params: Dictionary = stale_identity_profile.get("params", {})
	stale_identity_params["identity"] = "manifest identity changed without localization"
	stale_identity_profile["params"] = stale_identity_params
	stale_identity["effect_profile"] = stale_identity_profile
	_check(Formatter.build(stale_identity).is_empty(), "changed order-5 source identity must fail closed")
	_check_safe_failure_propagation(stale_identity, "stale order-5 identity localization")

	var zero_core := core.duplicate(true)
	var zero_core_profile: Dictionary = zero_core.get("effect_profile", {})
	zero_core_profile["params"] = {"attribute": "unknown_attribute", "amount": 0}
	zero_core["effect_profile"] = zero_core_profile
	_check(Formatter.build(zero_core).is_empty(), "core with unknown attribute/zero amount must fail closed")
	_check_safe_failure_propagation(zero_core, "invalid core")

	var missing_final_params := final_node.duplicate(true)
	var missing_final_profile: Dictionary = missing_final_params.get("effect_profile", {})
	missing_final_profile["params"] = {}
	missing_final_params["effect_profile"] = missing_final_profile
	_check(Formatter.build(missing_final_params).is_empty(), "final with empty caps params must fail closed")
	_check_safe_failure_propagation(missing_final_params, "final with empty caps params")

	var weak_final := final_node.duplicate(true)
	weak_final["gain_over_order_5_min"] = 1.19
	_check(Formatter.build(weak_final).is_empty(), "final below 1.20 floor must fail closed")
	_check_safe_failure_propagation(weak_final, "weak final")

	var unknown_param := final_node.duplicate(true)
	var unknown_profile: Dictionary = unknown_param.get("effect_profile", {})
	var unknown_params: Dictionary = unknown_profile.get("params", {})
	unknown_params["unmapped_english_token"] = 1
	unknown_profile["params"] = unknown_params
	unknown_param["effect_profile"] = unknown_profile
	_check(Formatter.build(unknown_param).is_empty(), "final with unmapped parameter token must fail closed")
	_check_safe_failure_propagation(unknown_param, "final with unmapped parameter token")

	var mismatched_caps := final_node.duplicate(true)
	mismatched_caps["caps"] = {"required_hits": 999}
	_check(Formatter.build(mismatched_caps).is_empty(), "final with caps != effect params must fail closed")
	_check_safe_failure_propagation(mismatched_caps, "final with mismatched caps")

	var garbage_value := final_node.duplicate(true)
	var garbage_profile: Dictionary = garbage_value.get("effect_profile", {})
	var garbage_params: Dictionary = garbage_profile.get("params", {})
	garbage_params["required_hits"] = "garbage"
	garbage_profile["params"] = garbage_params
	garbage_value["effect_profile"] = garbage_profile
	garbage_value["caps"] = garbage_params.duplicate(true)
	_check(Formatter.build(garbage_value).is_empty(), "final with non-numeric/non-boolean param must fail closed")
	_check_safe_failure_propagation(garbage_value, "final with garbage param value")

	var identity_only := final_node.duplicate(true)
	var identity_profile: Dictionary = identity_only.get("effect_profile", {})
	identity_profile["params"] = {"identity": 1}
	identity_only["effect_profile"] = identity_profile
	identity_only["caps"] = {"identity": 1}
	_check(Formatter.build(identity_only).is_empty(), "identity-only final params must fail closed")
	_check_safe_failure_propagation(identity_only, "identity-only final")


func _check_safe_failure_propagation(node: Dictionary, context: String) -> void:
	var decorated := Formatter.apply_to_node(node)
	_check(not bool(decorated.get("dossier_valid", true)), "%s must propagate dossier_valid=false" % context)
	_check((decorated.get("dossier", {}) as Dictionary).is_empty(), "%s must propagate an empty dossier" % context)
	_check(str(decorated.get("desc", "")) == Formatter.FAILURE_TEXT, "%s must expose only the explicit safe failure copy" % context)


func _find_role(nodes: Array, role: String) -> Dictionary:
	for raw_node in nodes:
		var node: Dictionary = raw_node
		if str(node.get("role", "")) == role:
			return node
	return {}


func _find_effect(nodes: Array, effect_key: String) -> Dictionary:
	for raw_node in nodes:
		var node: Dictionary = raw_node
		var profile: Dictionary = node.get("effect_profile", {})
		if str(profile.get("effect_key", "")) == effect_key:
			return node
	return {}


func _has_digit(value: String) -> bool:
	for character in value:
		if character >= "0" and character <= "9":
			return true
	return false


func _has_ascii_letter(value: String) -> bool:
	for character in value:
		if (character >= "a" and character <= "z") or (character >= "A" and character <= "Z"):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
