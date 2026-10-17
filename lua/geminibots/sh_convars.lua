--[[
    GeminiBots - ConVars & Settings Synchronization
    Регистрация консольных переменных (ConVars) с флагами FCVAR_ARCHIVE и FCVAR_REPLICATED
    для изменения настроек через консоль и синхронизации с Q-меню.
    FCVAR_NOTIFY специально НЕ используется: иначе каждое изменение (включая
    перестройку Q-меню) рассылается анонсом в чат всем игрокам. Изменения
    видны только в консоли сервера. Плюс свои сохранения в data-файл.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.ConVars = GeminiBots.ConVars or {}

local FCVAR = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED)

-- Таблица определения ConVar'ов: имя, дефолтное значение, описание
local CONVAR_DEFS = {
    -- Основные
    { "geminibots_enabled", "1", "Включить/выключить ИИ ботов GeminiBots (вкл/выкл)" },
    { "geminibots_custom_names", "1", "Уникальные кастомные ники ботов (вкл/выкл)" },
    { "geminibots_preserve_bots", "1", "Сохранять и восстанавливать ботов при смене карты (вкл/выкл)" },
    { "geminibots_debug", "0", "Режим отладки ботов в консоли (вкл/выкл)" },
    { "geminibots_debug_draw", "0", "Отрисовка отладки в мире (траектории гранат, пути) (вкл/выкл)" },

    -- Внешность (Appearance)
    { "geminibots_appearance_enabled", "1", "Случайная внешность ботов при спавне (вкл/выкл)" },
    { "geminibots_appearance_model", "1", "Случайные модели игроков для ботов (вкл/выкл)" },
    { "geminibots_appearance_skin", "1", "Случайные скины моделей (вкл/выкл)" },
    { "geminibots_appearance_bodygroups", "1", "Случайные бодигруппы моделей (вкл/выкл)" },
    { "geminibots_appearance_color", "1", "Случайный цвет игрока (вкл/выкл)" },
    { "geminibots_appearance_respawn", "1", "Менять внешность при каждом возрождении (Вкл = Да, Выкл = Один раз)" },

    -- Экипировка (Loadout)
    { "geminibots_loadout_enabled", "1", "Случайная выдача оружия при спавне (вкл/выкл)" },
    { "geminibots_loadout_min", "1", "Минимальное количество выдаваемых оружий (1-5)" },
    { "geminibots_loadout_max", "3", "Максимальное количество выдаваемых оружий (1-5)" },
    { "geminibots_loadout_strip", "1", "Очищать дефолтное оружие перед выдачей (вкл/выкл)" },
    { "geminibots_loadout_ammo", "180", "Количество выдаваемых патронов для каждого оружия" },
    { "geminibots_loadout_smart", "1", "Умный лоадаут: не более одной гранаты/тактики и минимум один стреляющий ствол (вкл/выкл)" },

    -- Чат (Chat)
    { "geminibots_chat_enabled", "1", "Разрешить ботам писать в чат (вкл/выкл)" },
    { "geminibots_chat_smart_context", "1", "Умный контекст фраз с учетом K/D, читов и серий (вкл/выкл)" },
    { "geminibots_chat_kill_chance", "0.40", "Шанс сообщения в чат после убийства игрока (0-100%)" },
    { "geminibots_chat_death_chance", "0.35", "Шанс сообщения в чат после собственной смерти (0-100%)" },
    { "geminibots_chat_comeback_chance", "0.50", "Шанс ответа бота на обвинение другого бота (0-100%)" },
    { "geminibots_chat_taunt_chance", "0.50", "Шанс боевой насмешки (троллинг аима/нычкотролля, 0.0 - 1.0)" },
    { "geminibots_file_log", "1", "Писать подробный лог в файл data/geminibots/logs/debug.log (вкл/выкл)" },

    -- Сенсорика и зрение (Perception)
    { "geminibots_vision_fov", "110", "Угол обзора ботов в градусах (30 - 180)" },
    { "geminibots_vision_range", "2500", "Максимальная дистанция обнаружения врагов (юниты)" },
    { "geminibots_hearing_range", "700", "Дистанция обнаружения шагов и бега за стенами (юниты)" },
    { "geminibots_gun_hearing_range", "3000", "Дистанция слуха выстрелов по коридорам и сквозь стены (юниты)" },
    { "geminibots_memory_duration", "6.0", "Сколько секунд бот помнит цель за укрытием" },

    -- Цели (Targeting)
    { "geminibots_target_mode", "both", "Режим целей: both / pve / players / npcs" },

    -- Прицеливание и бой (Aim & Combat)
    { "geminibots_reaction_min", "0.15", "Минимальная задержка реакции перед огнем (сек)" },
    { "geminibots_reaction_max", "0.35", "Максимальная задержка реакции перед огнем (сек)" },
    { "geminibots_aim_speed", "360", "Скорость доводки прицела (градусов в секунду)" },
    { "geminibots_aim_smoothing", "0.25", "Плавность наведения прицела (0.05 - 1.0)" },
    { "geminibots_aim_prediction", "1", "Упреждение движения цели при стрельбе (вкл/выкл)" },
    { "geminibots_aim_spread", "1.8", "Разброс/ошибка прицеливания ботов в градусах (0.0 - 5.0)" },
    { "geminibots_aim_headshot_chance", "0.35", "Вероятность целиться в голову (0-100%)" },
    { "geminibots_combat_min_dist", "250", "Минимальная дистанция боя перед отходом назад" },
    { "geminibots_combat_max_dist", "900", "Максимальная дистанция боя перед сближением" },
    { "geminibots_flee_health", "0.25", "Порог здоровья для отступления (0.0 - 0.8)" },
    { "geminibots_wallbang", "1", "Прострел стекла/хрупкого по свежему следу (вкл/выкл)" },
    { "geminibots_c4_enabled", "1", "Боты ставят и разминируют C4 от SWCS (вкл/выкл)" },
    -- SWCS-реакции (декой/огонь; флешка действует всегда, пока стоит SWCS)
    { "geminibots_swcs_decoy_chance", "0.40", "Шанс пойти проверять звук декоя SWCS (0-100%)" },
    { "geminibots_swcs_fire_avoid", "1", "Отходить от огня молика/зажигательной SWCS (вкл/выкл)" },
    { "geminibots_swcs_fire_radius", "320", "Дистанция реакции на огонь SWCS (юниты)" },
    -- Передвижение (Movement)
    { "geminibots_bhop_enabled", "1", "Баннихоп ботов на ходу (вкл/выкл)" },
    { "geminibots_bhop_chance", "0.85", "Шанс прыжка на каждое приземление (0-100%)" },

    -- Состояния FSM
    { "geminibots_disabled_states", "", "Выключенные состояния FSM через запятую (напр. flee,investigate)" }
}

-- Регистрация всех ConVar'ов
for _, def in ipairs(CONVAR_DEFS) do
    local cvar = CreateConVar(def[1], def[2], FCVAR, def[3])
    GeminiBots.ConVars[def[1]] = cvar
end

-- Описания для тултипов в меню (русские, из таблицы выше)
GeminiBots.ConVarDescs = GeminiBots.ConVarDescs or {}
for _, def in ipairs(CONVAR_DEFS) do
    GeminiBots.ConVarDescs[def[1]] = def[3]
end

-- Синхронизация значений ConVar'ов в таблицу GeminiBots.Config на сервере
function GeminiBots:SyncConfigFromConVars()
    if not self.Config then return end

    local cfg = self.Config

    cfg.Enabled = GetConVar("geminibots_enabled"):GetBool()
    cfg.CustomNames = GetConVar("geminibots_custom_names") and GetConVar("geminibots_custom_names"):GetBool() or true
    cfg.PreserveBots = GetConVar("geminibots_preserve_bots") and GetConVar("geminibots_preserve_bots"):GetBool() or true
    cfg.Debug = GetConVar("geminibots_debug"):GetBool()
    cfg.DebugDraw = GetConVar("geminibots_debug_draw"):GetBool()

    if cfg.Appearance then
        cfg.Appearance.Enabled = GetConVar("geminibots_appearance_enabled"):GetBool()
        cfg.Appearance.RandomModel = GetConVar("geminibots_appearance_model"):GetBool()
        cfg.Appearance.RandomSkin = GetConVar("geminibots_appearance_skin"):GetBool()
        cfg.Appearance.RandomBodygroups = GetConVar("geminibots_appearance_bodygroups"):GetBool()
        cfg.Appearance.RandomColor = GetConVar("geminibots_appearance_color"):GetBool()
        cfg.Appearance.ChangeOnRespawn = GetConVar("geminibots_appearance_respawn"):GetBool()
    end

    if cfg.Loadout then
        cfg.Loadout.Enabled = GetConVar("geminibots_loadout_enabled"):GetBool()
        cfg.Loadout.MinWeapons = math.Clamp(GetConVar("geminibots_loadout_min"):GetInt(), 1, 10)
        cfg.Loadout.MaxWeapons = math.Clamp(GetConVar("geminibots_loadout_max"):GetInt(), cfg.Loadout.MinWeapons, 10)
        cfg.Loadout.StripDefaultWeapons = GetConVar("geminibots_loadout_strip"):GetBool()
        cfg.Loadout.AmmoAmount = GetConVar("geminibots_loadout_ammo"):GetInt()
        cfg.Loadout.SmartLoadout = GetConVar("geminibots_loadout_smart"):GetBool()
    end

    if cfg.Chat then
        cfg.Chat.Enabled = GetConVar("geminibots_chat_enabled"):GetBool()
        cfg.Chat.SmartContext = GetConVar("geminibots_chat_smart_context"):GetBool()
        cfg.Chat.KillChance = math.Clamp(GetConVar("geminibots_chat_kill_chance"):GetFloat(), 0.0, 1.0)
        cfg.Chat.DeathChance = math.Clamp(GetConVar("geminibots_chat_death_chance"):GetFloat(), 0.0, 1.0)
        cfg.Chat.ComebackChance = math.Clamp(GetConVar("geminibots_chat_comeback_chance"):GetFloat(), 0.0, 1.0)
        cfg.Chat.TauntChance = math.Clamp(GetConVar("geminibots_chat_taunt_chance"):GetFloat(), 0.0, 1.0)
    end

    cfg.VisionFOV = GetConVar("geminibots_vision_fov"):GetFloat()
    cfg.VisionRange = GetConVar("geminibots_vision_range"):GetFloat()
    cfg.HearingRange = GetConVar("geminibots_hearing_range"):GetFloat()
    cfg.GunHearingRange = GetConVar("geminibots_gun_hearing_range") and GetConVar("geminibots_gun_hearing_range"):GetFloat() or 3000
    cfg.MemoryDuration = GetConVar("geminibots_memory_duration"):GetFloat()

    if cfg.Targeting then
        local mode = string.lower(GetConVar("geminibots_target_mode"):GetString())
        if mode ~= "both" and mode ~= "pve" and mode ~= "players" and mode ~= "npcs" then
            mode = "both"
        end
        cfg.Targeting.Mode = mode
    end

    cfg.ReactionTimeMin = GetConVar("geminibots_reaction_min"):GetFloat()
    cfg.ReactionTimeMax = GetConVar("geminibots_reaction_max"):GetFloat()

    cfg.AimSpeed = GetConVar("geminibots_aim_speed"):GetFloat()
    cfg.AimSmoothing = GetConVar("geminibots_aim_smoothing"):GetFloat()
    cfg.AimPrediction = GetConVar("geminibots_aim_prediction"):GetBool()
    cfg.AimSpread = GetConVar("geminibots_aim_spread"):GetFloat()
    cfg.HeadshotChance = GetConVar("geminibots_aim_headshot_chance"):GetFloat()

    cfg.CombatMinDistance = GetConVar("geminibots_combat_min_dist"):GetFloat()
    cfg.CombatMaxDistance = GetConVar("geminibots_combat_max_dist"):GetFloat()
    cfg.FleeHealthThreshold = GetConVar("geminibots_flee_health"):GetFloat()
    cfg.WallbangEnabled = GetConVar("geminibots_wallbang"):GetBool()
    cfg.C4Enabled = GetConVar("geminibots_c4_enabled"):GetBool()

    cfg.SWCS = cfg.SWCS or {}
    cfg.SWCS.DecoyChance = math.Clamp(GetConVar("geminibots_swcs_decoy_chance"):GetFloat(), 0.0, 1.0)
    cfg.SWCS.FireAvoid = GetConVar("geminibots_swcs_fire_avoid"):GetBool()
    cfg.SWCS.FireRadius = math.Clamp(GetConVar("geminibots_swcs_fire_radius"):GetFloat(), 100, 1200)

    if cfg.BunnyHop then
        cfg.BunnyHop.Enabled = GetConVar("geminibots_bhop_enabled"):GetBool()
        cfg.BunnyHop.Chance = math.Clamp(GetConVar("geminibots_bhop_chance"):GetFloat(), 0.0, 1.0)
    end

    -- Выключенные состояния: строка "flee, investigate" -> множество
    cfg.DisabledStates = {}
    for name in string.gmatch(string.lower(GetConVar("geminibots_disabled_states"):GetString() or ""), "[a-z_]+") do
        cfg.DisabledStates[name] = true
    end
end

--------------------------------------------------------------------------------
-- Свои сохранения настроек (data/geminibots/convars.json)
-- Живут отдельно от config.cfg и применяются без анонсов в чат.
--------------------------------------------------------------------------------
local PERSIST_FILE = "geminibots/convars.json"
local persistScheduled = false

local function WritePersistedConVars()
    persistScheduled = false
    if GeminiBots.SuppressPersist then return end -- режимные значения не сохраняем
    local data = {}
    for _, def in ipairs(CONVAR_DEFS) do
        local cv = GetConVar(def[1])
        if cv then data[def[1]] = cv:GetString() end
    end
    if not file.IsDir("geminibots", "DATA") then
        file.CreateDir("geminibots")
    end
    file.Write(PERSIST_FILE, util.TableToJSON(data, true))
end

-- Сохранение с задержкой 2 сек, чтобы не писать файл на каждый тик слайдера
function GeminiBots:ScheduleConVarsSave()
    if not SERVER then return end
    if self.SuppressPersist then return end -- режим владеет конфигом
    if persistScheduled then return end
    persistScheduled = true
    timer.Simple(2.0, function()
        if persistScheduled then WritePersistedConVars() end
    end)
end

function GeminiBots:SaveConVarsNow()
    if not SERVER then return end
    WritePersistedConVars()
end

-- Загрузка сохранений при старте (тихо, только в консоль сервера)
function GeminiBots:LoadPersistedConVars()
    if not SERVER then return end
    if not file.Exists(PERSIST_FILE, "DATA") then return end

    local data = util.JSONToTable(file.Read(PERSIST_FILE, "DATA") or "")
    if not istable(data) then return end

    local applied = 0
    for _, def in ipairs(CONVAR_DEFS) do
        local val = data[def[1]]
        if val ~= nil then
            RunConsoleCommand(def[1], tostring(val))
            applied = applied + 1
        end
    end

    if applied > 0 then
        self:Log("Загружены сохраненные настройки (%d) из data/%s", applied, PERSIST_FILE)
    end
end

if SERVER then
    hook.Add("ShutDown", "GeminiBots_SaveConVars", function()
        WritePersistedConVars()
    end)
end

-- Команда-переключатель отрисовки отладки (траектории гранат, пути)
concommand.Add("geminibots_debug_draw_toggle", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    if SERVER then
        local cv = GetConVar("geminibots_debug_draw")
        if not cv then return end
        local newVal = not cv:GetBool()
        RunConsoleCommand("geminibots_debug_draw", newVal and "1" or "0")
        if GeminiBots.SyncConfigFromConVars then
            GeminiBots:SyncConfigFromConVars()
        end
        local state = newVal and "ВКЛ / ON" or "ВЫКЛ / OFF"
        local msg = "[GeminiBots] Отрисовка отладки (траектории): " .. state
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end
end, nil, "Вкл/выкл отрисовку отладки (траектории гранат) с подтверждением")

-- Команда для сброса всех настроек к дефолтным значениям
concommand.Add("geminibots_reset_defaults", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    for _, def in ipairs(CONVAR_DEFS) do
        RunConsoleCommand(def[1], def[2])
    end
    if GeminiBots.SyncConfigFromConVars then
        GeminiBots:SyncConfigFromConVars()
    end
    print("[GeminiBots] Все настройки сброшены к значениям по умолчанию / All settings reset to default.")
end, nil, "Сбросить все параметры GeminiBots по умолчанию")

-- Применяем коллбэки на изменение ConVar'ов для мгновенной синхронизации на сервере
if SERVER then
    for _, def in ipairs(CONVAR_DEFS) do
        cvars.AddChangeCallback(def[1], function(name, oldVal, newVal)
            if GeminiBots.SyncConfigFromConVars then
                GeminiBots:SyncConfigFromConVars()
            end
            GeminiBots:ScheduleConVarsSave()
        end, "GeminiBots_Sync_" .. def[1])
    end

    -- Первичная синхронизация при запуске + загрузка своих сохранений
    GeminiBots:SyncConfigFromConVars()
    GeminiBots:LoadPersistedConVars()
    GeminiBots:SyncConfigFromConVars()
end
