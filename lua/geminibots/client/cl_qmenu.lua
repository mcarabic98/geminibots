--[[
    GeminiBots - Q Menu (Spawnmenu) Settings Panel
    Вкладка настроек в Q-меню (Utilities/Options -> GeminiBots) с двуязычной поддержкой (RU / EN)
    и управлением отдельными .txt файлами чата.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Lang = GeminiBots.Lang or {}
GeminiBots.CachedPacks = GeminiBots.CachedPacks or {}
GeminiBots.CachedAdapters = GeminiBots.CachedAdapters or {}
GeminiBots.CachedStates = GeminiBots.CachedStates or {}
GeminiBots.CachedSkillPresets = GeminiBots.CachedSkillPresets or {}

local currentSettingsPanel = nil
local currentOpts = nil

-- Локализация: Русский и Английский языки
local PHRASES = {
    ru = {
        MenuTitle = "GeminiBots - Управление ботами",
        MenuDesc = "Настройка искусственного интеллекта стандартных ботов в реальном времени.",

        LangButton = "Язык: РУССКИЙ (клик: авто -> RU -> EN)",

        -- Секция 1
        HeaderGeneral = "Основные параметры",
        Enabled = "Включить ИИ ботов",
        CustomNames = "Уникальные кастомные ники ботов",
        PreserveBots = "Восстанавливать ботов при смене карты",
        HeaderAppearance = "Внешность",
        Appearance = "Случайная внешность ботов (модели/скины)",
        AppearanceModel = "Случайные модели игроков",
        AppearanceSkin = "Случайные скины моделей",
        AppearanceBodygroups = "Случайные бодигруппы",
        AppearanceColor = "Случайный цвет игрока",
        AppearanceRespawn = "Менять внешность при каждом возрождении",
        Debug = "Режим отладки (вывод в консоль)",
        DebugDraw = "Отрисовка отладки в мире (траектории, пути)",

        -- Секция 2
        HeaderLoadout = "Выбор оружия ботов (Loadout & SWEPs)",
        LoadoutEnabled = "Выдавать случайное оружие при спавне",
        LoadoutStrip = "Очищать дефолтные тулы (Sandbox)",
        LoadoutMin = "Мин. количество пушек",
        LoadoutMax = "Макс. количество пушек",
        LoadoutAmmo = "Количество запасных патронов",
        PresetHeader = "--- Быстрые пресеты пула оружия ---",
        PresetAll = "Включить ВСЁ оружие",
        PresetHL2 = "Только стандартные HL2",
        PresetM9K = "Все M9K (сканировать сервер)",
        PresetPistols = "Только пистолеты",
        PresetRifles = "Только автоматы и ПП",
        PresetShotguns = "Только дробовики",
        PresetSnipers = "Только снайперки",
        PresetNone = "Отключить всё",
        WeaponListHeader = "--- Список оружия в пуле (Отметьте нужные) ---",
        WeaponNotInstalled = " [НЕ УСТАНОВЛЕНО НА СЕРВЕРЕ]",
        AddWeaponHelp = "Добавить оружие по имени класса (напр. m9k_vector):",
        BtnAddWeapon = "Добавить оружие в пул (+)",
        BtnAddHeldWeapon = "Взять пушку из рук и добавить в пул ботов",
        BtnGiveHeldWeapon = "Мгновенно выдать пушку из рук всем ботам",
        BtnReloadWeapons = "Перезагрузить weapons.txt с диска",
        BtnOpenArsenal = "ОТКРЫТЬ АРСЕНАЛ: скан + поиск + фильтры",
        WPackHeader = "--- Оружейные паки (адаптеры тактики) ---",
        WPackFound = "найден",
        WPackMissing = "нет на сервере",
        C4Enabled = "Боты ставят и разминируют C4 (нужен SWCS)",

        -- Секция 3
        HeaderChat = "Чат и реакции ботов",
        ChatEnabled = "Разрешить ботам общаться в чате",
        SmartContext = "Умный контекст фраз (учет K/D, стриков и читов)",
        ChatKillChance = "Шанс насмешки после фрага",
        ChatDeathChance = "Шанс оправдания после смерти",
        ChatComebackChance = "Шанс ответа на обвинение бота",
        ChatTauntChance = "Шанс боевой насмешки (аим/нычки)",
        FileLog = "Писать подробный лог в файл (data/geminibots/logs/debug.log)",
        PacksHeader = "--- Текстовые паки фраз (.txt) ---",
        PacksHelp = "Файлы: garrysmod/data/geminibots/chat/\n(Отметьте галочками нужные паки фраз):",
        PackStats = "%s  [Фрагов: %d | Смертей: %d]",
        BtnReloadPacks = "Перезагрузить .txt паки с диска",

        -- Секция 4
        HeaderPerception = "Сенсорика, зрение и память",
        VisionFOV = "Угол обзора (FOV в градусах)",
        VisionRange = "Дальность видимости (юниты)",
        HearingRange = "Слух шагов и бега за стенами (юниты)",
        GunHearingRange = "Слух выстрелов по коридорам/карте (юниты)",
        MemoryDuration = "Память о цели за стеной (сек)",
        TargetModeHeader = "--- Режим целей (кого атаковать) ---",
        TargetBoth = "Все подряд",
        TargetPvE = "PvE: сначала NPC",
        TargetPlayers = "Только игроки",
        TargetNPCs = "Только NPC",

        -- Секция 5
        HeaderCombat = "Прицеливание и боевой ИИ",
        ReactionMin = "Мин. задержка реакции (сек)",
        ReactionMax = "Макс. задержка реакции (сек)",
        AimSpeed = "Скорость поворота прицела",
        AimSmoothing = "Плавность доводки (Lerp)",
        AimPrediction = "Упреждение движения цели (Lead Aim)",
        AimSpread = "Разброс/ошибка прицеливания (град)",
        HeadshotChance = "Шанс целиться в голову",
        CombatMinDist = "Мин. дистанция боя (отход)",
        CombatMaxDist = "Макс. дистанция боя (сближение)",
        FleeHealth = "Порог бегства (% здоровья)",
        Wallbang = "Прострел стекла/хрупкого (wallbang)",

        HeaderSWCS = "SWCS: декои, флешки, огонь",
        SWCSHelp = "Декой — проверка звука с шансом (иначе игнор). Флешка SWCS слепит и глушит всегда. Огонь молика — отход вбок.",
        DecoyChance = "Шанс пойти на звук декоя",
        FireAvoid = "Отходить от огня молика",
        FireRadius = "Радиус реакции на огонь (юниты)",

        -- Секция 6
        HeaderMovement = "Передвижение и баннихоп",
        BunnyHop = "Баннихоп на ходу (и без врагов)",
        BunnyHopChance = "Шанс прыжка на приземление",

        -- Секция 7
        HeaderDifficulty = "Пресеты сложности",
        DifficultyHelp = "Готовые настройки. Подкрути ниже и сохрани свой пресет через поле.",
        BtnSavePreset = "Сохранить текущие как пресет",
        BtnDeletePreset = "Удалить пресет",
        PresetNameHelp = "Имя своего пресета:",

        -- Секция 8
        HeaderActions = "Быстрые действия",
        HeaderDebug = "Отладка",
        HeaderStates = "Состояния FSM",
        StatesHelp = "Выкл — бот вместо состояния уходит в idle. Idle выключить нельзя.",
        BtnSpawnBot = "Заспавнить бота (+1)",
        BtnSpawnMax = "Заполнить сервер ботами (Максимум)",
        BtnKickAll = "Удалить всех ботов с сервера",
        BtnRerollNames = "Рандомизировать ники ботов",
        BtnReloadNames = "Перезагрузить names.txt с диска",
        BtnRerollAppearance = "Сменить внешность ботов",
        BtnReloadAI = "Перезагрузить всех ботов",
        BtnNavGen = "Сгенерировать Navmesh (nav_generate)",
        BtnReset = "Сбросить все настройки по умолчанию",
        BtnSaveBots = "Сохранить ботов (перенос карты)",
        BtnRestoreBots = "Восстановить сохраненных ботов",
        TeleportHelp = "--- Телепорты (есть ULX-мост: !bringbots, !gotobot) ---",
        BtnBringBots = "Привести ВСЕХ ботов к себе",
        BotNickHelp = "Ник бота (можно часть):",
        BtnBringOne = "Привести этого бота",
        BtnGotoBot = "Телепортироваться к боту",
        BtnBotInfo = "Инфо всех ботов (в консоль)",
        BtnBotInfoOne = "Инфо этого бота (в консоль)",
        ESPHelp = "--- ESP (боксы + инфо, только админам) ---",
        ESPEnabled = "ESP ботов",
        ESPSkeleton = "Скелеты в ESP",
        ESPBoxes = "ESP: боксы",
        ESPHP = "ESP: полоса HP",
        ESPInfo = "ESP: строки инфо",
        ESPStatus = "ESP: статусы и путь",
    },
    en = {
        MenuTitle = "GeminiBots - Bot Management",
        MenuDesc = "Real-time AI configuration for default Garry's Mod player bots.",

        LangButton = "Language: ENGLISH (click: auto -> RU -> EN)",

        -- Section 1
        HeaderGeneral = "General Settings",
        Enabled = "Enable GeminiBots AI",
        CustomNames = "Unique bot custom nicknames",
        PreserveBots = "Restore bots after map change",
        HeaderAppearance = "Appearance",
        Appearance = "Random bot appearance (models/skins)",
        AppearanceModel = "Random player models",
        AppearanceSkin = "Random model skins",
        AppearanceBodygroups = "Random bodygroups",
        AppearanceColor = "Random player color",
        AppearanceRespawn = "Change appearance on every respawn",
        Debug = "Debug mode (console output)",
        DebugDraw = "Debug drawing in world (trajectories, paths)",

        -- Section 2
        HeaderLoadout = "Bot Weapon Selection (Loadout & SWEPs)",
        LoadoutEnabled = "Give random weapons on spawn",
        LoadoutStrip = "Strip default sandbox weapons",
        LoadoutMin = "Min weapons count",
        LoadoutMax = "Max weapons count",
        LoadoutAmmo = "Reserve ammo amount",
        PresetHeader = "--- Quick Weapon Presets ---",
        PresetAll = "Enable ALL Weapons",
        PresetHL2 = "Only Standard HL2",
        PresetM9K = "All M9K (Scan Server)",
        PresetPistols = "Pistols Only",
        PresetRifles = "Rifles & SMGs Only",
        PresetShotguns = "Shotguns Only",
        PresetSnipers = "Snipers Only",
        PresetNone = "Disable All",
        WeaponListHeader = "--- Weapon Pool (Check weapons to enable) ---",
        WeaponNotInstalled = " [NOT INSTALLED ON SERVER]",
        AddWeaponHelp = "Add weapon by classname (e.g. m9k_vector):",
        BtnAddWeapon = "Add Weapon to Pool (+)",
        BtnAddHeldWeapon = "Add weapon from my hands to bot pool",
        BtnGiveHeldWeapon = "Instantly give held weapon to all bots",
        BtnReloadWeapons = "Reload weapons.txt from disk",
        BtnOpenArsenal = "OPEN ARSENAL: scan + search + filters",
        WPackHeader = "--- Weapon packs (tactic adapters) ---",
        WPackFound = "detected",
        WPackMissing = "not on server",
        C4Enabled = "Bots plant and defuse C4 (needs SWCS)",

        -- Section 3
        HeaderChat = "Chat & Taunts",
        ChatEnabled = "Allow bots to write in chat",
        SmartContext = "Smart phrase context (K/D, streaks, cheat whining)",
        ChatKillChance = "Taunt chance after kill",
        ChatDeathChance = "Excuse chance after death",
        ChatComebackChance = "Comeback chance on bot accusation",
        ChatTauntChance = "Combat taunt chance (aim/hiding)",
        FileLog = "Write verbose log to file (data/geminibots/logs/debug.log)",
        PacksHeader = "--- Chat Text Packs (.txt) ---",
        PacksHelp = "Folder: garrysmod/data/geminibots/chat/\n(Check the packs you want to enable):",
        PackStats = "%s  [Kills: %d | Deaths: %d]",
        BtnReloadPacks = "Reload .txt packs from disk",

        -- Section 4
        HeaderPerception = "Perception, Vision & Memory",
        VisionFOV = "Field of view (FOV in degrees)",
        VisionRange = "Vision max range (units)",
        HearingRange = "Footstep hearing range behind walls (units)",
        GunHearingRange = "Gunfire hearing range across corridors (units)",
        MemoryDuration = "Target memory duration (sec)",
        TargetModeHeader = "--- Targeting mode (who to attack) ---",
        TargetBoth = "Everyone",
        TargetPvE = "PvE: NPC first",
        TargetPlayers = "Players only",
        TargetNPCs = "NPC only",

        -- Section 5
        HeaderCombat = "Aiming & Combat AI",
        ReactionMin = "Min reaction delay (sec)",
        ReactionMax = "Max reaction delay (sec)",
        AimSpeed = "Aim turn speed",
        AimSmoothing = "Aim smoothing factor (Lerp)",
        AimPrediction = "Target lead aim (prediction)",
        AimSpread = "Aim spread/inaccuracy (deg)",
        HeadshotChance = "Headshot aim chance",
        CombatMinDist = "Min combat distance (retreat)",
        CombatMaxDist = "Max combat distance (close in)",
        FleeHealth = "Flee health threshold (% HP)",
        Wallbang = "Wallbang through glass/breakables",

        HeaderSWCS = "SWCS: decoys, flashes, fire",
        SWCSHelp = "Decoy: investigate sound on chance (else ignore). SWCS flash blinds + deafens always. Molotov fire: sidestep away.",
        DecoyChance = "Chance to investigate decoy sound",
        FireAvoid = "Back away from molotov fire",
        FireRadius = "Fire avoidance radius (units)",

        -- Section 6
        HeaderMovement = "Movement & Bunny-hop",
        BunnyHop = "Bunny-hop while moving (even with no enemies)",
        BunnyHopChance = "Hop chance per landing",

        -- Section 7
        HeaderDifficulty = "Difficulty presets",
        DifficultyHelp = "Ready-made settings. Tune below, then save your own via name field.",
        BtnSavePreset = "Save current as preset",
        BtnDeletePreset = "Delete preset",
        PresetNameHelp = "Custom preset name:",

        -- Section 8
        HeaderActions = "Quick Actions",
        HeaderDebug = "Debug",
        HeaderStates = "FSM states",
        StatesHelp = "Off = bot idles instead. Idle can't be turned off.",
        BtnSpawnBot = "Spawn Bot (+1)",
        BtnSpawnMax = "Fill Server with Bots (Max)",
        BtnKickAll = "Kick All Bots",
        BtnRerollNames = "Reroll All Bot Nicknames",
        BtnReloadNames = "Reload names.txt from disk",
        BtnRerollAppearance = "Reroll Bot Appearance",
        BtnReloadAI = "Restart All Bots AI",
        BtnNavGen = "Generate Navmesh (nav_generate)",
        BtnReset = "Reset All Settings to Defaults",
        BtnSaveBots = "Save bots (map carry)",
        BtnRestoreBots = "Restore saved bots",
        TeleportHelp = "--- Teleports (ULX bridge: !bringbots, !gotobot) ---",
        BtnBringBots = "Bring ALL bots to me",
        BotNickHelp = "Bot nick (partial ok):",
        BtnBringOne = "Bring this bot",
        BtnGotoBot = "Teleport to bot",
        BtnBotInfo = "All bots info (to console)",
        BtnBotInfoOne = "This bot info (to console)",
        ESPHelp = "--- ESP (boxes + info, admins only) ---",
        ESPEnabled = "Bot ESP",
        ESPSkeleton = "ESP skeletons",
        ESPBoxes = "ESP: boxes",
        ESPHP = "ESP: HP bar",
        ESPInfo = "ESP: info lines",
        ESPStatus = "ESP: statuses and path",
    }
}

-- Текущий язык клиента: ручной выбор (ru/en) либо вживую из GMod
local currentLang = "ru"

local function T(key)
    local langTable = PHRASES[GeminiBots.GetMenuLang()] or PHRASES.ru
    return langTable[key] or key
end

-- Построение меню настроек
local currentTab = "main"

local function BuildSettingsMenu(panel, tab, opts)
    if not IsValid(panel) then return end
    currentSettingsPanel = panel
    currentTab = tab or currentTab or "main"
    tab = currentTab
    currentOpts = opts
    panel:ClearControls()

    -- Кнопка переключения языка (RU / EN). В отдельном окне язык живет
    -- в шапке окна, общая шапка там не строится (opts.noSharedHeader).
    if not (opts and opts.noSharedHeader) then
        local btnLang = panel:Button(T("LangButton"))
        btnLang.DoClick = function()
            GeminiBots.ToggleMenuLang()
            currentLang = GeminiBots.GetMenuLang()
            BuildSettingsMenu(panel, tab)
        end

        panel:Help(T("MenuDesc"))
    end

    ----------------------------------------------------------------------------
    -- Вкладка "Основные": общие параметры + чат
    ----------------------------------------------------------------------------
    if tab == "main" then
    panel:Help("\n=== " .. T("HeaderGeneral") .. " ===")
    panel:CheckBox(T("Enabled"), "geminibots_enabled")
    panel:CheckBox(T("CustomNames"), "geminibots_custom_names")
    panel:CheckBox(T("PreserveBots"), "geminibots_preserve_bots")
    panel:Help("\n=== " .. T("HeaderAppearance") .. " ===")
    panel:CheckBox(T("Appearance"), "geminibots_appearance_enabled")
    panel:CheckBox(T("AppearanceModel"), "geminibots_appearance_model")
    panel:CheckBox(T("AppearanceSkin"), "geminibots_appearance_skin")
    panel:CheckBox(T("AppearanceBodygroups"), "geminibots_appearance_bodygroups")
    panel:CheckBox(T("AppearanceColor"), "geminibots_appearance_color")
    panel:CheckBox(T("AppearanceRespawn"), "geminibots_appearance_respawn")
    end -- main: общие параметры

    ----------------------------------------------------------------------------
    -- Вкладка "Оружие": экипировка и Арсенал
    ----------------------------------------------------------------------------
    if tab == "weapons" then
    panel:Help("\n=== " .. T("HeaderLoadout") .. " ===")
    panel:CheckBox(T("LoadoutEnabled"), "geminibots_loadout_enabled")
    panel:CheckBox(T("LoadoutStrip"), "geminibots_loadout_strip")
    panel:NumSlider(T("LoadoutMin"), "geminibots_loadout_min", 1, 5, 0)
    panel:NumSlider(T("LoadoutMax"), "geminibots_loadout_max", 1, 5, 0)
    panel:NumSlider(T("LoadoutAmmo"), "geminibots_loadout_ammo", 30, 600, 0)

    -- Выбор оружия — в отдельном окне Арсенала (скан + поиск + фильтры)
    GeminiBots.Theme.ButtonGrid(panel, {
        { label = T("BtnOpenArsenal") or "Открыть Арсенал (скан + поиск)", fn = function()
            RunConsoleCommand("geminibots_weapons_menu")
        end },
        { label = T("BtnAddHeldWeapon"), fn = function()
            net.Start("GeminiBots_AddHeldWeapon")
            net.SendToServer()
        end },
        { label = T("BtnGiveHeldWeapon"), fn = function()
            net.Start("GeminiBots_GiveHeldWeaponToBots")
            net.SendToServer()
        end },
        { label = T("BtnReloadWeapons"), fn = function()
            RunConsoleCommand("geminibots_weapon_reload")
        end },
    })

    panel:CheckBox(T("C4Enabled"), "geminibots_c4_enabled")

    -- Адаптеры оружейных паков: детект + вкл/выкл тактики пака
    panel:Help(T("WPackHeader"))
    if #GeminiBots.CachedAdapters == 0 then
        net.Start("GeminiBots_RequestWeaponAdapters")
        net.SendToServer()
    end
    for _, ad in ipairs(GeminiBots.CachedAdapters) do
        local entry = ad
        local label = entry.title .. " [" .. (entry.detected and T("WPackFound") or T("WPackMissing")) .. "]"
        local chk = panel:CheckBox(label)
        chk:SetValue(entry.active == true and 1 or 0)
        chk.OnChange = function(self, val)
            net.Start("GeminiBots_ToggleWeaponAdapter")
            net.WriteString(entry.id)
            net.WriteBool(val)
            net.SendToServer()
        end
    end
    end -- weapons: экипировка

    ----------------------------------------------------------------------------
    -- Вкладка "Основные": чат и текстовые паки (.txt)
    ----------------------------------------------------------------------------
    if tab == "main" then
    panel:Help("\n=== " .. T("HeaderChat") .. " ===")
    panel:CheckBox(T("ChatEnabled"), "geminibots_chat_enabled")
    panel:CheckBox(T("SmartContext"), "geminibots_chat_smart_context")
    panel:NumSlider(T("ChatKillChance"), "geminibots_chat_kill_chance", 0.0, 1.0, 2)
    panel:NumSlider(T("ChatDeathChance"), "geminibots_chat_death_chance", 0.0, 1.0, 2)
    panel:NumSlider(T("ChatComebackChance"), "geminibots_chat_comeback_chance", 0.0, 1.0, 2)
    panel:NumSlider(T("ChatTauntChance"), "geminibots_chat_taunt_chance", 0.0, 1.0, 2)
    panel:CheckBox(T("FileLog"), "geminibots_file_log")

    panel:Help(T("PacksHeader"))
    panel:Help(T("PacksHelp"))

    -- Если список паков еще не получен с сервера, запрашиваем
    if #GeminiBots.CachedPacks == 0 then
        net.Start("GeminiBots_RequestChatPacks")
        net.SendToServer()
    end

    -- Список отдельных .txt паков с чекбоксами для вкл/выкл
    for _, pack in ipairs(GeminiBots.CachedPacks) do
        local entry = pack
        local label = string.format(T("PackStats"), entry.name, entry.kills or 0, entry.deaths or 0)
        local chk = panel:CheckBox(label)
        chk:SetValue(entry.active == true and 1 or 0)

        chk.OnChange = function(self, val)
            net.Start("GeminiBots_ToggleChatPack")
            net.WriteString(entry.name)
            net.WriteBool(val)
            net.SendToServer()
        end
    end

    local btnReloadPacks = panel:Button(T("BtnReloadPacks"))
    btnReloadPacks.DoClick = function()
        RunConsoleCommand("geminibots_chat_reload_packs")
    end
    end -- main: чат

    ----------------------------------------------------------------------------
    -- Вкладка "Бой и движение": сенсорика, бой, передвижение, пресеты
    ----------------------------------------------------------------------------
    if tab == "combat" then
    panel:Help("\n=== " .. T("HeaderPerception") .. " ===")
    panel:NumSlider(T("VisionFOV"), "geminibots_vision_fov", 45, 180, 0)
    panel:NumSlider(T("VisionRange"), "geminibots_vision_range", 500, 6000, 0)
    panel:NumSlider(T("HearingRange"), "geminibots_hearing_range", 100, 2000, 0)
    panel:NumSlider(T("GunHearingRange"), "geminibots_gun_hearing_range", 500, 6000, 0)
    panel:NumSlider(T("MemoryDuration"), "geminibots_memory_duration", 1.0, 20.0, 1)

    panel:Help(T("TargetModeHeader"))

    GeminiBots.Theme.ButtonGrid(panel, {
        { label = T("TargetBoth"), fn = function() RunConsoleCommand("geminibots_target_mode", "both") end },
        { label = T("TargetPvE"), fn = function() RunConsoleCommand("geminibots_target_mode", "pve") end },
        { label = T("TargetPlayers"), fn = function() RunConsoleCommand("geminibots_target_mode", "players") end },
        { label = T("TargetNPCs"), fn = function() RunConsoleCommand("geminibots_target_mode", "npcs") end },
    })

    ----------------------------------------------------------------------------
    -- Бой и прицеливание (вкладка "Бой и движение")
    ----------------------------------------------------------------------------
    panel:Help("\n=== " .. T("HeaderCombat") .. " ===")
    panel:NumSlider(T("ReactionMin"), "geminibots_reaction_min", 0.0, 1.0, 2)
    panel:NumSlider(T("ReactionMax"), "geminibots_reaction_max", 0.0, 1.5, 2)
    panel:NumSlider(T("AimSpeed"), "geminibots_aim_speed", 90, 720, 0)
    panel:NumSlider(T("AimSmoothing"), "geminibots_aim_smoothing", 0.05, 0.8, 2)
    panel:CheckBox(T("AimPrediction"), "geminibots_aim_prediction")
    panel:NumSlider(T("AimSpread"), "geminibots_aim_spread", 0.0, 5.0, 1)
    panel:NumSlider(T("HeadshotChance"), "geminibots_aim_headshot_chance", 0.0, 1.0, 2)
    panel:NumSlider(T("CombatMinDist"), "geminibots_combat_min_dist", 100, 600, 0)
    panel:NumSlider(T("CombatMaxDist"), "geminibots_combat_max_dist", 600, 2500, 0)
    panel:NumSlider(T("FleeHealth"), "geminibots_flee_health", 0.0, 0.6, 2)
    panel:CheckBox(T("Wallbang"), "geminibots_wallbang")

    panel:Help("\n=== " .. T("HeaderSWCS") .. " ===")
    panel:Help(T("SWCSHelp"))
    panel:NumSlider(T("DecoyChance"), "geminibots_swcs_decoy_chance", 0.0, 1.0, 2)
    panel:CheckBox(T("FireAvoid"), "geminibots_swcs_fire_avoid")
    panel:NumSlider(T("FireRadius"), "geminibots_swcs_fire_radius", 150, 800, 0)

    ----------------------------------------------------------------------------
    -- Передвижение (вкладка "Бой и движение")
    ----------------------------------------------------------------------------
    panel:Help("\n=== " .. T("HeaderMovement") .. " ===")
    panel:CheckBox(T("BunnyHop"), "geminibots_bhop_enabled")
    panel:NumSlider(T("BunnyHopChance"), "geminibots_bhop_chance", 0.0, 1.0, 2)

    ----------------------------------------------------------------------------
    -- Пресеты сложности (вкладка "Бой и движение")
    ----------------------------------------------------------------------------
    panel:Help("\n=== " .. T("HeaderDifficulty") .. " ===")
    panel:Help(T("DifficultyHelp"))

    if #GeminiBots.CachedSkillPresets == 0 then
        net.Start("GeminiBots_RequestSkillPresets")
        net.SendToServer()
    end

    -- Встроенные пресеты по порядку + свои: одной сеткой, размер сам
    do
        local defs = {}
        for _, id in ipairs(GeminiBots.SkillPresets.Order or {}) do
            local def = GeminiBots.SkillPresets.BuiltIn[id]
            if def then
                local presetId = id
                local label = (GeminiBots.GetMenuLang() == "ru") and def.label_ru or def.label_en
                defs[#defs + 1] = { label = label, fn = function()
                    net.Start("GeminiBots_ApplySkillPreset")
                    net.WriteString(presetId)
                    net.SendToServer()
                end }
            end
        end
        for _, entry in ipairs(GeminiBots.CachedSkillPresets) do
            if entry.custom then
                local presetId = entry.id
                defs[#defs + 1] = { label = presetId .. " (свой)", fn = function()
                    net.Start("GeminiBots_ApplySkillPreset")
                    net.WriteString(presetId)
                    net.SendToServer()
                end }
            end
        end
        GeminiBots.Theme.ButtonGrid(panel, defs)
    end

    panel:Help(T("PresetNameHelp"))
    local txtPreset = panel:TextEntry(T("PresetNameHelp"))
    local btnSavePreset = panel:Button(T("BtnSavePreset"))
    btnSavePreset.DoClick = function()
        local val = txtPreset:GetValue()
        if val and val ~= "" then
            net.Start("GeminiBots_SaveSkillPreset")
            net.WriteString(val)
            net.SendToServer()
        end
    end

    local btnDeletePreset = panel:Button(T("BtnDeletePreset"))
    btnDeletePreset.DoClick = function()
        local val = txtPreset:GetValue()
        if val and val ~= "" then
            net.Start("GeminiBots_DeleteSkillPreset")
            net.WriteString(val)
            net.SendToServer()
        end
    end
    end -- combat: сенсорика, бой, движение, пресеты

    ----------------------------------------------------------------------------
    -- Вкладка "Админ": быстрые действия и управление
    ----------------------------------------------------------------------------
    if tab == "admin" then
    panel:Help("\n=== " .. T("HeaderActions") .. " ===")

    GeminiBots.Theme.ButtonGrid(panel, {
        { label = T("BtnSpawnBot"), fn = function() RunConsoleCommand("geminibots_add") end },
        { label = T("BtnSpawnMax"), fn = function() RunConsoleCommand("geminibots_spawn_max") end },
        { label = T("BtnKickAll"), fn = function() RunConsoleCommand("geminibots_kick_all") end },
    })
    GeminiBots.Theme.ButtonGrid(panel, {
        { label = T("BtnRerollNames"), fn = function() RunConsoleCommand("geminibots_names_reroll") end },
        { label = T("BtnReloadNames"), fn = function() RunConsoleCommand("geminibots_names_reload") end },
        { label = T("BtnRerollAppearance"), fn = function() RunConsoleCommand("geminibots_appearance_reroll") end },
        { label = T("BtnReloadAI"), fn = function() RunConsoleCommand("geminibots_reload") end },
    })
    GeminiBots.Theme.ButtonGrid(panel, {
        { label = T("BtnNavGen"), fn = function() RunConsoleCommand("nav_generate") end },
        { label = T("BtnReset"), fn = function() RunConsoleCommand("geminibots_reset_defaults") end },
        { label = T("BtnSaveBots"), fn = function() RunConsoleCommand("geminibots_save_bots") end },
        { label = T("BtnRestoreBots"), fn = function() RunConsoleCommand("geminibots_restore_bots") end },
    })

    -- Поле ника объявлено заранее: сетка ниже читает его в замыканиях
    local txtBotNick

    panel:Help(T("TeleportHelp"))
    GeminiBots.Theme.ButtonGrid(panel, {
        { label = T("BtnBringBots"), fn = function() RunConsoleCommand("geminibots_bring", "*") end },
        { label = T("BtnBringOne"), fn = function()
            local val = IsValid(txtBotNick) and txtBotNick:GetValue() or ""
            if val ~= "" then RunConsoleCommand("geminibots_bring", val) end
        end },
        { label = T("BtnGotoBot"), fn = function()
            local val = IsValid(txtBotNick) and txtBotNick:GetValue() or ""
            if val ~= "" then RunConsoleCommand("geminibots_goto", val) end
        end },
        { label = T("BtnBotInfo"), fn = function() RunConsoleCommand("geminibots_bot_info") end },
        { label = T("BtnBotInfoOne"), fn = function()
            local val = IsValid(txtBotNick) and txtBotNick:GetValue() or ""
            if val ~= "" then RunConsoleCommand("geminibots_bot_info", val) end
        end },
    })

    panel:Help(T("BotNickHelp"))
    txtBotNick = panel:TextEntry(T("BotNickHelp"))

    panel:Help(T("ESPHelp"))
    local chkESP = panel:CheckBox(T("ESPEnabled"))
    chkESP:SetValue(GeminiBots.ESPEnabled and 1 or 0)
    chkESP.OnChange = function(_, val)
        GeminiBots.SetESP(val)
    end

    local chkSkel = panel:CheckBox(T("ESPSkeleton"))
    chkSkel:SetValue(GeminiBots.ESPSkeleton and 1 or 0)
    chkSkel.OnChange = function(_, val)
        GeminiBots.ESPSkeleton = (val == true)
    end

    panel:CheckBox(T("ESPBoxes"), "geminibots_esp_boxes")
    panel:CheckBox(T("ESPHP"), "geminibots_esp_hp")
    panel:CheckBox(T("ESPInfo"), "geminibots_esp_info")
    panel:CheckBox(T("ESPStatus"), "geminibots_esp_status")

    panel:Help("\n=== " .. T("HeaderDebug") .. " ===")
    panel:CheckBox(T("Debug"), "geminibots_debug")
    panel:CheckBox(T("DebugDraw"), "geminibots_debug_draw")

    panel:Help("\n=== " .. T("HeaderStates") .. " ===")
    panel:Help(T("StatesHelp"))
    if #GeminiBots.CachedStates == 0 then
        net.Start("GeminiBots_RequestStates")
        net.SendToServer()
    end
    for _, st in ipairs(GeminiBots.CachedStates) do
        local entry = st
        local chk = panel:CheckBox(entry.name .. " [" .. entry.source .. "]")
        chk:SetValue(entry.enabled == true and 1 or 0)
        chk.OnChange = function(self, val)
            net.Start("GeminiBots_ToggleState")
            net.WriteString(entry.name)
            net.WriteBool(val)
            net.SendToServer()
        end
    end
    end -- admin: действия
end

-- Прием списка чат-паков с сервера и обновление UI.
-- Вкладку "Меню" отдельного окна не трогаем: она клиентская, построитель ее затрет.
net.Receive("GeminiBots_ReceiveChatPacks", function()
    GeminiBots.CachedPacks = net.ReadTable()
    if IsValid(currentSettingsPanel) and not currentSettingsPanel.GeminiIsMenuTab then
        BuildSettingsMenu(currentSettingsPanel, currentTab, currentOpts)
    end
end)

-- Прием списка пресетов сложности и обновление UI
net.Receive("GeminiBots_ReceiveSkillPresets", function()
    GeminiBots.CachedSkillPresets = net.ReadTable()
    if IsValid(currentSettingsPanel) and not currentSettingsPanel.GeminiIsMenuTab then
        BuildSettingsMenu(currentSettingsPanel, currentTab, currentOpts)
    end
end)

-- Прием списка адаптеров оружейных паков и обновление UI
net.Receive("GeminiBots_ReceiveWeaponAdapters", function()
    GeminiBots.CachedAdapters = net.ReadTable()
    if IsValid(currentSettingsPanel) and not currentSettingsPanel.GeminiIsMenuTab then
        BuildSettingsMenu(currentSettingsPanel, currentTab, currentOpts)
    end
end)

-- Прием списка состояний FSM и обновление UI
net.Receive("GeminiBots_ReceiveStates", function()
    GeminiBots.CachedStates = net.ReadTable()
    if IsValid(currentSettingsPanel) and not currentSettingsPanel.GeminiIsMenuTab then
        BuildSettingsMenu(currentSettingsPanel, currentTab, currentOpts)
    end
end)

-- Регистрация в Spawnmenu: настройки переехали в отдельное окно,
-- в Q оставляем одну кнопку "Открыть меню" (и в Options, и в Utilities)
hook.Add("PopulateToolMenu", "GeminiBots_PopulateToolMenu", function()
    local function MakeOpener(pnl)
        pnl:ClearControls()
        local ru = GeminiBots.GetMenuLang() == "ru"
        pnl:Help(ru and "Все настройки переехали в отдельное окно."
            or "All settings moved to the standalone window.")
        local btn = pnl:Button(ru and "ОТКРЫТЬ МЕНЮ" or "OPEN MENU")
        btn.DoClick = function()
            RunConsoleCommand("geminibots_menu")
        end
        local btnArs = pnl:Button(ru and "ОТКРЫТЬ АРСЕНАЛ" or "OPEN ARSENAL")
        btnArs.DoClick = function()
            RunConsoleCommand("geminibots_weapons_menu")
        end
    end

    spawnmenu.AddToolMenuOption(
        "Options",
        "GeminiBots",
        "GeminiBots_Open",
        "Открыть меню / Open menu",
        "",
        "",
        MakeOpener
    )

    spawnmenu.AddToolMenuOption(
        "Utilities",
        "GeminiBots",
        "GeminiBots_Utilities",
        "Открыть меню / Open menu",
        "",
        "",
        MakeOpener
    )
end)

-- Мост для отдельного окна настроек (cl_settings.lua): тот же построитель,
-- та же цель пересборки по сети. Без этого окно пришлось бы дублировать.
function GeminiBots.BuildSettingsMenu(panel, tab, opts)
    return BuildSettingsMenu(panel, tab, opts)
end

function GeminiBots.SetSettingsTarget(panel, tab, opts)
    currentSettingsPanel = panel
    currentTab = tab
    currentOpts = opts
end

function GeminiBots.GetMenuLang()
    local cv = GetConVar("geminibots_menu_lang")
    local v = cv and string.lower(cv:GetString() or "auto") or "auto"
    if v == "ru" or v == "en" then return v end
    -- Авто: язык берем из GMod вживую — чел с англ. игрой сразу видит EN
    local gl = GetConVar("gmod_language") and GetConVar("gmod_language"):GetString() or ""
    if string.find(string.lower(gl), "ru") then return "ru" end
    return "en"
end

-- Ручной режим конвара (auto/ru/en): кнопка в шапке его крутит
function GeminiBots.MenuLangMode()
    local cv = GetConVar("geminibots_menu_lang")
    local v = cv and string.lower(cv:GetString() or "auto") or "auto"
    if v == "ru" or v == "en" then return v end
    return "auto"
end

function GeminiBots.ToggleMenuLang()
    -- авто -> ru -> en -> авто, выбор запоминается конваром
    local order = { "auto", "ru", "en" }
    local cur = GeminiBots.MenuLangMode()
    local next = "auto"
    for i, m in ipairs(order) do
        if m == cur then next = order[(i % #order) + 1] break end
    end
    RunConsoleCommand("geminibots_menu_lang", next)
    currentLang = GeminiBots.GetMenuLang()
    return currentLang
end
