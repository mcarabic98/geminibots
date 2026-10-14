--[[
    GeminiBots - State: Idle
    Состояние короткого ожидания: осмотр по сторонам и переход к исследованию карты.
]]--

local State = {}

function State:Enter(bot)
    GeminiBots.Navigator:Stop(bot)
    -- На проверке звука пауза короче, чтобы не терять темп
    if bot.investigatePos then
        bot.stateData.duration = math.Rand(0.4, 0.8)
    else
        bot.stateData.duration = math.Rand(0.6, 1.6)
    end
    bot.stateData.enterTime = CurTime()
    bot.stateData.nextLookTime = CurTime() + 0.4
end

function State:Update(bot, dt)
    -- Защита: если enterTime не был инициализирован
    if not bot.stateData.enterTime then
        self:Enter(bot)
    end

    -- Если появился враг, немедленно вступаем в бой
    if IsValid(bot.target) then
        GeminiBots.FSM:SetState(bot, "combat")
        return
    end

    -- Если поступил новый сигнал расследования (выстрелы или шаги), сразу идем на звук
    if bot.investigatePos and (CurTime() - (bot.investigateTime or 0) < 15.0) then
        GeminiBots.FSM:SetState(bot, "investigate")
        return
    end

    -- Периодический случайный осмотр по сторонам
    if CurTime() >= (bot.stateData.nextLookTime or 0) then
        local curYaw = bot.ply:EyeAngles().y
        local newYaw = curYaw + math.Rand(-60, 60)
        bot.desiredViewAngles = Angle(math.Rand(-10, 10), math.NormalizeAngle(newYaw), 0)
        bot.stateData.nextLookTime = CurTime() + math.Rand(1.0, 2.0)
    end

    -- По истечении времени переходим к исследованию карты
    local enterTime = bot.stateData.enterTime or CurTime()
    local duration = bot.stateData.duration or 2.0
    if CurTime() - enterTime >= duration then
        GeminiBots.FSM:SetState(bot, "wander")
    end
end

function State:Exit(bot)
    bot.stateData = {}
end

GeminiBots.FSM:RegisterState("idle", State)
