--[[
    GeminiBots - Skill Presets Manager (Server)
    Применение встроенных пресетов сложности и своих пользовательских
    (слепки текущих настроек, data/geminibots/skill_presets.json).
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Skill = GeminiBots.Skill or {}

util.AddNetworkString("GeminiBots_RequestSkillPresets")
util.AddNetworkString("GeminiBots_ReceiveSkillPresets")
util.AddNetworkString("GeminiBots_ApplySkillPreset")
util.AddNetworkString("GeminiBots_SaveSkillPreset")
util.AddNetworkString("GeminiBots_DeleteSkillPreset")

local CUSTOM_FILE = "geminibots/skill_presets.json"
local customCache = nil

local function LoadCustom()
    if customCache then return customCache end
    customCache = {}

    if not file.IsDir("geminibots", "DATA") then
        file.CreateDir("geminibots")
    end
    if not file.Exists(CUSTOM_FILE, "DATA") then return customCache end

    local data = util.JSONToTable(file.Read(CUSTOM_FILE, "DATA") or "")
    if istable(data) then customCache = data end
    return customCache
end

local function SaveCustomFile()
    file.Write(CUSTOM_FILE, util.TableToJSON(LoadCustom(), true))
end

local function NormalizeId(name)
    if not name then return nil end
    local id = string.lower(string.Trim(tostring(name)))
    id = string.gsub(id, "%s+", "_")
    if id == "" then return nil end
    return id
end

-- Список для клиента: { {id, custom} } (встроенные первыми по Order)
function GeminiBots.Skill:GetList()
    local out = {}
    for _, id in ipairs(GeminiBots.SkillPresets.Order or {}) do
        if GeminiBots.SkillPresets.BuiltIn[id] then
            table.insert(out, { id = id, custom = false })
        end
    end
    local names = {}
    for id, _ in pairs(LoadCustom()) do table.insert(names, id) end
    table.sort(names)
    for _, id in ipairs(names) do
        table.insert(out, { id = id, custom = true })
    end
    return out
end

local function SendListToClient(ply)
    net.Start("GeminiBots_ReceiveSkillPresets")
    net.WriteTable(GeminiBots.Skill:GetList())
    if IsValid(ply) then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

-- Применить пресет (встроенный или свой): проставить ConVar'ы
function GeminiBots.Skill:Apply(id)
    if not id then return false end
    id = NormalizeId(id)
    if not id then return false end

    local values = nil
    if GeminiBots.SkillPresets.BuiltIn[id] then
        values = GeminiBots.SkillPresets.BuiltIn[id].values
    else
        values = LoadCustom()[id]
    end
    if not istable(values) then return false end

    for _, key in ipairs(GeminiBots.SkillPresets.Keys or {}) do
        local val = values[key]
        if val ~= nil and GetConVar(key) then
            RunConsoleCommand(key, tostring(val))
        end
    end

    GeminiBots:Log("Применен пресет сложности: %s", id)
    return true
end

-- Сохранить текущие настройки как свой пресет
function GeminiBots.Skill:SaveCustom(name)
    local id = NormalizeId(name)
    if not id then return false, "пустое имя" end
    if GeminiBots.SkillPresets.BuiltIn[id] then
        return false, "имя занято встроенным пресетом"
    end

    local snapshot = {}
    for _, key in ipairs(GeminiBots.SkillPresets.Keys or {}) do
        local cv = GetConVar(key)
        if cv then snapshot[key] = cv:GetString() end
    end

    LoadCustom()[id] = snapshot
    SaveCustomFile()
    GeminiBots:Log("Сохранен свой пресет сложности: %s", id)
    return true
end

function GeminiBots.Skill:DeleteCustom(name)
    local id = NormalizeId(name)
    if not id then return false end
    if not LoadCustom()[id] then return false end
    LoadCustom()[id] = nil
    SaveCustomFile()
    GeminiBots:Log("Удален свой пресет сложности: %s", id)
    return true
end

local function IsAdmin(ply)
    return not IsValid(ply) or ply:IsSuperAdmin() or ply:IsAdmin() or game.SinglePlayer()
end

net.Receive("GeminiBots_RequestSkillPresets", function(_, ply)
    SendListToClient(ply)
end)

net.Receive("GeminiBots_ApplySkillPreset", function(_, ply)
    if not IsAdmin(ply) then return end
    if GeminiBots.Skill:Apply(net.ReadString()) then
        SendListToClient()
    end
end)

net.Receive("GeminiBots_SaveSkillPreset", function(_, ply)
    if not IsAdmin(ply) then return end
    local ok, err = GeminiBots.Skill:SaveCustom(net.ReadString())
    if ok then
        SendListToClient()
        if IsValid(ply) then ply:ChatPrint("[GeminiBots] Пресет сложности сохранен.") end
    else
        if IsValid(ply) then ply:ChatPrint("[GeminiBots] Не сохранено: " .. tostring(err)) end
    end
end)

net.Receive("GeminiBots_DeleteSkillPreset", function(_, ply)
    if not IsAdmin(ply) then return end
    if GeminiBots.Skill:DeleteCustom(net.ReadString()) then
        SendListToClient()
    end
end)

concommand.Add("geminibots_skill_list", function()
    print("=== [GeminiBots] Пресеты сложности ===")
    for _, entry in ipairs(GeminiBots.Skill:GetList()) do
        print(string.format(" - %-16s %s", entry.id, entry.custom and "(свой)" or "(встроенный)"))
    end
end, nil, "Показать все пресеты сложности")

concommand.Add("geminibots_skill_preset", function(ply, _, args)
    if not IsAdmin(ply) then return end
    if not args[1] then
        print("[GeminiBots] Использование: geminibots_skill_preset <имя>")
        return
    end
    if GeminiBots.Skill:Apply(args[1]) then
        print("[GeminiBots] Применен пресет: " .. args[1])
    else
        print("[GeminiBots] Пресет не найден: " .. args[1])
    end
end, nil, "Применить пресет сложности (easy/normal/hard/expert или свой)")

concommand.Add("geminibots_skill_save", function(ply, _, args)
    if not IsAdmin(ply) then return end
    if not args[1] then
        print("[GeminiBots] Использование: geminibots_skill_save <имя>")
        return
    end
    local ok, err = GeminiBots.Skill:SaveCustom(args[1])
    print(ok and ("[GeminiBots] Пресет сохранен: " .. args[1]) or ("[GeminiBots] Ошибка: " .. tostring(err)))
end, nil, "Сохранить текущие настройки как свой пресет сложности")

concommand.Add("geminibots_skill_delete", function(ply, _, args)
    if not IsAdmin(ply) then return end
    if not args[1] then
        print("[GeminiBots] Использование: geminibots_skill_delete <имя>")
        return
    end
    print(GeminiBots.Skill:DeleteCustom(args[1]) and "[GeminiBots] Пресет удален." or "[GeminiBots] Пресет не найден.")
end, nil, "Удалить свой пресет сложности")

LoadCustom()
