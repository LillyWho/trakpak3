--General Entity Functions for Trakpak3
--MsgC(Trakpak3.Magenta,"Running TP3Lib\n")

--Helper function for finding by targetname
Trakpak3.FindByTargetname = function(name)
	if name and (name != "") then
		local result = ents.FindByName(name)[1]
		if IsValid(result) then
			return result, true
		end
	end
	return nil, false
end

-- A ? B : C
Trakpak3.FIF = function(condition, val_true, val_false)
	if condition then return val_true else return val_false end
end

function Trakpak3.Sign(num)
	if num>0 then
		return 1
	elseif num<0 then
		return -1
	else
		return 0
	end
end

--String Processing for Vectors
function Trakpak3.HammerStringToVector(str)
	local coords = string.Explode(" ",str)
	if coords[1] and coords[2] and coords[3] then
		return Vector(tonumber(coords[1]), tonumber(coords[2]), tonumber(coords[3]))
	end
	return nil
	
end

--String Processing for Angles
function Trakpak3.HammerStringToAngle(str)
	local coords = string.Explode(" ",str)
	if coords[1] and coords[2] and coords[3] then
		return Angle(tonumber(coords[1]), tonumber(coords[2]), tonumber(coords[3]))
	end
	return nil
	
end

--String Processing for Colors
function Trakpak3.HammerStringToColor(str)
	local coords = string.Explode(" ",str)
	if coords[1] and coords[2] and coords[3] then
		local alpha = coords[4]
		if alpha then alpha = tonumber(alpha) end
		return Color(tonumber(coords[1]), tonumber(coords[2]), tonumber(coords[3]), alpha or 255)
	end
	return nil
	
end

--RotateAroundAxis that actually returns a new angle
function Trakpak3.RotateAroundAxis(angle, axis, rotation)
	local newang = Angle()
	newang:Set(angle)
	newang:RotateAroundAxis(axis,rotation)
	return newang
end

--Finds the "root" entity in a chain (I.E. the one that the input entity is directly or indirectly parented to)
function Trakpak3.GetRoot(ent)
	if not ent:IsValid() then return end
	while ent:GetParent():IsValid() do
		ent = ent:GetParent()
	end
	return ent
end

--Sets multiple bodygroups, takes either an array (list) or a string separated by spaces.
function Trakpak3.SetBodygroups(ent, bgs)
	if not (ent and bgs) then return end
	
	local itype = type(bgs)
	
	if itype=="string" then
		bgs = string.Explode(" ",bgs)
	end
	
	if type(bgs)=="table" then
		for bg, part in ipairs(bgs) do ent:SetBodygroup(bg, tonumber(part)) end
	end
end

--Projects a point onto a line segment
function Trakpak3.LineProject(startpos, endpos, sample)
	local baseline = endpos-startpos
	local hypotenuse = sample-startpos
	local baselength = baseline:Length()
	local hyplength = hypotenuse:Length()
	
	--calculate baseline distance
	local progress = baseline:Dot(hypotenuse)/baselength
	local prognorm = progress/baselength
	
	--calculate distance to line
	local theta = math.acos(progress/hyplength)
	local opposite = math.sin(theta)*hyplength
	
	return progress, prognorm, opposite, baselength
end

function Trakpak3.ZZDistance(points, sample, tolerance)
	local cum_length = 0 --cum is short for cumulative you pervert
	for seg = 1, table.Count(points) - 1 do
		--get start and end points
		local startpos = points[seg]
		local endpos = points[seg+1]
		
		local progress, prognorm, perpdist, seglength = Trakpak3.LineProject(startpos, endpos, sample)
		if (prognorm <= 1) and (perpdist<=tolerance) then --point projection is before the end of this segment; return
			cum_length = cum_length + progress
			break
		else --point is either out of bounds or too far ahead, add the seg length and look in the next segment
			cum_length = cum_length + seglength
		end
	end
	
	return cum_length
end

--Unused
function Trakpak3.TotalDistance(points)
	local cum_length = 0
	for seg = 1, table.Count(points) - 1 do
		cum_length = cum_length + (points[seg+1] - points[seg]):Length()
	end
	return cum_length
end

function Trakpak3.Distance2D(v1, v2)
	local a = v1*Vector(1,1,0)
	local b = v2*Vector(1,1,0)
	return a:Distance(b)
end

--Dictionaries
Trakpak3.SpeedDictionary = {
	["FULL"] = 5,
	["LIMITED"] = 4,
	["MEDIUM"] = 3,
	["SLOW"] = 2,
	["RESTRICTED"] = 1,
	["STOP/DANGER"] = 0,
	
	[5] = "FULL",
	[4] = "LIMITED",
	[3] = "MEDIUM",
	[2] = "SLOW",
	[1] = "RESTRICTED",
	[0] = "STOP/DANGER"
}


--Global Init Variable
hook.Add("InitPostEntity","Trakpak3_GlobalInit",function()
	timer.Simple(5,function() Trakpak3.InitPostEntity = true end)
end)

--Mover Library, used for Turntables, Transfer tables, etc.
--[[
function Trakpak3.PhysicsInitMover(self)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:MakePhysicsObjectAShadow(false, false)
	self:SetMoveType(MOVETYPE_NOCLIP)
	self:SetMoveType(MOVETYPE_PUSH)
end

function Trakpak3.MoverSetLifetime(self, duration)
	local savetable = self:GetSaveTable()
	self:SetSaveValue("m_flMoveDoneTime", savetable.ltime + duration)
end

function Trakpak3.MoveToPosition(self, targetpos, speed)
	if not speed then return end
	if speed<=0 then return end
	
	local curpos = self:GetPos()
	local displacement = targetpos-curpos
	local duration = displacement:Length()/speed
	Trakpak3.MoverSetLifetime(self, duration)
	
	self:SetLocalVelocity(displacement:GetNormalized()*speed)
end
]]--
--Deprecated node chain finder
--[[
function Trakpak3.FindNodeChain(startname, endname)
	local debugme = false
	local discovered_nodes = {}
	local node_chain = {}
	local nodecount = 0
	local node, valid = Trakpak3.FindByTargetname(startname)
	local nodename = startname
	if debugme then
		print("\nStarting new chain find:")
		print(nodename, node, valid)
	end
	while valid do
		if discovered_nodes[nodename] then --Infinite Loop!
			if debugme then print("Already found node "..nodename..", breaking loop.") end
			break
		else --New node, record and find the next one if applicable
			nodecount = nodecount + 1
			discovered_nodes[nodename] = true
			node_chain[nodecount] = node:EntIndex()
			if debugme then print("Target: ",node.target) end
			if nodename==endname then --You've reached the last node, good job!
				if debugme then print("Node "..nodename.." is end of chain.") end
				break 
			elseif node.target and (node.target!="") then --There's another node
				nodename = node.target
				node, valid = Trakpak3.FindByTargetname(nodename)
				if debugme then print("Next Node: "..nodename) end
			else
				if debugme then print("End of the line!") end
				break
			end --End of the line
		end
	end
	if debugme then
		print("Final Chain: ")
		PrintTable(node_chain)
	end
	return node_chain, nodecount
end
]]--

--Ranger class blacklisting moved to lua/trakpak3/shared.lua