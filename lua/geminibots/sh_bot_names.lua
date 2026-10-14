--[[
    GeminiBots - Shared Bot Names & Player Metatable Overrides
    Подменяет методы получения ника (Nick, GetName, Name, GetPrintName)
    для отображения уникальных кастомных имен ботов во всех интерфейсах игры
    (scoreboard, killfeed, чат, HUD, голосовые уведомления и т.д.).
]]--

GeminiBots = GeminiBots or {}

local meta = FindMetaTable("Player")
if meta then
    local oldNick = meta.Nick
    local oldGetName = meta.GetName
    local oldName = meta.Name
    local oldGetPrintName = meta.GetPrintName

    local cvarCustomNames = nil

    local function ShouldUseCustomNick(ply)
        if not IsValid(ply) or not ply:IsBot() then return false end

        if not cvarCustomNames then
            cvarCustomNames = GetConVar("geminibots_custom_names")
        end

        if cvarCustomNames and not cvarCustomNames:GetBool() then
            return false
        end

        return true
    end

    function meta:Nick()
        if ShouldUseCustomNick(self) then
            local custom = self:GetNWString("GeminiBots_CustomNick", "")
            if custom ~= "" then
                return custom
            end
        end
        return oldNick(self)
    end

    meta.GetName = meta.Nick
    meta.Name = meta.Nick

    if oldGetPrintName then
        function meta:GetPrintName()
            if ShouldUseCustomNick(self) then
                local custom = self:GetNWString("GeminiBots_CustomNick", "")
                if custom ~= "" then
                    return custom
                end
            end
            return oldGetPrintName(self)
        end
    end
end
