--[[
    GeminiBots - State: Combat
    Боевое состояние: ведение перестрелки, тактическое маневрирование и преследование.
]]--

local State = {}

function State:Enter(bot)
    GeminiBots.Navigator:Stop(bot)
    bot.stateData.lastCombatUpdate = CurTime()
end

function State:Update(bot, dt)
    local ply = bot.ply
    local cfg = GeminiBots.Config

    -- Murder: безоружный мирный при известном убийце рядом — бежать, а не драться
    if GeminiBots.MurderFleeCheck and GeminiBots.MurderFleeCheck(bot) then return end

    -- 1. Проверка здоровья: если здоровье критически мало, пытаемся отступить
    local fleeThreshold = (cfg and cfg.FleeHealthThreshold) or 0.25
    if (ply:Health() / ply:GetMaxHealth()) <= fleeThreshold then
        GeminiBots.FSM:SetState(bot, "flee")
        return
    end

    -- 2. Проверка валидности цели
    local target = bot.target
    if not IsValid(target) or not target:Alive() then
        bot.target = nil
        GeminiBots.FSM:SetState(bot, "idle")
        return
    end

    -- 3. Если цель скрылась из виду, но мы помним ее последнюю позицию:
    -- сначала пробуем прострел (стекло/хрупкое + свежий след), иначе разведка
    local hasLOS = GeminiBots.Vision:HasLineOfSight(bot, target)
    if not hasLOS and bot.lastKnownTargetPos then
        if GeminiBots.Combat:TryWallbang(bot, target) then
            return
        end
        local distToLast = ply:GetPos():Distance(bot.lastKnownTargetPos)
        if distToLast > 100 then
            -- Бежим к точке, где враг пропал из виду. Репас не чаще 2 раз
            -- в секунду; три провала подряд — точка недостижима, уходим
            -- проверять дальше по коридору вместо вечной погони
            if CurTime() >= (bot.stateData.nextChaseRepath or 0) then
                bot.stateData.nextChaseRepath = CurTime() + 0.5
                if GeminiBots.Navigator:MoveTo(bot, bot.lastKnownTargetPos) then
                    bot.stateData.chaseFails = 0
                else
                    bot.stateData.chaseFails = (bot.stateData.chaseFails or 0) + 1
                end
            end
            if (bot.stateData.chaseFails or 0) >= 3 then
                bot.stateData.chaseFails = 0
                local chaseDir = (bot.lastKnownTargetPos - ply:GetPos()):GetNormalized()
                bot.investigatePos = bot.lastKnownTargetPos + chaseDir * 400
                bot.investigateTime = CurTime()
                bot.investigateKind = "chase"
                bot.target = nil
                bot.lastKnownTargetPos = nil
                GeminiBots.FSM:SetState(bot, "wander")
                return
            end
            return
        else
            -- На углу: ищем дальше по коридору
            local chaseDir = (bot.lastKnownTargetPos - ply:GetPos()):GetNormalized()
            bot.investigatePos = bot.lastKnownTargetPos + chaseDir * 400
            bot.investigateTime = CurTime()
            bot.investigateKind = "chase"
            bot.target = nil
            bot.lastKnownTargetPos = nil
            GeminiBots.FSM:SetState(bot, "wander")
            return
        end
    end

    -- 4. Передаем управление боевому модулю
    GeminiBots.Combat:Update(bot, dt)
end

function State:Exit(bot)
    GeminiBots.Navigator:Stop(bot)
    bot.forwardMove = 0
    bot.sideMove = 0
    bot.buttons = 0
    bot.stateData = {}
end

GeminiBots.FSM:RegisterState("combat", State)
