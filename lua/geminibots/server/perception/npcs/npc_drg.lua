--[[
    GeminiBots - NPC Adapter: DrGBase
    DrG-монстры — NextBot-SENT'ы (IsNPC false, IsNextBot true), классы
    у каждого пака свои, поэтому префиксы широкие + детект по глобалу.
    Дружелюбных (фракция к игроку / флаг) пропускаем, остальных валим.
    Точный API DrGBase гуляет между версиями — все вызовы в pcall,
    неизвестно = generic (живой = враг).
]]

GeminiBots = GeminiBots or {}
GeminiBots.NPCAdapters = GeminiBots.NPCAdapters or {}

local function PCallMethod(ent, name, arg)
    local fn = ent[name]
    if type(fn) ~= "function" then return nil end
    local ok, res = pcall(fn, ent, arg)
    if ok then return res end
    return nil
end

GeminiBots.NPCAdapters:Register({
    id = "drg",
    title = "DrGBase",
    prefixes = { "drg_", "npc_drg", "nextbot_" },

    Detect = function()
        return DrGBase ~= nil or file.Exists("autorun/drgbase_autorun.lua", "LUA")
    end,

    IsEnemy = function(self, bot, ent)
        -- Явный флаг дружелюбия у NextBot'а
        local friendly = PCallMethod(ent, "DrG_IsFriendly")
        if friendly == true then return false end
        local hostile = PCallMethod(ent, "DrG_IsHostile")
        if hostile == true then return true end
        if hostile == false then return false end
        -- Отношение фракции к игроку (если база дает такой метод)
        local ply = bot and bot.ply or nil
        if IsValid(ply) then
            local rel = PCallMethod(ent, "GetRelationship", ply)
            if rel == D_HT or rel == D_FR then return true end
            if rel == D_LI or rel == D_NU then return false end
            local disp = PCallMethod(ent, "Disposition", ply)
            if disp == D_HT or disp == D_FR then return true end
            if disp == D_LI or disp == D_NU then return false end
        end
        -- Упавший/сдавшийся NextBot: не добиваем лежачего
        local downed = PCallMethod(ent, "IsDowned")
        if downed == true then return false end
        return nil -- undecided: generic (живой = враг)
    end,

    AimHeight = function(self, ent)
        local okMn, mn = pcall(function() return ent:OBBMins() end)
        local okMx, mx = pcall(function() return ent:OBBMaxs() end)
        if okMn and okMx and mn and mx then
            return math.Clamp((mx.z - mn.z) * 0.6, 20, 120)
        end
        return nil
    end,
})
