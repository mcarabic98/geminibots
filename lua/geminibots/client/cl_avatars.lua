--[[
    GeminiBots - Bot Letter Avatars (Client)
    У ботов нет SteamID, поэтому штатный AvatarImage рисует "?".
    Подменяем отрисовку только для ботов: первая буква ника на фоне
    приглушенного цвета из курированной палитры (без неона и кислот,
    как просили). Цвет стабилен: выбирается хешем ника, а не рандомом,
    чтобы не мигал при переоткрытии таба. На остальных игроков
    стандартное поведение не меняется.
]]

GeminiBots = GeminiBots or {}
GeminiBots.Avatars = GeminiBots.Avatars or {}

-- Курированная палитра: приглушенные тона, белый текст читается везде
GeminiBots.Avatars.Palette = {
    Color(99, 102, 241), Color(59, 130, 246), Color(30, 64, 175),
    Color(14, 165, 183), Color(13, 148, 136), Color(16, 185, 129),
    Color(101, 163, 13), Color(132, 204, 22), Color(202, 138, 4),
    Color(180, 83, 9), Color(234, 88, 12), Color(220, 38, 38),
    Color(190, 24, 93), Color(168, 85, 247), Color(124, 58, 237),
    Color(71, 85, 105), Color(120, 113, 108), Color(61, 90, 128),
}

-- Стабильный индекс цвета по нику (сумма байт)
function GeminiBots.Avatars:ColorForNick(nick)
    local sum = 0
    nick = tostring(nick or "?")
    for i = 1, #nick do
        sum = sum + string.byte(nick, i)
    end
    return self.Palette[(sum % #self.Palette) + 1]
end

-- Первый символ с учетом UTF-8 (кириллица — 2 байта, не режем пополам)
function GeminiBots.Avatars:FirstLetter(nick)
    local s = tostring(nick or "")
    local b = string.byte(s, 1)
    if not b then return "?" end
    local len = 1
    if b >= 240 then len = 4 elseif b >= 224 then len = 3 elseif b >= 192 then len = 2 end
    local ch = string.sub(s, 1, len)
    -- Латиницу капитализируем, кириллицу string.upper не берет — оставляем как есть
    if b < 128 then ch = string.upper(ch) end
    if ch == "" then return "?" end
    return ch
end

function GeminiBots.Avatars:NickOf(ply)
    if not IsValid(ply) then return "?" end
    local custom = ply:GetNWString("GeminiBots_CustomNick", "")
    if custom ~= "" then return custom end
    return ply:Nick() or "?"
end

-- Класс AvatarImage движок не отдает, поэтому правим каждый инстанс отдельно.
-- Чужие панели не трогаем.
local function HookAvatarInstance(pnl)
    if not IsValid(pnl) or pnl.GeminiAvatarHooked then return end
    pnl.GeminiAvatarHooked = true

    local OldSetPlayer = pnl.SetPlayer
    function pnl:SetPlayer(ply, size)
        self.GeminiAvatarIsBot = IsValid(ply) and ply:IsBot() or false
        if self.GeminiAvatarIsBot then
            self.GeminiAvatarNick = GeminiBots.Avatars:NickOf(ply)
        else
            self.GeminiAvatarNick = nil
            -- Чужой таб (HL2DM) зовет SetPlayer(nil) для ботов — игрок
            -- потерян, но ник лежит второй колонкой в строке-родителе.
            -- Берем его и рисуем букву все равно (пустой "?" вместо
            -- штатного "?" никому не мешает)
            if not IsValid(ply) then
                local par = self.GetParent and self:GetParent() or nil
                if IsValid(par) and par.GetColumnText then
                    local ok, txt = pcall(function() return par:GetColumnText(2) end)
                    if ok and txt ~= nil and txt ~= "" then
                        self.GeminiAvatarIsBot = true
                        self.GeminiAvatarNick = tostring(txt)
                    end
                end
            end
        end
        if OldSetPlayer then
            return OldSetPlayer(self, ply, size)
        end
    end

    local OldPaint = pnl.Paint
    function pnl:Paint(w, h)
        if not self.GeminiAvatarIsBot then
            if OldPaint then return OldPaint(self, w, h) end
            return
        end
        local nick = self.GeminiAvatarNick or "?"
        local bg = GeminiBots.Avatars:ColorForNick(nick)
        draw.RoundedBox(4, 0, 0, w, h, bg)
        draw.SimpleText(
            GeminiBots.Avatars:FirstLetter(nick),
            (w > 48 or h > 48) and "DermaLarge" or "Trebuchet24",
            w / 2, h / 2, Color(255, 255, 255, 255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        return true
    end
end

local function InstallAvatarOverride()
    if GeminiBots.Avatars.Installed then return true end
    local OldCreate = vgui.Create
    if not OldCreate then return false end
    vgui.Create = function(className, parent, ...)
        local pnl = OldCreate(className, parent, ...)
        if className == "AvatarImage" then
            HookAvatarInstance(pnl)
        end
        return pnl
    end
    GeminiBots.Avatars.Installed = true
    return true
end

if InstallAvatarOverride() then
    print("[GeminiBots] Аватарки ботов: перехват vgui.Create установлен.")
else
    print("[GeminiBots] Аватарки ботов: нет vgui.Create, пропуск!")
end

