# Конфиг: конвары и команды

Все `geminibots_*`-конвары серверные (архивируются, реплицируются, без анонсов в чат). Хранятся в `data/geminibots/convars.json`, переживают рестарт. Значения применяются после смены карты.

## Основные

| Конвар | Дефолт | Что делает |
|---|---|---|
| `geminibots_enabled` | 1 | ИИ ботов вкл/выкл |
| `geminibots_custom_names` | 1 | Уникальные ники вместо Bot01… (пул — `data/geminibots/names.txt`, свой ник на строку, `#` — коммент; не хватило — добавится `_2`, `_3`). Ник выдается сразу в движке при спавне — виден везде (табы, киллфид, сторонние overlay) |
| `geminibots_preserve_bots` | 1 | Перенос ботов с никами при смене карты (`data/geminibots/saved_session.json`, старше 10 минут — не восстанавливаем) |
| `geminibots_debug` | 0 | Лог отладки в консоль |
| `geminibots_debug_draw` | 0 | Отрисовка в мире (дуги гранат, пути) |

## Внешность

`geminibots_appearance_enabled` (1), `_model`/`_skin`/`_bodygroups`/`_color` (1), `_respawn` (1 — менять при каждом возрождении, 0 — один раз).

## Экипировка

`geminibots_loadout_enabled` (1), `_min` (1, 1–5), `_max` (3, 1–5), `_strip` (1 — отобрать тулы песочницы), `_ammo` (180 запасных патронов).

## Чат

`geminibots_chat_enabled` (1), `_smart_context` (1), `_kill_chance` (0.40), `_death_chance` (0.35), `_comeback_chance` (0.50), `_taunt_chance` (0.50 — у насмешек свой ролл, нули остальных шансов тишину не дают), `geminibots_file_log` (1 — `data/geminibots/logs/debug.log`).

## Сенсорика и цели

`geminibots_vision_fov` (110, 30–180), `_vision_range` (2500, 500–6000), `_hearing_range` (700, 100–2000), `_gun_hearing_range` (3000, 500–6000), `_memory_duration` (6.0 сек), `geminibots_target_mode` (`both` / `pve` / `players` / `npcs`).

## Бой

`geminibots_reaction_min` (0.15) / `_max` (0.35), `_aim_speed` (360), `_aim_smoothing` (0.25), `_aim_prediction` (1), `_aim_spread` (1.8), `_aim_headshot_chance` (0.35), `_combat_min_dist` (250), `_combat_max_dist` (900), `_flee_health` (0.25), `_wallbang` (1), `_c4_enabled` (1), `_swcs_decoy_chance` (0.40), `_swcs_fire_avoid` (1), `_swcs_fire_radius` (320), `_bhop_enabled` (1), `_bhop_chance` (0.85).

## FSM и читеры

- `geminibots_disabled_states` — состояния через запятую (`flee,investigate`), вместо них бот уходит в `idle`.
- `geminibots_cheater <easy|normal|hard|expert>` — бот-читер (админ; не в Murder). `easy` (легит, волхак), `normal` (аим), `hard` (волхак + всегда в голову), `expert` (все + спинбот). В ESP — строка `ЧИТЕР: тир`.

## Пресеты сложности

`geminibots_skill_preset <имя>` (`easy`, `normal`, `hard`, `expert` или свой), `_save`, `_delete`, `_list`. Встроенные: Легко (реакция 0.5–0.9, разброс 3.5), Норма (0.15–0.35 / 1.8), Сложно (0.08–0.18 / 0.9), Эксперт (0.03–0.08 / 0.4). Свои — слепок текущих настроек в `data/geminibots/skill_presets.json`.

## Команды

- Боты: `geminibots_add`, `geminibots_spawn_max` (= `geminibots_fill`), `geminibots_kick_all`, `geminibots_reload`, `geminibots_save_bots`, `geminibots_restore_bots`.
- Оружие: `geminibots_weapon_list`, `_toggle <класс>`, `_add`, `_remove`, `_preset <hl2|m9k|all|none|pistols|rifles|shotguns|snipers|default>`, `_reload`, `_scan`, `_prune`, `_clear_broken`, `geminibots_weapons_menu`, `geminibots_weapon_dump`, `geminibots_pack_list`.
- Ники/вид: `geminibots_names_reroll`, `geminibots_names_reload`, `geminibots_appearance_reroll`.
- Админ: `geminibots_bring [ник|*]`, `geminibots_goto <ник>`, `geminibots_bot_info [ник]`, `geminibots_esp`, `geminibots_debug_draw_toggle`, `geminibots_reset_defaults` (сброс конваров).
- Чат-паки: `geminibots_chat_pack_list`, `_toggle <файл>`, `_reload_packs`, `_delete`, `_restore`.
- FSM: `geminibots_states_list`, `geminibots_states_reload`, `geminibots_bot_state <ник> <состояние>`.
- ULX (если стоит): `!bringbots`, `!gotobot <ник>`, `!addbot [N]`, `!kickbots`, `!botinfo [ник]`, `!botpreset <имя>`, `!botstate <ник> <состояние>`.
