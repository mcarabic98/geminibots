--[[
    GeminiBots - Arsenal Browser (Client)
    Отдельное окно выбора оружия: скан установленного, поиск, фильтры по пакам.
    Неустановленное из weapons.txt скрыто по умолчанию.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.CachedArsenal = GeminiBots.CachedArsenal or {}
GeminiBots.ArsenalFrame = GeminiBots.ArsenalFrame or nil

local function RequestArsenal(includeMissing)
    net.Start("GeminiBots_RequestArsenal")
    net.WriteBool(includeMissing == true)
    net.SendToServer()
end

function GeminiBots.RequestArsenal(includeMissing)
    RequestArsenal(includeMissing)
end

local function SendToggle(class, active)
    net.Start("GeminiBots_ToggleWeapon")
    net.WriteString(class)
    net.WriteBool(active)
    net.SendToServer()
end

local function SendBulk(list)
    net.Start("GeminiBots_BulkWeapons")
    net.WriteTable(list)
    net.SendToServer()
end

-- Прием чанков Арсенала (см. SendBigTable на сервере): склейка по transferId
local arsenalTransferId = -1
local arsenalChunks = {}

net.Receive("GeminiBots_ReceiveArsenal", function()
    local tid = net.ReadUInt(16)
    local total = net.ReadUInt(8)
    local index = net.ReadUInt(8)
    local chunk = net.ReadData(net.ReadUInt(16))

    if tid ~= arsenalTransferId then
        arsenalTransferId = tid
        arsenalChunks = {}
    end
    arsenalChunks[index] = chunk

    for i = 1, total do
        if not arsenalChunks[i] then return end -- ждем остальные куски
    end

    local json = util.Decompress(table.concat(arsenalChunks))
    arsenalChunks = {}
    if not json then return end

    GeminiBots.CachedArsenal = util.JSONToTable(json) or {}
    if IsValid(GeminiBots.ArsenalFrame) then
        GeminiBots.ArsenalFrame:RefreshList()
    end
end)

-- Локализация заголовков окна берется вживую из GeminiBots.LangStr

-- Подписи типов оружия для фильтров и строк
local WTYPE_RU = {
    All = "Все", rifle = "Винтовки", smg = "ПП", pistol = "Пистолеты",
    shotgun = "Дробовики", sniper = "Снайперки", mg = "Пулеметы",
    melee = "Рукопашка", grenade = "Гранаты", tactical = "Тактика",
    special = "Спец.", other = "Другое"
}
local WTYPE_EN = {
    All = "All", rifle = "Rifles", smg = "SMGs", pistol = "Pistols",
    shotgun = "Shotguns", sniper = "Snipers", mg = "MGs",
    melee = "Melee", grenade = "Grenades", tactical = "Tactical",
    special = "Special", other = "Other"
}
local WTYPE_UK = {
    All = "Усі", rifle = "Гвинтівки", smg = "ПП", pistol = "Пістолети",
    shotgun = "Дробовики", sniper = "Снайперки", mg = "Кулемети",
    melee = "Рукопаш", grenade = "Гранати", tactical = "Тактика",
    special = "Спец.", other = "Інше"
}
local WTYPE_ES = {
    All = "Todas", rifle = "Fusiles", smg = "SMG", pistol = "Pistolas",
    shotgun = "Escopetas", sniper = "Francotiradoras", mg = "Ametralladoras",
    melee = "Cuerpo a cuerpo", grenade = "Granadas", tactical = "Tácticas",
    special = "Especiales", other = "Otras"
}
local WTYPE_PT = {
    All = "Todas", rifle = "Fuzis", smg = "SMGs", pistol = "Pistolas",
    shotgun = "Escopetas", sniper = "Snipers", mg = "Metralhadoras",
    melee = "Corpo a corpo", grenade = "Granadas", tactical = "Táticas",
    special = "Especiais", other = "Outras"
}

local WTYPE_BY_LANG = {
    ru = WTYPE_RU, uk = WTYPE_UK, es = WTYPE_ES, pt = WTYPE_PT, en = WTYPE_EN
}

local function TypeLabel(key, lang)
    local t = WTYPE_BY_LANG[lang or GeminiBots.GetMenuLang()] or WTYPE_EN
    return t[key] or key
end

-- Стилизованная кнопка: текст храним в поле, нативный гасим, иначе двоится.
-- Смена языка идет через тот же SetText.
local function StyleBtn(b, tall)
    local T = GeminiBots.Theme
    if tall then b:SetTall(tall) end
    b.hover = 0
    local NativeSetText = b.SetText
    b.btnText = b:GetText()
    function b:SetText(t) self.btnText = tostring(t or "") end
    NativeSetText(b, "")
    function b:Paint(w, h)
        self.hover = Lerp(FrameTime() * 12, self.hover or 0, self:IsHovered() and 1 or 0)
        local c = T.Corner()
        -- Плавный переход цвета, а не резкий скачок
        local bgc = T.Mix(T.Colors.accentDk, T.Colors.accent, self.hover or 0)
        GeminiBots.Theme.RBox(0, 0, w, h, c, bgc)
        local txt = self.btnText or ""
        if txt ~= "" then
            GeminiBots.Theme.DrawSpaced(txt, "GeminiText", w / 2, h / 2,
                T.Colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
        end
    end
    local OldClick = b.DoClick
    b.DoClick = function(self, ...)
        GeminiBots.Theme.ClickSound()
        if OldClick then return OldClick(self, ...) end
    end
    return b
end

function GeminiBots.OpenArsenal()
    if IsValid(GeminiBots.ArsenalFrame) then
        GeminiBots.ArsenalFrame:SetMouseInputEnabled(true)
        GeminiBots.ArsenalFrame:SetKeyboardInputEnabled(false)
        -- Позиция из сохранения (как при первом открытии), а не центр:
        -- Center затирал позицию, которую игрок выбрал сам
        GeminiBots.Theme.LoadWinPos("arsenal", GeminiBots.ArsenalFrame)
        gui.EnableScreenClicker(true)
        RequestArsenal(GeminiBots.ArsenalFrame.ShowMissing)
        return GeminiBots.ArsenalFrame
    end

    local T = GeminiBots.Theme
    -- Строка по языку меню: { ru=..., uk=..., es=..., pt=..., en=... }
    local function L(t) return GeminiBots.LangStr(t) end
    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetSize(880, 620)
    frame:Center()
    T.LoadWinPos("arsenal", frame)
    -- Как настройки: мышь окну, клавиатура игре (печать через диалог)
    frame:SetMouseInputEnabled(true)
    frame:SetKeyboardInputEnabled(false)
    gui.EnableScreenClicker(true)
    T.MakeDraggable(frame, 46)

    local fadeCvA = GetConVar("geminibots_menu_fade")
    if not fadeCvA or fadeCvA:GetBool() then
        frame:SetAlpha(0)
        frame:AlphaTo(255, 0.18, 0)
    end

    function frame:Paint(w, h)
        T.DrawBlur(self)
        local c = T.Corner()
        draw.RoundedBox(c, 0, 0, w, h, T.Colors.bg)
        draw.RoundedBoxEx(c, 0, 0, w, 46, T.Colors.header, true, true, false, false)
        GeminiBots.Theme.DrawSpaced(L{
            ru = "GeminiBots — Арсенал ботов", uk = "GeminiBots — Арсенал ботів",
            es = "GeminiBots — Arsenal de bots", pt = "GeminiBots — Arsenal dos bots",
            en = "GeminiBots — Bot Arsenal" },
            "GeminiTitle", 16, 23, T.Colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetText("")
    closeBtn:SetSize(46, 46)
    closeBtn:SetPos(880 - 46, 0)
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
        T.SaveWinPos("arsenal", frame)
        GeminiBots.ArsenalFrame = nil
        -- Арсенал отдельно от настроек: курсор возвращаем игре
        if not IsValid(GeminiBots.SettingsFrame) then
            gui.EnableScreenClicker(false)
        end
        local fadeCvC = GetConVar("geminibots_menu_fade")
        if fadeCvC and not fadeCvC:GetBool() then
            if IsValid(frame) then frame:Remove() end
            return
        end
        frame:AlphaTo(0, 0.15, 0, function()
            if IsValid(frame) then frame:Remove() end
        end)
    end

    frame.ShowMissing = false
    frame.OnlyEnabled = false
    frame.PackFilter = "All"
    frame.TypeFilter = "All"
    frame.SearchText = ""

    GeminiBots.ArsenalFrame = frame
    frame.GeminiLangFns = {}

    -- Подписи обновляются сменой языка из окна настроек
    local function OnLang(apply)
        table.insert(frame.GeminiLangFns, apply)
        local ok = pcall(apply)
    end

    function frame:ApplyLang()
        for _, fn in ipairs(self.GeminiLangFns or {}) do
            pcall(fn)
        end
        if self.RefreshFilters then self:RefreshFilters() end
        if self.RefreshList then self:RefreshList() end
    end

    -- Шапка в два ряда: сверху поиск с фильтрами, снизу галки
    local top = vgui.Create("DPanel", frame)
    top:Dock(TOP)
    top:SetTall(96)
    top:DockMargin(4, 50, 4, 4)
    top.Paint = function() end

    local row1 = vgui.Create("DPanel", top)
    row1:Dock(TOP)
    row1:SetTall(44)
    row1.Paint = function() end

    local row2 = vgui.Create("DPanel", top)
    row2:Dock(TOP)
    row2:SetTall(36)
    row2:DockMargin(0, 6, 0, 0)
    row2.Paint = function() end

    -- Поиск: как везде — клик открывает диалог ввода (полям фокус не дают,
    -- печатать прямо в поле нельзя). Раскрашено под поле ввода, но это
    -- кнопка: нередактируемый DTextEntry клик не отдавал, диалог не открывался
    local search = vgui.Create("DButton", row1)
    search:Dock(LEFT)
    search:SetWide(240)
    search:SetText("")
    search.hover = 0
    search.GeminiValue = ""
    -- Плейсхолдер сразу по языку: до первого переключения языка он был
    -- жестко русским и в английском интерфейсе
    search.GeminiPlaceholder = L{
        ru = "Поиск по классу или названию...", uk = "Пошук за класом або назвою...",
        es = "Buscar por clase o nombre...", pt = "Buscar por classe ou nome...",
        en = "Search class or name..." }
    function search:Paint(w, h)
        self.hover = Lerp(FrameTime() * 12, self.hover or 0, self:IsHovered() and 1 or 0)
        draw.RoundedBox(math.min(T.Corner(), math.floor(h / 2)), 0, 0, w, h,
            T.Mix(T.Colors.input, T.Colors.accentDk, (self.hover or 0) * 0.5))
        local txt = self.GeminiValue
        local col = T.Colors.text
        if not txt or txt == "" then
            txt = self.GeminiPlaceholder or ""
            col = T.Colors.muted
        end
        local ok, l = pcall(utf8.len, txt)
        if ok and l and l > 28 then
            local _, pos = pcall(utf8.offset, txt, 29)
            if pos then txt = string.sub(txt, 1, pos - 1) .. "…" end
        end
        draw.SimpleText(txt, "GeminiText", 10, h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    OnLang(function()
        if IsValid(search) then
            search.GeminiPlaceholder = L{
                ru = "Поиск по классу или названию...", uk = "Пошук за класом або назвою...",
                es = "Buscar por clase o nombre...", pt = "Buscar por classe ou nome...",
                en = "Search class or name..." }
        end
    end)
    search.DoClick = function()
        T.ClickSound()
        local old = search.GeminiValue or ""
        T.AskText(L{
            ru = "Поиск", uk = "Пошук", es = "Buscar",
            pt = "Buscar", en = "Search" }, old, false,
            function(v)
                search.GeminiValue = v or ""
                frame.SearchText = string.lower(v or "")
                frame:RefreshList()
            end,
            function(v)
                search.GeminiValue = v or ""
                frame.SearchText = string.lower(v or "")
                frame:RefreshList()
            end,
            function()
                search.GeminiValue = old
                frame.SearchText = string.lower(old)
                frame:RefreshList()
            end)
    end

    -- Фильтр паков: пункты строятся из данных сервера (SWCS и др. подхватятся сами)
    local packBox = vgui.Create("DComboBox", row1)
    frame.PackBox = packBox
    packBox:Dock(LEFT)
    packBox:SetWide(150)
    packBox:DockMargin(8, 0, 0, 0)
    packBox:SetValue("All")
    packBox:AddChoice("All", "All")
    T.StyleComboFace(packBox)
    packBox.OnSelect = function(_, _, _, key)
        frame.PackFilter = key or "All"
        frame:RefreshList()
    end

    -- Фильтр типов оружия (винтовки, ПП, ...): тоже из данных сервера
    local typeBox = vgui.Create("DComboBox", row1)
    frame.TypeBox = typeBox
    typeBox:Dock(LEFT)
    typeBox:SetWide(150)
    typeBox:DockMargin(8, 0, 0, 0)
    typeBox:SetValue(TypeLabel("All"))
    typeBox:AddChoice(TypeLabel("All"), "All")
    T.StyleComboFace(typeBox)
    typeBox.OnSelect = function(_, _, _, key)
        frame.TypeFilter = key or "All"
        frame:RefreshList()
    end

    local chkEnabled = vgui.Create("DCheckBoxLabel", row2)
    chkEnabled:Dock(LEFT)
    chkEnabled:DockMargin(0, 0, 0, 0)
    chkEnabled:SetFont("GeminiSmall")
    chkEnabled:SetTextColor(T.Colors.muted)    OnLang(function()
        if IsValid(chkEnabled) then
            chkEnabled:SetText(L{
                ru = "Только включённые", uk = "Лише увімкнені",
                es = "Solo activadas", pt = "Somente ativas", en = "Enabled only" })
        end
    end)
    chkEnabled:SetValue(0)
    chkEnabled.OnChange = function(_, val)
        frame.OnlyEnabled = val
        frame:RefreshList()
    end

    local chkMissing = vgui.Create("DCheckBoxLabel", row2)
    chkMissing:Dock(LEFT)
    chkMissing:DockMargin(24, 0, 0, 0)
    chkMissing:SetFont("GeminiSmall")
    chkMissing:SetTextColor(T.Colors.muted)
    OnLang(function()
        if IsValid(chkMissing) then
            chkMissing:SetText(L{
                ru = "Показать отсутствующие", uk = "Показати відсутні",
                es = "Mostrar no instaladas", pt = "Mostrar não instaladas",
                en = "Show missing" })
            chkMissing:SetTooltip(L{
                ru = "Записи из weapons.txt, которых нет на сервере",
                uk = "Записи з weapons.txt, яких немає на сервері",
                es = "Entradas de weapons.txt no instaladas en el servidor",
                pt = "Entradas do weapons.txt não instaladas no servidor",
                en = "weapons.txt entries not installed" })
        end
    end)
    chkMissing:SetValue(0)
    chkMissing.OnChange = function(_, val)
        frame.ShowMissing = val
        RequestArsenal(val)
    end

    local btnRescan = vgui.Create("DButton", row1)
    btnRescan:Dock(LEFT)
    btnRescan:SetWide(110)
    btnRescan:DockMargin(8, 0, 0, 0)
    OnLang(function()
        if IsValid(btnRescan) then
            btnRescan:SetText(L{
                ru = "Скан", uk = "Скан", es = "Escanear",
                pt = "Escanear", en = "Rescan" })
        end
    end)
    btnRescan.DoClick = function()
        RequestArsenal(frame.ShowMissing)
    end
    StyleBtn(btnRescan, 36)

    -- Панель пресетов: выбор типа оружия
    local presets = vgui.Create("DPanel", frame)
    presets:Dock(TOP)
    presets:SetTall(30)
    presets:DockMargin(4, 0, 4, 0)
    presets.Paint = function() end

    local presetLabel = vgui.Create("DLabel", presets)
    presetLabel:Dock(LEFT)
    presetLabel:SetWide(40)
    presetLabel:SetFont("GeminiText")
    presetLabel:SetTextColor(T.Colors.muted)
    OnLang(function()
        if IsValid(presetLabel) then
            presetLabel:SetText(L{
                ru = "Тип:", uk = "Тип:", es = "Tipo:",
                pt = "Tipo:", en = "Type:" })
        end
    end)

    -- texts — таблица по языкам { ru=..., uk=..., es=..., pt=..., en=... }
    local function PresetBtn(texts, preset)
        local b = vgui.Create("DButton", presets)
        b:Dock(LEFT)
        b:SetWide(90)
        b:DockMargin(0, 0, 4, 0)
        b:SetText(L(texts))
        OnLang(function()
            if IsValid(b) then
                b:SetText(L(texts))
            end
        end)
        b.DoClick = function()
            net.Start("GeminiBots_SetWeaponPreset")
            net.WriteString(preset)
            net.SendToServer()
        end
        StyleBtn(b, 26)
        return b
    end

    PresetBtn({ ru = "HL2", uk = "HL2", es = "HL2", pt = "HL2", en = "HL2" }, "hl2")
    PresetBtn({ ru = "M9K", uk = "M9K", es = "M9K", pt = "M9K", en = "M9K" }, "m9k")
    PresetBtn({ ru = "Пистолеты", uk = "Пістолети", es = "Pistolas",
        pt = "Pistolas", en = "Pistols" }, "pistols")
    PresetBtn({ ru = "Винтовки", uk = "Гвинтівки", es = "Fusiles",
        pt = "Fuzis", en = "Rifles" }, "rifles")
    PresetBtn({ ru = "Дробь", uk = "Дріб", es = "Escopetas",
        pt = "Escopetas", en = "Shotguns" }, "shotguns")
    PresetBtn({ ru = "Снайп.", uk = "Снайп.", es = "Snipers",
        pt = "Snipers", en = "Snipers" }, "snipers")
    -- Массовые действия отдельно справа от фильтров типов
    local bOff = PresetBtn({ ru = "ВЫКЛ", uk = "ВИКЛ", es = "APAGAR",
        pt = "DESLIGAR", en = "OFF" }, "none")
    local bAll = PresetBtn({ ru = "ВСЁ", uk = "ВСЕ", es = "TODAS",
        pt = "TODAS", en = "ALL" }, "all")
    bOff:Dock(RIGHT)
    bAll:Dock(RIGHT)
    bOff:DockMargin(0, 0, 0, 0)
    bAll:DockMargin(0, 0, 8, 0)

    -- Средняя панель: счетчик сверху, bulk-кнопки парой во всю ширину
    local mid = vgui.Create("DPanel", frame)
    mid:Dock(TOP)
    mid:SetTall(58)
    mid:DockMargin(4, 0, 4, 0)
    mid.Paint = function() end

    local countLabel = vgui.Create("DLabel", mid)
    countLabel:Dock(TOP)
    countLabel:SetTall(20)
    countLabel:SetText("")
    countLabel:SetFont("GeminiSmall")
    countLabel:SetTextColor(T.Colors.muted)
    countLabel:SetContentAlignment(4)
    frame.CountLabel = countLabel

    -- Цвета статичных подписей SetTextColor копирует один раз: при смене
    -- темы без этой строки оставался старый цвет (применяем через ApplyLang)
    OnLang(function()
        if IsValid(countLabel) then countLabel:SetTextColor(T.Colors.muted) end
        if IsValid(presetLabel) then presetLabel:SetTextColor(T.Colors.muted) end
        if IsValid(chkEnabled) then chkEnabled:SetTextColor(T.Colors.muted) end
        if IsValid(chkMissing) then chkMissing:SetTextColor(T.Colors.muted) end
    end)

    local bulkDefs = {
        { label = L{
            ru = "Вкл. видимые", uk = "Увімк. видимі", es = "Activar visibles",
            pt = "Ativar visíveis", en = "Enable visible" },
          tip = L{
            ru = "Включить всё видимое в списке", uk = "Увімкнути все видиме у списку",
            es = "Activar todo lo visible en la lista", pt = "Ativar tudo que está visível na lista",
            en = "Enable all listed" },
          fn = function()
            local visible = frame:GetVisibleClasses()
            if #visible == 0 then return end
            local payload = {}
            for _, class in ipairs(visible) do
                table.insert(payload, { class = class, active = true })
            end
            SendBulk(payload)
        end },
        { label = L{
            ru = "Выкл. видимые", uk = "Вимк. видимі", es = "Desactivar visibles",
            pt = "Desativar visíveis", en = "Disable visible" },
          tip = L{
            ru = "Выключить всё видимое в списке", uk = "Вимкнути все видиме у списку",
            es = "Desactivar todo lo visible en la lista", pt = "Desativar tudo que está visível na lista",
            en = "Disable all listed" },
          fn = function()
            local visible = frame:GetVisibleClasses()
            if #visible == 0 then return end
            local payload = {}
            for _, class in ipairs(visible) do
                table.insert(payload, { class = class, active = false })
            end
            SendBulk(payload)
        end },
    }
    local bulkRows = T.ButtonGrid(mid, bulkDefs, true)
    frame.BulkBtns = bulkRows[1] and bulkRows[1].GeminiBtns or {}
    OnLang(function()
        local btns = frame.BulkBtns or {}
        if IsValid(btns[1]) then
            btns[1].btnLabel = L{
                ru = "Вкл. видимые", uk = "Увімк. видимі", es = "Activar visibles",
                pt = "Ativar visíveis", en = "Enable visible" }
            T.Tooltip(btns[1], L{
                ru = "Включить всё видимое в списке", uk = "Увімкнути все видиме у списку",
                es = "Activar todo lo visible en la lista", pt = "Ativar tudo que está visível na lista",
                en = "Enable all listed" })
        end
        if IsValid(btns[2]) then
            btns[2].btnLabel = L{
                ru = "Выкл. видимые", uk = "Вимк. видимі", es = "Desactivar visibles",
                pt = "Desativar visíveis", en = "Disable visible" }
            T.Tooltip(btns[2], L{
                ru = "Выключить всё видимое в списке", uk = "Вимкнути все видиме у списку",
                es = "Desactivar todo lo visible en la lista", pt = "Desativar tudo que está visível na lista",
                en = "Disable all listed" })
        end
    end)

    -- Список
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(4, 4, 4, 4)
    T.SmoothScroll(scroll)
    frame.ListPanel = scroll

    function frame:GetFilteredData()
        local out = {}
        local q = self.SearchText or ""
        for _, e in ipairs(GeminiBots.CachedArsenal or {}) do
            if self.PackFilter ~= "All" and e.pack ~= self.PackFilter then continue end
            if (self.TypeFilter or "All") ~= "All" and (e.wtype or "other") ~= self.TypeFilter then continue end
            if self.OnlyEnabled and not e.active then continue end
            if q ~= "" then
                local hay = string.lower((e.class or "") .. " " .. (e.name or ""))
                if not string.find(hay, q, 1, true) then continue end
            end
            -- Лишнее прячем и на клиенте, на случай старого кеша
            if e.available == false and not self.ShowMissing then continue end
            table.insert(out, e)
        end
        return out
    end

    function frame:GetVisibleClasses()
        local classes = {}
        for _, e in ipairs(self:GetFilteredData()) do
            if e.available ~= false then
                table.insert(classes, e.class)
            end
        end
        return classes
    end

    -- Перестроить пункты фильтров пак/тип из загруженных данных
    function frame:RefreshFilters()
        local packs, pset = {}, {}
        local types, tset = {}, {}
        for _, e in ipairs(GeminiBots.CachedArsenal or {}) do
            if e.pack and not pset[e.pack] then
                pset[e.pack] = true
                table.insert(packs, e.pack)
            end
            local wt = e.wtype or "other"
            if not tset[wt] then
                tset[wt] = true
                table.insert(types, wt)
            end
        end
        table.sort(packs)
        table.sort(types)
        if IsValid(self.PackBox) then
            self.PackBox:Clear()
            self.PackBox:AddChoice("All", "All")
            for _, p in ipairs(packs) do self.PackBox:AddChoice(p, p) end
            self.PackBox:SetValue(self.PackFilter or "All")
        end
        if IsValid(self.TypeBox) then
            self.TypeBox:Clear()
            self.TypeBox:AddChoice(TypeLabel("All"), "All")
            for _, t in ipairs(types) do self.TypeBox:AddChoice(TypeLabel(t), t) end
            self.TypeBox:SetValue(TypeLabel(self.TypeFilter or "All"))
        end
    end

    function frame:RefreshList()
        if not IsValid(self.ListPanel) then return end
        self:RefreshFilters()
        self.ListPanel:Clear()

        local data = self:GetFilteredData()

        local enabledCount = 0
        for _, e in ipairs(GeminiBots.CachedArsenal or {}) do
            if e.active and e.available ~= false then enabledCount = enabledCount + 1 end
        end

        if IsValid(self.CountLabel) then
            self.CountLabel:SetText(L{
                ru = string.format("Показано: %d/%d · Вкл: %d", #data, #(GeminiBots.CachedArsenal or {}), enabledCount),
                uk = string.format("Показано: %d/%d · Увімк: %d", #data, #(GeminiBots.CachedArsenal or {}), enabledCount),
                es = string.format("Mostradas: %d/%d · Activas: %d", #data, #(GeminiBots.CachedArsenal or {}), enabledCount),
                pt = string.format("Mostradas: %d/%d · Ativas: %d", #data, #(GeminiBots.CachedArsenal or {}), enabledCount),
                en = string.format("Shown: %d/%d · On: %d", #data, #(GeminiBots.CachedArsenal or {}), enabledCount) })
        end

        for _, e in ipairs(data) do
            local entry = e
            local special = entry.available == false or entry.broken or entry.compatible == false
            local row = vgui.Create("DPanel", self.ListPanel)
            row:Dock(TOP)
            row:SetTall(28)
            row:DockMargin(0, 0, 0, 2)
            row.Paint = function(_, w, h)
                local bg
                if entry.available == false or entry.broken then
                    bg = Color(70, 40, 40, 255)
                elseif entry.compatible == false then
                    bg = Color(60, 55, 40, 255)
                elseif entry.active then
                    bg = T.Colors.accent
                else
                    bg = T.Colors.row
                end
                GeminiBots.Theme.RBox(0, 0, w, h, T.Corner(), bg)
            end
            -- Слева имя с типом, справа приглушенно класс (он же в тултипе)
            local rowText = special and Color(235, 235, 240) or T.Colors.text
            if entry.active and not special then rowText = Color(255, 255, 255) end

            local chk = vgui.Create("DCheckBoxLabel", row)
            chk:Dock(LEFT)
            chk:DockMargin(6, 0, 0, 0)
            chk:SetWide(430)
            chk:SetFont("GeminiSmall")
            chk:SetTextColor(rowText)
            local lang = GeminiBots.GetMenuLang()
            local label = string.format("[%s] %s <%s>",
                entry.pack or "?", entry.name or "", TypeLabel(entry.wtype or "other", lang))
            if entry.available == false then
                label = label .. ({
                    ru = " [НЕТ НА СЕРВЕРЕ]", uk = " [НЕМАЄ НА СЕРВЕРІ]",
                    es = " [NO INSTALADA]", pt = " [NÃO INSTALADA]",
                    en = " [MISSING]" })[lang or "en"]
            end
            if entry.compatible == false then
                label = label .. ({
                    ru = " [НЕ ДЛЯ БОТОВ]", uk = " [НЕ ДЛЯ БОТІВ]",
                    es = " [NO PARA BOTS]", pt = " [INCOMPATÍVEL COM BOTS]",
                    en = " [BOT-INCOMPATIBLE]" })[lang or "en"]
            end
            if entry.broken then
                label = label .. ({
                    ru = " [ОШИБКА]", uk = " [ПОМИЛКА]",
                    es = " [ROTO]", pt = " [COM ERRO]",
                    en = " [BROKEN]" })[lang or "en"]
            end
            chk:SetText(label)
            chk:SetValue(entry.active and 1 or 0)
            chk:SetTooltip(entry.class)
            chk.OnChange = function(_, val)
                SendToggle(entry.class, val)
                -- Оптимистично обновляем кеш, чтобы не мигало
                entry.active = val
                if val and not entry.inPool then entry.inPool = true end
                timer.Simple(0.5, function()
                    if IsValid(frame) then frame:RefreshList() end
                end)
            end

            local nameLabel = vgui.Create("DLabel", row)
            nameLabel:Dock(FILL)
            nameLabel:DockMargin(8, 0, 4, 0)
            nameLabel:SetText(entry.class)
            nameLabel:SetFont("GeminiSmall")
            -- На цветных строках приглушенный не читается: там белый
            nameLabel:SetTextColor((entry.active or special)
                and Color(235, 235, 240) or T.Colors.muted)
            nameLabel:SetContentAlignment(6)
            nameLabel:SetTooltip(entry.name or entry.class)

            if entry.available == false then
                local btnDel = vgui.Create("DButton", row)
                btnDel:Dock(RIGHT)
                btnDel:SetWide(70)
                btnDel:SetText("X")
                btnDel:SetTooltip(L{
                    ru = "Удалить из weapons.txt", uk = "Видалити з weapons.txt",
                    es = "Eliminar de weapons.txt", pt = "Remover do weapons.txt",
                    en = "Remove from weapons.txt" })
                local delClass = entry.class
                btnDel.DoClick = function()
                    net.Start("GeminiBots_RemoveWeapon")
                    net.WriteString(delClass)
                    net.SendToServer()
                end
                StyleBtn(btnDel, 24)
            end
        end
    end

    RequestArsenal(false)
    return frame
end

concommand.Add("geminibots_weapons_menu", function()
    GeminiBots.OpenArsenal()
end, nil, "Открыть окно Арсенала ботов")
