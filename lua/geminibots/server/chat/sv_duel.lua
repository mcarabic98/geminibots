--[[
    GeminiBots - Duels & Social Chat (Server)
    Живое общение из чата: приветствия, "gg", дуэли "го на <оружие>".
    Дуэль: бот берет названный ствол и дерется только с вызвавшим
    (должен видеть его). Смена ствола противником — жалоба в чат.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Duels = GeminiBots.Duels or {}

-- Токсик-пак активен? От этого зависит тон ответов.
function GeminiBots.Chat:IsToxicActive()
    return self:IsPackActive("toxic_hard_ru_en.txt") or self:IsPackActive("toxic_ru.txt")
end

-- Взять случайную фразу чат-категории (GREETING, GG, DUEL...), nil если пусто
function GeminiBots.Chat:PickChatPhrase(event, fallbackEvent)
    local list = self:GatherPhrases("chat", event)
    if #list == 0 and fallbackEvent then
        list = self:GatherPhrases("chat", fallbackEvent)
    end
    if #list == 0 then
        GeminiBots.FileLog("pick", "EMPTY chat pool event=%s (привет/gg/дуэль промолчит)", event)
        return nil
    end
    return list[math.random(#list)]
end

-- Первое слово без концевой пунктуации ("hi" не должно ловиться в "this")
local function FirstWord(low)
    local w = string.match(low or "", "^(%S+)")
    if not w then return "" end
    w = string.gsub(w, "[%p]+$", "")
    return w
end

local GREETINGS = {
    ["привет"] = 1, ["здравствуй"] = 1, ["здарова"] = 1, ["здаров"] = 1,
    ["хай"] = 1, ["hi"] = 1, ["hello"] = 1, ["hey"] = 1,
    ["yo"] = 1, ["sup"] = 1
}

local GREET_PREFIXES = { "добрый ", "good morning", "good evening", "good afternoon" }

local GG_WORDS = { ["gg"] = 1, ["ggwp"] = 1, ["гг"] = 1 }

-- Дуэльное оружие: ключевые слова -> подпись для фраз -> классы на выбор
local DUEL_WEAPONS = {
    { keys = { "нож", "ножи", "ножам", "ножах", "ноже", "ножик", "knife", "knives" }, display = "ножах", classes = { "weapon_crowbar" } },
    { keys = { "пистолет", "пистолетах", "пистолете", "пистолеты", "пм", "pistol", "pistols" }, display = "пистолетах", classes = { "weapon_pistol", "m9k_colt1911", "m9k_glock", "m9k_usp" } },
    { keys = { "дипл", "дигле", "диглах", "дигл", "deagle" }, display = "диглах", classes = { "m9k_deagle", "weapon_357" } },
    { keys = { "дробовик", "дробовиках", "дробь", "shotgun", "shotguns" }, display = "дробовиках", classes = { "weapon_shotgun", "m9k_remington870", "m9k_spas12" } },
    { keys = { "калаш", "калашах", "калаше", "ак", "ак-47", "ak47", "ak-47", "автомат", "kalash" }, display = "калашах", classes = { "m9k_ak47", "weapon_ar2", "weapon_smg1" } },
    { keys = { "снайпер", "снайперка", "снайперках", "авп", "awp", "sniper" }, display = "снайперках", classes = { "m9k_awp", "weapon_crossbow" } }
}

local function FindDuelWeapon(rest)
    local padded = " " .. (rest or "") .. " "
    for _, entry in ipairs(DUEL_WEAPONS) do
        for _, key in ipairs(entry.keys) do
            if string.find(padded, " " .. key .. " ", 1, true) then
                return entry
            end
        end
    end
    return nil
end

-- Случайный живой бот (для ответов в общий чат)
local function RandomAliveBot()
    local alive = {}
    for _, b in ipairs(player.GetBots()) do
        if IsValid(b) and b:Alive() then table.insert(alive, b) end
    end
    if #alive == 0 then return nil end
    return alive[math.random(#alive)]
end

local function SocialSay(botPly, template, speakerNick)
    if not template or not IsValid(botPly) then return end
    local cfg = GeminiBots.Config and GeminiBots.Config.Chat
    if not cfg then return end
    local msg = string.Replace(template, "{victim}", speakerNick or "друг")
    msg = string.Replace(msg, "{killer}", botPly:Nick())
    GeminiBots.Chat:SayWithDelay(botPly, msg, math.Rand(cfg.MinTypingDelay or 0.6, cfg.MaxTypingDelay or 1.8))
end

-- Ближайший живой бот, который прямо сейчас видит вызывающего
local function FindDuelBot(challenger)
    local best, bestDist = nil, math.huge
    local cpos = challenger:GetPos()
    for _, botPly in ipairs(player.GetBots()) do
        if not IsValid(botPly) or not botPly:Alive() then continue end
        if GeminiBots.Duels[botPly] then continue end
        local bot = GeminiBots:GetBot(botPly)
        if not bot then continue end
        if not GeminiBots.Vision:HasLineOfSight(bot, challenger) then continue end
        local d = botPly:GetPos():Distance(cpos)
        if d < bestDist then
            bestDist = d
            best = botPly
        end
    end
    return best
end

-- Старт дуэли: бот берет ствол и дерется только с вызвавшим
local function StartDuel(challenger, entry)
    local botPly = FindDuelBot(challenger)
    if not botPly then return end

    local class = nil
    for _, cand in ipairs(entry.classes) do
        if GeminiBots.Loadout:IsWeaponAvailable(cand) then
            class = cand
            break
        end
    end
    if not class then return end

    if not botPly:HasWeapon(class) then
        if not GeminiBots.Loadout:SafeGive(botPly, class) then return end
    end
    botPly:SelectWeapon(class)

    GeminiBots.Duels[botPly] = {
        enemy = challenger,
        class = class,
        display = entry.display,
        since = CurTime()
    }

    local toxic = GeminiBots.Chat:IsToxicActive()
    local tpl = GeminiBots.Chat:PickChatPhrase(toxic and "DUEL_TOXIC" or "DUEL", "DUEL")
    if tpl then
        tpl = string.Replace(tpl, "{duel}", entry.display)
        SocialSay(botPly, tpl, challenger:Nick())
    end
end

-- Жалоба на смену ствола противником ("так мы на ножах...")
function GeminiBots.DuelNag(bot, duel)
    local enemy = duel.enemy
    if not IsValid(enemy) then return end
    local toxic = GeminiBots.Chat:IsToxicActive()
    local tpl = GeminiBots.Chat:PickChatPhrase(toxic and "DUEL_NAG_TOXIC" or "DUEL_NAG", "DUEL_NAG")
    if not tpl then return end

    local egun = "ствол"
    local ew = enemy:GetActiveWeapon()
    if IsValid(ew) then
        egun = GeminiBots.Loadout:GetWeaponPrintName(ew:GetClass())
        egun = string.match(egun, "^(.-)%s*%(") or egun
    end

    tpl = string.Replace(tpl, "{duel}", duel.display)
    tpl = string.Replace(tpl, "{egun}", egun)
    SocialSay(bot.ply, tpl, enemy:Nick())
end

-- Конец дуэли, если участник умер или дуэлянт убил постороннего
hook.Add("PlayerDeath", "GeminiBots_Duel_End", function(victim, _, attacker)
    if not GeminiBots.Duels then return end
    for botPly, duel in pairs(GeminiBots.Duels) do
        if botPly == victim or duel.enemy == victim then
            GeminiBots.Duels[botPly] = nil
        elseif botPly == attacker and duel.enemy ~= victim then
            GeminiBots.Duels[botPly] = nil
        end
    end
end)

hook.Add("PlayerDisconnected", "GeminiBots_Duel_Cleanup", function(ply)
    if not GeminiBots.Duels then return end
    GeminiBots.Duels[ply] = nil
    for botPly, duel in pairs(GeminiBots.Duels) do
        if duel.enemy == ply then GeminiBots.Duels[botPly] = nil end
    end
end)

-- Живой чат: приветствия, gg, вызовы на дуэль "го на <оружие>"
hook.Add("PlayerSay", "GeminiBots_Chat_Social", function(ply, text)
    if not IsValid(ply) or ply:IsBot() then return end

    local cfg = GeminiBots.Config and GeminiBots.Config.Chat
    if not cfg or not cfg.Enabled then return end

    local low = GeminiBots.Utf8Lower(string.Trim(text or ""))
    if low == "" then return end
    GeminiBots.FileLog("social", "from=%s say=[%s]", ply:Nick(), string.sub(low, 1, 80))

    -- 1. Дуэль "го на ножах" (свой кулдаун, не делит общий социальный).
    -- Кириллицу режем паттерном, а не смещением: sub считает байты
    local rest = string.match(low, "^го на%s+(.+)$") or string.match(low, "^го%s+(.+)$")
    if rest then
        -- В Murder дуэлей нет: там свое оружие режима
        if GeminiBots.MurderActive and GeminiBots.MurderActive() then return end
        -- Дуэль только вживую: с трупом драться не с кем.
        if not ply:Alive() then return end
        GeminiBots.Chat.DuelCD = GeminiBots.Chat.DuelCD or {}
        if CurTime() >= (GeminiBots.Chat.DuelCD[ply] or 0) then
            local entry = FindDuelWeapon(rest)
            if entry then
                GeminiBots.Chat.DuelCD[ply] = CurTime() + 90
                StartDuel(ply, entry)
                return
            end
        else
            return
        end
    end

    -- Общий социальный кулдаун (привет/gg)
    if CurTime() < (GeminiBots.Chat.SocialCD or 0) then
        GeminiBots.FileLog("social", "BLOCK cooldown (SocialCD)")
        return
    end

    local first = FirstWord(low)
    local toxic = GeminiBots.Chat:IsToxicActive()

    -- 2. Приветствие: в токсике вместо "привет" — "ты кто ваще"
    local isGreet = GREETINGS[first] == 1
    if not isGreet then
        for _, prefix in ipairs(GREET_PREFIXES) do
            if string.StartWith(low, prefix) then
                isGreet = true
                break
            end
        end
    end
    if isGreet then
        local botPly = RandomAliveBot()
        if not botPly then
            GeminiBots.FileLog("social", "greet: NO alive bot to answer")
            return
        end
        local tpl = GeminiBots.Chat:PickChatPhrase(toxic and "GREETING_TOXIC" or "GREETING", "GREETING")
        if not tpl then
            GeminiBots.FileLog("social", "greet: tpl=nil (пул приветствий пуст)")
            return
        end
        GeminiBots.FileLog("social", "greet: %s answers [%s]", botPly:Nick(), string.sub(tpl, 1, 80))
        GeminiBots.Chat.SocialCD = CurTime() + 20
        SocialSay(botPly, tpl, ply:Nick())
        return
    end

    -- 3. "gg": спасибо. В токсике — игнор.
    if GG_WORDS[first] == 1 then
        if toxic then return end
        local botPly = RandomAliveBot()
        if not botPly then return end
        local tpl = GeminiBots.Chat:PickChatPhrase("GG", nil)
        if not tpl then return end
        GeminiBots.Chat.SocialCD = CurTime() + 20
        SocialSay(botPly, tpl, ply:Nick())
        return
    end
end)
