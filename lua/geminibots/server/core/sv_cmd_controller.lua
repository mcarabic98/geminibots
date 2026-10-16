--[[
    GeminiBots - Command Controller
    Перехват StartCommand для управления движениями, кнопками и сглаживанием взгляда ботов.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Controller = GeminiBots.Controller or {}

-- Плавное приближение углов с учетом кратчайшего пути по кругу (-180..180)
local function ApproachAngle(current, target, maxStep)
    local diff = math.AngleDifference(target, current)
    return current + math.Clamp(diff, -maxStep, maxStep)
end

-- Один битый угол заражает current навсегда: NaN-гард с откатом
local function SafeAngle(v, fallback)
    if v ~= v then return fallback end
    return v
end

-- Сглаживание направления взгляда: один кламп-шаг к цели за тик.
-- Второго Lerp назад нет (давал скорость в разы ниже aimSpeed
-- и вечное "почти навелся")
function GeminiBots.Controller:SmoothAngles(bot, current, desired, dt)
    local cfg = GeminiBots.Config
    local am = GeminiBots.BotAim(bot)
    local aimSpeed = am.speed

    local maxStep = aimSpeed * dt

    local p = ApproachAngle(current.p, desired.p, maxStep)
    local y = ApproachAngle(current.y, desired.y, maxStep)
    p, y = SafeAngle(p, current.p), SafeAngle(y, current.y)

    return Angle(math.Clamp(p, -89, 89), math.NormalizeAngle(y), 0)
end

-- Проверка взаимодействия с дверями перед ботом.
-- Трейс каждый 3-й тик бота (20 Гц хватает за глаза, было 60)
local function CheckDoorInteraction(ply, cmd, bot)
    bot.doorTick = (bot.doorTick or 0) + 1
    if bot.doorTick % 3 ~= 0 then return end
    local doorRange = (GeminiBots.Config and GeminiBots.Config.DoorInteractionRange) or 65
    local tr = util.TraceLine({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:GetAimVector() * doorRange,
        filter = ply,
        mask = MASK_SOLID
    })

    if tr.Hit and IsValid(tr.Entity) then
        local class = tr.Entity:GetClass()
        if string.find(class, "door") or string.find(class, "button") then
            cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_USE))
        end
    end
end

-- Главный хук StartCommand для всех ботов
hook.Add("StartCommand", "GeminiBots_StartCommand_Controller", function(ply, cmd)
    if not IsValid(ply) or not ply:IsBot() then return end
    if not ply:Alive() then return end

    local cfg = GeminiBots.Config
    if not cfg or not cfg.Enabled then return end

    local bot = GeminiBots:GetBot(ply)
    if not bot then
        bot = GeminiBots:RegisterBot(ply)
        if not bot then return end
    end

    local dt = FrameTime()
    if dt <= 0 then dt = 0.015 end

    -- 1. Сглаживание и установка углов обзора.
    -- cmd:SetViewAngles у ботов движок игнорирует (движение из того же cmd
    -- применяется, а взгляд застывает с респауна — доказано зондом
    -- geminibots_bot_aim: current сошелся с desired, eye не двинулся).
    -- Поэтому ставим взгляд напрямую, как делают боты HL2DM
    bot.currentViewAngles = GeminiBots.Controller:SmoothAngles(
        bot,
        bot.currentViewAngles or ply:EyeAngles(),
        bot.desiredViewAngles or ply:EyeAngles(),
        dt
    )

    cmd:SetViewAngles(bot.currentViewAngles)
    ply:SetEyeAngles(bot.currentViewAngles)

    -- 2. Применение движений (ForwardMove / SideMove / UpMove)
    cmd:SetForwardMove(bot.forwardMove or 0)
    cmd:SetSideMove(bot.sideMove or 0)
    cmd:SetUpMove(bot.upMove or 0)

    -- 3. Применение нажатия кнопок (IN_ATTACK, IN_JUMP, IN_DUCK и т.д.)
    cmd:SetButtons(bot.buttons or 0)

    -- 4. Автоматическое открытие дверей
    CheckDoorInteraction(ply, cmd, bot)

    -- 5. Автопрыжок при утыкании в небольшое препятствие
    if (bot.forwardMove or 0) > 50 and ply:IsOnGround() then
        local vel = ply:GetVelocity():Length2D()
        if vel < 25 then
            -- Если бот пытается бежать вперед, но застрял на земле, пробуем перепрыгнуть
            cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_JUMP))
        end
    end

    -- 6. Баннихоп: прыжок в момент касания земли на ходу.
    -- Работает везде (патруль без врагов, бой, бегство): бот резво скачет
    -- по карте вместо унылого бега. Ролл шанса — раз на приземление.
    local bhop = cfg.BunnyHop
    if bhop and bhop.Enabled then
        -- Остановка бхопа возле источника звука и в присяде
        local duckHeld = bit.band(bot.buttons or 0, IN_DUCK) ~= 0
        local nearDest = false
        if bot.pathTargetPos and IsValid(ply) then
            nearDest = ply:GetPos():DistToSqr(bot.pathTargetPos) < (250 * 250)
        end
        if not duckHeld and not nearDest then
            if not ply:IsOnGround() then
                bot.bhopRolled = false
            elseif not bot.bhopRolled then
                bot.bhopRolled = true
                local chance = bhop.Chance
                if chance == nil then chance = 0.85 end
                bot.bhopSkip = math.random() > chance
            end

            if ply:IsOnGround() and not bot.bhopSkip
                and ply:GetMoveType() ~= MOVETYPE_LADDER
                and not ply:Crouching() then
                local moving = math.abs(bot.forwardMove or 0) > 50
                    or math.abs(bot.sideMove or 0) > 50
                -- Только на ходу: стоя на месте прыгать бессмысленно
                -- (застревание отдельно отрабатывает автопрыжок выше)
                if moving and ply:GetVelocity():Length2D() > 60 then
                    cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_JUMP))
                end
            end
        end
    end
end)
