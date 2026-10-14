--[[
    GeminiBots - Skill Presets (Shared)
    Встроенные пресеты сложности: готовые наборы настроек для ленивых,
    свои пресеты докладываются сверху через Q-меню/консоль.
    Значения — это имена ConVar'ов и их значения (применяются "как есть").
]]--

GeminiBots = GeminiBots or {}
GeminiBots.SkillPresets = GeminiBots.SkillPresets or {}

-- Ключи, входящие в пресет (слепок именно этих ConVar'ов)
GeminiBots.SkillPresets.Keys = {
    "geminibots_reaction_min",
    "geminibots_reaction_max",
    "geminibots_aim_speed",
    "geminibots_aim_smoothing",
    "geminibots_aim_prediction",
    "geminibots_aim_spread",
    "geminibots_aim_headshot_chance",
    "geminibots_vision_fov",
    "geminibots_vision_range",
    "geminibots_hearing_range",
    "geminibots_memory_duration",
    "geminibots_combat_min_dist",
    "geminibots_combat_max_dist",
    "geminibots_flee_health",
    "geminibots_bhop_chance"
}

GeminiBots.SkillPresets.Order = { "easy", "normal", "hard", "expert" }

GeminiBots.SkillPresets.BuiltIn = {
    easy = {
        label_ru = "Легко (мишени)",
        label_en = "Easy (targets)",
        values = {
            geminibots_reaction_min = "0.50",
            geminibots_reaction_max = "0.90",
            geminibots_aim_speed = "180",
            geminibots_aim_smoothing = "0.12",
            geminibots_aim_prediction = "0",
            geminibots_aim_spread = "3.5",
            geminibots_aim_headshot_chance = "0.10",
            geminibots_vision_fov = "90",
            geminibots_vision_range = "1800",
            geminibots_hearing_range = "400",
            geminibots_memory_duration = "3.0",
            geminibots_combat_min_dist = "300",
            geminibots_combat_max_dist = "700",
            geminibots_flee_health = "0.40",
            geminibots_bhop_chance = "0.30"
        }
    },
    normal = {
        label_ru = "Норма (по умолчанию)",
        label_en = "Normal (default)",
        values = {
            geminibots_reaction_min = "0.15",
            geminibots_reaction_max = "0.35",
            geminibots_aim_speed = "360",
            geminibots_aim_smoothing = "0.25",
            geminibots_aim_prediction = "1",
            geminibots_aim_spread = "1.8",
            geminibots_aim_headshot_chance = "0.35",
            geminibots_vision_fov = "110",
            geminibots_vision_range = "2500",
            geminibots_hearing_range = "700",
            geminibots_memory_duration = "6.0",
            geminibots_combat_min_dist = "250",
            geminibots_combat_max_dist = "900",
            geminibots_flee_health = "0.25",
            geminibots_bhop_chance = "0.85"
        }
    },
    hard = {
        label_ru = "Сложно (потеют)",
        label_en = "Hard (sweaty)",
        values = {
            geminibots_reaction_min = "0.08",
            geminibots_reaction_max = "0.18",
            geminibots_aim_speed = "500",
            geminibots_aim_smoothing = "0.40",
            geminibots_aim_prediction = "1",
            geminibots_aim_spread = "0.9",
            geminibots_aim_headshot_chance = "0.50",
            geminibots_vision_fov = "130",
            geminibots_vision_range = "3200",
            geminibots_hearing_range = "900",
            geminibots_memory_duration = "9.0",
            geminibots_combat_min_dist = "250",
            geminibots_combat_max_dist = "1100",
            geminibots_flee_health = "0.15",
            geminibots_bhop_chance = "1.0"
        }
    },
    expert = {
        label_ru = "Эксперт (машины)",
        label_en = "Expert (aimbots)",
        values = {
            geminibots_reaction_min = "0.03",
            geminibots_reaction_max = "0.08",
            geminibots_aim_speed = "650",
            geminibots_aim_smoothing = "0.60",
            geminibots_aim_prediction = "1",
            geminibots_aim_spread = "0.4",
            geminibots_aim_headshot_chance = "0.65",
            geminibots_vision_fov = "150",
            geminibots_vision_range = "4000",
            geminibots_hearing_range = "1200",
            geminibots_memory_duration = "12.0",
            geminibots_combat_min_dist = "200",
            geminibots_combat_max_dist = "1300",
            geminibots_flee_health = "0.08",
            geminibots_bhop_chance = "1.0"
        }
    }
}
