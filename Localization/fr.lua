if GetCVar("language.2") ~= "fr" then
    return
end

local strings = {
    SI_GRAVVY_BUILD_PLANNER_TITLE = "Planificateur de configurations",
    SI_GRAVVY_BUILD_PLANNER_DEFAULT_BUILD = "Nouvelle configuration",
    SI_GRAVVY_BUILD_PLANNER_DEFAULT_SETUP = "Configuration de base",
    SI_GRAVVY_BUILD_PLANNER_COPIED_BUILD_NAME = "Copie de <<1>>",
    SI_GRAVVY_BUILD_PLANNER_COPIED_SETUP_NAME = "Copie de <<1>>",
    SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_NAME = "Saisissez un nom de configuration.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_EXISTS = "Une configuration porte déjà ce nom.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_MISSING = "Cette configuration n'existe plus.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_REQUIRED = "Au moins une configuration est requise.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_NAME = "Saisissez un nom de variante.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_EXISTS = "Cette configuration possède déjà une variante de ce nom.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING = "Cette variante n'existe plus.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_REQUIRED = "Chaque configuration nécessite au moins une variante.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_SLOT = "Cet emplacement d'équipement n'est pas valide.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_SLOT_OCCUPIED = "Une arme à deux mains utilise cet emplacement.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_REQUIREMENT = "Cette exigence d'équipement n'est pas valide.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_NOTHING_TO_UNDO = "Il n'y a rien à annuler.",
}

for stringId, translation in pairs(strings) do
    SafeAddString(_G[stringId], translation, 1)
end
