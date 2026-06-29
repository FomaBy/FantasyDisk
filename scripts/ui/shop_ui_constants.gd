class_name ShopUIConstants
extends RefCounted

const ARTIFACT_ICON_DIR := "res://assets/sprites/ui/icons/artifacts/"
const SHOP_ICON_DIR := "res://assets/sprites/ui/icons/shop/"
const SHOP_SLOT_FRAME_PATH := "res://assets/sprites/ui/shop/ui_shop_artifact_slot_frame.png"
const SHOP_SLOT_HOVER_PATH := "res://assets/sprites/ui/shop/ui_shop_artifact_slot_hover.png"
const SHOP_PRICE_BADGE_PATH := "res://assets/sprites/ui/shop/ui_shop_price_badge.png"
const SHOP_PURCHASED_OVERLAY_PATH := "res://assets/sprites/ui/shop/ui_shop_purchased_overlay.png"
const SHOP_TOOLTIP_FRAME_PATH := "res://assets/sprites/ui/shop/ui_shop_tooltip_frame.png"
# SCRUM-567: 9-slice плашка-нейм-плейт под подпись названия товара (источник
# 1728×624, бордюр ~150px → tex-margins; центр-парчмент тянется без растяжения
# орнамента).
const SHOP_CAPTION_PLATE_PATH := "res://assets/sprites/ui/shop/ui_shop_caption_plate.png"
const SHOP_CAPTION_PLATE_MARGINS := Vector4(150.0, 150.0, 150.0, 150.0)
const SHOP_INLINE_SLOT_SIZE := Vector2(148, 148)
# SCRUM-567: иконка ужата с 82 до 64, чтобы в слот 148px влезли подпись названия
# (верх) + иконка + ценник (низ) без наслоения.
const SHOP_INLINE_ICON_SIZE := Vector2(64, 64)
# SCRUM-567: фикс-размерная подпись названия товара В ВЕРХНЕЙ полосе слота (внутри
# 148×148 — text-control обязан помещаться в родителя-кнопку, рендер-верификатор
# это проверяет). Текст ужимается clip до 1 строки; длинные имена не растягивают
# карточку. Иконка сдвинута вниз под подпись (см. SHOP_INLINE_ICON_TOP).
const SHOP_INLINE_CAPTION_SIZE := Vector2(140, 20)
const SHOP_INLINE_CAPTION_TOP := 4.0
const SHOP_INLINE_ICON_TOP := 26.0
const SHOP_CURSOR_VARIANTS := {
	"arrow": "res://assets/sprites/ui/cursor/game_cursor.png",
	"pointing_hand": "res://assets/sprites/ui/cursor/game_cursor_hover.png",
	"cross": "res://assets/sprites/ui/cursor/game_cursor_attack.png",
}
