--[[
    GeminiBots - Combat Controller
    Управление ведением огня, тактическими стрейфами, дистанцией боя и перезарядкой.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Combat = GeminiBots.Combat or {}

-- Прострел: проверки по таймеру, только по свежему следу и пробиваемым преградам
local WALLBANG_MEMORY = 2.0 -- сколько секунд после потери из виду еще жжем
local WALLBANG_CHECK_INTERVAL = 0.5 -- как часто проверять преграду
local WALLBANG_BURST = 0.7 -- длина очереди в стену
local WALLBANG_COOLDOWN = 1.5 -- пауза между очередями
local WALLBANG_MAX_DIST = 1500 -- дальше не достаем

-- Попытка прострела укрытия: враг только что ушел за стекло/хрупкое,
-- бьем короткой очередью в предсказанную точку. Возвращает true, если
-- бот занят прострелом (никуда не идти).
function GeminiBots.Combat:TryWallbang(bot, target)
    if not bot or not IsValid(bot.ply) or not bot.ply:Alive() then return false end
    if not IsValid(target) then return false end
    local cfg = GeminiBots.Config
    if not cfg or cfg.WallbangEnabled == false then return false end

    -- Продолжаем начатую очередь без перепроверок (но с патронами:
    -- пустой ствол очередью не давит)
    if (bot.wallbangUntil or 0) > CurTime() then
        local wbWep = bot.ply:GetActiveWeapon()
        local cw = (IsValid(wbWep) and wbWep.Clip1) and wbWep:Clip1() or 1
        if cw ~= 0 then
            if bot.wallbangAim then bot.desiredViewAngles = bot.wallbangAim end
            bot.buttons = bit.bor(bot.buttons or 0, IN_ATTACK)
            return true
        end
    end
    if CurTime() < (bot.nextWallbangTime or 0) then return false end
    if CurTime() < (bot.nextWallbangCheck or 0) then return false end
    bot.nextWallbangCheck = CurTime() + WALLBANG_CHECK_INTERVAL

    local lastPos = bot.lastKnownTargetPos
    if not lastPos then return false end
    if not bot.targetLostTime or bot.targetLostTime <= 0 then return false end
    if CurTime() - bot.targetLostTime > WALLBANG_MEMORY then return false end

    local ply = bot.ply
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return false end
    local class = wep:GetClass()
    -- Взрывное, ловушки и рукопашка в стену не работают
    if GeminiBots.WeaponSelector:ExplosiveKind(class) ~= nil then return false end
    local clip = wep:Clip1()
    if clip ~= nil and clip <= 0 then return false end

    local eyePos = ply:EyePos()
    local aimPoint = Vector(lastPos.x, lastPos.y, lastPos.z + 45)
    local dist = eyePos:Distance(aimPoint)
    if dist > WALLBANG_MAX_DIST then return false end

    -- Какая преграда: движок реально пробивает только стекло и хрупкое.
    -- Бетон/металл пули остановят — туда даже не начинаем.
    local tr = util.TraceLine({
        start = eyePos,
        endpos = aimPoint,
        filter = ply,
        mask = MASK_SHOT
    })
    if not tr.Hit then return false end -- стена вдруг исчезла: пусть движется

    local penetrable = (tr.MatType == MAT_GLASS)
    local hitEnt = tr.Entity
    if IsValid(hitEnt) then
        local hc = string.lower(hitEnt:GetClass())
        if string.find(hc, "breakable", 1, true) or string.find(hc, "glass", 1, true) then
            penetrable = true
        end
    end
    if not penetrable then return false end

    -- Предикт: куда враг ушел за укрытие за время полета пули
    local vel = bot.lastSeenVel or Vector(0, 0, 0)
    local predicted = aimPoint + vel * (dist / 6000 + 0.2)
    local aimAngles = (predicted - eyePos):Angle()
    aimAngles.p = math.Clamp(aimAngles.p, -89, 89)
    aimAngles.y = math.NormalizeAngle(aimAngles.y)

    bot.desiredViewAngles = aimAngles
    bot.wallbangAim = aimAngles
    bot.buttons = bit.bor(bot.buttons or 0, IN_ATTACK)
    bot.wallbangUntil = CurTime() + WALLBANG_BURST
    bot.nextWallbangTime = CurTime() + WALLBANG_BURST + WALLBANG_COOLDOWN
    GeminiBots.Navigator:Stop(bot) -- стоим и давим очередью, а не бежим
    return true
end

-- Главное обновление боевой логики бота
function GeminiBots.Combat:Update(bot, dt)
    if not bot or not IsValid(bot.ply) or not bot.ply:Alive() then return end

    -- Ослепленный не стреляет: глушим и движение (иначе идет вслепую
    -- по последнему маршруту) — кнопки уже нули выше
    if GeminiBots.SWCS_IsBlind and GeminiBots.SWCS_IsBlind(bot.ply) then
        bot.forwardMove, bot.sideMove, bot.upMove = 0, 0, 0
        return
    end

    local target = bot.target
    if not IsValid(target) or not target:Alive() then return end

    local ply = bot.ply
    local cfg = GeminiBots.Config
    local dist = ply:GetPos():Distance(target:GetPos())

    -- 1. Выбор подходящего оружия под дистанцию
    GeminiBots.WeaponSelector:UpdateWeapon(bot, dist)

    -- Что у бота в руках: обычное, гранатомет или граната
    local wep = ply:GetActiveWeapon()
    local activeClass = IsValid(wep) and wep:GetClass() or ""
    local boomKind = GeminiBots.WeaponSelector:ExplosiveKind(activeClass)
    local WA = GeminiBots.WeaponAdapters
    local adapterKind = (WA and activeClass ~= "") and WA:Kind(activeClass) or nil
    local tacticPointOk = false

    -- 2. Расчет углов прицеливания
    local aimAngles
    local aimThreshold = 14
    local lobLanding = nil
    local lobPoints = nil

    -- Навесы считаем не чаще 3 раз в секунду: симуляция жрет аллокации,
    -- за 0.3 сек дуга не устаревает
    if boomKind == "frag" and IsValid(target)
        and CurTime() >= (bot.nextLobCalc or 0) then
        bot.nextLobCalc = CurTime() + 0.3
        -- Гранату кидаем навесом по баллистике, а не прямой наводкой
        bot.lobAngles, bot.lobLanding, bot.lobPoints =
            GeminiBots.Aiming:CalculateLobAngles(bot, target:GetPos())
    end
    if boomKind == "frag" and IsValid(target) and bot.lobAngles then
        aimAngles, lobLanding, lobPoints = bot.lobAngles, bot.lobLanding, bot.lobPoints
        aimThreshold = 10
    elseif boomKind ~= "frag" then
        aimAngles = GeminiBots.Aiming:CalculateAimAngles(bot, target)
    end

    -- Тактический бросок (флеш/смок/декой): навесом в точку адаптера
    if adapterKind == "tactical" and IsValid(target) and WA
        and CurTime() >= (bot.nextLobCalc or 0) then
        bot.nextLobCalc = CurTime() + 0.3
        local okP, point = pcall(WA.TacticPoint, WA, bot, target, activeClass)
        if okP and point and isvector(point) then
            bot.lobAngles, bot.lobLanding, bot.lobPoints =
                GeminiBots.Aiming:CalculateLobAngles(bot, point)
            tacticPointOk = true
        else
            bot.lobAngles, bot.lobLanding, bot.lobPoints = nil, nil, nil
        end
    end
    if adapterKind == "tactical" and bot.lobAngles then
        aimAngles, lobLanding, lobPoints = bot.lobAngles, bot.lobLanding, bot.lobPoints
        aimThreshold = 12
        bot.desiredViewAngles = aimAngles
    end
    -- Между пересчетами дуги держим прошлый прицел, а не nil
    if aimAngles then
        bot.lastAimAngles = aimAngles
    else
        aimAngles = bot.lastAimAngles or Angle(0, 0, 0)
    end

    bot.desiredViewAngles = aimAngles

    -- 3. Проверка перезарядки. Пока магазин пуст и идет перезарядка —
    -- только она: движок игнорит релоад во время атаки, бот вечно щелкает
    bot.reloadingGun = false
    if IsValid(wep) and wep.Clip1 and wep:Clip1() == 0 then
        local ammoType = wep:GetPrimaryAmmoType()
        if ammoType and ammoType ~= -1 and ply:GetAmmoCount(ammoType) > 0 then
            bot.buttons = bit.bor(bot.buttons or 0, IN_RELOAD)
            bot.reloadingGun = true
        end
    end

    -- 4. Ведение огня
    local hasLOS, hitPos = GeminiBots.Vision:HasLineOfSight(bot, target)
    local aimReady = GeminiBots.Aiming:IsAimReady(bot, aimAngles, aimThreshold)

    -- Боевая насмешка: бот давно видит цель, а та все жива — троллим аим.
    -- Счетчик сбрасывается при смене цели или потере из виду.
    if (bot.targetLostTime or 0) == 0 then
        if bot.tauntTarget ~= target then
            bot.tauntTarget = target
            bot.tauntSince = CurTime()
        elseif CurTime() - (bot.tauntSince or CurTime()) > 20 then
            bot.tauntSince = CurTime()
            GeminiBots.Chat:SayCombatTaunt(bot, "AIMSHAME")
        end
    else
        bot.tauntTarget = nil
    end

    -- Гейт взрывного оружия: не стрелять, если заденет самого
    local holdFire = false
    if boomKind == "launcher" or boomKind == "frag" then
        local safe = GeminiBots.WeaponSelector:SafeDistance(activeClass)

        -- Враг ближе безопасной дистанции — ждем и срочно меняем пушку
        -- (троттлинг срочной переоценки: иначе рулетка каждый тик)
        if dist < safe then
            holdFire = true
            if CurTime() > (bot.nextUrgentEval or 0) then
                bot.nextWeaponEvalTime = 0
                bot.nextUrgentEval = CurTime() + 0.5
            end
        else
            -- Стена перед носом ближе безопасной — ракета/граната вернется
            local eyePos = ply:EyePos()
            local aimDir = aimAngles:Forward()
            local tr = util.TraceLine({
                start = eyePos,
                endpos = eyePos + aimDir * safe,
                filter = ply,
                mask = MASK_SOLID
            })
            if tr.Hit then
                holdFire = true
            end
        end

        -- Граната: кидаем, только если расчетная точка падения рядом с целью
        -- (иначе полетит в потолок или за спину)
        if not holdFire and boomKind == "frag" and lobLanding and IsValid(target) then
            if lobLanding:Distance(target:GetPos()) > 250 then
                holdFire = true
            end
        end
    end

    -- Тактика без готовой точки/кулдауна — не кидаем, сразу меняем пушку
    if adapterKind == "tactical"
        and (not tacticPointOk or CurTime() < (bot.nextTacticalTime or 0)) then
        holdFire = true
        if CurTime() > (bot.nextUrgentEval or 0) then
            bot.nextWeaponEvalTime = 0
            bot.nextUrgentEval = CurTime() + 0.5
        end
    end

    -- Не стреляем в стену и пол прямо перед собой
    if not holdFire then
        local eyePosF = ply:EyePos()
        local checkDist = math.min(150, dist * 0.7)
        if checkDist > 10 then
            local trF = util.TraceLine({
                start = eyePosF,
                endpos = eyePosF + aimAngles:Forward() * checkDist,
                filter = ply,
                mask = MASK_SOLID_BRUSHONLY
            })
            if trF.Hit then
                holdFire = true
            end
        end
    end

    -- Траекторию шлем точками по сети: штатный дебаг видно только с developer
    if (boomKind == "frag" or adapterKind == "tactical") and lobPoints and #lobPoints > 1
        and GeminiBots.Config and GeminiBots.Config.DebugDraw then
        if CurTime() >= (bot.GeminiBots_NextTrajSend or 0) then
            bot.GeminiBots_NextTrajSend = CurTime() + 0.15
            GeminiBots.Aiming:BroadcastTrajectory(ply, lobPoints, lobLanding, 255, 150, 0)
        end
    end

    -- Проверка таймера реакции
    if not holdFire and not bot.reloadingGun
        and (bot.reactionTimer or 0) <= CurTime() and hasLOS and aimReady then
        -- Если оружие готово стрелять
        if CurTime() >= (bot.nextBurstTime or 0) then
            -- Гейт наводки как у ботов HL2MP, но угловой вместо EyeTrace:
            -- трасс в худую цель вдаль не попадает никогда, и бот вечно
            -- "не навелся". Меряем ошибку между реальным взглядом и
            -- направлением на центр цели: <= 7 градусов — жмем, сорвалось —
            -- дожимаем 3 сек. Навесы (граната/тактика) целятся в точку,
            -- их пропускаем
            local fireOk = true
            if boomKind ~= "frag" and adapterKind ~= "tactical" then
                local onTarget = false
                if hasLOS then
                    local okA, aimPt = pcall(function() return target:WorldSpaceCenter() end)
                    if okA and aimPt then
                        local angTo = (aimPt - ply:EyePos()):Angle()
                        local eye = ply:EyeAngles()
                        local dyaw = math.AngleDifference(angTo.y, eye.y)
                        local dpitch = math.AngleDifference(angTo.p, eye.p)
                        if math.sqrt(dyaw * dyaw + dpitch * dpitch) <= 7 then
                            onTarget = true
                        end
                    end
                end
                if onTarget then
                    bot.lastOnTargetTime = CurTime()
                elseif CurTime() - (bot.lastOnTargetTime or 0) > 3.0 then
                    fireOk = false
                end
            end
            if fireOk then
                bot.buttons = bit.bor(bot.buttons or 0, IN_ATTACK)

                -- Допкнопки адаптера (тяжелый удар ножа)
                local extra = WA and WA:ExtraButtons(bot, wep, dist) or 0
                if extra ~= 0 then
                    bot.buttons = bit.bor(bot.buttons, extra)
                end

                -- Тактический бросок — одиночный: кулдаун и сразу переоценка пушки
                if adapterKind == "tactical" then
                    bot.nextTacticalTime = CurTime() + math.Rand(35, 50)
                    bot.nextWeaponEvalTime = 0
                end
            end

            -- Пауза между выстрелами: гранаты кидаем редко, пистолеты/дробь средне.
            -- Адаптер пака может задать свою (тазер SWCS — долгая перезарядка).
            local burstDelay
            local adapterBurst = WA and WA:BurstDelay(activeClass) or nil
            if adapterBurst then
                burstDelay = math.Rand(adapterBurst * 0.9, adapterBurst * 1.1)
            elseif boomKind == "frag" then
                burstDelay = math.Rand(1.0, 1.6)
            else
                local isPistolOrShotgun = IsValid(wep) and (wep:GetClass():find("pistol") or wep:GetClass():find("357") or wep:GetClass():find("shotgun"))
                burstDelay = isPistolOrShotgun and math.Rand(0.2, 0.4) or math.Rand(0.08, 0.16)
            end
            bot.nextBurstTime = CurTime() + burstDelay
        end
    end

    -- Дуэль: противник сменил ствол — жалоба (не чаще раза в 20 сек).
    -- Тулган/физган/камеру за нарушение не считаем.
    local duel = GeminiBots.Duels and GeminiBots.Duels[ply]
    if duel and IsValid(duel.enemy) and target == duel.enemy
        and CurTime() >= (bot.duelNagNext or 0) then
        local ew = duel.enemy:GetActiveWeapon()
        if IsValid(ew) then
            local ec = string.lower(ew:GetClass())
            local at = ew:GetPrimaryAmmoType()
            local isTool = string.find(ec, "tool", 1, true)
                or string.find(ec, "camera", 1, true)
                or string.find(ec, "phys", 1, true)
            if at and at ~= -1 and not isTool and ew:GetClass() ~= duel.class then
                bot.duelNagNext = CurTime() + 20
                GeminiBots.DuelNag(bot, duel)
            end
        end
    end

    -- 5. Тактическое перемещение в бою.
    -- Полоса дистанции от активного ствола (keepDistance у Zeta):
    -- снайпер держит 1000, дробовик жмется к 200. Нет ствола —
    -- общие конвары
    local minDist = (cfg and cfg.CombatMinDistance) or 250
    local maxDist = (cfg and cfg.CombatMaxDistance) or 900
    local keep = IsValid(wep)
        and GeminiBots.WeaponSelector:KeepDistance(activeClass) or nil
    if keep then
        -- Рукопашка: полоса вплотную, иначе бот вечно стрейфит вне удара
        if keep <= 90 then
            minDist, maxDist = 0, 130
        else
            minDist = math.Clamp(keep * 0.7, 100, 2000)
            maxDist = math.Clamp(keep * 1.4, 150, 2000)
        end
    end

    if dist > maxDist then
        -- Слишком далеко: сближаемся с целью (бросаем, если цель пропала).
        -- Репас не чаще 2 раз в секунду: FindPath каждый тик — дорого
        if CurTime() >= (bot.nextCombatRepath or 0) then
            bot.nextCombatRepath = CurTime() + 0.5
            GeminiBots.Navigator:MoveTo(bot, target:GetPos(), false, {
                abortFn = function(b) return not IsValid(b.target) end,
            })
        end
    elseif dist < minDist then
        -- Слишком близко: пятимся назад
        GeminiBots.Navigator:Stop(bot)
        bot.forwardMove = -220
    else
        -- Оптимальная боевая дистанция: тактический стрейф влево-вправо
        GeminiBots.Navigator:Stop(bot)

        if CurTime() > (bot.nextStrafeSwitch or 0) then
            bot.strafeDirection = (bot.strafeDirection or 1) * -1
            local minInterval = (cfg and cfg.StrafeIntervalMin) or 0.8
            local maxInterval = (cfg and cfg.StrafeIntervalMax) or 2.0
            bot.nextStrafeSwitch = CurTime() + math.Rand(minInterval, maxInterval)
        end

        bot.sideMove = (bot.strafeDirection or 1) * 220

        -- Шанс присесть во время интенсивной перестрелки: держим 1-2 сек,
        -- а не мигаем каждый тик (хитбокс дергается, бхоп рвется)
        if CurTime() >= (bot.crouchUntil or 0) then
            local crouchChance = (cfg and cfg.CrouchChance) or 0.25
            if math.random() <= crouchChance then
                bot.crouchUntil = CurTime() + math.Rand(1.0, 2.0)
            else
                bot.crouchUntil = 0
            end
        end
        if CurTime() < (bot.crouchUntil or 0) then
            bot.buttons = bit.bor(bot.buttons or 0, IN_DUCK)
        end
    end
end
