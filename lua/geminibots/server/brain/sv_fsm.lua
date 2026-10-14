--[[
    GeminiBots - Finite State Machine (FSM) Manager
    Управление состояниями ИИ ботов, диспетчеризация логики и главный цикл Think.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.FSM = GeminiBots.FSM or {}
GeminiBots.FSM.States = GeminiBots.FSM.States or {}

-- Регистрация нового состояния в FSM
function GeminiBots.FSM:RegisterState(name, stateTbl)
    if not name or not stateTbl then return end
    stateTbl.Name = name
    stateTbl.Enter = stateTbl.Enter or function() end
    stateTbl.Update = stateTbl.Update or function() end
    stateTbl.Exit = stateTbl.Exit or function() end

    self.States[name] = stateTbl
    GeminiBots:Debug("Зарегистрировано состояние FSM: %s", name)
end

-- Переключение бота в новое состояние
function GeminiBots.FSM:SetState(bot, newStateName, ...)
    if not bot or not newStateName then return end

    -- Выключенные состояния (конвар): все едут в idle, сам idle всегда можно
    local dis = GeminiBots.Config and GeminiBots.Config.DisabledStates
    if dis and dis[newStateName] and newStateName ~= "idle" then
        newStateName = "idle"
    end

    local currentStateObj = self.States[bot.state]
    if currentStateObj and currentStateObj.Exit then
        currentStateObj:Exit(bot)
    end

    local oldState = bot.state
    bot.state = newStateName
    bot.stateData = {} -- Очистка временных данных предыдущего состояния

    local newStateObj = self.States[newStateName]
    if newStateObj and newStateObj.Enter then
        newStateObj:Enter(bot, ...)
        GeminiBots:Debug("Бот %s перешел: %s -> %s", bot.ply:Nick(), oldState or "none", newStateName)
    else
        GeminiBots:Warn("Состояние %s не найдено для бота %s!", newStateName, bot.ply:Nick())
    end
end

-- Обновление одного бота
function GeminiBots.FSM:UpdateBot(bot, dt)
    if not bot or not IsValid(bot.ply) or not bot.ply:Alive() then return end

    local cfg = GeminiBots.Config
    if not cfg or not cfg.Enabled then return end

    -- Сброс кнопок в начале каждого тика логики (состояния сами выставят нужные флаги)
    bot.buttons = 0

    -- 1. Обновление сенсорной памяти
    GeminiBots.Memory:Update(bot)

    -- SWCS-флешка: ослепленный пропускает скан и стоит на месте
    if GeminiBots.SWCS_IsBlind and GeminiBots.SWCS_IsBlind(bot.ply) then
        GeminiBots.SWCS_BlindUpdate(bot)
        bot.nextScanTime = CurTime() + 0.3
        bot.forwardMove, bot.sideMove, bot.upMove = 0, 0, 0
        return
    elseif bot.wasBlind then
        bot.wasBlind = false
    end

    -- 2. Периодическое сканирование целей вокруг.
    -- На минировании руки заняты: не отвлекаемся
    if CurTime() >= (bot.nextScanTime or 0) then
        local scanInterval = (cfg and cfg.ScanInterval) or 0.2
        -- Джиттер сканов: все боты спавнятся разом и сканируют в один тик
        -- (пила нагрузки). Разброс ±50% рассинхронизирует без потери темпа
        bot.nextScanTime = CurTime() + scanInterval * math.Rand(1.0, 1.5)
        if bot.state ~= "plant" and bot.state ~= "defuse" then
            local foundTarget = GeminiBots.Vision:FindBestTarget(bot)
            if IsValid(foundTarget) and foundTarget ~= bot.target then
                -- Липкость цели: в толпе скан каждый раз отдает ближайшего,
                -- цель флипает, каждый флип сбрасывает реакцию и прицел —
                -- бот вечно "почти навелся" и молчит. Новую берем, только
                -- если явно ближе (на четверть); переключение — короткой
                -- реакцией (оба и так в поле зрения), полный ролл — только
                -- на свежий контакт
                local switchFast = false
                if IsValid(bot.target) and bot.target:Alive() then
                    local curD = bot.ply:GetPos():DistToSqr(bot.target:GetPos())
                    local newD = bot.ply:GetPos():DistToSqr(foundTarget:GetPos())
                    if newD >= curD * 0.5625 then
                        foundTarget = nil
                    else
                        switchFast = true
                    end
                end
                if IsValid(foundTarget) then
                    bot.target = foundTarget
                    -- Уходим в бой — свежий сигнал расследования гасим, иначе
                    -- пинг-понг investigate→combat→idle→investigate
                    bot.investigatePos = nil
                    bot.investigateTime = 0
                    local am = GeminiBots.BotAim(bot)
                    if switchFast then
                        bot.reactionTimer = CurTime() + math.Rand(0.1, 0.2)
                    else
                        bot.reactionTimer = CurTime() + math.Rand(am.reactMin, am.reactMax)
                    end

                    -- Если не были в бою, немедленно переключаемся
                    if bot.state ~= "combat" and bot.state ~= "flee" then
                        self:SetState(bot, "combat")
                    end
                end
            end
        end
    end

    -- 3. Выполнение логики текущего состояния
    local stateObj = self.States[bot.state]
    if stateObj and stateObj.Update then
        stateObj:Update(bot, dt)
    else
        -- Фоллбэк на патрулирование, если состояние не определено
        self:SetState(bot, "wander")
    end

    -- Огонь молика рядом: отходим, стрельбу не прерываем
    if GeminiBots.SWCS_AvoidFire then GeminiBots.SWCS_AvoidFire(bot) end

    -- 4. Обновление перемещения по путевым точкам (если бот следует по маршруту)
    if bot.path then
        GeminiBots.Navigator:Update(bot)
    end

    -- Крутилка хвх: стоит без пути и не дерется — вертится.
    -- В бою целится как положено, на ходу идет как положено
    if bot.cheater and bot.cheater.spin and not bot.path then
        local busy = bot.state == "combat" and IsValid(bot.target)
        if not busy then
            local cur = bot.desiredViewAngles or bot.ply:EyeAngles()
            bot.desiredViewAngles = Angle(0, math.NormalizeAngle(cur.y + 540 * dt), 0)
        end
    end
end

-- Главный хук Think для обработки ИИ всех ботов
hook.Add("Think", "GeminiBots_Brain_Think", function()
    local cfg = GeminiBots.Config
    if not cfg or not cfg.Enabled then return end

    local bots = GeminiBots:GetAllBots()
    local dt = FrameTime()
    if dt <= 0 then dt = 0.015 end

    for ply, bot in pairs(bots) do
        if IsValid(ply) and ply:IsBot() and ply:Alive() then
            GeminiBots.FSM:UpdateBot(bot, dt)
        end
    end
end)
