--[[
    GeminiBots - UI Theme (Client)
    Общая темная тема отдельного окна настроек и Арсенала:
    палитра, шрифты (extended = true для кириллицы), конструкторы
    строк-тоглов, слайдеров, кнопок, стилизация скролла и полей ввода.
    Q-меню (spawnmenu) не трогаем — там нативный вид.
]]

GeminiBots = GeminiBots or {}
GeminiBots.Theme = GeminiBots.Theme or {}

local T = GeminiBots.Theme

-- Палитры: темная по умолчанию, светлая на выбор.
-- Все Paint читают T.Colors вживую, поэтому смена темы мгновенная.
T.Themes = {
    dark = {
        bg       = Color(18, 20, 26),
        card     = Color(28, 31, 40),
        row      = Color(34, 38, 48),
        header   = Color(24, 26, 33),
        accent   = Color(88, 101, 242),
        accentDk = Color(60, 70, 180),
        green    = Color(67, 181, 129),
        red      = Color(240, 71, 71),
        text     = Color(235, 235, 240),
        muted    = Color(150, 156, 170),
        input    = Color(22, 24, 30),
        border   = Color(52, 58, 72),
    },
    light = {
        bg       = Color(236, 238, 242),
        card     = Color(255, 255, 255),
        row      = Color(244, 246, 250),
        header   = Color(225, 228, 234),
        accent   = Color(88, 101, 242),
        accentDk = Color(70, 82, 200),
        green    = Color(46, 160, 100),
        red      = Color(220, 50, 50),
        text     = Color(32, 34, 40),
        muted    = Color(110, 116, 128),
        input    = Color(232, 234, 239),
        border   = Color(210, 214, 222),
    },
}

T.Colors = {}
for k, v in pairs(T.Themes.dark) do T.Colors[k] = v end

CreateClientConVar("geminibots_menu_theme", "dark", true, false,
    "Тема меню GeminiBots: dark / light")
CreateClientConVar("geminibots_menu_fade", "1", true, false,
    "Анимации открытия/закрытия окон GeminiBots (1 = Вкл, 0 = Выкл)")
CreateClientConVar("geminibots_menu_blur", "0", true, false,
    "Блюр фона под окнами GeminiBots: число проходов 0-3 (0 = Выкл)")
CreateClientConVar("geminibots_menu_accent", "5865F2", true, false,
    "Акцентный цвет меню GeminiBots (hex без #, напр. 5865F2)")
CreateClientConVar("geminibots_menu_corner", "8", true, false,
    "Радиус скругления меню GeminiBots (0-16)")
CreateClientConVar("geminibots_menu_scale", "1.0", true, false,
    "Масштаб интерфейса меню GeminiBots (0.85-1.15)")
CreateClientConVar("geminibots_menu_sounds", "1", true, false,
    "Звуки кликов в меню GeminiBots (1 = Вкл, 0 = Выкл)")
CreateClientConVar("geminibots_menu_font", "Roboto", true, false,
    "Шрифт меню GeminiBots: Roboto / Segoe UI / Tahoma / Verdana / Arial")
CreateClientConVar("geminibots_menu_tab", "main", true, false,
    "Последняя открытая вкладка меню GeminiBots")
CreateClientConVar("geminibots_menu_particles", "stars", true, false,
    "Частицы на фоне меню GeminiBots: off/stars/snow/rain/embers")
CreateClientConVar("geminibots_menu_particles_accent", "1", true, false,
    "Частицы в цвете акцента меню (1 = Вкл, 0 = белые)")
CreateClientConVar("geminibots_menu_lang", "auto", true, false,
    "Язык меню GeminiBots: auto/ru/en (auto = как в GMod)")
CreateClientConVar("geminibots_menu_logo", "0", true, false,
    "Лого GeminiBots в шапке: 0 голова-бот / 1 радар-свип / 2 вейпоинт-ромб")

-- Описания клиентских конваров для тултипов
GeminiBots.ConVarDescs = GeminiBots.ConVarDescs or {}
GeminiBots.ConVarDescs["geminibots_menu_theme"] = "Тема меню GeminiBots: dark / light"
GeminiBots.ConVarDescs["geminibots_menu_fade"] = "Анимации открытия/закрытия окон GeminiBots (вкл/выкл)"
GeminiBots.ConVarDescs["geminibots_menu_blur"] = "Размытие фона под окнами GeminiBots: уровень 0-3 (0 = Выкл)"
GeminiBots.ConVarDescs["geminibots_menu_accent"] = "Акцентный цвет меню GeminiBots (hex без #, напр. 5865F2)"
GeminiBots.ConVarDescs["geminibots_menu_corner"] = "Радиус скругления меню GeminiBots (0-16)"
GeminiBots.ConVarDescs["geminibots_menu_scale"] = "Масштаб интерфейса меню GeminiBots (85-115%)"
GeminiBots.ConVarDescs["geminibots_menu_sounds"] = "Звуки кликов в меню GeminiBots (вкл/выкл)"
GeminiBots.ConVarDescs["geminibots_menu_particles"] = "Частицы на фоне меню GeminiBots: выкл/созвездие/снег/дождь/искры"
GeminiBots.ConVarDescs["geminibots_menu_particles_accent"] = "Частицы в цвете акцента (выкл = белые)"
GeminiBots.ConVarDescs["geminibots_menu_lang"] = "Язык меню: авто (как в GMod) / русский / английский"
GeminiBots.ConVarDescs["geminibots_menu_logo"] = "Лого в шапке меню: голова-бот / радар-свип / вейпоинт-ромб"
GeminiBots.ConVarDescs["geminibots_menu_font"] = "Шрифт меню GeminiBots (Roboto и похожие)"

-- Масштаб и скругление (читаются вживую каждым Paint)
function T.Scale()
    local cv = GetConVar("geminibots_menu_scale")
    local v = cv and cv:GetFloat() or 1.0
    return math.Clamp(v, 0.85, 1.15)
end

function T.SZ(n)
    return math.max(1, math.Round(n * T.Scale()))
end

function T.Corner()
    local cv = GetConVar("geminibots_menu_corner")
    local v = cv and cv:GetInt() or 8
    return math.Clamp(v, 0, 16)
end

-- Шрифты с нормальным кириллическим хинтингом, похожие на Roboto
T.FontFaces = { "Roboto", "Segoe UI", "Tahoma", "Verdana", "Arial" }

function T.FontFace()
    local cv = GetConVar("geminibots_menu_font")
    local v = cv and cv:GetString() or "Roboto"
    for _, f in ipairs(T.FontFaces) do
        if v == f then return v end
    end
    return "Roboto"
end

-- Рисуем текст по буквам с ровным шагом: движок трекинга не умеет,
-- а Roboto Bold в мелком кегле слипает пары букв
function T.DrawSpaced(text, font, x, y, color, ax, ay, track)
    track = track or 1
    text = tostring(text or "")
    if text == "" then return 0 end
    if not utf8 or not utf8.codes then
        draw.SimpleText(text, font, x, y, color, ax, ay)
        return 0
    end
    surface.SetFont(font)
    local chars, widths, total = {}, {}, 0
    for _, code in utf8.codes(text) do
        local ch = utf8.char(code)
        chars[#chars + 1] = ch
        local w = surface.GetTextSize(ch)
        widths[#widths + 1] = w
        total = total + w
    end
    total = total + track * (#chars - 1)
    local sx = x
    if ax == TEXT_ALIGN_CENTER then
        sx = x - total / 2
    elseif ax == TEXT_ALIGN_RIGHT then
        sx = x - total
    end
    for i, ch in ipairs(chars) do
        draw.SimpleText(ch, font, sx, y, color, TEXT_ALIGN_LEFT, ay)
        sx = sx + widths[i] + track
    end
    return total
end

-- Подпись с ровными отступами (замена DLabel там, где текст наш)
function T.SpacedLabel(parent, tall)
    local l = vgui.Create("DPanel", parent)
    l:Dock(TOP)
    l:SetTall(tall or T.SZ(20))
    l.Paint = function(self, w, h)
        local ax = self.GeminiAX or TEXT_ALIGN_CENTER
        local px = w / 2
        if ax == TEXT_ALIGN_LEFT then px = self.GeminiX or 0 end
        if ax == TEXT_ALIGN_RIGHT then px = w - (self.GeminiX or 0) end
        T.DrawSpaced(self.GeminiText or "", self.GeminiFont or "GeminiText",
            px, h / 2, self.GeminiColor or T.Colors.text, ax, TEXT_ALIGN_CENTER, 1)
    end
    return l
end
-- Шрифты пересоздаются тем же именем (движок позволяет) при смене масштаба.
-- Семейство берет из выбора (по умолчанию Roboto)
function T.BuildFonts()
    local face = T.FontFace()
    local s = T.Scale()
    surface.CreateFont("GeminiTitle", { font = face, size = math.Round(24 * s), weight = 700, extended = true, antialias = true })
    surface.CreateFont("GeminiHeader", { font = face, size = math.Round(19 * s), weight = 700, extended = true, antialias = true })
    surface.CreateFont("GeminiText", { font = face, size = math.Round(17 * s), weight = 500, extended = true, antialias = true })
    surface.CreateFont("GeminiSmall", { font = face, size = math.Round(15 * s), weight = 500, extended = true, antialias = true })
    surface.CreateFont("GeminiLogo", { font = face, size = math.Round(15 * s), weight = 800, extended = true, antialias = true })
end

T.BuildFonts()

-- Акцент из hex ("5865F2" или "#5865F2")
function T.ApplyAccent(hex, quiet)
    hex = tostring(hex or ""):upper():gsub("#", "")
    if not string.match(hex, "^%x%x%x%x%x%x$") then
        if not quiet then print("[GeminiBots] Плохой hex акцента: " .. tostring(hex)) end
        return false
    end
    local n = tonumber(hex, 16)
    local r = math.floor(n / 65536) % 256
    local g = math.floor(n / 256) % 256
    local b = n % 256
    T.Colors.accent = Color(r, g, b)
    T.Colors.accentDk = Color(math.Round(r * 0.7), math.Round(g * 0.7), math.Round(b * 0.7))
    return true
end

function T.CurrentAccent()
    local cv = GetConVar("geminibots_menu_accent")
    return (cv and cv:GetString()) or "5865F2"
end

-- Готовые пресеты оформления: акцент + углы + блюр
T.Presets = {
    discord = { accent = "5865F2", corner = "8", blur = "2" },
    minimal = { accent = "80848E", corner = "4", blur = "0" },
    candy   = { accent = "EB459E", corner = "16", blur = "2" },
}

function T.ApplyPreset(id)
    local p = T.Presets[id]
    if not p then return end
    T.WriteConVar("geminibots_menu_accent", p.accent)
    T.WriteConVar("geminibots_menu_corner", p.corner)
    T.WriteConVar("geminibots_menu_blur", p.blur)
    T.ApplyAccent(p.accent, true)
    if GeminiBots.RefreshOpenWindows then
        GeminiBots.RefreshOpenWindows()
    end
end

function T.ApplyTheme(name)
    local pal = T.Themes[name] or T.Themes.dark
    for k, v in pairs(pal) do T.Colors[k] = v end
    -- Акцент поверх палитры (кастомный цвет живет отдельно от темы)
    T.ApplyAccent(T.CurrentAccent(), true)
end

function T.CurrentTheme()
    local cv = GetConVar("geminibots_menu_theme")
    local v = cv and cv:GetString() or "dark"
    if v ~= "light" and v ~= "dark" then v = "dark" end
    return v
end

T.ApplyTheme(T.CurrentTheme())

cvars.AddChangeCallback("geminibots_menu_theme", function(_, _, newVal)
    T.ApplyTheme(newVal)
    -- Пересобрать открытые окна, чтобы обновить статичные цвета подписей
    if GeminiBots.RefreshOpenWindows then
        GeminiBots.RefreshOpenWindows()
    end
end)

cvars.AddChangeCallback("geminibots_menu_accent", function(_, _, newVal)
    if T.ApplyAccent(newVal, true) and GeminiBots.RefreshOpenWindows then
        GeminiBots.RefreshOpenWindows()
    end
end)

cvars.AddChangeCallback("geminibots_menu_scale", function()
    T.BuildFonts()
    if GeminiBots.RefreshOpenWindows then
        GeminiBots.RefreshOpenWindows()
    end
end)

-- Запись конвара с учетом репликации: серверные только через сервер,
-- клиентские напрямую (иначе "Unknown command" и тишина)
function T.WriteConVar(name, strVal)
    local cv = GetConVar(name)
    if not cv then return end
    if cv:IsFlagSet(FCVAR_REPLICATED) then
        RunConsoleCommand(name, tostring(strVal))
    else
        cv:SetString(tostring(strVal))
    end
end

T.BuildFonts()

function T.ClickSound()
    local cv = GetConVar("geminibots_menu_sounds")
    if cv and not cv:GetBool() then return end
    surface.PlaySound("garrysmod/ui_click.wav")
end

-- Гладкий скругленный прямоугольник: штатный draw.RoundedBox дает
-- лесенку на углах, здесь больше сегментов — край ровнее.
-- (Полного AA в 2D движка нет, но ступеньки заметно мельче.)
function T.RBox(x, y, w, h, r, color, seg)
    seg = seg or 20
    r = math.min(r or 0, w / 2, h / 2)
    -- Сбрасываем текстуру: полигоны с привязанной текстурой дают мусор
    draw.NoTexture()
    surface.SetDrawColor(color)
    if r <= 0 then
        surface.DrawRect(x, y, w, h)
        return
    end
    surface.DrawRect(x + r, y, w - 2 * r, h)
    surface.DrawRect(x, y + r, w, h - 2 * r)
    -- Нахлест на 1px поверх стыков с веерами: иначе на границе
    -- треугольников и ректов просвечивает волосяная щель.
    -- Только для непрозрачных заливок: на полупрозрачных (ховер)
    -- двойное смешивание само даст видимые полосы
    if (color.a or 255) >= 255 then
        surface.DrawRect(x + r - 1, y, 2, h)
        surface.DrawRect(x + w - r - 1, y, 2, h)
        surface.DrawRect(x, y + r - 1, w, 2)
        surface.DrawRect(x, y + h - r - 1, w, 2)
    end
    local starts = { 180, 270, 0, 90 }
    local cx = { x + r, x + w - r, x + w - r, x + r }
    local cy = { y + r, y + r, y + h - r, y + h - r }
    for i = 1, 4 do
        local pts = { { x = cx[i], y = cy[i] } }
        for j = 0, seg do
            local a = math.rad(starts[i] + j * 90 / seg)
            pts[#pts + 1] = { x = cx[i] + math.cos(a) * r, y = cy[i] + math.sin(a) * r }
        end
        surface.DrawPoly(pts)
    end
end

-- Режимы частиц фона меню
T.ParticleModes = { "off", "stars", "snow", "rain", "embers" }

function T.ParticleMode()
    local cv = GetConVar("geminibots_menu_particles")
    local v = cv and string.lower(cv:GetString() or "") or "stars"
    if v == "1" or v == "true" then v = "stars" end
    if v == "0" or v == "false" or v == "" then v = "off" end
    for _, m in ipairs(T.ParticleModes) do
        if v == m then return v end
    end
    return "off"
end

function T.ParticleModeName(mode)
    local ru = GeminiBots.GetMenuLang() == "ru"
    local names = ru
        and { off = "Выкл", stars = "Созвездие", snow = "Снег", rain = "Дождь", embers = "Искры" }
        or { off = "Off", stars = "Stars", snow = "Snow", rain = "Rain", embers = "Embers" }
    return names[mode] or mode
end

-- Цвет частиц: акцент (вкл) либо цвет текста темы (выкл).
-- Текст темный на светлой теме и светлый на темной — баг
-- "белые частицы на светлой теме" закрыт структурно
function T.ParticleColor()
    local cv = GetConVar("geminibots_menu_particles_accent")
    if cv and cv:GetBool() then return T.Colors.accent end
    return T.Colors.text
end

-- Смешать два цвета (для ховера: заливка меняет цвет целиком,
-- без полупрозрачных оверлеев и их швов)
function T.Mix(a, b, t)
    t = math.Clamp(t or 0, 0, 1)
    return Color(
        math.Round(Lerp(t, a.r, b.r)),
        math.Round(Lerp(t, a.g, b.g)),
        math.Round(Lerp(t, a.b, b.b)),
        math.Round(Lerp(t, a.a or 255, b.a or 255)))
end

--------------------------------------------------------------------------------
-- Тематические тултипы: темная плашка с акцентной рамкой вместо
-- желтого бокса движка. Показ с задержкой 0.5 сек у курсора.
--------------------------------------------------------------------------------
T.TipPanels = T.TipPanels or {}

function T.Tooltip(panel, text)
    if not IsValid(panel) or not text or text == "" then return end
    panel.GeminiTipText = text
    T.TipPanels[panel] = true
end

local TipFrame = nil
local TipFor, TipSince = nil, 0
local TipMX, TipMY = nil, nil

-- Считаем строки сами: движковый замер высоты врет на первом показе
local function TipLineCount(txt)
    local total = 0
    for _, para in ipairs(string.Split(txt or "", "\n")) do
        local cur, lines = 0, 1
        for word in string.gmatch(para, "%S+") do
            local ok, wl = pcall(utf8.len, word)
            if not ok or not wl then wl = math.ceil(#word / 2) end
            if cur == 0 then
                cur = wl
            elseif cur + 1 + wl > 48 then
                lines = lines + 1
                cur = wl
            else
                cur = cur + 1 + wl
            end
        end
        total = total + lines
    end
    return math.Clamp(total, 1, 6)
end

local function RefreshTipText(tip, txt)
    tip.GeminiText = txt
    local lbl = tip.GeminiLabel
    lbl:SetText(txt)
    -- Строка мелкого шрифта с запасом сверху/снизу, иначе режет
    local h = TipLineCount(txt) * 20
    lbl:SetSize(260, h)
    lbl:SetPos(10, 9)
    tip:SetSize(280, h + 18)
end

local function GetTipFrame()
    if IsValid(TipFrame) then return TipFrame end
    TipFrame = vgui.Create("DPanel")
    TipFrame:SetSize(280, 30)
    TipFrame:SetMouseInputEnabled(false)
    TipFrame:SetKeyboardInputEnabled(false)
    TipFrame:SetVisible(false)
    TipFrame.Paint = function(self, w, h)
        local c = T.Corner()
        T.RBox(0, 0, w, h, c, T.Colors.accent)
        T.RBox(1, 1, w - 2, h - 2, math.max(0, c - 1), T.Colors.card)
    end
    local lbl = vgui.Create("DLabel", TipFrame)
    lbl:SetPos(10, 8)
    lbl:SetSize(260, 20)
    lbl:SetFont("GeminiSmall")
    lbl:SetTextColor(T.Colors.text)
    lbl:SetWrap(true)
    TipFrame.GeminiLabel = lbl
    return TipFrame
end

hook.Add("Think", "GeminiBots_TipThink", function()
    local tip = GetTipFrame()
    if not IsValid(tip) then return end
    -- Цвет текста вживую: фрейм переживает смену темы, SetTextColor
    -- один раз скопировал бы старое (белое на светлой и не видно)
    if IsValid(tip.GeminiLabel) then
        tip.GeminiLabel:SetTextColor(T.Colors.text)
    end
    local mx, my = gui.MouseX(), gui.MouseY()
    -- Курсор заметно дернулся: прячем и ждем заново, старость не показываем.
    -- Мелкое дрожание руки (пара пикселей) игнорим, иначе не покажется никогда
    if TipMX == nil or math.abs(mx - TipMX) > 6 or math.abs(my - TipMY) > 6 then
        TipMX, TipMY = mx, my
        TipSince = CurTime()
        tip:SetVisible(false)
        TipFor = nil
    end
    -- Видимость по всей цепочке родителей: IsVisible сам по себе
    -- скрытые вкладки не отсекает, и тултип брался с них
    local function ChainVisible(p)
        local cur = p
        while IsValid(cur) do
            if not cur:IsVisible() then return false end
            cur = cur:GetParent()
        end
        return true
    end
    -- Чистим мертвые панели, ищем панель под курсором
    local found = nil
    for p in pairs(T.TipPanels) do
        if not IsValid(p) then
            T.TipPanels[p] = nil
        elseif ChainVisible(p) then
            local lx, ly = p:ScreenToLocal(mx, my)
            if lx >= 0 and ly >= 0 and lx <= p:GetWide() and ly <= p:GetTall() then
                found = p
                break
            end
        end
    end
    if found ~= TipFor then
        TipFor = found
        TipSince = CurTime()
        tip:SetVisible(false)
    end
    if not found then return end
    if CurTime() - TipSince < 0.5 then return end
    local txt = found.GeminiTipText or ""
    local fresh = (not tip:IsVisible()) or (tip.GeminiText ~= txt)
    if tip.GeminiText ~= txt then
        RefreshTipText(tip, txt)
    end
    -- Появление fade'ом как у меню (если анимации не выключены)
    if fresh then
        local fadeCv = GetConVar("geminibots_menu_fade")
        if not fadeCv or fadeCv:GetBool() then
            tip:SetAlpha(0)
            tip:AlphaTo(255, 0.12, 0)
        else
            tip:SetAlpha(255)
        end
    end
    tip:SetPos(math.min(mx + 16, ScrW() - 290), math.min(my + 18, ScrH() - tip:GetTall() - 10))
    -- Не закрываем строку, на которую наведены: уезжаем под нее
    if IsValid(found) then
        local fx, fy = found:LocalToScreen(0, found:GetTall())
        tip:SetPos(math.Clamp(fx, 0, ScrW() - 290), math.min(fy + 6, ScrH() - tip:GetTall() - 10))
    end
    tip:MoveToFront()
    tip:SetVisible(true)
end)

-- Скругленная карточка-фон
function T.PaintCard(_, w, h)
    draw.RoundedBox(T.Corner(), 0, 0, w, h, T.Colors.card)
end

-- Слайдеры-шансы: показываем процентами, храним дробью
T.PctConVars = {
    ["geminibots_menu_scale"] = true,
    ["geminibots_chat_kill_chance"] = true,
    ["geminibots_chat_death_chance"] = true,
    ["geminibots_chat_comeback_chance"] = true,
    ["geminibots_chat_taunt_chance"] = true,
    ["geminibots_aim_headshot_chance"] = true,
    ["geminibots_bhop_chance"] = true,
    ["geminibots_swcs_decoy_chance"] = true,
}

-- Английские описания для тултипов в EN-режиме
GeminiBots.ConVarDescsEN = {
    ["geminibots_enabled"] = "Enable GeminiBots bot AI (on/off)",
    ["geminibots_custom_names"] = "Unique custom nicknames for bots (on/off)",
    ["geminibots_preserve_bots"] = "Restore bots on map change (on/off)",
    ["geminibots_debug"] = "Bot debug output in console (on/off)",
    ["geminibots_debug_draw"] = "World debug drawing, grenade trajectories and paths (on/off)",
    ["geminibots_appearance_enabled"] = "Random bot appearance on spawn (on/off)",
    ["geminibots_appearance_model"] = "Random player models (on/off)",
    ["geminibots_appearance_skin"] = "Random model skins (on/off)",
    ["geminibots_appearance_bodygroups"] = "Random bodygroups (on/off)",
    ["geminibots_appearance_color"] = "Random player color (on/off)",
    ["geminibots_appearance_respawn"] = "Change appearance on every respawn (On = Yes, Off = Once)",
    ["geminibots_appearance_respawn"] = "Change appearance on every respawn (on/off)",
    ["geminibots_loadout_enabled"] = "Random weapons on spawn (on/off)",
    ["geminibots_loadout_min"] = "Min weapons given (1-5)",
    ["geminibots_loadout_max"] = "Max weapons given (1-5)",
    ["geminibots_loadout_ammo"] = "Reserve ammo per weapon",
    ["geminibots_loadout_strip"] = "Strip default weapons before giving out (on/off)",
    ["geminibots_chat_enabled"] = "Let bots write in chat (on/off)",
    ["geminibots_chat_smart_context"] = "Smart phrase context with K/D and streaks (on/off)",
    ["geminibots_chat_kill_chance"] = "Chat message chance after a kill (0-100%)",
    ["geminibots_chat_death_chance"] = "Chat message chance after own death (0-100%)",
    ["geminibots_chat_comeback_chance"] = "Bot comeback chance on accusation (0-100%)",
    ["geminibots_chat_taunt_chance"] = "Combat taunt chance, aim and hiding (0-100%)",
    ["geminibots_file_log"] = "Verbose log to data/geminibots/logs/debug.log (on/off)",
    ["geminibots_vision_fov"] = "Bot field of view, degrees (30-180)",
    ["geminibots_vision_range"] = "Max enemy detection distance, units",
    ["geminibots_hearing_range"] = "Footstep hearing distance through walls, units",
    ["geminibots_gun_hearing_range"] = "Gunshot hearing distance, units",
    ["geminibots_memory_duration"] = "How long a bot remembers a target behind cover, sec",
    ["geminibots_target_mode"] = "Target mode: both / pve / players / npcs",
    ["geminibots_reaction_min"] = "Min reaction delay before firing, sec",
    ["geminibots_reaction_max"] = "Max reaction delay before firing, sec",
    ["geminibots_aim_speed"] = "Aim turn speed, degrees per second",
    ["geminibots_aim_smoothing"] = "Aim smoothing factor (0.05-1.0)",
    ["geminibots_aim_prediction"] = "Lead moving targets when firing (on/off)",
    ["geminibots_aim_spread"] = "Bot aim error, degrees (0.0-5.0)",
    ["geminibots_aim_headshot_chance"] = "Chance to aim for the head (0-100%)",
    ["geminibots_combat_min_dist"] = "Min combat distance before falling back, units",
    ["geminibots_combat_max_dist"] = "Max combat distance before closing in, units",
    ["geminibots_flee_health"] = "Health fraction to retreat at (0.0-0.8)",
    ["geminibots_wallbang"] = "Shoot through glass/breakables on a fresh trail (on/off)",
    ["geminibots_c4_enabled"] = "Bots plant and defuse SWCS C4 (on/off)",
    ["geminibots_swcs_decoy_chance"] = "Chance to check an SWCS decoy sound (0-100%)",
    ["geminibots_swcs_fire_avoid"] = "Back away from SWCS molotov fire (on/off)",
    ["geminibots_swcs_fire_radius"] = "SWCS fire reaction distance, units",
    ["geminibots_bhop_enabled"] = "Bunny-hop while moving (on/off)",
    ["geminibots_bhop_chance"] = "Hop chance per landing (0-100%)",
    ["geminibots_menu_theme"] = "GeminiBots menu theme: dark / light",
    ["geminibots_menu_fade"] = "GeminiBots window open/close animations (on/off)",
    ["geminibots_menu_blur"] = "Background blur under GeminiBots windows: level 0-3 (0 = Off)",
    ["geminibots_menu_accent"] = "GeminiBots menu accent color (hex without #, e.g. 5865F2)",
    ["geminibots_menu_corner"] = "GeminiBots menu corner radius (0-16)",
    ["geminibots_menu_scale"] = "GeminiBots menu UI scale (85-115%)",
    ["geminibots_menu_sounds"] = "Click sounds in GeminiBots menu (on/off)",
    ["geminibots_menu_particles"] = "Menu background particles: off/stars/snow/rain/embers",
    ["geminibots_menu_particles_accent"] = "Particles in accent color (off = white)",
    ["geminibots_menu_lang"] = "Menu language: auto (same as GMod) / Russian / English",
    ["geminibots_menu_font"] = "GeminiBots menu font (Roboto and lookalikes)",
}

-- Текст тултипа на языке меню + скобки из подписи
function T.CvarTip(convarName, extra)
    local ru = GeminiBots.GetMenuLang() == "ru"
    local d = ru and GeminiBots.ConVarDescs or GeminiBots.ConVarDescsEN
    local tip = (d and d[convarName])
        or (GeminiBots.ConVarDescs and GeminiBots.ConVarDescs[convarName]) or ""
    if extra and extra ~= "" then tip = tip .. "\n" .. extra end
    return tip
end

-- Описание начинается с текста подписи: подпись не дублируем
function T.ShortTip(label, tip)
    tip = tostring(tip or "")
    label = tostring(label or "")
    if label ~= "" and tip:sub(1, #label) == label then
        tip = string.gsub(tip:sub(#label + 1), "^%s+", "")
    end
    return tip
end

-- Секция-заголовок: крупнее и акцентным цветом, с ровными отступами
function T.SectionHeader(parent, text)
    text = string.gsub(string.gsub(text, "^[%s=%-]+", ""), "[%s=%-]+$", "")
    local l = T.SpacedLabel(parent, T.SZ(24))
    l:DockMargin(0, 10, 0, 4)
    l.GeminiText = text
    l.GeminiFont = "GeminiHeader"
    l.GeminiColor = T.Colors.accent
    return l
end

-- Приглушенная подпись
function T.MutedLabel(parent, text)
    local l = vgui.Create("DLabel", parent)
    l:Dock(TOP)
    l:DockMargin(4, 2, 4, 2)
    l:SetText(text)
    l:SetFont("GeminiSmall")
    l:SetTextColor(T.Colors.muted)
    l:SetWrap(true)
    l:SetAutoStretchVertical(true)
    return l
end

-- Строка-тогл. Возвращает объект с SetValue(0/1) и полем OnChange(self, bool).
-- С конваром: клик пишет в конвар + Think-синхронизация снаружи.
-- Без конвара: ручное состояние (паки чата, адаптеры, ESP).
function T.ToggleRow(parent, label, convarName)
    -- Все скобки из подписи долой (их может быть несколько подряд)
    label = tostring(label or "")
    while label:match("%s*%([^()]*%)%s*$") do
        label = string.gsub(label, "%s*%([^()]*%)%s*$", "")
    end
    local row = vgui.Create("DButton", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 6)
    row:SetTall(T.SZ(34))
    row:SetText("")
    row.state = false
    row.convar = convarName
    row.hover = 0
    row.knob = 0

    if convarName then
        local cv = GetConVar(convarName)
        if cv then
            row.state = cv:GetBool()
            row.knob = row.state and 1 or 0
        end
    end

    function row:SetValue(v)
        self.state = (v == 1 or v == true)
    end

    function row:Think()
        if self.convar then
            local cv = GetConVar(self.convar)
            if cv then self.state = cv:GetBool() end
        end
    end

    function row:Paint(w, h)
        local c = T.Corner()
        self.hover = Lerp(FrameTime() * 12, self.hover or 0, self:IsHovered() and 1 or 0)
        -- Выбранное — осветлением вместо рамки, ховер добавляет сверху
        local t = (self.hover or 0) * 0.35
        if self.state then t = 0.45 + (self.hover or 0) * 0.2 end
        T.RBox(0, 0, w, h, c,
            T.Mix(T.Colors.row, T.Colors.accent, math.min(1, t)))
        -- iOS-переключатель справа: кружок ездит, трек красится
        local kw = math.min(44, w * 0.14)
        local kh = math.min(22, h - 12)
        local kx = w - 10 - kw
        local ky = h / 2 - kh / 2
        self.knob = Lerp(FrameTime() * 14, self.knob or 0, self.state and 1 or 0)
        local track = self.state and T.Colors.accent or T.Colors.input
        T.RBox(kx, ky, kw, kh, kh / 2, track)
        local kd = kh - 4
        local nx = kx + 2 + (kw - kd - 4) * (self.knob or 0)
        T.RBox(nx, ky + 2, kd, kd, kd / 2, Color(255, 255, 255))
        T.DrawSpaced(label, "GeminiText", 10, h / 2,
            T.Colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1)
    end

    row.DoClick = function(self)
        T.ClickSound()
        local nv = not self.state
        if self.convar then
            T.WriteConVar(self.convar, nv and "1" or "0")
            self.state = nv
        else
            self.state = nv
        end
        if self.OnChange then self.OnChange(self, nv) end
    end

    if convarName and (GeminiBots.ConVarDescs or GeminiBots.ConVarDescsEN) then
        -- Скобки ушли из подписи: описание и так все говорит
        local tip = T.ShortTip(label, T.CvarTip(convarName))
        if tip ~= "" then T.Tooltip(row, tip) end
    end

    return row
end

-- Строка-слайдер с боксом значения, привязка к конвару.
-- Диапазоны вида "(0-16)" из подписи режем (min/max и так на дорожке).
-- Масштаб показываем в процентах.
function T.SliderRow(parent, label, convarName, min, max, decimals)
    decimals = decimals or 0
    -- Шансы (0-1) и масштаб показываем в процентах, храним дробью
    local isPct = T.PctConVars[convarName] == true
    -- Все скобки из подписи долой (их может быть несколько подряд)
    label = tostring(label or "")
    while label:match("%s*%([^()]*%)%s*$") do
        label = string.gsub(label, "%s*%([^()]*%)%s*$", "")
    end
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 6)
    row:SetTall(T.SZ(52))
    row.Paint = T.PaintCard
    if convarName and (GeminiBots.ConVarDescs or GeminiBots.ConVarDescsEN) then
        -- Скобки ушли из подписи: описание и так все говорит
        local tip = T.ShortTip(label, T.CvarTip(convarName))
        if tip ~= "" then T.Tooltip(row, tip) end
    end

    -- Верхняя строка: подпись слева, значение справа.
    -- Нижняя: дорожка во всю ширину, ровно от края до края
    local top = vgui.Create("DPanel", row)
    top:Dock(TOP)
    top:SetTall(T.SZ(22))
    top:DockMargin(0, 4, 0, 0)
    top.Paint = function() end

    local name = vgui.Create("DLabel", top)
    name:SetText(label)
    name:SetFont("GeminiText")
    name:SetTextColor(T.Colors.text)
    name:Dock(LEFT)
    name:DockMargin(8, 0, 0, 0)
    name:SetWide(10)
    name:SizeToContentsX()

    local bar = vgui.Create("DPanel", row)
    bar:Dock(FILL)
    bar:DockMargin(8, 0, 8, 6)
    bar.Paint = function() end
    bar.frac = 0
    bar.drag = false

    local function ConVarValue()
        local cv = GetConVar(convarName)
        if not cv then return min end
        if decimals == 0 then return cv:GetInt() end
        return cv:GetFloat()
    end

    local function ApplyFrac(f)
        f = math.Clamp(f or 0, 0, 1)
        local v = min + f * (max - min)
        local mult = 10 ^ decimals
        v = math.Round(v * mult) / mult
        -- Как тоглы: серверные через сервер, клиентские напрямую
        if decimals == 0 then
            T.WriteConVar(convarName, tostring(math.Round(v)))
        else
            T.WriteConVar(convarName, tostring(v))
        end
        bar.frac = (v - min) / math.max(1e-9, max - min)
        return v
    end

    bar.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT then return end
        self.drag = true
        self:MouseCapture(true)
        local x = self:CursorPos()
        ApplyFrac(x / math.max(1, self:GetWide()))
    end
    bar.OnMouseReleased = function(self)
        self.drag = false
        self:MouseCapture(false)
    end
    bar.OnCursorMoved = function(self)
        if not self.drag then return end
        local x = self:CursorPos()
        ApplyFrac(x / math.max(1, self:GetWide()))
    end
    -- Начальная позиция сразу из конвара (не ждем первый Think)
    do
        local v0 = ConVarValue()
        bar.frac = (v0 - min) / math.max(1e-9, max - min)
    end
    bar.Think = function(self)
        if not self.drag then
            local v = ConVarValue()
            self.frac = (v - min) / math.max(1e-9, max - min)
        end
    end
    bar.Paint = function(self, w, h)
        local cy = h / 2
        -- Плавная заливка: отображаемое догоняет целевое
        self.dfrac = Lerp(FrameTime() * 14, self.dfrac or self.frac or 0, self.frac or 0)
        draw.RoundedBox(2, 0, cy - 2, w, 4, T.Colors.input)
        local kd = T.SZ(12)
        -- Кружок не выезжает за края дорожки
        local fx = math.Clamp((self.dfrac or 0) * w, kd / 2, math.max(kd / 2, w - kd / 2))
        draw.RoundedBox(2, 0, cy - 2, fx, 4, T.Colors.accent)
        draw.RoundedBox(kd / 2, fx - kd / 2, cy - kd / 2, kd, kd, T.Colors.text)
    end

    local function ApplyText(t)
        local raw = string.gsub(t or "", "%%", "")
        local v = tonumber(raw) or min
        if isPct then v = v / 100 end
        v = math.Clamp(v, min, max)
        ApplyFrac((v - min) / math.max(1e-9, max - min))
    end

    -- Кнопка-значение вместо поля: клик открывает диалог ввода.
    -- Сидит в верхней строке справа, дорожка внизу во всю ширину
    local vbox = T.AccentButton(top, "")
    vbox:Dock(RIGHT)
    vbox:SetWide(T.SZ(76))
    vbox:DockMargin(0, 0, 8, 0)
    vbox.btnFont = "GeminiText"
    vbox.Think = function(self)
        local cur
        if isPct then
            cur = string.format("%d%%", math.Round(ConVarValue() * 100))
        else
            local fmt = "%." .. decimals .. "f"
            cur = string.format(fmt, ConVarValue())
        end
        self.btnLabel = cur
    end
    vbox.DoClick = function()
        T.ClickSound()
        T.AskText(label, ConVarValue(), true, nil, function(v)
            ApplyText(v)
        end)
    end

    return row
end

-- Акцентная кнопка (возвращает кнопку, DoClick назначает построитель)
function T.AccentButton(parent, label)
    local b = vgui.Create("DButton", parent)
    b:Dock(TOP)
    b:DockMargin(0, 0, 0, 6)
    b:SetTall(T.SZ(32))
    b:SetText("")
    b.hover = 0
    b.btnLabel = label
    b.btnFont = "GeminiText"
    -- Outlined: белая скругленная рамка поверх (активный выбор темы)
    function b:Paint(w, h)
        self.hover = Lerp(FrameTime() * 12, self.hover or 0, self:IsHovered() and 1 or 0)
        local c = T.Corner()
        -- Плавный переход цвета, а не резкий скачок
        local bgc = T.Mix(T.Colors.accentDk, T.Colors.accent, self.hover or 0)
        if self.Outlined then
            T.RBox(0, 0, w, h, c, T.Colors.text)
            local ic = math.max(0, c - 2)
            T.RBox(2, 2, w - 4, h - 4, ic, bgc)
        else
            T.RBox(0, 0, w, h, c, bgc)
        end
        T.DrawSpaced(self.btnLabel, self.btnFont or "GeminiText", w / 2, h / 2,
            T.Colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
    end
    b.DoClick = function() T.ClickSound() end
    -- Клик слышно сразу при нажатии, а не после срабатывания кнопки
    local OldPress = b.OnMousePressed
    function b:OnMousePressed(code)
        if code == MOUSE_LEFT then T.ClickSound() end
        if OldPress then return OldPress(self, code) end
    end
    return b
end

-- Темное поле ввода
function T.StyleTextEntry(entry)
    entry:SetTextColor(T.Colors.text)
    entry:SetCursorColor(T.Colors.text)
    entry:SetHighlightColor(T.Colors.accent)
    entry:SetPaintBackground(false)
    local OldPaint = entry.Paint
    entry.Paint = function(self, w, h)
        draw.RoundedBox(math.min(T.Corner(), math.floor(h / 2)), 0, 0, w, h, T.Colors.input)
        self:DrawTextEntryText(T.Colors.text, T.Colors.accent, T.Colors.text)
    end
end

-- Шапка комбобокса темная, текст рисуем поверх штатного (он иногда просвечивает)
function T.StyleComboFace(box)
    box:SetTextColor(T.Colors.text)
    box:SetFont("GeminiText")
    function box:Paint(w, h)
        draw.RoundedBox(math.min(T.Corner(), math.floor(h / 2)), 0, 0, w, h, T.Colors.input)
    end
    function box:PaintOver(w, h)
        draw.SimpleText(self:GetText(), "GeminiText", 8, h / 2,
            T.Colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("▾", "GeminiText", w - 8, h / 2,
            T.Colors.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    -- Выпадающий список тоже темный, а не белая дерма
    function box:OnMenuOpened(menu)
        if not IsValid(menu) then return end
        menu.Paint = function(_, w, h)
            T.RBox(0, 0, w, h, math.min(6, T.Corner()), T.Colors.card)
        end
        for _, ch in ipairs(menu:GetChildren()) do
            if IsValid(ch) and ch.GetClassName and ch:GetClassName() == "DMenuOption" then
                ch:SetTextColor(T.Colors.text)
                ch:SetFont("GeminiSmall")
                ch.hover = 0
                ch.Paint = function(self, w, h)
                    self.hover = Lerp(FrameTime() * 12, self.hover or 0,
                        self:IsHovered() and 1 or 0)
                    if (self.hover or 0) > 0.01 then
                        T.RBox(0, 0, w, h, 3, T.Mix(T.Colors.row,
                            T.Colors.accent, self.hover * 0.5))
                    end
                    draw.SimpleText(self:GetText(), "GeminiSmall", 20, h / 2,
                        T.Colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
            end
        end
    end
end

-- Тонкий акцентный скроллбар
function T.StyleScroll(scroll)
    local bar = scroll:GetVBar()
    -- Контент не лезет под ползунок: отступ справа у канваса
    if IsValid(scroll:GetCanvas()) then
        scroll:GetCanvas():DockPadding(0, 0, 8, 0)
    end
    if not IsValid(bar) then return end
    bar:SetWide(6)
    function bar:Paint() end
    if IsValid(bar.btnUp) then function bar.btnUp:Paint() end end
    if IsValid(bar.btnDown) then function bar.btnDown:Paint() end end
    function bar.btnGrip:Paint(w, h)
        draw.RoundedBox(3, 0, 0, w, h, T.Colors.accent)
    end
end

-- Блюр фона за окном (вызывать в начале Paint фрейма).
-- Сила = число проходов (конвар geminibots_menu_blur 0-3, 0 = Выкл).
function T.DrawBlur(frame)
    local passes = T.BlurPasses()
    for i = 1, passes do
        Derma_DrawBackgroundBlur(frame, CurTime())
    end
end

function T.BlurPasses()
    local cv = GetConVar("geminibots_menu_blur")
    local v = cv and cv:GetInt() or 0
    return math.Clamp(v, 0, 3)
end

function T.BlurEnabled()
    return T.BlurPasses() > 0
end

-- Плавный скролл: цель от колеса, догоняем в Think. Ползунок тащим как обычно.
function T.SmoothScroll(scroll)
    T.StyleScroll(scroll)
    local bar = scroll:GetVBar()
    if not IsValid(bar) then return end
    bar.GeminiTarget = nil
    local OldWheel = scroll.OnMouseWheeled
    function scroll:OnMouseWheeled(dlta)
        if IsValid(bar) then
            -- Держим цель прокрутки в границах, иначе залипает на краях
            local viewH = scroll:GetTall() or 0
            local canvasH = IsValid(scroll:GetCanvas()) and scroll:GetCanvas():GetTall() or 0
            local max = math.max(0, canvasH - viewH)
            local cur = bar.GeminiTarget or bar:GetScroll()
            bar.GeminiTarget = math.Clamp(cur - dlta * 60, 0, max)
        end
        return true
    end
    local OldThink = scroll.Think
    function scroll:Think()
        if OldThink then OldThink(self) end
        if not IsValid(bar) then return end
        if input.IsMouseDown(MOUSE_LEFT) then
            bar.GeminiTarget = nil
            return
        end
        if bar.GeminiTarget then
            local nv = Lerp(FrameTime() * 12, bar:GetScroll(), bar.GeminiTarget)
            if math.abs(nv - bar.GeminiTarget) < 0.5 then
                nv = bar.GeminiTarget
                bar.GeminiTarget = nil
            end
            bar:SetScroll(nv)
        end
    end
end

-- Сетка кнопок: влезают по ширине текста, максимум 3 в ряд,
-- остаток тянется на всю ширину без дыр. Новые кнопки просто
-- дописываем в defs — раскладка пересчитается сама.
-- defs: { { label = "...", fn = function() ... end }, ... }
function T.ButtonGrid(parent, defs, forceDark)
    if not parent or not defs or #defs == 0 then return {} end
    if not (forceDark or parent.GeminiThemed) then
        for _, d in ipairs(defs) do
            local b = parent:Button(d.label)
            if d.fn then b.DoClick = d.fn end
        end
        return {}
    end
    local grid = vgui.Create("DPanel", parent)
    grid:Dock(TOP)
    grid:DockMargin(0, 0, 0, 6)
    grid:SetTall(T.SZ(32))
    grid.Paint = function() end
    grid.GeminiBtns = {}
    for _, d in ipairs(defs) do
        local b = T.AccentButton(grid, d.label)
        b:Dock(NODOCK)
        b:DockMargin(0, 0, 0, 0)
        b.btnFont = "GeminiSmall"
        if d.fn then b.DoClick = d.fn end
        if d.tip then T.Tooltip(b, d.tip) end
        grid.GeminiBtns[#grid.GeminiBtns + 1] = b
    end
    grid.PerformLayout = function(self)
        local W = self:GetWide()
        if W <= 0 then return end
        -- Сколько места просит каждая кнопка (текст + поля)
        surface.SetFont("GeminiSmall")
        local need = {}
        for i, b in ipairs(self.GeminiBtns) do
            if IsValid(b) then
                local tw = surface.GetTextSize(b.btnLabel or "")
                -- +1px трекинга на букву: рисуем с отступами
                local okc, cc = pcall(utf8.len, b.btnLabel or "")
                if not okc or not cc then cc = 0 end
                need[i] = math.max(tw + 28 + cc, 120)
            else
                need[i] = 0
            end
        end
        -- Жадные ряды: больше 3 нельзя, уже текста — хоть по одной.
        -- Хвост-одиночка без пары выглядит глупо: забираем один
        -- из прошлого ряда (3+1 -> 2+2), если влезает
        local gap, rowH, rowGap = 8, T.SZ(30), 6
        local rows = {}
        local y, i, n = 0, 1, #self.GeminiBtns
        local function fits(from, count, W)
            local share = (W - gap * (count - 1)) / count
            for j = from, from + count - 1 do
                if (need[j] or 0) > share then return false end
            end
            return true
        end
        while i <= n do
            local k = 1
            for try = math.min(3, n - i + 1), 1, -1 do
                if fits(i, try, W) then k = try break end
            end
            rows[#rows + 1] = { from = i, count = k }
            i = i + k
        end
        if #rows >= 2 then
            local last = rows[#rows]
            local prev = rows[#rows - 1]
            if last.count == 1 and prev.count > 1 then
                -- Делим хвост поровну: последние (m+1) кнопок на два ряда
                local total = prev.count + 1
                local first = math.ceil(total / 2)
                if fits(prev.from, first, W)
                    and fits(prev.from + first, total - first, W) then
                    prev.count = first
                    last.from = prev.from + first
                    last.count = total - first
                end
            end
        end
        for _, r in ipairs(rows) do
            local share = (W - gap * (r.count - 1)) / r.count
            local x = 0
            for j = r.from, r.from + r.count - 1 do
                local b = self.GeminiBtns[j]
                if IsValid(b) then
                    local lastInRow = (j == r.from + r.count - 1)
                    local bw = (not lastInRow) and math.floor(share) or (W - math.floor(x))
                    b:SetPos(math.floor(x), y)
                    b:SetSize(bw, rowH)
                end
                x = x + share + gap
            end
            y = y + rowH + rowGap
        end
        local tall = math.max(rowH, y - rowGap)
        if self:GetTall() ~= tall then self:SetTall(tall) end
    end
    return { grid }
end

-- Мини-диалог ввода: у него свой попап, поэтому печать работает всегда.
-- Окна при этом остаются в режиме ходьбы (им фокус не нужен вообще).
GeminiBots.AskFrame = nil

local function ShortenValue(v, n)
    v = tostring(v or "")
    local ok, l = pcall(utf8.len, v)
    if not ok or not l or l <= n then return v end
    local ok2, pos = pcall(utf8.offset, v, n + 1)
    if not ok2 or not pos then return v end
    return string.sub(v, 1, pos - 1) .. "…"
end

function T.AskText(title, initial, isNumeric, onLive, onConfirm, onCancel)
    -- Один диалог на сессию, переиспользуем: плодить окна запрещено
    -- структурно, а не проверками (проверки гонки не держат)
    local f = IsValid(GeminiBots.AskFrame) and GeminiBots.AskFrame or nil
    if not f then
        local ru0 = GeminiBots.GetMenuLang() == "ru"
        f = vgui.Create("DFrame")
        GeminiBots.AskFrame = f
        f:SetSize(T.SZ(400), T.SZ(150))
        f:Center()
        f:SetTitle("")
        f:ShowCloseButton(false)
        f.OnRemove = function()
            if GeminiBots.AskFrame == f then GeminiBots.AskFrame = nil end
            gui.EnableScreenClicker(true)
        end
        function f:Paint(w, h)
            T.DrawBlur(self)
            local c = T.Corner()
            draw.RoundedBox(c, 0, 0, w, h, T.Colors.bg)
            draw.RoundedBoxEx(c, 0, 0, w, 44, T.Colors.header, true, true, false, false)
            T.DrawSpaced(self.GeminiTitle or "", "GeminiTitle", 14, 24,
                T.Colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1)
        end
        local FW = T.SZ(400)
        local xBtn = vgui.Create("DButton", f)
        xBtn:SetText("")
        xBtn:SetSize(44, 44)
        xBtn:SetPos(FW - 44, 0)
        xBtn.hover = 0
        function xBtn:Paint(w, h)
            self.hover = Lerp(FrameTime() * 12, self.hover or 0, self:IsHovered() and 1 or 0)
            draw.RoundedBoxEx(T.Corner(), 0, 0, w, h,
                ColorAlpha(T.Colors.red, self.hover * 255), false, true, false, false)
            draw.SimpleText("✕", "GeminiTitle", w / 2, h / 2,
                T.Colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        xBtn.DoClick = function()
            T.ClickSound()
            if f.GeminiFinish then f.GeminiFinish(false) end
        end
        local entry = vgui.Create("DTextEntry", f)
        entry:SetPos(10, 54)
        entry:SetSize(FW - 20, T.SZ(30))
        entry:SetFont("GeminiText")
        T.StyleTextEntry(entry)
        f.GeminiEntry = entry
        local bw = math.floor((FW - 20 - 8) / 2)
        local by = 54 + T.SZ(30) + 10
        local bOk = T.AccentButton(f, "OK")
        bOk:Dock(NODOCK)
        bOk:SetPos(10, by)
        bOk:SetSize(bw, T.SZ(30))
        f.GeminiOk = bOk
        local bNo = T.AccentButton(f, ru0 and "Отмена" or "Cancel")
        bNo:Dock(NODOCK)
        bNo:SetPos(10 + bw + 8, by)
        bNo:SetSize(FW - 20 - bw - 8, T.SZ(30))
        f.GeminiNo = bNo
        f.Think = function(self)
            if input.WasKeyPressed(KEY_ESCAPE) and self.GeminiFinish then
                self.GeminiFinish(false)
            end
        end
        T.MakeDraggable(f, 44)
    end
    -- Новое открытие: поколение +1, старые колбэки протухают
    f.GeminiGen = (f.GeminiGen or 0) + 1
    local myGen = f.GeminiGen
    local ru = GeminiBots.GetMenuLang() == "ru"
    f.GeminiTitle = title or ""
    f.GeminiDone = false
    local entry = f.GeminiEntry
    entry:SetNumeric(isNumeric and true or false)
    entry:SetText(tostring(initial or ""))
    entry:RequestFocus()
    entry:SelectAllText()
    local function finish(ok, val)
        if f.GeminiGen ~= myGen or f.GeminiDone then return end
        f.GeminiDone = true
        if ok and onConfirm then onConfirm(val) end
        if not ok and onCancel then onCancel() end
        local fadeCvC = GetConVar("geminibots_menu_fade")
        if fadeCvC and not fadeCvC:GetBool() then
            f:Remove()
        else
            f:AlphaTo(0, 0.15, 0, function()
                if IsValid(f) and f.GeminiGen == myGen then f:Remove() end
            end)
        end
    end
    f.GeminiFinish = finish
    entry.OnEnter = function(self) finish(true, self:GetValue()) end
    entry.OnChange = function(self)
        if onLive then onLive(self:GetValue()) end
    end
    f.GeminiOk.DoClick = function() finish(true, entry:GetValue()) end
    f.GeminiNo.btnLabel = ru and "Отмена" or "Cancel"
    f.GeminiNo.DoClick = function() finish(false) end
    gui.EnableScreenClicker(false)
    f:MakePopup()
    f:MoveToFront()
    f:SetVisible(true)
    local fadeCvD = GetConVar("geminibots_menu_fade")
    if not fadeCvD or fadeCvD:GetBool() then
        f:SetAlpha(0)
        f:AlphaTo(255, 0.18, 0)
    else
        f:SetAlpha(255)
    end
    return f
end
function T.MakeDraggable(frame, headerH)
    headerH = headerH or 46
    frame:SetDraggable(false)
    frame.GeminiDrag = nil
    function frame:OnMousePressed(code)
        if code == MOUSE_LEFT then
            local _, y = self:CursorPos()
            if y ~= nil and y < headerH then
                self.GeminiDrag = { x = gui.MouseX() - self:GetX(), y = gui.MouseY() - self:GetY() }
                self:MouseCapture(true)
            end
        end
    end
    function frame:OnMouseReleased(code)
        if code == MOUSE_LEFT and self.GeminiDrag then
            self.GeminiDrag = nil
            self:MouseCapture(false)
        end
    end
    local OldThink = frame.Think
    function frame:Think()
        if OldThink then OldThink(self) end
        if self.GeminiDrag then
            if input.IsMouseDown(MOUSE_LEFT) then
                self:SetPos(gui.MouseX() - self.GeminiDrag.x, gui.MouseY() - self.GeminiDrag.y)
                -- За экран не утащить: шапка обязана остаться доступной
                T.ClampToScreen(self)
            else
                self.GeminiDrag = nil
                self:MouseCapture(false)
            end
        end
    end
end

-- Держать окно в пределах экрана (шапка всегда доступна для захвата)
function T.ClampToScreen(frame)
    if not IsValid(frame) then return end
    local w, h = frame:GetSize()
    local x, y = frame:GetPos()
    x = math.Clamp(x, -w + 140, ScrW() - 140)
    y = math.Clamp(y, 0, math.max(0, ScrH() - 60))
    frame:SetPos(x, y)
end
local WINPOS_FILE = "geminibots/ui_pos.json"

function T.SaveWinPos(key, frame)
    if not IsValid(frame) then return end
    local x, y = frame:GetPos()
    local all = {}
    if file.Exists(WINPOS_FILE, "DATA") then
        all = util.JSONToTable(file.Read(WINPOS_FILE, "DATA") or "") or {}
    end
    if not istable(all) then all = {} end
    all[key] = { x = x, y = y }
    file.Write(WINPOS_FILE, util.TableToJSON(all))
end

function T.LoadWinPos(key, frame)
    if not IsValid(frame) then return end
    if not file.Exists(WINPOS_FILE, "DATA") then
        frame:Center()
        return
    end
    local all = util.JSONToTable(file.Read(WINPOS_FILE, "DATA") or "")
    if not istable(all) or not istable(all[key]) then
        frame:Center()
        return
    end
    local x = math.Clamp(all[key].x or 0, 0, math.max(0, ScrW() - 200))
    local y = math.Clamp(all[key].y or 0, 0, math.max(0, ScrH() - 100))
    frame:SetPos(x, y)
    -- Позиция могла сохраниться с другого разрешения: втягиваем обратно
    T.ClampToScreen(frame)
end
