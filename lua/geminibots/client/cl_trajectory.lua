--[[
    GeminiBots - Trajectory Renderer (Client)
    Прием предсказанных траекторий гранат с сервера и отрисовка средствами
    клиента. Работает всегда, без developer: движковый debugoverlay требует
    developer ConVar и не сетится с дедика, поэтому рисуем сами.
]]--

GeminiBots = GeminiBots or {}
GeminiBots.Trajectories = GeminiBots.Trajectories or {}

net.Receive("GeminiBots_Trajectory", function()
    local thrower = net.ReadEntity()
    local n = net.ReadUInt(8)
    if n < 2 or n > 64 then return end

    local pts = {}
    for i = 1, n do
        pts[i] = net.ReadVector()
    end
    local landing = net.ReadVector()
    local col = Color(net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8))

    GeminiBots.Trajectories[thrower] = {
        points = pts,
        landing = landing,
        color = col,
        expire = CurTime() + 0.3
    }
end)

-- Чистим протухшие дуги, когда отрисовка выключена на сервере
hook.Add("Think", "GeminiBots_TrajectoryGC", function()
    for thrower, data in pairs(GeminiBots.Trajectories) do
        if CurTime() > data.expire then
            GeminiBots.Trajectories[thrower] = nil
        end
    end
end)

hook.Add("PostDrawTranslucentRenderables", "GeminiBots_DrawTrajectories", function(_, bSkybox)
    if bSkybox then return end
    if table.IsEmpty(GeminiBots.Trajectories) then return end

    for _, data in pairs(GeminiBots.Trajectories) do
        local pts = data.points
        if pts and #pts > 1 then
            for i = 1, #pts - 1 do
                render.DrawLine(pts[i], pts[i + 1], data.color, false)
            end
            render.DrawWireframeSphere(data.landing, 8, 8, 8, data.color)
        end
    end
end)
