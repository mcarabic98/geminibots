--[[
    GeminiBots - ESP Sender (Server)
    Раз в 0.1 сек шлет компактные данные ботов ТОЛЬКО админам с включенным
    ESP (не Broadcast). Без LOS-проверок: цифры дешевые, рисует клиент.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.ESP = GeminiBots.ESP or {}

util.AddNetworkString("GeminiBots_ESPToggle")
util.AddNetworkString("GeminiBots_ESPData")

local SEND_INTERVAL = 0.1
local nextSend = 0

-- Порядок ДОЛЖЕН совпадать с STATE_NAMES на клиенте
local STATE_IDS = { idle = 0, wander = 1, combat = 2, flee = 3, investigate = 4, plant = 5, defuse = 6 }

-- Тип звука, на который идет бот (поле bot.investigateKind ставят слух-хуки)
local SND_IDS = { gunfire = 1, steps = 2, decoy = 3, c4 = 4 }

local function IsAdmin(ply)
    return not IsValid(ply) or ply:IsSuperAdmin() or ply:IsAdmin() or game.SinglePlayer()
end

local function EspAdmins()
    local out = {}
    for _, ply in ipairs(player.GetHumans()) do
        -- Права перепроверяем каждый тик: разжалованный админ ESP больше не получает
        if IsValid(ply) and ply.GeminiBots_ESP
            and (ply:IsSuperAdmin() or ply:IsAdmin() or game.SinglePlayer()) then
            table.insert(out, ply)
        end
    end
    return out
end

local function SendESPData(adminPly)
    -- Фильтруем заранее: счетчик обязан совпадать с числом записей,
    -- иначе клиентский ридер уйдет в мусор по всему сообщению
    local valid = {}
    for _, botPly in ipairs(player.GetBots()) do
        if IsValid(botPly) then
            table.insert(valid, botPly)
            if #valid >= 255 then break end
        end
    end

    net.Start("GeminiBots_ESPData")
    net.WriteUInt(#valid, 8)

    -- Огни молика одним списком на всех ботов, а не FindByClass на каждого
    local fires = {}
    for _, f in ipairs(ents.FindByClass("swcs_inferno")) do
        if IsValid(f) then table.insert(fires, f:GetPos()) end
    end
    local fireRadius = (GeminiBots.Config and GeminiBots.Config.SWCS
        and GeminiBots.Config.SWCS.FireRadius) or 320

    for _, botPly in ipairs(valid) do

        local bot = GeminiBots:GetBot(botPly)
        local stateId = 0
        if bot and STATE_IDS[bot.state] ~= nil then
            stateId = STATE_IDS[bot.state]
        end

        local targetLabel = "-"
        if bot and IsValid(bot.target) then
            targetLabel = bot.target:IsPlayer() and bot.target:Nick() or bot.target:GetClass()
        end

        local wepClass = "-"
        local wep = botPly:GetActiveWeapon()
        if IsValid(wep) then wepClass = wep:GetClass() end

        -- Бит 0 — оглушен флешкой, бит 1 — рядом огонь (отходит от молика),
        -- биты 2-3 — команда детматча (0 нет, 1 Rebel, 2 Combine; только HL2MP)
        local flags = 0
        local blindTenths = 0
        if GeminiBots.SWCS_IsBlind and GeminiBots.SWCS_IsBlind(botPly) then
            flags = flags + 1
            local remain = botPly:GetNWFloat("BlindUntilTime", 0) - CurTime()
            blindTenths = math.Clamp(math.ceil(math.max(0, remain) * 10), 0, 255)
        end
        if #fires > 0 then
            local bp = botPly:GetPos()
            for _, fp in ipairs(fires) do
                if bp:Distance(fp) <= fireRadius then
                    flags = flags + 2
                    break
                end
            end
        end

        local sndId = 0
        if bot and bot.investigateKind then
            sndId = SND_IDS[bot.investigateKind] or 0
        end
        if GeminiBots.HL2MPActive and GeminiBots.HL2MPActive() then
            local t = botPly:Team()
            if t == 1 or t == 2 then flags = flags + t * 4 end
        end
        local invPos = (bot and bot.state == "investigate" and bot.investigatePos) or nil

        -- Статус бомбы: 1 ставлю, 2 убегаю, 3 ищу, 4 дефужу, 5 не хватит времени
        local bombStatus = 0
        if bot then
            if bot.state == "plant" then
                bombStatus = 1
            elseif bot.state == "defuse" then
                bombStatus = 4
            elseif bot.state == "flee" and bot.fleeBomb ~= nil then
                bombStatus = bot.fleeNoTime and 5 or 2
            elseif bot.state == "investigate" and bot.investigateKind == "c4" then
                bombStatus = 3
            end
        end

        net.WriteEntity(botPly)
        net.WriteVector(botPly:GetPos())
        net.WriteVector(botPly:EyePos())
        net.WriteUInt(math.Clamp(botPly:Health(), 0, 65535), 16)
        net.WriteUInt(math.Clamp(botPly:GetMaxHealth(), 0, 65535), 16)
        net.WriteUInt(stateId, 3)
        net.WriteString(targetLabel)
        net.WriteString(wepClass)
        net.WriteUInt(flags, 4)
        net.WriteUInt(sndId, 3)
        net.WriteUInt(blindTenths, 8)
        net.WriteUInt(bombStatus, 3)
        net.WriteBool(invPos ~= nil)
        if invPos then net.WriteVector(invPos) end
        net.WriteUInt((bot and bot.cheatId) or 0, 3)
    end

    net.Send(adminPly)
end

hook.Add("Think", "GeminiBots_ESP_Think", function()
    if CurTime() < nextSend then return end
    nextSend = CurTime() + SEND_INTERVAL

    local admins = EspAdmins()
    if #admins == 0 then return end

    for _, adm in ipairs(admins) do
        if IsValid(adm) then SendESPData(adm) end
    end
end)

net.Receive("GeminiBots_ESPToggle", function(_, ply)
    if not IsValid(ply) or not IsAdmin(ply) then return end
    ply.GeminiBots_ESP = net.ReadBool() == true

    if not ply.GeminiBots_ESP then
        -- Сразу очистить экран клиента
        net.Start("GeminiBots_ESPData")
        net.WriteUInt(0, 8)
        net.Send(ply)
    end
end)

hook.Add("PlayerDisconnected", "GeminiBots_ESP_Cleanup", function(ply)
    ply.GeminiBots_ESP = nil
end)
