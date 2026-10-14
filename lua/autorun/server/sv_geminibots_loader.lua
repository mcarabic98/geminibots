--[[
    GeminiBots - Main Server Loader
    Автоматическая загрузка компонентов и инициализация структуры.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Version = "1.0.0"

local PREFIX = "[GeminiBots] "

function GeminiBots:Log(msg, ...)
    MsgC(Color(100, 200, 255), PREFIX, Color(220, 220, 220), string.format(tostring(msg), ...), "\n")
end

function GeminiBots:Warn(msg, ...)
    MsgC(Color(255, 180, 50), PREFIX .. "[WARN] ", Color(240, 220, 180), string.format(tostring(msg), ...), "\n")
end

function GeminiBots:Debug(msg, ...)
    if not self.Config or not self.Config.Debug then return end
    MsgC(Color(180, 120, 255), PREFIX .. "[DEBUG] ", Color(210, 210, 210), string.format(tostring(msg), ...), "\n")
end

-- Безопасное подключение серверного файла
local function SafeIncludeServer(path)
    if file.Exists(path, "LUA") then
        include(path)
        GeminiBots:Debug("Загружен модуль: %s", path)
        return true
    else
        GeminiBots:Warn("Файл модуля не найден: %s", path)
        return false
    end
end

-- Безопасное подключение shared-файла (сервер + клиент)
local function SafeIncludeShared(path)
    AddCSLuaFile(path)
    if file.Exists(path, "LUA") then
        include(path)
        GeminiBots:Debug("Загружен shared-модуль: %s", path)
        return true
    else
        GeminiBots:Warn("Shared-файл не найден: %s", path)
        return false
    end
end

-- Безопасное подключение клиентского файла
local function SafeIncludeClient(path)
    AddCSLuaFile(path)
    if CLIENT then
        include(path)
    end
end

-- 1. Загрузка конфигурации и ConVars (сервер + клиент)
SafeIncludeShared("geminibots/sh_config.lua")
SafeIncludeShared("geminibots/sh_convars.lua")
SafeIncludeShared("geminibots/sh_bot_names.lua")
SafeIncludeShared("geminibots/sh_skill_presets.lua")

-- Клиентский интерфейс (Q-меню настройки)
SafeIncludeClient("geminibots/client/cl_qmenu.lua")
SafeIncludeClient("geminibots/client/cl_theme.lua")
SafeIncludeClient("geminibots/client/cl_icons.lua")
SafeIncludeClient("geminibots/client/cl_arsenal.lua")
SafeIncludeClient("geminibots/client/cl_trajectory.lua")
SafeIncludeClient("geminibots/client/cl_esp.lua")
SafeIncludeClient("geminibots/client/cl_avatars.lua")
SafeIncludeClient("geminibots/client/cl_settings.lua")
SafeIncludeClient("geminibots/client/cl_navwarn.lua")
AddCSLuaFile("autorun/client/cl_geminibots_loader.lua")

-- 2. Ядро (Core)
SafeIncludeServer("geminibots/server/core/sv_logger.lua")
SafeIncludeServer("geminibots/server/core/sv_bot_names.lua")
SafeIncludeServer("geminibots/server/core/sv_appearance.lua")
SafeIncludeServer("geminibots/server/core/sv_skill.lua")
SafeIncludeServer("geminibots/server/core/sv_bot_manager.lua")
SafeIncludeServer("geminibots/server/core/sv_admin.lua")
SafeIncludeServer("geminibots/server/core/sv_esp.lua")
SafeIncludeServer("geminibots/server/core/sv_cmd_controller.lua")
SafeIncludeServer("geminibots/server/core/sv_loadout.lua")

-- 3. Чат и реакции (Chat)
SafeIncludeServer("geminibots/server/chat/sv_chat_packs.lua")
SafeIncludeServer("geminibots/server/chat/sv_chat.lua")
SafeIncludeServer("geminibots/server/chat/sv_duel.lua")

-- 4. Навигация (Navigation)
SafeIncludeServer("geminibots/server/navigation/sv_navmesh.lua")
SafeIncludeServer("geminibots/server/navigation/sv_navigator.lua")

-- 5. Восприятие и память (Perception)
SafeIncludeServer("geminibots/server/perception/sv_npc_adapters.lua")
SafeIncludeServer("geminibots/server/perception/npcs/npc_vj.lua")
SafeIncludeServer("geminibots/server/perception/npcs/npc_drg.lua")
SafeIncludeServer("geminibots/server/perception/sv_vision.lua")
SafeIncludeServer("geminibots/server/perception/sv_memory.lua")

-- 6. Боевая система (Combat)
SafeIncludeServer("geminibots/server/combat/sv_aiming.lua")
SafeIncludeServer("geminibots/server/combat/sv_weapon_adapters.lua")
SafeIncludeServer("geminibots/server/combat/packs/wp_generic.lua")
SafeIncludeServer("geminibots/server/combat/packs/wp_swcs.lua")
SafeIncludeServer("geminibots/server/combat/packs/wp_murder.lua")
SafeIncludeServer("geminibots/server/combat/sv_weapon_selector.lua")
SafeIncludeServer("geminibots/server/combat/sv_scavenger.lua")
SafeIncludeServer("geminibots/server/combat/sv_combat.lua")
SafeIncludeServer("geminibots/server/brain/sv_cheater.lua")

-- 7. Мозг и конечный автомат (Brain & FSM)
SafeIncludeServer("geminibots/server/brain/sv_fsm.lua")

-- 8. Состояния поведения (States)
local stateFiles = {
    "geminibots/server/brain/states/sv_state_idle.lua",
    "geminibots/server/brain/states/sv_state_wander.lua",
    "geminibots/server/brain/states/sv_state_combat.lua",
    "geminibots/server/brain/states/sv_state_flee.lua",
    "geminibots/server/brain/states/sv_state_investigate.lua",
    "geminibots/server/brain/states/sv_state_plant.lua",
    "geminibots/server/brain/states/sv_state_defuse.lua"
}

for _, statePath in ipairs(stateFiles) do
    SafeIncludeServer(statePath)
end

-- Кастомные состояния из data (после встроенных, могут их перекрывать)
SafeIncludeServer("geminibots/server/brain/sv_states_custom.lua")

-- 9. Совместимость с режимами (тихо спит, если режим не тот)
SafeIncludeServer("geminibots/server/compat/sv_murder.lua")
SafeIncludeServer("geminibots/server/compat/sv_hl2mp.lua")
SafeIncludeServer("geminibots/server/compat/sv_swcs.lua")
SafeIncludeServer("geminibots/server/compat/sv_c4.lua")

GeminiBots:Log("Аддон успешно инициализирован (Версия: %s)", GeminiBots.Version)
