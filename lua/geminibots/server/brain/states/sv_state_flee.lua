--[[
    GeminiBots - State: Flee
    Отступление и поиск безопасного укрытия при критически низком уровне здоровья.
]]--

local State = {}

function State:Enter(bot)
    bot.stateData.timeout = CurTime() + 6.0

    local fleePos = nil
    if IsValid(bot.fleeBomb) then
        -- От бомбы: как можно дальше по прямой (взрыв 1750)
        local awayDir = (bot.ply:GetPos() - bot.fleeBomb:GetPos())
        awayDir.z = 0
        if awayDir:LengthSqr() < 1 then awayDir = Vector(1, 0, 0) end
        awayDir:Normalize()
        local retreatTarget = bot.ply:GetPos() + awayDir * 1600
        local tr = util.TraceLine({
            start = bot.ply:GetPos() + Vector(0, 0, 20),
            endpos = retreatTarget + Vector(0, 0, 20),
            mask = MASK_SOLID_BRUSHONLY
        })
        fleePos = tr.Hit and (tr.HitPos + tr.HitNormal * 60) or retreatTarget
    elseif IsValid(bot.target) then
        -- Направление строго от противника
        local awayDir = (bot.ply:GetPos() - bot.target:GetPos()):GetNormalized()
        local retreatTarget = bot.ply:GetPos() + awayDir * 1000

        -- Трассой проверяем, что не уходим в тупик
        local tr = util.TraceLine({
            start = bot.ply:GetPos() + Vector(0, 0, 20),
            endpos = retreatTarget + Vector(0, 0, 20),
            mask = MASK_SOLID_BRUSHONLY
        })

        fleePos = tr.Hit and (tr.HitPos + tr.HitNormal * 60) or retreatTarget
    else
        fleePos = GeminiBots.Nav:GetRandomWanderPos(bot.ply:GetPos(), 800)
    end

    if fleePos then
        GeminiBots.Navigator:MoveTo(bot, fleePos)
    end
end

function State:Update(bot, dt)
    -- Бомба рядом: держим дистанцию, пока не рванет или не уйдем далеко
    if bot.fleeBomb ~= nil then
        if IsValid(bot.fleeBomb) then
            local d = bot.ply:GetPos():Distance(bot.fleeBomb:GetPos())
            if d < 1700 then
                bot.stateData.timeout = CurTime() + 4.0
                if CurTime() >= (bot.stateData.nextBombRepath or 0) then
                    bot.stateData.nextBombRepath = CurTime() + 1.0
                    local awayDir = (bot.ply:GetPos() - bot.fleeBomb:GetPos())
                    awayDir.z = 0
                    if awayDir:LengthSqr() < 1 then awayDir = Vector(1, 0, 0) end
                    awayDir:Normalize()
                    local retreatTarget = bot.ply:GetPos() + awayDir * 1600
                    local tr = util.TraceLine({
                        start = bot.ply:GetPos() + Vector(0, 0, 20),
                        endpos = retreatTarget + Vector(0, 0, 20),
                        mask = MASK_SOLID_BRUSHONLY
                    })
                    local safe = tr.Hit and (tr.HitPos + tr.HitNormal * 60) or retreatTarget
                    GeminiBots.Navigator:MoveTo(bot, safe)
                end
                return
            end
        end
        -- Далеко ушли или бомбы больше нет: свободны
        bot.fleeBomb = nil
        bot.fleeNoTime = nil
        GeminiBots.FSM:SetState(bot, "idle")
        return
    end

    -- По истечении времени отступления или если добежали до точки
    if not bot.path or CurTime() >= (bot.stateData.timeout or 0) then
        -- Если враг потерян из виду, возвращаемся в спокойное состояние
        if not IsValid(bot.target) or not GeminiBots.Vision:HasLineOfSight(bot, bot.target) then
            GeminiBots.FSM:SetState(bot, "idle")
        else
            -- Если враг все еще преследует, принимаем последний бой
            GeminiBots.FSM:SetState(bot, "combat")
        end
    end
end

function State:Exit(bot)
    GeminiBots.Navigator:Stop(bot)
    bot.stateData = {}
end

GeminiBots.FSM:RegisterState("flee", State)
