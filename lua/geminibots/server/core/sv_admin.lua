--[[
    GeminiBots - Admin Tools (Server)
    Телепорты ботов (к себе / себя к боту), инспектор состояния ИИ,
    мост в ULX (если установлен). ESP сюда не входит — отдельно.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Admin = GeminiBots.Admin or {}

local function IsAdmin(ply)
    return not IsValid(ply) or ply:IsSuperAdmin() or ply:IsAdmin() or game.SinglePlayer()
end

-- Найти бота по нику (кастомному или стандартному): точное > префикс > подстрока
function GeminiBots.Admin:FindBot(query)
    if not query or query == "" then return nil end
    local lower = (GeminiBots.Utf8Lower or string.lower)
    query = lower(string.Trim(tostring(query)))

    local bots = player.GetBots()
    if #bots == 0 then return nil end

    local prefixHits, subHits = {}, {}
    for _, botPly in ipairs(bots) do
        if not IsValid(botPly) then continue end
        local nick = lower(botPly:Nick() or "")
        local custom = lower(botPly:GetNWString("GeminiBots_CustomNick", ""))
        if nick == query or custom == query then
            return botPly
        end
        if string.StartWith(nick, query) or (custom ~= "" and string.StartWith(custom, query)) then
            table.insert(prefixHits, botPly)
        elseif string.find(nick, query, 1, true)
            or (custom ~= "" and string.find(custom, query, 1, true)) then
            table.insert(subHits, botPly)
        end
    end

    return prefixHits[1] or subHits[1]
end

-- Сбросить навигацию бота после телепорта, чтобы не бежал по старому пути
local function ResetNavAfterTeleport(bot)
    if not bot then return end
    if GeminiBots.Navigator and GeminiBots.Navigator.Stop then
        GeminiBots.Navigator:Stop(bot)
    end
    if IsValid(bot.ply) then
        bot.lastStuckPos = bot.ply:GetPos()
        bot.stuckTimer = CurTime()
        bot.bhopRolled = false
    end
end

-- Телепортировать ботов к админу (кругом, чтобы не слиплись).
-- botPlyOrNil == nil: всех живых ботов.
-- Возвращает число перемещенных.
function GeminiBots.Admin:BringBots(adminPly, botPlyOrNil)
    if not IsValid(adminPly) then return 0 end
    local targets = {}
    if IsValid(botPlyOrNil) and botPlyOrNil:IsBot() then
        table.insert(targets, botPlyOrNil)
    else
        for _, botPly in ipairs(player.GetBots()) do
            if IsValid(botPly) and botPly:Alive() then
                table.insert(targets, botPly)
            end
        end
    end
    if #targets == 0 then return 0 end

    local center = adminPly:GetPos()
    for i, botPly in ipairs(targets) do
        local ang = (i - 1) * (360 / #targets)
        local dest = center + Angle(0, ang, 0):Forward() * 140 + Vector(0, 0, 10)
        botPly:SetPos(dest)
        botPly:SetEyeAngles((center - dest):Angle())
        ResetNavAfterTeleport(GeminiBots:GetBot(botPly))
    end

    return #targets
end

-- Телепортировать админа к боту (встает перед ним, не внутри)
function GeminiBots.Admin:GotoBot(adminPly, botPly)
    if not IsValid(adminPly) or not IsValid(botPly) then return false end
    if not botPly:Alive() then return false end

    local botPos = botPly:GetPos()
    local yaw = IsValid(botPly) and botPly:EyeAngles().y or 0
    local dest = botPos + Angle(0, yaw + 180, 0):Forward() * 120 + Vector(0, 0, 10)
    adminPly:SetPos(dest)
    adminPly:SetEyeAngles((botPos - dest):Angle())
    return true
end

-- Текстовая сводка состояния ИИ бота (движение, стрельба, цель, память)
function GeminiBots.Admin:BotInfoString(botPly)
    if not IsValid(botPly) then return "Бот не найден." end
    local L = {}
    local function add(s) table.insert(L, s) end

    add(string.format("=== Бот: %s ===", botPly:Nick()))
    add(string.format("Жив: %s | HP: %d/%d | Броня: %d",
        botPly:Alive() and "да" or "нет",
        botPly:Health(), botPly:GetMaxHealth(), botPly:Armor()))

    local bot = GeminiBots:GetBot(botPly)
    if not bot then
        add("ИИ: не зарегистрирован (еще не инициализирован)")
        return table.concat(L, "\n")
    end

    add(string.format("Состояние ИИ: %s", tostring(bot.state)))

    -- Цель и стрельба
    if IsValid(bot.target) then
        local t = bot.target
        local tName = t:IsPlayer() and t:Nick() or t:GetClass()
        local tHP = (t.Health and t:Health() or -1)
        local dist = math.floor(botPly:GetPos():Distance(t:GetPos()))
        local los = GeminiBots.Vision and GeminiBots.Vision:HasLineOfSight(bot, t)
        add(string.format("Цель: %s | HP: %s | Дист: %d | LOS: %s",
            tName, tostring(tHP), dist, los and "да" or "нет"))
    else
        add("Цель: нет")
    end

    local wep = botPly:GetActiveWeapon()
    if IsValid(wep) then
        local clip = wep:Clip1()
        local at = wep:GetPrimaryAmmoType()
        local reserve = (at and at ~= -1) and botPly:GetAmmoCount(at) or -1
        add(string.format("Оружие: %s | Магазин: %s | Запас: %s | Всего стволов: %d",
            wep:GetClass(), tostring(clip), tostring(reserve), #botPly:GetWeapons()))
    else
        add("Оружие: нет в руках")
    end

    -- Движение и навигация
    local pos = botPly:GetPos()
    add(string.format("Позиция: %d, %d, %d | Скорость: %d | На земле: %s",
        math.floor(pos.x), math.floor(pos.y), math.floor(pos.z),
        math.floor(botPly:GetVelocity():Length()), botPly:IsOnGround() and "да" or "нет"))
    if bot.path and bot.pathIndex then
        add(string.format("Маршрут: узел %d/%d | Кнопки: %d | Move: %d/%d",
            bot.pathIndex, #bot.path, bot.buttons or 0,
            math.floor(bot.forwardMove or 0), math.floor(bot.sideMove or 0)))
    else
        add(string.format("Маршрут: нет | Кнопки: %d | Move: %d/%d",
            bot.buttons or 0, math.floor(bot.forwardMove or 0), math.floor(bot.sideMove or 0)))
    end

    -- Память и таймеры
    if IsValid(bot.target) and bot.lastKnownTargetPos then
        local ago = bot.targetLostTime and bot.targetLostTime > 0
            and string.format("%.1fs назад потеряна", CurTime() - bot.targetLostTime)
            or "в поле зрения"
        add("Память цели: " .. ago)
    end
    if (bot.reactionTimer or 0) > CurTime() then
        add(string.format("Реакция: огонь через %.2fs", bot.reactionTimer - CurTime()))
    end
    if bot.nextWeaponEvalTime then
        add(string.format("Стрейф: %s", (bot.strafeDirection or 1) > 0 and "вправо" or "влево"))
    end

    return table.concat(L, "\n")
end

local function PrintToCaller(caller, text)
    if not IsValid(caller) then
        print(text)
        return
    end
    -- TextMsg лимит 255 байт на сообщение: режем вывод кусками по строкам
    local buf = ""
    local function flush()
        if buf ~= "" then caller:PrintMessage(HUD_PRINTCONSOLE, buf) end
        buf = ""
    end
    for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
        while #line > 200 do
            caller:PrintMessage(HUD_PRINTCONSOLE, string.sub(line, 1, 200))
            line = string.sub(line, 201)
        end
        if #buf + #line + 1 > 200 then flush() end
        buf = buf .. line .. "\n"
    end
    flush()
    caller:ChatPrint("[GeminiBots] Инфо выведено в консоль (F10).")
end

concommand.Add("geminibots_bring", function(ply, _, args)
    if not IsAdmin(ply) then return end
    if not IsValid(ply) then
        print("[GeminiBots] Нужен живой админ на сервере (цель телепорта).")
        return
    end

    local target = nil
    if args[1] and args[1] ~= "" and args[1] ~= "*" then
        target = GeminiBots.Admin:FindBot(args[1])
        if not target then
            local msg = "[GeminiBots] Бот не найден: " .. args[1]
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
            return
        end
    end

    local n = GeminiBots.Admin:BringBots(ply, target)
    local msg = string.format("[GeminiBots] Телепортировано ботов к вам: %d", n)
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end, nil, "Телепортировать ботов к себе: geminibots_bring [ник|*]")

concommand.Add("geminibots_goto", function(ply, _, args)
    if not IsAdmin(ply) then return end
    if not IsValid(ply) then
        print("[GeminiBots] Нужен живой админ на сервере.")
        return
    end
    if not args[1] or args[1] == "" then
        ply:ChatPrint("[GeminiBots] Использование: geminibots_goto <ник бота>")
        return
    end

    local target = GeminiBots.Admin:FindBot(args[1])
    if not target then
        ply:ChatPrint("[GeminiBots] Бот не найден: " .. args[1])
        return
    end

    if GeminiBots.Admin:GotoBot(ply, target) then
        ply:ChatPrint("[GeminiBots] Телепортированы к боту: " .. target:Nick())
    else
        ply:ChatPrint("[GeminiBots] Не вышло (бот мертв?).")
    end
end, nil, "Телепортироваться к боту: geminibots_goto <ник бота>")

concommand.Add("geminibots_bot_info", function(ply, _, args)
    if not IsAdmin(ply) then return end

    if not args[1] or args[1] == "" then
        -- Краткий список всех ботов
        local L = { "=== Боты GeminiBots ===" }
        for _, botPly in ipairs(player.GetBots()) do
            if IsValid(botPly) then
                local bot = GeminiBots:GetBot(botPly)
                local tName = (bot and IsValid(bot.target))
                    and (bot.target:IsPlayer() and bot.target:Nick() or bot.target:GetClass())
                    or "-"
                table.insert(L, string.format("- %s | HP %d | %s | цель: %s | стволов: %d",
                    botPly:Nick(), botPly:Health(),
                    bot and tostring(bot.state) or "?",
                    tName, #botPly:GetWeapons()))
            end
        end
        if #L == 1 then table.insert(L, "(ботов нет)") end
        PrintToCaller(ply, table.concat(L, "\n"))
        return
    end

    local target = GeminiBots.Admin:FindBot(args[1])
    if not target then
        local msg = "[GeminiBots] Бот не найден: " .. args[1]
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    PrintToCaller(ply, GeminiBots.Admin:BotInfoString(target))
end, nil, "Инфо ИИ бота: geminibots_bot_info [ник] (без ника — список)")

--------------------------------------------------------------------------------
-- Мост в ULX (если установлен): !bringbots и !gotobot
--------------------------------------------------------------------------------
timer.Simple(5, function()
    if not (ulx and ULib and ulx.command) then return end

    local ok, err = pcall(function()
        local bring = ulx.command("GeminiBots", "ulx bringbots", function(calling_ply)
            if not IsValid(calling_ply) then return end
            local n = GeminiBots.Admin:BringBots(calling_ply, nil)
            if ulx.fancyLogAdmin then
                ulx.fancyLogAdmin(calling_ply, "#A привел ботов GeminiBots (#s шт.)", n)
            end
        end)
        bring:defaultAccess(ULib.ACCESS_ADMIN)
        bring:help("Привести всех ботов GeminiBots к себе.")

        local gotoBot = ulx.command("GeminiBots", "ulx gotobot", function(calling_ply, botNick)
            if not IsValid(calling_ply) then return end
            local target = GeminiBots.Admin:FindBot(botNick)
            if not target then
                if ulx.fancyLogAdmin then
                    ulx.fancyLogAdmin(calling_ply, "#A: бот не найден: #s", tostring(botNick))
                end
                return
            end
            if GeminiBots.Admin:GotoBot(calling_ply, target) and ulx.fancyLogAdmin then
                ulx.fancyLogAdmin(calling_ply, "#A телепортировался к боту #s", target:Nick())
            end
        end)
        gotoBot:addParam({ type = ULib.cmds.StringArg, hint = "ник бота" })
        gotoBot:defaultAccess(ULib.ACCESS_ADMIN)
        gotoBot:help("Телепортироваться к боту GeminiBots по нику.")

        local addbot = ulx.command("GeminiBots", "ulx addbot", function(calling_ply, count)
            local n = math.Clamp(math.floor(count or 1), 1, game.MaxPlayers())
            local spawned = 0
            for i = 1, n do
                if #player.GetAll() >= game.MaxPlayers() then break end
                timer.Simple(0.05 * (i - 1), function()
                    if GeminiBots.SpawnBotWithNick then
                        GeminiBots.SpawnBotWithNick(GeminiBots.NextCustomNick
                            and GeminiBots.NextCustomNick() or nil)
                    end
                end)
                spawned = spawned + 1
            end
            if ulx.fancyLogAdmin then
                ulx.fancyLogAdmin(calling_ply, "#A добавил ботов GeminiBots (#s шт.)", spawned)
            end
        end, "!addbot")
        addbot:addParam({ type = ULib.cmds.NumArg, min = 1, max = 128, hint = "сколько", ULib.cmds.optional })
        addbot:defaultAccess(ULib.ACCESS_ADMIN)
        addbot:help("Добавить ботов GeminiBots.")

        local kickbots = ulx.command("GeminiBots", "ulx kickbots", function(calling_ply)
            local n = 0
            for _, botPly in ipairs(player.GetBots()) do
                if IsValid(botPly) then
                    botPly:Kick("Удален GeminiBots")
                    n = n + 1
                end
            end
            if ulx.fancyLogAdmin then
                ulx.fancyLogAdmin(calling_ply, "#A убрал ботов GeminiBots (#s шт.)", n)
            end
        end, "!kickbots")
        kickbots:defaultAccess(ULib.ACCESS_ADMIN)
        kickbots:help("Убрать всех ботов GeminiBots.")

        local botinfo = ulx.command("GeminiBots", "ulx botinfo", function(calling_ply, botNick)
            local text
            if not botNick or botNick == "" then
                local L = { "=== Боты GeminiBots ===" }
                for _, botPly in ipairs(player.GetBots()) do
                    if IsValid(botPly) then
                        local bot = GeminiBots:GetBot(botPly)
                        table.insert(L, string.format("- %s | HP %d | %s",
                            botPly:Nick(), botPly:Health(),
                            bot and tostring(bot.state) or "?"))
                    end
                end
                if #L == 1 then table.insert(L, "(ботов нет)") end
                text = table.concat(L, "\n")
            else
                local target = GeminiBots.Admin:FindBot(botNick)
                if not target then
                    if ulx.fancyLogAdmin then
                        ulx.fancyLogAdmin(calling_ply, "#A: бот не найден: #s", tostring(botNick))
                    end
                    return
                end
                text = GeminiBots.Admin:BotInfoString(target)
            end
            if IsValid(calling_ply) then
                for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
                    calling_ply:PrintMessage(HUD_PRINTCONSOLE, line)
                end
                calling_ply:ChatPrint("[GeminiBots] Инфо в консоли (F10).")
            else
                print(text)
            end
        end, "!botinfo")
        botinfo:addParam({ type = ULib.cmds.StringArg, hint = "ник бота", ULib.cmds.optional })
        botinfo:defaultAccess(ULib.ACCESS_ADMIN)
        botinfo:help("Инфо ИИ бота (без ника — список).")

        local botpreset = ulx.command("GeminiBots", "ulx botpreset", function(calling_ply, preset)
            if GeminiBots.Skill and GeminiBots.Skill:Apply(preset) then
                if ulx.fancyLogAdmin then
                    ulx.fancyLogAdmin(calling_ply, "#A применил пресет сложности #s", tostring(preset))
                end
            else
                ULib.tsayError(calling_ply, "Нет такого пресета: " .. tostring(preset), true)
            end
        end, "!botpreset")
        botpreset:addParam({ type = ULib.cmds.StringArg, hint = "easy|normal|hard|expert|свой" })
        botpreset:defaultAccess(ULib.ACCESS_ADMIN)
        botpreset:help("Применить пресет сложности ботов.")

        local botstate = ulx.command("GeminiBots", "ulx botstate", function(calling_ply, botNick, state)
            local target = GeminiBots.Admin:FindBot(botNick)
            if not target then
                ULib.tsayError(calling_ply, "Бот не найден: " .. tostring(botNick), true)
                return
            end
            local bot = GeminiBots:GetBot(target)
            if not bot then
                ULib.tsayError(calling_ply, "ИИ бота не зарегистрирован.", true)
                return
            end
            if not GeminiBots.FSM or not GeminiBots.FSM.States[state] then
                ULib.tsayError(calling_ply, "Нет такого состояния: " .. tostring(state), true)
                return
            end
            GeminiBots.FSM:SetState(bot, state)
            if ulx.fancyLogAdmin then
                ulx.fancyLogAdmin(calling_ply, "#A перевел бота #s в #s", target:Nick(), state)
            end
        end, "!botstate")
        botstate:addParam({ type = ULib.cmds.StringArg, hint = "ник бота" })
        botstate:addParam({ type = ULib.cmds.StringArg, hint = "состояние" })
        botstate:defaultAccess(ULib.ACCESS_ADMIN)
        botstate:help("Перевести бота в состояние FSM.")
    end)

    if ok then
        GeminiBots:Log("ULX-мост активен: !bringbots, !gotobot, !addbot, !kickbots, !botinfo, !botpreset, !botstate")
    else
        GeminiBots:Warn("ULX-мост не встал: %s", tostring(err))
    end
end)
