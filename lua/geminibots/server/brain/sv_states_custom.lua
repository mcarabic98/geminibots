--[[
    GeminiBots - Custom FSM States (from data/)
    Свои состояния без правки аддона: положи .lua в
    garrysmod/data/geminibots/states/, имя файла = имя состояния.
    Файл должен ВЕРНУТЬ таблицу { Update = function(bot, dt) ... }.
    Enter/Exit необязательны. Перезагрузка: geminibots_states_reload.
    Состояние с именем встроенного (idle/wander/...) его ПЕРЕКРОЕТ.

    Боту доступны: bot.ply, bot.target, bot.investigatePos,
    bot.desiredViewAngles, bot.forwardMove/sideMove, bot.buttons,
    GeminiBots.Navigator:MoveTo(bot, pos), GeminiBots.FSM:SetState(bot, name).
]]

GeminiBots = GeminiBots or {}

-- Файл может выполниться дважды (второе монтирование аддона, хот-релоад):
-- без защиты команды задвоятся
if GeminiBots.CustomStatesFileLoaded then return end
GeminiBots.CustomStatesFileLoaded = true

local STATES_DIR = "geminibots/states"
local TEMPLATE = [[-- Свое состояние FSM для GeminiBots: файл вернуть таблицей.
-- Имя состояния = имя файла (dance.lua -> "dance").
-- Включить бота: geminibots_bot_state <ник> dance
return {
    Enter = function(bot)
        bot.stateData.t = 0
    end,
    Update = function(bot, dt)
        if not IsValid(bot.ply) then return end
        -- Крутимся на месте 5 сек, потом гуляем дальше
        bot.stateData.t = (bot.stateData.t or 0) + dt
        local yaw = bot.ply:EyeAngles().y + 120 * dt
        bot.desiredViewAngles = Angle(0, yaw, 0)
        if bot.stateData.t > 5 then
            GeminiBots.FSM:SetState(bot, "wander")
        end
    end,
    Exit = function(bot)
    end,
}
]]

GeminiBots.FSM.CustomStates = GeminiBots.FSM.CustomStates or {}
GeminiBots.FSM.StateSource = GeminiBots.FSM.StateSource or {}

-- Загрузка/перезагрузка кастомных состояний из data
function GeminiBots.FSM:LoadCustomStates()
    if not file.IsDir(STATES_DIR, "DATA") then
        file.CreateDir(STATES_DIR)
    end

    local files, _ = file.Find(STATES_DIR .. "/*.lua", "DATA")
    if not files or #files == 0 then
        -- Пусто: кладем пример, чтобы было с чего начать
        file.Write(STATES_DIR .. "/_example.lua", TEMPLATE)
        GeminiBots:Log("Папка %s пуста, положен пример _example.lua.", STATES_DIR)
        return 0
    end

    -- Убираем прошлые кастомные, которых больше нет на диске
    local present = {}
    for _, f in ipairs(files) do
        present[string.lower(string.StripExtension(f))] = true
    end
    for name in pairs(self.CustomStates) do
        if not present[name] then
            self.States[name] = nil
            self.StateSource[name] = nil
            self.CustomStates[name] = nil
        end
    end

    local loaded = 0
    for _, f in ipairs(files) do
        -- Файлы с подчеркивания в начале (примеры) не грузим
        if string.StartWith(f, "_") then continue end
        local name = string.lower(string.StripExtension(f))
        local code = file.Read(STATES_DIR .. "/" .. f, "DATA") or ""
        if code == "" then continue end

        local fn = CompileString(code, "geminibots_state_" .. name, false)
        if type(fn) ~= "function" then
            GeminiBots:Warn("Состояние %s: ошибка компиляции (%s).", name, tostring(fn))
            continue
        end
        local ok, tbl = pcall(fn)
        if not ok or type(tbl) ~= "table" then
            GeminiBots:Warn("Состояние %s: файл должен вернуть таблицу.", name)
            continue
        end
        if type(tbl.Update) ~= "function" then
            GeminiBots:Warn("Состояние %s: нет функции Update.", name)
            continue
        end

        if self.States[name] and not self.CustomStates[name] then
            GeminiBots:Warn("Состояние %s перекрывает встроенное!", name)
        end
        self:RegisterState(name, tbl)
        self.CustomStates[name] = true
        self.StateSource[name] = "data:" .. f
        loaded = loaded + 1
    end

    GeminiBots:Log("Кастомных состояний загружено: %d.", loaded)
    return loaded
end

for _k, _v in pairs(GeminiBots.FSM.States or {}) do
    if GeminiBots.FSM.StateSource[_k] == nil then
        GeminiBots.FSM.StateSource[_k] = "builtin"
    end
end

-- Список состояний: имя, откуда, выключено ли
concommand.Add("geminibots_states_list", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    local dis = GeminiBots.Config and GeminiBots.Config.DisabledStates or {}
    local names = {}
    for name in pairs(GeminiBots.FSM.States or {}) do table.insert(names, name) end
    table.sort(names)
    local out = function(msg)
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end
    out("[GeminiBots] Состояния FSM:")
    for _, name in ipairs(names) do
        local src = GeminiBots.FSM.StateSource[name] or "builtin"
        local off = dis[name] and " [ВЫКЛ]" or ""
        out(string.format(" - %s (%s)%s", name, src, off))
    end
end, nil, "Показать все состояния FSM ботов")

concommand.Add("geminibots_states_reload", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    local n = GeminiBots.FSM:LoadCustomStates()
    local msg = string.format("[GeminiBots] Кастомных состояний перезагружено: %d.", n or 0)
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end, nil, "Перезагрузить кастомные состояния из data/geminibots/states/")

-- Принудительно перевести бота в состояние (тесты своих состояний)
concommand.Add("geminibots_bot_state", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    local nick, state = args[1], args[2]
    if not nick or not state then
        local msg = "[GeminiBots] Использование: geminibots_bot_state <ник> <состояние>"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    state = string.lower(state)
    if not GeminiBots.FSM.States[state] then
        local msg = string.format("[GeminiBots] Нет состояния: %s.", state)
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    local count = 0
    for _, botPly in ipairs(player.GetBots()) do
        if string.find(string.lower(botPly:Nick()), string.lower(nick), 1, true) then
            local bot = GeminiBots:GetBot(botPly)
            if bot then
                GeminiBots.FSM:SetState(bot, state)
                count = count + 1
            end
        end
    end
    local msg = string.format("[GeminiBots] В %s переведено ботов: %d.", state, count)
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end, nil, "Принудительно перевести бота в состояние FSM")

-- Грузим сразу при старте (после встроенных состояний из загрузчика)
timer.Simple(0.5, function()
    GeminiBots.FSM:LoadCustomStates()
end)

--------------------------------------------------------------------------------
-- Тумблеры состояний для меню (админка): список + вкл/выкл
--------------------------------------------------------------------------------
util.AddNetworkString("GeminiBots_RequestStates")
util.AddNetworkString("GeminiBots_ReceiveStates")
util.AddNetworkString("GeminiBots_ToggleState")

local function SendStates(ply)
    local dis = GeminiBots.Config and GeminiBots.Config.DisabledStates or {}
    local list = {}
    for name in pairs(GeminiBots.FSM.States or {}) do
        -- idle выключить нельзя: это дом, куда все возвращаются
        if name ~= "idle" then
            table.insert(list, {
                name = name,
                source = GeminiBots.FSM.StateSource[name] or "builtin",
                enabled = not dis[name],
            })
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    net.Start("GeminiBots_ReceiveStates")
    net.WriteTable(list)
    net.Send(ply)
end

net.Receive("GeminiBots_RequestStates", function(_, ply)
    if not IsValid(ply) or (not ply:IsAdmin() and not ply:IsSuperAdmin()
        and not game.SinglePlayer()) then return end
    SendStates(ply)
end)

net.Receive("GeminiBots_ToggleState", function(_, ply)
    if not IsValid(ply) or (not ply:IsAdmin() and not ply:IsSuperAdmin()
        and not game.SinglePlayer()) then return end
    local name = string.match(net.ReadString() or "", "^[a-z][a-z0-9_]*$")
    if not name or name == "idle" or not GeminiBots.FSM.States[name] then return end
    local enabled = net.ReadBool()

    local dis = {}
    local cv = GetConVar("geminibots_disabled_states")
    for n in string.gmatch(string.lower(cv and cv:GetString() or ""), "[a-z_]+") do
        dis[n] = true
    end
    if enabled then
        dis[name] = nil
    else
        dis[name] = true
    end
    local out = {}
    for n in pairs(dis) do table.insert(out, n) end
    table.sort(out)
    RunConsoleCommand("geminibots_disabled_states", table.concat(out, ","))
    -- Синк конфига подхватит колбэк, список сразу свежий
    timer.Simple(0.2, function()
        if IsValid(ply) then SendStates(ply) end
    end)
end)
