--[[
    GeminiBots - Bot Manager
    Регистрация, жизненный цикл и хранилище данных ИИ каждого бота.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Bots = GeminiBots.Bots or {}

-- Создание контекста данных для нового бота
function GeminiBots:RegisterBot(ply)
    if not IsValid(ply) or not ply:IsBot() then return nil end

    -- Если уже зарегистрирован, возвращаем существующие данные
    if self.Bots[ply] then
        return self.Bots[ply]
    end

    local bot = {
        ply = ply,
        state = "idle",
        stateData = {},
        target = nil,
        lastKnownTargetPos = nil,
        targetLostTime = 0,
        reactionTimer = 0,

        -- Управление взглядом
        currentViewAngles = ply:EyeAngles(),
        desiredViewAngles = ply:EyeAngles(),

        -- Навигация
        path = nil,
        pathIndex = 1,
        pathTargetPos = nil,
        reachOverride = nil,
        moveAbort = nil,
        nextRepathTime = 0,
        lastStuckPos = ply:GetPos(),
        stuckTimer = CurTime(),

        -- Команды движения для StartCommand
        buttons = 0,
        forwardMove = 0,
        sideMove = 0,
        upMove = 0,

        -- Боевые тайминги
        nextBurstTime = 0,
        strafeDirection = 1,
        nextStrafeSwitch = 0
    }

    self.Bots[ply] = bot

    if self.AssignBotName and (ply:GetNWString("GeminiBots_CustomNick", "") == "") then
        self:AssignBotName(ply)
    end

    self:Log("Бот зарегистрирован в системе ИИ: %s", ply:Nick())

    timer.Simple(0, function()
        if IsValid(ply) and self.Bots[ply] and self.FSM and self.FSM.SetState then
            self.FSM:SetState(self.Bots[ply], "idle")
        end
    end)

    return bot
end

-- Удаление бота из системы
function GeminiBots:UnregisterBot(ply)
    if self.Bots[ply] then
        self.Bots[ply] = nil
        self:Debug("Бот удален из системы ИИ: %s", IsValid(ply) and ply:Nick() or "Unknown")
    end
end

-- Получить контекст данных бота
function GeminiBots:GetBot(ply)
    if not IsValid(ply) then return nil end
    return self.Bots[ply]
end

-- Получить всех активных ботов
function GeminiBots:GetAllBots()
    return self.Bots
end

-- Все игроки одним списком: player.GetAll каждый скан каждого бота —
-- дорого, раз в полсекунды хватает (заход/выход с задержкой незаметны)
GeminiBots.PlayersCache = GeminiBots.PlayersCache or {}
GeminiBots.PlayersCacheAt = GeminiBots.PlayersCacheAt or -99

function GeminiBots:AllPlayersCached()
    local now = CurTime()
    if (self.PlayersCacheAt or -99) + 0.5 < now or not self.PlayersCache then
        self.PlayersCache = player.GetAll()
        self.PlayersCacheAt = now
    end
    return self.PlayersCache
end

-- Сброс состояния бота (при возрождении)
function GeminiBots:ResetBot(ply)
    local bot = self:GetBot(ply)
    if not bot then
        bot = self:RegisterBot(ply)
    end

    if bot then
        bot.state = "idle"
        bot.stateData = {}
        bot.target = nil
        bot.lastKnownTargetPos = nil
        bot.investigateKind = nil
        bot.investigatePos = nil
        bot.investigateTime = 0
        bot.heardDist = nil
        bot.plantArmed = nil
        bot.aloneSince = nil
        bot.defuseBomb = nil
        bot.fleeBomb = nil
        bot.fleeNoTime = nil
        bot.path = nil
        bot.pathIndex = 1
        bot.pathTargetPos = nil
        bot.reachOverride = nil
        bot.moveAbort = nil
        bot.avoidPos = nil
        bot.avoidUntil = 0
        bot.avoidRadius = nil
        bot.detourTries = 0
        bot.duckUntil = 0
        bot.breakEnt = nil
        bot.breakUntil = 0
        bot.sideStepUntil = 0
        bot.stuckCount = 0
        bot.bhopRolled = false
        bot.bhopSkip = false
        bot.crouchUntil = 0
        bot.keepLookUntil = 0
        bot.peekWindow = CurTime()
        bot.nextScanTime = 0
        bot.fleeLockUntil = 0
        bot.aimNaNWarn = 0
        bot.reactionTimer = 0
        bot.nextBurstTime = 0
        bot.nextWeaponEvalTime = 0
        bot.nextCombatRepath = 0
        bot.nextUrgentEval = 0
        bot.nextLobCalc = 0
        bot.lobAngles = nil
        bot.lobLanding = nil
        bot.lobPoints = nil
        bot.lastAimAngles = nil
        bot.aimTarget = nil
        bot.lastOnTargetTime = 0
        bot.wallbangUntil = 0
        bot.wallbangAim = nil
        bot.nextWallbangTime = 0
        bot.nextWallbangCheck = 0
        bot.tauntTarget = nil
        bot.buttons = 0
        bot.forwardMove = 0
        bot.sideMove = 0
        bot.upMove = 0
        bot.lastStuckPos = ply:GetPos()
        bot.stuckTimer = CurTime()
        bot.currentViewAngles = ply:EyeAngles()
        bot.desiredViewAngles = ply:EyeAngles()

        if self.FSM and self.FSM.SetState then
            self.FSM:SetState(bot, "wander")
        end
    end
end

--------------------------------------------------------------------------------
-- Хуки жизненного цикла
--------------------------------------------------------------------------------
hook.Add("PlayerInitialSpawn", "GeminiBots_Manager_InitialSpawn", function(ply)
    if ply:IsBot() then
        GeminiBots:RegisterBot(ply)
    end
end)

-- Автовыбор команды ботам: без нее в командных режимах боты висят
-- в спектаторах/unassigned и "не появляются".
hook.Add("PlayerInitialSpawn", "GeminiBots_AutoTeam", function(ply)
    if not IsValid(ply) or not ply:IsBot() then return end
    timer.Simple(1.0, function()
        if not IsValid(ply) then return end
        -- Murder: только команда игроков (спектаторы — team 1)
        if GeminiBots.MurderActive and GeminiBots.MurderActive() then
            if ply:Team() ~= 2 then ply:SetTeam(2) end
            return
        end
        -- HL2MP: свой пуш из спектаторов (команда + спавн), не мешаем
        if GeminiBots.HL2MPActive and GeminiBots.HL2MPActive() then return end
        -- Песочница и производные: команд нет, не трогаем
        if GAMEMODE and GAMEMODE.IsSandboxDerived then return end
        -- Командные режимы: в меньшую не-спектаторскую команду
        local curName = string.lower(tostring(team.GetName(ply:Team()) or ""))
        local needTeam = ply:Team() == 0
            or string.find(curName, "spect", 1, true)
            or string.find(curName, "unassign", 1, true)
        if not needTeam then return end
        local best, bestCount = nil, nil
        for _, tid in ipairs(team.GetAllTeams() or {}) do
            if tid == 0 then continue end
            local nm = string.lower(tostring(team.GetName(tid) or ""))
            if nm == "" then continue end
            if string.find(nm, "spect", 1, true) then continue end
            if string.find(nm, "unassign", 1, true) then continue end
            if string.find(nm, "connect", 1, true) then continue end
            local c = #team.GetPlayers(tid)
            if best == nil or c < bestCount then
                best, bestCount = tid, c
            end
        end
        if best ~= nil and best ~= ply:Team() then
            ply:SetTeam(best)
            GeminiBots:Log("Бот %s отправлен в команду %s (автовыбор).", ply:Nick(), team.GetName(best))
        end
    end)
end)

hook.Add("PlayerSpawn", "GeminiBots_Manager_Spawn", function(ply)
    if ply:IsBot() then
        timer.Simple(0.1, function()
            if IsValid(ply) then
                GeminiBots:ResetBot(ply)
            end
        end)
    end
end)

hook.Add("PlayerDisconnected", "GeminiBots_Manager_Disconnected", function(ply)
    if ply:IsBot() then
        GeminiBots:UnregisterBot(ply)
    end
end)

-- Спавн одного бота: с кастомным ником сразу в движке, чтобы имя
-- видели все (табы, киллфид, читы) — а не только наш код по NWString.
-- Не вышло с именем — обычный bot
local function SpawnOneBot(nick)
    if #player.GetAll() >= game.MaxPlayers() then return end
    if nick and nick ~= "" then
        local ok, bot = pcall(player.CreateNextBot, nick)
        if ok and IsValid(bot) then return end
    end
    RunConsoleCommand("bot")
end

local function NextCustomNick()
    local cv = GetConVar("geminibots_custom_names")
    if cv and not cv:GetBool() then return nil end
    if GeminiBots.PickFreeNick then
        return GeminiBots:PickFreeNick()
    end
    return nil
end

-- Публично для ULX-моста (!addbot): спавн и подбор ника
GeminiBots.SpawnBotWithNick = SpawnOneBot
GeminiBots.NextCustomNick = NextCustomNick

-- Консольные команды для управления ботами
concommand.Add("geminibots_add", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then
        print("[GeminiBots] geminibots_add: отказано (нужен админ).")
        return
    end
    print("[GeminiBots] geminibots_add: спавн одного бота...")
    SpawnOneBot(NextCustomNick())
end, nil, "Заспавнить одного бота с ИИ GeminiBots")

-- Функция спавна максимального количества ботов
local function SpawnMaxBots(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then
        print("[GeminiBots] geminibots_spawn_max: отказано (нужен админ).")
        return
    end

    local maxPlayers = game.MaxPlayers()
    local currentCount = #player.GetAll()
    local availableSlots = maxPlayers - currentCount

    if availableSlots <= 0 then
        local msg = string.format("[GeminiBots] Сервер полон! Занято слотов: %d/%d", currentCount, maxPlayers)
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end

    print(string.format("[GeminiBots] geminibots_spawn_max: спавн %d ботов...", availableSlots))

    GeminiBots:Log("Спавн максимального количества ботов: %d слотов (Лимит сервера: %d)", availableSlots, maxPlayers)

    -- Спавним с задержкой, иначе движок теряет часть ботов
    for i = 1, availableSlots do
        timer.Simple(0.05 * (i - 1), function()
            SpawnOneBot(NextCustomNick())
        end)
    end
end

concommand.Add("geminibots_spawn_max", SpawnMaxBots, nil, "Заполнить сервер ботами до максимального лимита игроков")
concommand.Add("geminibots_fill", SpawnMaxBots, nil, "Заполнить сервер ботами до максимального лимита игроков")

-- Удалить всех ботов с сервера
local function KickAllBots(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end

    local count = 0
    for _, botPly in ipairs(player.GetBots()) do
        botPly:Kick("Удален GeminiBots")
        count = count + 1
    end
    GeminiBots:Log("Удалено ботов с сервера: %d", count)
end

concommand.Add("geminibots_kick_all", KickAllBots, nil, "Удалить (кикнуть) всех ботов с сервера")

concommand.Add("geminibots_reload", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    GeminiBots.Bots = {}
    for _, botPly in ipairs(player.GetBots()) do
        GeminiBots:RegisterBot(botPly)
        GeminiBots:ResetBot(botPly)
    end
    GeminiBots:Log("Все боты на сервере перезапущены.")
end, nil, "Перезагрузить состояние всех ботов")

-- Автоматическая регистрация существующих ботов при горячей перезагрузке скрипта
timer.Simple(0.1, function()
    for _, botPly in ipairs(player.GetBots()) do
        GeminiBots:RegisterBot(botPly)
    end
end)

--------------------------------------------------------------------------------
-- Сохранение и перенос ботов при смене карты / перезагрузке
--------------------------------------------------------------------------------
local SESSION_FILE = "geminibots/saved_session.json"

function GeminiBots:SaveBotsState()
    local cv = GetConVar("geminibots_preserve_bots")
    if cv and not cv:GetBool() then return end

    local bots = player.GetBots()
    if #bots == 0 then
        if file.Exists(SESSION_FILE, "DATA") then
            file.Delete(SESSION_FILE)
        end
        return
    end

    local botList = {}
    for _, botPly in ipairs(bots) do
        table.insert(botList, {
            nick = botPly:GetNWString("GeminiBots_CustomNick", "")
        })
    end

    local saveData = {
        timestamp = os.time(),
        count = #botList,
        bots = botList
    }

    if not file.IsDir("geminibots", "DATA") then
        file.CreateDir("geminibots")
    end

    file.Write(SESSION_FILE, util.TableToJSON(saveData, true))
    GeminiBots:Log("Сохранено %d ботов перед смене карты/перезагрузке сервера.", #botList)
end

function GeminiBots:RestoreSavedBots()
    local cv = GetConVar("geminibots_preserve_bots")
    if cv and not cv:GetBool() then return end

    if not file.Exists(SESSION_FILE, "DATA") then return end

    local raw = file.Read(SESSION_FILE, "DATA")
    file.Delete(SESSION_FILE) -- Удаляем сразу, чтобы избежать повторного спавна при обычном рестарте

    if not raw or raw == "" then return end

    local data = util.JSONToTable(raw)
    if not data or not data.bots or #data.bots == 0 then return end

    -- Снапшот старше 10 минут: это был рестарт сервера, а не смена карты
    if data.timestamp and (os.time() - data.timestamp > 600) then
        GeminiBots:Log("Сохраненное состояние ботов устарело (> 10 мин), автовосстановление отменено.")
        return
    end

    -- Заполняем очередь кастомных имен для восстановления
    GeminiBots.RestoringBotNames = {}
    for _, b in ipairs(data.bots) do
        if b.nick and b.nick ~= "" then
            table.insert(GeminiBots.RestoringBotNames, b.nick)
        end
    end

    local maxPlayers = game.MaxPlayers()
    local currentCount = #player.GetAll()
    local availableSlots = maxPlayers - currentCount
    local toSpawn = math.min(#data.bots, availableSlots)

    if toSpawn <= 0 then
        GeminiBots:Warn("Невозможно восстановить ботов: сервер полон (%d/%d слотов занято).", currentCount, maxPlayers)
        return
    end

    GeminiBots:Log("Восстановление ботов после смены карты: %d ботов (сохранено было: %d)...", toSpawn, #data.bots)

    for i = 1, toSpawn do
        timer.Simple(0.05 * (i - 1), function()
            -- Сохраненный ник отдаем сразу в движок (см. SpawnOneBot),
            -- в AssignBotName он подхватится сам; очередь — запасной путь
            local nick = nil
            local cv = GetConVar("geminibots_custom_names")
            if (not cv or cv:GetBool())
                and GeminiBots.RestoringBotNames and #GeminiBots.RestoringBotNames > 0 then
                nick = table.remove(GeminiBots.RestoringBotNames, 1)
            end
            SpawnOneBot(nick)
        end)
    end
end

-- Подъем мертвых: в песочнице трупы никто не поднимает (режимы со своим
-- респауном не трогаем: Murder — раундами, HL2DM — мгновенно сам)
timer.Create("GeminiBots_AutoRespawn", 3, 0, function()
    if not (GAMEMODE and GAMEMODE.IsSandboxDerived) then return end
    if GeminiBots.MurderActive and GeminiBots.MurderActive() then return end
    if GeminiBots.HL2MPActive and GeminiBots.HL2MPActive() then return end
    local cfg = GeminiBots.Config
    if not cfg or not cfg.Enabled then return end
    for _, botPly in ipairs(player.GetBots()) do
        if IsValid(botPly) and not botPly:Alive() then
            botPly:Spawn()
        end
    end
end)

-- Сохраняем ботов при смене карты
hook.Add("ShutDown", "GeminiBots_SaveBotsOnShutDown", function()
    GeminiBots:SaveBotsState()
end)

-- Хук восстановления ботов после полной загрузки новой карты
hook.Add("InitPostEntity", "GeminiBots_RestoreBotsOnInitPostEntity", function()
    -- Небольшая задержка 2 сек, чтобы карта, navmesh и реальные игроки успели прогрузиться
    timer.Simple(2.0, function()
        GeminiBots:RestoreSavedBots()
    end)
end)

-- Консольные команды ручного сохранения и восстановления
concommand.Add("geminibots_save_bots", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    GeminiBots:SaveBotsState()
    local msg = "[GeminiBots] Состояние текущих ботов сохранено."
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end, nil, "Вручную сохранить текущих ботов для переноса на следующую карту")

concommand.Add("geminibots_restore_bots", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    GeminiBots:RestoreSavedBots()
end, nil, "Вручную восстановить ранее сохраненных ботов")

