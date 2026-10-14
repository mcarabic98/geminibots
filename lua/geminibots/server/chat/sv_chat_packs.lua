--[[
    GeminiBots - Chat Packs Manager
    Загрузка фраз ботов из отдельных .txt файлов в папке garrysmod/data/geminibots/chat/
    Поддержка нескольких файлов, их включение/отключение и синхронизация с Q-меню.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Chat = GeminiBots.Chat or {}
GeminiBots.Chat.Packs = GeminiBots.Chat.Packs or {}
GeminiBots.Chat.ActivePacks = GeminiBots.Chat.ActivePacks or {}

local DATA_DIR = "geminibots/chat"
local CONFIG_FILE = "geminibots/active_packs.json"

util.AddNetworkString("GeminiBots_RequestChatPacks")
util.AddNetworkString("GeminiBots_ReceiveChatPacks")
util.AddNetworkString("GeminiBots_ToggleChatPack")

-- Стандартные паки, генерируемые при первом запуске.
-- Легаси-паки (default_ru/toxic_ru/default_en) убраны: их заменяют билингвы.
-- Удаленные через pack_delete паки сюда не возвращаются (черный список).
local DEFAULT_PACKS = {
    ["toxic_hard_ru_en.txt"] = [[# GeminiBots - ЖЕСТКИЙ токсичный пак (RU / EN, 18+)
# Маты, грязь, капс в стиле школоло-рейджа. Выключен по умолчанию: включается
# галкой в Q-меню или командой geminibots_chat_pack_toggle toxic_hard_ru_en.txt
# Формат обычный: [KILL:*] — {victim}, [DEATH:*] — {killer},
# [DEATH:CLAPBACK] — еще {kfrags}/{fdeaths} (цифры хвастуна из таба)

[KILL:DEFAULT]
ЕБАТЬ ТЫ ДНО, {victim}
НАХУЙ С СЕРВЕРА, ХУЕСОС
ТЕБЯ ДАЖЕ БОТ ВЫЕБАЛ, {victim}
УДАЛЯЙ ИГРУ, ДОЛБОЁБ
ПИЗДЕЦ ТЫ МУСОР, {victim}
ЛЕЖАТЬ, СУКА
СИДИ, СУКА, НЕ ВЫСОВЫВАЙСЯ
МИНУС МУСОР
СОСИ ХУЙ, {victim}
ИДИ НАХУЙ, {victim}
GET FUCKED, {victim}
SIT DOWN, BITCH
TRASH KID {victim}, UNINSTALL
EAT SHIT AND DIE, {victim}
DUMBASS {victim}, STAY DOWN
MOTHERFUCKER {victim}, TOO EASY

[DEATH:DEFAULT]
ЕБАНЫЙ ЧИТЕР, {killer}
СУКА С ЧИТАМИ, {killer}
ПОШЕЛ НАХУЙ, {killer}
ПИЗДЕЦ, ЛАКЕР {killer}
ХУЙНЯ, А НЕ ИГРА
ДА Я СРАЛ НА ЭТОТ РАУНД
САСИ ХУЙ, {killer}
FUCK OFF, {killer}
LUCKY BITCH {killer}
BULLSHIT ROUND, {killer}
EAT MY SHIT, {killer}
OUTPLAYED MY ASS, {killer}

[KILL:REVENGE]
НА, СУКА, ПОЛУЧИ, {victim}
ДОЛЖОК, МРАЗЬ, {victim}
REVENGE, BITCH {victim}

[KILL:AIMSHAME]
СТРЕЛЯЕШЬ КАК СЛЕПОЙ ХУЕСОС, {victim}
ЦЕЛЬСЯ, ХУЛИ, {victim}
BLIND MOTHERFUCKER {victim}

[KILL:PEEKER]
ВЫЛЕЗАЙ, СУКА
ХВАТИТ ЖАТЬСЯ ПО УГЛАМ, {victim}
STOP HIDING, BITCH {victim}

[DEATH:WALLBANG]
СЫН БЛЯДИ С ЧИТАМИ, {killer}
ЕБАТЬ ТЫ ЧЕРЕЗ СТЕНЫ ХУЯРИШЬ, {killer}
ВХ ЕБАНОЕ ВЫРУБИ, {killer}
WALLHACKING FUCKER {killer}

[DEATH:BACKSTAB]
В СПИНУ, СУКА? {killer}
СЫКЛО ЕБАНОЕ, {killer}
BACKSTABBING BITCH {killer}

[DEATH:SPAWNKILL]
ТОЛЬКО ВЫШЕЛ, УЕБОК {killer}?
САСИ НА СПАВНЕ, {killer}
SPAWNKILLING FUCKER {killer}

[DEATH:COMEBACK]
САМ ХУЙНЯ БЕЗРУКАЯ, {killer}
ЕБАЛО ЗАКРОЙ, {killer}
CRY, BITCH {killer}

[DEATH:CLAPBACK]
ТЫ {kfrags} НА {fdeaths} ДЕЛАЕШЬ, ЕБАЛО ЗАКРОЙ
САМ СОСЁШЬ, {fdeaths} РАЗ УМЕР
{kfrags}/{fdeaths}, SHUT THE FUCK UP

[CHAT:GREETING_TOXIC]
ты кто ваще
чо надо
иди отсюда
who are you even
чо приперся

[CHAT:DUEL_TOXIC]
погнали на {duel}, отсосешь
го на {duel}, посмотрим на тебя

[CHAT:DUEL_NAG_TOXIC]
мы на {duel} договаривались, мудила
убери ствол, сука, мы на {duel}
хули с другим стволом, мы на {duel}
]],

    ["standard_ru_en.txt"] = [[# GeminiBots - Standard Chat Pack (Bilingual RU / EN)
# Обычные фразы для перестрелок без лишней токсичности.
# Новый формат: [KILL:DEFAULT], [DEATH:BACKSTAB], [DEATH:LONGSHOT] и т.д.

[KILL:DEFAULT]
# --- Русский (20 фрагов) ---
хорошая попытка, {victim}
минус, играем дальше
почти получилось, {victim}
не стой на открытом месте, {victim}
чистый выстрел
аккуратнее в следующий раз
отличный раунд, {victim}
дефолтный фраг, продолжаем
перезаряжаюсь, минус один
было близко, {victim}
главное не сдаваться, {victim}
отдохни немного
не заметил меня?
gg, {victim}
в следующий раз повезет
проверяй углы, {victim}
четко в цель
нормальная перестрелка была
держи дистанцию, {victim}
плюс фраг в копилку

# --- English (20 kills) ---
good try, {victim}
nice attempt, {victim}
got one, moving on
almost had me, {victim}
clean shot
watch your corners, {victim}
well played, {victim}
one down, reloading
good fight, {victim}
that was close, {victim}
gg wp, {victim}
keep practicing, {victim}
caught you off guard
better luck next time, {victim}
gotcha, {victim}
solid duel
watch out next round
target down
nice movement though, {victim}
fair fight

[DEATH:DEFAULT]
# --- Русский (16 смертей) ---
отличный выстрел, {killer}
не успел среагировать
красиво снял, {killer}
перезарядка подвела
хорош, {killer}
ладно, в следующий раз заберу
блин, патроны кончились
бывает, респавнюсь
хорошая реакция, {killer}
надо было стрейфить лучше
ай, почти же снял тебя
один на один в следующий раз
эх, не дожал
сейчас вернусь в строй
заслуженный фраг, {killer}
ладно, 1:0 в твою пользу

# --- English (17 deaths) ---
nice shot, {killer}
good aim, {killer}
well played, {killer}
ran out of ammo...
caught me reloading
good fight, {killer}
almost had you
fair kill, {killer}
gg, nice reflex
respawning now
1-0 for you, {killer}
you got me fair and square
oof, clean headshot
my mistake, rushed too fast
well timed, {killer}
solid hit
see you in a second, {killer}

[DEATH:BACKSTAB]
# Убили в спину / обошли
нормально ты меня подловил, {killer}
не ожидал тебя там увидеть
грамотно обошел, {killer}
nice flank, {killer}
didn't see you there, {killer}

[DEATH:LONGSHOT]
# Сняли издалека
откуда прилетело?
where did that come from?
]],

    ["accuses_ru_en.txt"] = [[# GeminiBots - Accusations & Excuses Chat Pack (Bilingual RU / EN)
# Тематика: обвинения в читах, нытье на пинг, тикрейт, хитбоксы, крысятничество и незнание карты.
# Новый формат: [KILL:DEFAULT], [DEATH:WALLBANG], [DEATH:BACKSTAB] и т.д.

[KILL:DEFAULT]
# --- Русский (20 фрагов: насмешки над оправданиями, пингом и кемперством жертвы) ---
карту подучи сначала, {victim}
на пинг свой посмотри, {victim}, телепортируешься же
в стену стрелял что ли, {victim}?
опять в углу сидел, {victim}? не помогло
скажи еще, что хитбокс кривой, {victim}
удали свои бесплатные читы, {victim}, даже они не спасают
ты спиной вперед бегаешь, {victim}?
научись гранаты кидать, сам себе под ноги бросил
на монитор нажми, {victim}, он выключен
радар включи, {victim}, я прямо перед тобой стоял
скажи еще, что мышка дернулась, {victim}
с таким пингом в соло играть надо, {victim}
наушники купи, шаги за километр слышно
не стой на чужом спавне, если карты не знаешь
кастомный прицел не помог тебе, {victim}
оправдания в студию, {victim}
типичный кемпер, даже кемпить не умеешь
сенсу понизь, {victim}, в потолок целишься
проверил углы? а спину кто проверять будет?
щас опять напишешь, что фпс просел, {victim}

# --- English (20 kills: mocking excuses, lag and bad map knowledge) ---
learn the map first, {victim}
check your ping, {victim}, you were teleporting
shooting at the floor again, {victim}?
corner camping won't save you, {victim}
go ahead, blame the hitboxes, {victim}
uninstall those free cheats, {victim}, they didn't help
turn your monitor on, {victim}
buy some headphones, heard you from miles away
check your radar next time, {victim}
blame your mouse sensitivity, {victim}
stop crying about tickrate, {victim}
your excuses are getting old, {victim}
don't rush corners if you don't know the map
wifi gaming at its finest, {victim}
you literally ran into my crosshair, {victim}
waiting for the 'my fps dropped' excuse, {victim}
crosshair placement: floor, {victim}
nice camping spot, too bad everyone knows it
spectate and learn how to move, {victim}
blame the server next, {victim}

[DEATH:DEFAULT]
# --- Русский (14 смертей: общие обвинения и нытье) ---
бан тебе, {killer}, чисто по костям ведешь
пинг 500 у {killer}, по нему урон вообще не регает!
аимбот выключи, {killer}, прицел трясется
ты из этой щели хоть раз за раунд вылезал, {killer}?
куда ты стрелял? пули боком полетели, {killer}
крыса на споте, весь раунд в текстурах сидит
у меня фпс до 10 упал, лакер ты, {killer}
ты по пингу преимущество имеешь, интерполяцию подкрутил?
читер на сервере, админы, забаньте {killer}!
зажим в молоко, одна пулька рандомно в лоб зашла
пикерс адвантадж у {killer}, я даже на экран его не получил
мышку купи нормальную, а не софт с автонаводкой, {killer}
сервер лагает, я три обоймы в {killer} всадил!
готовься к проверке на софт, {killer}

# --- English (13 deaths: generic hack/netcode blame) ---
nice aimbot, {killer}, report submitted
your 300 ping makes you immortal, {killer}
turn off your toggle, {killer}, shaking crosshair
camping rat spot, {killer}, try moving once
peekers advantage abuser, {killer}
massive ping spike, no hitreg on {killer}
who sits in that corner for 5 minutes, {killer}?
banned incoming, enjoy your VAC, {killer}
trash tickrate, none of my shots registered on {killer}
wifi warrior advantage, fix your internet {killer}
nice triggerbot, fired the exact millisecond I peeked
admin check {killer}'s steam profile please
got lucky with a ricochet headshot, {killer}

[DEATH:WALLBANG]
# Убили сквозь стену / префаером
через стену префаером? админа позвать, {killer}?
хитбокс сломан, я уже за углом был, {killer}!
silent aim спалился, {killer}, демку пишу
wh выруби, {killer}, на shift бежал и ты сразу вышел
случайный прострел вслепую, 0 скилла у {killer}
blatant wallhack, {killer}, pre-aiming through walls
silent aim detected, recording demo for {killer}
random spray and pray headshot, zero skill {killer}
cheap wallbang, you definitely have ESP, {killer}
I was shift walking, how did you know I was there, {killer}?
broken hitboxes! I was already behind cover, {killer}!

[DEATH:BACKSTAB]
# Убили в спину
в спину с инвиза снял, в лоб выйти побоялся?
only can kill from behind, face me 1v1 {killer}
]]
,
    ["events_ru_en.txt"] = [[# GeminiBots - Event Chat Pack (Bilingual RU / EN)
# Новый формат: категории событий вместо общих [KILLS]/[DEATHS].
# [KILL:REVENGE/LONGSHOT/MIDAIR], [DEATH:WALLBANG/BACKSTAB/SPAWNKILL/LONGSHOT/MIDAIR]
# Свои категории добавляются так же: [DEATH:МОЯ_КАТЕГОРИЯ] + детект в коде.
# Старый формат ([KILLS]/[DEATHS]) продолжает работать как DEFAULT.

[KILL:REVENGE]
1:1, {victim}, квиты
должок вернул, {victim}
отомстил, {victim}
1:1, payback {victim}
revenge served, {victim}

[KILL:LONGSHOT]
снял через полкарты, {victim}
с такого расстояния еще попади, {victim}
cross-map delete, {victim}
too far to hide, {victim}

[KILL:MIDAIR]
сбил в полете, {victim}
вертуху поймал, {victim}
airshot, {victim}
stay grounded, {victim}

[DEATH:WALLBANG]
сквозь стену? серьезно, {killer}?
префаер сквозь текстуры, {killer}
wallbang through concrete, {killer}?
даже стекло не спасает от {killer}
shooting through walls now, {killer}?

[DEATH:BACKSTAB]
только в спину и можешь, {killer}
в лоб слабо выйти, {killer}?
only from behind, {killer}?
face me 1v1, {killer}

[DEATH:SPAWNKILL]
только зареспавнился, {killer}!
со спавна снимаешь, {killer}?
spawnkilling already, {killer}?
дай хоть из спавна выйти, {killer}

[DEATH:LONGSHOT]
через всю карту попал, {killer}?
кемперишь с другого конца, {killer}?
camping across the map, {killer}?
nice angle, {killer}

[DEATH:MIDAIR]
в полете снял, {killer}?
красиво, {killer}, признаю
fine, that airshot was clean, {killer}

[KILL:AIMSHAME]
да целься нормально, {victim}
ну и аим у тебя, {victim}
по стоячей мишени попасть не можешь, {victim}
стреляешь как из водяного, {victim}
целься лучше, {victim}
my grandmother aims better, {victim}
shooting blanks over there, {victim}?
aim diff, {victim}

[KILL:PEEKER]
крутой геймплей у тебя
давай выходи, {victim}
из нычки вылезай, {victim}
угол-то отпусти, {victim}
вылезай, не укушу, {victim}
peekaboo warrior, {victim}
stop hugging that corner, {victim}
come out, {victim}

[DEATH:COMEBACK]
скилла нет, вот и валишь на читы, {killer}
плачь дальше, {killer}
скилл купи, {killer}
0 аргументов, одни обвинения, {killer}
cry more, {killer}
no skill no proof, {killer}

[DEATH:CLAPBACK]
так ты {kfrags} на {fdeaths} делаешь, чё ez-то
сам сосёшь, {fdeaths} раз умер
{kfrags}/{fdeaths} — вот и всё твое ez
с твоим кд только ez и писать
{kfrags} frags on {fdeaths} deaths, what's so ez?

[CHAT:GREETING]
привет-привет
здарова
о, привет
hello
hey hey
йо, здарова
привет, {victim}
hello there

[CHAT:GG]
спасибо
gg wp
хорошая катка
взаимно
thanks, gg

[CHAT:DUEL]
погнали на {duel}
принято, {duel}
го, только на {duel}
let's go, {duel} only

[CHAT:DUEL_NAG]
так мы на {duel}, убери ствол
договаривались на {duel}
эй, мы на {duel}
не по правилам играешь
we agreed on {duel}
]]
}

local DELETED_FILE = "geminibots/deleted_packs.json"

-- Удаленные навсегда паки (не пересоздавать из кода)
local function LoadDeletedPacks()
    GeminiBots.Chat.DeletedPacks = {}
    if file.Exists(DELETED_FILE, "DATA") then
        local tbl = util.JSONToTable(file.Read(DELETED_FILE, "DATA") or "")
        if istable(tbl) then
            for name, v in pairs(tbl) do
                if v then GeminiBots.Chat.DeletedPacks[name] = true end
            end
        end
    end
end

local function SaveDeletedPacks()
    file.Write(DELETED_FILE, util.TableToJSON(GeminiBots.Chat.DeletedPacks or {}, true))
end

function GeminiBots.Chat:IsPackDeleted(filename)
    return self.DeletedPacks and self.DeletedPacks[filename] == true
end

-- Создание стандартных файлов, если их нет (кроме удаленных навсегда)
local function EnsureDefaultPacks()
    if not file.IsDir("geminibots", "DATA") then
        file.CreateDir("geminibots")
    end
    if not file.IsDir(DATA_DIR, "DATA") then
        file.CreateDir(DATA_DIR)
    end

    for filename, content in pairs(DEFAULT_PACKS) do
        if GeminiBots.Chat:IsPackDeleted(filename) then continue end
        local path = DATA_DIR .. "/" .. filename
        -- Пустой файл (0 байт) сам не чинится и дает пак с 0 фраз навсегда:
        -- перезаписываем встроенным содержимым так же, как отсутствующий.
        local needWrite = not file.Exists(path, "DATA")
        if not needWrite then
            needWrite = (file.Size(path, "DATA") or 0) == 0
        end
        if needWrite then
            file.Write(path, content)
            GeminiBots:Log("Создан стандартный чат-пак: data/%s", path)
        end
    end
end

-- Загрузка сохраненного состояния включенных паков
local function LoadActiveState()
    GeminiBots.Chat.ActivePacks = {}
    if file.Exists(CONFIG_FILE, "DATA") then
        local raw = file.Read(CONFIG_FILE, "DATA")
        local tbl = util.JSONToTable(raw or "")
        if istable(tbl) then
            GeminiBots.Chat.ActivePacks = tbl
            return
        end
    end

    -- По умолчанию активны билингвы (легаси default_ru/toxic_ru/default_en убраны из кода)
    GeminiBots.Chat.ActivePacks["standard_ru_en.txt"] = true
    GeminiBots.Chat.ActivePacks["accuses_ru_en.txt"] = true
    GeminiBots.Chat.ActivePacks["events_ru_en.txt"] = true
end

-- Сохранение состояния включенных паков
local function SaveActiveState()
    local json = util.TableToJSON(GeminiBots.Chat.ActivePacks, true)
    file.Write(CONFIG_FILE, json)
end

-- Парсинг одного .txt файла пака.
-- Новый формат (расширяемый): секции [KILL:КАТЕГОРИЯ] и [DEATH:КАТЕГОРИЯ].
-- Категория — любое слово: DEFAULT, WALLBANG, BACKSTAB, SPAWNKILL, LONGSHOT,
-- MIDAIR, REVENGE... Новые категории добавляются просто новой секцией.
-- Старый формат ([KILLS]/[DEATHS]) тоже работает: это то же самое,
-- что [KILL:DEFAULT] / [DEATH:DEFAULT].
local function ParsePackFile(filename)
    local fullPath = DATA_DIR .. "/" .. filename
    local raw = file.Read(fullPath, "DATA")
    if not raw then return nil end

    -- Определение темы по умолчанию по имени файла
    local defaultTheme = "standard"
    local lowerName = string.lower(filename)
    if string.find(lowerName, "accuse") or string.find(lowerName, "excuse") or string.find(lowerName, "cheat") then
        defaultTheme = "accusations"
    elseif string.find(lowerName, "toxic") or string.find(lowerName, "rage") then
        defaultTheme = "toxic"
    end

    local pack = {
        name = filename,
        theme = defaultTheme,
        kills = {},
        deaths = {},
        chat = {}
    }

    local currentKind = nil -- "kills" или "deaths"
    local currentCat = "DEFAULT"
    local lines = string.Explode("\n", raw)

    for _, line in ipairs(lines) do
        -- Убираем переносы \r и пробелы по краям
        line = string.Trim(line)

        -- Проверка указания темы в комментариях (например: # THEME: ACCUSATIONS)
        if string.sub(line, 1, 1) == "#" or string.sub(line, 1, 2) == "--" or string.sub(line, 1, 2) == "//" then
            local themeTag = string.match(string.lower(line), "theme%s*:%s*([%a%-_]+)")
            if themeTag then
                pack.theme = string.lower(themeTag)
            end
            continue
        end

        if line == "" then continue end

        local upper = string.upper(line)

        -- Новый формат: [KILL:КАТЕГОРИЯ] / [DEATH:КАТЕГОРИЯ] / [CHAT:КАТЕГОРИЯ]
        -- (CHAT — триггеры из живого чата: приветствия, дуэли)
        -- ВАЖНО: в Lua-паттернах НЕТ альтернации через |, поэтому слово
        -- kind забираем общим (%a+), а KILL/DEATH/CHAT проверяем сравнением.
        local kindWord, catWord = string.match(upper, "^%[%s*(%a+)%s*:%s*([%w_]+)%s*%]$")
        if (kindWord == "KILL" or kindWord == "DEATH" or kindWord == "CHAT") and catWord then
            if kindWord == "KILL" then
                currentKind = "kills"
            elseif kindWord == "DEATH" then
                currentKind = "deaths"
            else
                currentKind = "chat"
            end
            currentCat = catWord
            pack[currentKind][currentCat] = pack[currentKind][currentCat] or {}
            continue
        end

        -- Старый формат: [KILLS]/[DEATHS] = категория DEFAULT
        if upper == "[KILLS]" or upper == "[KILL]" then
            currentKind, currentCat = "kills", "DEFAULT"
            if not pack.kills.DEFAULT then pack.kills.DEFAULT = {} end
            continue
        elseif upper == "[DEATHS]" or upper == "[DEATH]" then
            currentKind, currentCat = "deaths", "DEFAULT"
            if not pack.deaths.DEFAULT then pack.deaths.DEFAULT = {} end
            continue
        end

        -- Добавление фразы в текущую секцию (kills/deaths/chat)
        if currentKind == "kills" or currentKind == "deaths" or currentKind == "chat" then
            pack[currentKind][currentCat] = pack[currentKind][currentCat] or {}
            table.insert(pack[currentKind][currentCat], line)
        end
    end

    return pack
end

-- Подсчет фраз и категорий в паке (для логов и списка)
local function CountPack(pack)
    local kills, deaths, chat, cats = 0, 0, 0, {}
    for cat, list in pairs(pack.kills or {}) do
        kills = kills + #list
        cats["KILL:" .. cat] = true
    end
    for cat, list in pairs(pack.deaths or {}) do
        deaths = deaths + #list
        cats["DEATH:" .. cat] = true
    end
    for cat, list in pairs(pack.chat or {}) do
        chat = chat + #list
        cats["CHAT:" .. cat] = true
    end
    local catNames = {}
    for name, _ in pairs(cats) do table.insert(catNames, name) end
    table.sort(catNames)
    return kills, deaths, catNames, chat
end

-- Полная перезагрузка всех текстовых паков из папки
function GeminiBots.Chat:ReloadPacks()
    LoadDeletedPacks()
    EnsureDefaultPacks()
    LoadActiveState()

    self.Packs = {}
    local files, _ = file.Find(DATA_DIR .. "/*.txt", "DATA")

    for _, f in ipairs(files) do
        local pack = ParsePackFile(f)
        if pack then
            self.Packs[f] = pack
            local nk, nd = CountPack(pack)
            local fsize = file.Size(DATA_DIR .. "/" .. f, "DATA") or -1
            local active = self:IsPackActive(f) and "ON" or "OFF"
            if nk == 0 and nd == 0 then
                GeminiBots:Warn("Чат-пак %s пуст (0 фраз): файл data/%s/%s пуст или бит. Удалите его и выполните geminibots_chat_reload_packs.", f, DATA_DIR, f)
            end
            GeminiBots:Debug("Загружен чат-пак: %s [Тема: %s] (Фрагов: %d, Смертей: %d)", f, pack.theme, nk, nd)
            GeminiBots.FileLog("packs", "pack=%s size=%d theme=%s active=%s kills=%d deaths=%d",
                f, fsize, pack.theme, active, nk, nd)
        else
            GeminiBots.FileLog("packs", "PARSE FAIL (nil): %s", f)
        end
    end

    GeminiBots.FileLog("packs", "reload done: %d packs, files=%s",
        table.Count(self.Packs), table.concat(files, ","))

    GeminiBots:Log("Всего загружено чат-паков из data/%s: %d", DATA_DIR, table.Count(self.Packs))
end

-- Проверка, включен ли конкретный пак
function GeminiBots.Chat:IsPackActive(filename)
    return self.ActivePacks[filename] == true
end

-- Включение или отключение пака
function GeminiBots.Chat:SetPackActive(filename, active)
    self.ActivePacks[filename] = (active == true)
    SaveActiveState()
    GeminiBots:Log("Чат-пак %s %s", filename, active and "ВКЛЮЧЕН" or "ВЫКЛЮЧЕН")
end

-- Включен ли учет умного контекста (K/D, стрики, хедшоты)
function GeminiBots.Chat:IsSmartContextEnabled()
    local cvar = GetConVar("geminibots_chat_smart_context")
    if cvar then
        return cvar:GetBool()
    end
    local cfg = GeminiBots.Config and GeminiBots.Config.Chat
    return cfg and (cfg.SmartContext ~= false)
end

-- Расчет K/D соотношения игрока
function GeminiBots.Chat:GetPlayerKD(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return 1.0 end
    local frags = math.max(0, ply:Frags())
    local deaths = math.max(1, ply:Deaths())
    return frags / deaths
end

-- Выбор случайной фразы: сначала пул категории события (WALLBANG, ...),
-- если такой нигде нет — фолбэк на DEFAULT. Внутри — рулетка по темам
-- паков (standard, accusations, toxic) с переданными весами.
function GeminiBots.Chat:SelectWeightedMessage(msgType, event, weights)
    event = event or "DEFAULT"
    -- Группировка фраз из активных паков по темам
    local poolsByTheme = {
        standard = {},
        accusations = {},
        toxic = {}
    }

    for name, pack in pairs(self.Packs) do
        if self:IsPackActive(name) then
            local sections = pack[msgType]
            -- Событийные фразы пакета, иначе его же DEFAULT
            local phrases = sections and (sections[event] or sections["DEFAULT"])
            if not phrases then continue end

            local theme = pack.theme or "standard"
            if not poolsByTheme[theme] then
                poolsByTheme[theme] = {}
            end

            for _, phrase in ipairs(phrases) do
                table.insert(poolsByTheme[theme], phrase)
            end
        end
    end

    -- Формируем доступные категории и их суммарные веса
    local totalWeight = 0
    local candidatesThemes = {}

    for theme, list in pairs(poolsByTheme) do
        if #list > 0 then
            local w = math.max(1, weights[theme] or 10)
            totalWeight = totalWeight + w
            table.insert(candidatesThemes, { theme = theme, weight = w, pool = list })
        end
    end

    -- Если нет активных паков с фразами: для чата — тишина (nil),
    -- для убийств/смертей — стандартный случайный фолбэк
    if totalWeight <= 0 or #candidatesThemes == 0 then
        GeminiBots.FileLog("pick", "EMPTY POOLS type=%s event=%s -> fallback (все активные паки пусты!)", msgType, event)
        if msgType == "chat" then return nil end
        return (msgType == "kills") and self:GetRandomKillMessage() or self:GetRandomDeathMessage()
    end

    -- Взвешенный случайный выбор рулеткой
    local rand = math.Rand(0, totalWeight)
    local accumulated = 0

    for _, entry in ipairs(candidatesThemes) do
        accumulated = accumulated + entry.weight
        if rand <= accumulated then
            local phrase = entry.pool[math.random(#entry.pool)]
            GeminiBots.FileLog("pick", "type=%s event=%s theme=%s pool=%d say=[%s]",
                msgType, event, entry.theme, #entry.pool, string.sub(phrase, 1, 90))
            return phrase
        end
    end

    -- Страховочный возврат
    local lastEntry = candidatesThemes[#candidatesThemes]
    return lastEntry.pool[math.random(#lastEntry.pool)]
end

-- Собрать все фразы категории (с фолбэком на DEFAULT) из активных паков
function GeminiBots.Chat:GatherPhrases(msgType, event)
    local out = {}
    for name, pack in pairs(self.Packs) do
        if self:IsPackActive(name) then
            local sections = pack[msgType]
            local phrases = sections and (sections[event] or sections["DEFAULT"])
            if phrases then
                for _, msg in ipairs(phrases) do
                    table.insert(out, msg)
                end
            end
        end
    end
    return out
end

-- Получить случайное сообщение убийства из всех АКТИВНЫХ паков (DEFAULT)
function GeminiBots.Chat:GetRandomKillMessage()
    local candidates = self:GatherPhrases("kills", "DEFAULT")

    if #candidates > 0 then
        return candidates[math.random(#candidates)]
    end

    GeminiBots.FileLog("pick", "FALLBACK builtin KillMessages (активные паки не дали фраз убийства)")
    local fallback = GeminiBots.Config.Chat and GeminiBots.Config.Chat.KillMessages
    if fallback and #fallback > 0 then
        return fallback[math.random(#fallback)]
    end

    return "ez {victim}"
end

-- Получить случайное сообщение смерти из всех АКТИВНЫХ паков (DEFAULT)
function GeminiBots.Chat:GetRandomDeathMessage()
    local candidates = self:GatherPhrases("deaths", "DEFAULT")

    if #candidates > 0 then
        return candidates[math.random(#candidates)]
    end

    GeminiBots.FileLog("pick", "FALLBACK builtin DeathMessages (активные паки не дали фраз смерти)")
    local fallback = GeminiBots.Config.Chat and GeminiBots.Config.Chat.DeathMessages
    if fallback and #fallback > 0 then
        return fallback[math.random(#fallback)]
    end

    return "лакер {killer}"
end

-- Умный выбор фразы при УБИЙСТВЕ жертвы ботом.
-- bot и victim здесь — энтити игроков (исправлено: раньше брался bot.ply,
-- которого у энтити нет, и kill-чат падал с "table index is nil").
function GeminiBots.Chat:GetSmartKillMessage(bot, victim, hitgroup, event)
    if not self:IsSmartContextEnabled() then
        return self:GetRandomKillMessage()
    end
    event = event or "DEFAULT"

    local victimKD = self:GetPlayerKD(victim)
    local victimPing = IsValid(victim) and victim:Ping() or 0
    local domination = (self.Nemesis and self.Nemesis[bot] and self.Nemesis[bot][victim]) or 0

    local weights = {
        standard = 15,
        accusations = 5,
        toxic = 5
    }

    -- Событийные смещения тем (поверх статистики)
    if event == "REVENGE" then
        weights.standard = weights.standard + 20
        weights.toxic = weights.toxic + 10
    elseif event == "LONGSHOT" then
        weights.standard = weights.standard + 25
    elseif event == "MIDAIR" then
        weights.standard = weights.standard + 20
        weights.toxic = weights.toxic + 10
    end

    -- У жертвы низкий K/D (слабая игра) -> резко увеличиваем шанс подколок на тему карты, пинга и кемперства
    -- Порядок важен: сначала строгая проверка (<= 0.3 влечет <= 0.6)
    if victimKD <= 0.3 then
        weights.accusations = weights.accusations + 70
        weights.toxic = weights.toxic + 35
    elseif victimKD <= 0.6 then
        weights.accusations = weights.accusations + 35
        weights.toxic = weights.toxic + 20
    elseif victimKD >= 2.0 then
        -- Жертва сильный игрок -> бот пишет уважительные стандартные фразы
        weights.standard = weights.standard + 40
    end

    -- Жертва лагает
    if victimPing >= 120 then
        weights.accusations = weights.accusations + 35
    end

    -- Бот убивает эту жертву несколько раз подряд
    if domination >= 2 then
        weights.accusations = weights.accusations + 30
        weights.toxic = weights.toxic + 20
    end

    -- Хедшот
    if hitgroup == HITGROUP_HEAD then
        weights.standard = weights.standard + 20
        weights.accusations = weights.accusations + 15
    end

    return self:SelectWeightedMessage("kills", event, weights)
end

-- Умный выбор фразы при СМЕРТИ бота от рук killer (энтити игроков)
function GeminiBots.Chat:GetSmartDeathMessage(bot, killer, hitgroup, event)
    if not self:IsSmartContextEnabled() then
        return self:GetRandomDeathMessage()
    end
    event = event or "DEFAULT"

    local killerKD = self:GetPlayerKD(killer)
    local killerPing = IsValid(killer) and killer:Ping() or 0
    local killerStreak = (self.Streaks and self.Streaks[killer]) or 0
    local domination = (self.Nemesis and self.Nemesis[killer] and self.Nemesis[killer][bot]) or 0

    local weights = {
        standard = 15,
        accusations = 5,
        toxic = 5
    }

    -- Событийные смещения тем (поверх статистики)
    if event == "WALLBANG" then
        weights.accusations = weights.accusations + 35
    elseif event == "BACKSTAB" then
        weights.accusations = weights.accusations + 20
        weights.toxic = weights.toxic + 10
    elseif event == "SPAWNKILL" then
        weights.accusations = weights.accusations + 25
        weights.toxic = weights.toxic + 25
    elseif event == "LONGSHOT" then
        weights.standard = weights.standard + 20
    elseif event == "MIDAIR" then
        weights.standard = weights.standard + 15
        weights.accusations = weights.accusations + 10
    end

    -- Убийца имеет высокий K/D -> бот подозревает читы (аимбот, WH, префаеры)
    -- Порядок важен: сначала строгая проверка (>= 4.0 влечет >= 2.5)
    if killerKD >= 4.0 then
        weights.accusations = weights.accusations + 100
        weights.toxic = weights.toxic + 30
    elseif killerKD >= 2.5 then
        weights.accusations = weights.accusations + 50
    elseif killerKD <= 0.8 then
        -- Убийца обычный/слабый -> обычное оправдание или похвала
        weights.standard = weights.standard + 35
    end

    -- Убийца идет на серии фрагов без смертей (сначала строгая проверка)
    if killerStreak >= 6 then
        weights.accusations = weights.accusations + 60
    elseif killerStreak >= 3 then
        weights.accusations = weights.accusations + 30
    end

    -- Убийца доминирует над этим ботом
    if domination >= 2 then
        weights.accusations = weights.accusations + 40
        weights.toxic = weights.toxic + 25
    end

    -- Смерть от хедшота
    if hitgroup == HITGROUP_HEAD then
        weights.accusations = weights.accusations + 35
    end

    -- Убийца с высоким пингом
    if killerPing >= 120 then
        weights.accusations = weights.accusations + 40
    end

    return self:SelectWeightedMessage("deaths", event, weights)
end

-- Получить структурированный список паков для клиента/меню
function GeminiBots.Chat:GetPacksList()
    local list = {}
    for name, pack in pairs(self.Packs) do
        local nk, nd, _, nch = CountPack(pack)
        table.insert(list, {
            name = name,
            kills = nk,
            deaths = nd,
            chat = nch or 0,
            active = self:IsPackActive(name)
        })
    end
    table.SortByMember(list, "name", true)
    return list
end

--------------------------------------------------------------------------------
-- Сетевая синхронизация с клиентом (Q-Menu)
--------------------------------------------------------------------------------
local function SendPacksToClient(ply)
    local list = GeminiBots.Chat:GetPacksList()
    net.Start("GeminiBots_ReceiveChatPacks")
    net.WriteTable(list)
    if IsValid(ply) then
        net.Send(ply)
    else
        net.Broadcast()
    end
    local parts = {}
    for _, e in ipairs(list) do
        table.insert(parts, string.format("%s(k=%d,d=%d,%s)",
            e.name, e.kills or -1, e.deaths or -1, e.active and "ON" or "OFF"))
    end
    GeminiBots.FileLog("packs", "sent to %s: %s",
        IsValid(ply) and ply:Nick() or "ALL", table.concat(parts, " "))
end

net.Receive("GeminiBots_RequestChatPacks", function(len, ply)
    SendPacksToClient(ply)
end)

net.Receive("GeminiBots_ToggleChatPack", function(len, ply)
    if IsValid(ply) and not ply:IsSuperAdmin() and not ply:IsAdmin() and not game.SinglePlayer() then
        return
    end

    local packName = net.ReadString()
    local active = net.ReadBool()

    GeminiBots.Chat:SetPackActive(packName, active)
    SendPacksToClient()
end)

--------------------------------------------------------------------------------
-- Консольные команды
--------------------------------------------------------------------------------
concommand.Add("geminibots_chat_pack_list", function()
    print("=== [GeminiBots] Список чат-паков (.txt) ===")
    print("Папка: garrysmod/data/" .. DATA_DIR .. "/")
    for name, pack in pairs(GeminiBots.Chat.Packs) do
        local status = GeminiBots.Chat:IsPackActive(name) and "[ВКЛЮЧЕН / ON]" or "[ВЫКЛЮЧЕН / OFF]"
        local nk, nd, cats = CountPack(pack)
        print(string.format(" - %-20s %-16s (Фрагов: %d, Смертей: %d)", name, status, nk, nd))
        if #cats > 0 then
            print(string.format("     категории: %s", table.concat(cats, ", ")))
        end
    end
end, nil, "Вывести список всех загруженных текстовых паков")

concommand.Add("geminibots_chat_pack_toggle", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local name = args[1]
    if not name or not GeminiBots.Chat.Packs[name] then
        print("[GeminiBots] Ошибка: пак не найден. Введите geminibots_chat_pack_list для просмотра доступных.")
        return
    end

    local currentState = GeminiBots.Chat:IsPackActive(name)
    GeminiBots.Chat:SetPackActive(name, not currentState)
    SendPacksToClient()
end, nil, "Включить/выключить пак по имени файла (пример: geminibots_chat_pack_toggle accuses_ru_en.txt)")

concommand.Add("geminibots_chat_reload_packs", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    GeminiBots.Chat:ReloadPacks()
    SendPacksToClient()
    print("[GeminiBots] Все текстовые паки успешно перезагружены с диска.")
end, nil, "Перезагрузить все .txt файлы чата из папки data/geminibots/chat/")

concommand.Add("geminibots_chat_pack_delete", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local name = args[1]
    if not name or not GeminiBots.Chat.Packs[name] then
        print("[GeminiBots] Ошибка: пак не найден. Введите geminibots_chat_pack_list для просмотра доступных.")
        return
    end

    file.Delete(DATA_DIR .. "/" .. name)
    GeminiBots.Chat.DeletedPacks = GeminiBots.Chat.DeletedPacks or {}
    GeminiBots.Chat.DeletedPacks[name] = true
    SaveDeletedPacks()
    GeminiBots.Chat.ActivePacks[name] = nil
    SaveActiveState()
    GeminiBots.Chat:ReloadPacks()
    SendPacksToClient()
    print(string.format("[GeminiBots] Пак %s удален навсегда (файл стерт, из кода не вернется).", name))
end, nil, "Удалить пак навсегда: файл стирается и не пересоздается (пример: geminibots_chat_pack_delete toxic_ru.txt)")

concommand.Add("geminibots_chat_pack_restore", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local name = args[1]
    if not name then
        print("[GeminiBots] Использование: geminibots_chat_pack_restore <имя_файла.txt>")
        return
    end

    if GeminiBots.Chat.DeletedPacks then
        GeminiBots.Chat.DeletedPacks[name] = nil
    end
    SaveDeletedPacks()
    GeminiBots.Chat:ReloadPacks()
    SendPacksToClient()
    if DEFAULT_PACKS[name] then
        print(string.format("[GeminiBots] Пак %s убран из черного списка и пересоздан из кода.", name))
    else
        print(string.format("[GeminiBots] Пак %s убран из черного списка (файл восстановите вручную).", name))
    end
end, nil, "Вернуть удаленный пак: убрать из черного списка и пересоздать")

-- Первоначальная загрузка паков при старте
timer.Simple(0.2, function()
    GeminiBots.Chat:ReloadPacks()
end)
