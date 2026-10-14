--[[
    GeminiBots - Vector Icons & Logo (Client)
    Свои иконки кодом (полигоны/линии), без PNG и silkicons:
    четко на любом масштабе, красятся в любой цвет, ноль файлов.
    T.DrawIcon(name, x, y, s, col) — иконки 5 вкладок.
    T.DrawLogo(variant, x, y, s, col) — лого в шапке (0 голова-бот,
    1 радар-свип, 2 вейпоинт-ромб). Выбор: geminibots_menu_logo.
]]

GeminiBots = GeminiBots or {}
GeminiBots.Theme = GeminiBots.Theme or {}
local T = GeminiBots.Theme

local function Poly(cx, cy, r, n, rot, col)
    local pts = {}
    for i = 0, n - 1 do
        local a = (rot or 0) + i * math.pi * 2 / n
        pts[#pts + 1] = { x = cx + math.cos(a) * r, y = cy + math.sin(a) * r }
    end
    surface.SetDrawColor(col)
    surface.DrawPoly(pts)
end

local function Disc(cx, cy, r, col)
    draw.NoTexture()
    Poly(cx, cy, r, 24, 0, col)
end

local function ThickLine(x1, y1, x2, y2, w, col)
    draw.NoTexture()
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1e-6 then return end
    local nx, ny = -dy / len * w / 2, dx / len * w / 2
    surface.SetDrawColor(col)
    surface.DrawPoly({
        { x = x1 + nx, y = y1 + ny }, { x = x1 - nx, y = y1 - ny },
        { x = x2 - nx, y = y2 - ny }, { x = x2 + nx, y = y2 + ny },
    })
end

local function RectPoly(x, y, w, h, col)
    draw.NoTexture()
    surface.SetDrawColor(col)
    surface.DrawPoly({
        { x = x, y = y }, { x = x + w, y = y },
        { x = x + w, y = y + h }, { x = x, y = y + h },
    })
end

-- Шестерня: 8 зубцов + диск + ступица в цвет фона
-- (белым на темной не видно — детали всегда цветом подложки)
local function IconCog(x, y, s, col, detail)
    local cx, cy = x + s / 2, y + s / 2
    local r = s * 0.30
    for i = 0, 7 do
        local a = i * math.pi / 4
        local tx, ty = cx + math.cos(a) * r, cy + math.sin(a) * r
        RectPoly(tx - s * 0.07, ty - s * 0.07, s * 0.14, s * 0.14, col)
    end
    Disc(cx, cy, r, col)
    Disc(cx, cy, r * 0.38, detail or col)
end

-- Пистолет сбоку: затвор + рукоять + спусковая скоба
local function IconGun(x, y, s, col)
    draw.NoTexture()
    local u = s / 16
    surface.SetDrawColor(col)
    surface.DrawPoly({ -- затвор
        { x = x + 1 * u, y = y + 4 * u }, { x = x + 15 * u, y = y + 4 * u },
        { x = x + 15 * u, y = y + 7 * u }, { x = x + 1 * u, y = y + 7 * u },
    })
    surface.DrawPoly({ -- рукоять (наклон вниз-назад)
        { x = x + 4 * u, y = y + 7 * u }, { x = x + 7.5 * u, y = y + 7 * u },
        { x = x + 6 * u, y = y + 14 * u }, { x = x + 2.8 * u, y = y + 14 * u },
    })
    ThickLine(x + 8.5 * u, y + 7 * u, x + 8.5 * u, y + 10 * u, 1.6, col)
    ThickLine(x + 8.5 * u, y + 10 * u, x + 11 * u, y + 10 * u, 1.6, col)
    ThickLine(x + 11 * u, y + 10 * u, x + 11 * u, y + 7 * u, 1.6, col)
end

-- Бомба: корпус + пробка + шнур + искра
local function IconBomb(x, y, s, col)
    local cx, cy = x + s * 0.42, y + s * 0.60
    Disc(cx, cy, s * 0.30, col)
    RectPoly(x + s * 0.55, y + s * 0.16, s * 0.16, s * 0.12, col)
    ThickLine(x + s * 0.62, y + s * 0.18, x + s * 0.78, y + s * 0.08, 2, col)
    local sx, sy = x + s * 0.84, y + s * 0.06
    Disc(sx, sy, s * 0.07, Color(255, 200, 80))
    ThickLine(sx - s * 0.12, sy, sx - s * 0.05, sy, 1.6, Color(255, 200, 80))
    ThickLine(sx, sy - s * 0.12, sx, sy - s * 0.05, 1.6, Color(255, 200, 80))
end

-- Щит + галочка в цвет фона
local function IconShield(x, y, s, col, detail)
    draw.NoTexture()
    local u = s / 16
    surface.SetDrawColor(col)
    surface.DrawPoly({
        { x = x + 8 * u, y = y + 1.5 * u },
        { x = x + 13.5 * u, y = y + 4 * u },
        { x = x + 13.5 * u, y = y + 8.5 * u },
        { x = x + 8 * u, y = y + 14.5 * u },
        { x = x + 2.5 * u, y = y + 8.5 * u },
        { x = x + 2.5 * u, y = y + 4 * u },
    })
    local wcol = detail or Color(255, 255, 255, 230)
    ThickLine(x + 5.5 * u, y + 8 * u, x + 7.5 * u, y + 10 * u, 2.2, wcol)
    ThickLine(x + 7.5 * u, y + 10 * u, x + 11 * u, y + 5.5 * u, 2.2, wcol)
end

-- Палитра: круг + 3 кляксы в цвет фона + кисть
local function IconPalette(x, y, s, col, detail)
    local cx, cy = x + s / 2, y + s / 2
    Disc(cx, cy, s * 0.38, col)
    local dot = detail or Color(255, 255, 255, 230)
    Disc(cx - s * 0.14, cy - s * 0.10, s * 0.06, dot)
    Disc(cx + s * 0.02, cy - s * 0.18, s * 0.06, dot)
    Disc(cx + s * 0.14, cy - s * 0.02, s * 0.06, dot)
    ThickLine(cx - s * 0.05, cy + s * 0.28, cx + s * 0.22, cy + s * 0.05, 2.4, dot)
end

T.IconDrawers = {
    cog = IconCog, gun = IconGun, bomb = IconBomb,
    shield = IconShield, palette = IconPalette,
}

function T.DrawIcon(name, x, y, s, col, detail)
    local fn = T.IconDrawers[name or "cog"]
    if not fn then return end
    fn(x, y, s, col or Color(255, 255, 255), detail)
end

-- Панель-иконка для сайдбара (красится в цвет текста, детали —
-- в цвет кнопки: та же формула, что в Paint вкладки, иначе на ховере
-- и активной детали выбиваются)
function T.IconPanel(parent, name)
    local p = vgui.Create("DPanel", parent)
    p:SetSize(20, 20)
    p:SetMouseInputEnabled(false)
    p:SetKeyboardInputEnabled(false)
    p.GeminiIcon = name or "cog"
    p.GeminiCol = nil
    function p:Paint(w, h)
        draw.NoTexture()
        local c = self.GeminiCol or T.Colors.text
        local bg = T.Colors.row
        local par = self:GetParent()
        if IsValid(par) then
            local hov = par.hover or 0
            if par.activeTab then
                bg = T.Mix(T.Colors.accent, Color(255, 255, 255), hov * 0.2)
            else
                bg = T.Mix(T.Colors.row, T.Colors.accent, hov * 0.35)
            end
        end
        T.DrawIcon(self.GeminiIcon, 0, 0, math.min(w, h), c, bg)
    end
    return p
end

-- Логотип в шапке: голова-круг + плечи-полукругом (как дефолтная
-- аватарка), без антенны. Плечи — верхняя половина эллипса полигоном,
-- строго внутри квадрата: целый диск торчал бы на заголовок
local function LogoHead(x, y, s, col)
    local cx = x + s / 2
    draw.NoTexture()
    local rx, ry = s * 0.40, s * 0.32
    local cy = y + s * 0.94
    local pts = {}
    for i = 0, 12 do
        local a = math.pi + i * math.pi / 12
        pts[#pts + 1] = { x = cx + math.cos(a) * rx, y = cy + math.sin(a) * ry }
    end
    pts[#pts + 1] = { x = cx + rx, y = y + s }
    pts[#pts + 1] = { x = cx - rx, y = y + s }
    surface.SetDrawColor(col)
    surface.DrawPoly(pts)
    -- Голова чистая
    Disc(cx, y + s * 0.32, s * 0.21, col)
    -- Буква G на теле: там широко, на голове ей тесно
    draw.SimpleText("G", "GeminiLogo", cx, y + s * 0.80,
        Color(255, 255, 255, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

T.LogoDrawers = { LogoHead }
T.LogoNames = { "Голова-бот" }
T.LogoNamesEN = { "Bot head" }

function T.DrawLogo(variant, x, y, s, col)
    local fn = T.LogoDrawers[(variant or 0) + 1]
    if not fn then fn = LogoHead end
    fn(x, y, s, col or Color(255, 255, 255))
end

function T.LogoVariant()
    local cv = GetConVar("geminibots_menu_logo")
    if not cv then return 0 end
    return math.Clamp(cv:GetInt(), 0, #T.LogoDrawers - 1)
end
