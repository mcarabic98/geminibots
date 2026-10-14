--[[
    GeminiBots - State: Investigate
    Проверка подозрительного шума (bot.investigatePos ставит слух):
    подход к точке, осмотр с поворотами головы (иногда присев),
    затем возврат к обычной жизни. Враг в любой момент уводит в бой.
]]

local FRESH_WINDOW = 20.0 -- сигнал старше — протух, не идем
local STATE_TIMEOUT = 25.0 -- общий лимит на всю проверку
local INSPECT_MIN = 2.5 -- осмотр на точке: от
local INSPECT_MAX = 4.5 -- осмотр на точке: до
local REPATH_DIST = 200 -- новый шум дальше — перестраиваем маршрут

local State = {}

-- Переход к фазе осмотра на месте
local function BeginInspect(bot)
    bot.stateData.phase = "inspect"
    bot.stateData.inspectUntil = CurTime() + math.Rand(INSPECT_MIN, INSPECT_MAX)
    bot.stateData.nextLookTime = 0
    GeminiBots.Navigator:Stop(bot)
end

function State:Enter(bot)
    bot.stateData.phase = "approach"
    bot.stateData.timeout = CurTime() + STATE_TIMEOUT
    bot.stateData.targetPos = bot.investigatePos

    if not bot.stateData.targetPos then
        GeminiBots.FSM:SetState(bot, "idle")
        return
    end

    if not GeminiBots.Navigator:MoveTo(bot, bot.stateData.targetPos) then
        -- Путь не построился: осматриваемся с места и расходимся
        BeginInspect(bot)
    end
end

function State:Update(bot, dt)
    -- Враг в поле зрения — никакого осмотра, сразу бой
    if IsValid(bot.target) then
        GeminiBots.FSM:SetState(bot, "combat")
        return
    end

    -- Общий таймаут: сигнал давно протух или застряли
    if CurTime() >= (bot.stateData.timeout or 0) then
        bot.investigatePos = nil
        GeminiBots.FSM:SetState(bot, "idle")
        return
    end

    -- Новый свежий шум в другую точку — идем туда же
    local sigPos = bot.investigatePos
    local sigFresh = sigPos and (CurTime() - (bot.investigateTime or 0) < FRESH_WINDOW)
    if sigFresh and (not bot.stateData.targetPos
        or sigPos:Distance(bot.stateData.targetPos) > REPATH_DIST) then
        bot.stateData.targetPos = sigPos
        bot.stateData.phase = "approach"
        GeminiBots.Navigator:MoveTo(bot, sigPos)
        return
    end
    if not sigFresh then
        bot.investigatePos = nil
    end

    if (bot.stateData.phase or "approach") == "approach" then
        -- Дошли (пути больше нет) — начинаем осмотр
        if not bot.path then
            BeginInspect(bot)
            return
        end
        -- На ходу смотрим по курсу, иногда косимся в сторону шума
        if CurTime() >= (bot.stateData.nextLookTime or 0) then
            bot.stateData.nextLookTime = CurTime() + math.Rand(0.8, 1.6)
            local yaw
            if bot.path[bot.pathIndex] then
                yaw = (bot.path[bot.pathIndex] - bot.ply:GetPos()):Angle().y
            else
                yaw = bot.ply:EyeAngles().y
            end
            if math.random() < 0.3 and bot.stateData.targetPos then
                yaw = (bot.stateData.targetPos - bot.ply:GetPos()):Angle().y
            end
            bot.desiredViewAngles = Angle(0, math.NormalizeAngle(yaw), 0)
            bot.keepLookUntil = CurTime() + 0.5
        end
        return
    end

    -- Фаза осмотра: стоим, крутим головой, иногда приседаем
    if CurTime() >= (bot.stateData.inspectUntil or 0) then
        bot.investigatePos = nil
        GeminiBots.FSM:SetState(bot, "idle")
        return
    end

    if CurTime() >= (bot.stateData.nextLookTime or 0) then
        bot.stateData.nextLookTime = CurTime() + math.Rand(0.6, 1.2)
        local curYaw = bot.ply:EyeAngles().y
        bot.desiredViewAngles = Angle(math.Rand(-8, 8),
            math.NormalizeAngle(curYaw + math.Rand(-120, 120)), 0)
    end
    -- Присед держим 1-2 сек, а не мигаем каждый тик
    if CurTime() >= (bot.crouchUntil or 0) then
        if math.random() < 0.3 then
            bot.crouchUntil = CurTime() + math.Rand(1.0, 2.0)
        else
            bot.crouchUntil = 0
        end
    end
    if CurTime() < (bot.crouchUntil or 0) then
        bot.buttons = bit.bor(bot.buttons or 0, IN_DUCK)
    end
end

function State:Exit(bot)
    GeminiBots.Navigator:Stop(bot)
    bot.stateData = {}
end

GeminiBots.FSM:RegisterState("investigate", State)
