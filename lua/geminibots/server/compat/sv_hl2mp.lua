--[[
    GeminiBots - HL2MP Gamemode Compatibility (Server)
    Ремейк HL2 Deathmatch (workshop 557213208, папка hl2mp):
    - FFA (teamplay 0): бьют все во всех — наш командный фильтр
      зрения пропускал бы своих по команде, здесь он обойден;
    - TDM (teamplay 1): только чужая команда, зеркало
      PlayerShouldTakeDamage режима (свой урон режим режет);
    - живым считается игрок команды Rebel/Combine, зеркало
      IsPlayerAlive режима (наблюдатели и конец раунда — не цели);
    - экипировкой владеет режим (лоадаут спавна + подбор с карты):
      наш лодаут отключен снапшотом, как в Murder;
    - подбор пушек с карты общий (Scavenger): бот идет к стволу тиром
      выше своего и берет касанием.
    Чего нет в v1: умный скоринг подбора под дистанцию боя
    (берем по тиру, а не по селектору), квота добора ботов под режим.
]]

GeminiBots = GeminiBots or {}

local HL2MP_MODE = false
do
    local ok, gm = pcall(engine.ActiveGamemode)
    HL2MP_MODE = ok and gm == "hl2mp"
end

function GeminiBots.HL2MPActive()
    return HL2MP_MODE
end

-- TDM ли сейчас (конвар режима реплицирован, читаем вживую:
-- админ может переключить на ходу)
function GeminiBots.HL2MPIsTDM()
    local cv = GetConVar("sv_hl2mp_teamplay")
    return cv and cv:GetBool() or false
end

--------------------------------------------------------------------------------
-- Снапшот настроек на время HL2MP (как в Murder): сохраняем текущие,
-- применяем режимные, после возвращаем обратно.
--------------------------------------------------------------------------------
local SNAP_FILE = "geminibots/hl2mp_prev_config.json"

local HL2MP_CONFIG = {
    geminibots_loadout_enabled = "0", -- стволы дает режим + карта
    geminibots_vision_range = "4000", -- карты большие и открытые: дальше видим
    geminibots_gun_hearing_range = "6000", -- дальняя перестрелка стягивает всех
}

local function SnapshotCurrent()
    local snap = {}
    for name, cv in pairs(GeminiBots.ConVars or {}) do
        if cv then
            local ok, val = pcall(function() return cv:GetString() end)
            if ok and val ~= nil then snap[name] = val end
        end
    end
    file.Write(SNAP_FILE, util.TableToJSON(snap, true))
end

local function ApplyConfig(tbl)
    for name, val in pairs(tbl or {}) do
        local cv = GetConVar(name)
        if cv then
            local ok, err = pcall(function() cv:SetString(tostring(val)) end)
            if not ok then
                GeminiBots:Warn("HL2MP-конфиг: не вышло выставить %s: %s", name, tostring(err))
            end
        end
    end
    if GeminiBots.SyncConfigFromConVars then
        GeminiBots:SyncConfigFromConVars()
    end
end

-- Применение отложено на 3 сек: рестор сохранений из convars.json едет
-- очередью RunConsoleCommand и выполняется ПОСЛЕ загрузки файлов. Мгновенный
-- Apply здесь проиграл бы гонку (настройки песочницы перебили бы режимные),
-- а SnapshotCurrent снял бы еще не восстановленные дефолты вместо настроек
-- пользователя. Поведенческие гейты (EquipBot и др.) от тайминга не зависят.
if HL2MP_MODE then
    GeminiBots.SuppressPersist = true -- режимные значения в сохранения не пишем
    GeminiBots:Log("HL2MP: режим обнаружен, конфиг применится через 3 сек.")
    timer.Simple(3, function()
        if not HL2MP_MODE then return end
        if not file.Exists(SNAP_FILE, "DATA") then
            SnapshotCurrent()
            GeminiBots:Log("HL2MP: настройки песочницы сохранены в data/%s.", SNAP_FILE)
        end
        ApplyConfig(HL2MP_CONFIG)
        GeminiBots:Log("HL2MP: применен особый конфиг режима.")
    end)
else
    -- Сбрасываем флаг только если и Murder не активен (файл Murder грузится раньше)
    if not (GeminiBots.MurderActive and GeminiBots.MurderActive()) then
        GeminiBots.SuppressPersist = false
    end
    if file.Exists(SNAP_FILE, "DATA") then
        local snap = util.JSONToTable(file.Read(SNAP_FILE, "DATA") or "")
        if istable(snap) then
            -- Возвращаем ТОЛЬКО ключи режима (см. Murder: полный снапшот
            -- затирал правки пользователя устаревшими значениями)
            local back = {}
            for name in pairs(HL2MP_CONFIG) do
                if snap[name] ~= nil then back[name] = snap[name] end
            end
            ApplyConfig(back)
            GeminiBots:Log("HL2MP: предыдущие настройки восстановлены.")
        else
            GeminiBots:Warn("HL2MP: снапшот бит, восстановить не вышло: %s.", SNAP_FILE)
        end
        file.Delete(SNAP_FILE)
        GeminiBots:SaveConVarsNow()
    end
end

-- Может ли бот целиться в ent (только hl2mp; вызывается из Vision).
-- Зеркало PlayerShouldTakeDamage + IsPlayerAlive режима.
function GeminiBots.HL2MPCanTarget(bot, ent)
    if not IsValid(ent) or not ent:IsPlayer() then return true end
    if not bot or not IsValid(bot.ply) then return false end
    if not ent:Alive() then return false end
    -- Только бойцы команд (наблюдатели/конец раунда — не цели)
    local t = ent:Team()
    if t ~= 1 and t ~= 2 then return false end -- TEAM_REBEL/TEAM_COMBINE
    -- TDM: чужая команда. FFA: все живые
    if GeminiBots.HL2MPIsTDM() then
        return t ~= bot.ply:Team()
    end
    return true
end

--------------------------------------------------------------------------------
-- Вывод ботов из спектаторов: их PlayerInitialSpawn кладет ВСЕХ в
-- TEAM_SPECTATOR, а выводит только F2-меню человека. Наш общий автовыбор
-- ставит команду, но не спавнит — поэтому здесь свой пуш: команда
-- (меньшая) + ForceTeam/ForcePlayerModel (иначе их PlayerSetTeamModel
-- свалит всех в Combine) + Spawn. Дозорным таймером: застрявших в
-- наблюдателях подбираем и позже (смена карты, кик/заход).
--------------------------------------------------------------------------------
local function HL2MPTeamCounts()
    local r, c = 0, 0
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            if p:Team() == 1 then r = r + 1
            elseif p:Team() == 2 then c = c + 1 end
        end
    end
    return r, c
end

local function HL2MPPushBot(ply)
    if not HL2MP_MODE then return end
    if not IsValid(ply) or not ply:IsBot() then return end
    local t = ply:Team()
    local spectating = ply:GetObserverMode() ~= OBS_MODE_NONE
    local inGame = (t == 1 or t == 2) and not spectating and ply:Alive()
    if inGame then return end
    -- Команда: держим свою, новичка — в меньшую
    local want = t
    if want ~= 1 and want ~= 2 then
        local r, c = HL2MPTeamCounts()
        want = (r <= c) and 1 or 2
    end
    ply.HL2MP_ForceTeam = want
    ply.HL2MP_ForcePlayerModel = (want == 1) and "male10" or "combine"
    ply:SetTeam(want)
    ply:Spawn()
end

hook.Add("PlayerInitialSpawn", "GeminiBots_HL2MP_TeamPush", function(ply)
    if not HL2MP_MODE then return end
    if not IsValid(ply) or not ply:IsBot() then return end
    -- Разброс задержки: пачка разом рожденных ботов иначе видит одни
    -- и те же счеты и ложится в одну команду
    timer.Simple(1.5 + math.random() * 1.5, function()
        HL2MPPushBot(ply)
    end)
end)

-- Дисбаланс команд: перегнать одного бота из большей в меньшую.
-- Людей не трогаем, воюющих не дергаем (респаун = суицид с потерей
-- позиции), за раз одного (следующий доберет через 5 сек)
local function HL2MPRebalance()
    local r, c = HL2MPTeamCounts()
    if math.abs(r - c) <= 1 then return end
    local big = (r > c) and 1 or 2
    local small = (big == 1) and 2 or 1
    for _, ply in ipairs(player.GetBots()) do
        if IsValid(ply) and ply:Team() == big then
            local bot = GeminiBots:GetBot(ply)
            if bot and bot.state == "combat" then continue end
            ply.HL2MP_ForceTeam = small
            ply.HL2MP_ForcePlayerModel = (small == 1) and "male10" or "combine"
            ply:SetTeam(small)
            if ply:Alive() then ply:Spawn() end
            GeminiBots:Log("HL2MP: бот %s переведен в команду %d (баланс %d/%d).",
                ply:Nick(), small, r, c)
            return
        end
    end
end

if HL2MP_MODE then
    timer.Create("GeminiBots_HL2MP_SpectWatch", 5, 0, function()
        for _, ply in ipairs(player.GetBots()) do
            HL2MPPushBot(ply)
        end
        HL2MPRebalance()
    end)
end
