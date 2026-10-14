--[[
    GeminiBots - Navmesh & Pathfinding System
    Поиск пути по навигационной сетке CNavArea с алгоритмом A*,
    защитой от тупиков лабиринтов и системой поиска/охоты на игроков.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Nav = GeminiBots.Nav or {}

-- Проверка, загружен ли navmesh на карте
function GeminiBots.Nav:IsAvailable()
    return navmesh and navmesh.IsLoaded and navmesh.IsLoaded()
end

-- Все зоны одним списком: GetAllNavAreas тяжелый, дергается из каждого
-- wanderEnter. Зоны статичны, кэш на 30 сек (nav_generate переживет)
GeminiBots.Nav.AreasCache = GeminiBots.Nav.AreasCache or {}
GeminiBots.Nav.AreasCacheAt = GeminiBots.Nav.AreasCacheAt or -99

function GeminiBots.Nav:AllAreas()
    local now = CurTime()
    if (self.AreasCacheAt or -99) + 30 < now or not self.AreasCache then
        local areas = nil
        if self:IsAvailable() then
            local ok, res = pcall(navmesh.GetAllNavAreas)
            if ok and res then areas = res end
        end
        self.AreasCache = areas or {}
        self.AreasCacheAt = now
    end
    return self.AreasCache
end

-- Получить случайную навигационную зону на карте
function GeminiBots.Nav:GetRandomArea()
    if not self:IsAvailable() then return nil end
    local areas = self:AllAreas()
    if not areas or #areas == 0 then return nil end

    return areas[math.random(#areas)]
end

-- Эвристика расстояния для A*
local function Heuristic(areaA, areaB)
    return areaA:GetCenter():DistToSqr(areaB:GetCenter())
end

-- Путь A* по зонам navmesh (не сквозь стены).
-- avoidPos/avoudRadius: точка упора (ящики, мебель — их в навмеше нет),
-- зоны рядом штрафуем, чтобы второй путь пошел в обход, а не в ту же стену
function GeminiBots.Nav:FindPath(startPos, endPos, avoidPos, avoidRadius)
    if not self:IsAvailable() then
        return { startPos, endPos }
    end

    local startArea = navmesh.GetNearestNavArea(startPos, false, 600, false, true)
    local goalArea = navmesh.GetNearestNavArea(endPos, false, 600, false, true)

    if not IsValid(startArea) or not IsValid(goalArea) then
        return { startPos, endPos }
    end

    if startArea == goalArea then
        return { startPos, endPos }
    end

    -- Очередь открытых и закрытых узлов
    local openSet = { [startArea:GetID()] = startArea }
    local cameFrom = {}

    local gScore = { [startArea:GetID()] = 0 }
    local fScore = { [startArea:GetID()] = Heuristic(startArea, goalArea) }

    local iterations = 0
    local maxIterations = 600 -- Увеличенный лимит для сложных лабиринтов и коридоров

    local closestArea = startArea
    local closestDistSqr = Heuristic(startArea, goalArea)

    while table.Count(openSet) > 0 and iterations < maxIterations do
        iterations = iterations + 1

        -- Ищем узел с минимальным fScore
        local current = nil
        local lowestF = math.huge

        for id, area in pairs(openSet) do
            local score = fScore[id] or math.huge
            if score < lowestF then
                lowestF = score
                current = area
            end
        end

        if not current then break end

        -- Отслеживаем ближайшую к цели зону, если путь будет неполным
        local distToGoalSqr = Heuristic(current, goalArea)
        if distToGoalSqr < closestDistSqr then
            closestDistSqr = distToGoalSqr
            closestArea = current
        end

        -- Цель достигнута
        if current == goalArea then
            local path = { endPos }
            local currId = current:GetID()

            while cameFrom[currId] do
                local prevArea = cameFrom[currId]
                table.insert(path, 1, prevArea:GetCenter())
                currId = prevArea:GetID()
            end

            table.insert(path, 1, startPos)
            return path
        end

        local currentId = current:GetID()
        openSet[currentId] = nil

        local adjacent = current:GetAdjacentAreas() or {}
        for _, neighbor in ipairs(adjacent) do
            if IsValid(neighbor) then
                local neighborId = neighbor:GetID()
                local tentativeG = (gScore[currentId] or math.huge) + current:GetCenter():Distance(neighbor:GetCenter())
                -- Обход упора: рядом с застрявшей точкой дорого
                if avoidPos and avoidRadius then
                    local nc = neighbor:GetCenter()
                    if nc:Distance(startPos) > 100
                        and nc:DistToSqr(avoidPos) < avoidRadius * avoidRadius then
                        tentativeG = tentativeG + 3000
                    end
                end

                if tentativeG < (gScore[neighborId] or math.huge) then
                    cameFrom[neighborId] = current
                    gScore[neighborId] = tentativeG
                    fScore[neighborId] = tentativeG + math.sqrt(Heuristic(neighbor, goalArea))
                    openSet[neighborId] = neighbor
                end
            end
        end
    end

    -- Точного пути нет: идем до ближайшей достигнутой зоны по коридору
    if closestArea and closestArea ~= startArea then
        local path = { closestArea:GetCenter() }
        local currId = closestArea:GetID()

        while cameFrom[currId] do
            local prevArea = cameFrom[currId]
            table.insert(path, 1, prevArea:GetCenter())
            currId = prevArea:GetID()
        end

        table.insert(path, 1, startPos)
        return path
    end

    return { startPos, endPos }
end

-- Получить случайную свободную точку для локального блуждания
function GeminiBots.Nav:GetRandomWanderPos(fromPos, maxRadius)
    local radius = maxRadius or 1200

    if self:IsAvailable() then
        local area = self:GetRandomArea()
        if IsValid(area) then
            return area:GetCenter()
        end
    end

    local angle = math.Rand(0, 360)
    local dir = Angle(0, angle, 0):Forward()
    local dist = math.Rand(300, radius)
    local dest = fromPos + dir * dist

    local tr = util.TraceLine({
        start = fromPos + Vector(0, 0, 20),
        endpos = dest + Vector(0, 0, 20),
        mask = MASK_SOLID_BRUSHONLY
    })

    if tr.Hit then
        return tr.HitPos + tr.HitNormal * 50
    end

    return dest
end

-- Получить дальнюю точку для активного исследования закрытых пространств / лабиринта
function GeminiBots.Nav:GetSearchPos(fromPos, minRadius, maxRadius)
    local minR = minRadius or 800
    local maxR = maxRadius or 3500

    if self:IsAvailable() then
        local areas = self:AllAreas()
        if areas and #areas > 0 then
            local candidates = {}
            for i = 1, math.min(#areas, 60) do
                local a = areas[math.random(#areas)]
                if IsValid(a) then
                    local d = fromPos:Distance(a:GetCenter())
                    if d >= minR and d <= maxR then
                        table.insert(candidates, a)
                    end
                end
            end

            if #candidates > 0 then
                return candidates[math.random(#candidates)]:GetCenter()
            end

            local randomArea = areas[math.random(#areas)]
            if IsValid(randomArea) then
                return randomArea:GetCenter()
            end
        end
    end

    return self:GetRandomWanderPos(fromPos, maxR)
end

-- Охота тянется к активности на карте
function GeminiBots.Nav:GetHuntPos(bot)
    if not bot or not IsValid(bot.ply) then return nil end
    local botPos = bot.ply:GetPos()

    local mode = GeminiBots.Config and GeminiBots.Config.Targeting
        and GeminiBots.Config.Targeting.Mode or "both"

    -- Ищем живых врагов по режиму целей: игроки и/или NPC
    local enemies = {}
    if mode ~= "npcs" then
        for _, ply in ipairs(player.GetAll()) do
            if ply ~= bot.ply and ply:Alive()
                and GeminiBots.Vision:IsValidTarget(bot, ply)
                and GeminiBots.Vision:CanTargetClass(bot, ply) then
                table.insert(enemies, ply)
            end
        end
    end

    if #enemies == 0 and mode ~= "players" then
        local pool = (GeminiBots.NPCAdapters and GeminiBots.NPCAdapters:AllNPCs())
            or ents.FindByClass("npc_*")
        for _, npc in ipairs(pool) do
            if IsValid(npc) and GeminiBots.Vision:IsValidTarget(bot, npc) then
                local d = botPos:Distance(npc:GetPos())
                if d >= 300 and d <= 3500 then
                    table.insert(enemies, npc)
                end
            end
        end
    end

    if #enemies > 0 then
        -- Выбираем случайного врага и берем зону в его секторе (с небольшим разбросом, чтобы не читерить)
        local targetPly = enemies[math.random(#enemies)]
        local enemyPos = targetPly:GetPos()

        -- Смещаем точку поиска в район врага с разбросом 300-600 юнитов
        local offset = Vector(math.Rand(-500, 500), math.Rand(-500, 500), 0)
        local roughAreaPos = enemyPos + offset

        if self:IsAvailable() then
            local nearest = navmesh.GetNearestNavArea(roughAreaPos, false, 800, false, true)
            if IsValid(nearest) then
                return nearest:GetCenter()
            end
        end

        return roughAreaPos
    end

    -- Если врагов не видно или нет, ищем удаленную точку на карте
    return self:GetSearchPos(botPos, 800, 3500)
end

--------------------------------------------------------------------------------
-- Голая карта: предлагаем админу сгенерировать навмеш попапом в стиле меню
--------------------------------------------------------------------------------
util.AddNetworkString("GeminiBots_NoNavmesh")
util.AddNetworkString("GeminiBots_NavGenerate")

hook.Add("InitPostEntity", "GeminiBots_NavWatch", function()
    timer.Simple(10, function()
        local cfg = GeminiBots.Config
        if not cfg or not cfg.Enabled then return end
        if navmesh.IsLoaded() then return end
        for _, ply in ipairs(player.GetHumans()) do
            if IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin()) then
                net.Start("GeminiBots_NoNavmesh")
                net.Send(ply)
            end
        end
        GeminiBots:Log("На карте нет навмеша, админам предложена генерация.")
    end)
end)

-- Админ нажал "Сгенерировать": штатный nav_generate, ждем готовности
net.Receive("GeminiBots_NavGenerate", function(_, ply)
    if not IsValid(ply) or (not ply:IsAdmin() and not ply:IsSuperAdmin()) then return end
    if navmesh.IsLoaded() or GeminiBots.NavGenRunning then return end
    GeminiBots.NavGenRunning = true
    GeminiBots.NavGenPolls = 0
    game.ConsoleCommand("nav_generate\n")
    ply:ChatPrint("[GeminiBots] Генерация навмеша запущена, сервер подвиснет на несколько минут.")
    GeminiBots:Log("Админ %s запустил генерацию навмеша.", ply:Nick())
    timer.Create("GeminiBots_NavGenWatch", 10, 0, function()
        GeminiBots.NavGenPolls = (GeminiBots.NavGenPolls or 0) + 1
        if navmesh.IsLoaded() then
            timer.Remove("GeminiBots_NavGenWatch")
            GeminiBots.NavGenRunning = false
            for _, p in ipairs(player.GetHumans()) do
                if IsValid(p) then
                    p:ChatPrint("[GeminiBots] Навмеш готов, боты поехали.")
                end
            end
            return
        end
        -- 20 минут ждем, дальше просим сменить карту вручную
        if GeminiBots.NavGenPolls > 120 then
            timer.Remove("GeminiBots_NavGenWatch")
            GeminiBots.NavGenRunning = false
            for _, p in ipairs(player.GetHumans()) do
                if IsValid(p) then
                    p:ChatPrint("[GeminiBots] Генерация затянулась: смените карту вручную.")
                end
            end
        end
    end)
end)
