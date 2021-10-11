local L = LANG.GetLanguageTableReference("en")

-- GENERAL ROLE LANGUAGE STRINGS
L[SEANCE.name] = "Seance"
L["info_popup_" .. SEANCE.name] = [[You are the Seance. You can see the dead.]]
L["body_found_" .. SEANCE.abbr] = "They were the Seance."
L["search_role_" .. SEANCE.abbr] = "This person was the Seance!"
L["target_" .. SEANCE.name] = "Seance"
L["ttt2_desc_" .. SEANCE.name] = [[You are the Seance. You can see the dead.]]

-- OTHER ROLE LANGUAGE STRINGS
L["PLY_DIED_" .. SEANCE.name] = "Someone has died recently."
L["NAMED_PLY_DIED_" .. SEANCE.name] = "{name} has recently joined the deceased."
L["NAMED_PLY_DIED_LIST_" .. SEANCE.name] = "These {n} player(s) are dead (that you know of):\n{list}."
L["NUM_DEAD_" .. SEANCE.name] = "There are now {n} dead player(s) (that you know of)."
