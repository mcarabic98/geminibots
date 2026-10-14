--[[
    GeminiBots - State: Plant (C4)
    Подрывник ставит бомбу: достает C4 и держит атаку 3 сек (так ставит
    сам SWCS). Стоит смирно, на врагов не отвлекается. Успех — побег,
    провал по таймауту — обычная жизнь.
]]

local ARM_TIMEOUT = 6.5 -- SWCS ставит 3 сек, остальное запас на лаги
local SUCCESS_DIST = 250 -- своя свежая бомба рядом — уже стоит

local State = {}

function State:Enter(bot)
    bot.stateData.timeout = CurTime() + ARM_TIMEOUT
    bot.stateData.armedAt = 0
    if IsValid(bot.ply) and bot.ply:HasWeapon("weapon_swcs_c4") then
        bot.ply:SelectWeapon("weapon_swcs_c4")
    end
    GeminiBots.Navigator:Stop(bot)
end

function State:Update(bot, dt)
    local ply = bot.ply
    if not IsValid(ply) or not ply:Alive() then return end

    -- Успех: рядом свежая бомба или C4 уже забрал SWCS
    local bomb = GeminiBots.C4_NearestLiveBomb
        and GeminiBots.C4_NearestLiveBomb(ply:GetPos(), SUCCESS_DIST) or nil
    if IsValid(bomb) or not ply:HasWeapon("weapon_swcs_c4") then
        bot.plantArmed = nil
        if IsValid(bomb) then
            bot.fleeBomb = bomb
            bot.fleeNoTime = false
            bot.plantedBomb = bomb
        end
        GeminiBots.FSM:SetState(bot, "flee")
        return
    end

    -- Не успел (сбили прицел, душили движением): расходимся
    if CurTime() >= (bot.stateData.timeout or 0) then
        bot.plantArmed = nil
        GeminiBots.FSM:SetState(bot, "wander")
        return
    end

    -- Стоим и держим атаку. SWCS сам заморозит скорость и присядет.
    bot.forwardMove = 0
    bot.sideMove = 0
    bot.buttons = bit.bor(bot.buttons or 0, IN_ATTACK)
end

function State:Exit(bot)
    bot.forwardMove = 0
    bot.sideMove = 0
    bot.buttons = 0
    bot.stateData = {}
end

GeminiBots.FSM:RegisterState("plant", State)
