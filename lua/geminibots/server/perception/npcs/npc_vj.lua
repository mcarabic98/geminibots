--[[
    GeminiBots - NPC Adapter: VJ Base
    VJ-монстры — штатные NPC (IsNPC true, класс npc_vj_*), но со своей
    системой "свой/чужой": диспозиция к игроку + класс VJ_NPC_Class.
    Союзников (CLASS_PLAYER_ALLY) и мирных не трогаем.
]]

GeminiBots = GeminiBots or {}
GeminiBots.NPCAdapters = GeminiBots.NPCAdapters or {}

GeminiBots.NPCAdapters:Register({
    id = "vj",
    title = "VJ Base",
    prefixes = { "npc_vj_" },

    Detect = function()
        return VJBASE_VERSION ~= nil or _VJBASE ~= nil
            or file.Exists("autorun/vj_base_autorun.lua", "LUA")
    end,

    IsEnemy = function(self, bot, ent)
        -- Союзники VJ: свой класс, их пропускаем всегда
        local okC, cls = pcall(function() return ent.VJ_NPC_Class end)
        if okC and type(cls) == "table" then
            for _, c in ipairs(cls) do
                if c == "CLASS_PLAYER_ALLY" then return false end
            end
        elseif okC and cls == "CLASS_PLAYER_ALLY" then
            return false
        end
        -- Диспозиция движка: враг/страх = цель, остальное = нет
        local okD, disp = pcall(function()
            return ent:Disposition(bot and bot.ply or nil)
        end)
        if okD and disp ~= nil then
            if disp == D_HT or disp == D_FR then return true end
            if disp == D_LI or disp == D_NU then return false end
        end
        return nil -- undecided: generic (живой = враг)
    end,

    AimHeight = function(self, ent)
        -- VJ-модели выше/ниже штатных: целимся в 60% высоты
        local okMn, mn = pcall(function() return ent:OBBMins() end)
        local okMx, mx = pcall(function() return ent:OBBMaxs() end)
        if okMn and okMx and mn and mx then
            return math.Clamp((mx.z - mn.z) * 0.6, 20, 120)
        end
        return nil
    end,
})
