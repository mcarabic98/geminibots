--[[
    GeminiBots - SWCS Weapon Pack Adapter
    Фаза 1: стрелковка работает через generic-скоринг селектора
    (в именах классов есть ak47/awp/deagle/m4/scout — кривые уже ловят),
    адаптер чинит только то, что generic ломает:
    - hegrenade/molotov: generic видит "grenade" и считает гранатометом
      прямого выстрела (launcher) -> переводим на навесной бросок (frag);
    - c4: ставить бот не умеет -> trap (вес 0, не берем);
    - taser: одиночный разряд вплотную -> short + длинная пауза;
    - flash/smoke/decoy: тактические броски фазы 3 -> tactical (пока вес 0);
    - ножи/щиты: рукопашка -> melee (дубль generic clip=-1, для надежности).
]]

GeminiBots.WeaponAdapters:Register({
    id = "swcs",
    title = "SWCS",
    prefixes = { "weapon_swcs_" },
    kinds = {
        { "planted", "trap" },
        { "c4", "trap" },
        { "breachcharge", "trap" },
        { "hegrenade", "frag" },
        { "incgrenade", "frag" },
        { "molotov", "frag" },
        { "incendiary", "frag" },
        { "flashbang", "tactical" },
        { "smoke", "tactical" },
        { "decoy", "tactical" },
        { "taser", "short" },
        { "tagrenade", "frag" }, -- граната-разведчик: навесом к врагу, подсвечивает
        { "healthshot", "trap" }, -- лечилка: бот пользоваться не умеет
        { "knife", "melee" },
        { "bayonet", "melee" },
        { "axe", "melee" },
        { "shield", "melee" },
    },
    burst = {
        { "taser", 1.2 },
    },
    -- Поправки типов по дампу weapon_dump (там HoldType врет)
    types = {
        { "m249", "mg" },
        { "negev", "mg" },
        { "aug", "rifle" },
        { "bizon", "smg" },
        { "mp5sd", "smg" },
    },
    -- Тактика только по кулдауну и на рабочей дистанции, иначе 0
    score = function(bot, class, dist)
        if not bot or not IsValid(bot.ply) then return 0 end
        if CurTime() < (bot.nextTacticalTime or 0) then return 0 end
        if dist < 300 or dist > 1100 then return 0 end
        return 70
    end,
    -- Куда кидать: дым — между собой и целью (завеса),
    -- флеш/декой — к позиции врага
    tacticPoint = function(bot, target, class)
        if not bot or not IsValid(bot.ply) or not IsValid(target) then return nil end
        local lower = string.lower(class or "")
        local tpos = target:GetPos()
        if string.find(lower, "smoke", 1, true) then
            local bp = bot.ply:GetPos()
            return bp + (tpos - bp) * 0.5 + Vector(0, 0, 40)
        end
        return tpos + Vector(0, 0, 30)
    end,
    -- Тяжелый удар ножом вплотную, с шансом
    extraButtons = function(bot, wep, dist)
        if dist < 110 and math.random() < 0.35 then return IN_ATTACK2 end
        return 0
    end,
})
