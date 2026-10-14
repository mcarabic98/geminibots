--[[
    GeminiBots - Weapon Scavenger (Server)
    Подбор пушек с карты: бот идет к лежащему стволу тиром выше своего
    и берет касанием (штатный пикап движка). Безоружный ищет по всей
    округе, вооруженный — только апгрейд рядом. Ловушки (SLAM и т.п.)
    бот ставить не умеет — игнорит. В Murder выключен: экипировкой
    владеет режим (v1 scope Murder).
    Вызывается из wander (Enter/Update), кэш стволов общий на всех ботов.
]]

GeminiBots = GeminiBots or {}
GeminiBots.Scavenger = GeminiBots.Scavenger or {}

-- Радиусы поиска: безоружный идет далеко, сытый — только за углом
local UNARMED_RADIUS = 4500
local UPGRADE_RADIUS = 1500

-- Тир ствола по классу: выше тир — сильнее (грубо, для подбора хватает).
-- -1 — мусор (утилиты, ловушки): не подбор, селектор их тоже в 0
local function Tier(class)
    local lower = string.lower(class or "")
    if lower == "" then return -1 end
    -- Утилиты: тулганы, камеры, гравипушки — не оружие
    if string.find(lower, "toolgun", 1, true)
        or string.find(lower, "camera", 1, true)
        or string.find(lower, "physcannon", 1, true)
        or string.find(lower, "physgun", 1, true)
        or string.find(lower, "hands", 1, true) then
        return -1
    end
    -- Ловушки бот ставить не умеет
    local boom = GeminiBots.WeaponSelector
        and GeminiBots.WeaponSelector:ExplosiveKind(class) or nil
    if boom == "trap" then return -1 end
    -- Рукопашка: не ствол, но голому лучше ножа ничего нет
    if string.find(lower, "crowbar", 1, true)
        or string.find(lower, "stunstick", 1, true)
        or string.find(lower, "knife", 1, true) then
        return 0
    end
    -- Гранатометы: мощно, но с риском — тир высокий, бой решает дистанцию
    if string.find(lower, "rpg", 1, true)
        or string.find(lower, "launcher", 1, true)
        or string.find(lower, "m79", 1, true)
        or string.find(lower, "gp25", 1, true)
        or string.find(lower, "m203", 1, true) then
        return 5
    end
    -- Винтовки и дальнобой
    if string.find(lower, "ar2", 1, true)
        or string.find(lower, "ak47", 1, true)
        or string.find(lower, "m4", 1, true)
        or string.find(lower, "rifle", 1, true)
        or string.find(lower, "scar", 1, true)
        or string.find(lower, "famas", 1, true)
        or string.find(lower, "galil", 1, true)
        or string.find(lower, "aug", 1, true)
        or string.find(lower, "crossbow", 1, true)
        or string.find(lower, "sniper", 1, true)
        or string.find(lower, "awp", 1, true) then
        return 4
    end
    -- Дробовики и магнум-револьверы
    if string.find(lower, "shotgun", 1, true)
        or string.find(lower, "spas", 1, true)
        or string.find(lower, "m1014", 1, true)
        or string.find(lower, "xm1014", 1, true)
        or string.find(lower, "nova", 1, true)
        or string.find(lower, "mag7", 1, true)
        or string.find(lower, "357", 1, true)
        or string.find(lower, "deagle", 1, true)
        or string.find(lower, "python", 1, true)
        or string.find(lower, "frag", 1, true) then
        return 3
    end
    -- ПП и автоматы-коротыши
    if string.find(lower, "smg", 1, true)
        or string.find(lower, "mp5", 1, true)
        or string.find(lower, "ump", 1, true)
        or string.find(lower, "vector", 1, true)
        or string.find(lower, "mac10", 1, true)
        or string.find(lower, "uzi", 1, true)
        or string.find(lower, "p90", 1, true)
        or string.find(lower, "mp7", 1, true)
        or string.find(lower, "mp9", 1, true) then
        return 2
    end
    -- Пистолеты
    if string.find(lower, "pistol", 1, true)
        or string.find(lower, "glock", 1, true)
        or string.find(lower, "usp", 1, true)
        or string.find(lower, "colt", 1, true)
        or string.find(lower, "beretta", 1, true)
        or string.find(lower, "revolver", 1, true) then
        return 1
    end
    -- Неизвестный ствол: средний, пусть берет
    return 2
end

-- Лучший тир в инвентаре бота
function GeminiBots.Scavenger:BestTier(bot)
    if not bot or not IsValid(bot.ply) then return 0 end
    local best = 0
    for _, w in ipairs(bot.ply:GetWeapons() or {}) do
        if IsValid(w) then
            local t = Tier(w:GetClass())
            if t > best then best = t end
        end
    end
    return best
end

-- Есть ли у бота ствол такого класса
function GeminiBots.Scavenger:HasClass(bot, class)
    if not bot or not IsValid(bot.ply) then return false end
    for _, w in ipairs(bot.ply:GetWeapons() or {}) do
        if IsValid(w) and w:GetClass() == class then return true end
    end
    return false
end

-- Кэш лежащих стволов: FindByClass каждый тик на каждого бота дорого.
-- CacheAt = -99: первый скан сразу строит, а не отдает пустоту 2 секунды
GeminiBots.Scavenger.Cache = GeminiBots.Scavenger.Cache or {}
GeminiBots.Scavenger.CacheAt = GeminiBots.Scavenger.CacheAt or -99

function GeminiBots.Scavenger:GroundWeapons()
    local now = CurTime()
    if (self.CacheAt or 0) + 2 < now or not self.Cache then
        local out = {}
        for _, e in ipairs(ents.FindByClass("weapon_*")) do
            if IsValid(e) then
                -- Чужой ствол в руках — не трогаем, только лежащие
                local owner = nil
                pcall(function() owner = e:GetOwner() end)
                if not IsValid(owner) then
                    out[#out + 1] = e
                end
            end
        end
        self.Cache = out
        self.CacheAt = now
    end
    return self.Cache
end

-- Найти апгрейд: позиция + сущность. nil — идти не за чем
function GeminiBots.Scavenger:FindUpgrade(bot)
    if not bot or not IsValid(bot.ply) then return nil end
    -- Murder: экипировкой владеет режим, лута нет
    if GeminiBots.MurderActive and GeminiBots.MurderActive() then return nil end
    local best = self:BestTier(bot)
    local radius = (best <= 0) and UNARMED_RADIUS or UPGRADE_RADIUS
    local pos = bot.ply:GetPos()
    local bestEnt, bestDist = nil, radius * radius
    for _, e in ipairs(self:GroundWeapons()) do
        if IsValid(e) then
            local class = e:GetClass()
            -- Свой такой уже есть — не идем
            if not self:HasClass(bot, class) then
                local t = Tier(class)
                -- Строго выше; голый берет и рукопашку (тир 0 >= 0),
                -- мусор (тир -1) не берет никто
                if (t > best or (best <= 0 and t >= 0)) and t >= 0 then
                    local d = pos:DistToSqr(e:GetPos())
                    if d < bestDist then
                        bestDist = d
                        bestEnt = e
                    end
                end
            end
        end
    end
    if IsValid(bestEnt) then
        return bestEnt:GetPos(), bestEnt
    end
    return nil
end

--------------------------------------------------------------------------------
-- Расходники: аптечки, батареи, патроны. Зеркало правил подбора HL2DM:
-- лечилка при HP<max, батарея при броне<max, патроны при запасе<max.
--------------------------------------------------------------------------------
local SUPPLY_RADIUS = 2000
local CRITICAL_RADIUS = 3000

-- Тип патрона -> классы коробок на карте (HL2 + HL1)
local AMMO_ITEMS = {
    Pistol = { "item_ammo_pistol" },
    SMG1 = { "item_ammo_smg1" },
    AR2 = { "item_ammo_ar2", "item_ammo_ar2_large" },
    Buckshot = { "item_box_buckshot" },
    ["357"] = { "item_ammo_357" },
    XBowBolt = { "item_ammo_crossbow" },
    RPG_Round = { "item_rpg_round" },
    SMG1_Grenade = { "item_ammo_smg1_grenade" },
    AR2AltFire = { "item_ammo_ar2_altfire" },
    ["9mmRound"] = { "ammo_glockclip", "ammo_9mmbox", "ammo_mp5clip" },
    MP5_Grenade = { "ammo_mp5grenades" },
    RPG_Rocket = { "ammo_rpgclip" },
    BuckshotHL1 = { "ammo_buckshot" },
    ["357Round"] = { "ammo_357" },
    Uranium = { "ammo_gaussclip" },
    XBoxBoltHL1 = { "ammo_crossbow" },
}

GeminiBots.Scavenger.ItemCache = GeminiBots.Scavenger.ItemCache or {}
GeminiBots.Scavenger.ItemCacheAt = GeminiBots.Scavenger.ItemCacheAt or -99

function GeminiBots.Scavenger:GroundItems()
    local now = CurTime()
    if (self.ItemCacheAt or 0) + 2 < now or not self.ItemCache then
        local out = {}
        for _, e in ipairs(ents.FindByClass("item_*")) do
            if IsValid(e) then out[#out + 1] = e end
        end
        for _, e in ipairs(ents.FindByClass("ammo_*")) do
            if IsValid(e) then out[#out + 1] = e end
        end
        self.ItemCache = out
        self.ItemCacheAt = now
    end
    return self.ItemCache
end

-- Каких патронов не хватает: множество имен типов (Pistol, SMG1...)
function GeminiBots.Scavenger:MissingAmmo(bot)
    local need = {}
    if not bot or not IsValid(bot.ply) then return need end
    for _, w in ipairs(bot.ply:GetWeapons() or {}) do
        if IsValid(w) then
            local okId, aid = pcall(function() return w:GetPrimaryAmmoType() end)
            if okId and aid and aid > 0 then
                local reserve = bot.ply:GetAmmoCount(aid)
                local okClip, maxClip = pcall(function() return w:GetMaxClip1() end)
                local want = (okClip and maxClip and maxClip > 0) and maxClip * 2 or 30
                if reserve < want then
                    local okN, aname = pcall(function() return game.GetAmmoName(aid) end)
                    if okN and aname then need[aname] = true end
                end
            end
        end
    end
    return need
end

-- Найти расходник: critical=true — только лечение при тяжелом ранении.
-- Возвращает позицию + сущность
function GeminiBots.Scavenger:FindSupply(bot, critical)
    if not bot or not IsValid(bot.ply) then return nil end
    if GeminiBots.MurderActive and GeminiBots.MurderActive() then return nil end
    local ply = bot.ply
    local maxHP = ply:GetMaxHealth()
    -- Вне крита лечимся при потере >5%: детур за vial при 99/100 — суета
    local hurt = ply:Health() < maxHP * (critical and 0.4 or 0.95)
    local okArmor, armor = pcall(function() return ply:Armor() end)
    local okMaxArmor, maxArmor = pcall(function() return ply:GetMaxArmor() end)
    local wantBattery = not critical and okArmor and okMaxArmor
        and armor < maxArmor * 0.5
    local wantAmmo = {}
    if not critical then wantAmmo = self:MissingAmmo(bot) end
    if not hurt and not wantBattery and next(wantAmmo) == nil then return nil end

    local radius = critical and CRITICAL_RADIUS or SUPPLY_RADIUS
    local pos = ply:GetPos()
    local bestEnt, bestDist = nil, radius * radius
    for _, e in ipairs(self:GroundItems()) do
        if IsValid(e) then
            local class = e:GetClass()
            local ok = false
            if hurt and (class == "item_healthkit" or class == "item_healthvial") then
                ok = true
            elseif wantBattery and class == "item_battery" then
                ok = true
            elseif next(wantAmmo) ~= nil then
                for ammoName in pairs(wantAmmo) do
                    local boxes = AMMO_ITEMS[ammoName]
                    if boxes then
                        for _, b in ipairs(boxes) do
                            if b == class then ok = true break end
                        end
                    end
                    if ok then break end
                end
            end
            if ok then
                local d = pos:DistToSqr(e:GetPos())
                if d < bestDist then
                    bestDist = d
                    bestEnt = e
                end
            end
        end
    end
    if IsValid(bestEnt) then
        return bestEnt:GetPos(), bestEnt
    end
    return nil
end

-- Общая цель вылазки: тяжелое ранение -> лечение, потом ствол,
-- потом батарея/патроны. Возвращает позицию, сущность и класс ствола
-- (для расходников класс nil — взятие видно по исчезновению сущности)
function GeminiBots.Scavenger:FindGoal(bot)
    local pos, ent = self:FindSupply(bot, true)
    if pos then return pos, ent, nil end
    pos, ent = self:FindUpgrade(bot)
    if pos then return pos, ent, IsValid(ent) and ent:GetClass() or nil end
    pos, ent = self:FindSupply(bot, false)
    if pos then return pos, ent, nil end
    return nil
end
