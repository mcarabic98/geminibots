--[[
    GeminiBots - Loadout & Equipment System
    Управление пулом оружия, выбор разрешенных пушек (через Q-меню, консоль и weapons.txt),
    пресеты (HL2, M9K, пистолеты, автоматы) и выдача экипировки ботам при спавне.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Loadout = GeminiBots.Loadout or {}
GeminiBots.Loadout.Pool = GeminiBots.Loadout.Pool or {}
GeminiBots.Loadout.Active = GeminiBots.Loadout.Active or {}
-- Классы, давшие ошибку при выдаче ботам (сессия). Повторно не выдаются.
GeminiBots.Loadout.Broken = GeminiBots.Loadout.Broken or {}

local DATA_DIR = "geminibots"
local WEAPONS_FILE = DATA_DIR .. "/weapons.txt"
local CONFIG_FILE = DATA_DIR .. "/active_weapons.json"

util.AddNetworkString("GeminiBots_RequestWeaponPool")
util.AddNetworkString("GeminiBots_ReceiveWeaponPool")
util.AddNetworkString("GeminiBots_ToggleWeapon")
util.AddNetworkString("GeminiBots_SetWeaponPreset")
util.AddNetworkString("GeminiBots_AddWeapon")
util.AddNetworkString("GeminiBots_RemoveWeapon")
util.AddNetworkString("GeminiBots_AddHeldWeapon")
util.AddNetworkString("GeminiBots_GiveHeldWeaponToBots")
util.AddNetworkString("GeminiBots_RequestArsenal")
util.AddNetworkString("GeminiBots_ReceiveArsenal")
util.AddNetworkString("GeminiBots_BulkWeapons")

-- Стандартные движковые оружия Source/HL2
local DEFAULT_ENGINE_WEAPONS = {
    ["weapon_pistol"] = "9mm Pistol (HL2)",
    ["weapon_357"] = ".357 Magnum (HL2)",
    ["weapon_smg1"] = "Submachine Gun SMG1 (HL2)",
    ["weapon_ar2"] = "Overwatch Pulse-Rifle AR2 (HL2)",
    ["weapon_shotgun"] = "Shotgun (HL2)",
    ["weapon_crossbow"] = "Crossbow (HL2)",
    ["weapon_crowbar"] = "Crowbar (HL2)",
    ["weapon_frag"] = "Frag Grenade (HL2)",
    ["weapon_rpg"] = "RPG Launcher (HL2)",
    ["weapon_slam"] = "S.L.A.M. (HL2)",
    ["weapon_stunstick"] = "Stunstick (HL2)"
}

-- Дефолтный список оружия при первой установке
local DEFAULT_WEAPONS_LIST = {
    "weapon_pistol",
    "weapon_357",
    "weapon_smg1",
    "weapon_ar2",
    "weapon_shotgun",
    "weapon_crossbow",
    "weapon_crowbar",
    "weapon_rpg",
    "m9k_colt1911",
    "m9k_deagle",
    "m9k_glock",
    "m9k_usp",
    "m9k_ragingbull",
    "m9k_ak47",
    "m9k_m4a1",
    "m9k_mp5",
    "m9k_ump45",
    "m9k_vector",
    "m9k_famas",
    "m9k_scar",
    "m9k_val",
    "m9k_spas12",
    "m9k_remington870",
    "m9k_mossberg590",
    "m9k_striker",
    "m9k_awp",
    "m9k_barret_m82",
    "m9k_svu",
    "m9k_dragunov"
}

-- Проверка доступности оружия на сервере
function GeminiBots.Loadout:IsWeaponAvailable(wepClass)
    if not wepClass or wepClass == "" then return false end
    if DEFAULT_ENGINE_WEAPONS[wepClass] then return true end
    if weapons.Get(wepClass) ~= nil then return true end
    if list.Get("Weapon") and list.Get("Weapon")[wepClass] ~= nil then return true end
    return false
end

-- Получить красивое читаемое название оружия
function GeminiBots.Loadout:GetWeaponPrintName(wepClass)
    if DEFAULT_ENGINE_WEAPONS[wepClass] then
        return DEFAULT_ENGINE_WEAPONS[wepClass]
    end

    local wepObj = weapons.Get(wepClass)
    if wepObj and wepObj.PrintName and wepObj.PrintName ~= "" then
        local pn = wepObj.PrintName
        -- Нелокализованные "#weapon_xxx" / "#spawnmenu.xxx" показываем как класс
        if string.StartWith(pn, "#") then
            return wepClass
        end
        local category = wepObj.Category or ""
        if category ~= "" and not string.StartWith(category, "#") then
            return string.format("%s (%s)", pn, category)
        end
        return pn
    end

    return wepClass
end

-- Тип оружия для фильтра Арсенала: сначала kind адаптера пака,
-- потом HoldType SWEP'а, потом подстроки имени (те же семьи, что в скоринге).
-- Ключи: rifle/smg/pistol/shotgun/sniper/mg/melee/grenade/tactical/special/other
local HOLDTYPE_TYPE = {
    pistol = "pistol", revolver = "pistol", duel = "pistol",
    smg = "smg",
    ar2 = "rifle",
    shotgun = "shotgun",
    crossbow = "sniper",
    rpg = "special",
    melee = "melee", melee2 = "melee", knife = "melee", fist = "melee",
    grenade = "grenade",
    slam = "special",
}

local ADAPTERKIND_TYPE = {
    frag = "grenade",
    tactical = "tactical",
    trap = "special",
    melee = "melee",
    short = "special",
}

function GeminiBots.Loadout:GetWeaponType(wepClass)
    if not wepClass or wepClass == "" then return "other" end

    local WA = GeminiBots.WeaponAdapters
    if WA then
        local ak = WA:Kind(wepClass)
        if ak and ADAPTERKIND_TYPE[ak] then return ADAPTERKIND_TYPE[ak] end
        -- Явные поправки пака (врут HoldType) — до generic-правил
        local to = WA:TypeOverride(wepClass)
        if to then return to end
    end

    -- Пулеметы — до HoldType: SWCS m249/negev значатся shotgun, а по сути MG
    local lower = string.lower(wepClass)
    if string.find(lower, "m249") or string.find(lower, "negev")
        or string.find(lower, "minigun") or string.find(lower, "m60")
        or string.find(lower, "lmg") then
        return "mg"
    end

    local wepObj = weapons.Get(wepClass)
    if wepObj and wepObj.HoldType and HOLDTYPE_TYPE[wepObj.HoldType] then
        return HOLDTYPE_TYPE[wepObj.HoldType]
    end

    if string.find(lower, "shotgun") or string.find(lower, "spas")
        or string.find(lower, "remington") or string.find(lower, "mossberg")
        or string.find(lower, "striker") or string.find(lower, "m1014")
        or string.find(lower, "xm1014") or string.find(lower, "mag7")
        or string.find(lower, "nova") or string.find(lower, "sawedoff") then
        return "shotgun"
    end
    if string.find(lower, "sniper") or string.find(lower, "awp")
        or string.find(lower, "barret") or string.find(lower, "svu")
        or string.find(lower, "dragunov") or string.find(lower, "crossbow")
        or string.find(lower, "scout") or string.find(lower, "ssg08") then
        return "sniper"
    end
    if string.find(lower, "ar2") or string.find(lower, "ak47")
        or string.find(lower, "m4") or string.find(lower, "rifle")
        or string.find(lower, "scar") or string.find(lower, "famas")
        or string.find(lower, "galil") or string.find(lower, "aug")
        or string.find(lower, "g36") or string.find(lower, "sg55")
        or string.find(lower, "g3sg1") then
        return "rifle"
    end
    if string.find(lower, "smg") or string.find(lower, "mp5")
        or string.find(lower, "ump") or string.find(lower, "vector")
        or string.find(lower, "mac10") or string.find(lower, "uzi")
        or string.find(lower, "p90") or string.find(lower, "mp7")
        or string.find(lower, "mp9") or string.find(lower, "tec9")
        or string.find(lower, "bizon") or string.find(lower, "sten")
        or string.find(lower, "thompson") or string.find(lower, "honeybadger")
        or string.find(lower, "pdw") then
        return "smg"
    end
    if string.find(lower, "pistol") or string.find(lower, "357")
        or string.find(lower, "deagle") or string.find(lower, "glock")
        or string.find(lower, "colt") or string.find(lower, "usp")
        or string.find(lower, "revolver") or string.find(lower, "ragingbull")
        or string.find(lower, "hk45") or string.find(lower, "sig")
        or string.find(lower, "luger") or string.find(lower, "beretta")
        or string.find(lower, "python") or string.find(lower, "elite")
        or string.find(lower, "cz") or string.find(lower, "fiveseven")
        or string.find(lower, "p250") or string.find(lower, "p2000")
        or string.find(lower, "hkp") then
        return "pistol"
    end
    if string.find(lower, "knife") or string.find(lower, "bayonet")
        or string.find(lower, "crowbar") or string.find(lower, "stunstick")
        or string.find(lower, "axe") then
        return "melee"
    end
    if string.find(lower, "frag") or string.find(lower, "grenade")
        or string.find(lower, "flash") or string.find(lower, "smoke")
        or string.find(lower, "molotov") then
        return "grenade"
    end
    return "other"
end

-- Определить пак оружия по классу/категории (для фильтров Арсенала)
function GeminiBots.Loadout:GetWeaponPack(wepClass)
    if not wepClass then return "Other" end
    if DEFAULT_ENGINE_WEAPONS[wepClass] then return "HL2" end
    -- Подпись адаптера первее префиксных эвристик (SWCS и др.)
    local WA = GeminiBots.WeaponAdapters
    if WA then
        local ad = WA:Find(wepClass)
        if ad then return ad.title end
    end
    local lower = string.lower(wepClass)
    if string.StartWith(lower, "m9k_") then return "M9K" end
    if string.StartWith(lower, "tfa_") then return "TFA" end
    if string.StartWith(lower, "arccw_") then return "ArcCW" end
    if string.StartWith(lower, "cw_") then return "CW2.0" end

    local wepObj = weapons.Get(wepClass)
    if wepObj and wepObj.Category then
        local cat = string.lower(wepObj.Category)
        if string.find(cat, "m9k") then return "M9K" end
        if string.find(cat, "tfa") then return "TFA" end
        if string.find(cat, "arccw") then return "ArcCW" end
    end
    return "Other"
end

-- Категория SWEP'а (как задано автором оружия)
function GeminiBots.Loadout:GetWeaponCategory(wepClass)
    local wepObj = weapons.Get(wepClass)
    if wepObj and wepObj.Category and wepObj.Category ~= "" then
        return wepObj.Category
    end
    if DEFAULT_ENGINE_WEAPONS[wepClass] then return "Half-Life 2" end
    return "Other"
end

-- Совместимо ли оружие с ботами (точное совпадение с IncompatibleBases)
function GeminiBots.Loadout:IsWeaponCompatible(wepClass)
    if not wepClass or wepClass == "" then return false end
    local cfg = GeminiBots.Config and GeminiBots.Config.Loadout
    local blocked = cfg and cfg.IncompatibleBases
    if not blocked then return true end
    if blocked[wepClass] then return false end
    return true
end

-- Безопасная выдача: ловит ошибки кривых SWEP (напр. SWCS падает в Give),
-- помечает класс как сломанный и подчищает недосозданный ствол
function GeminiBots.Loadout:SafeGive(ply, wepClass)
    if not IsValid(ply) or not wepClass or wepClass == "" then return nil end
    if self.Broken[wepClass] then return nil end
    if not self:IsWeaponCompatible(wepClass) then
        GeminiBots:Debug("Пропуск несовместимого с ботами оружия: %s", wepClass)
        return nil
    end

    local ok, result = xpcall(function()
        return ply:Give(wepClass)
    end, function(err)
        return debug.traceback(err, 2)
    end)

    if not ok then
        self.Broken[wepClass] = true
        local firstLine = string.match(tostring(result), "[^\n]*") or tostring(result)
        GeminiBots:Warn("Оружие %s сломано для ботов, пропуск: %s", wepClass, firstLine)
        for _, w in ipairs(ply:GetWeapons() or {}) do
            if IsValid(w) and w:GetClass() == wepClass then w:Remove() end
        end
        return nil
    end

    if not IsValid(result) then
        self.Broken[wepClass] = true
        GeminiBots:Warn("Оружие %s не выдалось ботам (невалидный энтити), пропуск.", wepClass)
        return nil
    end

    return result
end

-- Скан ВСЕГО установленного на сервере оружия (SWEP-реестр + движковые)
-- Мусор (тулы, камеры, кулаки, багбейт) отсеивается и в Арсенал не попадает.
-- Возвращает список {class, name, pack, category}
local EXCLUDED_WEAPON_CLASSES = {
    ["gmod_tool"] = true,
    ["gmod_camera"] = true,
    ["weapon_fists"] = true,
    ["weapon_bugbait"] = true,
    ["manhack_welder"] = true,
    ["manhacl_welder"] = true,
    -- Технические базы M9K: не спавнятся и без HoldType
    ["bobs_gun_base"] = true,
    ["bobs_shotty_base"] = true,
    ["bobs_scoped_base"] = true,
    ["bobs_blacklisted"] = true,
    -- Технические базы SWCS
    ["weapon_swcs_base"] = true,
    ["weapon_swcs_base_grenade"] = true,
    ["weapon_swcs_base_item"] = true,
    ["weapon_swcs_base_melee_throwable"] = true,
}

function GeminiBots.Loadout:IsWeaponExcluded(wepClass)
    if not wepClass or wepClass == "" then return true end
    if EXCLUDED_WEAPON_CLASSES[wepClass] then return true end
    local lower = string.lower(wepClass)
    if string.StartWith(lower, "gmod_") then return true end
    if string.find(lower, "fists") then return true end
    if string.find(lower, "bugbait") then return true end
    if string.find(lower, "welder") then return true end
    -- Базы любых паков (tfa_gun_base, arccw_base, ...): класс-контейнер,
    -- не оружие. Легитимные стволы "_base" в имени не содержат.
    if string.find(lower, "_base", 1, true) then return true end

    local wepObj = weapons.Get(wepClass)
    if wepObj then
        -- Неспавнящиеся базы любых паков (TFA, Customizable SWEPs и т.п.):
        -- у них нет HoldType/моделей, Give такого класса роняет ошибки
        -- у ЛЮБОГО игрока, не только у ботов. AdminSpawnable==nil считаем
        -- запретом (по дампу у баз spawn=false/nil).
        if wepObj.Spawnable == false and wepObj.AdminSpawnable ~= true then return true end
    end

    if wepObj and wepObj.Category and wepObj.Category ~= "" then
        local cat = string.lower(wepObj.Category)
        if string.find(cat, "tool", 1, true) then return true end
    end

    return false
end

function GeminiBots.Loadout:ScanInstalledWeapons()
    local result = {}
    local seen = {}

    local function push(class)
        if not class or class == "" or seen[class] then return end
        if self:IsWeaponExcluded(class) then return end
        seen[class] = true
        table.insert(result, {
            class = class,
            name = self:GetWeaponPrintName(class),
            pack = self:GetWeaponPack(class),
            category = self:GetWeaponCategory(class)
        })
    end

    for class, _ in pairs(DEFAULT_ENGINE_WEAPONS) do
        push(class)
    end

    for _, wep in ipairs(weapons.GetList() or {}) do
        local cls = wep.ClassName or wep.Class
        if cls and cls ~= "" then push(cls) end
    end

    if list.Get("Weapon") then
        for class, _ in pairs(list.Get("Weapon")) do
            push(class)
        end
    end

    table.sort(result, function(a, b) return a.class < b.class end)
    return result
end

-- Построить данные для Арсенала: merge (установленное + пул).
-- Если includeMissing=false, записи из weapons.txt без установки скрываются.
function GeminiBots.Loadout:GetArsenalData(includeMissing)
    local poolSet = {}
    for _, c in ipairs(self.Pool) do poolSet[c] = true end

    local installed = self:ScanInstalledWeapons()
    local installedSet = {}
    for _, e in ipairs(installed) do installedSet[e.class] = true end

    local out = {}
    for _, e in ipairs(installed) do
        local inPool = poolSet[e.class] == true
        local isActive = false
        if inPool then
            isActive = (self.Active[e.class] ~= false)
        else
            isActive = false
        end
        table.insert(out, {
            class = e.class,
            name = e.name,
            pack = e.pack,
            wtype = self:GetWeaponType(e.class),
            category = e.category,
            active = isActive,
            available = true,
            inPool = inPool,
            compatible = self:IsWeaponCompatible(e.class),
            broken = self.Broken[e.class] == true
        })
    end

    if includeMissing then
        for _, class in ipairs(self.Pool) do
            if not installedSet[class] and not self:IsWeaponAvailable(class) then
                table.insert(out, {
                    class = class,
                    name = self:GetWeaponPrintName(class),
                    pack = self:GetWeaponPack(class),
                    wtype = self:GetWeaponType(class),
                    category = self:GetWeaponCategory(class),
                    active = (self.Active[class] ~= false),
                    available = false,
                    inPool = true,
                    compatible = self:IsWeaponCompatible(class),
                    broken = self.Broken[class] == true
                })
            end
        end
    end

    table.sort(out, function(a, b) return a.class < b.class end)
    return out
end

local function SaveActiveState()
    if not file.IsDir(DATA_DIR, "DATA") then
        file.CreateDir(DATA_DIR)
    end
    file.Write(CONFIG_FILE, util.TableToJSON(GeminiBots.Loadout.Active, true))
end

-- Перезапись weapons.txt из текущего пула (для persistence после скана/пресетов)
local function SavePoolToFile()
    if not file.IsDir(DATA_DIR, "DATA") then
        file.CreateDir(DATA_DIR)
    end
    local content = "# ==============================================================================\n" ..
                    "# GeminiBots - Список оружия для ботов / Bot Weapon Pool\n" ..
                    "# ==============================================================================\n\n"
    for _, c in ipairs(GeminiBots.Loadout.Pool) do
        content = content .. c .. "\n"
    end
    file.Write(WEAPONS_FILE, content)
end

-- Загрузка состояния активных оружий из JSON
local function LoadActiveState()
    if file.Exists(CONFIG_FILE, "DATA") then
        local raw = file.Read(CONFIG_FILE, "DATA")
        if raw and raw ~= "" then
            local data = util.JSONToTable(raw)
            if istable(data) then
                GeminiBots.Loadout.Active = data
                return
            end
        end
    end

    -- По умолчанию все оружие в пуле включено
    GeminiBots.Loadout.Active = {}
    for _, class in ipairs(GeminiBots.Loadout.Pool) do
        GeminiBots.Loadout.Active[class] = true
    end
end

-- Загрузка пула оружия из data/geminibots/weapons.txt
function GeminiBots.Loadout:ReloadWeapons()
    if not file.IsDir(DATA_DIR, "DATA") then
        file.CreateDir(DATA_DIR)
    end

    if not file.Exists(WEAPONS_FILE, "DATA") then
        local header = "# ==============================================================================\n" ..
                       "# GeminiBots - Список оружия для ботов / Bot Weapon Pool\n" ..
                       "# ==============================================================================\n\n"
        for _, class in ipairs(DEFAULT_WEAPONS_LIST) do
            header = header .. class .. "\n"
        end
        file.Write(WEAPONS_FILE, header)
    end

    local raw = file.Read(WEAPONS_FILE, "DATA")
    self.Pool = {}
    local seen = {}

    if raw and raw ~= "" then
        local lines = string.Explode("\n", raw)
        for _, line in ipairs(lines) do
            local trimmed = string.Trim(line)
            if trimmed ~= "" and not string.StartWith(trimmed, "#") and not string.StartWith(trimmed, "//") then
                if not seen[trimmed] then
                    table.insert(self.Pool, trimmed)
                    seen[trimmed] = true
                end
            end
        end
    end

    if #self.Pool == 0 then
        self.Pool = table.Copy(DEFAULT_WEAPONS_LIST)
    end

    LoadActiveState()

    -- Синхронизируем таблицу Active с текущим пулом
    for _, class in ipairs(self.Pool) do
        if self.Active[class] == nil then
            self.Active[class] = true
        end
    end

    -- После перезагрузки пула даем сломанному оружию второй шанс
    self.Broken = {}

    GeminiBots:Log("Загружено оружия в пул GeminiBots: %d (Доступно на сервере: %d)", #self.Pool, #self:GetAvailablePool())
end

-- Добавить оружие в пул
function GeminiBots.Loadout:AddWeapon(class)
    if not class or class == "" then return false end
    class = string.lower(string.Trim(class))

    for _, c in ipairs(self.Pool) do
        if c == class then return false end -- Уже в списке
    end

    table.insert(self.Pool, class)
    self.Active[class] = true
    SaveActiveState()

    -- Дописываем в weapons.txt
    local currentText = file.Read(WEAPONS_FILE, "DATA") or ""
    currentText = currentText .. "\n" .. class
    file.Write(WEAPONS_FILE, currentText)

    GeminiBots:Log("В пул ботов добавлено новое оружие: %s", class)
    return true
end

-- Удалить оружие из пула
function GeminiBots.Loadout:RemoveWeapon(class)
    if not class then return false end
    class = string.lower(string.Trim(class))

    local found = false
    for i, c in ipairs(self.Pool) do
        if c == class then
            table.remove(self.Pool, i)
            found = true
            break
        end
    end

    if found then
        self.Active[class] = nil
        SaveActiveState()
        SavePoolToFile()

        GeminiBots:Log("Оружие удалено из пула ботов: %s", class)
        return true
    end

    return false
end

-- Включить/выключить конкретное оружие
-- Если оружия нет в пуле, но оно установлено: включение = добавить в пул.
-- Технические базы (bobs_gun_base и т.п.) в пул не добавляются никогда.
function GeminiBots.Loadout:SetWeaponActive(class, active)
    if not class then return end
    class = string.lower(string.Trim(class))
    active = (active == true)

    if active and not table.HasValue(self.Pool, class) then
        if self:IsWeaponExcluded(class) then return end
        if self:IsWeaponAvailable(class) then
            table.insert(self.Pool, class)
            SavePoolToFile()
        end
    end

    self.Active[class] = active
    SaveActiveState()
end

-- Вычистить из пула технические базы и мусор (память + weapons.txt)
function GeminiBots.Loadout:PrunePool()
    local removed = {}
    for i = #self.Pool, 1, -1 do
        local class = self.Pool[i]
        if self:IsWeaponExcluded(class) then
            table.remove(self.Pool, i)
            self.Active[class] = nil
            table.insert(removed, class)
        end
    end

    if #removed > 0 then
        SaveActiveState()
        SavePoolToFile()
        GeminiBots:Log("Из пула удалены базовые/мусорные классы (%d): %s", #removed, table.concat(removed, ", "))
    end

    return removed
end

-- Применить быстрый пресет выбора оружия
function GeminiBots.Loadout:ApplyPreset(presetName)
    if not presetName then return end
    presetName = string.lower(presetName)

    -- Если пресет требует M9K или все установленные, сканируем зарегистрированные SWEP'ы и дополняем пул
    if presetName == "m9k" or presetName == "all" then
        local poolChanged = false
        for _, e in ipairs(self:ScanInstalledWeapons()) do
            local cls = e.class
            if presetName == "all" or string.StartWith(cls, "m9k_") then
                if not table.HasValue(self.Pool, cls) then
                    table.insert(self.Pool, cls)
                    poolChanged = true
                end
            end
        end
        if poolChanged then SavePoolToFile() end
    end

    for _, class in ipairs(self.Pool) do
        local isEngineHL2 = DEFAULT_ENGINE_WEAPONS[class] ~= nil
        local isM9K = string.StartWith(class, "m9k_")

        if presetName == "all" then
            self.Active[class] = true
        elseif presetName == "none" then
            self.Active[class] = false
        elseif presetName == "hl2" then
            self.Active[class] = isEngineHL2
        elseif presetName == "m9k" then
            self.Active[class] = isM9K
        elseif presetName == "pistols" then
            local isPistol = string.find(class, "pistol") or string.find(class, "357") or
                             string.find(class, "deagle") or string.find(class, "glock") or
                             string.find(class, "colt") or string.find(class, "usp") or
                             string.find(class, "revolver") or string.find(class, "ragingbull")
            self.Active[class] = (isPistol ~= nil)
        elseif presetName == "rifles" then
            local isRifle = string.find(class, "smg") or string.find(class, "ar2") or
                            string.find(class, "ak47") or string.find(class, "m4a1") or
                            string.find(class, "mp5") or string.find(class, "ump") or
                            string.find(class, "famas") or string.find(class, "scar") or
                            string.find(class, "val") or string.find(class, "vector")
            self.Active[class] = (isRifle ~= nil)
        elseif presetName == "shotguns" then
            local isShotgun = string.find(class, "shotgun") or string.find(class, "spas") or
                              string.find(class, "remington") or string.find(class, "mossberg") or
                              string.find(class, "striker")
            self.Active[class] = (isShotgun ~= nil)
        elseif presetName == "snipers" then
            local isSniper = string.find(class, "crossbow") or string.find(class, "awp") or
                             string.find(class, "barret") or string.find(class, "svu") or
                             string.find(class, "dragunov") or string.find(class, "sniper")
            self.Active[class] = (isSniper ~= nil)
        elseif presetName == "default" then
            self.Active[class] = true
        end
    end

    SaveActiveState()
    GeminiBots:Log("Применен пресет оружия для ботов: %s", presetName)
end

-- Получить реально доступное и включенное оружие
-- Сломанное и несовместимое с ботами отсеивается здесь
function GeminiBots.Loadout:GetAvailablePool()
    local available = {}
    for _, class in ipairs(self.Pool) do
        if (self.Active[class] ~= false)
            and self:IsWeaponAvailable(class)
            and not self.Broken[class]
            and self:IsWeaponCompatible(class) then
            table.insert(available, class)
        end
    end

    if #available == 0 then
        table.insert(available, "weapon_pistol")
    end

    return available
end

-- Перемешивание таблицы
local function ShuffleTable(tbl)
    local n = #tbl
    for i = n, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

-- Роль оружия для умного лоадаута (по типу из GetWeaponType)
local ROLE_OF_TYPE = {
    rifle = "primary", smg = "primary", shotgun = "primary",
    sniper = "primary", mg = "primary",
    pistol = "secondary",
    grenade = "frag",
    tactical = "tactical",
    melee = "melee",
}
-- Порядок предпочтения и лимит единиц на роль: граната/тактика/мили — по
-- одной, стволов можно пару. special/other (ловушки, тазер) не берем вообще
local ROLE_ORDER = { "primary", "secondary", "frag", "tactical", "melee" }
local ROLE_CAP = { primary = 2, secondary = 2, frag = 1, tactical = 1, melee = 1 }

local function RoleOf(class)
    return ROLE_OF_TYPE[GeminiBots.Loadout:GetWeaponType(class)] or "other"
end

-- Умный подбор: ровно wantCount единиц, но без дублей гранат/тактики и
-- обязательно со стреляющим стволом. Возвращает список классов (может быть
-- пустым — тогда вызывающий падает на прежний случайный выбор)
local function BuildSmartLoadout(pool, wantCount)
    local byRole = {}
    for _, class in ipairs(pool) do
        local r = RoleOf(class)
        if r ~= "other" then
            byRole[r] = byRole[r] or {}
            table.insert(byRole[r], class)
        end
    end
    for _, list in pairs(byRole) do ShuffleTable(list) end

    local chosen, taken = {}, {}
    local function take(role)
        if #chosen >= wantCount then return false end
        if (taken[role] or 0) >= (ROLE_CAP[role] or 1) then return false end
        local list = byRole[role]
        if not list or #list == 0 then return false end
        local c = table.remove(list, 1)
        table.insert(chosen, c)
        taken[role] = (taken[role] or 0) + 1
        return true
    end

    -- Сначала по одному на роль, затем добор (второй ствол) до wantCount
    for _, role in ipairs(ROLE_ORDER) do take(role) end
    while #chosen < wantCount do
        local progressed = false
        for _, role in ipairs(ROLE_ORDER) do
            if #chosen >= wantCount then break end
            if take(role) then progressed = true end
        end
        if not progressed then break end
    end

    -- Гарантия стреляющего ствола: одни гранаты/мили — не лоадаут
    local hasShoot = false
    for _, c in ipairs(chosen) do
        local r = RoleOf(c)
        if r == "primary" or r == "secondary" then hasShoot = true break end
    end
    if not hasShoot then
        local gunRole = ((byRole.primary and #byRole.primary > 0) and "primary")
            or ((byRole.secondary and #byRole.secondary > 0) and "secondary") or nil
        if gunRole then
            local gun = table.remove(byRole[gunRole], 1)
            if #chosen >= wantCount and #chosen > 0 then table.remove(chosen, 1) end
            table.insert(chosen, 1, gun)
        end
    end

    return chosen
end

-- Лучший ствол для выбора в руки: primary > secondary > первый
local function PickActiveClass(givenWeapons)
    local best = givenWeapons[1]
    for _, w in ipairs(givenWeapons) do
        if IsValid(w) then
            local r = RoleOf(w:GetClass())
            if r == "primary" then return w:GetClass() end
            if r == "secondary" then best = w end
        end
    end
    return IsValid(best) and best:GetClass() or nil
end

-- Выдать боту случайный набор оружия из активного пула
function GeminiBots.Loadout:EquipBot(ply)
    if not IsValid(ply) or not ply:IsBot() then return end

    -- Murder: экипировкой владеет режим (руки/нож/магнум), свое не выдаем и не стрипаем
    if GeminiBots.MurderActive and GeminiBots.MurderActive() then return end
    -- HL2MP: стволы дает режим и карта, свое не выдаем (гейт явный, а не
    -- только конваром: рестор сохранений из convars.json едет очередью
    -- RunConsoleCommand и может перебить снапшот режима по порядку)
    if GeminiBots.HL2MPActive and GeminiBots.HL2MPActive() then return end

    local cfg = GeminiBots.Config and GeminiBots.Config.Loadout
    if not cfg or not cfg.Enabled then return end

    if cfg.StripDefaultWeapons then
        ply:StripWeapons()
        ply:StripAmmo()
    end

    local pool = self:GetAvailablePool()
    if #pool == 0 then return end

    local available = table.Copy(pool)

    local minWeps = math.Clamp(cfg.MinWeapons or 1, 1, #available)
    local maxWeps = math.Clamp(cfg.MaxWeapons or 3, minWeps, #available)
    local countToGive = math.random(minWeps, maxWeps)

    -- Умный подбор: не более одной гранаты/тактики/рукопашки и хотя бы один
    -- стреляющий ствол. Пул ролево бедный (одни гранаты) — прежний случайный
    local picks
    if cfg.SmartLoadout ~= false then
        picks = BuildSmartLoadout(available, countToGive)
    end
    if not picks or #picks == 0 then
        ShuffleTable(available)
        picks = {}
        for i = 1, countToGive do picks[i] = available[i] end
    end

    local givenWeapons = {}

    for _, wepClass in ipairs(picks) do
        if not wepClass then break end
        local wep = self:SafeGive(ply, wepClass)

        if IsValid(wep) then
            table.insert(givenWeapons, wep)

            -- Настройка патронов тоже под защитой: кривые SWEP падают и тут
            local okSetup = pcall(function()
                local ammoCount = cfg.AmmoAmount or 180

                local primaryAmmo = wep:GetPrimaryAmmoType()
                if primaryAmmo and primaryAmmo ~= -1 then
                    ply:GiveAmmo(ammoCount, primaryAmmo, true)
                end

                local secondaryAmmo = wep:GetSecondaryAmmoType()
                if secondaryAmmo and secondaryAmmo ~= -1 then
                    ply:GiveAmmo(10, secondaryAmmo, true)
                end

                if wep.Clip1 and wep.GetMaxClip1 and wep:GetMaxClip1() > 0 then
                    wep:SetClip1(wep:GetMaxClip1())
                end
            end)

            if not okSetup then
                self.Broken[wepClass] = true
                GeminiBots:Warn("Оружие %s сломано для ботов (настройка патронов), пропуск.", wepClass)
                if IsValid(wep) then wep:Remove() end
                table.remove(givenWeapons)
            end
        end
    end

    if #givenWeapons > 0 then
        -- В руки — стреляющий ствол (primary > secondary), не граната/нож
        local activeClass = PickActiveClass(givenWeapons)
        if activeClass then ply:SelectWeapon(activeClass) end
    end

    GeminiBots:Debug("Боту %s выдано %d единиц оружия.", ply:Nick(), #givenWeapons)
end

hook.Add("PlayerSpawn", "GeminiBots_Loadout_OnSpawn", function(ply)
    if ply:IsBot() then
        timer.Simple(0.05, function()
            if IsValid(ply) and ply:Alive() then
                GeminiBots.Loadout:EquipBot(ply)
            end
        end)
    end
end)

--------------------------------------------------------------------------------
-- Сетевое взаимодействие с клиентом (Q-Меню + Арсенал)
--------------------------------------------------------------------------------
-- Отправка большой таблицы чанками: JSON -> сжатие -> куски по ~30КБ.
-- Протокол: UInt16(transferId), UInt8(total), UInt8(index), UInt16(len), Data(chunk).
-- ВАЖНО: WriteString/ReadString здесь нельзя — сжатый блоб бинарный, внутри
-- есть нулевые байты, а net-строки это C-строки до первого \0 (обрезка!).
-- Иначе net.WriteTable падает с "overflowed net message" на больших паках.
local CHUNK_SIZE = 30000
local transferCounter = 0

local function SendBigTable(netName, tbl, ply)
    transferCounter = (transferCounter + 1) % 65535
    local json = util.TableToJSON(tbl or {})
    local blob = util.Compress(json or "")
    if not blob or #blob == 0 then return end

    local total = math.max(1, math.ceil(#blob / CHUNK_SIZE))
    if total > 255 then return end -- паранойя: ~7МБ таблицы не шлем

    for i = 1, total do
        local piece = string.sub(blob, (i - 1) * CHUNK_SIZE + 1, i * CHUNK_SIZE)
        net.Start(netName)
        net.WriteUInt(transferCounter, 16)
        net.WriteUInt(total, 8)
        net.WriteUInt(i, 8)
        net.WriteUInt(#piece, 16)
        net.WriteData(piece, #piece)
        if IsValid(ply) then
            net.Send(ply)
        else
            net.Broadcast()
        end
    end
end

-- Отправка пула: по умолчанию скрываем неустановленное (missing скрыто).
-- includeMissing=true показывает и отсутствующие (для диагностики).
local function SendWeaponPoolToClient(ply, includeMissing)
    local list = {}
    for _, class in ipairs(GeminiBots.Loadout.Pool) do
        local available = GeminiBots.Loadout:IsWeaponAvailable(class)
        if available or includeMissing then
            table.insert(list, {
                class = class,
                name = GeminiBots.Loadout:GetWeaponPrintName(class),
                pack = GeminiBots.Loadout:GetWeaponPack(class),
                category = GeminiBots.Loadout:GetWeaponCategory(class),
                active = (GeminiBots.Loadout.Active[class] ~= false),
                available = available,
                inPool = true
            })
        end
    end

    SendBigTable("GeminiBots_ReceiveWeaponPool", list, ply)
end

-- Отправка полных данных Арсенала (скан установленного + пул)
local function SendArsenalToClient(ply, includeMissing)
    local data = GeminiBots.Loadout:GetArsenalData(includeMissing == true)
    SendBigTable("GeminiBots_ReceiveArsenal", data, ply)
end

local function RefreshWeaponUI()
    SendWeaponPoolToClient(nil, false)
    SendArsenalToClient(nil, false)
end

net.Receive("GeminiBots_RequestWeaponPool", function(len, ply)
    local includeMissing = false
    if len and len > 0 then
        local ok, val = pcall(net.ReadBool)
        if ok and val ~= nil then includeMissing = val end
    end
    SendWeaponPoolToClient(ply, includeMissing)
end)

net.Receive("GeminiBots_RequestArsenal", function(len, ply)
    local includeMissing = false
    if len and len > 0 then
        local ok, val = pcall(net.ReadBool)
        if ok and val ~= nil then includeMissing = val end
    end
    SendArsenalToClient(ply, includeMissing)
end)

net.Receive("GeminiBots_ToggleWeapon", function(len, ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    local class = net.ReadString()
    local active = net.ReadBool()

    GeminiBots.Loadout:SetWeaponActive(class, active)
    RefreshWeaponUI()
end)

-- Массовое вкл/выкл списка классов (для кнопок Арсенала "включить видимые")
net.Receive("GeminiBots_BulkWeapons", function(len, ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    local tbl = net.ReadTable()
    if not istable(tbl) then return end
    for _, entry in ipairs(tbl) do
        if isstring(entry) then
            GeminiBots.Loadout:SetWeaponActive(entry, true)
        elseif istable(entry) and entry.class then
            GeminiBots.Loadout:SetWeaponActive(entry.class, entry.active ~= false)
        end
    end
    RefreshWeaponUI()
end)

net.Receive("GeminiBots_SetWeaponPreset", function(len, ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    local preset = net.ReadString()

    GeminiBots.Loadout:ApplyPreset(preset)
    RefreshWeaponUI()
end)

net.Receive("GeminiBots_AddWeapon", function(len, ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    local class = net.ReadString()

    if GeminiBots.Loadout:AddWeapon(class) then
        RefreshWeaponUI()
    end
end)

net.Receive("GeminiBots_RemoveWeapon", function(len, ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    local class = net.ReadString()

    if GeminiBots.Loadout:RemoveWeapon(class) then
        RefreshWeaponUI()
    end
end)

net.Receive("GeminiBots_AddHeldWeapon", function(len, ply)
    if not IsValid(ply) then return end
    if not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end

    local activeWep = ply:GetActiveWeapon()
    if not IsValid(activeWep) then
        ply:ChatPrint("[GeminiBots] У вас в руках нет активного оружия!")
        return
    end

    local class = activeWep:GetClass()
    local name = GeminiBots.Loadout:GetWeaponPrintName(class)

    if GeminiBots.Loadout:AddWeapon(class) then
        ply:ChatPrint(string.format("[GeminiBots] Оружие \"%s\" (%s) успешно добавлено в пул ботов!", name, class))
        RefreshWeaponUI()
    else
        ply:ChatPrint(string.format("[GeminiBots] Оружие \"%s\" (%s) уже есть в пуле ботов.", name, class))
    end
end)

net.Receive("GeminiBots_GiveHeldWeaponToBots", function(len, ply)
    if not IsValid(ply) then return end
    if not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end

    local activeWep = ply:GetActiveWeapon()
    if not IsValid(activeWep) then
        ply:ChatPrint("[GeminiBots] Возьмите оружие в руки перед выдачей!")
        return
    end

    local class = activeWep:GetClass()
    if not GeminiBots.Loadout:IsWeaponCompatible(class) then
        ply:ChatPrint(string.format("[GeminiBots] Оружие \"%s\" несовместимо с ботами (см. IncompatibleBases), выдача отменена!", class))
        return
    end
    local count = 0

    for _, botPly in ipairs(player.GetBots()) do
        if IsValid(botPly) and botPly:Alive() then
            local wep = GeminiBots.Loadout:SafeGive(botPly, class)
            if IsValid(wep) then
                pcall(function()
                    local ammo = wep:GetPrimaryAmmoType()
                    if ammo and ammo ~= -1 then botPly:GiveAmmo(180, ammo, true) end
                    botPly:SelectWeapon(class)
                end)
                count = count + 1
            end
        end
    end

    ply:ChatPrint(string.format("[GeminiBots] Оружие \"%s\" мгновенно выдано %d живым ботам!", class, count))
end)

--------------------------------------------------------------------------------
-- Консольные команды
--------------------------------------------------------------------------------
concommand.Add("geminibots_weapon_list", function()
    print("=== [GeminiBots] Пул оружия для ботов (только установленное) ===")
    print("Файл: garrysmod/data/" .. WEAPONS_FILE)
    for _, class in ipairs(GeminiBots.Loadout.Pool) do
        if not GeminiBots.Loadout:IsWeaponAvailable(class) then continue end
        local active = (GeminiBots.Loadout.Active[class] ~= false) and "[ВКЛ / ON]" or "[ВЫКЛ / OFF]"
        local name = GeminiBots.Loadout:GetWeaponPrintName(class)
        local pack = GeminiBots.Loadout:GetWeaponPack(class)
        print(string.format(" - %-22s %-12s [%s] (%s)", class, active, pack, name))
    end
end, nil, "Вывести список всего оружия в пуле ботов")

concommand.Add("geminibots_weapon_scan", function()
    local data = GeminiBots.Loadout:ScanInstalledWeapons()
    print(string.format("=== [GeminiBots] Скан установленного оружия: %d ===", #data))
    local byPack = {}
    for _, e in ipairs(data) do
        byPack[e.pack] = (byPack[e.pack] or 0) + 1
    end
    for pack, n in pairs(byPack) do print(string.format(" - %s: %d", pack, n)) end
    for _, e in ipairs(data) do
        local inPool = table.HasValue(GeminiBots.Loadout.Pool, e.class)
        local compat = GeminiBots.Loadout:IsWeaponCompatible(e.class) and "" or "[НЕ ДЛЯ БОТОВ] "
        print(string.format(" - %-24s [%s] %s%s%s", e.class, e.pack, compat, inPool and "[В ПУЛЕ] " or "", e.name))
    end
end, nil, "Сканировать все установленное на сервере оружие")

concommand.Add("geminibots_weapon_toggle", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    local class = args[1]
    if not class then
        print("[GeminiBots] Использование: geminibots_weapon_toggle <класс_оружия>")
        return
    end

    local current = (GeminiBots.Loadout.Active[class] ~= false)
    GeminiBots.Loadout:SetWeaponActive(class, not current)
    RefreshWeaponUI()
    print(string.format("[GeminiBots] Оружие %s теперь %s", class, (not current) and "ВКЛЮЧЕНО" or "ВЫКЛЮЧЕНО"))
end, nil, "Включить/выключить оружие в пуле (пример: geminibots_weapon_toggle m9k_ak47)")

concommand.Add("geminibots_weapon_add", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    local class = args[1]
    if not class then
        print("[GeminiBots] Использование: geminibots_weapon_add <класс_оружия>")
        return
    end

    if GeminiBots.Loadout:AddWeapon(class) then
        RefreshWeaponUI()
        print("[GeminiBots] Оружие успешно добавлено в пул: " .. class)
    else
        print("[GeminiBots] Оружие уже есть в пуле или неверный класс.")
    end
end, nil, "Добавить новый класс оружия в пул ботов (пример: geminibots_weapon_add m9k_deagle)")

concommand.Add("geminibots_weapon_remove", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    local class = args[1]
    if not class then
        print("[GeminiBots] Использование: geminibots_weapon_remove <класс_оружия>")
        return
    end

    if GeminiBots.Loadout:RemoveWeapon(class) then
        RefreshWeaponUI()
        print("[GeminiBots] Оружие удалено из пула: " .. class)
    else
        print("[GeminiBots] Оружие не найдено в пуле.")
    end
end, nil, "Удалить класс оружия из пула ботов")

concommand.Add("geminibots_weapon_preset", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    local preset = args[1]
    if not preset then
        print("[GeminiBots] Доступные пресеты: hl2, m9k, all, none, pistols, rifles, shotguns, snipers, default")
        return
    end

    GeminiBots.Loadout:ApplyPreset(preset)
    RefreshWeaponUI()
    print("[GeminiBots] Применен пресет: " .. preset)
end, nil, "Применить пресет оружия (пример: geminibots_weapon_preset m9k)")

concommand.Add("geminibots_weapon_reload", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    GeminiBots.Loadout:ReloadWeapons()
    RefreshWeaponUI()
    print("[GeminiBots] Пул оружия успешно перезагружен из файла data/geminibots/weapons.txt")
end, nil, "Перезагрузить список оружия из data/geminibots/weapons.txt")

-- Дамп метаданных оружия в файл: класс | категория | HoldType | спавн.
-- Для точной типизации паков: geminibots_weapon_dump weapon_swcs
-- Намеренно без проверки админа и с перехватом ошибок: команда
-- диагностическая, а тихий return уже один раз стоил нам дня отладки.
concommand.Add("geminibots_weapon_dump", function(ply, cmd, args)
    print("[GeminiBots] weapon_dump: старт...")
    local ok, err = xpcall(function()
        local prefix = string.lower(args[1] or "")
        local list = weapons.GetList() or {}
        print(string.format("[GeminiBots] weapon_dump: всего SWEP в реестре: %d", #list))
        local lines = {}
        for _, w in ipairs(list) do
            if not w or not w.ClassName then continue end
            local cls = w.ClassName
            if prefix ~= "" and not string.StartWith(string.lower(cls), prefix) then continue end
            table.insert(lines, string.format("%s | cat=%s | hold=%s | spawn=%s/%s",
                cls, tostring(w.Category), tostring(w.HoldType),
                tostring(w.Spawnable), tostring(w.AdminSpawnable)))
        end
        table.sort(lines)
        file.Write("geminibots/weapon_dump.txt", table.concat(lines, "\n"))
        print(string.format("[GeminiBots] Дамп оружия (%d записей, префикс '%s'): data/geminibots/weapon_dump.txt",
            #lines, prefix == "" and "*" or prefix))
    end, function(e) return debug.traceback(e, 2) end)
    if not ok then
        print("[GeminiBots] weapon_dump ОШИБКА: " .. tostring(err))
    end
end, nil, "Выгрузить классы/категории/HoldType оружия в data/geminibots/weapon_dump.txt")

concommand.Add("geminibots_weapon_add_held", function(ply)
    if not IsValid(ply) then return end
    if not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end

    local activeWep = ply:GetActiveWeapon()
    if not IsValid(activeWep) then
        ply:ChatPrint("[GeminiBots] Возьмите в руки оружие, которое хотите добавить!")
        return
    end

    local class = activeWep:GetClass()
    local name = GeminiBots.Loadout:GetWeaponPrintName(class)

    if GeminiBots.Loadout:AddWeapon(class) then
        ply:ChatPrint(string.format("[GeminiBots] Оружие \"%s\" (%s) добавлено в пул ботов!", name, class))
        RefreshWeaponUI()
    else
        ply:ChatPrint(string.format("[GeminiBots] Оружие \"%s\" (%s) уже есть в пуле ботов.", name, class))
    end
end, nil, "Добавить оружие, которое сейчас у вас в руках, в пул ботов")

concommand.Add("geminibots_weapon_give_all", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end

    local class = args[1]
    if not class or class == "" then
        if IsValid(ply) and IsValid(ply:GetActiveWeapon()) then
            class = ply:GetActiveWeapon():GetClass()
        end
    end

    if not class or class == "" then
        local msg = "[GeminiBots] Возьмите оружие в руки или укажите класс: geminibots_weapon_give_all <класс>"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end

    local count = 0
    for _, botPly in ipairs(player.GetBots()) do
        if IsValid(botPly) and botPly:Alive() then
            local wep = GeminiBots.Loadout:SafeGive(botPly, class)
            if IsValid(wep) then
                pcall(function()
                    local ammo = wep:GetPrimaryAmmoType()
                    if ammo and ammo ~= -1 then botPly:GiveAmmo(180, ammo, true) end
                    botPly:SelectWeapon(class)
                end)
                count = count + 1
            end
        end
    end

    local msg = string.format("[GeminiBots] Оружие \"%s\" мгновенно выдано %d живым ботам!", class, count)
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end, nil, "Мгновенно выдать оружие из рук (или по классу) всем активным ботам")

concommand.Add("geminibots_weapon_clear_broken", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    GeminiBots.Loadout.Broken = {}
    local msg = "[GeminiBots] Список сломанного оружия очищен, при следующем спавне будет повторная попытка выдачи."
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end, nil, "Сбросить список оружия, помеченного как сломанное для ботов")

concommand.Add("geminibots_weapon_prune", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    local removed = GeminiBots.Loadout:PrunePool()
    RefreshWeaponUI()
    local msg = string.format("[GeminiBots] Чистка пула завершена, удалено: %d", #removed)
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end, nil, "Удалить из пула технические базы (bobs_gun_base и т.п.) и мусор")

-- Инициализация пула при старте сервера
GeminiBots.Loadout:ReloadWeapons()
-- Повторная чистка после полной регистрации SWEP (реестр на момент include еще пуст)
timer.Simple(5, function()
    GeminiBots.Loadout:PrunePool()
end)
