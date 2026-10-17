--[[
    GeminiBots - State: Defuse (C4)
    Сапер разминирует: подходит к бомбе вплотную, смотрит на нее и держит
    E (IN_USE). Без набора 10 сек, с набором 5. Не успевает — убегает.
    Урон дефуз не прерывает: пока держит кнопку, SWCS считает прогресс.
]]

local USE_DIST = 70 -- подходим вплотную, USE берет только рядом
local CLOSE_DIST = 45 -- не зацепилось с первого раза: подходим еще ближе
local GIVEUP_TIME = 4.0 -- держим, но не дефузимся: отходим и пробуем позже

local State = {}

function State:Enter(bot, bomb)
    bot.defuseBomb = bomb
    bot.stateData.nextRepath = 0
    bot.stateData.useStart = 0
    bot.stateData.sawDefusing = false
    bot.stateData.closeIn = false
    bot.stateData.giveUpAt = 0
    if IsValid(bomb) then
        GeminiBots.Navigator:MoveTo(bot, bomb:GetPos())
    end
end

-- Я сейчас в процессе дефуза (флаг ставит сам SWCS)
local function AmIDefusing(ply)
    if not IsValid(ply) then return false end
    local ok, v = pcall(function() return ply:GetNWBool("m_bIsDefusing", false) end)
    return ok and v == true
end

function State:Update(bot, dt)
    local ply = bot.ply
    if not IsValid(ply) or not ply:Alive() then return end

    local bomb = bot.defuseBomb
    local info = GeminiBots.C4_Info and GeminiBots.C4_Info(bomb) or nil
    if not info then
        -- Бомбы больше нет (рванула/разминировали/убрали): свободны
        bot.defuseBomb = nil
        GeminiBots.FSM:SetState(bot, "idle")
        return
    end

    -- Кто-то другой уже работает: не толпимся
    if IsValid(info.defuser) and info.defuser ~= ply then
        bot.defuseBomb = nil
        GeminiBots.FSM:SetState(bot, "wander")
        return
    end

    -- Не хватит времени: убегаем
    local needed = GeminiBots.C4_Needed and GeminiBots.C4_Needed(ply) or 12
    if info.remain < needed then
        bot.defuseBomb = nil
        bot.fleeBomb = bomb
        bot.fleeNoTime = true
        GeminiBots.FSM:SetState(bot, "flee")
        return
    end

    local dist = ply:GetPos():Distance(bomb:GetPos())
    local want = bot.stateData.closeIn and CLOSE_DIST or USE_DIST
    if dist > want then
        -- Идем к бомбе (без прыжков под конец: дефуз только с земли)
        if CurTime() >= (bot.stateData.nextRepath or 0) then
            bot.stateData.nextRepath = CurTime() + 1.0
            bot.stateData.directWalk = not GeminiBots.Navigator:MoveTo(bot, bomb:GetPos())
            if bot.stateData.directWalk then
                bot.stateData.directFrom = ply:GetPos()
                bot.stateData.directAt = CurTime()
                GeminiBots:Debug("Сапер %s: навмеш не дал путь, иду напролом.", ply:Nick())
            end
        end
        if bot.stateData.directWalk then
            -- Навмеша нет: идем по прямой, через 3 сек топтания сдаемся.
            -- Вверх — прыжком с приседом в воздухе
            local dir = bomb:GetPos() - ply:GetPos()
            bot.desiredViewAngles = Angle(0, dir:Angle().y, 0)
            bot.viewSrc = "defuse"
            bot.forwardMove = ply:GetRunSpeed() or 250
            if dir.z > 18 then
                bot.buttons = bit.bor(bot.buttons or 0, IN_JUMP)
                if dir.z > 50 and not ply:IsOnGround() then
                    bot.buttons = bit.bor(bot.buttons or 0, IN_DUCK)
                end
            end
            if ply:GetPos():Distance(bot.stateData.directFrom or ply:GetPos()) < 25
                and CurTime() - (bot.stateData.directAt or CurTime()) > 3.0 then
                bot.defuseBomb = nil
                GeminiBots.FSM:SetState(bot, "wander")
                return
            end
        end
        return
    end

    -- На месте: смотрим на бомбу и держим E
    GeminiBots.Navigator:Stop(bot)
    bot.forwardMove = 0
    bot.sideMove = 0
    bot.desiredViewAngles = ((bomb:GetPos() + Vector(0, 0, 30)) - ply:EyePos()):Angle()
    bot.desiredViewAngles.p = math.Clamp(bot.desiredViewAngles.p, -60, 60)
    bot.viewSrc = "defuse"
    bot.buttons = bit.bor(bot.buttons or 0, IN_USE)

    if bot.stateData.useStart == 0 then
        bot.stateData.useStart = CurTime()
        bot.stateData.giveUpAt = CurTime() + GIVEUP_TIME
    end
    if AmIDefusing(ply) then
        bot.stateData.sawDefusing = true
    elseif not bot.stateData.sawDefusing then
        if not bot.stateData.closeIn then
            -- USE не зацепился: подходим вплотную
            bot.stateData.closeIn = true
            GeminiBots.Navigator:MoveTo(bot, bomb:GetPos())
        elseif CurTime() >= (bot.stateData.giveUpAt or 0) then
            -- И вблизи не берет: отходим, таймер директора вернет позже
            bot.defuseBomb = nil
            GeminiBots.FSM:SetState(bot, "wander")
            return
        end
    end
end

function State:Exit(bot)
    bot.defuseBomb = nil
    bot.forwardMove = 0
    bot.sideMove = 0
    bot.buttons = 0
    bot.stateData = {}
end

GeminiBots.FSM:RegisterState("defuse", State)
