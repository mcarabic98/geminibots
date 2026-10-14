--[[
    GeminiBots - Weapon Pack Adapters (Server)
    Скелет совместимости с оружейными паками: каждый пак описывается
    отдельным файлом-адаптером (см. packs/wp_*.lua), а не ветками if.
    Адаптер дает: детект по префиксу класса, переопределение kind
    (frag / launcher / trap / melee / short / tactical), паузу между
    выстрелами и подпись для Арсенала/Q-меню. Пак без адаптера работает
    на generic-скоринге селектора (средние оценки) — бот его берет,
    но без спецтактики.
]]

GeminiBots = GeminiBots or {}
GeminiBots.WeaponAdapters = GeminiBots.WeaponAdapters or {}
GeminiBots.WeaponAdapters.list = GeminiBots.WeaponAdapters.list or {}
GeminiBots.WeaponAdapters.Active = GeminiBots.WeaponAdapters.Active or {}

local DATA_FILE = "geminibots/pack_adapters.json"

util.AddNetworkString("GeminiBots_RequestWeaponAdapters")
util.AddNetworkString("GeminiBots_ReceiveWeaponAdapters")
util.AddNetworkString("GeminiBots_ToggleWeaponAdapter")

-- Регистрация адаптера: { id="swcs", title="SWCS",
--   prefixes={ "weapon_swcs_" },
--   kinds={ {"hegrenade","frag"}, {"c4","trap"}, ... },
--   burst={ {"taser",1.2} } }
function GeminiBots.WeaponAdapters:Register(def)
    assert(def and def.id and def.title, "bad weapon adapter")
    def.prefixes = def.prefixes or {}
    def.kinds = def.kinds or {}
    def.burst = def.burst or {}
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
        -- Префиксы адаптера тоже в нижний: заглавные в определении молча не матчились
        if string.StartWith(lower, string.lower(p)) then return true end
    end
    return false
end

-- Найти адаптер по классу (по префиксу). Состояние вкл/выкл не учитывает.
function GeminiBots.WeaponAdapters:Find(class)
    if not class or class == "" then return nil end
    local lower = string.lower(class)
    for _, a in ipairs(self.list) do
        if MatchPrefix(lower, a.prefixes) then return a end
    end
    return nil
end

function GeminiBots.WeaponAdapters:IsEnabled(id)
    return self.Active[id] ~= false
end

-- Kind класса по адаптеру (nil = generic-логика селектора).
-- Выключенный адаптер ничего не перекрывает.
function GeminiBots.WeaponAdapters:Kind(class)
    local a = self:Find(class)
    if not a or not self:IsEnabled(a.id) then return nil end
    local lower = string.lower(class)
    for _, rule in ipairs(a.kinds) do
        if rule[1] and rule[2] and string.find(lower, string.lower(rule[1]), 1, true) then
            return rule[2]
        end
    end
    return nil
end

-- Поправки типов, где HoldType автора врет (примеры — в wp_swcs).
function GeminiBots.WeaponAdapters:TypeOverride(class)
    local a = self:Find(class)
    if not a or not self:IsEnabled(a.id) then return nil end
    if type(a.types) ~= "table" then return nil end
    local lower = string.lower(class)
    for _, rule in ipairs(a.types) do
        if rule[1] and rule[2] and string.find(lower, string.lower(rule[1]), 1, true) then
            return rule[2]
        end
    end
    return nil
end

-- Пауза между выстрелами для класса (сек). nil = стандарт селектора.
-- Кламп снизу: 0 от адаптера давал бы full-auto каждый тик
function GeminiBots.WeaponAdapters:BurstDelay(class)
    local a = self:Find(class)
    if not a or not self:IsEnabled(a.id) then return nil end
    local lower = string.lower(class)
    for _, rule in ipairs(a.burst) do
        if rule[1] and rule[2] and string.find(lower, string.lower(rule[1]), 1, true) then
            return math.max(tonumber(rule[2]) or 0, 0.05)
        end
    end
    return nil
end

-- Счет адаптера с учетом состояния бота (кулдауны тактики).
-- Возвращает число или nil (nil = обычная логика селектора).
-- Вызывает user-функцию адаптера a.score(bot, class, dist) через pcall.
function GeminiBots.WeaponAdapters:AdapterScore(bot, class, dist)
    local a = self:Find(class)
    if not a or not self:IsEnabled(a.id) then return nil end
    if type(a.score) ~= "function" then return nil end
    local ok, res = pcall(a.score, bot, class, dist)
    if ok and type(res) == "number" then return res end
    return nil
end

-- Точка тактического броска (флеш/смок/декой): a.tacticPoint(bot, target, class).
function GeminiBots.WeaponAdapters:TacticPoint(bot, target, class)
    local a = self:Find(class)
    if not a or not self:IsEnabled(a.id) then return nil end
    if type(a.tacticPoint) ~= "function" then return nil end
    local ok, res = pcall(a.tacticPoint, bot, target, class)
    if ok and res then return res end
    return nil
end

-- Допкнопки атаки (только рукопашка: тяжелый удар). Ошибки адаптера
-- не должны ронять бой, поэтому pcall.
function GeminiBots.WeaponAdapters:ExtraButtons(bot, wep, dist)
    if not bot or not IsValid(wep) then return 0 end
    local class = wep:GetClass()
    local a = self:Find(class)
    if not a or not self:IsEnabled(a.id) then return 0 end
    if type(a.extraButtons) ~= "function" then return 0 end
    if self:Kind(class) ~= "melee" then return 0 end
    local ok, res = pcall(a.extraButtons, bot, wep, dist)
    if ok and type(res) == "number" then return res end
    return 0
end

-- Состояние вкл/выкл (persist в data)
local function LoadActiveState()
    local self = GeminiBots.WeaponAdapters
    self.Active = {}
    if file.Exists(DATA_FILE, "DATA") then
        local tbl = util.JSONToTable(file.Read(DATA_FILE, "DATA") or "")
        if istable(tbl) then self.Active = tbl end
    end
end

local function SaveActiveState()
    file.Write(DATA_FILE, util.TableToJSON(GeminiBots.WeaponAdapters.Active or {}))
end

LoadActiveState()

-- Установлен ли пак на сервере (хоть один ствол с его префиксом в реестре)
local function IsDetected(adapter)
    for _, w in ipairs(weapons.GetList() or {}) do
        if w and w.ClassName and MatchPrefix(string.lower(w.ClassName), adapter.prefixes) then
            return true
        end
    end
    return false
end

function GeminiBots.WeaponAdapters:GetAdaptersList()
    local out = {}
    for _, a in ipairs(self.list) do
        table.insert(out, {
            id = a.id,
            title = a.title,
            detected = IsDetected(a),
            active = self:IsEnabled(a.id)
        })
    end
    return out
end

local function SendAdaptersToClient(ply)
    local list = GeminiBots.WeaponAdapters:GetAdaptersList()
    net.Start("GeminiBots_ReceiveWeaponAdapters")
    net.WriteTable(list)
    if IsValid(ply) then net.Send(ply) else net.Broadcast() end
end

net.Receive("GeminiBots_RequestWeaponAdapters", function(_, ply)
    SendAdaptersToClient(ply)
end)

net.Receive("GeminiBots_ToggleWeaponAdapter", function(_, ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then
        return
    end
    local id = net.ReadString()
    local active = net.ReadBool()
    GeminiBots.WeaponAdapters.Active[id] = (active == true)
    SaveActiveState()
    GeminiBots:Log("Адаптер оружейного пака %s %s", id, active and "ВКЛЮЧЕН" or "ВЫКЛЮЧЕН")
    SendAdaptersToClient()
end)

concommand.Add("geminibots_pack_list", function()
    print("=== [GeminiBots] Адаптеры оружейных паков ===")
    for _, a in ipairs(GeminiBots.WeaponAdapters:GetAdaptersList()) do
        print(string.format(" - %-8s %-10s %s / %s", a.id, a.title,
            a.detected and "[НАЙДЕН]" or "[нет на сервере]",
            a.active and "[ВКЛ]" or "[ВЫКЛ]"))
    end
end, nil, "Список адаптеров оружейных паков (SWCS, M9K, TFA, ...)")
