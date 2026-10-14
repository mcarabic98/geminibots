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

-- Локализация заголовков окна
local function IsRU()
    local lang = GetConVar("gmod_language") and GetConVar("gmod_language"):GetString() or "ru"
    return string.find(string.lower(lang), "ru") ~= nil
end

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

local function TypeLabel(key, ru)
    local t = ru and WTYPE_RU or WTYPE_EN
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
        GeminiBots.ArsenalFrame:Center()
        gui.EnableScreenClicker(true)
        RequestArsenal(GeminiBots.ArsenalFrame.ShowMissing)
        return GeminiBots.ArsenalFrame
    end

    local ru = IsRU()
    local T = GeminiBots.Theme
    -- Язык читаем вживую из настроек, а не запоминаем при открытии
    local function LiveRU() return GeminiBots.GetMenuLang() == "ru" end
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
        GeminiBots.Theme.DrawSpaced(LiveRU() and "GeminiBots — Арсенал ботов" or "GeminiBots — Bot Arsenal",
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

    local search = vgui.Create("DTextEntry", row1)
    search:Dock(LEFT)
    search:SetWide(240)
    search:SetFont("GeminiText")
    T.StyleTextEntry(search)
    OnLang(function()
        if IsValid(search) then
            search:SetPlaceholderText(LiveRU() and "Поиск по классу или названию..." or "Search class or name...")
        end
    end)
    search.OnChange = function(self)
        frame.SearchText = string.lower(self:GetValue() or "")
        frame:RefreshList()
    end
    -- Поиск через диалог: поле только показывает, печатаем в диалоге
    search:SetEditable(false)
    search.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT then return end
        T.ClickSound()
        local old = self:GetValue()
        T.AskText(LiveRU() and "Поиск" or "Search", old, false,
            function(v)
                frame.SearchText = string.lower(v or "")
                frame:RefreshList()
                if IsValid(search) then search:SetText(v or "") end
            end,
            function() end,
            function()
                if IsValid(search) then search:SetText(old) end
                frame.SearchText = string.lower(old or "")
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
    typeBox:SetValue(TypeLabel("All", LiveRU()))
    typeBox:AddChoice(TypeLabel("All", LiveRU()), "All")
    T.StyleComboFace(typeBox)
    typeBox.OnSelect = function(_, _, _, key)
        frame.TypeFilter = key or "All"
        frame:RefreshList()
    end

    local chkEnabled = vgui.Create("DCheckBoxLabel", row2)
    chkEnabled:Dock(LEFT)
    chkEnabled:DockMargin(0, 0, 0, 0)
    chkEnabled:SetFont("GeminiSmall")
    chkEnabled:SetTextColor(T.Colors.muted)
    OnLang(function()
        if IsValid(chkEnabled) then
            chkEnabled:SetText(LiveRU() and "Только включённые" or "Enabled only")
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
            chkMissing:SetText(LiveRU() and "Показать отсутствующие" or "Show missing")
            chkMissing:SetTooltip(LiveRU() and "Записи из weapons.txt, которых нет на сервере" or "weapons.txt entries not installed")
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
            btnRescan:SetText(LiveRU() and "Скан" or "Rescan")
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
            presetLabel:SetText(LiveRU() and "Тип:" or "Type:")
        end
    end)

    local function PresetBtn(ruText, enText, preset)
        local b = vgui.Create("DButton", presets)
        b:Dock(LEFT)
        b:SetWide(90)
        b:DockMargin(0, 0, 4, 0)
        b:SetText(LiveRU() and ruText or enText)
        OnLang(function()
            if IsValid(b) then
                b:SetText(LiveRU() and ruText or enText)
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

    PresetBtn("HL2", "HL2", "hl2")
    PresetBtn("M9K", "M9K", "m9k")
    PresetBtn("Пистолеты", "Pistols", "pistols")
    PresetBtn("Винтовки", "Rifles", "rifles")
    PresetBtn("Дробь", "Shotguns", "shotguns")
    PresetBtn("Снайп.", "Snipers", "snipers")
    -- Массовые действия отдельно справа от фильтров типов
    local bOff = PresetBtn("ВЫКЛ", "OFF", "none")
    local bAll = PresetBtn("ВСЁ", "ALL", "all")
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

    local bulkDefs = {
        { label = LiveRU() and "Вкл. видимые" or "Enable visible",
          tip = LiveRU() and "Включить всё видимое в списке" or "Enable all listed",
          fn = function()
            local visible = frame:GetVisibleClasses()
            if #visible == 0 then return end
            local payload = {}
            for _, class in ipairs(visible) do
                table.insert(payload, { class = class, active = true })
            end
            SendBulk(payload)
        end },
        { label = LiveRU() and "Выкл. видимые" or "Disable visible",
          tip = LiveRU() and "Выключить всё видимое в списке" or "Disable all listed",
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
            btns[1].btnLabel = LiveRU() and "Вкл. видимые" or "Enable visible"
            T.Tooltip(btns[1], LiveRU() and "Включить всё видимое в списке" or "Enable all listed")
        end
        if IsValid(btns[2]) then
            btns[2].btnLabel = LiveRU() and "Выкл. видимые" or "Disable visible"
            T.Tooltip(btns[2], LiveRU() and "Выключить всё видимое в списке" or "Disable all listed")
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
            self.TypeBox:AddChoice(TypeLabel("All", LiveRU()), "All")
            for _, t in ipairs(types) do self.TypeBox:AddChoice(TypeLabel(t, LiveRU()), t) end
            self.TypeBox:SetValue(TypeLabel(self.TypeFilter or "All", LiveRU()))
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
            if LiveRU() then
                self.CountLabel:SetText(string.format("Показано: %d/%d · Вкл: %d", #data, #(GeminiBots.CachedArsenal or {}), enabledCount))
            else
                self.CountLabel:SetText(string.format("Shown: %d/%d · On: %d", #data, #(GeminiBots.CachedArsenal or {}), enabledCount))
            end
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
            local lru = LiveRU()
            local label = string.format("[%s] %s <%s>",
                entry.pack or "?", entry.name or "", TypeLabel(entry.wtype or "other", lru))
            if entry.available == false then label = label .. (lru and " [НЕТ НА СЕРВЕРЕ]" or " [MISSING]") end
            if entry.compatible == false then label = label .. (lru and " [НЕ ДЛЯ БОТОВ]" or " [BOT-INCOMPATIBLE]") end
            if entry.broken then label = label .. (lru and " [ОШИБКА]" or " [BROKEN]") end
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
                btnDel:SetTooltip(LiveRU() and "Удалить из weapons.txt" or "Remove from weapons.txt")
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
