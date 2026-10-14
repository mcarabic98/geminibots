--[[
    GeminiBots - C4 Director (SWCS)
    Раз в секунду разруливает бомбу: назначает подрывника (выдает C4),
    отправляет подрывника ставить, остальных — искать и разминировать.
    Без SWCS или без живых бомб спит. В Murder не работает.

    Механика SWCS: ставит где угодно (зоны нет), держать атаку 3 сек.
    Бомба swcs_planted_c4, таймер mp_c4timer (дефолт 40 сек), взрыв
    500 урона на 1750. Дефуз — держать E: 10 сек без набора, 5 с набором.
]]

GeminiBots = GeminiBots or {}

local C4_CLASS = "weapon_swcs_c4"
local BOMB_CLASS = "swcs_planted_c4"
local SEEK_DIST = 100 -- ближе — уже разминируем, дальше — идем искать
local ASSIGN_COOLDOWN = 45 -- пауза между подрывниками
local ALONE_RADIUS = 1500 -- свидетели: живые игроки ближе — ставить нельзя
local ALONE_TIME = 5.0 -- сколько никого не должно быть рядом перед установкой

-- Живая бомба рядом с точкой (тикает и не разминирована)
function GeminiBots.C4_NearestLiveBomb(pos, radius)
    if not pos then return nil end
    local best, bestDist = nil, radius or 1e9
    for _, b in ipairs(ents.FindByClass(BOMB_CLASS)) do
        if IsValid(b) then
            local ok, ticking, defused = pcall(function()
                return b:GetBombTicking(), b:GetBombDefused()
            end)
            if ok and ticking and not defused then
                local d = pos:Distance(b:GetPos())
                if d <= bestDist then
                    best, bestDist = b, d
                end
            end
        end
    end
    return best, bestDist
end

-- Рядом никого живого (кроме себя): без свидетелей
function GeminiBots.C4_IsAlone(bot, radius)
    if not bot or not IsValid(bot.ply) then return false end
    local bp = bot.ply:GetPos()
    for _, p in ipairs(player.GetAll()) do
        if p ~= bot.ply and IsValid(p) and p:Alive() then
            if p:GetObserverMode() == OBS_MODE_NONE
                and bp:Distance(p:GetPos()) <= radius then
                return false
            end
        end
    end
    return true
end

-- Сводка по бомбе: тикает ли, сколько осталось, кто дефузит,
-- сколько нужно мне (набор 5 сек, без 10 + запас)
function GeminiBots.C4_Info(bomb)
    if not IsValid(bomb) then return nil end
    local ok, ticking, defused, blow, defuser = pcall(function()
        return bomb:GetBombTicking(), bomb:GetBombDefused(),
            bomb:GetC4Blow(), bomb:GetBombDefuser()
    end)
    if not ok or not ticking or defused then return nil end
    return {
        remain = (blow or 0) - CurTime(),
        defuser = IsValid(defuser) and defuser or nil,
    }
end

-- Сколько секунд дефуза нужно этому боту (набор проверяет сам SWCS)
function GeminiBots.C4_Needed(ply)
    local ok, has = pcall(function()
        if ply.HasDefuser then return ply:HasDefuser() end
        return ply:GetNWBool("SWCS.Defuser", false)
    end)
    return ((ok and has) and 5 or 10) + 2
end

local function SWCSReady()
    return weapons.Get(C4_CLASS) ~= nil
end

timer.Create("GeminiBots_C4_Think", 1.0, 0, function()
    local cfg = GeminiBots.Config
    if not cfg or not cfg.Enabled or not cfg.C4Enabled then return end
    if GeminiBots.MurderActive and GeminiBots.MurderActive() then return end
    -- HL2DM: детматчу минирование не нужно — там уже был игрок со взрывчаткой
    if GeminiBots.HL2MPActive and GeminiBots.HL2MPActive() then return end
    if not SWCSReady() then return end

    local liveBomb = GeminiBots.C4_NearestLiveBomb(Vector(0, 0, 0), 1e9)

    -- Чистим протухшие ссылки на свою бомбу
    for _, bot in pairs(GeminiBots:GetAllBots()) do
        if bot.plantedBomb and not IsValid(bot.plantedBomb) then
            bot.plantedBomb = nil
        end
        if bot.plantArmed and (not IsValid(bot.ply)
            or not bot.ply:HasWeapon(C4_CLASS)) then
            bot.plantArmed = nil
        end
    end

    -- Назначение подрывника: живой бомбы нет, ботов хватает
    if not liveBomb and CurTime() >= (GeminiBots.NextC4Assign or 0) then
        local candidates = {}
        for _, bot in pairs(GeminiBots:GetAllBots()) do
            if IsValid(bot.ply) and bot.ply:Alive()
                and (bot.state == "idle" or bot.state == "wander")
                and not IsValid(bot.target)
                and not bot.plantArmed
                and not bot.ply:HasWeapon(C4_CLASS)
                and not (GeminiBots.SWCS_IsBlind
                    and GeminiBots.SWCS_IsBlind(bot.ply)) then
                table.insert(candidates, bot)
            end
        end
        -- Подрывник + кому искать: минимум двое
        if #candidates >= 2 then
            local pick = candidates[math.random(#candidates)]
            local wep = GeminiBots.Loadout:SafeGive(pick.ply, C4_CLASS)
            if IsValid(wep) then
                pick.plantArmed = true
                GeminiBots.NextC4Assign = CurTime() + ASSIGN_COOLDOWN
            end
        end
    end

    for _, bot in pairs(GeminiBots:GetAllBots()) do
        if not IsValid(bot.ply) or not bot.ply:Alive() then continue end
        local st = bot.state

        -- Подрывник идет ставить: в покое, без цели, с земли и без свидетелей
        if bot.plantArmed and not liveBomb
            and (st == "idle" or st == "wander" or st == "investigate")
            and not IsValid(bot.target)
            and bot.ply:IsOnGround()
            and bot.ply:HasWeapon(C4_CLASS) then
            -- Рядом никого: копим одиночество, ставим после паузы
            if GeminiBots.C4_IsAlone(bot, ALONE_RADIUS) then
                if not bot.aloneSince then bot.aloneSince = CurTime() end
                if CurTime() - bot.aloneSince >= ALONE_TIME then
                    bot.aloneSince = nil
                    GeminiBots.FSM:SetState(bot, "plant")
                end
            else
                bot.aloneSince = nil
            end
            continue
        end

        -- Дальше только живая бомба и чужая (свою подрывник игнорит)
        if not liveBomb then continue end
        if bot.plantedBomb == liveBomb then continue end
        if GeminiBots.SWCS_IsBlind and GeminiBots.SWCS_IsBlind(bot.ply) then continue end
        if st ~= "idle" and st ~= "wander" and st ~= "investigate" then continue end
        if st == "investigate" and bot.investigateKind ~= "c4" then continue end

        local info = GeminiBots.C4_Info(liveBomb)
        if not info then continue end
        local needed = GeminiBots.C4_Needed(bot.ply)
        local dist = bot.ply:GetPos():Distance(liveBomb:GetPos())

        -- Кто-то уже работает: не толпимся, при гибели — бежим
        if info.defuser and info.defuser ~= bot.ply then
            if info.remain < needed
                and (st == "idle" or st == "wander"
                    or (st == "investigate" and bot.investigateKind == "c4")) then
                bot.fleeBomb = liveBomb
                bot.fleeNoTime = true
                GeminiBots.FSM:SetState(bot, "flee")
            end
            continue
        end

        -- Не хватит времени: убегаем
        if info.remain < needed then
            bot.fleeBomb = liveBomb
            bot.fleeNoTime = true
            GeminiBots.FSM:SetState(bot, "flee")
            continue
        end

        -- Далеко — идем искать, близко — разминируем.
        -- Повторно в тот же дефуз не дергаем: сбросит путь и бот встанет
        if dist > SEEK_DIST then
            if st == "idle" or st == "wander" then
                bot.investigatePos = liveBomb:GetPos()
                bot.investigateTime = CurTime()
                bot.investigateKind = "c4"
                GeminiBots.FSM:SetState(bot, "wander")
            end
        elseif bot.state ~= "defuse" or bot.defuseBomb ~= liveBomb then
            GeminiBots.FSM:SetState(bot, "defuse", liveBomb)
        end
    end
end)
