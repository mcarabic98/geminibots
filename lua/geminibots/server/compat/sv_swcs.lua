--[[
    GeminiBots - SWCS Compatibility: decoy / flash / molotov reactions
    Тихо спит, если SWCS не стоит: сущностей swcs_* нет — триггеров нет.

    Механики SWCS (по декомпилу воркшопа 2193997180):
    - декои: энтити swcs_decoy_projectile, после приземления ~14 сек
      очередями издает звуки выстрелов + sound.EmitHint(SOUND_COMBAT);
    - флешка: swcs.RadiusFlash() ставит игрокам NW-переменную
      "BlindUntilTime" (см. PLAYER:SWCS_Blind в sh_player.lua), клиент
      рисует белый экран. У ботов своего зрения-глазами нет, поэтому
      читаем ту же NW-переменную и глушим сенсорику сами;
    - молик/зажигательная: снаряд swcs_molotov_projectile спавнит
      swcs_inferno (урон 40 dps, радиус ~150, живет ~7 сек).
]]

GeminiBots = GeminiBots or {}

-- Ослеплен ли игрок флешкой SWCS. Без самого SWCS всегда false.
function GeminiBots.SWCS_IsBlind(ply)
    if not IsValid(ply) then return false end
    local ok, untilT = pcall(function() return ply:GetNWFloat("BlindUntilTime", 0) end)
    if not ok or not untilT then return false end
    return untilT > CurTime()
end

-- Ослепленный бот: стоит, крутит головой, иногда приседает.
function GeminiBots.SWCS_BlindUpdate(bot)
    if not bot or not IsValid(bot.ply) then return end
    if not bot.wasBlind then
        bot.wasBlind = true
        bot.target = nil
        bot.lastKnownTargetPos = nil
        bot.investigatePos = nil
        bot.investigateKind = nil
        bot.forwardMove = 0
        bot.sideMove = 0
        GeminiBots.Navigator:Stop(bot)
    end
    -- Медленный поворот вслепую, иногда присесть
    if CurTime() >= (bot.nextBlindStumble or 0) then
        bot.nextBlindStumble = CurTime() + math.Rand(0.7, 1.4)
        local curYaw = bot.ply:EyeAngles().y
        bot.desiredViewAngles = Angle(math.Rand(-10, 5),
            math.NormalizeAngle(curYaw + math.Rand(-90, 90)), 0)
    end
    bot.buttons = 0
    if math.random() < 0.4 then
        bot.buttons = bit.bor(bot.buttons, IN_DUCK)
    end
end

-- Ближайший огонь молика рядом с точкой (класс swcs_inferno).
function GeminiBots.SWCS_NearestFire(pos, radius)
    if not pos then return nil end
    local nearest, best = nil, radius or 320
    for _, f in ipairs(ents.FindByClass("swcs_inferno")) do
        if IsValid(f) then
            local d = pos:Distance(f:GetPos())
            if d <= best then
                nearest, best = f, d
            end
        end
    end
    return nearest, best
end

-- Огонь рядом: бросаем маршрут и отходим в сторону (чуть боком,
-- чтобы обойти пятно, а не пятиться). Стрельбу не прерываем.
function GeminiBots.SWCS_AvoidFire(bot)
    if not bot or not IsValid(bot.ply) or not bot.ply:Alive() then return end
    local cfg = GeminiBots.Config
    local sw = cfg and cfg.SWCS
    if not sw or not sw.FireAvoid then return end
    if CurTime() < (bot.nextFireRepath or 0) then return end

    local radius = sw.FireRadius or 320
    local bpos = bot.ply:GetPos()
    local fire, dist = GeminiBots.SWCS_NearestFire(bpos, radius)
    if not fire then return end

    bot.nextFireRepath = CurTime() + 0.8
    local away = bpos - fire:GetPos()
    away.z = 0
    if away:LengthSqr() < 1 then away = Vector(1, 0, 0) end
    away:Normalize()
    -- Уходим чуть боком, чтобы обойти огонь, а не пятиться назад
    local sideSign = (math.random() < 0.5) and 0.5 or -0.5
    local dir = (away + Vector(-away.y, away.x, 0) * sideSign):GetNormalized()
    local target = bpos + dir * 450
    local tr = util.TraceLine({
        start = bpos + Vector(0, 0, 20),
        endpos = target + Vector(0, 0, 20),
        mask = MASK_SOLID_BRUSHONLY
    })
    local safe = tr.Hit and (tr.HitPos + tr.HitNormal * 60) or target
    GeminiBots.Navigator:MoveTo(bot, safe)
end

-- Декои: периодически проверяем активные. Бот в покое с шансом идет
-- на звук, отказ запоминаем и этот декои больше не трогаем.
timer.Create("GeminiBots_SWCS_DecoyScan", 0.7, 0, function()
    local cfg = GeminiBots.Config
    if not cfg or not cfg.Enabled then return end
    local sw = cfg.SWCS
    local chance = sw and sw.DecoyChance or 0.40
    if chance <= 0 then return end

    local decoys = ents.FindByClass("swcs_decoy_projectile")
    if #decoys == 0 then return end

    local gunRange = cfg.GunHearingRange or 3000
    for _, dec in ipairs(decoys) do
        if not IsValid(dec) then continue end
        local dpos = dec:GetPos()
        local key = dec:EntIndex()
        for _, bot in pairs(GeminiBots:GetAllBots()) do
            if not IsValid(bot.ply) or not bot.ply:Alive() then continue end
            -- Реагируем только в покое или на проверке другого звука
            if bot.state ~= "idle" and bot.state ~= "wander"
                and bot.state ~= "investigate" then continue end
            -- Ослепленный ничего не слышит
            if GeminiBots.SWCS_IsBlind(bot.ply) then continue end
            bot.swcsDecoys = bot.swcsDecoys or {}
            if bot.swcsDecoys[key] then continue end
            if bot.ply:GetPos():Distance(dpos) > gunRange then continue end
            -- Один ролл на декои: дальше игнор
            bot.swcsDecoys[key] = true
            if table.Count(bot.swcsDecoys) > 40 then bot.swcsDecoys = {} end
            if math.random() > chance then continue end
            bot.investigatePos = dpos + Vector(math.Rand(-60, 60), math.Rand(-60, 60), 0)
            bot.investigateTime = CurTime()
            bot.investigateKind = "decoy"
            bot.desiredViewAngles = (dpos - bot.ply:EyePos()):Angle()
            GeminiBots.FSM:SetState(bot, "wander")
        end
    end
end)
