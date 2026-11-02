--[[
    GeminiBots - Standalone Settings Window (Client)
    Отдельное окно настроек: левый сайдбар (4 раздела), справа контент
    в скролле. Открывается командой geminibots_menu — работает в любом
    режиме, включая Murder. Бинд: bind p geminibots_menu.
    Контролы строит тот же BuildSettingsMenu, что и Q-меню, но через шимы
    на темную тему (cl_theme.lua): тоглы, слайдеры, кнопки, секции.
    Q-меню не трогаем — там нативный вид.
]]

GeminiBots = GeminiBots or {}
GeminiBots.SettingsFrame = GeminiBots.SettingsFrame or nil

local FIT_TIMER = "GeminiBots_SettingsFit"

-- Строка по языку меню: { ru=..., uk=..., es=..., pt=..., en=... }, нет своей — английская
local function L(t)
    return GeminiBots.LangStr(t)
end

local TABS = {
    { id = "main", ru = "Основные", uk = "Основні", es = "General", pt = "Geral", en = "Main", icon = "cog" },
    { id = "weapons", ru = "Оружие", uk = "Зброя", es = "Armas", pt = "Armas", en = "Weapons", icon = "gun" },
    { id = "combat", ru = "Бой и движение", uk = "Бій і рух", es = "Combate", pt = "Combate", en = "Combat", icon = "bomb" },
    { id = "admin", ru = "Админ", uk = "Адмін", es = "Admin", pt = "Admin", en = "Admin", icon = "shield" },
    { id = "menu", ru = "Меню", uk = "Меню", es = "Interfaz", pt = "Interface", en = "Menu", icon = "palette" },
    { id = "about", ru = "Об аддоне", uk = "Про аддон", es = "Acerca de", pt = "Sobre", en = "About", icon = "info" },
}

-- Шимы методов панели под интерфейс построителя меню (темные контролы)
local function ShimForm(form)
    form:SetName("")
    form.Paint = function() end
    -- Метка темной темы: по ней сетка кнопок решает, рисовать темно или нативно
    form.GeminiThemed = true
    function form:ClearControls()
        -- Чистим детей вручную: штатный Clear оставляет мусор и дублирует контент
        for _, ch in ipairs(self:GetChildren()) do
            if IsValid(ch) then ch:Remove() end
        end
        if self.Items then self.Items = {} end
    end
    function form:Help(text)
        text = tostring(text or "")
        local t = string.Trim(text)
        if t == "" then return end
        if string.StartWith(t, "---") or string.StartWith(t, "===") then
            GeminiBots.Theme.SectionHeader(self, t)
        else
            GeminiBots.Theme.MutedLabel(self, text)
        end
    end
    function form:CheckBox(label, convarName)
        return GeminiBots.Theme.ToggleRow(self, label, convarName)
    end
    function form:NumSlider(label, convarName, min, max, decimals)
        return GeminiBots.Theme.SliderRow(self, label, convarName, min, max, decimals)
    end
    function form:Button(label)
        return GeminiBots.Theme.AccentButton(self, label)
    end
    function form:TextEntry(label)
        -- Кнопка-значение вместо поля: клик открывает диалог ввода
        -- (полям фокус не дают, печатать в них нельзя напрямую)
        local T = GeminiBots.Theme
        local b = T.AccentButton(self, tostring(label or ""))
        b.GeminiValue = ""
        function b:GetValue() return self.GeminiValue end
        local function RefreshLabel()
            local v = b.GeminiValue
            local ok, l = pcall(utf8.len, v)
            if ok and l and l > 28 then
                local _, pos = pcall(utf8.offset, v, 29)
                if pos then v = string.sub(v, 1, pos - 1) .. "…" end
            end
            b.btnLabel = tostring(label or "") .. " " .. v
        end
        RefreshLabel()
        b.DoClick = function()
            T.ClickSound()
            T.AskText(label, b.GeminiValue, false, nil, function(v)
                b.GeminiValue = v or ""
                RefreshLabel()
            end)
        end
        self:InvalidateLayout()
        return b
    end
end

-- Высота формы по нижнему ребенку с запасом. Меряем после layout:
-- переносы строк меняют высоту.
local function FitForm(form)
    if not IsValid(form) then return end
    form:InvalidateLayout(true)
    local bottom = 12
    for _, ch in ipairs(form:GetChildren()) do
        if IsValid(ch) then
            bottom = math.max(bottom, (ch:GetY() or 0) + (ch:GetTall() or 0) + 4)
        end
    end
    form:SetTall(math.max(bottom + 8, 120))
end

local function BuildTab(frame, id)
    local data = frame.GeminiForms and frame.GeminiForms[id]
    if not data then return end
    if id == "menu" then
        -- Вкладка меню строится через свою функцию ниже по файлу
        GeminiBots.BuildMenuTabInner(frame, data.form)
    elseif id == "about" then
        GeminiBots.BuildAboutTabInner(frame, data.form)
    else
        GeminiBots.SetSettingsTarget(data.form, id, { noSharedHeader = true })
        GeminiBots.BuildSettingsMenu(data.form, id, { noSharedHeader = true })
    end
    FitForm(data.form)
    -- Подсветка активного пункта сайдбара
    for tid, nav in pairs(frame.GeminiNav or {}) do
        if IsValid(nav) then nav.activeTab = (tid == id) end
    end
end

-- Вкладка "Об аддоне": кратко, версия, создатели, ссылка на GitHub
function GeminiBots.BuildAboutTabInner(frame, form)
    form:ClearControls()
    local T = GeminiBots.Theme
    form.GeminiIsMenuTab = true
    GeminiBots.SetSettingsTarget(form, "about", { noSharedHeader = true })

    local head = vgui.Create("DPanel", form)
    head:Dock(TOP)
    head:SetTall(T.SZ(64))
    head:DockMargin(0, 0, 0, 6)
    head.Paint = function(_, w, h)
        T.DrawLogo(T.LogoVariant(), 8, math.floor((h - 40) / 2), 40, T.Colors.accent)
        T.DrawSpaced("GeminiBots", "GeminiHeader", 58, math.floor(h / 2) - 10,
            T.Colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1)
        T.DrawSpaced(L{
        ru = "Живые боты для Garry's Mod", uk = "Живі боти для Garry's Mod",
        es = "Bots vivos para Garry's Mod", pt = "Bots vivos para Garry's Mod",
        en = "Smarter bots for Garry's Mod" },
            "GeminiSmall", 59, math.floor(h / 2) + 12,
            T.Colors.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1)
    end

    T.MutedLabel(form, L{
        ru = "Версия: 1.0.0", uk = "Версія: 1.0.0",
        es = "Versión: 1.0.0", pt = "Versão: 1.0.0", en = "Version: 1.0.0" })
    T.MutedLabel(form, L{
        ru = "Автор: mcarabic98", uk = "Автор: mcarabic98",
        es = "Autor: mcarabic98", pt = "Autor: mcarabic98", en = "Author: mcarabic98" })
    T.MutedLabel(form, L{
        ru = "Совместная разработка (фуу вайбкод): Muse Spark 1.3 (rip 17.10.2026), Gemini 3.8 Flash (страшные лимиты), Deepsek v4.1 flash (на смену Muse)",
        uk = "Спільна розробка (фуу вайбкод): Muse Spark 1.3 (rip 17.10.2026), Gemini 3.8 Flash (страшні ліміти), Deepsek v4.1 flash (на зміну Muse)",
        es = "Codesarrollado con (puaj, vibecode): Muse Spark 1.3 (rip 17.10.2026), Gemini 3.8 Flash (límites de miedo), Deepseek v4.1 flash (reemplazó a Muse)",
        pt = "Codesenvolvido com (aff, vibecode): Muse Spark 1.3 (rip 17.10.2026), Gemini 3.8 Flash (limites assustadores), Deepseek v4.1 flash (no lugar do Muse)",
        en = "Co-developed with (eww vibecode): Muse Spark 1.3 (rip 17.10.2026), Gemini 3.8 Flash (scary limits), Deepseek v4.1 flash (replaced Muse)" })
    T.MutedLabel(form, L{
        ru = "ИИ стандартных ботов: бой, чувства, чат, оружие, режимы.",
        uk = "ІІ стандартних ботів: бій, почуття, чат, зброя, режими.",
        es = "IA de los bots estándar: combate, sentidos, chat, armas, modos.",
        pt = "IA dos bots padrão: combate, sentidos, chat, armas, modos.",
        en = "Stock bot AI: combat, senses, chat, weapons, gamemodes." })

    local btnGH = T.AccentButton(form, "GitHub: mcarabic98/geminibots")
    btnGH.DoClick = function()
        T.ClickSound()
        gui.OpenURL("https://github.com/mcarabic98/geminibots")
    end
    T.Tooltip(btnGH, "https://github.com/mcarabic98/geminibots")
end

-- Вкладка "Меню" (только здесь): настройки интерфейса. Храним в GeminiBots,
-- чтобы построитель видел ее сверху файла. Сетевые пересборки ее не трогают.
function GeminiBots.BuildMenuTabInner(frame, form)
    form:ClearControls() -- без этого каждый ребилд (смена темы/языка) дописывает копию
    local T = GeminiBots.Theme
    form.GeminiIsMenuTab = true
    GeminiBots.SetSettingsTarget(form, "menu", { noSharedHeader = true })

    local function header(text)
        local l = T.SpacedLabel(form, T.SZ(24))
        l:DockMargin(0, 2, 0, 4)
        l.GeminiText = text
        l.GeminiFont = "GeminiHeader"
        l.GeminiColor = T.Colors.accent
    end

    header(L{
        ru = "Тема оформления", uk = "Тема оформлення", es = "Tema visual",
        pt = "Tema visual", en = "Color theme" })

    -- Две темы рядом: выбранная залита акцентом (как вкл),
    -- вторая темная (как выкл). Без обводок
    local themeRow = vgui.Create("DPanel", form)
    themeRow:Dock(TOP)
    themeRow:SetTall(T.SZ(28))
    themeRow:DockMargin(0, 0, 0, 6)
    themeRow.Paint = function() end
    local cur = T.CurrentTheme()
    local function ThemeBtn(label, id, active)
        local b = vgui.Create("DButton", themeRow)
        b:SetText("")
        b.hover = 0
        b.btnLabel = label
        function b:Paint(w, h)
            self.hover = Lerp(FrameTime() * 12, self.hover or 0, self:IsHovered() and 1 or 0)
            local c = T.Corner()
            local base = active and T.Colors.accent or T.Colors.row
            T.RBox(0, 0, w, h, c, T.Mix(base, T.Colors.accent, (self.hover or 0) * 0.25))
            draw.SimpleText(self.btnLabel, "GeminiText", w / 2, h / 2,
                T.Colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            T.ClickSound()
            T.WriteConVar("geminibots_menu_theme", id)
            BuildTab(frame, "menu")
        end
        return b
    end
    local btnDark = ThemeBtn(L{
        ru = "Тёмная", uk = "Темна", es = "Oscura",
        pt = "Escura", en = "Dark" }, "dark", cur == "dark")
    local btnLight = ThemeBtn(L{
        ru = "Светлая", uk = "Світла", es = "Clara",
        pt = "Clara", en = "Light" }, "light", cur ~= "dark")
    btnDark:Dock(LEFT)
    btnLight:Dock(RIGHT)
    btnDark:DockMargin(0, 0, 4, 0)
    btnLight:DockMargin(4, 0, 0, 0)
    themeRow.PerformLayout = function(self)
        local half = math.floor((self:GetWide() - 8) / 2)
        btnDark:SetWide(half)
        btnLight:SetWide(half)
    end

    header(L{
        ru = "Акцентный цвет", uk = "Акцентний колір", es = "Color de acento",
        pt = "Cor de destaque", en = "Accent color" })

    -- Пресеты- swatches + свой цвет через миксер
    local swatches = vgui.Create("DPanel", form)
    swatches:Dock(TOP)
    swatches:DockMargin(0, 0, 0, 6)
    swatches:SetTall(T.SZ(36))
    swatches.Paint = function() end
    -- 9 акцентов Catppuccin Mocha слева, свой цвет на второй половине
    local presetHex = { "F38BA8", "FAB387", "F9E2AF", "A6E3A1", "94E2D5",
        "89DCEB", "89B4FA", "B4BEFE", "CBA6F7" }
    local curAccent = T.CurrentAccent():upper()
    local swList = {}
    local btnCustom -- ниже, PerformLayout дергает раньше по времени, но позже по коду
    for _, hex in ipairs(presetHex) do
        local sw = vgui.Create("DButton", swatches)
        sw:Dock(LEFT)
        sw:DockMargin(0, 4, 4, 4)
        sw:SetWide(T.SZ(34))
        sw:SetText("")
        sw.swatchHex = hex
        function sw:Paint(w, h)
            local n = tonumber(self.swatchHex, 16)
            local c = Color(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
            -- Без обводки выбранного: цвет применяется сразу, видно и так.
            -- Радиус едет за скруглением: при 0 — квадраты
            T.RBox(0, 0, w, h, math.min(h / 2, T.Corner()), c)
        end
        sw.DoClick = function()
            T.ClickSound()
            T.WriteConVar("geminibots_menu_accent", hex)
            T.ApplyAccent(hex, true)
            BuildTab(frame, "menu")
        end
        swList[#swList + 1] = sw
    end
    -- Граница ровно по середине (как у тем выше): свотчи слева,
    -- остаток до середины добираем отступом кнопки
    swatches.PerformLayout = function(self)
        local half = math.floor((self:GetWide() - 8) / 2)
        local swW = math.max(20, math.floor((half - 36) / 9))
        for _, sw in ipairs(swList) do
            if IsValid(sw) then sw:SetWide(swW) end
        end
        if IsValid(btnCustom) then
            btnCustom:DockMargin(half - 9 * (swW + 4) + 4, 4, 0, 4)
        end
    end
    -- Свой цвет на второй половине ряда свотчей
    btnCustom = T.AccentButton(swatches, L{
        ru = "Свой цвет...", uk = "Свій колір...", es = "Color personalizado...",
        pt = "Cor personalizada...", en = "Custom color..." })
    btnCustom:Dock(FILL)
    btnCustom:DockMargin(4, 4, 0, 4)
    btnCustom.DoClick = function()
        T.ClickSound()
        -- Один миксер: повторный клик фокусит открытый
        if IsValid(GeminiBots.MixerFrame) then
            GeminiBots.MixerFrame:MoveToFront()
            GeminiBots.MixerFrame:MakePopup()
            return
        end
        -- Миксер в нашей теме, а не серое окно движка
        local mf = vgui.Create("DFrame")
        GeminiBots.MixerFrame = mf
        mf:SetSize(T.SZ(320), T.SZ(400))
        mf:Center()
        mf:SetTitle("")
        mf:ShowCloseButton(false)
        mf:MakePopup()
        mf.OnRemove = function() GeminiBots.MixerFrame = nil end
        T.MakeDraggable(mf, 44)
        -- Появление fade'ом как у остальных окон
        local fadeCvM = GetConVar("geminibots_menu_fade")
        if not fadeCvM or fadeCvM:GetBool() then
            mf:SetAlpha(0)
            mf:AlphaTo(255, 0.18, 0)
        end
        local function CloseMixer()
            local fadeCvC = GetConVar("geminibots_menu_fade")
            if fadeCvC and not fadeCvC:GetBool() then
                mf:Remove()
            else
                mf:AlphaTo(0, 0.15, 0, function()
                    if IsValid(mf) then mf:Remove() end
                end)
            end
        end
        function mf:Paint(w, h)
            T.DrawBlur(self)
            local c = T.Corner()
            draw.RoundedBox(c, 0, 0, w, h, T.Colors.bg)
            draw.RoundedBoxEx(c, 0, 0, w, 44, T.Colors.header, true, true, false, false)
            T.DrawSpaced(L{
                ru = "Свой акцентный цвет", uk = "Свій акцентний колір",
                es = "Color de acento personalizado", pt = "Cor de destaque personalizada",
                en = "Custom accent color" },
                "GeminiTitle", 14, 22, T.Colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1)
        end
        -- Крестик: случайно открыл — закрыл
        local xBtn = vgui.Create("DButton", mf)
        xBtn:SetText("")
        xBtn:SetSize(44, 44)
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
            CloseMixer()
        end
        mf.PerformLayout = function(self)
            xBtn:SetPos(self:GetWide() - 44, 0)
        end
        -- Кнопка снизу, миксер занимает остальное: без налезания и дыр
        local okb = T.AccentButton(mf, L{
            ru = "Выбрать", uk = "Обрати", es = "Elegir",
            pt = "Escolher", en = "Pick" })
        okb:Dock(BOTTOM)
        okb:DockMargin(10, 0, 10, 10)
        local mixer = vgui.Create("DColorMixer", mf)
        mixer:Dock(FILL)
        mixer:DockMargin(10, 54, 10, 6)
        mixer:SetColor(Color(88, 101, 242))
        okb.DoClick = function()
            local c = mixer:GetColor()
            local hex = string.format("%02X%02X%02X", c.r, c.g, c.b)
            T.WriteConVar("geminibots_menu_accent", hex)
            T.ApplyAccent(hex, true)
            CloseMixer()
            BuildTab(frame, "menu")
        end
    end

    header(L{
        ru = "Геометрия", uk = "Геометрія", es = "Geometría",
        pt = "Geometria", en = "Geometry" })
    -- Выбор шрифта кнопкой-переключателем
    local btnFont = T.AccentButton(form, "")
    btnFont.DoClick = function()
        T.ClickSound()
        local cur = T.FontFace()
        local idx = 1
        for i, f in ipairs(T.FontFaces) do
            if f == cur then idx = i break end
        end
        T.WriteConVar("geminibots_menu_font", T.FontFaces[(idx % #T.FontFaces) + 1])
        T.BuildFonts()
    end
    btnFont.Think = function(self)
        self.btnLabel = L{
            ru = "Шрифт: ", uk = "Шрифт: ", es = "Fuente: ",
            pt = "Fonte: ", en = "Font: " } .. T.FontFace()
    end
    T.Tooltip(btnFont, T.CvarTip("geminibots_menu_font"))
    T.SliderRow(form, L{
        ru = "Скругление углов (0-16)", uk = "Заокруглення кутів (0-16)",
        es = "Radio de esquinas (0-16)", pt = "Raio dos cantos (0-16)",
        en = "Corner radius (0-16)" },
        "geminibots_menu_corner", 0, 16, 0)
    T.SliderRow(form, L{
        ru = "Масштаб интерфейса (0.85-1.15)", uk = "Масштаб інтерфейсу (0.85-1.15)",
        es = "Escala de la interfaz (0.85-1.15)", pt = "Escala da interface (0.85-1.15)",
        en = "UI scale (0.85-1.15)" },
        "geminibots_menu_scale", 0.85, 1.15, 2)

    header(L{
        ru = "Эффекты", uk = "Ефекти", es = "Efectos",
        pt = "Efeitos", en = "Effects" })
    T.SliderRow(form, L{
        ru = "Размытие", uk = "Розмиття", es = "Desenfoque",
        pt = "Desfoque", en = "Blur" },
        "geminibots_menu_blur", 0, 3, 0)
    T.ToggleRow(form, L{
        ru = "Анимации открытия/закрытия", uk = "Анімації відкриття/закриття",
        es = "Animaciones de abrir/cerrar", pt = "Animações de abrir/fechar",
        en = "Open/close animations" }, "geminibots_menu_fade")
    T.ToggleRow(form, L{
        ru = "Звуки кликов", uk = "Звуки кліків", es = "Sonidos de clic",
        pt = "Sons de clique", en = "Click sounds" }, "geminibots_menu_sounds")

    -- Режим частиц кнопкой-переключателем: выкл/созвездие/снег/дождь
    local btnParticles = T.AccentButton(form, "")
    btnParticles.DoClick = function()
        T.ClickSound()
        local cur = T.ParticleMode()
        local idx = 1
        for i, m in ipairs(T.ParticleModes) do
            if m == cur then idx = i break end
        end
        T.WriteConVar("geminibots_menu_particles",
            T.ParticleModes[(idx % #T.ParticleModes) + 1])
    end
    btnParticles.Think = function(self)
        self.btnLabel = L{
            ru = "Частицы: ", uk = "Частинки: ", es = "Partículas: ",
            pt = "Partículas: ", en = "Particles: " }
            .. T.ParticleModeName(T.ParticleMode())
    end
    T.Tooltip(btnParticles, T.CvarTip("geminibots_menu_particles"))
    T.ToggleRow(form, L{
        ru = "Частицы в цвете акцента", uk = "Частинки в кольорі акценту",
        es = "Partículas en color de acento", pt = "Partículas na cor de destaque",
        en = "Accent-colored particles" },
        "geminibots_menu_particles_accent")

    GeminiBots.Theme.ButtonGrid(form, {
        { label = L{
            ru = "Сбросить оформление", uk = "Скинути оформлення",
            es = "Restablecer apariencia", pt = "Redefinir aparência",
            en = "Reset appearance" }, fn = function()
            T.ClickSound()
            T.WriteConVar("geminibots_menu_theme", "dark")
            T.WriteConVar("geminibots_menu_accent", "5865F2")
            T.WriteConVar("geminibots_menu_corner", "8")
            T.WriteConVar("geminibots_menu_scale", "1.0")
            T.WriteConVar("geminibots_menu_blur", "0")
            T.WriteConVar("geminibots_menu_sounds", "1")
            T.WriteConVar("geminibots_menu_fade", "1")
            T.WriteConVar("geminibots_menu_particles", "stars")
            T.WriteConVar("geminibots_menu_particles_accent", "1")
            T.WriteConVar("geminibots_menu_logo", "0")
            T.WriteConVar("geminibots_menu_font", "Roboto")
            BuildTab(frame, "menu")
        end },
        { label = L{
            ru = "Сбросить позицию окон", uk = "Скинути позицію вікон",
            es = "Restablecer posición de ventanas", pt = "Redefinir posição das janelas",
            en = "Reset window positions" }, fn = function()
            T.ClickSound()
            file.Delete("geminibots/ui_pos.json")
            BuildTab(frame, "menu")
        end },
    })

    T.MutedLabel(form, L{
        ru = "Открытие/закрытие окна: bind p geminibots_menu",
        uk = "Відкриття/закриття вікна: bind p geminibots_menu",
        es = "Abrir/cerrar ventana: bind p geminibots_menu",
        pt = "Abrir/fechar janela: bind p geminibots_menu",
        en = "Toggle window: bind p geminibots_menu" })
end

local function SwitchTab(frame, id, animate)
    if not frame.GeminiForms or not frame.GeminiForms[id] then return end
    -- Запоминаем вкладку: в следующий раз откроемся на ней же
    GeminiBots.Theme.WriteConVar("geminibots_menu_tab", id)
    for tid, data in pairs(frame.GeminiForms) do
        if IsValid(data.scroll) then
            data.scroll:SetVisible(tid == id)
        end
    end
    frame.GeminiCurrent = id
    BuildTab(frame, id)
    -- Плавная смена вкладки: контент проявляется fade'ом
    if animate then
        local cv = GetConVar("geminibots_menu_fade")
        local sc = frame.GeminiForms[id].scroll
        if (not cv or cv:GetBool()) and IsValid(sc) then
            sc:SetAlpha(0)
            sc:AlphaTo(255, 0.15, 0)
        end
    end
end

local function StartFitTimer(frame)
    if timer.Exists(FIT_TIMER) then timer.Remove(FIT_TIMER) end
    timer.Create(FIT_TIMER, 0.5, 0, function()
        local fr = GeminiBots.SettingsFrame
        if not IsValid(fr) then
            timer.Remove(FIT_TIMER)
            return
        end
        local cur = fr.GeminiCurrent
        if cur and fr.GeminiForms and fr.GeminiForms[cur] then
            FitForm(fr.GeminiForms[cur].form)
        end
    end)
end

function GeminiBots.OpenSettings()
    if IsValid(GeminiBots.SettingsFrame) then
        -- Как при первом открытии: мышь окну, клавиатура игре, позиция —
        -- сохраненная. MakePopup здесь запрещен: он захватывает клавиатуру,
        -- и WASD перестают идти в игру
        local fr = GeminiBots.SettingsFrame
        fr:SetMouseInputEnabled(true)
        fr:SetKeyboardInputEnabled(false)
        gui.EnableScreenClicker(true)
        fr:MoveToFront()
        return fr
    end

    local T = GeminiBots.Theme
    local frame = vgui.Create("DFrame")
    local W = math.min(ScrW() * 0.95, T.SZ(960))
    local H = math.min(ScrH() * 0.9, T.SZ(680))
    frame:SetSize(W, H)
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(true)
    -- Без захвата клавиатуры: WASD идут в игру, с открытым меню можно ходить.
    -- Печатать в поля ввода при этом не выйдет (фокус клавиатуры у игры).
    frame:SetMouseInputEnabled(true)
    frame:SetKeyboardInputEnabled(false)
    -- Курсор отдельно: без MakePopup движок его не показывает,
    -- тогда кликать можно только с открытым чатом
    gui.EnableScreenClicker(true)
    frame:MoveToFront()
    GeminiBots.SettingsFrame = frame
    frame.GeminiOpenedAt = CurTime()
    -- Частицы фона: точки в относительных координатах (живут при ресайзе).
    -- Набор зависит от режима, при смене режима пересоздаем
    frame.GeminiDots = {}
    frame.GeminiPMode = nil
    T.LoadWinPos("settings", frame)

    -- Открытый попап ест фокус клавиатуры, бинд движка не доходит:
    -- ловим клавишу сами. Пауза 0.3 сек, чтобы открытие сразу не закрывалось.
    do
        frame.GeminiToggleCode = nil
        local binding = input.LookupBinding("geminibots_menu")
        if binding and binding ~= "" and input.GetKeyCode then
            local code = input.GetKeyCode(binding)
            if code and code > 0 then
                frame.GeminiToggleCode = code
            end
        end
    end
    frame.Think = function(self)
        -- Частицы живут всегда, даже в первые 0.3 сек
        local pmode = T.ParticleMode()
        if pmode ~= self.GeminiPMode then
            self.GeminiPMode = pmode
            self.GeminiDots = {}
            local n = pmode == "snow" and 55 or (pmode == "rain" and 90
                or (pmode == "embers" and 60 or 28))
            for i = 1, n do
                self.GeminiDots[i] = { x = math.random(), y = math.random(),
                    vx = math.Rand(-0.02, 0.02), vy = math.Rand(-0.02, 0.02),
                    sp = math.Rand(0.7, 1.3), ph = math.Rand(0, 6.28) }
            end
        end
        local dt = FrameTime()
        if dt > 0 and pmode ~= "off" then
            if pmode == "snow" then
                -- Снег: медленно вниз с покачиванием
                for _, d in ipairs(self.GeminiDots) do
                    d.y = (d.y + 0.08 * d.sp * dt) % 1
                    d.x = (d.x + (math.sin(CurTime() * 0.7 + d.ph) * 0.012 + d.vx * 0.2) * dt) % 1
                end
            elseif pmode == "rain" then
                -- Дождь: летит по диагонали, черточка вдоль полета
                for _, d in ipairs(self.GeminiDots) do
                    d.y = (d.y + 1.1 * d.sp * dt) % 1
                    d.x = (d.x - 0.385 * d.sp * dt) % 1
                end
            elseif pmode == "embers" then
                -- Искры: тлеют вверх с покачиванием и мерцанием
                for _, d in ipairs(self.GeminiDots) do
                    d.y = (d.y - 0.16 * d.sp * dt) % 1
                    d.x = (d.x + (math.sin(CurTime() * 1.3 + d.ph) * 0.03 + d.vx * 0.2) * dt) % 1
                end
            else
                -- Созвездие: медленный дрейф
                for _, d in ipairs(self.GeminiDots) do
                    d.x = (d.x + d.vx * dt) % 1
                    d.y = (d.y + d.vy * dt) % 1
                end
            end
        end
        if CurTime() - (self.GeminiOpenedAt or 0) < 0.3 then return end
        local code = self.GeminiToggleCode
        if code and input.WasKeyPressed(code) then
            GeminiBots.CloseSettings()
        end
    end
    frame.OnKeyCodePressed = function(self, code)
        if code and code == self.GeminiToggleCode
            and CurTime() - (self.GeminiOpenedAt or 0) >= 0.3 then
            GeminiBots.CloseSettings()
        end
    end
    -- Перетаскивание цепляем последним, чужой Think внутри сохраняется
    T.MakeDraggable(frame, 46)

    local fadeCv = GetConVar("geminibots_menu_fade")
    if not fadeCv or fadeCv:GetBool() then
        frame:SetAlpha(0)
        frame:AlphaTo(255, 0.18, 0)
    end

    function frame:Paint(w, h)
        T.DrawBlur(self)
        local c = T.Corner()
        draw.RoundedBox(c, 0, 0, w, h, T.Colors.bg)
        draw.RoundedBoxEx(c, 0, 0, w, 46, T.Colors.header, true, true, false, false)
        -- Частицы за контентом (дети рисуются позже, поверх).
        -- Ниже шапки: на заголовок не лезем
        local pmode = frame.GeminiPMode
        if pmode and pmode ~= "off" and frame.GeminiDots then
            draw.NoTexture()
            local y0, hh = 46, math.max(1, h - 46)
            -- База цвета: акцент либо цвет текста темы (на светлой темный,
            -- на темной светлый — белые точки там больше не теряются)
            local pc = T.ParticleColor()
            if pmode == "rain" then
                for _, d in ipairs(frame.GeminiDots) do
                    local px, py = d.x * w, y0 + d.y * hh
                    local len = 10 * (d.sp or 1)
                    surface.SetDrawColor(pc.r, pc.g, pc.b, 40)
                    surface.DrawLine(px, py, px + 0.35 * len, py - len)
                end
            elseif pmode == "embers" then
                -- Тлеющие искры: оттенок акцента/темы, пульсирует только
                -- яркость (тон не трогаем — иначе акцент рыжеет)
                for _, d in ipairs(frame.GeminiDots) do
                    local px, py = d.x * w, y0 + d.y * hh
                    local fl = 0.5 + 0.5 * math.sin(CurTime() * (3 + (d.sp or 1)) + (d.ph or 0))
                    local a = math.Round(60 + 150 * fl)
                    local r = 1.5 + (d.sp or 1)
                    local e = 0.55 + 0.45 * fl
                    local er, eg, eb = math.Round(pc.r * e), math.Round(pc.g * e), math.Round(pc.b * e)
                    surface.SetDrawColor(er, eg, eb, a)
                    surface.DrawCircle(px, py, r, er, eg, eb, a)
                end
            else
                local pts = {}
                local dotA = pmode == "snow" and 55 or 40
                for _, d in ipairs(frame.GeminiDots) do
                    local px, py = d.x * w, y0 + d.y * hh
                    pts[#pts + 1] = { x = px, y = py }
                    surface.SetDrawColor(pc.r, pc.g, pc.b, dotA)
                    surface.DrawCircle(px, py, 2, pc.r, pc.g, pc.b, dotA)
                end
                if pmode == "stars" then
                    for i = 1, #pts do
                        for j = i + 1, #pts do
                            local dx, dy = pts[i].x - pts[j].x, pts[i].y - pts[j].y
                            local dist = math.sqrt(dx * dx + dy * dy)
                            if dist < 130 then
                                surface.SetDrawColor(pc.r, pc.g, pc.b,
                                    math.Round(22 * (1 - dist / 130)))
                                surface.DrawLine(pts[i].x, pts[i].y, pts[j].x, pts[j].y)
                            end
                        end
                    end
                end
            end
        end
        local title = L{
            ru = "GeminiBots — Настройки ботов", uk = "GeminiBots — Налаштування ботів",
            es = "GeminiBots — Ajustes de bots", pt = "GeminiBots — Configurações dos bots",
            en = "GeminiBots — Bot Settings" }
        T.DrawLogo(T.LogoVariant(), 14, 9, 28, T.Colors.accent)
        T.DrawSpaced(title, "GeminiTitle", 48, 24,
            T.Colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1)
        -- Счетчик ботов считаем прямо здесь: Paint идет каждый кадр,
        -- Think для этого ненадежен
        local ct = L{
            ru = string.format("ботов онлайн: %d/%d", #player.GetBots(), game.MaxPlayers()),
            uk = string.format("ботів онлайн: %d/%d", #player.GetBots(), game.MaxPlayers()),
            es = string.format("bots en línea: %d/%d", #player.GetBots(), game.MaxPlayers()),
            pt = string.format("bots online: %d/%d", #player.GetBots(), game.MaxPlayers()),
            en = string.format("bots online: %d/%d", #player.GetBots(), game.MaxPlayers()) }
        T.DrawSpaced(ct, "GeminiSmall", w - 104, 24,
            T.Colors.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 1)
    end

    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetText("")
    closeBtn:SetSize(46, 46)
    closeBtn:SetPos(W - 46, 0)
    closeBtn.hover = 0
    function closeBtn:Paint(w, h)
        self.hover = Lerp(FrameTime() * 12, self.hover or 0, self:IsHovered() and 1 or 0)
        draw.RoundedBoxEx(T.Corner(), 0, 0, w, h,
            ColorAlpha(T.Colors.red, self.hover * 255), false, true, false, false)
        draw.SimpleText("✕", "GeminiTitle", w / 2, h / 2,
            T.Colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function()
        T.ClickSound()
        GeminiBots.CloseSettings()
    end

    -- Кнопка языка в шапке. Настройка блюра живет во вкладке "Меню".
    local langBtn = vgui.Create("DButton", frame)
    langBtn:SetText("")
    langBtn:SetSize(46, 46)
    langBtn:SetPos(W - 46 - 48, 0)
    langBtn.hover = 0
    function langBtn:Paint(w, h)
        self.hover = Lerp(FrameTime() * 12, self.hover or 0, self:IsHovered() and 1 or 0)
        if self.hover > 0.01 then
            draw.RoundedBox(0, 0, 0, w, h, ColorAlpha(T.Colors.accent, self.hover * 80))
        end
        -- Режим: авто (язык GMod) либо ручной RU/UK/ES/PT/EN
        local mode = GeminiBots.MenuLangMode and GeminiBots.MenuLangMode() or "auto"
        local txt = mode
        if mode == "auto" then
            txt = (GeminiBots.GetMenuLang() == "ru") and "АВТО" or "AUTO"
        else
            txt = string.upper(mode)
        end
        draw.SimpleText(txt,
            "GeminiText", w / 2, h / 2, T.Colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    langBtn.DoClick = function()
        T.ClickSound()
        -- Пересборку (сайдбар, вкладка, арсенал) делает колбэк смены
        -- geminibots_menu_lang: он срабатывает уже после применения конвара
        GeminiBots.ToggleMenuLang()
    end

    -- Сайдбар навигации
    local nav = vgui.Create("DPanel", frame)
    nav:Dock(LEFT)
    nav:SetWide(T.SZ(180))
    nav:DockMargin(8, 54, 0, 8)
    nav.Paint = function(_, w, h)
        draw.RoundedBox(T.Corner(), 0, 0, w, h, T.Colors.header)
    end
    frame.GeminiNav = {}

    -- Контентная зона
    local content = vgui.Create("DPanel", frame)
    content:Dock(FILL)
    content:DockMargin(8, 54, 8, 8)
    content.Paint = function() end

    frame.GeminiForms = {}
    frame.GeminiCurrent = nil

    for _, t in ipairs(TABS) do
        local scroll = vgui.Create("DScrollPanel", content)
        scroll:Dock(FILL)
        scroll:SetVisible(false)
        T.SmoothScroll(scroll)
        -- Обычный DPanel вместо DForm: у формы свои категории и очистка,
        -- с ними контент дублируется и едет верстка.
        local form = vgui.Create("DPanel", scroll)
        form:Dock(TOP)
        form.Paint = function() end
        -- Метка для колбэка смены языка в cl_qmenu: эти панели он не трогает,
        -- их пересобирает свой колбэк (BuildTab + FitForm + подписи сайдбара)
        form.GeminiIsStandalone = true
        ShimForm(form)
        frame.GeminiForms[t.id] = { form = form, scroll = scroll }

        local nb = vgui.Create("DButton", nav)
        nb:Dock(TOP)
        nb:DockMargin(8, 8, 8, 0)
        nb:SetTall(T.SZ(40))
        nb:SetText("")
        nb.activeTab = false
        nb.hover = 0
        nb.titleRU = t.ru
        nb.titleEN = t.en
        -- Все языковые варианты сразу: в колбэке смены языка nb[lang]
        -- не находил ключи uk/es/pt и всегда падал в английский
        nb.GeminiLabels = t
        nb.navLabel = t[GeminiBots.GetMenuLang()] or t.en
        local tabId = t.id
        -- Иконка слева (своя векторная, красится в цвет текста)
        local nim = T.IconPanel(nb, t.icon or "cog")
        nim:SetPos(10, math.floor((nb:GetTall() - 20) / 2))
        nb.PerformLayout = function(self)
            nim:SetPos(10, math.floor((self:GetTall() - 20) / 2))
        end
        function nb:Paint(w, h)
            self.hover = Lerp(FrameTime() * 12, self.hover or 0, self:IsHovered() and 1 or 0)
            local c = T.Corner()
            -- Ховер меняет сам цвет кнопки, без оверлея
            if self.activeTab then
                T.RBox(0, 0, w, h, c,
                    T.Mix(T.Colors.accent, Color(255, 255, 255), (self.hover or 0) * 0.2))
            else
                T.RBox(0, 0, w, h, c,
                    T.Mix(T.Colors.row, T.Colors.accent, (self.hover or 0) * 0.35))
            end
            -- Активная вкладка и так залита акцентом, боковой тик лишний.
            -- Текст влево от иконки, мелким: длинные названия не режутся
            T.DrawSpaced(self.navLabel, "GeminiSmall", 38, h / 2,
                T.Colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1)
        end
        nb.DoClick = function()
            T.ClickSound()
            SwitchTab(frame, tabId, true)
        end
        frame.GeminiNav[t.id] = nb
    end

    -- Открываемся на запомненной вкладке (по умолчанию Основные)
    local startTab = "main"
    local tabCv = GetConVar("geminibots_menu_tab")
    if tabCv and frame.GeminiForms[tabCv:GetString()] then
        startTab = tabCv:GetString()
    end
    SwitchTab(frame, startTab)
    StartFitTimer(frame)

    return frame
end

function GeminiBots.CloseSettings()
    -- Диалог ввода закрываем первым (сам вернет курсор, мы заберем обратно)
    if IsValid(GeminiBots.AskFrame) then GeminiBots.AskFrame:Remove() end
    -- Курсор возвращаем игре (включали при открытии)
    gui.EnableScreenClicker(false)
    local fr = GeminiBots.SettingsFrame
    -- Арсенал — дочернее окно настроек: закрывается вместе с ними
    local ar = GeminiBots.ArsenalFrame
    if IsValid(ar) then
        local T = GeminiBots.Theme
        T.SaveWinPos("arsenal", ar)
        local fadeA = GetConVar("geminibots_menu_fade")
        if fadeA and not fadeA:GetBool() then
            ar:Remove()
        else
            ar:AlphaTo(0, 0.15, 0, function()
                if IsValid(ar) then ar:Remove() end
            end)
        end
        GeminiBots.ArsenalFrame = nil
    end
    if not IsValid(fr) then return end
    GeminiBots.Theme.SaveWinPos("settings", fr)
    local cv = GetConVar("geminibots_menu_fade")
    if cv and not cv:GetBool() then
        fr:Remove()
        return
    end
    fr:AlphaTo(0, 0.15, 0, function()
        if IsValid(fr) then fr:Remove() end
    end)
end

-- Пересбор открытых окон (смена темы/языка): текущая вкладка + Арсенал.
-- Для арсенала берем ApplyLang: он обновляет и подписи с цветами статичных
-- меток, а не только список строк
function GeminiBots.RefreshOpenWindows()
    local fr = GeminiBots.SettingsFrame
    if IsValid(fr) and fr.GeminiCurrent then
        BuildTab(fr, fr.GeminiCurrent)
    end
    local ar = GeminiBots.ArsenalFrame
    if IsValid(ar) then
        if ar.ApplyLang then ar:ApplyLang() else ar:RefreshList() end
    end
end

-- Смена языка меню: пересобираем открытые окна ПОСЛЕ применения конвара.
-- Раньше пересборка была только в кнопке языка, поэтому при смене языка
-- из консоли или Q-меню (а также при отложенном применении RunConsoleCommand)
-- окно оставалось на старом языке: заголовок уже новый, контент — старый
cvars.AddChangeCallback("geminibots_menu_lang", function()
    local fr = GeminiBots.SettingsFrame
    if IsValid(fr) then
        local lang = GeminiBots.GetMenuLang()
        for _, nb in pairs(fr.GeminiNav or {}) do
            if IsValid(nb) then
                local lbls = nb.GeminiLabels
                nb.navLabel = lbls and (lbls[lang] or lbls.en) or nb.titleEN
            end
        end
        if fr.GeminiCurrent then BuildTab(fr, fr.GeminiCurrent) end
    end
    local ar = GeminiBots.ArsenalFrame
    if IsValid(ar) and ar.ApplyLang then
        ar:ApplyLang()
    end
end, "GeminiBots_LangChanged")

concommand.Add("geminibots_menu", function()
    -- Тоггл на бинд: открыто — закрыть, закрыто — открыть
    if IsValid(GeminiBots.SettingsFrame) then
        GeminiBots.CloseSettings()
    else
        GeminiBots.OpenSettings()
    end
end, nil, "Открыть/закрыть окно настроек GeminiBots (бинд: bind p geminibots_menu)")
