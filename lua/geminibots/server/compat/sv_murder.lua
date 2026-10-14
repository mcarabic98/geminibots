--[[
    GeminiBots - Murder Gamemode Compatibility (Server)
    Оригинальный Murder (workshop 187073946). В режиме:
    - экипировкой владеет режим (руки/нож/магнум): наш лодаут отключен;
    - все в одной команде специально: командный фильтр зрения обойден,
      вместо него фильтр ролей (см. MurderCanTarget);
    - чат фрагов/смертей/камбэков/клапбэков/секреток выключен: боты видят
      убийцу, называть его в чат (= ломать дедукцию) нельзя;
    - дуэли выключены (лок ствола конфликтует с ножом/магнумом);
    - бот-мирняк знает убийцу, только если ВИДЕЛ убийство (LOS на киллера
      в момент смерти), его пырнули лично или убийца раскрыт режимом;
    - бот, зашедший посреди раунда, выпускается играть сразу (свежий,
      в этом раунде не умирал), а не маринуется трупом до следующего;
    - безоружный мирняк при известном убийце рядом — бежит (flee),
      а не дерется руками (дружественный огонь = TK-наказание режима).
    Чего нет в v1: сбор улик, подбор выпавшего магнума, сознательные
    обвинения в чат, лок ножа убийце (рулетка нож/руки, оба бьют вблизи).
]]

GeminiBots = GeminiBots or {}
GeminiBots.Murder = GeminiBots.Murder or {}
GeminiBots.Murder.Known = GeminiBots.Murder.Known or {}
GeminiBots.Murder.DiedThisRound = GeminiBots.Murder.DiedThisRound or {}

local MURDER_MODE = false
do
    local ok, gm = pcall(engine.ActiveGamemode)
    MURDER_MODE = ok and gm == "murder"
end

function GeminiBots.MurderActive()
    return MURDER_MODE
end

--------------------------------------------------------------------------------
-- Снапшот настроек на время Murder: сохраняем текущие, применяем режимные,
-- после возвращаем обратно.
--------------------------------------------------------------------------------
local SNAP_FILE = "geminibots/murder_prev_config.json"

local MURDER_CONFIG = {
    geminibots_loadout_enabled = "0", -- экипировкой владеет режим
    geminibots_chat_kill_chance = "0", -- именам убийц в чате не место
    geminibots_chat_death_chance = "0",
    geminibots_chat_comeback_chance = "0",
    geminibots_combat_max_dist = "600", -- карты Murder тесные
    geminibots_target_mode = "both", -- фильтр ролей все равно первее
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
                GeminiBots:Warn("Murder-конфиг: не вышло выставить %s: %s", name, tostring(err))
            end
        end
    end
    -- Дожимаем синк конваров явно
    if GeminiBots.SyncConfigFromConVars then
        GeminiBots:SyncConfigFromConVars()
    end
end

-- Применение отложено на 3 сек: рестор сохранений из convars.json едет
-- очередью RunConsoleCommand и выполняется ПОСЛЕ загрузки файлов.
if MURDER_MODE then
    GeminiBots.SuppressPersist = true -- режимные значения в сохранения не пишем
    GeminiBots:Log("Murder: режим обнаружен, конфиг применится через 3 сек.")
    timer.Simple(3, function()
        if not MURDER_MODE then return end
        if not file.Exists(SNAP_FILE, "DATA") then
            SnapshotCurrent()
            GeminiBots:Log("Murder: настройки песочницы сохранены в data/%s.", SNAP_FILE)
        end
        ApplyConfig(MURDER_CONFIG)
        GeminiBots:Log("Murder: применен особый конфиг режима.")
    end)
else
    GeminiBots.SuppressPersist = false
    if file.Exists(SNAP_FILE, "DATA") then
        local snap = util.JSONToTable(file.Read(SNAP_FILE, "DATA") or "")
        if istable(snap) then
            -- Возвращаем ТОЛЬКО ключи режима: полный снапшот затирал бы
            -- правки пользователя (напр. preserve_bots, включенный уже
            -- в режиме) устаревшими значениями на момент входа
            local back = {}
            for name in pairs(MURDER_CONFIG) do
                if snap[name] ~= nil then back[name] = snap[name] end
            end
            ApplyConfig(back)
            GeminiBots:Log("Murder: предыдущие настройки восстановлены.")
        else
            GeminiBots:Warn("Murder: снапшот бит, восстановить не вышло: %s.", SNAP_FILE)
        end
        file.Delete(SNAP_FILE)
        GeminiBots:SaveConVarsNow()
    end
end

-- Может ли бот целиться в ent (только murder; вызывается из Vision)
function GeminiBots.MurderCanTarget(bot, ent)
    if not IsValid(ent) or not ent:IsPlayer() then return false end
    if not bot or not IsValid(bot.ply) then return false end
    -- Убийца валит всех подряд — это игра
    if bot.ply:GetMurderer() then return true end
    -- Мирный: только известный убийца (видел сам / раскрыт режимом)
    local known = GeminiBots.Murder.Known[bot.ply]
    if IsValid(known) and known == ent then return true end
    if ent:GetMurdererRevealed() then return true end
    return false
end

-- Есть ли у бота огнестрел режима (магнум)
function GeminiBots.MurderHasGun(botPly)
    for _, w in ipairs(botPly:GetWeapons() or {}) do
        if IsValid(w) and w:GetClass() == "weapon_mu_magnum" then return true end
    end
    return false
end

-- Найти публично раскрытого убийцу (туман режима его подсветил)
local function FindRevealedMurderer()
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:IsPlayer() and p:Alive() and p:GetMurdererRevealed() then
            return p
        end
    end
    return nil
end

-- Безоружный мирняк при известном убийце рядом — бежать.
-- Возвращает true, если увел бота в flee.
function GeminiBots.MurderFleeCheck(bot)
    if not MURDER_MODE then return false end
    local ply = bot and bot.ply
    if not IsValid(ply) or not ply:Alive() then return false end
    if ply:GetMurderer() then return false end -- убийца не бежит
    if GeminiBots.MurderHasGun(ply) then return false end -- вооружен — дерись

    local known = GeminiBots.Murder.Known[ply]
    if not IsValid(known) or not known:Alive() then
        known = FindRevealedMurderer()
        if not known then return false end
    end
    if ply:GetPos():Distance(known:GetPos()) > 900 then return false end

    bot.target = known
    GeminiBots.FSM:SetState(bot, "flee")
    return true
end

if not MURDER_MODE then return end

-- Свидетель запоминает убийцу в лицо. Погибшие в раунде помечаются.
hook.Add("PlayerDeath", "GeminiBots_Murder_Witness", function(victim, inflictor, attacker)
    if IsValid(victim) and victim:IsPlayer() then
        GeminiBots.Murder.DiedThisRound[victim] = true
    end
    if not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim then return end
    for botPly, bot in pairs(GeminiBots.Bots or {}) do
        if not IsValid(botPly) or not botPly:Alive() then continue end
        if botPly == victim or botPly == attacker then continue end
        if not bot then continue end
        local seen = GeminiBots.Vision:HasLineOfSight(bot, attacker)
        if seen then
            GeminiBots.Murder.Known[botPly] = attacker
        end
    end
end)

-- Пырнули лично — убийца известен без вариантов.
-- victim:IsBot только у игроков: у NPC метода нет, проверяем класс первым
hook.Add("EntityTakeDamage", "GeminiBots_Murder_LearnAttacker", function(victim, dmginfo)
    if not IsValid(victim) or not victim:IsPlayer() then return end
    if not victim:IsBot() then return end
    local atk = dmginfo and dmginfo:GetAttacker()
    if IsValid(atk) and atk:IsPlayer() and atk ~= victim then
        GeminiBots.Murder.Known[victim] = atk
    end
end)

-- Новый раунд: знание и смерти сбрасываются
hook.Add("OnStartRound", "GeminiBots_Murder_Reset", function()
    GeminiBots.Murder.Known = {}
    GeminiBots.Murder.DiedThisRound = {}
end)

-- Чистка таблиц при выходе
hook.Add("PlayerDisconnected", "GeminiBots_Murder_Cleanup", function(ply)
    GeminiBots.Murder.Known[ply] = nil
    GeminiBots.Murder.DiedThisRound[ply] = nil
    for botPly, known in pairs(GeminiBots.Murder.Known) do
        if known == ply then GeminiBots.Murder.Known[botPly] = nil end
    end
end)

-- Зашедший посреди раунда играет сразу. Стадии режима учитываем.
hook.Add("PlayerInitialSpawn", "GeminiBots_Murder_Joiner", function(ply)
    if not IsValid(ply) or not ply:IsBot() then return end
    timer.Simple(2.0, function()
        if not IsValid(ply) or ply:Alive() then return end
        if ply:Team() ~= 2 then return end
        if GeminiBots.Murder.DiedThisRound[ply] then return end
        if not (GAMEMODE and GAMEMODE.GetRound and GAMEMODE.Round) then return end
        local stage = GAMEMODE:GetRound()
        local R = GAMEMODE.Round
        if stage == R.MapSwitch then return end
        ply:Spawn()
        if stage == R.RoundStarting then
            ply:Freeze(true) -- как все на предстарте, разморозит RoundUnFreezePlayers
        end
    end)
end)

GeminiBots:Log("Совместимость с Murder включена: лодаут/чат/дуэли под режимом.")
