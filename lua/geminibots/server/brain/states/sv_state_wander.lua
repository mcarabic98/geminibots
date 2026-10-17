--[[
    GeminiBots - State: Wander / Search & Hunt
    Активное исследование карты, поиск игроков в лабиринтах/комнатах,
    проверка углов и реакция на источники звука (выстрелы, шаги).
]]--

local State = {}

function State:Enter(bot)
    local targetPos = nil

    -- Свежая точка расследования (звук выстрела или бег за стеной) —
    -- это работа отдельного состояния investigate (подход + осмотр)
    if bot.investigatePos and (CurTime() - (bot.investigateTime or 0) < 20.0) then
        GeminiBots.FSM:SetState(bot, "investigate")
        return
    end

    -- Иначе используем активный поиск игроков на карте (охота по секторам)
    -- Подбор раньше охоты: тяжелое ранение -> лечение, потом ствол,
    -- потом батарея/патроны. Взял (сущность исчезла / класс в инвентаре) —
    -- дальше по делам
    if GeminiBots.Scavenger then
        local wpos, went, wclass = GeminiBots.Scavenger:FindGoal(bot)
        if wpos and IsValid(went) then
            if GeminiBots.Navigator:MoveTo(bot, wpos) then
                bot.stateData.pickupEnt = went
                bot.stateData.pickupClass = wclass
                bot.stateData.timeout = CurTime() + 15.0
                bot.stateData.nextCornerCheck = CurTime() + math.Rand(1.2, 2.5)
                return
            end
        end
    end
    targetPos = GeminiBots.Nav:GetHuntPos(bot)

    -- HL2MP-детматч: охота тянет всех в один сектор (кучкуются на спавне).
    -- Точка охоты рядом — идем в дальний рейд по всей карте вместо толпы
    if targetPos and GeminiBots.HL2MPActive and GeminiBots.HL2MPActive() then
        if bot.ply:GetPos():Distance(targetPos) < 700 then
            targetPos = GeminiBots.Nav:GetSearchPos(bot.ply:GetPos(), 1500, 4500)
        end
    end

    if not targetPos then
        targetPos = GeminiBots.Nav:GetRandomWanderPos(bot.ply:GetPos(), 1800)
    end

    local success = GeminiBots.Navigator:MoveTo(bot, targetPos)

    -- HL2DM: темп выше, карты больше — переохота вдвое чаще
    local wanderTime = 15.0
    if GeminiBots.HL2MPActive and GeminiBots.HL2MPActive() then
        wanderTime = 8.0
    end
    bot.stateData.timeout = CurTime() + wanderTime
    bot.stateData.nextCornerCheck = CurTime() + math.Rand(1.2, 2.5)

    if not success then
        -- Если путь не удалось построить, пробуем случайную точку по navmesh
        local altPos = GeminiBots.Nav:GetSearchPos(bot.ply:GetPos(), 600, 2000)
        if not GeminiBots.Navigator:MoveTo(bot, altPos) then
            GeminiBots.FSM:SetState(bot, "idle")
        end
    end
end

function State:Update(bot, dt)
    -- Если замечен враг, сразу переходим в бой
    if IsValid(bot.target) then
        GeminiBots.FSM:SetState(bot, "combat")
        return
    end

    -- Динамическое переключение: на блуждании услышан новый звук — на проверку
    if bot.investigatePos then
        if CurTime() - (bot.investigateTime or 0) < 20.0 then
            GeminiBots.FSM:SetState(bot, "investigate")
            return
        end
        bot.investigatePos = nil -- протухший сигнал чистим, чтобы не дергался
    end

    -- Периодический осмотр поворотов и развилок коридоров в лабиринте
    if CurTime() >= (bot.stateData.nextCornerCheck or 0) then
        bot.stateData.nextCornerCheck = CurTime() + math.Rand(1.5, 3.0)

        if bot.path and bot.pathIndex and bot.path[bot.pathIndex] then
            local toNext = (bot.path[bot.pathIndex] - bot.ply:GetPos()):Angle()
            -- Беглый взгляд в сторону коридора/двери на 35-50 градусов
            local glanceYaw = toNext.y + (math.random(0, 1) == 1 and 40 or -40)
            bot.desiredViewAngles = Angle(0, math.NormalizeAngle(glanceYaw), 0)
            bot.viewSrc = "glance"
            bot.keepLookUntil = CurTime() + 0.5
        end
    end

    -- Шли за подбором и взяли его: расходник исчез с земли,
    -- ствол появился в инвентаре — дальше по делам
    if bot.stateData.pickupEnt ~= nil and GeminiBots.Scavenger then
        local done = not IsValid(bot.stateData.pickupEnt)
        if not done and bot.stateData.pickupClass then
            done = GeminiBots.Scavenger:HasClass(bot, bot.stateData.pickupClass)
        end
        if done then
            GeminiBots.FSM:SetState(bot, "idle")
            return
        end
    end

    -- Если цель маршрута достигнута или вышло максимальное время прогулки
    if not bot.path or CurTime() >= (bot.stateData.timeout or 0) then
        GeminiBots.FSM:SetState(bot, "idle")
    end
end

function State:Exit(bot)
    GeminiBots.Navigator:Stop(bot)
    bot.stateData = {}
end

GeminiBots.FSM:RegisterState("wander", State)
