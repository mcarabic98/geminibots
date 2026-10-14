--[[
    GeminiBots - Vision & Sensory System
    Сканирование пространства, расчет конуса видимости (FOV), слуха и прямой видимости (LOS).
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Vision = GeminiBots.Vision or {}

-- Проверка валидности потенциальной цели
function GeminiBots.Vision:IsValidTarget(bot, ent)
    if not IsValid(ent) then return false end
    if ent == bot.ply then return false end

    -- Игрок или бот
    if ent:IsPlayer() then
        if not ent:Alive() then return false end
        if ent:GetMoveType() == MOVETYPE_NOCLIP then return false end

        -- Наблюдатели (спектаторы, слежка через ULX и т.п.): висят на боте
        -- в упор, из-за чего бот вечно пятится от "врага" в нуле юнитов
        if ent:GetObserverMode() ~= OBS_MODE_NONE then return false end
        if ent:GetMoveType() == MOVETYPE_OBS then return false end

        -- Если командная игра (например, TTT или команды DarkRP/CW)
        -- Murder: все в одной команде специально — вместо этого фильтр ролей
        if GeminiBots.MurderActive and GeminiBots.MurderActive() then
            return GeminiBots.MurderCanTarget(bot, ent)
        end
        -- HL2MP: FFA бьет всех, TDM только чужих (фильтр команд режима)
        if GeminiBots.HL2MPActive and GeminiBots.HL2MPActive() then
            return GeminiBots.HL2MPCanTarget(bot, ent)
        end
        if ent:Team() ~= 0 and ent:Team() == bot.ply:Team() and not (GAMEMODE and GAMEMODE.IsSandboxDerived) then
            return false
        end

        return true
    end

    -- NPC и модовые монстры (VJ/DrG через адаптеры, см. sv_npc_adapters)
    if GeminiBots.NPCAdapters and GeminiBots.NPCAdapters:IsNPCEntity(ent) then
        if not GeminiBots.NPCAdapters:IsEnemy(bot, ent) then return false end
        local okNPC, isNPC = pcall(function() return ent:IsNPC() end)
        if okNPC and isNPC then
            local okSt, st = pcall(function() return ent:GetNPCState() end)
            if okSt and st == NPC_STATE_DEAD then return false end
        end
        return true
    end

    return false
end

-- Разрешен ли класс сущности режимом целей (both/pve/players/npcs)
function GeminiBots.Vision:CanTargetClass(bot, ent)
    if not IsValid(ent) then return false end
    local cfg = GeminiBots.Config
    local mode = cfg and cfg.Targeting and cfg.Targeting.Mode or "both"
    if mode == "players" then return ent:IsPlayer() end
    if mode == "npcs" then
        if GeminiBots.NPCAdapters then
            return GeminiBots.NPCAdapters:IsNPCEntity(ent)
        end
        return ent:IsNPC()
    end
    return true
end

-- Проверка прямой видимости (Line Of Sight)
function GeminiBots.Vision:HasLineOfSight(bot, target)
    if not IsValid(target) then return false end

    local eyePos = bot.ply:EyePos()
    local targetHead = target:EyePos()
    local targetCenter = target:WorldSpaceCenter()

    -- 1. Проверяем луч в голову
    local trHead = util.TraceLine({
        start = eyePos,
        endpos = targetHead,
        filter = bot.ply,
        mask = MASK_SHOT
    })

    if trHead.Entity == target or trHead.Fraction >= 0.98 then
        return true, targetHead
    end

    -- 2. Если голова перекрыта, проверяем центр туловища
    local trCenter = util.TraceLine({
        start = eyePos,
        endpos = targetCenter,
        filter = bot.ply,
        mask = MASK_SHOT
    })

    if trCenter.Entity == target or trCenter.Fraction >= 0.98 then
        return true, targetCenter
    end

    return false, nil
end

-- Кэш LOS на тик: память, состояние боя и боевой модуль спрашивают одно
-- и то же по 3 раза в тик (6 трейсов). Нулевая потеря: в пределах тика
-- мир не меняется. Ключ — номер кадра движка + цель
local RawHasLineOfSight = GeminiBots.Vision.HasLineOfSight
function GeminiBots.Vision:HasLineOfSight(bot, target)
    if not IsValid(target) then return false end
    local fr = (FrameNumber and FrameNumber()) or 0
    if bot.losFrame == fr and bot.losTarget == target then
        return bot.losHas, bot.losPos
    end
    local has, pos = RawHasLineOfSight(self, bot, target)
    bot.losFrame, bot.losTarget, bot.losHas, bot.losPos = fr, target, has, pos
    return has, pos
end

-- Проверка, находится ли цель в поле зрения (FOV) или слышимости (включая сквозь стены)
function GeminiBots.Vision:CanPerceive(bot, target)
    -- Ослепленный флешкой не видит и не слышит
    if GeminiBots.SWCS_IsBlind and bot and IsValid(bot.ply)
        and GeminiBots.SWCS_IsBlind(bot.ply) then
        return false, false
    end
    if not self:IsValidTarget(bot, target) then return false, false end

    local cfg = GeminiBots.Config
    local okE, eyePos = pcall(function() return bot.ply:EyePos() end)
    local okC, targetPos = pcall(function() return target:WorldSpaceCenter() end)
    if not okE or not okC or not eyePos or not targetPos then return false, false end

    local dist = eyePos:Distance(targetPos)
    local maxRange = (cfg and cfg.VisionRange) or 2500
    if dist > maxRange then return false, false end

    local hasLOS, hitPos = false, nil

    -- Читерство: волхак видит сквозь стены (конус зрения остается),
    -- хвх вообще без конуса — только дистанция
    local cht = bot.cheater
    if cht and cht.omni then
        return true, false
    end

    -- Дешевый конус зрения ДО трейсов: вне FOV прямая видимость не нужна
    -- никому, кроме слуха (ниже) — два трейса на кандидата экономим.
    -- Поведение то же: раньше LOS считался и вне конуса, но в ответ не шел
    local dirToTarget = (targetPos - eyePos):GetNormalized()
    local aimVector = bot.ply:GetAimVector()
    local dot = aimVector:Dot(dirToTarget)
    local angle = math.deg(math.acos(math.Clamp(dot, -1, 1)))
    local fov = (cfg and cfg.VisionFOV) or 110
    local inFOV = angle <= (fov / 2)

    hasLOS, hitPos = false, nil
    if inFOV then
        hasLOS, hitPos = self:HasLineOfSight(bot, target)
    end
    if cht and cht.wallhack then
        hasLOS = true
        hitPos = hitPos or targetPos
    end

    -- Слуховой канал: шаги, бег, стрельба (слышно сквозь стены и за углами)
    local hearingRange = (cfg and cfg.HearingRange) or 700
    local heardSound = false
    if dist <= hearingRange then
        local isLoud = false
        if target:IsPlayer() then
            local vel = target:GetVelocity():Length()
            if vel > 120 or target:KeyDown(IN_ATTACK) then
                isLoud = true
            end
        elseif target:IsNPC() then
            if target:GetVelocity():Length() > 50 then
                isLoud = true
            end
        elseif GeminiBots.NPCAdapters
            and GeminiBots.NPCAdapters:IsNPCEntity(target) then
            -- Модовые NextBot'ы (DrG): IsNPC у них false, слух тот же
            local okV, vel = pcall(function() return target:GetVelocity():Length() end)
            if okV and vel and vel > 50 then
                isLoud = true
            end
        end

        if isLoud then
            heardSound = true
            if hasLOS then
                return true, true -- Замечен и зрением, и звуком
            else
                return false, true -- Услышан сквозь стену/за углом
            end
        end
    end

    -- Зрительный канал: трейсы выше уже доказали прямую видимость,
    -- конус посчитан чистой математикой без единого трейса
    if hasLOS and inFOV then
        return true, heardSound -- Замечен зрением
    end

    return false, heardSound
end

-- Поиск наилучшей цели среди всех окружающих сущностей + обработка услышанных звуков
function GeminiBots.Vision:FindBestTarget(bot)
    if not bot or not IsValid(bot.ply) or not bot.ply:Alive() then return nil end

    -- Ослепленный никого не ищет
    if GeminiBots.SWCS_IsBlind and GeminiBots.SWCS_IsBlind(bot.ply) then return nil end

    local cfg = GeminiBots.Config
    local mode = cfg and cfg.Targeting and cfg.Targeting.Mode or "both"
    local wantPlayers = (mode ~= "npcs")
    local wantNPCs = (mode ~= "players")

    local botPos = bot.ply:GetPos()

    -- Дуэль: дерется только с вызвавшим. Видит — атакует, слышит — идет
    -- на звук, не видит — остальных игнорирует (возврат nil).
    local duel = GeminiBots.Duels and GeminiBots.Duels[bot.ply] or nil
    if duel then
        if not IsValid(duel.enemy) or not duel.enemy:Alive()
            or (duel.since and CurTime() - duel.since > 180) then
            GeminiBots.Duels[bot.ply] = nil
            duel = nil
        end
    end
    if duel then
        local e = duel.enemy
        if self:IsValidTarget(bot, e) then
            local canSee, heard = self:CanPerceive(bot, e)
            if canSee then return e end
            if heard then
                bot.investigatePos = e:GetPos()
                bot.investigateTime = CurTime()
                bot.investigateKind = "steps"
                if bot.state == "idle" or bot.state == "wander" then
                    bot.desiredViewAngles = (e:GetPos() - bot.ply:EyePos()):Angle()
                    GeminiBots.FSM:SetState(bot, "wander")
                end
            end
        end
        return nil
    end

    -- Кандидаты: игроки + NPC в радиусе зрения (по режиму целей)
    local candidates = {}
    if wantPlayers then
        for _, ply in ipairs(player.GetAll()) do
            table.insert(candidates, ply)
        end
    end
    if wantNPCs then
        local range = (cfg and cfg.VisionRange) or 2500
        -- Кэш реестра: штатные NPC + NextBot'ы (DrG) одним проходом
        local pool = (GeminiBots.NPCAdapters and GeminiBots.NPCAdapters:AllNPCs())
            or ents.FindByClass("npc_*")
        for _, npc in ipairs(pool) do
            if IsValid(npc) and botPos:Distance(npc:GetPos()) <= range then
                table.insert(candidates, npc)
            end
        end
    end

    local bestPlayer, bestPlayerDist = nil, math.huge
    local bestNPC, bestNPCDist = nil, math.huge
    -- Дистанция услышанного: сбрасываем каждый скан, внутри скана побеждает ближний
    bot.heardDist = nil

    for _, ent in ipairs(candidates) do
        if ent ~= bot.ply and self:IsValidTarget(bot, ent) then
            local canSee, heard = self:CanPerceive(bot, ent)

            -- Если враг виден в глаза — кандидат на моментальный бой
            if canSee then
                local distSqr = botPos:DistToSqr(ent:GetPos())
                if ent == bot.target then
                    distSqr = distSqr * 0.75
                end

                local isNPCEnt = ent:IsNPC()
                if GeminiBots.NPCAdapters then
                    isNPCEnt = GeminiBots.NPCAdapters:IsNPCEntity(ent)
                end
                if isNPCEnt then
                    if distSqr < bestNPCDist then
                        bestNPCDist = distSqr
                        bestNPC = ent
                    end
                else
                    if distSqr < bestPlayerDist then
                        bestPlayerDist = distSqr
                        bestPlayer = ent
                    end
                end
            elseif heard then
                -- Враг за стеной, но слышно: запоминаем точку и идем проверять.
                -- Побеждает ближайший, а не последний в списке
                local hearDist = botPos:DistToSqr(ent:GetPos())
                if not bot.investigatePos or hearDist < (bot.heardDist or math.huge) then
                    bot.investigatePos = ent:GetPos()
                    bot.investigateTime = CurTime()
                    bot.investigateKind = "steps"
                    bot.heardDist = hearDist
                end

                -- Гулял или стоял: поворачиваемся к источнику шума
                if bot.state == "idle" or bot.state == "wander" then
                    bot.desiredViewAngles = (ent:GetPos() - bot.ply:EyePos()):Angle()
                    GeminiBots.FSM:SetState(bot, "wander")
                end
            end
        end
    end

    -- PvE: NPC в приоритете, игроки — только если NPC рядом нет
    if mode == "pve" then
        return bestNPC or bestPlayer
    end

    -- Иначе побеждает ближайший
    if bestNPC and bestPlayer then
        return (bestNPCDist <= bestPlayerDist) and bestNPC or bestPlayer
    end
    return bestNPC or bestPlayer
end

-- Акустическая реакция на выстрелы: все боты в округе слышат перестрелку и стягиваются
hook.Add("EntityFireBullets", "GeminiBots_Acoustic_Gunfire", function(entity, data)
    if not IsValid(entity) then return end
    local shooterPos = entity:GetPos()
    local cfg = GeminiBots.Config
    local gunRange = (cfg and cfg.GunHearingRange) or 3000

    for _, bot in pairs(GeminiBots:GetAllBots()) do
        if IsValid(bot.ply) and bot.ply:Alive() and bot.ply ~= entity then
            -- Слепой от флешки выстрелов не слышит
            if GeminiBots.SWCS_IsBlind and GeminiBots.SWCS_IsBlind(bot.ply) then continue end
            if GeminiBots.Vision:IsValidTarget(bot, entity) then
                local dist = bot.ply:GetPos():Distance(shooterPos)
                if dist <= gunRange then
                    -- Вне боя: слышит стрельбу и идет на звук
                    if bot.state == "idle" or bot.state == "wander" then
                        bot.investigatePos = shooterPos + Vector(math.Rand(-80, 80), math.Rand(-80, 80), 0)
                        bot.investigateTime = CurTime()
                        bot.investigateKind = "gunfire"
                        bot.desiredViewAngles = (shooterPos - bot.ply:EyePos()):Angle()
                        GeminiBots.FSM:SetState(bot, "wander")
                    end
                end
            end
        end
    end
end)
