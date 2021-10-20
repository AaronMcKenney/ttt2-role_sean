if SERVER then
	AddCSLuaFile()
	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_sean.vmt")
	util.AddNetworkString("TTT2SeanceInformAboutAll")
	util.AddNetworkString("TTT2SeanceInformAboutDeath")
	util.AddNetworkString("TTT2SeanceInformAboutDisconnect")
end

function ROLE:PreInitialize()
	self.color = Color(149, 199, 0, 255)
	self.abbr = "sean" -- abbreviation
	
	self.unknownTeam = true -- disables team voice chat.
	self.disableSync = false -- Do tell the player about his role

	self.defaultTeam = TEAM_INNOCENT -- the team name: roles with same team name are working together
	self.defaultEquipment = INNO_EQUIPMENT -- here you can set up your own default equipment

	-- ULX ConVars
	self.conVarData = {
		pct = 0.15, -- necessary: percentage of getting this role selected (per player)
		maximum = 1, -- maximum amount of roles in a round
		minPlayers = 4, -- minimum amount of players until this role is able to get selected
		credits = 0, -- the starting credits of a specific role
		shopFallback = SHOP_DISABLED,
		togglable = true, -- option to toggle a role for a client if possible (F1 menu)
		random = 30
	}
end

function ROLE:Initialize()
	roles.SetBaseRole(self, ROLE_INNOCENT)
end

--Text Mode Enum for text updates
TEXT_MODE = {SILENT = 0, UNNAMED = 1, NAMED = 2}

local function IsInSpecDM(ply)
	if SpecDM and (ply.IsGhost and ply:IsGhost()) then
		return true
	end
	
	return false
end

if SERVER then
	local function GetNumDeadPlys()
		local num_dead_plys = 0
		
		local plys = player.GetAll()
		for i = 1, #plys do
			local ply = plys[i]
			
			if not ply:Alive() or IsInSpecDM(ply) then
				num_dead_plys = num_dead_plys + 1
			end
		end
		
		return num_dead_plys
	end
	
	function ROLE:GiveRoleLoadout(ply, isRoleChange)
		if GetRoundState() ~= ROUND_ACTIVE then
			return
		end
		
		net.Start("TTT2SeanceInformAboutAll")
		local plys = player.GetAll()
		for i = 1, #plys do
			local ply = plys[i]
			
			net.WriteString(ply:SteamID64())
			net.WriteString(ply:GetName())
			net.WriteBool(ply.sean_sees_as_dead == true)
		end
		net.Send(ply)
	end
	
	local function InformSeanceAboutTheDeceased(victim, num_dead_plys)
		victim.sean_sees_as_dead = true
		
		local plys = player.GetAll()
		for i = 1, #plys do
			local ply = plys[i]
			
			if ply:GetSubRole() == ROLE_SEANCE then
				net.Start("TTT2SeanceInformAboutDeath")
				net.WriteString(victim:SteamID64())
				net.WriteString(victim:GetName())
				net.WriteInt(num_dead_plys, 16)
				net.Send(ply)
			end
		end
	end
	
	hook.Add("TTT2PostPlayerDeath", "TTT2PostPlayerDeathSeance", function(victim, inflictor, attacker)
		if GetRoundState() ~= ROUND_ACTIVE or IsInSpecDM(victim) then
			return
		end
		
		local notify_delay = GetConVar("ttt2_seance_notification_time"):GetInt()
		local num_dead_plys = GetNumDeadPlys()
		
		--print("SEAN_DEBUG TTT2PostPlayerDeathSeance: victim name=" .. victim:GetName() .. ", victim id=".. tostring(victim:SteamID64()) .. ", notify_delay=" .. tostring(notify_delay) .. ", num_dead_plys=" .. num_dead_plys)
		
		if notify_delay > 0 then
			timer.Create("SeanceInformDeathTimer_" .. victim:SteamID64(), GetConVar("ttt2_seance_notification_time"):GetInt(), 1, function()
				InformSeanceAboutTheDeceased(victim, num_dead_plys)
			end)
		else
			InformSeanceAboutTheDeceased(victim, num_dead_plys)
		end
	end)
	
	local function InformSeanceAboutDisconnect(disconnected_ply)
		if timer.Exists("SeanceInformDeathTimer_" .. disconnected_ply:SteamID64()) then
			timer.Remove("SeanceInformDeathTimer_" .. disconnected_ply:SteamID64())
		end
		disconnected_ply.sean_sees_as_dead = nil
		
		local plys = player.GetAll()
		for i = 1, #plys do
			local ply = plys[i]
			
			if ply:GetSubRole() == ROLE_SEANCE then
				net.Start("TTT2SeanceInformAboutDisconnect")
				net.WriteString(disconnected_ply:SteamID64())
				net.WriteString(disconnected_ply:GetName())
				net.Send(ply)
			end
		end
	end
	
	hook.Add("PlayerLoadout", "PlayerLoadoutSeance", function(ply)
		if GetRoundState() ~= ROUND_ACTIVE or not ply:Alive() or IsInSpecDM(ply) then
			return
		end
		
		--A now living player is "disconnected" from the "Astral Plain".
		InformSeanceAboutDisconnect(ply)
	end)
	
	hook.Add("PlayerDisconnected", "PlayerDisconnectedSeance", function(ply)
		if GetRoundState() ~= ROUND_ACTIVE then
			return
		end
		
		--Edge case: If a player disconnects, we need to stop trying to look at them.
		InformSeanceAboutDisconnect(ply)
	end)
	
	local function ResetSeanceDataForServer()
		local plys = player.GetAll()
		for i = 1, #plys do
			local ply = plys[i]
			if timer.Exists("SeanceInformDeathTimer_" .. ply:SteamID64()) then
				timer.Remove("SeanceInformDeathTimer_" .. ply:SteamID64())
			end
			ply.sean_sees_as_dead = nil
		end
	end
	hook.Add("TTTPrepareRound", "TTTPrepareRoundSeanceForServer", ResetSeanceDataForServer)
	hook.Add("TTTBeginRound", "TTTBeginRoundSeanceForServer", ResetSeanceDataForServer)
	hook.Add("TTTEndRound", "TTTEndRoundSeanceForServer", ResetSeanceDataForServer)
end

if CLIENT then
	--CONSTS
	--The exact color that is used for spectators, except slightly transparent
	local SPEC_COLOR_A_FLOOR = 22
	local SPEC_COLOR_A_CEIL = 44
	local SPEC_COLOR_A_RAISE_FLOOR = 11
	local SPEC_COLOR_A_RAISE_CEIL = 77
	local SPEC_COLOR = Color(200, 200, 0, SPEC_COLOR_A_FLOOR)
	local POS_XY_VARIANCE_FLOOR = -100
	local POS_XY_VARIANCE_CEIL = 100
	local POS_Z_RAISE_FLOOR = 10
	local POS_Z_RAISE_CEIL = 75
	local POS_Z_VARIANCE_FLOOR = 0
	local POS_Z_VARIANCE_CEIL = 50
	local FADE_DIST_SQRD = 300*300
	local FADE_TIME = 1
	local FADE_LAG_TBL = {0,0.2,0.4,0.6,0.8,1}
	local MIN_TIME_BEFORE_SWITCH = 9
	--Used for drawing outlines around props that fellow spectators have possessed.
	local MATERIAL_PROPSPEC_OUTLINE = Material("models/props_combine/portalball001_sheet")
	
	local function PlayerKeyCompare(ply, ply_id, ply_name)
		--The client only sees "nil" for Bot Steam IDs. It makes debugging tricky.
		--As a workaround, compare names for bots.
		if not ply_id or not ply:SteamID64() then
			--print("SEAN_DEBUG PlayerKeyCompare: Comparing " .. tostring(ply:GetName()) .. " to " .. tostring(ply_name) .. " (Name workaround for bots)")
			return (ply:GetName() == ply_name)
		else
			--print("SEAN_DEBUG PlayerKeyCompare: Comparing " .. tostring(ply:SteamID64()) .. " to " .. tostring(ply_id) .. " (" .. ply:GetName() .. ")")
			return (ply:SteamID64() == ply_id)
		end
	end
	
	net.Receive("TTT2SeanceInformAboutAll", function()
		local client = LocalPlayer()
		local mode = GetConVar("ttt2_seance_dead_text_mode"):GetInt()
		local num_dead_plys = 0
		local name_list = ""
		
		local plys = player.GetAll()
		for i = 1, #plys do
			local ply_i_id = net.ReadString()
			local ply_i_name = net.ReadString()
			local ply_i_is_dead = net.ReadBool()
			
			for j = 1, #plys do
				local ply_j = plys[j]
				
				if PlayerKeyCompare(ply_j, ply_i_id, ply_i_name) then
					if ply_i_is_dead then
						ply_j.sean_sees_as_dead = true
						num_dead_plys = num_dead_plys + 1
						
						if mode == TEXT_MODE.NAMED then
							if #name_list <= 0 then
								name_list = ply_i_name
							else
								name_list = name_list .. ", " .. ply_i_name
							end
						end
					else
						ply_j.sean_sees_as_dead = nil
					end
					
					break
				end
			end
		end
		
		if mode == TEXT_MODE.UNNAMED or (mode == TEXT_MODE.NAMED and num_dead_plys <= 0) then
			LANG.Msg("NUM_DEAD_" .. SEANCE.name, {n=num_dead_plys}, MSG_MSTACK_ROLE)
		elseif mode == TEXT_MODE.NAMED then
			LANG.Msg("NAMED_PLY_DIED_LIST_" .. SEANCE.name, {n=num_dead_plys, list=name_list}, MSG_MSTACK_ROLE)
		end
	end)
	
	net.Receive("TTT2SeanceInformAboutDeath", function()
		local client = LocalPlayer()
		local mode = GetConVar("ttt2_seance_dead_text_mode"):GetInt()
		local ply_id = net.ReadString()
		local ply_name = net.ReadString()
		local num_dead_plys = net.ReadInt(16)
		
		--print("SEAN_DEBUG TTT2SeanceInformAboutDeath: ply_name=" .. ply_name .. ", ply_id=" .. ply_id .. ", num_dead_plys=" .. tostring(num_dead_plys))
		
		local plys = player.GetAll()
		for i = 1, #plys do
			local ply = plys[i]
			
			if PlayerKeyCompare(ply, ply_id, ply_name) then
				ply.sean_sees_as_dead = true
				
				--print("SEAN_DEBUG TTT2SeanceInformAboutDeath: Marking " .. ply:GetName() .. " as dead.")
				
				if mode == TEXT_MODE.UNNAMED then
					LANG.Msg("PLY_DIED_" .. SEANCE.name, nil, MSG_MSTACK_ROLE)
				elseif mode == TEXT_MODE.NAMED then
					LANG.Msg("NAMED_PLY_DIED_" .. SEANCE.name, {name=ply:GetName()}, MSG_MSTACK_ROLE)
				end
				if mode ~= TEXT_MODE.SILENT then
					LANG.Msg("NUM_DEAD_" .. SEANCE.name, {n=num_dead_plys}, MSG_MSTACK_ROLE)
				end
				break
			end
		end
	end)
	
	net.Receive("TTT2SeanceInformAboutDisconnect", function()
		local client = LocalPlayer()
		local ply_id = net.ReadString()
		local ply_name = net.ReadString()
		
		--print("SEAN_DEBUG TTT2SeanceInformAboutDisconnect: ply_name=" .. ply_name .. ", ply_id=" .. ply_id)
		
		local plys = player.GetAll()
		for i = 1, #plys do
			local ply = plys[i]
			if PlayerKeyCompare(ply, ply_id, ply_name) then
				ply.sean_sees_as_dead = nil
				--print("SEAN_DEBUG TTT2SeanceInformAboutDisconnect: Marking " .. ply:GetName() .. " as disconnected.")
				break
			end
		end
	end)
	
	local function CreateOrb(ply, cur_time)
		if not ply.sean_orb then
			ply.sean_orb = {}
		else
			--Create a deep copy of the now stale final position and color.
			ply.sean_orb.stale = {}
			ply.sean_orb.stale.pos = Vector(ply.sean_orb.pos.x, ply.sean_orb.pos.y, ply.sean_orb.pos.z)
			ply.sean_orb.stale.color = Color(ply.sean_orb.color.r, ply.sean_orb.color.g, ply.sean_orb.color.b, ply.sean_orb.color.a)
		end
		
		--center is the position of where the player was actually recorded at.
		--Create a deep copy to better handle transitions between different positions.
		local ply_pos = ply:GetPos()
		ply.sean_orb.center = Vector(ply_pos.x, ply_pos.y, ply_pos.z)
		
		--Raise orb's position as the center is usually in the floor.
		ply.sean_orb.pos_z_floor = ply.sean_orb.center.z + math.random(POS_Z_VARIANCE_FLOOR, POS_Z_VARIANCE_CEIL)
		ply.sean_orb.pos_z_raise = math.random(POS_Z_RAISE_FLOOR, POS_Z_RAISE_CEIL)
		ply.sean_orb.pos = Vector(
			ply.sean_orb.center.x + math.random(POS_XY_VARIANCE_FLOOR, POS_XY_VARIANCE_CEIL),
			ply.sean_orb.center.y + math.random(POS_XY_VARIANCE_FLOOR, POS_XY_VARIANCE_CEIL),
			ply.sean_orb.pos_z_floor
		)
		ply.sean_orb.disp_pos = Vector(ply.sean_orb.pos.x, ply.sean_orb.pos.y, ply.sean_orb.pos.z)
		
		--Create a deep copy of the color here for SPEC_COLOR to avoid messing it up for everyone.
		ply.sean_orb.color_a_floor = math.random(SPEC_COLOR_A_FLOOR, SPEC_COLOR_A_CEIL)
		ply.sean_orb.color_a_raise = math.random(SPEC_COLOR_A_RAISE_FLOOR, SPEC_COLOR_A_RAISE_CEIL)
		ply.sean_orb.color = Color(SPEC_COLOR.r, SPEC_COLOR.g, SPEC_COLOR.b, ply.sean_orb.color_a_floor)
		ply.sean_orb.disp_color = Color(ply.sean_orb.color.r, ply.sean_orb.color.g, ply.sean_orb.color.b, ply.sean_orb.color.a)
		
		ply.sean_orb.time_stamp = cur_time
		ply.sean_orb.fade_lag = FADE_LAG_TBL[math.random(#FADE_LAG_TBL)]
		ply.sean_orb.time_switch = nil
	end
	
	local function Interpolate(x, x0, x1, y0, y1)
		--Linear Interpolation:
		--  y = y0 + (x - x0) * ((y1 - y0) / (x1 - x0))
		return y0 + (x - x0) * ((y1 - y0) / (x1 - x0))
	end
	
	local function Smoothstep(x, x0, x1)
		--"Smooths" a linear interpolation, such that if x is time the particle will move slowly at both the start and end
		
		--Clamp x between [0, 1], with 0 representing x0 ("left edge") and 1 representing x1 ("right edge")
		local x = math.Clamp((x - x0) / (x1 - x0), 0, 1)
		
		--Smoothstep:
		--  x' = 3*x*x - 2*x*x*x
		--  x' = x*x*(3 - 2*x)
		--  Where "x" is within [0,1]
		local ss_x = x * x * (3 - 2 * x)
		
		--Map the value from [0,1] back to [x0, x1]
		--  x'' = x0 + x' * (x1 - x0)
		return x0 + ss_x * (x1 - x0)
	end
	
	local function SSInterp(x, x0, x1, y0, y1)
		--Smoothstep Interpolation
		return Interpolate(Smoothstep(x, x0, x1), x0, x1, y0, y1)
	end
	
	local function AdvancementStep(ply, cur_time)
		local time_delta = cur_time - ply.sean_orb.time_stamp
		local t0 = ply.sean_orb.time_stamp
		local t1 = ply.sean_orb.time_stamp + FADE_TIME
		
		local pos_z_delta = (15 * time_delta) % (2 * ply.sean_orb.pos_z_raise)
		if pos_z_delta > ply.sean_orb.pos_z_raise then
			pos_z_delta = 2 * ply.sean_orb.pos_z_raise - pos_z_delta
		end
		local color_a_delta = (43 * time_delta) % (2 * ply.sean_orb.color_a_raise)
		if color_a_delta > ply.sean_orb.color_a_raise then
			color_a_delta = 2 * ply.sean_orb.color_a_raise - color_a_delta
		end
		
		ply.sean_orb.pos.z = ply.sean_orb.pos_z_floor + pos_z_delta
		ply.sean_orb.color.a = ply.sean_orb.color_a_floor + color_a_delta
		
		ply.sean_orb.disp_pos.x = ply.sean_orb.pos.x
		ply.sean_orb.disp_pos.y = ply.sean_orb.pos.y
		ply.sean_orb.disp_pos.z = ply.sean_orb.pos.z
		ply.sean_orb.disp_color.a = ply.sean_orb.color.a
		
		if time_delta < FADE_TIME then
			if not ply.sean_orb.stale then
				--Show the orb fading into existence by slowly raising its alpha value from 0.
				ply.sean_orb.disp_color.a = SSInterp(cur_time, t0, t1, 0, ply.sean_orb.color.a)
			else
				--If the orb recently changed positions, mess with the display position and alpha to show the sphere moving between its stale and new positions
				ply.sean_orb.disp_pos.x = SSInterp(cur_time, t0, t1, ply.sean_orb.stale.pos.x, ply.sean_orb.pos.x)
				ply.sean_orb.disp_pos.y = SSInterp(cur_time, t0, t1, ply.sean_orb.stale.pos.y, ply.sean_orb.pos.y)
				ply.sean_orb.disp_pos.z = SSInterp(cur_time, t0, t1, ply.sean_orb.stale.pos.z, ply.sean_orb.pos.z)
				ply.sean_orb.disp_color.a = SSInterp(cur_time, t0, t1, ply.sean_orb.stale.color.a, ply.sean_orb.color.a)
				
				--If the orb is too far away from either its stale or new position, it should be invisible to provide more of a ghostly warping effect.
				local stale_new_dist_sqrd = ply.sean_orb.pos:DistToSqr(ply.sean_orb.stale.pos)
				if stale_new_dist_sqrd > FADE_DIST_SQRD*2 then
					local disp_new_dist_sqrd = ply.sean_orb.disp_pos:DistToSqr(ply.sean_orb.pos)
					local stale_disp_dist_sqrd = ply.sean_orb.disp_pos:DistToSqr(ply.sean_orb.stale.pos)
					if disp_new_dist_sqrd < FADE_DIST_SQRD then
						ply.sean_orb.disp_color.a = SSInterp(disp_new_dist_sqrd, FADE_DIST_SQRD, 0, 0, ply.sean_orb.color.a)
					elseif stale_disp_dist_sqrd <= FADE_DIST_SQRD then
						ply.sean_orb.disp_color.a = SSInterp(stale_disp_dist_sqrd, 0, FADE_DIST_SQRD, ply.sean_orb.stale.color.a, 0)
					else
						ply.sean_orb.disp_color.a = 0
					end
				end
			end
		end
	end
	
	hook.Add("PostDrawTranslucentRenderables", "PostDrawTranslucentRenderablesSeance", function(bDepth, bSkybox)
		local client = LocalPlayer()
		if bSkybox or GetRoundState() ~= ROUND_ACTIVE or client:GetSubRole() ~= ROLE_SEANCE or not client:Alive() or IsInSpecDM(client) then
			return
		end
		
		--Draw yellow orbs on spectators, provided that enough time has passed for them to be visible to The Seance
		--Also draw yellow outlines on spectated props.
		
		--Note: Spectator positions are only updated every 10 seconds or so.
		--Except during the first few seconds when they are transitioning from alive to dead, where it updates multiple times each second.
		--So there are calculations here to fake movement.
		
		--Sets the material to a white material that can be easily recolored
		render.SetColorMaterial()
		
		local plys = player.GetAll()
		for i = 1, #plys do
			local ply = plys[i]
			if not ply.sean_sees_as_dead then
				ply.sean_orb = nil
				continue
			end
			
			local tgt = ply:GetObserverTarget()
			if IsValid(tgt) and tgt:GetNWEntity("spec_owner", nil) == ply then
				--Outline any props that are currently being possessed by spectators.
				render.MaterialOverride(MATERIAL_PROPSPEC_OUTLINE)
				render.SuppressEngineLighting(true)
				render.SetColorModulation(1, 0.5, 0)
				
				tgt:SetModelScale(1.05, 0)
				tgt:DrawModel()
				
				--Reset render parameters now that we have drawn the outline.
				render.SetColorModulation(1, 1, 1)
				render.SuppressEngineLighting(false)
				render.MaterialOverride(nil)
			elseif GetConVar("ttt2_seance_visual_orb_enabled"):GetBool() then
				local cur_time = CurTime()
				if not ply.sean_orb then
					CreateOrb(ply, cur_time)
				elseif ply:GetPos() ~= ply.sean_orb.center then
					--Create a new orb state, which the current orb will transition to.
					--Stagger orb creation via fade_lag, so that all of the orbs don't move at once.
					if not ply.sean_orb.time_switch and (cur_time - ply.sean_orb.time_stamp >= MIN_TIME_BEFORE_SWITCH) then
						ply.sean_orb.time_switch = cur_time
					end
					
					--print("SEAN_DEBUG Create Orb Check (" .. ply:GetName() .. "): cur_time=" .. tostring(cur_time) .. ", time_switch=" .. tostring(ply.sean_orb.time_switch) .. ", fade_lag=" .. tostring(ply.sean_orb.fade_lag))
					if ply.sean_orb.time_switch and (cur_time >= ply.sean_orb.time_switch + ply.sean_orb.fade_lag) then
						--SEAN_DEBUG --print("  CREATED NEW ORB") --SEAN_DEBUG
						CreateOrb(ply, cur_time)
					else
						AdvancementStep(ply, cur_time)
					end
				else
					AdvancementStep(ply, cur_time)
				end
				
				render.DrawSphere(ply.sean_orb.disp_pos, 15, 30, 30, ply.sean_orb.disp_color)
				--SEAN_DEBUG --render.DrawSphere(ply.sean_orb.center, 15, 30, 30, Color(255, 0, 0, 255)) --SEAN_DEBUG
			end
		end
	end)
	
	local function ResetSeanceDataForClient()
		local plys = player.GetAll()
		for i = 1, #plys do
			local ply = plys[i]
			ply.sean_orb = nil
			ply.sean_sees_as_dead = nil
		end
	end
	hook.Add("TTTPrepareRound", "TTTPrepareRoundSeanceForClient", ResetSeanceDataForClient)
	hook.Add("TTTBeginRound", "TTTBeginRoundSeanceForClient", ResetSeanceDataForClient)
	hook.Add("TTTEndRound", "TTTEndRoundSeanceForClient", ResetSeanceDataForClient)
end