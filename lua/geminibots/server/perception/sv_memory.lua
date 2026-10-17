--[[
    GeminiBots - Memory & Reaction System
    Запоминание последней позиции цели, потеря из виду и реакция на полученный урон.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Memory = GeminiBots.Memory or {}

-- Обновление памяти бота по текущей цели
function GeminiBots.Memory:Update(bot)
    if not bot or not IsValid(bot.ply) then return end

    local target = bot.target
    if not IsValid(target) then
        bot.target = nil
        bot.lastKnownTargetPos = nil
        bot.targetLostTime = 0
        return
    end
    -- Alive есть не у всех сущностей: не смогли проверить — считаем живым
    -- (иначе NPC без метода сбрасывался бы каждый тик и его нельзя добить)
    local okAlive, alive = pcall(function() return target:Alive() end)
    if okAlive and not alive then
        bot.target = nil
        bot.lastKnownTargetPos = nil
        bot.targetLostTime = 0
        return
    end

    -- Цель стала невалидной (ушел в спектаторы/ноклип, смена команды
    -- или режима целей): забываем сразу, а не держим бой с призраком
    if not GeminiBots.Vision:IsValidTarget(bot, target)
        or not GeminiBots.Vision:CanTargetClass(bot, target) then
        bot.target = nil
        bot.lastKnownTargetPos = nil
        bot.targetLostTime = 0
        return
    end

    local hasLOS = GeminiBots.Vision:HasLineOfSight(bot, target)

    if hasLOS then
        -- Вернулся из-за укрытия: засчитать пик (прятался дольше 0.7 сек).
        -- Три пика за 12 секунд = "нычкотролль", бот пожалуется.
        if (bot.targetLostTime or 0) > 0 then
            local hiddenFor = CurTime() - bot.targetLostTime
            if hiddenFor > 0.7 and GeminiBots.Chat and GeminiBots.Chat.SayCombatTaunt then
                if CurTime() - (bot.peekWindow or 0) > 12 then
                    bot.peekWindow = CurTime()
                    bot.peekCount = 0
                end
                bot.peekCount = (bot.peekCount or 0) + 1
                if bot.peekCount >= 3 then
                    bot.peekCount = 0
                    GeminiBots.Chat:SayCombatTaunt(bot, "PEEKER")
                end
            end
        end
        -- Цель в упор: обновляем позицию и скорость (пригодится прострелу)
        bot.lastKnownTargetPos = target:GetPos()
        bot.lastSeenVel = target:GetVelocity()
        bot.targetLostTime = 0
    else
        -- Цель скрылась за препятствием
        if (bot.targetLostTime or 0) == 0 then
            bot.targetLostTime = CurTime()
            bot.lastKnownTargetPos = target:GetPos()
        end

        local cfg = GeminiBots.Config
        local memoryDuration = (cfg and cfg.MemoryDuration) or 6.0

        -- Если прошло больше времени памяти, бот забывает цель
        if CurTime() - bot.targetLostTime > memoryDuration then
            bot.target = nil
            bot.lastKnownTargetPos = nil
            bot.targetLostTime = 0
            GeminiBots:Debug("Бот %s потерял цель из памяти.", bot.ply:Nick())
        end
    end
end

-- Реакция на получение урона: бот мгновенно реагирует на атакующего
hook.Add("EntityTakeDamage", "GeminiBots_Memory_OnTakeDamage", function(target, dmginfo)
    if not IsValid(target) or not target:IsPlayer() or not target:IsBot() then return end

    local bot = GeminiBots:GetBot(target)
    if not bot then return end

    -- На минировании урон терпим: кнопку отпускать нельзя
    if bot.state == "plant" or bot.state == "defuse" then return end

    local attacker = dmginfo:GetAttacker()
    if IsValid(attacker) and attacker ~= target
        and GeminiBots.Vision:IsValidTarget(bot, attacker)
        and GeminiBots.Vision:CanTargetClass(bot, attacker) then
        -- Дуэлянт не отвлекается на посторонних: только его противник
        local duel = GeminiBots.Duels and GeminiBots.Duels[target]
        if duel and IsValid(duel.enemy) and attacker ~= duel.enemy then
            return
        end
        -- Если у бота нет цели или текущая цель скрыта, переключаемся на обидчика
        if not IsValid(bot.target) or (bot.targetLostTime and bot.targetLostTime > 0) then
            bot.target = attacker
            bot.lastKnownTargetPos = attacker:GetPos()
            bot.targetLostTime = 0

            -- Поворачиваемся в сторону обидчика (только yaw: разворот
            -- к ногам накоротке клал pitch, тот же баг что в скане)
            local okD, dir = pcall(function()
                return (attacker:EyePos() - target:EyePos()):Angle()
            end)
            if okD and dir then
                bot.desiredViewAngles = Angle(0, dir.y, 0)
                bot.viewSrc = "hurt"
            end

            -- Переключаем в боевое состояние
            if GeminiBots.FSM and GeminiBots.FSM.SetState then
                GeminiBots.FSM:SetState(bot, "combat")
            end
        end
    end
end)
