--[[
    GeminiBots - Bot Appearance System (Server)
    Случайная внешность ботов при спавне штатными методами движка:
    SetModel / SetSkin / SetBodygroup / SetPlayerColor. Без библиотек.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Appearance = GeminiBots.Appearance or {}

-- Кеш списка всех валидных моделей игроков
local modelCache = nil

local function GetAllModels()
    if modelCache and #modelCache > 0 then return modelCache end

    modelCache = {}
    for _, path in pairs(player_manager.AllValidModels() or {}) do
        if isstring(path) and path ~= "" then
            table.insert(modelCache, path)
        end
    end

    if #modelCache == 0 then
        modelCache = { "models/player/kleiner.mdl" }
    end

    return modelCache
end

-- Применить случайную внешность боту (force = обойти опцию "один раз")
function GeminiBots.Appearance:Apply(ply, force)
    if not IsValid(ply) or not ply:IsBot() then return end

    local cfg = GeminiBots.Config and GeminiBots.Config.Appearance
    if not cfg or not cfg.Enabled then return end

    -- Режим "один раз": внешность уже задана — не трогаем
    if not force and not cfg.ChangeOnRespawn and ply.GeminiBots_HasAppearance then
        return
    end

    -- Модель ставим первой: скин и бодигруппы зависят от нее
    if cfg.RandomModel then
        local models = GetAllModels()
        local ok = pcall(function()
            ply:SetModel(models[math.random(#models)])
        end)
        if not ok then return end
    end

    if cfg.RandomSkin then
        pcall(function()
            local maxSkin = math.max(0, (ply:SkinCount() or 1) - 1)
            ply:SetSkin(math.random(0, maxSkin))
        end)
    end

    if cfg.RandomBodygroups then
        pcall(function()
            for _, bg in ipairs(ply:GetBodyGroups() or {}) do
                if bg.num and bg.num > 1 then
                    ply:SetBodygroup(bg.id, math.random(0, bg.num - 1))
                end
            end
        end)
    end

    if cfg.RandomColor then
        pcall(function()
            ply:SetPlayerColor(Vector(math.Rand(0, 1), math.Rand(0, 1), math.Rand(0, 1)))
        end)
    end

    GeminiBots:Debug("Боту %s задана случайная внешность: %s", ply:Nick(), ply:GetModel())
    ply.GeminiBots_HasAppearance = true
end

-- При спавне ждем 0.5 сек, чтобы переустановить модель ПОСЛЕ гамемода
hook.Add("PlayerSpawn", "GeminiBots_Appearance_OnSpawn", function(ply)
    if ply:IsBot() then
        timer.Simple(0.5, function()
            if IsValid(ply) and ply:Alive() then
                GeminiBots.Appearance:Apply(ply)
            end
        end)
    end
end)

concommand.Add("geminibots_appearance_reroll", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then return end
    local n = 0
    for _, botPly in ipairs(player.GetBots()) do
        if IsValid(botPly) and botPly:Alive() then
            GeminiBots.Appearance:Apply(botPly, true)
            n = n + 1
        end
    end
    local msg = string.format("[GeminiBots] Внешность обновлена у ботов: %d", n)
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end, nil, "Случайно сменить модели/скины всем живым ботам")
