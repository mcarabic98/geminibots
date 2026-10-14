--[[
    GeminiBots - Murder Weapon Pack Adapter
    Стволы оригинального Murder: нож убийцы — рукопашка,
    магнум — обычный пистолет (ловится generic по HoldType revolver),
    руки — generic (в бою не используются: фильтр ролей не дает
    мирняку целей, убийца бьет ножом).
]]

GeminiBots.WeaponAdapters:Register({
    id = "murder",
    title = "Murder",
    prefixes = { "weapon_mu_" },
    kinds = {
        { "knife", "melee" },
    },
})
