class_name CombatFairness
extends Object

## Combat Feel Rework, этап C: единый математический пол «честного замаха»
## (windup) для всех АОЕ/телеграфов против игрока.
##
## Принцип: у героя ВСЕГДА должно хватать времени на реакцию + пробег до
## безопасной точки ДО детонации зоны. Ascension-множители могут сжимать замах,
## только пока он ВЫШЕ пола — пробить пол они не могут.
##
## Семантика escape_distance (документируется здесь, применяется на кол-сайтах):
##   • круг с центром НА игроке (зона кастуется в его позицию) → полный radius;
##   • круг с центром на боссе/кастере → radius * CASTER_CENTERED_ESCAPE_RATIO
##     (герой почти никогда не стоит в самом центре туши босса);
##   • кольцо зон с безопасным проходом → ширина пробега до прохода (на практике
##     зоны кольца смещены от игрока и покрываются offset-семантикой ниже);
##   • смещённая зона → max(0, radius − дистанция игрока до центра)
##     (см. circle_escape_distance);
##   • направленный луч/конус → боковой выход: полуширина полосы + запас.

const REACTION_FLOOR := 0.4        # человеческая реакция, s
const ESCAPE_SPEED_REF := 250.0    # опорная скорость пробега, px/s (классы 222–292)
const ABS_MIN_WINDUP := 0.55       # абсолютный минимум замаха любой зоны, s
const SLOW_COMP_CAP := 1.8         # кап компенсации замедлений игрока
const CASTER_CENTERED_ESCAPE_RATIO := 0.6  # эвристика зон с центром на кастере


## Честный замах: max(база×ascension, (реакция + пробег/скорость)×slow_comp, минимум).
## slow_comp = base_speed/current_speed игрока (паутина/слоу растягивают окно),
## кап SLOW_COMP_CAP; берётся с player, если тот отдаёт escape_speed()/
## base_escape_speed() (player.gd), иначе 1.0 (стабильно для тестов/стабов).
static func fair_windup(base: float, escape_distance: float, asc_mult := 1.0, player: Node = null) -> float:
	var slow_comp := 1.0
	if player != null and is_instance_valid(player) \
			and player.has_method("escape_speed") and player.has_method("base_escape_speed"):
		var current := float(player.call("escape_speed"))
		var base_speed := float(player.call("base_escape_speed"))
		if current > 0.01 and base_speed > 0.01:
			slow_comp = clampf(base_speed / current, 1.0, SLOW_COMP_CAP)
	var floor_windup := (REACTION_FLOOR + maxf(escape_distance, 0.0) / ESCAPE_SPEED_REF) * slow_comp
	return maxf(maxf(base * asc_mult, floor_windup), ABS_MIN_WINDUP)


## Дистанция побега для круговой зоны по ЖИВОЙ позиции игрока на момент каста:
## центр на игроке → полный радиус; смещённая зона → radius − dist (не ниже 0);
## игрок уже снаружи → 0 (REACTION_FLOOR/ABS_MIN_WINDUP всё равно держат окно).
## После каста зона НЕ следит за игроком — снапшот честен по построению.
static func circle_escape_distance(center: Vector2, radius: float, player: Node) -> float:
	var p := player as Node2D
	if p == null or not is_instance_valid(p):
		return radius
	return clampf(radius - p.global_position.distance_to(center), 0.0, radius)
