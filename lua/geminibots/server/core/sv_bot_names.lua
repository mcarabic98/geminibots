--[[
    GeminiBots - Bot Names Manager (Server)
    Загрузка пула имен из data/geminibots/names.txt, гарантированное назначение
    уникальных ников каждому боту и управление через команды/Q-меню.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.NamesPool = GeminiBots.NamesPool or {}

local DATA_DIR = "geminibots"
local NAMES_FILE = DATA_DIR .. "/names.txt"

-- Дефолтный резервный список на случай отсутствия файла
local DEFAULT_NAMES = {
    "Саня_Про", "Ваня_Нагибатор", "Димон_СВД", "Дед_Максим", "Токсик",
    "КиберКотлета", "Чебурек", "Сталкер_Петруха", "Кабан_1337", "Скибидист",
    "Банан_Убийца", "Серый_Волк", "Паша_Техник", "Пельмень_Боец", "Шнырь",
    "Гроза_Сервера", "Шустрый", "Михалыч", "Артем_2009", "Влад_Дракула",
    "Борщ_С_Капустой", "Мастер_АВП", "Снайпер_С_Крыши", "Леха_Тапок",
    "Курьер_Из_Ада", "Кринжовик", "Фарш_Машина", "Бутерброд", "Дядя_Богдан",
    "Ghost_Rider", "NoobMaster69", "xX_Shadow_Xx", "S1mple_Fan", "Blyatman",
    "Dr_Hax", "Gman_Enjoyer", "Valve_Employee", "GigaChad", "T-800",
    "Shooter_Boi", "Mr_Freeman", "Headshot_Machine", "Pudge_Mid", "Lag_Switch",
    "Clutch_King", "Speedy_Gonzales", "Gaben_Son", "Dead_Inside", "Hardcore_Gamer",
    "Agent_007", "Silent_Aim", "Pixel_Warrior", "Raptor", "Zero_Cool",
    "Viper", "FrostByte", "Neon_Ninja", "Bullet_Magnet", "Spawn_Camper"
}

-- Инициализация и загрузка файла с именами
function GeminiBots:LoadBotNames()
    self.NamesPool = {}

    if not file.IsDir(DATA_DIR, "DATA") then
        file.CreateDir(DATA_DIR)
    end

    -- Если файла нет в папке data, создаем его с дефолтными именами
    if not file.Exists(NAMES_FILE, "DATA") then
        local content = "# ==============================================================================\n" ..
                        "# GeminiBots - Список уникальных ников для ботов / Unique Bot Names List\n" ..
                        "# ==============================================================================\n\n"
        for _, name in ipairs(DEFAULT_NAMES) do
            content = content .. name .. "\n"
        end
        file.Write(NAMES_FILE, content)
        self:Log("Создан дефолтный файл имен: data/%s", NAMES_FILE)
    end

    local raw = file.Read(NAMES_FILE, "DATA")
    if not raw or raw == "" then
        self:Warn("Файл имен data/%s пуст! Используются резервные имена.", NAMES_FILE)
        self.NamesPool = table.Copy(DEFAULT_NAMES)
        return
    end

    local lines = string.Explode("\n", raw)
    for _, line in ipairs(lines) do
        local trimmed = string.Trim(line)
        -- Пропускаем пустые строки и комментарии
        if trimmed ~= "" and not string.StartWith(trimmed, "#") and not string.StartWith(trimmed, "//") and not string.StartWith(trimmed, "--") then
            table.insert(self.NamesPool, trimmed)
        end
    end

    if #self.NamesPool == 0 then
        self.NamesPool = table.Copy(DEFAULT_NAMES)
    end

    self:Log("Загружено уникальных ников ботов: %d", #self.NamesPool)
end

-- Свободный ник из пула (без назначения): для спавна с движковым именем
function GeminiBots:PickFreeNick(excludePly)
    if #self.NamesPool == 0 then
        self:LoadBotNames()
    end

    -- Собираем уже занятые ники на сервере
    local occupied = {}
    for _, p in ipairs(player.GetAll()) do
        if p ~= excludePly then
            local custom = p:GetNWString("GeminiBots_CustomNick", "")
            if custom ~= "" then
                occupied[custom] = true
            end
            occupied[p:Nick()] = true
        end
    end

    -- Ищем свободные имена из пула
    local available = {}
    for _, name in ipairs(self.NamesPool) do
        if not occupied[name] then
            table.insert(available, name)
        end
    end

    if #available > 0 then
        -- Случайный свободный ник
        return available[math.random(#available)]
    end

    -- Все ники заняты (ботов больше, чем имен в списке): вариант с суффиксом
    local base = self.NamesPool[math.random(#self.NamesPool)]
    for i = 2, 999 do
        local candidate = string.format("%s_%d", base, i)
        if not occupied[candidate] then
            return candidate
        end
    end
    return string.format("%s_%d", base, math.random(100, 999))
end

-- Назначить уникальный ник боту.
-- Движковое имя приоритетно: бот, созданный с именем (наш спавн через
-- CreateNextBot), уже зовется так везде — включая читы и сторонние табы.
-- NWString тогда лишь дублирует его для нашего кода
function GeminiBots:AssignBotName(ply, forcePool)
    if not IsValid(ply) or not ply:IsBot() then return end

    local cv = GetConVar("geminibots_custom_names")
    if cv and not cv:GetBool() then
        return
    end

    -- Реролл берет из пула принудительно, иначе движковое имя
    -- вернулось бы само в себя и ничего не сменилось
    if not forcePool then
        local engineNick = ply:Nick() or ""
        if engineNick ~= "" and not string.match(engineNick, "^Bot%d+$") then
            ply:SetNWString("GeminiBots_CustomNick", engineNick)
            return engineNick
        end
    end

    -- Если идет восстановление ботов после смены карты и есть сохраненный ник
    if self.RestoringBotNames and #self.RestoringBotNames > 0 then
        local restoredNick = table.remove(self.RestoringBotNames, 1)
        if restoredNick and restoredNick ~= "" then
            ply:SetNWString("GeminiBots_CustomNick", restoredNick)
            self:Log("Боту восстановлен прежний ник после смены карты: %s", restoredNick)
            return restoredNick
        end
    end

    -- Если пул еще не загружен, остальное решает PickFreeNick
    local chosenNick = self:PickFreeNick(ply)

    ply:SetNWString("GeminiBots_CustomNick", chosenNick)
    self:Log("Боту назначен уникальный ник: %s (стандартный: %s)", chosenNick, ply:EntIndex())
    return chosenNick
end

-- Перерандомизировать ники всех ботов на сервере
function GeminiBots:RerollAllBotNames(caller)
    if IsValid(caller) and not caller:IsSuperAdmin() and not caller:IsAdmin() and not game.SinglePlayer() then return end

    local bots = player.GetBots()
    if #bots == 0 then
        local msg = "[GeminiBots] На сервере нет ботов для переименования."
        if IsValid(caller) then caller:ChatPrint(msg) else print(msg) end
        return
    end

    -- Сначала сбрасываем старые кастомные ники у всех ботов
    for _, bot in ipairs(bots) do
        bot:SetNWString("GeminiBots_CustomNick", "")
    end

    -- Затем по очереди выдаем новые уникальные имена (из пула принудительно:
    -- движковое имя иначе вернулось бы само в себя)
    for _, bot in ipairs(bots) do
        GeminiBots:AssignBotName(bot, true)
    end

    local msg = string.format("[GeminiBots] Успешно переименовано ботов: %d", #bots)
    if IsValid(caller) then caller:ChatPrint(msg) else print(msg) end
    GeminiBots:Log(msg)
end

-- Хуки назначения ника
hook.Add("PlayerInitialSpawn", "GeminiBots_Names_InitialSpawn", function(ply)
    if ply:IsBot() then
        timer.Simple(0.05, function()
            if IsValid(ply) then
                GeminiBots:AssignBotName(ply)
            end
        end)
    end
end)

-- Консольные команды
concommand.Add("geminibots_names_reload", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    GeminiBots:LoadBotNames()
    local msg = string.format("[GeminiBots] Файл names.txt перезагружен. В пуле %d ников.", #GeminiBots.NamesPool)
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end, nil, "Перезагрузить список имен ботов из data/geminibots/names.txt")

concommand.Add("geminibots_names_reroll", function(ply, cmd, args)
    GeminiBots:RerollAllBotNames(ply)
end, nil, "Назначить новые уникальные случайные ники всем ботам на сервере")

-- Загружаем список имен при старте сервера
GeminiBots:LoadBotNames()
