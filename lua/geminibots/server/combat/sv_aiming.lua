--[[
    GeminiBots - Aiming & Ballistics System
    Расчет углов наведения, упреждение движения цели (Lead Aim) и естественный разброс.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Aiming = GeminiBots.Aiming or {}

util.AddNetworkString("GeminiBots_Trajectory")

-- Скорость броска гранаты: 1000 дает рабочие навесы.
GeminiBots.Aiming.FragThrowSpeed = 1000

-- Скорость снаряда для упреждения: у РПГ ракета медленная, у пуль — быстрая
function GeminiBots.Aiming:ProjectileSpeed(wepClass)
    if wepClass and string.find(string.lower(wepClass), "rpg", 1, true) then
        return 1500
    end
    return 6000
end

local CachedGravity = nil
local CachedGravityAt = -9999

-- Расчет точки и углов прицеливания в цель.
-- Голова/торс и разброс роллятся раз на цель (и раз в 2 сек), а не каждый
-- тик: иначе desired скачет, aimReady не стабилизируется и бот вечно недоводит
function GeminiBots.Aiming:CalculateAimAngles(bot, target)
    if not bot or not IsValid(bot.ply) or not IsValid(target) then
        return Angle(0, 0, 0)
    end

    if bot.aimTarget ~= target or CurTime() - (bot.aimRollTime or 0) > 2 then
        bot.aimTarget = target
        bot.aimRollTime = CurTime()
        local am = GeminiBots.BotAim(bot)
        bot.aimHead = math.random() <= (am.headshot or 0.35)
        -- Разброс тоже может прийти битым (NaN/отрицательный): math.Rand(NaN,..)
        -- заражал прицел NaN-ом, а math.Clamp(NaN,-89,89) потом возвращает 89
        local sp = am.spread or 0
        if sp ~= sp or sp < 0 then sp = 0 elseif sp > 10 then sp = 10 end
        bot.aimSpreadP = math.Rand(-sp, sp) * 0.5
        bot.aimSpreadY = math.Rand(-sp, sp) * 0.5
    end

    local cfg = GeminiBots.Config
    local eyePos = bot.ply:EyePos()

    -- 1. Выбор точки попадания (голова или торс)
    local aimPos = target:WorldSpaceCenter()

    if bot.aimHead then
        local okH, headPos = pcall(function() return target:EyePos() end)
        if okH and headPos then aimPos = headPos end
    end

    -- 2. Упреждение движения цели (Lead Aim).
    -- Только горизонталь: прыжок цели иначе уводит точку в небо.
    -- Хитскан мгновенный: целим в текущую точку, а не с упреждением
    -- (на 2500 юнитов упреждение давало ~200 мимо по стрейфу).
    -- Плоское: прыжки не предсказываем
    if cfg and cfg.AimPrediction then
        local dist = eyePos:Distance(aimPos)
        local activeWep = bot.ply:GetActiveWeapon()
        local projectileSpeed = self:ProjectileSpeed(IsValid(activeWep) and activeWep:GetClass() or "")
        local timeToHit = 0
        if projectileSpeed < 6000 then
            timeToHit = dist / projectileSpeed
        end

        -- Скорость цели тоже бывает битой (NaN из физики): NaN * 0 = NaN,
        -- поэтому при хитскане (timeToHit = 0) заражение все равно проходило
        local targetVel = target:GetVelocity()
        if targetVel.x ~= targetVel.x or targetVel.y ~= targetVel.y
            or targetVel.z ~= targetVel.z then
            targetVel = Vector(0, 0, 0)
        end
        targetVel.z = 0
        aimPos = aimPos + targetVel * timeToHit
    end

    -- 3. Вычисление базовых углов. Клинч (точки совпали) дает вырожденный
    -- угол (движок вернет pitch 90): держим прошлый прицел вместо взлета
    local toTarget = (aimPos - eyePos)
    if toTarget:LengthSqr() < 1 then
        return bot.lastAimAngles or Angle(0, 0, 0)
    end
    local aimAngle = toTarget:Angle()
    local baseP = aimAngle.p

    -- 3.5 NaN-страховка ДО разброса: math.Clamp(NaN,-89,89) вернул бы 89 и
    -- замаскировал заражение (проверка после клампа уже видит 89, а не NaN).
    -- Битый вектор (скорость/EyePos цели) давал pitch 89 при верном yaw
    if baseP ~= baseP or aimAngle.y ~= aimAngle.y
        or toTarget.x ~= toTarget.x or toTarget.y ~= toTarget.y or toTarget.z ~= toTarget.z then
        if CurTime() >= (bot.aimNaNWarn or 0) then
            bot.aimNaNWarn = CurTime() + 5
            print(string.format(
                "[GeminiBots][aimNaN] %s baseP=%s dir=%s aimPos=%s vel=%s eye=%s wsc=%s",
                bot.ply:Nick(), tostring(baseP), tostring(toTarget), tostring(aimPos),
                tostring(target:GetVelocity()), tostring(eyePos),
                tostring(target:WorldSpaceCenter())))
        end
        local dir = target:WorldSpaceCenter() - eyePos
        if dir:LengthSqr() >= 1 and dir.x == dir.x and dir.y == dir.y and dir.z == dir.z then
            aimAngle = dir:Angle()
        else
            aimAngle = bot.lastAimAngles or Angle(0, 0, 0)
        end
        baseP = aimAngle.p
    end

    -- 4. Добавление естественного разброса (Inaccuracy).
    -- Разброс санируем: битый/абсурдный (>20 град) сам клампится в 89
    local spreadP, spreadY = bot.aimSpreadP or 0, bot.aimSpreadY or 0
    if spreadP ~= spreadP or spreadP > 20 or spreadP < -20 then spreadP = 0 end
    if spreadY ~= spreadY or spreadY > 20 or spreadY < -20 then spreadY = 0 end
    if spreadP ~= 0 or spreadY ~= 0 then
        aimAngle.p = math.Clamp(aimAngle.p + spreadP, -89, 89)
        aimAngle.y = math.NormalizeAngle(aimAngle.y + spreadY)
    end

    -- Страховка от битой точки прицела: у чужих ботов EyePos иногда отдает
    -- точку почти под ногами, и взгляд падает в пол (pitch 89), хотя в центр
    -- цели смотреть почти ровно. Тогда честно берем центр цели
    local center = target:WorldSpaceCenter()
    local centerDir = center - eyePos
    if centerDir:LengthSqr() >= 1
        and centerDir.x == centerDir.x and centerDir.y == centerDir.y
        and centerDir.z == centerDir.z then
        local centerPitch = centerDir:Angle().p
        if math.abs(aimAngle.p) > 60 and math.abs(centerPitch) < 30 then
            if CurTime() >= (bot.aimBogusWarn or 0) then
                bot.aimBogusWarn = CurTime() + 5
                print(string.format(
                    "[GeminiBots][aimFix] %s head=%s baseP=%.0f rawP=%.0f centerP=%.0f spP=%s spY=%s aimPos=%s eye=%s wsc=%s tgtEye=%s",
                    bot.ply:Nick(), tostring(bot.aimHead), baseP, aimAngle.p, centerPitch,
                    tostring(bot.aimSpreadP), tostring(bot.aimSpreadY), tostring(aimPos),
                    tostring(eyePos), tostring(center), tostring(target:EyePos())))
            end
            aimAngle = centerDir:Angle()
        end
    end

    return aimAngle
end

-- Проверка, наведен ли прицел бота достаточно близко к цели для выстрела
function GeminiBots.Aiming:IsAimReady(bot, targetAngle, thresholdDeg)
    if not targetAngle then return false end
    local threshold = thresholdDeg or 12
    local curAngle = bot.currentViewAngles or bot.ply:EyeAngles()

    local diffP = math.abs(math.AngleDifference(curAngle.p, targetAngle.p))
    local diffY = math.abs(math.AngleDifference(curAngle.y, targetAngle.y))

    return (diffP <= threshold) and (diffY <= threshold)
end

-- Расчет навесного броска гранаты в точку цели.
-- Возвращает: углы броска, предсказанную точку падения, точки траектории.
function GeminiBots.Aiming:CalculateLobAngles(bot, targetPos, throwSpeed)
    local eyePos = bot.ply:EyePos()

    -- Гравитацию обновляем раз в минуту: смена среди игры подхватывается,
    -- каждый тик GetConVar не дергаем
    if not CachedGravity or CurTime() - CachedGravityAt > 60 then
        local gravCvar = GetConVar("sv_gravity")
        CachedGravity = (gravCvar and gravCvar:GetFloat()) or 600
        CachedGravityAt = CurTime()
    end
    local g = CachedGravity

    local v = throwSpeed or self.FragThrowSpeed or 1000

    local toT = targetPos - eyePos
    local dx = math.max(1, Vector(toT.x, toT.y, 0):Length())
    local dy = toT.z

    -- Уравнение дальности, пологая ветвь (низкий навес = быстрее долетит)
    local v2 = v * v
    local disc = v2 * v2 - g * (g * dx * dx + 2 * dy * v2)

    local pitch
    local landed = nil
    if disc <= 0 then
        -- Не долетит (цель выше под балконом): точки падения нет,
        -- гейт в бою такой бросок придержит
        pitch = math.rad(45)
    else
        pitch = math.atan((v2 - math.sqrt(disc)) / (g * dx))
    end
    pitch = math.Clamp(pitch, math.rad(5), math.rad(75))

    local yaw = math.deg(math.atan2(toT.y, toT.x))
    local angles = Angle(-math.deg(pitch), yaw, 0)

    -- Симуляция полета для проверки точки падения и дебаг-отрисовки
    local points = self:PredictThrowPoints(eyePos, angles, v, targetPos.z)
    if disc > 0 then landed = points[#points] end

    return angles, landed, points
end

-- Чистая симуляция полета гранаты: старт, углы, скорость -> точки дуги.
-- stopZ: остановить, когда снаряд опустится ниже (падение на уровень цели).
function GeminiBots.Aiming:PredictThrowPoints(startPos, angles, throwSpeed, stopZ)
    local g = CachedGravity or 600

    local v = throwSpeed or self.FragThrowSpeed or 1000
    local dir = angles:Forward()
    local pos = Vector(startPos.x, startPos.y, startPos.z)
    local vel = dir * v
    local dt = 0.05

    local points = { Vector(pos.x, pos.y, pos.z) }

    for i = 1, 60 do
        vel.z = vel.z - g * dt
        pos = pos + vel * dt
        table.insert(points, Vector(pos.x, pos.y, pos.z))
        if stopZ and pos.z <= stopZ and vel.z < 0 then break end
    end

    return points
end

-- Разослать траекторию клиентам для отрисовки (не зависит от developer).
-- Точки прореживаются до ~14, хватает для гладкой дуги.
function GeminiBots.Aiming:BroadcastTrajectory(throwerEnt, points, landing, r, g, b)
    if not IsValid(throwerEnt) then return end
    if not points or #points < 2 then return end

    local step = math.max(1, math.floor(#points / 14))
    local slim = {}
    for i = 1, #points, step do
        table.insert(slim, points[i])
    end
    if slim[#slim] ~= points[#points] then
        table.insert(slim, points[#points])
    end

    net.Start("GeminiBots_Trajectory")
    net.WriteEntity(throwerEnt)
    net.WriteUInt(#slim, 8)
    for _, p in ipairs(slim) do
        net.WriteVector(p)
    end
    net.WriteVector(landing or slim[#slim])
    net.WriteUInt(r or 255, 8)
    net.WriteUInt(g or 150, 8)
    net.WriteUInt(b or 0, 8)
    net.Broadcast()
end

-- Превью дуги для живого игрока с гранатой в руках (циан, у ботов оранжевая).
-- Точки уходят по сети, штатный дебаг с дедика не видно.
hook.Add("Think", "GeminiBots_PlayerFragPreview", function()
    local cfg = GeminiBots.Config
    if not cfg or not cfg.DebugDraw then return end

    for _, ply in ipairs(player.GetAll()) do
        if ply:IsBot() or not ply:Alive() then continue end
        if CurTime() < (ply.GeminiBots_NextTrajDraw or 0) then continue end
        ply.GeminiBots_NextTrajDraw = CurTime() + 0.15

        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) then continue end
        if GeminiBots.WeaponSelector:ExplosiveKind(wep:GetClass()) ~= "frag" then continue end

        local points = GeminiBots.Aiming:PredictThrowPoints(
            ply:EyePos(), ply:EyeAngles(),
            GeminiBots.Aiming.FragThrowSpeed, ply:EyePos().z - 300
        )

        GeminiBots.Aiming:BroadcastTrajectory(ply, points, points[#points], 0, 220, 255)
    end
end)
