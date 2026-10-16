--[[
    GeminiBots - NPC Adapters (Server)
    Реестр совместимости с NPC-базами по образцу оружейных адаптеров:
    каждый пак описывается отдельным файлом (см. npcs/npc_*.lua),
    а не ветками if в vision. Пак без адаптера работает на generic:
    любой живой NPC/NextBot считается врагом.
    Адаптер дает: префиксы классов, детект присутствия базы,
    проверку "враг ли" (своих не валим) и поправку точки прицеливания.
]]

GeminiBots = GeminiBots or {}
GeminiBots.NPCAdapters = GeminiBots.NPCAdapters or {}
GeminiBots.NPCAdapters.list = GeminiBots.NPCAdapters.list or {}

-- Регистрация: { id="vj", title="VJ Base", prefixes={ "npc_vj_" },
--   Detect=function() ... end,
--   IsEnemy=function(bot, ent) return true/false/nil end, -- nil = generic
--   AimHeight=function(ent) return 60 end }
function GeminiBots.NPCAdapters:Register(def)
    assert(def and def.id and def.title, "bad npc adapter")
    def.prefixes = def.prefixes or {}
    for i, a in ipairs(self.list) do
        if a.id == def.id then
            self.list[i] = def
            return
        end
    end
    table.insert(self.list, def)
end

local function MatchPrefix(lower, prefixes)
    for _, p in ipairs(prefixes or {}) do
        if string.StartWith(lower, p) then return true end
    end
    return false
end

function GeminiBots.NPCAdapters:Find(class)
    if not class or class == "" then return nil end
    local lower = string.lower(class)
    for _, a in ipairs(self.list) do
        if MatchPrefix(lower, a.prefixes) then return a end
    end
    return nil
end

-- Сущность считается NPC-целью: штатные NPC, NextBot'ы (DrGBase и др.),
-- либо класс из префиксов адаптера.
-- Без pcall: IsPlayer/IsNPC/IsNextBot/GetClass — нативные методы движка,
-- есть у каждой сущности. pcall в горячем цикле — дорогой, а ловить нечего
function GeminiBots.NPCAdapters:IsNPCEntity(ent)
    if not IsValid(ent) then return false end
    if ent:IsPlayer() then return false end
    if ent:IsNPC() then return true end
    if ent:IsNextBot() then return true end
    return self:Find(ent:GetClass() or "") ~= nil
end

-- Generic: живой и не мертвый. Адаптер может уточнить (своих пропускаем)
function GeminiBots.NPCAdapters:IsEnemy(bot, ent)
    if not IsValid(ent) then return false end
    local cls = ""
    pcall(function() cls = ent:GetClass() or "" end)
    local a = self:Find(cls)
    if a and type(a.IsEnemy) == "function" then
        local ok, res = pcall(a.IsEnemy, a, bot, ent)
        if ok and res ~= nil then return res end
    end
    local okH, hp = pcall(function() return ent:Health() end)
    if okH and hp ~= nil and hp <= 0 then return false end
    local okNPC, isNPC = pcall(function() return ent:IsNPC() end)
    if okNPC and isNPC then
        local okSt, st = pcall(function() return ent:GetNPCState() end)
        if okSt and st == NPC_STATE_DEAD then return false end
    end
    return true
end

-- Точка прицеливания: адаптер может дать высоту, иначе центр/глаза
function GeminiBots.NPCAdapters:AimPos(ent)
    if not IsValid(ent) then return nil end
    local cls = ""
    pcall(function() cls = ent:GetClass() or "" end)
    local a = self:Find(cls)
    if a and type(a.AimHeight) == "function" then
        local ok, h = pcall(a.AimHeight, a, ent)
        if ok and type(h) == "number" then
            return ent:GetPos() + Vector(0, 0, h)
        end
    end
    local okE, ep = pcall(function() return ent:EyePos() end)
    if okE and ep then return ep end
    local okC, cp = pcall(function() return ent:OBBCenter() end)
    if okC and cp then return ent:GetPos() + cp end
    return ent:GetPos() + Vector(0, 0, 50)
end

-- Кэш списка NPC-сущностей: ents.GetAll каждый тик на каждого бота
-- дорого, обновляем раз в секунду и раздаем всем сканам
GeminiBots.NPCAdapters.Cache = GeminiBots.NPCAdapters.Cache or {}
GeminiBots.NPCAdapters.CacheAt = GeminiBots.NPCAdapters.CacheAt or -99

function GeminiBots.NPCAdapters:AllNPCs()
    local now = CurTime()
    if self.CacheAt + 1 < now or not self.Cache then
        local out = {}
        for _, e in ipairs(ents.GetAll()) do
            if self:IsNPCEntity(e) then out[#out + 1] = e end
        end
        self.Cache = out
        self.CacheAt = now
    end
    return self.Cache
end
