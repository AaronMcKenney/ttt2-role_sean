--ConVar syncing
CreateConVar("ttt2_seance_notification_time", "30", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_seance_visual_orb_enabled", "1", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_seance_dead_text_mode", "1", {FCVAR_ARCHIVE, FCVAR_NOTFIY})

hook.Add("TTTUlxDynamicRCVars", "TTTUlxDynamicSeanceCVars", function(tbl)
	tbl[ROLE_SEANCE] = tbl[ROLE_SEANCE] or {}
	
	--# How many seconds after a player's death must pass until The Seance is made aware (visually and/or textually)?
	--  ttt2_seance_notification_time [0..n] (default: 30)
	table.insert(tbl[ROLE_SEANCE], {
		cvar = "ttt2_seance_notification_time",
		slider = true,
		min = 0,
		max = 120,
		decimal = 0,
		desc = "ttt2_seance_notification_time (Def: 30)"
	})
	
	--# Can The Seance see Spectators as yellow orbs?
	--  ttt2_seance_visual_orb_enabled [0/1] (default: 1)
	table.insert(tbl[ROLE_SEANCE], {
		cvar = "ttt2_seance_visual_orb_enabled",
		checkbox = true,
		desc = "ttt2_seance_visual_orb_enabled (Def: 1)"
	})
	
	--# Will The Seance receive a text informing them about the recently deceased (Note: Information will not be up to date. It will be off by ttt2_seance_notification_time seconds)?
	--  ttt2_seance_dead_text_mode [0..2] (default: 1)
	--  # 0: No textual information
	--  # 1: They are told that some player died. They are told the number of dead players
	--  # 2: They are told that a player died, and their specific name. They are told the number of dead players
	table.insert(tbl[ROLE_SEANCE], {
		cvar = "ttt2_seance_dead_text_mode",
		combobox = true,
		desc = "ttt2_seance_dead_text_mode (Def: 1)",
		choices = {
			"0 - Silent",
			"1 - Unnamed Player and # Dead",
			"2 - A Named Player and # Dead"
		},
		numStart = 0
	})
end)

hook.Add("TTT2SyncGlobals", "AddSeanceGlobals", function()
	SetGlobalInt("ttt2_seance_notification_time", GetConVar("ttt2_seance_notification_time"):GetInt())
	SetGlobalBool("ttt2_seance_visual_orb_enabled", GetConVar("ttt2_seance_visual_orb_enabled"):GetBool())
	SetGlobalInt("ttt2_seance_dead_text_mode", GetConVar("ttt2_seance_dead_text_mode"):GetInt())
end)

cvars.AddChangeCallback("ttt2_seance_notification_time", function(name, old, new)
	SetGlobalInt("ttt2_seance_notification_time", tonumber(new))
end)
cvars.AddChangeCallback("ttt2_seance_visual_orb_enabled", function(name, old, new)
	SetGlobalBool("ttt2_seance_visual_orb_enabled", tobool(tonumber(new)))
end)
cvars.AddChangeCallback("ttt2_seance_dead_text_mode", function(name, old, new)
	SetGlobalInt("ttt2_seance_dead_text_mode", tonumber(new))
end)
