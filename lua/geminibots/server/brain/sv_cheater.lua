--[[
    GeminiBots - Cheater Bots
    Боты-читеры: спавн только спецкомандой geminibots_cheater <тир>.
    Тиры: easy (легит — волхак), normal (аимботер — аим эксперта),
    hard (читак — волхак + реакция + всегда в голову),
    expert (хвх — все на максимум + спинбот).
    Стрельбы сквозь стены нет: пули движка бетон не пробивают.
    Анти-аим — крутилка: в бою целится как положено, без боя вертится.
]]

GeminiBots = GeminiBots or {}

local TIERS = {
    easy = {
        titleRU = "легит", titleEN = "legit", cheatId = 1,
        wallhack = true,
    },
    normal = {
        titleRU = "аим", titleEN = "aim", cheatId = 2,
        aim = { reactMin = 0.03, reactMax = 0.08, speed = 650,
            smoothing = 0.60, spread = 0.4, headshot = 0.65 },
    },
    hard = {
        titleRU = "читак", titleEN = "cheater", cheatId = 3,
        wallhack = true,
        aim = { reactMin = 0.03, reactMax = 0.08, speed = 650,
            smoothing = 0.60, spread = 0.4, headshot = 1.0 },
    },
    expert = {
        titleRU = "хвх", titleEN = "hvh", cheatId = 4,
        omni = true, spin = true,
        aim = { reactMin = 0.01, reactMax = 0.03, speed = 720,
            smoothing = 0.80, spread = 0.0, headshot = 1.0 },
    },
}

GeminiBots.CheaterTiers = TIERS

-- Параметры аима бота: у читера свои, у честных — из конфига
function GeminiBots.BotAim(bot)
    local a = bot and bot.cheater and bot.cheater.aim
    local cfg = GeminiBots.Config
    return {
        speed = (a and a.speed) or (cfg and cfg.AimSpeed) or 360,
        smoothing = (a and a.smoothing) or (cfg and cfg.AimSmoothing) or 0.25,
        spread = (a and a.spread) or (cfg and cfg.AimSpread) or 1.8,
        headshot = (a and a.headshot) or (cfg and cfg.HeadshotChance) or 0.35,
        reactMin = (a and a.reactMin) or (cfg and cfg.ReactionTimeMin) or 0.15,
        reactMax = (a and a.reactMax) or (cfg and cfg.ReactionTimeMax) or 0.35,
    }
end

concommand.Add("geminibots_cheater", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then
        print("[GeminiBots] geminibots_cheater: отказано (нужен админ).")
        return
    end
    if GeminiBots.MurderActive and GeminiBots.MurderActive() then
        local msg = "[GeminiBots] В Murder читерам не место."
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    local tier = string.lower(args[1] or "")
    if not TIERS[tier] then
        local msg = "[GeminiBots] Использование: geminibots_cheater <easy|normal|hard|expert>"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    print(string.format("[GeminiBots] geminibots_cheater: спавн читера (%s)...", tier))
    GeminiBots.PendingCheater = tier
    RunConsoleCommand("bot")
end, nil, "Заспавнить бота-читера: easy (легит), normal (аим), hard (читак), expert (хвх)")

-- Помечаем ближайшего заспавнившегося бота (загрузчик позже по порядку уже зарегистрировал)
hook.Add("PlayerInitialSpawn", "GeminiBots_Cheater_Flag", function(ply)
    if not IsValid(ply) or not ply:IsBot() then return end
    if not GeminiBots.PendingCheater then return end
    local tier = GeminiBots.PendingCheater
    GeminiBots.PendingCheater = nil
    timer.Simple(0.2, function()
        if not IsValid(ply) then return end
        local bot = GeminiBots:GetBot(ply) or GeminiBots:RegisterBot(ply)
        if bot and TIERS[tier] then
            bot.cheater = TIERS[tier]
            bot.cheatId = TIERS[tier].cheatId
            GeminiBots:Log("Бот %s — читер (%s).", ply:Nick(), tier)
        end
    end)
end)
