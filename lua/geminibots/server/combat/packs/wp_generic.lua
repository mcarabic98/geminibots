--[[
    GeminiBots - Generic Weapon Pack Adapters (detection only)
    Популярные паки, с которыми запускают аддон: боты берут их стволы
    на generic-скоринге селектора без спецтактики. Отдельные kind-правила
    добавляются сюда же, когда живые тесты покажут, что generic врет.
    Префиксы классов сверены с именами SWEP этих паков; если у вас
    пак с другим префиксом — допишите строку по образцу.
]]

local generic = {
    { id = "m9k", title = "M9K", prefixes = { "m9k_" } },
    { id = "tfa", title = "TFA", prefixes = { "tfa_" } },
    { id = "cw", title = "CW 2.0", prefixes = { "cw_" } },
    { id = "arccw", title = "ArcCW", prefixes = { "arccw_" } },
    { id = "fas2", title = "FA:S 2.0", prefixes = { "fas2_" } },
}

for _, def in ipairs(generic) do
    GeminiBots.WeaponAdapters:Register(def)
end
