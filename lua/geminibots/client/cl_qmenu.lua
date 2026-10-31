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

        LangButton = "Язык: РУССКИЙ (клик: авто -> RU -> UK -> ES -> PT -> EN)",

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

        LangButton = "Language: ENGLISH (click: auto -> RU -> UK -> ES -> PT -> EN)",

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
    },
    uk = {
        MenuTitle = "GeminiBots - Керування ботами",
        MenuDesc = "Налаштування ІІ стандартних ботів у реальному часі.",

        LangButton = "Мова: УКРАЇНСЬКА (клік: авто -> RU -> UK -> ES -> PT -> EN)",

        -- Секція 1
        HeaderGeneral = "Основні параметри",
        Enabled = "Увімкнути ІІ ботів",
        CustomNames = "Унікальні кастомні ніки ботів",
        PreserveBots = "Відновлювати ботів при зміні карти",
        HeaderAppearance = "Зовнішність",
        Appearance = "Випадкова зовнішність ботів (моделі/скіни)",
        AppearanceModel = "Випадкові моделі гравців",
        AppearanceSkin = "Випадкові скіни моделей",
        AppearanceBodygroups = "Випадкові бодігрупи",
        AppearanceColor = "Випадковий колір гравця",
        AppearanceRespawn = "Змінювати зовнішність при кожному відродженні",
        Debug = "Режим налагодження (вивід у консоль)",
        DebugDraw = "Візуалізація налагодження у світі (траєкторії, шляхи)",

        -- Секція 2
        HeaderLoadout = "Вибір зброї ботів (Loadout & SWEPs)",
        LoadoutEnabled = "Видавати випадкову зброю при спавні",
        LoadoutStrip = "Очищати дефолтні тули (Sandbox)",
        LoadoutMin = "Мін. кількість стволів",
        LoadoutMax = "Макс. кількість стволів",
        LoadoutAmmo = "Кількість запасних набоїв",
        PresetHeader = "--- Швидкі пресети пулу зброї ---",
        PresetAll = "Увімкнути ВСЮ зброю",
        PresetHL2 = "Лише стандартні HL2",
        PresetM9K = "Весь M9K (сканувати сервер)",
        PresetPistols = "Лише пістолети",
        PresetRifles = "Лише автомати та ПП",
        PresetShotguns = "Лише дробовики",
        PresetSnipers = "Лише снайперки",
        PresetNone = "Вимкнути все",
        WeaponListHeader = "--- Список зброї в пулі (Позначте потрібні) ---",
        WeaponNotInstalled = " [НЕ ВСТАНОВЛЕНО НА СЕРВЕРІ]",
        AddWeaponHelp = "Додати зброю за ім'ям класу (напр. m9k_vector):",
        BtnAddWeapon = "Додати зброю в пул (+)",
        BtnAddHeldWeapon = "Взяти ствол з рук і додати в пул ботів",
        BtnGiveHeldWeapon = "Миттєво видати ствол з рук усім ботам",
        BtnReloadWeapons = "Перезавантажити weapons.txt з диска",
        BtnOpenArsenal = "ВІДКРИТИ АРСЕНАЛ: скан + пошук + фільтри",
        WPackHeader = "--- Збройові паки (адаптери тактики) ---",
        WPackFound = "знайдено",
        WPackMissing = "немає на сервері",
        C4Enabled = "Боти ставлять і розміновують C4 (потрібен SWCS)",

        -- Секція 3
        HeaderChat = "Чат і реакції ботів",
        ChatEnabled = "Дозволити ботам спілкуватися в чаті",
        SmartContext = "Розумний контекст фраз (облік K/D, стріків і читів)",
        ChatKillChance = "Шанс насмішки після фрага",
        ChatDeathChance = "Шанс виправдання після смерті",
        ChatComebackChance = "Шанс відповіді на звинувачення бота",
        ChatTauntChance = "Шанс бойової насмішки (аім/нички)",
        FileLog = "Писати докладний лог у файл (data/geminibots/logs/debug.log)",
        PacksHeader = "--- Текстові паки фраз (.txt) ---",
        PacksHelp = "Файли: garrysmod/data/geminibots/chat/\n(Позначте галочками потрібні паки фраз):",
        PackStats = "%s  [Фрагів: %d | Смертей: %d]",
        BtnReloadPacks = "Перезавантажити .txt паки з диска",

        -- Секція 4
        HeaderPerception = "Сенсорика, зір і пам'ять",
        VisionFOV = "Кут огляду (FOV у градусах)",
        VisionRange = "Дальність видимості (юніти)",
        HearingRange = "Слух кроків і бігу за стінами (юніти)",
        GunHearingRange = "Слух пострілів по коридорах/карті (юніти)",
        MemoryDuration = "Пам'ять про ціль за стіною (сек)",
        TargetModeHeader = "--- Режим цілей (кого атакувати) ---",
        TargetBoth = "Усі підряд",
        TargetPvE = "PvE: спочатку NPC",
        TargetPlayers = "Лише гравці",
        TargetNPCs = "Лише NPC",

        -- Секція 5
        HeaderCombat = "Прицілювання і бойовий ІІ",
        ReactionMin = "Мін. затримка реакції (сек)",
        ReactionMax = "Макс. затримка реакції (сек)",
        AimSpeed = "Швидкість повороту прицілу",
        AimSmoothing = "Плавність доводки (Lerp)",
        AimPrediction = "Випередження руху цілі (Lead Aim)",
        AimSpread = "Розкид/помилка прицілювання (град)",
        HeadshotChance = "Шанс целитися в голову",
        CombatMinDist = "Мін. дистанція бою (відхід)",
        CombatMaxDist = "Макс. дистанція бою (зближення)",
        FleeHealth = "Поріг втечі (% здоров'я)",
        Wallbang = "Простріл скла/крихкого (wallbang)",

        HeaderSWCS = "SWCS: декої, флашки, вогонь",
        SWCSHelp = "Декой — перевірка звуку з шансом (інакше ігнор). Флашка SWCS сліпить і глушить завжди. Вогонь молотова — відхід убік.",
        DecoyChance = "Шанс піти на звук декоя",
        FireAvoid = "Відходити від вогню молотова",
        FireRadius = "Радіус реакції на вогонь (юніти)",

        -- Секція 6
        HeaderMovement = "Пересування і банніхоп",
        BunnyHop = "Банніхоп на ходу (і без ворогів)",
        BunnyHopChance = "Шанс стрибка при приземленні",

        -- Секція 7
        HeaderDifficulty = "Пресети складності",
        DifficultyHelp = "Готові налаштування. Підкрути нижче і збережи свій пресет через поле.",
        BtnSavePreset = "Зберегти поточні як пресет",
        BtnDeletePreset = "Видалити пресет",
        PresetNameHelp = "Ім'я свого пресету:",

        -- Секція 8
        HeaderActions = "Швидкі дії",
        HeaderDebug = "Налагодження",
        HeaderStates = "Стани FSM",
        StatesHelp = "Викл — бот замість стану іде в idle. Idle вимкнути не можна.",
        BtnSpawnBot = "Заспавнити бота (+1)",
        BtnSpawnMax = "Заповнити сервер ботами (Максимум)",
        BtnKickAll = "Видалити всіх ботів з сервера",
        BtnRerollNames = "Рандомізувати ніки ботів",
        BtnReloadNames = "Перезавантажити names.txt з диска",
        BtnRerollAppearance = "Змінити зовнішність ботів",
        BtnReloadAI = "Перезавантажити всіх ботів",
        BtnNavGen = "Згенерувати Navmesh (nav_generate)",
        BtnReset = "Скинути всі налаштування за замовчуванням",
        BtnSaveBots = "Зберегти ботів (перенос карти)",
        BtnRestoreBots = "Відновити збережених ботів",
        TeleportHelp = "--- Телепорти (є ULX-міст: !bringbots, !gotobot) ---",
        BtnBringBots = "Привести ВСІХ ботів до себе",
        BotNickHelp = "Нік бота (можна частину):",
        BtnBringOne = "Привести цього бота",
        BtnGotoBot = "Телепортуватися до бота",
        BtnBotInfo = "Інфо всіх ботів (у консоль)",
        BtnBotInfoOne = "Інфо цього бота (у консоль)",
        ESPHelp = "--- ESP (бокси + інфо, лише адмінам) ---",
        ESPEnabled = "ESP ботів",
        ESPSkeleton = "Скелети в ESP",
        ESPBoxes = "ESP: бокси",
        ESPHP = "ESP: смуга HP",
        ESPInfo = "ESP: рядки інфо",
        ESPStatus = "ESP: статуси і шлях",
    },
    es = {
        MenuTitle = "GeminiBots - Gestión de bots",
        MenuDesc = "Configuración en tiempo real de la IA de los bots estándar.",

        LangButton = "Idioma: ESPAÑOL (clic: auto -> RU -> UK -> ES -> PT -> EN)",

        -- Sección 1
        HeaderGeneral = "Ajustes generales",
        Enabled = "Activar la IA de los bots",
        CustomNames = "Apodos personalizados únicos para bots",
        PreserveBots = "Restaurar bots al cambiar de mapa",
        HeaderAppearance = "Apariencia",
        Appearance = "Apariencia aleatoria de bots (modelos/skins)",
        AppearanceModel = "Modelos de jugador aleatorios",
        AppearanceSkin = "Skins de modelo aleatorios",
        AppearanceBodygroups = "Bodygroups aleatorios",
        AppearanceColor = "Color de jugador aleatorio",
        AppearanceRespawn = "Cambiar apariencia en cada reaparición",
        Debug = "Modo depuración (salida por consola)",
        DebugDraw = "Dibujo de depuración en el mundo (trayectorias, rutas)",

        -- Sección 2
        HeaderLoadout = "Selección de armas de bots (Loadout & SWEPs)",
        LoadoutEnabled = "Dar armas aleatorias al aparecer",
        LoadoutStrip = "Quitar herramientas predeterminadas (Sandbox)",
        LoadoutMin = "Nº mínimo de armas",
        LoadoutMax = "Nº máximo de armas",
        LoadoutAmmo = "Cantidad de munición de reserva",
        PresetHeader = "--- Presets rápidos del arsenal ---",
        PresetAll = "Activar TODAS las armas",
        PresetHL2 = "Solo HL2 estándar",
        PresetM9K = "Todo M9K (escanear servidor)",
        PresetPistols = "Solo pistolas",
        PresetRifles = "Solo fusiles y subfusiles",
        PresetShotguns = "Solo escopetas",
        PresetSnipers = "Solo francotiradoras",
        PresetNone = "Desactivar todo",
        WeaponListHeader = "--- Lista de armas del pool (Marca las que quieras) ---",
        WeaponNotInstalled = " [NO INSTALADA EN EL SERVIDOR]",
        AddWeaponHelp = "Añadir arma por nombre de clase (p. ej. m9k_vector):",
        BtnAddWeapon = "Añadir arma al pool (+)",
        BtnAddHeldWeapon = "Tomar el arma en mano y añadirla al pool de bots",
        BtnGiveHeldWeapon = "Entregar al instante el arma en mano a todos los bots",
        BtnReloadWeapons = "Recargar weapons.txt desde el disco",
        BtnOpenArsenal = "ABRIR ARSENAL: escaneo + búsqueda + filtros",
        WPackHeader = "--- Packs de armas (adaptadores de táctica) ---",
        WPackFound = "detectado",
        WPackMissing = "no está en el servidor",
        C4Enabled = "Los bots colocan y desactivan C4 (requiere SWCS)",

        -- Sección 3
        HeaderChat = "Chat y reacciones de bots",
        ChatEnabled = "Permitir que los bots escriban en el chat",
        SmartContext = "Contexto inteligente de frases (K/D, rachas y trucos)",
        ChatKillChance = "Probabilidad de burla tras una baja",
        ChatDeathChance = "Probabilidad de excusa tras morir",
        ChatComebackChance = "Probabilidad de responder a la acusación de un bot",
        ChatTauntChance = "Probabilidad de provocación en combate (puntería/escondite)",
        FileLog = "Escribir registro detallado en archivo (data/geminibots/logs/debug.log)",
        PacksHeader = "--- Packs de texto de frases (.txt) ---",
        PacksHelp = "Archivos: garrysmod/data/geminibots/chat/\n(Marca con casillas los packs que quieras):",
        PackStats = "%s  [Bajas: %d | Muertes: %d]",
        BtnReloadPacks = "Recargar packs .txt desde el disco",

        -- Sección 4
        HeaderPerception = "Sentidos, visión y memoria",
        VisionFOV = "Campo de visión (FOV en grados)",
        VisionRange = "Alcance máximo de visión (unidades)",
        HearingRange = "Alcance auditivo de pasos tras muros (unidades)",
        GunHearingRange = "Alcance auditivo de disparos por el mapa (unidades)",
        MemoryDuration = "Memoria del objetivo tras un muro (seg)",
        TargetModeHeader = "--- Modo de objetivos (a quién atacar) ---",
        TargetBoth = "Todos por igual",
        TargetPvE = "PvE: primero NPC",
        TargetPlayers = "Solo jugadores",
        TargetNPCs = "Solo NPC",

        -- Sección 5
        HeaderCombat = "Puntería e IA de combate",
        ReactionMin = "Retardo mínimo de reacción (seg)",
        ReactionMax = "Retardo máximo de reacción (seg)",
        AimSpeed = "Velocidad de giro de la mira",
        AimSmoothing = "Suavizado del apuntado (Lerp)",
        AimPrediction = "Anticipación del movimiento del objetivo (Lead Aim)",
        AimSpread = "Dispersión/error de puntería (grados)",
        HeadshotChance = "Probabilidad de apuntar a la cabeza",
        CombatMinDist = "Distancia mínima de combate (retroceso)",
        CombatMaxDist = "Distancia máxima de combate (acercarse)",
        FleeHealth = "Umbral de huida (% de vida)",
        Wallbang = "Disparar a través de cristal/frágil (wallbang)",

        HeaderSWCS = "SWCS: señuelos, flash, fuego",
        SWCSHelp = "Señuelo: investigar el sonido con probabilidad (si no, ignorar). La flash de SWCS ciega y ensordece siempre. Fuego de molotov: apartarse a un lado.",
        DecoyChance = "Probabilidad de investigar un señuelo",
        FireAvoid = "Apartarse del fuego del molotov",
        FireRadius = "Radio de reacción al fuego (unidades)",

        -- Sección 6
        HeaderMovement = "Movimiento y bunny-hop",
        BunnyHop = "Bunny-hop al moverse (y sin enemigos)",
        BunnyHopChance = "Probabilidad de salto al aterrizar",

        -- Sección 7
        HeaderDifficulty = "Presets de dificultad",
        DifficultyHelp = "Ajustes listos. Modifícalos abajo y guarda tu preset en el campo.",
        BtnSavePreset = "Guardar los actuales como preset",
        BtnDeletePreset = "Eliminar preset",
        PresetNameHelp = "Nombre del preset propio:",

        -- Sección 8
        HeaderActions = "Acciones rápidas",
        HeaderDebug = "Depuración",
        HeaderStates = "Estados FSM",
        StatesHelp = "Desactivado = el bot pasa a idle en vez del estado. Idle no se puede desactivar.",
        BtnSpawnBot = "Generar bot (+1)",
        BtnSpawnMax = "Llenar el servidor de bots (Máximo)",
        BtnKickAll = "Expulsar a todos los bots del servidor",
        BtnRerollNames = "Randomizar los apodos de los bots",
        BtnReloadNames = "Recargar names.txt desde el disco",
        BtnRerollAppearance = "Cambiar apariencia de los bots",
        BtnReloadAI = "Reiniciar la IA de todos los bots",
        BtnNavGen = "Generar navmesh (nav_generate)",
        BtnReset = "Restablecer todos los ajustes por defecto",
        BtnSaveBots = "Guardar bots (traslado de mapa)",
        BtnRestoreBots = "Restaurar bots guardados",
        TeleportHelp = "--- Teletransportes (hay puente ULX: !bringbots, !gotobot) ---",
        BtnBringBots = "Traer a TODOS los bots hacia mí",
        BotNickHelp = "Apodo del bot (vale parcial):",
        BtnBringOne = "Traer a este bot",
        BtnGotoBot = "Teletransportarse al bot",
        BtnBotInfo = "Info de todos los bots (a consola)",
        BtnBotInfoOne = "Info de este bot (a consola)",
        ESPHelp = "--- ESP (cajas + info, solo admins) ---",
        ESPEnabled = "ESP de bots",
        ESPSkeleton = "Esqueletos en ESP",
        ESPBoxes = "ESP: cajas",
        ESPHP = "ESP: barra de vida",
        ESPInfo = "ESP: líneas de info",
        ESPStatus = "ESP: estados y ruta",
    },
    pt = {
        MenuTitle = "GeminiBots - Gerenciamento de bots",
        MenuDesc = "Configuração em tempo real da IA dos bots padrão.",

        LangButton = "Idioma: PORTUGUÊS BR (clique: auto -> RU -> UK -> ES -> PT -> EN)",

        -- Seção 1
        HeaderGeneral = "Configurações gerais",
        Enabled = "Ativar a IA dos bots",
        CustomNames = "Apelidos personalizados únicos para bots",
        PreserveBots = "Restaurar bots ao trocar de mapa",
        HeaderAppearance = "Aparência",
        Appearance = "Aparência aleatória dos bots (modelos/skins)",
        AppearanceModel = "Modelos de jogador aleatórios",
        AppearanceSkin = "Skins de modelo aleatórias",
        AppearanceBodygroups = "Bodygroups aleatórios",
        AppearanceColor = "Cor de jogador aleatória",
        AppearanceRespawn = "Mudar aparência a cada renascimento",
        Debug = "Modo de depuração (saída no console)",
        DebugDraw = "Desenho de depuração no mundo (trajetórias, caminhos)",

        -- Seção 2
        HeaderLoadout = "Seleção de armas dos bots (Loadout & SWEPs)",
        LoadoutEnabled = "Dar armas aleatórias ao nascer",
        LoadoutStrip = "Remover ferramentas padrão (Sandbox)",
        LoadoutMin = "Nº mínimo de armas",
        LoadoutMax = "Nº máximo de armas",
        LoadoutAmmo = "Quantidade de munição de reserva",
        PresetHeader = "--- Presets rápidos do arsenal ---",
        PresetAll = "Ativar TODAS as armas",
        PresetHL2 = "Somente HL2 padrão",
        PresetM9K = "Todo o M9K (escanear servidor)",
        PresetPistols = "Somente pistolas",
        PresetRifles = "Somente fuzis e SMGs",
        PresetShotguns = "Somente escopetas",
        PresetSnipers = "Somente snipers",
        PresetNone = "Desativar tudo",
        WeaponListHeader = "--- Lista de armas do pool (Marque as desejadas) ---",
        WeaponNotInstalled = " [NÃO INSTALADA NO SERVIDOR]",
        AddWeaponHelp = "Adicionar arma pelo nome da classe (ex.: m9k_vector):",
        BtnAddWeapon = "Adicionar arma ao pool (+)",
        BtnAddHeldWeapon = "Pegar a arma da mão e adicionar ao pool dos bots",
        BtnGiveHeldWeapon = "Entregar instantaneamente a arma da mão a todos os bots",
        BtnReloadWeapons = "Recarregar weapons.txt do disco",
        BtnOpenArsenal = "ABRIR ARSENAL: escaneio + busca + filtros",
        WPackHeader = "--- Packs de armas (adaptadores de tática) ---",
        WPackFound = "detectado",
        WPackMissing = "não está no servidor",
        C4Enabled = "Bots plantam e desarmam C4 (precisa do SWCS)",

        -- Seção 3
        HeaderChat = "Chat e reações dos bots",
        ChatEnabled = "Permitir que os bots escrevam no chat",
        SmartContext = "Contexto inteligente de frases (K/D, sequências e cheats)",
        ChatKillChance = "Chance de deboche após eliminação",
        ChatDeathChance = "Chance de desculpa após a morte",
        ChatComebackChance = "Chance de resposta à acusação de um bot",
        ChatTauntChance = "Chance de provocação em combate (mira/camper)",
        FileLog = "Escrever log detalhado em arquivo (data/geminibots/logs/debug.log)",
        PacksHeader = "--- Packs de texto de frases (.txt) ---",
        PacksHelp = "Arquivos: garrysmod/data/geminibots/chat/\n(Marque com caixas os packs desejados):",
        PackStats = "%s  [Eliminações: %d | Mortes: %d]",
        BtnReloadPacks = "Recarregar packs .txt do disco",

        -- Seção 4
        HeaderPerception = "Sentidos, visão e memória",
        VisionFOV = "Campo de visão (FOV em graus)",
        VisionRange = "Alcance máximo de visão (unidades)",
        HearingRange = "Alcance auditivo de passos atrás de paredes (unidades)",
        GunHearingRange = "Alcance auditivo de tiros pelo mapa (unidades)",
        MemoryDuration = "Memória do alvo atrás de uma parede (seg)",
        TargetModeHeader = "--- Modo de alvos (quem atacar) ---",
        TargetBoth = "Todos indistintamente",
        TargetPvE = "PvE: NPCs primeiro",
        TargetPlayers = "Somente jogadores",
        TargetNPCs = "Somente NPCs",

        -- Seção 5
        HeaderCombat = "Mira e IA de combate",
        ReactionMin = "Atraso mínimo de reação (seg)",
        ReactionMax = "Atraso máximo de reação (seg)",
        AimSpeed = "Velocidade de giro da mira",
        AimSmoothing = "Suavização da mira (Lerp)",
        AimPrediction = "Antecipação do movimento do alvo (Lead Aim)",
        AimSpread = "Dispersão/erro de mira (graus)",
        HeadshotChance = "Chance de mirar na cabeça",
        CombatMinDist = "Distância mínima de combate (recuar)",
        CombatMaxDist = "Distância máxima de combate (aproximar)",
        FleeHealth = "Limiar de fuga (% de vida)",
        Wallbang = "Atirar através de vidro/frágil (wallbang)",

        HeaderSWCS = "SWCS: iscas, flash, fogo",
        SWCSHelp = "Iscas (decoy): investigar o som com chance (senão ignora). O flash do SWCS cega e ensurdece sempre. Fogo de molotov: afastar-se para o lado.",
        DecoyChance = "Chance de investigar o som de uma isca",
        FireAvoid = "Afastar-se do fogo do molotov",
        FireRadius = "Raio de reação ao fogo (unidades)",

        -- Seção 6
        HeaderMovement = "Movimento e bunny-hop",
        BunnyHop = "Bunny-hop ao andar (e sem inimigos)",
        BunnyHopChance = "Chance de pulo ao aterrissar",

        -- Seção 7
        HeaderDifficulty = "Presets de dificuldade",
        DifficultyHelp = "Configurações prontas. Ajuste abaixo e salve seu preset pelo campo.",
        BtnSavePreset = "Salvar as atuais como preset",
        BtnDeletePreset = "Excluir preset",
        PresetNameHelp = "Nome do seu preset:",

        -- Seção 8
        HeaderActions = "Ações rápidas",
        HeaderDebug = "Depuração",
        HeaderStates = "Estados da FSM",
        StatesHelp = "Desligado = o bot vai para idle em vez do estado. Idle não pode ser desligado.",
        BtnSpawnBot = "Criar bot (+1)",
        BtnSpawnMax = "Encher o servidor de bots (Máximo)",
        BtnKickAll = "Remover todos os bots do servidor",
        BtnRerollNames = "Randomizar os apelidos dos bots",
        BtnReloadNames = "Recarregar names.txt do disco",
        BtnRerollAppearance = "Mudar a aparência dos bots",
        BtnReloadAI = "Reiniciar a IA de todos os bots",
        BtnNavGen = "Gerar navmesh (nav_generate)",
        BtnReset = "Restaurar todas as configurações padrão",
        BtnSaveBots = "Salvar bots (transferência de mapa)",
        BtnRestoreBots = "Restaurar bots salvos",
        TeleportHelp = "--- Teleportes (há ponte ULX: !bringbots, !gotobot) ---",
        BtnBringBots = "Trazer TODOS os bots até mim",
        BotNickHelp = "Apelido do bot (parcial serve):",
        BtnBringOne = "Trazer este bot",
        BtnGotoBot = "Teleportar-se até o bot",
        BtnBotInfo = "Info de todos os bots (no console)",
        BtnBotInfoOne = "Info deste bot (no console)",
        ESPHelp = "--- ESP (caixas + info, só admins) ---",
        ESPEnabled = "ESP dos bots",
        ESPSkeleton = "Esqueletos no ESP",
        ESPBoxes = "ESP: caixas",
        ESPHP = "ESP: barra de HP",
        ESPInfo = "ESP: linhas de info",
        ESPStatus = "ESP: status e caminho",
    }
}

-- Текущий язык клиента: ручной выбор либо вживую из GMod
local currentLang = "ru"

-- Доступные языки меню (коды). "pt-br" из конвара нормализуется в "pt"
GeminiBots.MENU_LANGS = { "ru", "uk", "es", "pt", "en" }

local function T(key)
    local langTable = PHRASES[GeminiBots.GetMenuLang()] or PHRASES.en or PHRASES.ru
    return langTable[key] or key
end

-- Строка по языку меню: t = { ru = "..", uk = "..", es = "..", pt = "..", en = ".." }.
-- Своей строки нет — берем английскую. Клиентские файлы грузятся после cl_qmenu,
-- поэтому хелпер доступен всей теме, арсеналу и ESP
function GeminiBots.LangStr(t)
    local lang = GeminiBots.GetMenuLang()
    return t[lang] or t.en or t.ru or ""
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
                local customTag = GeminiBots.LangStr{
                    ru = "свой", uk = "свій", es = "personalizado",
                    pt = "personalizado", en = "custom" }
                defs[#defs + 1] = { label = presetId .. " (" .. customTag .. ")", fn = function()
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
        pnl:Help(GeminiBots.LangStr{
            ru = "Все настройки переехали в отдельное окно.",
            uk = "Усі налаштування переїхали в окреме вікно.",
            es = "Todos los ajustes se movieron a la ventana independiente.",
            pt = "Todas as configurações foram para a janela separada.",
            en = "All settings moved to the standalone window." })
        local btn = pnl:Button(GeminiBots.LangStr{
            ru = "ОТКРЫТЬ МЕНЮ", uk = "ВІДКРИТИ МЕНЮ",
            es = "ABRIR MENÚ", pt = "ABRIR MENU", en = "OPEN MENU" })
        btn.DoClick = function()
            RunConsoleCommand("geminibots_menu")
        end
        local btnArs = pnl:Button(GeminiBots.LangStr{
            ru = "ОТКРЫТЬ АРСЕНАЛ", uk = "ВІДКРИТИ АРСЕНАЛ",
            es = "ABRIR ARSENAL", pt = "ABRIR ARSENAL", en = "OPEN ARSENAL" })
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
    if v == "pt-br" then v = "pt" end
    for _, m in ipairs(GeminiBots.MENU_LANGS or {}) do
        if v == m then return v end
    end
    -- Авто: язык берем из GMod вживую — чел с англ. игрой сразу видит EN
    local gl = string.lower(GetConVar("gmod_language") and GetConVar("gmod_language"):GetString() or "")
    if string.find(gl, "ukrain") then return "uk" end
    if string.find(gl, "ru") then return "ru" end
    if string.find(gl, "spa") or string.find(gl, "espan") then return "es" end
    if string.find(gl, "portug") or string.find(gl, "^br") then return "pt" end
    return "en"
end

-- Ручной режим конвара (auto/ru/en): кнопка в шапке его крутит
function GeminiBots.MenuLangMode()
    local cv = GetConVar("geminibots_menu_lang")
    local v = cv and string.lower(cv:GetString() or "auto") or "auto"
    if v == "pt-br" then v = "pt" end
    for _, m in ipairs(GeminiBots.MENU_LANGS or {}) do
        if v == m then return v end
    end
    return "auto"
end

function GeminiBots.ToggleMenuLang()
    -- авто -> ru -> uk -> es -> pt -> en -> авто, выбор запоминается конваром
    local order = { "auto", "ru", "uk", "es", "pt", "en" }
    local cur = GeminiBots.MenuLangMode()
    local nextLang = "auto"
    for i, m in ipairs(order) do
        if m == cur then nextLang = order[(i % #order) + 1] break end
    end
    RunConsoleCommand("geminibots_menu_lang", nextLang)
    currentLang = GeminiBots.GetMenuLang()
    return currentLang
end
