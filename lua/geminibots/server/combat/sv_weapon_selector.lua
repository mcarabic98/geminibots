--[[
    GeminiBots - Weapon Selector System
    Вероятностный выбор оружия под дистанцию боя:
    вдаль — снайперка, средняя — автомат/ПП, вплотную — дробовик.
    Взрывное оружие — только с безопасной дистанции (бот не суицидится):
    гранатометы бьют вдаль, гранаты летят навесом на средней, вплотную —
    вес 0 (не выбираются). Рулетка по весам (не 100% детерминизм),
    фолбэк на лучшее из имеющегося, троттлинг переоценки против дерганья.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.WeaponSelector = GeminiBots.WeaponSelector or {}

-- Пауза между переоценками: не дергаем пушку каждый тик
local EVAL_INTERVAL_MIN = 1.5
local EVAL_INTERVAL_MAX = 3.0

-- Бонус текущему оружию: бот не дергает пушки без веской причины
local STICKY_MULT = 1.6

-- Штраф за пустой магазин (запас еще есть): берем, только если лучше нет
local EMPTY_CLIP_MULT = 0.3

-- Паттерны классов взрывного оружия
local LAUNCHER_PATTERNS = {
    "rpg", "m79", "gp25", "m203", "milkor", "hk69", "at4", "rpg7",
    "law", "bazooka", "xm25", "panzerfaust", "panzerschreck", "piat",
    "carlgustaf", "m136", "grenade"
}

local FRAG_PATTERNS = {
    "frag", "m67", "mk2", "rgn", "rgo"
}

local TRAP_PATTERNS = {
    "slam", "tripmine"
}

local function MatchesAny(lower, patterns)
    for _, p in ipairs(patterns) do
        if string.find(lower, p, 1, true) then return true end
    end
    return false
end

-- Классификация взрывного: "launcher" (прямой выстрел), "frag" (навесной
-- бросок), "trap" (устанавливаемое, бот ставить не умеет), nil (обычное)
function GeminiBots.WeaponSelector:ExplosiveKind(class)
    if not class or class == "" then return nil end
    -- Сначала адаптеры паков: чинят то, где generic ошибается по подстрокам
    local WA = GeminiBots.WeaponAdapters
    if WA then
        local ak = WA:Kind(class)
        if ak == "frag" or ak == "launcher" or ak == "trap" then return ak end
    end
    local lower = string.lower(class)
    if MatchesAny(lower, TRAP_PATTERNS) then return "trap" end
    if MatchesAny(lower, LAUNCHER_PATTERNS) then return "launcher" end
    if MatchesAny(lower, FRAG_PATTERNS) then return "frag" end
    return nil
end

-- Безопасная дистанция применения (юниты): ближе бот сам себя заденет
function GeminiBots.WeaponSelector:SafeDistance(class)
    if not class then return 450 end
    local lower = string.lower(class)
    if string.find(lower, "rpg", 1, true) then return 550 end
    if self:ExplosiveKind(class) == "frag" then return 350 end
    if self:ExplosiveKind(class) == "launcher" then return 450 end
    return 450
end

-- Идеальная боевая дистанция ствола (прием у Zeta: keepDistance).
-- Бой держит полосу вокруг нее вместо общих конваров
function GeminiBots.WeaponSelector:KeepDistance(class)
    if not class or class == "" then return nil end
    local WA = GeminiBots.WeaponAdapters
    local adapterKind = WA and WA:Kind(class) or nil
    if adapterKind == "melee" then return 90 end
    if adapterKind == "short" then return 250 end
    if adapterKind == "launcher" or adapterKind == "frag" then
        return self:SafeDistance(class)
    end
    local lower = string.lower(class)
    if string.find(lower, "sniper") or string.find(lower, "awp")
        or string.find(lower, "barret") or string.find(lower, "svu")
        or string.find(lower, "dragunov") or string.find(lower, "crossbow")
        or string.find(lower, "scout") or string.find(lower, "ssg08") then
        return 1000
    end
    if string.find(lower, "ar2") or string.find(lower, "ak47")
        or string.find(lower, "m4") or string.find(lower, "rifle")
        or string.find(lower, "scar") or string.find(lower, "famas")
        or string.find(lower, "galil") or string.find(lower, "aug")
        or string.find(lower, "g36") or string.find(lower, "sg55")
        or string.find(lower, "g3sg1")
        or string.find(lower, "m249") or string.find(lower, "negev")
        or string.find(lower, "minigun") or string.find(lower, "m60")
        or string.find(lower, "lmg") then
        return 600
    end
    if string.find(lower, "smg") or string.find(lower, "mp5")
        or string.find(lower, "ump") or string.find(lower, "vector")
        or string.find(lower, "mac10") or string.find(lower, "uzi")
        or string.find(lower, "p90") or string.find(lower, "mp7")
        or string.find(lower, "mp9") or string.find(lower, "tec9")
        or string.find(lower, "bizon") or string.find(lower, "sten")
        or string.find(lower, "thompson") or string.find(lower, "honeybadger")
        or string.find(lower, "pdw") then
        return 450
    end
    if string.find(lower, "shotgun") or string.find(lower, "spas")
        or string.find(lower, "remington") or string.find(lower, "mossberg")
        or string.find(lower, "striker") or string.find(lower, "m1014")
        or string.find(lower, "xm1014") or string.find(lower, "mag7")
        or string.find(lower, "nova") or string.find(lower, "sawedoff") then
        return 200
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
        return 350
    end
    if string.find(lower, "crowbar", 1, true)
        or string.find(lower, "stunstick", 1, true)
        or string.find(lower, "knife", 1, true) then
        return 90
    end
    return 500
end

-- Оценка ствола на дистанции 0..100. Ноль — не брать вообще.
local function ScoreWeapon(class, dist, clip, bot)
    local lower = string.lower(class)
    local boomKind = GeminiBots.WeaponSelector:ExplosiveKind(class)

    -- Утилиты не оружие: физган/тулган/камера в бою не стреляют,
    -- иначе бот "дерется" гравипушкой и молчит
    if string.find(lower, "physcannon", 1, true)
        or string.find(lower, "physgun", 1, true)
        or string.find(lower, "toolgun", 1, true)
        or string.find(lower, "camera", 1, true) then
        return 0
    end

    -- Ловушки (SLAM и т.п.): ставить бот не умеет — не кандидат
    if boomKind == "trap" then return 0 end

    -- Гранатометы: только с безопасной дистанции, пик на 700-1500
    if boomKind == "launcher" then
        local safe = GeminiBots.WeaponSelector:SafeDistance(class)
        if dist < safe then return 0 end
        if dist >= 700 and dist <= 1500 then return 90 end
        if dist < 700 then return 30 + (dist - safe) / math.max(1, 700 - safe) * 60 end
        return math.max(50, 90 - (dist - 1500) / 1000 * 30)
    end

    -- Ручные гранаты: навесом на средней (450-950), в упор и вдаль — 0
    if boomKind == "frag" then
        local safe = GeminiBots.WeaponSelector:SafeDistance(class)
        if dist < safe or dist > 1600 then return 0 end
        if dist >= 450 and dist <= 950 then return 85 end
        if dist < 450 then return 30 + (dist - safe) / math.max(1, 450 - safe) * 55 end
        return math.max(25, 85 - (dist - 950) / 650 * 60)
    end

    -- Kinds адаптеров паков (SWCS-тазер, тактика, рукопашка паков)
    local WA = GeminiBots.WeaponAdapters
    local adapterKind = WA and WA:Kind(class) or nil
    if adapterKind == "tactical" then
        -- Тактические броски: счет с учетом кулдауна (nil = 0, не берем)
        local s = WA:AdapterScore(bot, class, dist)
        return s or 0
    end
    if adapterKind == "short" then -- тазер и подобное: только вплотную
        if dist <= 350 then return 85 end
        if dist >= 800 then return 10 end
        return 85 - (dist - 350) / 450 * 60
    end
    if adapterKind == "melee" then
        if dist < 200 then return 80 end
        return 5
    end

    -- Рукопашка (магазина нет): только вплотную
    if clip == -1 then
        if dist < 200 then return 80 end
        return 5
    end

    -- Дробовики: короли вплотную, вдаль почти бесполезны
    if string.find(lower, "shotgun") or string.find(lower, "spas")
        or string.find(lower, "remington") or string.find(lower, "mossberg")
        or string.find(lower, "striker") or string.find(lower, "m1014")
        or string.find(lower, "xm1014") or string.find(lower, "mag7")
        or string.find(lower, "nova") or string.find(lower, "sawedoff") then
        if dist <= 400 then return 100 end
        if dist >= 1000 then return 10 end
        return 100 - (dist - 400) / 600 * 75 -- 400->100 ... 1000->25
    end

    -- Снайперки: вдаль, вблизи мешают (m40a1 проверяем раньше m4!)
    if string.find(lower, "sniper") or string.find(lower, "awp")
        or string.find(lower, "m40a1")
        or string.find(lower, "barret") or string.find(lower, "svu")
        or string.find(lower, "dragunov") or string.find(lower, "crossbow")
        or string.find(lower, "scout") or string.find(lower, "ssg08") then
        if dist >= 1000 then return 100 end
        if dist >= 500 then return 60 + (dist - 500) / 500 * 40 end
        return 15
    end

    -- Винтовки/автоматы: универсалы, плато на средней-дальней
    if string.find(lower, "ar2") or string.find(lower, "ak47")
        or string.find(lower, "m4") or string.find(lower, "rifle")
        or string.find(lower, "scar") or string.find(lower, "famas")
        or string.find(lower, "galil") or string.find(lower, "aug")
        or string.find(lower, "g36") or string.find(lower, "sg55")
        or string.find(lower, "g3sg1") then
        if dist >= 300 and dist <= 1500 then return 90 end
        if dist < 300 then return 70 end
        return math.max(50, 90 - (dist - 1500) / 1000 * 40)
    end

    -- ПП/SMG: средняя-ближняя, вдаль сыплются
    if string.find(lower, "smg") or string.find(lower, "mp5")
        or string.find(lower, "ump") or string.find(lower, "vector")
        or string.find(lower, "mac10") or string.find(lower, "uzi")
        or string.find(lower, "p90") or string.find(lower, "mp7")
        or string.find(lower, "mp9") or string.find(lower, "tec9")
        or string.find(lower, "bizon") or string.find(lower, "sten")
        or string.find(lower, "thompson") or string.find(lower, "honeybadger")
        or string.find(lower, "pdw") then
        if dist <= 700 then return 85 end
        if dist >= 1400 then return 20 end
        return 85 - (dist - 700) / 700 * 55 -- 700->85 ... 1400->30
    end

    -- Пулеметы: средняя-дальняя, плотный огонь
    if string.find(lower, "m249") or string.find(lower, "negev")
        or string.find(lower, "minigun") or string.find(lower, "m60")
        or string.find(lower, "lmg") then
        if dist >= 300 and dist <= 1500 then return 88 end
        if dist < 300 then return 68 end
        return math.max(45, 88 - (dist - 1500) / 1000 * 40)
    end

    -- Пистолеты: слабые везде, вдаль почти никакие
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
        if dist <= 500 then return 55 end
        if dist >= 1500 then return 10 end
        return 55 - (dist - 500) / 1000 * 40 -- 500->55 ... 1500->15
    end

    -- Неизвестные пушки: нейтральная оценка с уклоном в среднюю, чтобы их брали
    if dist >= 300 and dist <= 1200 then return 60 end
    return 45
end

-- Выбор оружия из инвентаря
function GeminiBots.WeaponSelector:UpdateWeapon(bot, targetDist)
    if not bot or not IsValid(bot.ply) then return end

    local ply = bot.ply
    local weaponsList = ply:GetWeapons()
    if #weaponsList <= 1 then return end -- Выбирать не из чего

    local currentWep = ply:GetActiveWeapon()

    -- Дуэль: деремся только дуэльным стволом (если он есть и заряжен)
    local duel = GeminiBots.Duels and GeminiBots.Duels[ply]
    if duel and duel.class then
        for _, wep in ipairs(weaponsList) do
            if IsValid(wep) and wep:GetClass() == duel.class then
                local clip = wep:Clip1()
                local ammoType = wep:GetPrimaryAmmoType()
                local reserve = (ammoType and ammoType ~= -1) and ply:GetAmmoCount(ammoType) or 0
                if not (clip == 0 and reserve == 0 and clip ~= -1) then
                    if currentWep ~= wep then
                        ply:SelectWeapon(duel.class)
                    end
                    return
                end
            end
        end
    end

    -- Форсированная переоценка, если текущий ствол полностью пуст:
    -- стоим с пустой пушкой — надо срочно брать заряженную
    local forceEval = false
    if IsValid(currentWep) then
        local curClip = currentWep:Clip1()
        local curAmmoType = currentWep:GetPrimaryAmmoType()
        local curReserve = (curAmmoType and curAmmoType ~= -1) and ply:GetAmmoCount(curAmmoType) or 0
        if curClip == 0 and curReserve == 0 and curClip ~= -1 then
            forceEval = true
        end
    end

    if not forceEval and CurTime() < (bot.nextWeaponEvalTime or 0) then return end
    bot.nextWeaponEvalTime = CurTime() + math.Rand(EVAL_INTERVAL_MIN, EVAL_INTERVAL_MAX)

    local dist = targetDist or 500
    local candidates = {}

    for _, wep in ipairs(weaponsList) do
        if not IsValid(wep) then continue end

        -- Кривой скриптованный ствол не должен ронять оценку всего тика
        local okW, clip, ammoType = pcall(function()
            return wep:Clip1(), wep:GetPrimaryAmmoType()
        end)
        if not okW then continue end
        local reserve = (ammoType and ammoType ~= -1) and ply:GetAmmoCount(ammoType) or 0

        -- Совсем без патронов — даже не кандидат
        if clip == 0 and reserve == 0 and clip ~= -1 then continue end

        local score = ScoreWeapon(wep:GetClass(), dist, clip, bot)

        -- Вес 0 (взрывное в упор, ловушки) — даже не кандидат
        if score <= 0 then continue end

        if clip == 0 then
            score = score * EMPTY_CLIP_MULT
        end

        local weight = math.max(score, 1) ^ 2
        if wep == currentWep then
            weight = weight * STICKY_MULT
        end

        table.insert(candidates, { wep = wep, weight = weight })
    end

    if #candidates == 0 then return end

    -- Взвешенная рулетка: лучший ствол — чаще всего, но не всегда
    local total = 0
    for _, c in ipairs(candidates) do total = total + c.weight end

    local roll = math.Rand(0, total)
    local picked = candidates[#candidates].wep
    for _, c in ipairs(candidates) do
        roll = roll - c.weight
        if roll <= 0 then
            picked = c.wep
            break
        end
    end

    if IsValid(picked) and picked ~= currentWep then
        ply:SelectWeapon(picked:GetClass())
    end
end
