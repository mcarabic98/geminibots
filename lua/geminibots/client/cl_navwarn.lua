--[[
    GeminiBots - No-Navmesh Warning (Client)
    Голая карта: всплывающее окно в стиле меню с выбором
    "Сгенерировать пути" / "Ничего не делать". Раз за карту.
]]

GeminiBots = GeminiBots or {}
GeminiBots.NavWarnShown = GeminiBots.NavWarnShown or {}

function GeminiBots.ShowNavWarn()
    local T = GeminiBots.Theme
    if not T then return end
    local ru = GeminiBots.GetMenuLang() == "ru"

    local f = vgui.Create("DFrame")
    f:SetSize(T.SZ(440), T.SZ(250))
    f:Center()
    f:SetTitle("")
    f:ShowCloseButton(false)
    f:MakePopup()
    T.MakeDraggable(f, 44)

    local fadeCv = GetConVar("geminibots_menu_fade")
    if not fadeCv or fadeCv:GetBool() then
        f:SetAlpha(0)
        f:AlphaTo(255, 0.18, 0)
    end

    function f:Paint(w, h)
        T.DrawBlur(self)
        local c = T.Corner()
        draw.RoundedBox(c, 0, 0, w, h, T.Colors.bg)
        draw.RoundedBoxEx(c, 0, 0, w, 44, T.Colors.header, true, true, false, false)
        draw.SimpleText(ru and "Нет навмеша" or "No navmesh",
            "GeminiTitle", 14, 22, T.Colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local lbl = vgui.Create("DLabel", f)
    lbl:Dock(TOP)
    lbl:DockMargin(14, 52, 14, 0)
    lbl:SetTall(T.SZ(80))
    lbl:SetFont("GeminiText")
    lbl:SetTextColor(T.Colors.text)
    lbl:SetWrap(true)
    lbl:SetText(ru
        and "На этой карте нет навмеша — боты не смогут ходить. Сгенерировать пути? Сервер подвиснет на несколько минут."
        or "This map has no navmesh — bots can't walk. Generate paths? The server will freeze for a few minutes.")

    local btnGen = T.AccentButton(f, ru and "Сгенерировать пути" or "Generate paths")
    btnGen:DockMargin(T.SZ(14), T.SZ(2), T.SZ(14), T.SZ(10))
    btnGen.DoClick = function()
        T.ClickSound()
        net.Start("GeminiBots_NavGenerate")
        net.SendToServer()
        f:Remove()
    end

    -- Вторая кнопка тихая: обычная карточка, не акцент
    local btnNo = vgui.Create("DButton", f)
    btnNo:Dock(TOP)
    btnNo:DockMargin(T.SZ(14), 0, T.SZ(14), 0)
    btnNo:SetTall(T.SZ(32))
    btnNo:SetText("")
    btnNo.hover = 0
    btnNo.btnLabel = ru and "Ничего не делать" or "Do nothing"
    function btnNo:Paint(w, h)
        self.hover = Lerp(FrameTime() * 12, self.hover or 0, self:IsHovered() and 1 or 0)
        local bgc = T.Colors.row
        if self.hover > 0.01 then bgc = T.Colors.input end
        draw.RoundedBox(T.Corner(), 0, 0, w, h, bgc)
        draw.SimpleText(self.btnLabel, "GeminiText", w / 2, h / 2,
            T.Colors.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btnNo.DoClick = function()
        T.ClickSound()
        f:Remove()
    end
end

net.Receive("GeminiBots_NoNavmesh", function()
    local map = string.lower(game.GetMap() or "")
    if GeminiBots.NavWarnShown[map] then return end
    GeminiBots.NavWarnShown[map] = true
    GeminiBots.ShowNavWarn()
end)

