--[[
    GeminiBots - ESP Renderer (Client)
    Рисует боксы ботов + инфо рядом (состояние, цель, HP, оружие, дистанция)
    и опциональные скелеты. Данные приходят только включившим админам,
    10 раз в секунду. Без developer не зависит ни от чего.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.ESPEnabled = GeminiBots.ESPEnabled or false
GeminiBots.ESPSkeleton = GeminiBots.ESPSkeleton or false
GeminiBots.ESPCache = nil

-- Какие элементы ESP рисовать (клиентские, серверу все равно)
CreateClientConVar("geminibots_esp_boxes", "1", true, false, "ESP: боксы вокруг ботов")
CreateClientConVar("geminibots_esp_hp", "1", true, false, "ESP: полоса HP")
CreateClientConVar("geminibots_esp_info", "1", true, false, "ESP: строки инфо (ник, HP, цель, оружие)")
CreateClientConVar("geminibots_esp_status", "1", true, false, "ESP: статусы (оглушение, огонь, бомба, звук)")

GeminiBots.ConVarDescs = GeminiBots.ConVarDescs or {}
GeminiBots.ConVarDescs["geminibots_esp_boxes"] = "ESP: боксы вокруг ботов (вкл/выкл)"
GeminiBots.ConVarDescs["geminibots_esp_hp"] = "ESP: полоса HP слева от бокса (вкл/выкл)"
GeminiBots.ConVarDescs["geminibots_esp_info"] = "ESP: ник, состояние, HP, цель, оружие (вкл/выкл)"
GeminiBots.ConVarDescs["geminibots_esp_status"] = "ESP: оглушение, огонь, бомба, звук и путь (вкл/выкл)"
GeminiBots.ConVarDescsEN = GeminiBots.ConVarDescsEN or {}
GeminiBots.ConVarDescsEN["geminibots_esp_boxes"] = "ESP: boxes around bots (on/off)"
GeminiBots.ConVarDescsEN["geminibots_esp_hp"] = "ESP: HP bar left of the box (on/off)"
GeminiBots.ConVarDescsEN["geminibots_esp_info"] = "ESP: nick, state, HP, target, weapon (on/off)"
GeminiBots.ConVarDescsEN["geminibots_esp_status"] = "ESP: blind, fire, bomb, sound and path (on/off)"

function GeminiBots.SetESP(on)
    GeminiBots.ESPEnabled = (on == true)
    net.Start("GeminiBots_ESPToggle")
    net.WriteBool(GeminiBots.ESPEnabled)
    net.SendToServer()
    if not GeminiBots.ESPEnabled then
        GeminiBots.ESPCache = nil
    end
end

concommand.Add("geminibots_esp", function()
    GeminiBots.SetESP(not GeminiBots.ESPEnabled)
    chat.AddText(Color(100, 200, 255), "[GeminiBots] ESP: ",
        Color(255, 255, 255), GeminiBots.ESPEnabled and "ВКЛ" or "ВЫКЛ")
end, nil, "Вкл/выкл ESP ботов (только админам)")

net.Receive("GeminiBots_ESPData", function()
    local n = net.ReadUInt(8)
    if n == 0 then
        GeminiBots.ESPCache = nil
        return
    end

    -- Сливаем с кешем: render-позиции живут дальше (сглаживание),
    -- снап — только при первом появлении или телепорте
    local oldByEnt = {}
    if GeminiBots.ESPCache then
        for _, old in ipairs(GeminiBots.ESPCache.bots) do
            if IsValid(old.ent) then oldByEnt[old.ent] = old end
        end
    end

    local list = {}
    for i = 1, n do
        local ent = net.ReadEntity()
        local pos = net.ReadVector()
        local eye = net.ReadVector()
        local entry = {
            ent = ent,
            tpos = pos,
            teye = eye,
            rpos = Vector(pos.x, pos.y, pos.z),
            reye = Vector(eye.x, eye.y, eye.z),
            hp = net.ReadUInt(16),
            maxhp = net.ReadUInt(16),
            state = net.ReadUInt(3),
            target = net.ReadString(),
            weapon = net.ReadString(),
            flags = net.ReadUInt(4),
            snd = net.ReadUInt(3),
            blind = net.ReadUInt(8),
            bomb = net.ReadUInt(3)
        }
        entry.team = math.floor((entry.flags or 0) / 4)
        if net.ReadBool() then
            local iv = net.ReadVector()
            entry.inv = iv
            -- Точку звука опускаем на пол одним трассом: путь рисуем по земле
            local gtr = util.TraceLine({
                start = iv + Vector(0, 0, 32),
                endpos = iv - Vector(0, 0, 256),
                mask = MASK_SOLID_BRUSHONLY
            })
            entry.invG = gtr.Hit and (gtr.HitPos + Vector(0, 0, 4)) or iv
        end
        entry.cheat = net.ReadUInt(3)
        local old = IsValid(ent) and oldByEnt[ent] or nil
        if old and old.rpos and old.rpos:Distance(pos) < 400 then
            entry.rpos = old.rpos
            entry.reye = old.reye or entry.reye
        end
        list[i] = entry
    end
    GeminiBots.ESPCache = { bots = list, expire = CurTime() + 0.3 }
end)

-- Порядок ДОЛЖЕН совпадать с STATE_IDS на сервере (+1: Lua-индекс с 1)
local STATE_NAMES = { "idle", "wander", "combat", "flee", "investigate", "plant", "defuse", "?" }
local STATE_COLORS = {
    Color(80, 200, 120), -- idle: зеленый
    Color(80, 200, 120), -- wander: зеленый
    Color(255, 80, 80), -- combat: красный
    Color(255, 200, 80), -- flee: желтый
    Color(100, 200, 255), -- investigate: голубой
    Color(255, 150, 50), -- plant: оранжевый
    Color(80, 220, 255), -- defuse: циан
    Color(180, 180, 180) -- ?: серый
}

-- Пары костей для скелета (имена ValveBiped есть у всех playermodel)
local BONE_PAIRS = {
    { "ValveBiped.Bip01_Head1", "ValveBiped.Bip01_Neck1" },
    { "ValveBiped.Bip01_Neck1", "ValveBiped.Bip01_Spine2" },
    { "ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Spine" },
    { "ValveBiped.Bip01_Spine", "ValveBiped.Bip01_Pelvis" },
    { "ValveBiped.Bip01_Pelvis", "ValveBiped.Bip01_L_Thigh" },
    { "ValveBiped.Bip01_Pelvis", "ValveBiped.Bip01_R_Thigh" },
    { "ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf" },
    { "ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf" },
    { "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_L_Foot" },
    { "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_R_Foot" },
    { "ValveBiped.Bip01_L_Clavicle", "ValveBiped.Bip01_L_UpperArm" },
    { "ValveBiped.Bip01_R_Clavicle", "ValveBiped.Bip01_R_UpperArm" },
    { "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm" },
    { "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm" },
    { "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand" },
    { "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand" }
}

-- Кеш индексов костей: модель -> { {i1, i2} }. LookupBone один раз на модель.
local boneCache = {}

local function GetSkeletonPairs(ent)
    local model = ent:GetModel()
    if boneCache[model] == nil then
        local pairs = {}
        for _, b in ipairs(BONE_PAIRS) do
            local a = ent:LookupBone(b[1])
            local c = ent:LookupBone(b[2])
            if a and c then table.insert(pairs, { a, c }) end
        end
        boneCache[model] = pairs
    end
    return boneCache[model]
end

local function DrawSkeleton(ent)
    if not IsValid(ent) or not ent:Alive() then return end
    surface.SetDrawColor(255, 255, 255, 220)
    for _, pair in ipairs(GetSkeletonPairs(ent)) do
        local p1 = ent:GetBonePosition(pair[1])
        local p2 = ent:GetBonePosition(pair[2])
        if p1 and p2 then
            local s1, s2 = p1:ToScreen(), p2:ToScreen()
            if s1.visible and s2.visible then
                surface.DrawLine(s1.x, s1.y, s2.x, s2.y)
            end
        end
    end
end

hook.Add("HUDPaint", "GeminiBots_DrawESP", function()
    local cache = GeminiBots.ESPCache
    if not cache or CurTime() > cache.expire then return end

    local lpPos = IsValid(LocalPlayer()) and LocalPlayer():GetPos() or Vector(0, 0, 0)

    -- Какие элементы рисуем (тумблеры из админки)
    local function EOn(name)
        local cv = GetConVar(name)
        if not cv then return true end
        return cv:GetBool()
    end
    local showBoxes, showHP = EOn("geminibots_esp_boxes"), EOn("geminibots_esp_hp")
    local showInfo, showStatus = EOn("geminibots_esp_info"), EOn("geminibots_esp_status")

    -- Бокс плавно дотягивается до серверной позиции вместо рывков
    local k = 1 - math.exp(-18 * FrameTime())

    for _, b in ipairs(cache.bots) do
        -- Дотягиваем render-позицию к свежей серверной
        b.rpos.x = Lerp(k, b.rpos.x, b.tpos.x)
        b.rpos.y = Lerp(k, b.rpos.y, b.tpos.y)
        b.rpos.z = Lerp(k, b.rpos.z, b.tpos.z)
        b.reye.x = Lerp(k, b.reye.x, b.teye.x)
        b.reye.y = Lerp(k, b.reye.y, b.teye.y)
        b.reye.z = Lerp(k, b.reye.z, b.teye.z)

        local feet = b.rpos:ToScreen()
        local head = b.reye:ToScreen()
        if (not feet.visible) and (not head.visible) then continue end

        local height = math.abs(feet.y - head.y)
        if height < 4 then continue end

        local col = STATE_COLORS[b.state + 1] or STATE_COLORS[8]
        local w = height * 0.45
        local x, y = feet.x - w / 2, head.y

        -- Бокс
        if showBoxes then
            surface.SetDrawColor(col.r, col.g, col.b, 255)
            surface.DrawOutlinedRect(x, y, w, height)
        end

        -- Полоса HP слева
        if showHP then
            local frac = math.Clamp(b.hp / math.max(1, b.maxhp), 0, 1)
            surface.SetDrawColor(0, 0, 0, 200)
            surface.DrawRect(x - 7, y, 5, height)
            surface.SetDrawColor(255 * (1 - frac), 255 * frac, 60, 255)
            surface.DrawRect(x - 7, y + height * (1 - frac), 5, height * frac)
        end

        -- Инфо справа от бокса
        local nick = (IsValid(b.ent) and b.ent:Nick()) or "?"
        local dist = math.floor(lpPos:Distance(b.rpos))
        local tx = x + w + 5
        local ty = y
        local function text(s)
            draw.SimpleTextOutlined(s, "DermaDefault", tx, ty, col, 0, 0, 1, Color(0, 0, 0, 255))
            ty = ty + 13
        end
        if showInfo then
            text(nick .. " [" .. (STATE_NAMES[b.state + 1] or "?") .. "]")
            text(string.format("HP %d/%d | %d", b.hp, b.maxhp, dist))
            text("> " .. b.target)
            text(b.weapon)
            -- Команда детматча (только HL2MP присылает ненулевую)
            if (b.team or 0) == 1 then
                draw.SimpleTextOutlined("REBEL", "DermaDefault", tx, ty,
                    Color(255, 130, 60), 0, 0, 1, Color(0, 0, 0, 255))
                ty = ty + 13
            elseif (b.team or 0) == 2 then
                draw.SimpleTextOutlined("COMBINE", "DermaDefault", tx, ty,
                    Color(130, 140, 255), 0, 0, 1, Color(0, 0, 0, 255))
                ty = ty + 13
            end
        end

        -- Статусы: оглушение, огонь, какой звук проверяет
        if showStatus then
        local langRU = GeminiBots.GetMenuLang and GeminiBots.GetMenuLang() == "ru"
        local function textc(s, c)
            draw.SimpleTextOutlined(s, "DermaDefault", tx, ty, c, 0, 0, 1, Color(0, 0, 0, 255))
            ty = ty + 13
        end
        local flags = b.flags or 0
        if bit.band(flags, 1) ~= 0 then
            textc(string.format(langRU and "ОГЛУШЕН %.1fс" or "BLINDED %.1fs",
                (b.blind or 0) / 10), Color(255, 220, 80))
        end
        if bit.band(flags, 2) ~= 0 then
            textc(langRU and "ОГОНЬ — ОТХОД" or "FIRE — BACK", Color(255, 140, 40))
        end
        if b.state == 4 then
            local kinds = langRU
                and { "ищет", "выстрел", "шаги", "декой", "бомба" }
                or { "searching", "gunfire", "steps", "decoy", "bomb" }
            -- Бомбу показывает отдельная строка, тут не дублируем
            if (b.snd or 0) ~= 4 then
                textc("→ " .. (kinds[(b.snd or 0) + 1] or kinds[1]), Color(100, 200, 255))
            end
        end
        -- Статус бомбы: ставлю, убегаю, ищу, дефужу, не хватит времени
        if (b.bomb or 0) > 0 then
            local words = langRU
                and { "ставлю", "убегаю", "ищу", "дефужу", "не хватит времени" }
                or { "planting", "fleeing", "seeking", "defusing", "no time" }
            textc("БОМБА: " .. (words[b.bomb] or "?"), Color(255, 150, 50))
        end
        -- Читер: тир из команды спавна
        if (b.cheat or 0) > 0 then
            local tiers = langRU
                and { "легит", "аим", "читак", "хвх" }
                or { "legit", "aim", "cheater", "hvh" }
            textc("ЧИТЕР: " .. (tiers[b.cheat] or "?"), Color(255, 120, 120))
        end

        -- Путь до звука стелим по полу: сегменты между ног бота
        -- и землей под звуком. Источник помечаем кругом.
        if b.state == 4 and b.invG then
            surface.SetDrawColor(100, 200, 255, 200)
            local prev = nil
            for i = 0, 10 do
                local t = i / 10
                local p = Vector(
                    Lerp(t, b.rpos.x, b.invG.x),
                    Lerp(t, b.rpos.y, b.invG.y),
                    Lerp(t, b.rpos.z, b.invG.z))
                local s = p:ToScreen()
                if s.visible then
                    if prev then surface.DrawLine(prev.x, prev.y, s.x, s.y) end
                    prev = s
                else
                    prev = nil
                end
            end
            local ip = b.invG:ToScreen()
            if ip.visible then
                local r = math.Clamp(1400 / math.max(1, dist), 6, 24)
                surface.DrawCircle(ip.x, ip.y, r, 100, 200, 255, 220)
            end
        end
        end -- showStatus

        -- Скелет рисуем только в PVS: вне его кости замирают на старом месте
        if GeminiBots.ESPSkeleton and IsValid(b.ent) and not b.ent:IsDormant() then
            DrawSkeleton(b.ent)
        end
    end
end)
