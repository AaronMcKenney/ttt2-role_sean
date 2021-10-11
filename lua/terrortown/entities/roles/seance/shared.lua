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
	local SPEC_COLOR_A_RAISE_FLOOR = 0
	local SPEC_COLOR_A_RAISE_CEIL = 77
	local SPEC_COLOR = Color(200, 200, 0, SPEC_COLOR_A_FLOOR)
	local GRAV_CONST = 1000000 --Technically should be 6.67408 * 10^-11, but we're fudging the numbers.
	local POS_XY_VARIANCE_FLOOR = -100
	local POS_XY_VARIANCE_CEIL = 100
	local POS_Z_RAISE_FLOOR = 0
	local POS_Z_RAISE_CEIL = 75
	local POS_Z_VARIANCE_FLOOR = 0
	local POS_Z_VARIANCE_CEIL = 50
	local VEL_VARIANCE_FLOOR = -5
	local VEL_VARIANCE_CEIL = 5
	local MIN_DIST = 5
	local FADE_DIST = 300
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
	
	--BMF--local function CreateOrb(ply)
	--BMF--	ply.sean_orb = {}
	--BMF--	
	--BMF--	--Center of mass that the creates the "gravitational pull"
	--BMF--	ply.sean_orb.center = ply:GetPos()
	--BMF--	--Move it up slightly so it isn't in the floor
	--BMF--	ply.sean_orb.center.z = ply.sean_orb.center.z + POS_Z_RAISE_FLOOR
	--BMF--	
	--BMF--	ply.sean_orb.pos = Vector(
	--BMF--		ply.sean_orb.center.x + math.random(POS_VARIANCE_FLOOR, POS_VARIANCE_CEIL),
	--BMF--		ply.sean_orb.center.y + math.random(POS_VARIANCE_FLOOR, POS_VARIANCE_CEIL),
	--BMF--		ply.sean_orb.center.z + math.random(POS_VARIANCE_FLOOR, POS_VARIANCE_CEIL)
	--BMF--	)
	--BMF--	ply.sean_orb.vel = Vector(
	--BMF--		math.random(VEL_VARIANCE_FLOOR, VEL_VARIANCE_CEIL),
	--BMF--		math.random(VEL_VARIANCE_FLOOR, VEL_VARIANCE_CEIL),
	--BMF--		math.random(VEL_VARIANCE_FLOOR, VEL_VARIANCE_CEIL)
	--BMF--	)
	--BMF--end
	--BMF--
	--BMF--local function ComputeForce(ply, dist_magn)
	--BMF--	if dist_magn <= MIN_DIST then
	--BMF--		--Prevent divide by zeroes and large forces from flinging the orb to oblivion
	--BMF--		return Vector(0, 0, 0)
	--BMF--	end
	--BMF--	
	--BMF--	--Using the vectorized form of Newton's Universal Law of Gravitation:
	--BMF--	--F = G * m1 * m2 * (ud)/(d^3)
	--BMF--	--Where ud is the unit vector of the distance between m1 and m2 (dx/d, dy/d, dz/d)
	--BMF--	
	--BMF--	local dist_magn_quartic = dist_magn * dist_magn * dist_magn * dist_magn
	--BMF--	local dist_comp = Vector(
	--BMF--		ply.sean_orb.center.x - ply.sean_orb.pos.x,
	--BMF--		ply.sean_orb.center.y - ply.sean_orb.pos.y,
	--BMF--		ply.sean_orb.center.z - ply.sean_orb.pos.z
	--BMF--	)
	--BMF--	
	--BMF--	--Assume masses to be 1 (G is flubbed to account for this)
	--BMF--	local force = Vector(
	--BMF--		GRAV_CONST * dist_comp.x / dist_magn_quartic,
	--BMF--		GRAV_CONST * dist_comp.y / dist_magn_quartic,
	--BMF--		GRAV_CONST * dist_comp.z / dist_magn_quartic
	--BMF--	)
	--BMF--	
	--BMF--	return force
	--BMF--end
	--BMF--
	--BMF--local function AdvancementStep(ply, dist_magn)
	--BMF--	local force = ComputeForce(ply, dist_magn)
	--BMF--	
	--BMF--	--Assume masses to be 1, meaning that force is equivalent to acceleration
	--BMF--	--Assume dt to also be 1.
	--BMF--	ply.sean_orb.vel.x = ply.sean_orb.vel.x + force.x
	--BMF--	ply.sean_orb.vel.y = ply.sean_orb.vel.y + force.y
	--BMF--	ply.sean_orb.vel.z = ply.sean_orb.vel.z + force.z
	--BMF--	
	--BMF--	ply.sean_orb.pos.x = ply.sean_orb.pos.x + ply.sean_orb.vel.x
	--BMF--	ply.sean_orb.pos.y = ply.sean_orb.pos.y + ply.sean_orb.vel.y
	--BMF--	ply.sean_orb.pos.z = ply.sean_orb.pos.z + ply.sean_orb.vel.z
	--BMF--end
	
	local function CreateOrb2(ply)
		ply.sean_orb = {}
		
		--Center of mass that the creates the "gravitational pull"
		ply.sean_orb.center = ply:GetPos()
		
		--Raise orb's position as the center is usually in the floor.
		ply.sean_orb.pos_z_floor = ply.sean_orb.center.z + math.random(POS_Z_VARIANCE_FLOOR, POS_Z_VARIANCE_CEIL)
		ply.sean_orb.pos_z_raise = math.random(POS_Z_RAISE_FLOOR, POS_Z_RAISE_CEIL)
		ply.sean_orb.pos = Vector(
			ply.sean_orb.center.x + math.random(POS_XY_VARIANCE_FLOOR, POS_XY_VARIANCE_CEIL),
			ply.sean_orb.center.y + math.random(POS_XY_VARIANCE_FLOOR, POS_XY_VARIANCE_CEIL),
			ply.sean_orb.pos_z_floor
		)
		
		--Create a deep copy of the color here for SPEC_COLOR to avoid messing it up for everyone.
		ply.sean_orb.color_a_floor = math.random(SPEC_COLOR_A_FLOOR, SPEC_COLOR_A_CEIL)
		ply.sean_orb.color_a_raise = math.random(SPEC_COLOR_A_RAISE_FLOOR, SPEC_COLOR_A_RAISE_CEIL)
		ply.sean_orb.color = Color(SPEC_COLOR.r, SPEC_COLOR.g, SPEC_COLOR.b, ply.sean_orb.color_a_floor)
		
		ply.sean_orb.time_stamp = CurTime()
	end
	
	local function AdvancementStep2(ply)
		local time_delta = CurTime() - ply.sean_orb.time_stamp
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
		
		--BMF TODO
		--General idea:
		--For about 10 seconds, the spectator's position will not change.
		--Simuated movement will be put upon it, such that its position and transparency will fluctuate rapidly.
		--Explicitly, it should move in a random direction, losing transparency over space.
		--It is bound by a "cube" about the spectator's position, and will become completely transparent if it crosses the cube's threshold.
		--If it becomes too transparent, it will fade out and immediately fade in at a different position with a new direction.
		--For direction, the yellow orb is given an initial position and velocity, as well as a constant acceleration. This will give the yellow orb an arc to follow.
		--  If this is the first time the yellow orb is spawning (i.e. the player just died) the position and direction should look like it came from the corpse.
		--For best effects, the yellow orbs should sort of orbit the spectator's position most of the time, while allowing some leeway for them to veer off course.
		--  Simplest way to do this may actually be to reuse GravityColorizer logic.
		--
		--During each draw call, we'll check to see if the spectator's position has updated. 
		--If it has been updated, then:
		--  Over the course of 1 second, the center position that the yellow orb is moving about will be interpolated to the spectator's new position.
		--  If this new position is very far away (greater than the length of two "cubes" lets say) the yellow orb will lose transparency and fade out at the edge of "two cubes", regaining transparency once it is within "two cubes" of the new position.
		--BMF TODO
		
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
				--Draw a yellow orb about the spectator
				--BMF--if not ply.sean_orb then
				--BMF--	CreateOrb(ply)
				--BMF--end
				--BMF--
				--BMF----Note: Distance calls are very expensive. Minimize use of them!
				--BMF--local dist_magn = ply.sean_orb.center:Distance(ply.sean_orb.pos)
				--BMF--if dist_magn >= FADE_DIST then
				--BMF--	CreateOrb(ply)
				--BMF--end
				
				if not ply.sean_orb or ply:GetPos() ~= ply.sean_orb.center then
					CreateOrb2(ply)
				end
				
				render.DrawSphere(ply.sean_orb.pos, 15, 30, 30, ply.sean_orb.color)
				render.DrawSphere(ply.sean_orb.center, 15, 30, 30, Color(255, 0, 0, 255)) --SEAN_DEBUG
				
				--BMF--AdvancementStep(ply, dist_magn)
				AdvancementStep2(ply)
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