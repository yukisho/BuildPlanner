if GetCVar("language.2") ~= "es" then
    return
end

local strings = {
    SI_GRAVVY_BUILD_PLANNER_TITLE = "Planificador de configuraciones",
    SI_GRAVVY_BUILD_PLANNER_DEFAULT_BUILD = "Nueva configuración",
    SI_GRAVVY_BUILD_PLANNER_DEFAULT_SETUP = "Configuración base",
    SI_GRAVVY_BUILD_PLANNER_COPIED_BUILD_NAME = "Copia de <<1>>",
    SI_GRAVVY_BUILD_PLANNER_COPIED_SETUP_NAME = "Copia de <<1>>",
    SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_NAME = "Introduce un nombre para la configuración.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_EXISTS = "Ya existe una configuración con ese nombre.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_MISSING = "Esa configuración ya no existe.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_REQUIRED = "Se necesita al menos una configuración.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_NAME = "Introduce un nombre para la variante.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_EXISTS = "Esta configuración ya contiene una variante con ese nombre.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING = "Esa variante ya no existe.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_REQUIRED = "Cada configuración necesita al menos una variante.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_SLOT = "Ese espacio de equipo no es válido.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_SLOT_OCCUPIED = "Un arma de dos manos está usando ese espacio.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_REQUIREMENT = "Ese requisito de equipo no es válido.",
    SI_GRAVVY_BUILD_PLANNER_ERROR_NOTHING_TO_UNDO = "No hay nada que deshacer.",
}

for stringId, translation in pairs(strings) do
    SafeAddString(_G[stringId], translation, 1)
end
