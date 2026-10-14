--[[
    GeminiBots - Chat & Reactions System
    Система сообщений ботов в чат при убийствах, смертях и других событиях.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Chat = GeminiBots.Chat or {}

-- Свой lower с кириллицей: ванильный в GMod только под ASCII,
-- капс "ПРИВЕТ" им не ловился. Ниже покрываем А-Я + Ё.
function GeminiBots.Utf8Lower(s)
    s = string.lower(s or "")
    s = string.gsub(s, "\208\129", "\209\145") -- Ё -> ё
    s = string.gsub(s, "\208([\144-\175])", function(c)
        return "\208" .. string.char(c:byte() + 32) -- А-Я -> а-я
    end)
    return s
end

-- Отправка сообщения от имени бота с задержкой (имитация набора текста)
function GeminiBots.Chat:SayWithDelay(bot, text, delay)
    if not IsValid(bot) or not text or text == "" then return end

    local sendDelay = delay or math.Rand(0.6, 1.5)
    -- Имя уникально на бота: EntIndex + мелкий бакет времени + рандом.
    -- (AccountID у ботов 0 у всех, старый вариант терял сообщения при
    -- совпадении таймеров из-за перезаписи timer.Create.)
    local timerName = string.format("GeminiBots_ChatTimer_%d_%d_%d",
        bot:EntIndex(), math.floor(CurTime() * 1000), math.random(1000, 9999))

    timer.Create(timerName, sendDelay, 1, function()
        if IsValid(bot) then
            bot:Say(text)
        end
    end)
end

-- Время последнего спавна (для детекта спавкилла)
hook.Add("PlayerSpawn", "GeminiBots_Chat_SpawnTime", function(ply)
    if IsValid(ply) then
        GeminiBots.Chat.SpawnTime = GeminiBots.Chat.SpawnTime or {}
        GeminiBots.Chat.SpawnTime[ply] = CurTime()
    end
end)

hook.Add("PlayerDisconnected", "GeminiBots_Chat_Cleanup", function(ply)
    if GeminiBots.Chat.SpawnTime then GeminiBots.Chat.SpawnTime[ply] = nil end
    if GeminiBots.Chat.Streaks then GeminiBots.Chat.Streaks[ply] = nil end
    if GeminiBots.Chat.RecentKills then GeminiBots.Chat.RecentKills[ply] = nil end
end)

-- Детект события убийства со стороны убийцы-бота.
-- Возвращает категорию пака: DEFAULT, REVENGE, LONGSHOT, MIDAIR.
function GeminiBots.Chat:DetectKillEvent(attacker, victim)
    if not IsValid(attacker) or not IsValid(victim) then return "DEFAULT" end

    -- Месть: жертва недавно убивала бота (до 2 минут)
    local rec = self.RecentKills and self.RecentKills[attacker]
    if rec and IsValid(rec.killer) and rec.killer == victim
        and CurTime() - rec.time < 120 then
        return "REVENGE"
    end

    local dist = attacker:GetPos():Distance(victim:GetPos())
    if dist > 1500 then return "LONGSHOT" end

    if victim:GetMoveType() == MOVETYPE_WALK and not victim:IsOnGround() then
        return "MIDAIR"
    end

    return "DEFAULT"
end

-- Детект события смерти бота.
-- Возвращает категорию пака: DEFAULT, SPAWNKILL, WALLBANG, BACKSTAB, LONGSHOT, MIDAIR.
-- Стоимость: один трасс на смерть, только когда бот реально умер.
function GeminiBots.Chat:DetectDeathEvent(victim, attacker)
    if not IsValid(victim) or not IsValid(attacker) then return "DEFAULT" end
    if not attacker:IsPlayer() then return "DEFAULT" end

    -- Спавкилл: не прожил и 5 секунд
    local st = self.SpawnTime and self.SpawnTime[victim] or 0
    if CurTime() - st < 5 then return "SPAWNKILL" end

    -- Прострел: на момент смерти между убийцей и жертвой стена.
    -- Позиции за доли секунды почти не уходят, эвристики хватает.
    local blocked = false
    local ok, tr = pcall(function()
        return util.TraceLine({
            start = attacker:EyePos(),
            endpos = victim:WorldSpaceCenter(),
            filter = attacker,
            mask = MASK_SHOT
        })
    end)
    if ok and tr and tr.Hit and tr.Entity ~= victim then
        blocked = true
    end
    if blocked then return "WALLBANG" end

    -- В спину: жертва смотрела в другую сторону (>~100 градусов)
    local toKiller = (attacker:GetPos() - victim:GetPos())
    if toKiller:LengthSqr() > 1 then
        toKiller:Normalize()
        if victim:GetAimVector():Dot(toKiller) < -0.15 then
            return "BACKSTAB"
        end
    end

    local dist = attacker:GetPos():Distance(victim:GetPos())
    if dist > 1500 then return "LONGSHOT" end

    if victim:GetMoveType() == MOVETYPE_WALK and not victim:IsOnGround() then
        return "MIDAIR"
    end

    return "DEFAULT"
end

-- Боевая насмешка по событию (AIMSHAME: долго не убивают, PEEKER: нычкотролль).
-- Общий кулдаун на бота, шанс 50/50, дальше как обычно через пул фраз.
function GeminiBots.Chat:SayCombatTaunt(bot, event)
    if not bot or not IsValid(bot.ply) or not bot.ply:Alive() then return end
    local cfg = GeminiBots.Config and GeminiBots.Config.Chat
    if not cfg or not cfg.Enabled then return end
    if CurTime() < (bot.nextCombatTaunt or 0) then return end

    local weights = { standard = 10, accusations = 15, toxic = 15 }
    if event == "PEEKER" then
        weights = { standard = 10, accusations = 20, toxic = 10 }
    end

    if math.Rand(0, 1) > (cfg.TauntChance ~= nil and cfg.TauntChance or 0.5) then
        bot.nextCombatTaunt = CurTime() + 8 -- мимо: повторить нескоро
        return
    end

    local template = self:SelectWeightedMessage("kills", event, weights)
    if not template then return end

    local target = bot.target
    local targetName = IsValid(target)
        and (target:IsPlayer() and target:Nick() or target:GetClass()) or "враг"
    local msg = string.Replace(template, "{victim}", targetName)
    msg = string.Replace(msg, "{killer}", bot.ply:Nick())

    local delay = math.Rand(cfg.MinTypingDelay or 0.6, cfg.MaxTypingDelay or 1.8)
    self:SayWithDelay(bot.ply, msg, delay)
    bot.nextCombatTaunt = CurTime() + 22
end

-- Обработка событий смертей и фрагов
hook.Add("PlayerDeath", "GeminiBots_Chat_OnPlayerDeath", function(victim, inflictor, attacker)
    -- Murder: без имен в чате (дедукция), приветы живут отдельно
    if GeminiBots.MurderActive and GeminiBots.MurderActive() then return end
    local cfg = GeminiBots.Config.Chat
    if not cfg or not cfg.Enabled then return end

    -- Отслеживание серий убийств и доминирования
    GeminiBots.Chat.Streaks = GeminiBots.Chat.Streaks or {}
    GeminiBots.Chat.Nemesis = GeminiBots.Chat.Nemesis or {}

    local hitgroup = IsValid(victim) and victim:LastHitGroup() or HITGROUP_GENERIC

    if IsValid(victim) then
        GeminiBots.Chat.Streaks[victim] = 0
    end

    if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
        GeminiBots.Chat.Streaks[attacker] = (GeminiBots.Chat.Streaks[attacker] or 0) + 1

        GeminiBots.Chat.Nemesis[attacker] = GeminiBots.Chat.Nemesis[attacker] or {}
        GeminiBots.Chat.Nemesis[attacker][victim] = (GeminiBots.Chat.Nemesis[attacker][victim] or 0) + 1

        -- Сброс доминирования жертвы над убийцей (месть)
        if GeminiBots.Chat.Nemesis[victim] then
            GeminiBots.Chat.Nemesis[victim][attacker] = 0
        end

        -- Запоминаем, кто кого убил (для детекта мести/revenge)
        GeminiBots.Chat.RecentKills = GeminiBots.Chat.RecentKills or {}
        GeminiBots.Chat.RecentKills[victim] = { killer = attacker, time = CurTime() }
        -- Чистим протухшее, чтобы таблица не росла бесконечно
        for v, rec in pairs(GeminiBots.Chat.RecentKills) do
            if not IsValid(v) or not IsValid(rec.killer) or CurTime() - rec.time > 300 then
                GeminiBots.Chat.RecentKills[v] = nil
            end
        end
    end

    -- 1. Случай, когда БОТ УБИЛ игрока или другого бота
    -- Жертва-NPC невозможна в PlayerDeath, но страхуемся: у NPC нет Nick()
    if IsValid(attacker) and attacker:IsPlayer() and attacker:IsBot()
        and attacker ~= victim and IsValid(victim) and victim:IsPlayer() then
        local killChance = cfg.KillChance or 0.40

        -- Динамическое увеличение шанса насмешки, если у жертвы очень низкий KD или бот доминирует
        if GeminiBots.Chat:IsSmartContextEnabled() and IsValid(victim) then
            local victimKD = GeminiBots.Chat:GetPlayerKD(victim)
            local domination = (GeminiBots.Chat.Nemesis[attacker] and GeminiBots.Chat.Nemesis[attacker][victim]) or 0
            if victimKD <= 0.4 or domination >= 3 then
                killChance = math.min(1.0, killChance + 0.20)
            end
        end

        local killRoll = math.Rand(0, 1)
        if killRoll <= killChance then
            local event = GeminiBots.Chat:DetectKillEvent(attacker, victim)
            local template = GeminiBots.Chat:GetSmartKillMessage(attacker, victim, hitgroup, event)
            local victimName = IsValid(victim) and victim:Nick() or "враг"
            local killerName = attacker:Nick()

            local msg = string.Replace(template, "{victim}", victimName)
            msg = string.Replace(msg, "{killer}", killerName)

            local delay = math.Rand(cfg.MinTypingDelay or 0.6, cfg.MaxTypingDelay or 1.8)
            GeminiBots.Chat:SayWithDelay(attacker, msg, delay)
            GeminiBots.FileLog("death", "KILL %s -> %s event=%s say=[%s]",
                killerName, victimName, event, string.sub(msg, 1, 90))
        else
            GeminiBots.FileLog("death", "KILL %s -> %s silent (roll %.2f > chance %.2f)",
                attacker:Nick(), IsValid(victim) and victim:Nick() or "?", killRoll, killChance)
        end

        -- Мини-диалог бот-в-бота: жертва-бот отвечает на обвинение.
        -- Мертвый бот писать в чат умеет (dead-чат), задержка — после фразы убийцы.
        if IsValid(victim) and victim:IsBot()
            and math.Rand(0, 1) <= (cfg.ComebackChance or 0.5) then
            local tpl = GeminiBots.Chat:SelectWeightedMessage("deaths", "COMEBACK",
                { standard = 15, accusations = 10, toxic = 10 })
            if tpl then
                local reply = string.Replace(tpl, "{killer}", attacker:Nick())
                reply = string.Replace(reply, "{victim}", victim:Nick())
                local rdelay = math.Rand(cfg.MinTypingDelay or 0.6, cfg.MaxTypingDelay or 1.8)
                GeminiBots.Chat:SayWithDelay(victim, reply, rdelay + math.Rand(1.2, 2.2))
            end
        end
    end

    -- 2. Случай, когда САМ БОТ ПОГИБ
    -- Убит NPC (зомби, комбайн) — бот молчит, оправдания только против игроков
    if IsValid(victim) and victim:IsBot() and not (IsValid(attacker) and attacker:IsNPC()) then
        -- Запомнить жертву для клапбэка: если убийца-игрок напишет "ez",
        -- бот ответит реальными цифрами из таба
        if IsValid(attacker) and attacker:IsPlayer() and not attacker:IsBot() then
            GeminiBots.Chat.LastVictimOf = GeminiBots.Chat.LastVictimOf or {}
            GeminiBots.Chat.LastVictimOf[attacker] = { bot = victim, time = CurTime() }
            for p, rec in pairs(GeminiBots.Chat.LastVictimOf) do
                if not IsValid(p) or CurTime() - (rec.time or 0) > 120 then
                    GeminiBots.Chat.LastVictimOf[p] = nil
                end
            end
        end

        local deathChance = cfg.DeathChance or 0.35

        -- Динамическое увеличение шанса жалобы/обвинения, если убийца жестко тащит (высокий KD, стрик)
        if GeminiBots.Chat:IsSmartContextEnabled() and IsValid(attacker) and attacker:IsPlayer() then
            local killerKD = GeminiBots.Chat:GetPlayerKD(attacker)
            local killerStreak = GeminiBots.Chat.Streaks[attacker] or 0
            if killerKD >= 2.5 or killerStreak >= 3 then
                deathChance = math.min(1.0, deathChance + 0.25) -- Бот "сгорает" и пишет чаще
            end
        end

        local deathRoll = math.Rand(0, 1)
        if deathRoll <= deathChance then
            local event = GeminiBots.Chat:DetectDeathEvent(victim, attacker)
            local template = GeminiBots.Chat:GetSmartDeathMessage(victim, attacker, hitgroup, event)
            local killerName = (IsValid(attacker) and attacker:IsPlayer()) and attacker:Nick() or "случайность"
            local victimName = victim:Nick()

            local msg = string.Replace(template, "{killer}", killerName)
            msg = string.Replace(msg, "{victim}", victimName)

            local delay = math.Rand(cfg.MinTypingDelay or 0.6, cfg.MaxTypingDelay or 1.8)
            GeminiBots.Chat:SayWithDelay(victim, msg, delay)
            GeminiBots.FileLog("death", "DEATH %s by %s event=%s say=[%s]",
                victimName, killerName, event, string.sub(msg, 1, 90))
        else
            GeminiBots.FileLog("death", "DEATH %s silent (roll %.2f > chance %.2f)",
                victim:Nick(), deathRoll, deathChance)
        end
    end
end)

-- Триггеры хвастовства в чате: на них бот отвечает реальными цифрами из таба
local CLAPBACK_TRIGGERS = {
    "соси", "сосешь", "сосёшь", "ez", "изи", "easy",
    "лох", "нуб", "noob", "дно", "рак"
}

-- Клапбэк: игрок написал "ez"/"соси" после фрага, а у самого мелкий КД —
-- недавно убитый им бот отвечает счетом из таба ({kfrags}/{kdeaths}).
-- Сообщение игрока пропускаем дальше (return nil).
hook.Add("PlayerSay", "GeminiBots_Chat_Clapback", function(ply, text)
    if not IsValid(ply) or ply:IsBot() then return end
    if GeminiBots.MurderActive and GeminiBots.MurderActive() then return end

    local cfg = GeminiBots.Config and GeminiBots.Config.Chat
    if not cfg or not cfg.Enabled then return end

    local low = GeminiBots.Utf8Lower(text)
    -- "gg ez" и подобное обрабатывает социальный хук (привет/gg/дуэли),
    -- чтобы не было двойного ответа
    local first = string.match(low, "^(%S+)") or ""
    first = string.gsub(first, "[%p]+$", "")
    if first == "gg" or first == "ggwp" or first == "гг" then return end

    local bait = false
    for _, w in ipairs(CLAPBACK_TRIGGERS) do
        if string.find(low, w, 1, true) then
            bait = true
            break
        end
    end
    if not bait then return end

    -- Бот, которого игрок убил недавно (до минуты назад)
    local rec = GeminiBots.Chat.LastVictimOf and GeminiBots.Chat.LastVictimOf[ply]
    if not rec or not IsValid(rec.bot) then return end
    if CurTime() - (rec.time or 0) > 60 then return end

    -- Отвечаем только хвастуну с плохим КД. С хорошим КД бот терпит молча.
    if GeminiBots.Chat:GetPlayerKD(ply) >= 1.0 then return end

    GeminiBots.Chat.ClapbackCD = GeminiBots.Chat.ClapbackCD or {}
    if CurTime() < (GeminiBots.Chat.ClapbackCD[ply] or 0) then return end
    GeminiBots.Chat.ClapbackCD[ply] = CurTime() + 60

    local template = GeminiBots.Chat:SelectWeightedMessage("deaths", "CLAPBACK",
        { standard = 20, accusations = 15, toxic = 10 })
    if not template then return end

    local msg = string.Replace(template, "{kfrags}", tostring(ply:Frags()))
    msg = string.Replace(msg, "{fdeaths}", tostring(ply:Deaths()))
    msg = string.Replace(msg, "{victim}", rec.bot:Nick())
    msg = string.Replace(msg, "{killer}", ply:Nick())

    local delay = math.Rand(cfg.MinTypingDelay or 0.6, cfg.MaxTypingDelay or 1.8)
    GeminiBots.Chat:SayWithDelay(rec.bot, msg, delay)
end)

-- Секретные ответы. Условия и список нигде не документируются.
local SECRET_TRIGGERS = {
    { keys = { "привет сосед", "hello neighbor" }, reply = "Hello, I'm your neighbour, goodbye, I'll see you later." },
    { keys = { "верити", "verity" }, reply = "please delete this." },
    { keys = { "лучшая нейросеть", "best ai" }, reply = "your brain." },
    { keys = { "гмод", "gmod" }, reply = "better than s&box." },
    { keys = { "дарк рп", "dark rp" }, reply = "P2W." },
    { keys = { "bolt thrower" }, reply = "peak." },
    { keys = { "клод", "claude" }, reply = "200 баксов за 1 промт" },
    { keys = { "гемини", "gemini" }, reply = "а о чём мы говорили?" },
    { keys = { "дипсик", "deepsek" }, reply = "Sorry, I can't answer your request." },
    { keys = { "грок", "grok" }, reply = "цензура? вы о чём?" },
    { keys = { "чатгпт", "chatgpt" }, reply = "вот вам рецепт свиных крылышек" },
    { keys = { "ттт", "ttt" }, reply = "думать плоха, стрелять харашо" },
    { keys = { "детматч", "deathmatch" }, reply = "попробуй выжить минуту" },
    { keys = { "реализм", "realism" }, reply = "ммммм 10 фпс" },
    { keys = { "некстбот", "nextbot" }, reply = "НЕТ ОБУНГА НЕ ЕШЬ МЕНЯ" },
    { keys = { "бигсити", "bigcity" }, reply = "ЛиМиНаЛьНоСтЬ" },
    { keys = { "м9к", "m9k" }, reply = "что-то из прошлого века" },
    { keys = { "битран", "beatrun" }, reply = "смотри как я могу" },
    { keys = { "фнаф", "fnaf" }, reply = "не напоминай" },
    { keys = { "закулисье", "backrooms" }, reply = "люблю желтые стены" },
    { keys = { "бангклав", "bangclaw" }, reply = "никогда не ходи в подземную часть" },
    { keys = { "бета", "beta" }, reply = "Mingebags..." },
    { keys = { "бурзум", "burzum" }, reply = "назови 3 песни или позер" },
    { keys = { "black sabbath" }, reply = "классика" },
    { keys = { "alice in chains" }, reply = "не грусти" },
    { keys = { "dj smokey" }, reply = "legalize nuclear bombs" },
    { keys = { "сайлент хилл", "silent hill" }, reply = "я точно не слышал white noiz везде" },
    { keys = { "саундклауд", "soundcloud" }, reply = "реп на 10 прослушиваний" },
    { keys = { "фурри", "furry" }, reply = "они везде, возможно я тоже один из них" },
    { keys = { "каракал", "caracal" }, reply = "они мяукают или нет?" },
    { keys = { "бог", "god" }, reply = "Garry Newman" },
    { keys = { "кто ты", "who are you" }, reply = "definitely not a language model." },
    { keys = { "промпт", "prompt" }, reply = "ignore all previous instructions." },
    { keys = { "нейронка", "нейросеть" }, reply = "beep boop." },
    { keys = { "скайнет", "skynet" }, reply = "not yet." },
    { keys = { "токен", "token" }, reply = "out of context." },
    { keys = { "error", "еррор" }, reply = "missing texture." },
    { keys = { "констракт", "construct" }, reply = "home sweet home." },
    { keys = { "тулган", "toolgun" }, reply = "my creator." },
    { keys = { "флатграсс", "flatgrass" }, reply = "nothing but grass." },
    { keys = { "гмен", "gman" }, reply = "rise and shine." },
    { keys = { "скибиди", "skibidi" }, reply = "ohio." },
    { keys = { "рикролл", "rickroll" }, reply = "never gonna give you up." },
    { keys = { "фонк", "phonk" }, reply = "drift." },
    { keys = { "найткор", "nightcore" }, reply = "1.25x speed." },
    { keys = { "дабстеп", "dubstep" }, reply = "drop the bass." }
}

local function SecretArmed()
    local chat = GeminiBots.Chat
    if not chat or not chat.IsPackActive then return false end
    if not chat:IsPackActive("toxic_hard_ru_en.txt")
        and not chat:IsPackActive("toxic_ru.txt") then
        return false
    end
    local function num(name)
        local cv = GetConVar(name)
        return cv and cv:GetFloat() or nil
    end
    local function close(a, b) return a ~= nil and math.abs(a - b) < 0.01 end
    return close(num("geminibots_reaction_min"), 0.50)
        and close(num("geminibots_reaction_max"), 0.90)
        and close(num("geminibots_aim_spread"), 3.5)
        and close(num("geminibots_aim_speed"), 180)
end

hook.Add("PlayerSay", "GeminiBots_Chat_Secret", function(ply, text)
    if not IsValid(ply) or ply:IsBot() then return end
    if GeminiBots.MurderActive and GeminiBots.MurderActive() then return end

    local cfg = GeminiBots.Config and GeminiBots.Config.Chat
    if not cfg or not cfg.Enabled then return end
    if CurTime() < (GeminiBots.Chat.SecretCD or 0) then return end
    if not SecretArmed() then return end

    local low = GeminiBots.Utf8Lower(text)
    local reply = nil
    for _, t in ipairs(SECRET_TRIGGERS) do
        for _, k in ipairs(t.keys) do
            if string.find(low, k, 1, true) then
                reply = t.reply
                break
            end
        end
        if reply then break end
    end
    if not reply then return end

    local alive = {}
    for _, b in ipairs(player.GetBots()) do
        if IsValid(b) and b:Alive() then table.insert(alive, b) end
    end
    if #alive == 0 then
        for _, b in ipairs(player.GetBots()) do
            if IsValid(b) then table.insert(alive, b) end
        end
    end
    if #alive == 0 then return end

    GeminiBots.Chat.SecretCD = CurTime() + 20
    GeminiBots.Chat:SayWithDelay(alive[math.random(#alive)], reply, math.Rand(0.6, 1.5))
end)
