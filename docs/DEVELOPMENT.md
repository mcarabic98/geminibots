# Разработка: структура, FSM, деплой

## Дерево (коротко)

```text
lua/
├── autorun/server/sv_geminibots_loader.lua  -- порядок загрузки
├── autorun/client/cl_geminibots_loader.lua
└── geminibots/
    ├── sh_config.lua, sh_convars.lua, sh_bot_names.lua, sh_skill_presets.lua
    ├── client/  cl_settings.lua (окно), cl_qmenu.lua (кнопка в Q),
    │            cl_theme.lua, cl_icons.lua, cl_arsenal.lua, cl_esp.lua,
    │            cl_trajectory.lua, cl_avatars.lua, cl_navwarn.lua
    └── server/
        ├── core/        менеджер, лодаут, скилл, внешность, админ, ESP,
        │               команды, имена, логгер
        ├── chat/        паки, чат, дуэли
        ├── navigation/  навмеш (A*), навигатор
        ├── perception/  зрение/слух, память, NPC-адаптеры (+npcs/)
        ├── combat/      прицел, селектор, подбор (scavenger), бой,
        │               адаптеры (+packs/), читеры
        ├── compat/      murder, hl2mp, swcs, c4
        └── brain/       FSM, кастомные состояния, states/:
                        idle, wander, combat, flee, investigate, plant, defuse
```

## Свои FSM-состояния (способ для пользователей)

Файл-возврат таблицы в `data/geminibots/states/<имя>.lua` (пример `_example.lua` создается сам, файлы с `_` не грузятся):

```lua
local State = {}
function State:Enter(bot) end
function State:Update(bot, dt)
    -- GeminiBots.FSM:SetState(bot, "combat")
end
function State:Exit(bot) end
return State
```

Имя встроенного состояния его перекроет. Тумблеры — раздел «Состояния FSM» в админке (выкл = уход в `idle`, сам `idle` заблокирован), конвар `geminibots_disabled_states`. Команды: `geminibots_states_list`, `_reload`, `geminibots_bot_state <ник> <состояние>`.

Правка `stateFiles` в загрузчике — способ для разработчиков (состояния из кода аддона).

## Деплой и Lua

`deploy_to_gmod.bat` зеркалит проект в `addons/geminibots` (`robocopy /MIR`, папка `tools/` и мусор не копируются). Путь установки переопределяется переменной окружения `GEMINIBOTS_GMOD_ADDON`. Серверный и клиентский Lua применяется после смены карты. `data/*.txt` создаются, только если отсутствуют. Заметки по движку, выстраданные кодом: Lua-паттерны без `|`; `file.Append` молча не пишет (логгер через Read+Write); `SetBool` реплицированных конваров на клиенте падает (писать через `RunConsoleCommand`); `net.WriteTable` переполняется на больших паках (чанки); поле порядка ESP сервер↔клиент обязано совпадать.

## Перфоманс

Трейсы — главная валюта: конус зрения считается до LOS, LOS кэшируется на тик, гейт наводки — только в тики выстрела, сканы ботов рассинхронизированы джиттером, трейс приседа — каждый 3-й тик, списки NPC/стволов — кэши на 1–2 сек.

## Проверка синтаксиса

Стоковый Lua 5.1 (берется с lua.org, нужны `lua`/`luac`): `continue` из GLua гасится предобработкой, скрипт лежит в репозитории:
```console
lua tools/check_syntax.lua
```
(аргументом можно дать другой путь к `lua/`). `ALL OK (N files)` — можно деплоить. Ошибка парсинга вида `'=' expected near 'end'` на строке с `continue` — ложная (стоковый 5.1 его не знает).
