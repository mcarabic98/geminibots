--[[
    GeminiBots - Navigator Controller
    Следование по путевым точкам, вычисление векторов движения и защита от застреваний.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Navigator = GeminiBots.Navigator or {}

-- Установить боту цель перемещения.
-- opts (прием у Zeta): { tolerance = радиус точки (дефолт из конфига),
--   abortFn = function(bot) -> true: бросить маршрут прямо сейчас }
function GeminiBots.Navigator:MoveTo(bot, targetPos, isDetour, opts)
    if not bot or not IsValid(bot.ply) or not targetPos then return false end

    -- Свежая точка упора: строим в обход нее
    local avoidPos, avoidRadius = nil, nil
    if bot.avoidPos and CurTime() < (bot.avoidUntil or 0) then
        avoidPos, avoidRadius = bot.avoidPos, bot.avoidRadius or 220
    end
    local path = GeminiBots.Nav:FindPath(bot.ply:GetPos(), targetPos, avoidPos, avoidRadius)
    if not path or #path < 2 then return false end

    bot.path = path
    bot.pathIndex = 2 -- Первая точка — текущая позиция бота, вторая — первый шаг
    bot.pathTargetPos = targetPos
    -- Опции маршрута (сбрасываются в Stop)
    bot.reachOverride = (opts and opts.tolerance) or nil
    bot.moveAbort = (opts and opts.abortFn) or nil
    bot.lastStuckPos = bot.ply:GetPos()
    bot.stuckTimer = CurTime()
    bot.stuckCount = 0
    -- Свежая цель — новые попытки обхода; перестройка в обходе не пополняет
    if not isDetour then
        bot.detourTries = 2 -- столько раз перестроим в обход упора, потом сдаемся
    end

    return true
end

-- Остановить движение бота
function GeminiBots.Navigator:Stop(bot)
    if not bot then return end
    bot.path = nil
    bot.pathIndex = 1
    bot.pathTargetPos = nil
    bot.reachOverride = nil
    bot.moveAbort = nil
    bot.forwardMove = 0
    bot.sideMove = 0
end

-- Стекло и хрупкое на пути (окна, витрины): бьются, а не обходятся
local function IsBreakableEnt(ent)
    if not IsValid(ent) then return false end
    local c = string.lower(ent:GetClass())
    return string.find(c, "breakable", 1, true) ~= nil
        or string.find(c, "glass", 1, true) ~= nil
end

-- Обновление навигации каждый тик/кадр логики
-- Возвращает: true если цель достигнута, false если в пути, nil если пути нет
function GeminiBots.Navigator:Update(bot)
    if not bot or not IsValid(bot.ply) or not bot.ply:Alive() then return nil end
    if not bot.path or not bot.pathIndex then
        bot.forwardMove = 0
        bot.sideMove = 0
        return nil
    end

    -- Аборт маршрута предикатом (увидел врага, цель пропала, флаг подобран)
    if bot.moveAbort then
        local ok, abort = pcall(bot.moveAbort, bot)
        if ok and abort then
            self:Stop(bot)
            return "abort"
        end
    end

    local ply = bot.ply
    local currentPos = ply:GetPos()
    local targetNode = bot.path[bot.pathIndex]

    if not targetNode then
        self:Stop(bot)
        return true
    end

    local cfg = GeminiBots.Config
    local reachRadius = bot.reachOverride
        or (cfg and cfg.WaypointReachRadius) or 45

    -- Проверяем достижение текущей точки по горизонтали (2D)
    local dist2D = Vector(currentPos.x, currentPos.y, 0):Distance(Vector(targetNode.x, targetNode.y, 0))

    if dist2D <= reachRadius then
        bot.pathIndex = bot.pathIndex + 1

        -- Если достигли последней точки
        if bot.pathIndex > #bot.path then
            self:Stop(bot)
            return true
        end

        targetNode = bot.path[bot.pathIndex]
    end

    -- Вычисляем направление к текущему узлу
    local toNode = (targetNode - currentPos)
    local moveAngle = toNode:Angle()
    local eyeYaw = (bot.currentViewAngles and bot.currentViewAngles.y) or ply:EyeAngles().y

    -- Низкий проем (стойка, прилавок): стоя упираемся головой,
    -- пригнувшись проходим. Меряем с фиксированных высот,
    -- чтобы присед не сбивал замер.
    -- Трейс каждый 3-й тик (20 Гц вместо 60): решение "пригнуться"
    -- с лагом в пару кадров не чувствуется, трейсов втрое меньше
    bot.moveTick = (bot.moveTick or 0) + 1
    if bot.moveTick % 3 == 0 then
    do
        local flatDir = Vector(toNode.x, toNode.y, 0)
        if flatDir:LengthSqr() > 1 then
            flatDir:Normalize()
            local standEye = currentPos + Vector(0, 0, 60)
            local trStand = util.TraceLine({
                start = standEye,
                endpos = standEye + flatDir * 70,
                filter = ply,
                mask = MASK_SOLID
            })
            local blockedByWorld = trStand.Hit
                and not (IsValid(trStand.Entity)
                    and (trStand.Entity:IsPlayer() or trStand.Entity:IsNPC()))
            if blockedByWorld then
                local crouchEye = currentPos + Vector(0, 0, 28)
                local trCrouch = util.TraceLine({
                    start = crouchEye,
                    endpos = crouchEye + flatDir * 70,
                    filter = ply,
                    mask = MASK_SOLID
                })
                if not trCrouch.Hit then
                    bot.duckUntil = CurTime() + 0.4
                end
                -- В приседе не пролезть, а впереди стекло: разбиваем
                local hitEnt = trStand.Entity
                if CurTime() >= (bot.duckUntil or 0)
                    and IsBreakableEnt(hitEnt) then
                    bot.breakEnt = hitEnt
                    bot.breakUntil = CurTime() + 2.0
                end
            end
        end
    end
    end
    if CurTime() < (bot.duckUntil or 0) then
        bot.buttons = bit.bor(bot.buttons or 0, IN_DUCK)
    end

    -- Если у бота нет приоритетной цели для взгляда (не в бою), направляем взгляд по ходу движения.
    -- Осмотр по сторонам из состояний (keepLookUntil) не перебиваем: иначе
    -- glance в wander/investigate никогда не виден, бот смотрит только вперед
    if not IsValid(bot.target) and CurTime() >= (bot.keepLookUntil or 0) then
        bot.desiredViewAngles = Angle(0, moveAngle.y, 0)
        bot.viewSrc = "nav"
    end

    -- Разбиваем преграду: смотрим в нее и бьем/стреляем, пока не развалится
    if CurTime() < (bot.breakUntil or 0) and IsValid(bot.breakEnt)
        and CurTime() >= (bot.duckUntil or 0) then
        if not IsValid(bot.target) then
            local bc = bot.breakEnt:WorldSpaceCenter()
            local aim = (bc - ply:EyePos()):Angle()
            bot.desiredViewAngles = Angle(math.Clamp(aim.p, -60, 60),
                math.NormalizeAngle(aim.y), 0)
            bot.viewSrc = "break"
        end
        bot.buttons = bit.bor(bot.buttons or 0, IN_ATTACK)
    else
        bot.breakEnt = nil
    end

    -- Проекция движения на угол взгляда бота
    local yawDiff = math.AngleDifference(moveAngle.y, eyeYaw)
    local rad = math.rad(yawDiff)

    local speed = ply:GetRunSpeed() or 250
    if speed <= 0 then speed = 250 end

    -- Рядом с точкой сбавляем ход: подходим шагом, а не проносимся мимо
    if bot.pathTargetPos then
        local final2D = Vector(currentPos.x, currentPos.y, 0)
            :Distance(Vector(bot.pathTargetPos.x, bot.pathTargetPos.y, 0))
        if final2D < 200 then
            speed = speed * 0.5
        end
    end

    bot.forwardMove = math.cos(rad) * speed
    bot.sideMove = math.sin(rad) * speed

    -- Шаг вбок при упоре: обходим край препятствия, а не толкаем его лбом
    if CurTime() < (bot.sideStepUntil or 0) then
        bot.sideMove = (bot.sideStepDir or 1) * speed
        bot.forwardMove = (bot.forwardMove or 0) * 0.4
    end

    -- Проверка на необходимость прыжка (перепад высоты).
    -- Высокий уступ: в воздухе приседаем (крауч-джамп дотягивает выше).
    local heightDiff = targetNode.z - currentPos.z
    if heightDiff > ((cfg and cfg.JumpObstacleHeight) or 18) then
        bot.buttons = bit.bor(bot.buttons or 0, IN_JUMP)
        if heightDiff > 50 and not ply:IsOnGround() then
            bot.buttons = bit.bor(bot.buttons or 0, IN_DUCK)
        end
    end

    -- Защита от застревания (Anti-Stuck)
    -- самое тяжелое - это заставить ботов сесть за игровое кресло
    local stuckTimeout = (cfg and cfg.StuckTimeout) or 1.5
    if CurTime() - (bot.stuckTimer or 0) > stuckTimeout then
        local movedDist = currentPos:Distance(bot.lastStuckPos or currentPos)
        if movedDist < 25 then
            -- Ждем, пока пролезет под проемом, путь не трогаем
            if CurTime() < (bot.duckUntil or 0) then
                bot.lastStuckPos = currentPos
                bot.stuckTimer = CurTime()
                return false
            end
            bot.stuckCount = (bot.stuckCount or 0) + 1
            -- Пытаемся подпрыгнуть
            bot.buttons = bit.bor(bot.buttons or 0, IN_JUMP)
            -- И шагнуть вбок (стороны чередуем): край препятствия рядом
            bot.sideStepDir = -(bot.sideStepDir or 1)
            bot.sideStepUntil = CurTime() + 0.8

            -- Если застрял капитально — сначала пробуем длинный путь
            -- в обход (по лестнице пешком вместо прыжков на ящики),
            -- и только потом сдаемся
            if bot.stuckCount >= 2 then
                if (bot.detourTries or 0) > 0 and bot.pathTargetPos then
                    bot.detourTries = bot.detourTries - 1
                    bot.avoidPos = currentPos
                    bot.avoidUntil = CurTime() + 12.0
                    bot.avoidRadius = 220
                    GeminiBots:Debug("Бот %s уперся. Обход %d.", ply:Nick(), bot.detourTries)
                    self:MoveTo(bot, bot.pathTargetPos, true)
                    return false
                end
                GeminiBots:Debug("Бот %s застрял. Сброс пути.", ply:Nick())
                self:Stop(bot)
                return false
            end
        else
            bot.stuckCount = 0
        end

        bot.lastStuckPos = currentPos
        bot.stuckTimer = CurTime()
    end

    return false
end
