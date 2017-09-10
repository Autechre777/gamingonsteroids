--[[
API:
TPred:GetBestCastPosition(unit, delay, radius, range, speed, from, collision, spelltype)
Delay 	  -- in seconds
Collision -- is boolean
Spelltypes:
	"line"
	"circular"

]]



class "TPred"

function TPred:CutWaypoints(Waypoints, distance, unit)
	local result = {}
	local remaining = distance
	if distance > 0 then
		for i = 1, #Waypoints -1 do
			local A, B = Waypoints[i], Waypoints[i + 1]
			local dist = GetDistance(A, B)
			if dist >= remaining then
				result[1] = Vector(A) + remaining * (Vector(B) - Vector(A)):Normalized()
				
				for j = i + 1, #Waypoints do
					result[j - i + 1] = Waypoints[j]
				end
				remaining = 0
				break
			else
				remaining = remaining - dist
			end
		end
	else
		local A, B = Waypoints[1], Waypoints[2]
		result = Waypoints
		result[1] = Vector(A) - distance * (Vector(B) - Vector(A)):Normalized()
	end
	
	return result
end

function TPred:VectorMovementCollision(startPoint1, endPoint1, v1, startPoint2, v2, delay)
	local sP1x, sP1y, eP1x, eP1y, sP2x, sP2y = startPoint1.x, startPoint1.z, endPoint1.x, endPoint1.z, startPoint2.x, startPoint2.z
	local d, e = eP1x-sP1x, eP1y-sP1y
	local dist, t1, t2 = math.sqrt(d*d+e*e), nil, nil
	local S, K = dist~=0 and v1*d/dist or 0, dist~=0 and v1*e/dist or 0
	local function GetCollisionPoint(t) return t and {x = sP1x+S*t, y = sP1y+K*t} or nil end
	if delay and delay~=0 then sP1x, sP1y = sP1x+S*delay, sP1y+K*delay end
	local r, j = sP2x-sP1x, sP2y-sP1y
	local c = r*r+j*j
	if dist>0 then
		if v1 == math.huge then
			local t = dist/v1
			t1 = v2*t>=0 and t or nil
		elseif v2 == math.huge then
			t1 = 0
		else
			local a, b = S*S+K*K-v2*v2, -r*S-j*K
			if a==0 then 
				if b==0 then --c=0->t variable
					t1 = c==0 and 0 or nil
				else --2*b*t+c=0
					local t = -c/(2*b)
					t1 = v2*t>=0 and t or nil
				end
			else --a*t*t+2*b*t+c=0
				local sqr = b*b-a*c
				if sqr>=0 then
					local nom = math.sqrt(sqr)
					local t = (-nom-b)/a
					t1 = v2*t>=0 and t or nil
					t = (nom-b)/a
					t2 = v2*t>=0 and t or nil
				end
			end
		end
	elseif dist==0 then
		t1 = 0
	end
	return t1, GetCollisionPoint(t1), t2, GetCollisionPoint(t2), dist
end


function TPred:GetCurrentWayPoints(object)
	local result = {}
	if object.pathing.hasMovePath then
		table.insert(result, Vector(object.pos.x,object.pos.y, object.pos.z))
		for i = object.pathing.pathIndex, object.pathing.pathCount do
			path = object:GetPath(i)
			table.insert(result, Vector(path.x, path.y, path.z))
		end
	else
		table.insert(result, object and Vector(object.pos.x,object.pos.y, object.pos.z) or Vector(object.pos.x,object.pos.y, object.pos.z))
	end
	return result
end
function GetDistanceSqr(p1, p2)
	assert(p1, "GetDistance: invalid argument: cannot calculate distance to "..type(p1))
	
	return (p1.x - p2.x) ^ 2 + ((p1.z or p1.y) - (p2.z or p2.y)) ^ 2
end

function GetDistance(p1, p2)
	return math.sqrt(GetDistanceSqr(p1, p2))
end

function TPred:GetWaypointsLength(Waypoints)
	local result = 0
	for i = 1, #Waypoints -1 do
		result = result + GetDistance(Waypoints[i], Waypoints[i + 1])
	end
	return result
end

function TPred:CalculateTargetPosition(unit, delay, radius, speed, from, spelltype)
	local Waypoints = {}
	local Position, CastPosition = Vector(unit.pos), Vector(unit.pos)
	local t
	
	Waypoints = self:GetCurrentWayPoints(unit)
	local Waypointslength = self:GetWaypointsLength(Waypoints)
	if #Waypoints == 1 then
		Position, CastPosition = Vector(Waypoints[1].x, Waypoints[1].y, Waypoints[1].z), Vector(Waypoints[1].x, Waypoints[1].y, Waypoints[1].z)
		return Position, CastPosition
	elseif (Waypointslength - delay * unit.ms + radius) >= 0 then
		local tA = 0
		Waypoints = self:CutWaypoints(Waypoints, delay * unit.ms - radius)
		
		if speed ~= math.huge then
			for i = 1, #Waypoints - 1 do
				local A, B = Waypoints[i], Waypoints[i+1]
				if i == #Waypoints - 1 then
					B = Vector(B) + radius * Vector(B - A):Normalized()
				end

				local t1, p1, t2, p2, D = self:VectorMovementCollision(A, B, unit.ms, Vector(from.x,from.y,from.z), speed)
				local tB = tA + D / unit.ms
				t1, t2 = (t1 and tA <= t1 and t1 <= (tB - tA)) and t1 or nil, (t2 and tA <= t2 and t2 <= (tB - tA)) and t2 or nil
				t = t1 and t2 and math.min(t1, t2) or t1 or t2
				if t then
					CastPosition = t==t1 and Vector(p1.x, 0, p1.y) or Vector(p2.x, 0, p2.y)
					break
				end
				tA = tB
			end
		else
			t = 0
			CastPosition = Vector(Waypoints[1].x, Waypoints[1].y, Waypoints[1].z)
		end
		
		if t then
			if (self:GetWaypointsLength(Waypoints) - t * unit.ms - radius) >= 0 then
				Waypoints = self:CutWaypoints(Waypoints, radius + t * unit.ms)
				Position = Vector(Waypoints[1].x, Waypoints[1].y, Waypoints[1].z)
			else
				Position = CastPosition
			end
		elseif unit.type ~= myHero.type then
			CastPosition = Vector(Waypoints[#Waypoints].x, Waypoints[#Waypoints].y, Waypoints[#Waypoints].z)
			Position = CastPosition
		end
		
	elseif unit.type ~= myHero.type then
		CastPosition = Vector(Waypoints[#Waypoints].x, Waypoints[#Waypoints].y, Waypoints[#Waypoints].z)
		Position = CastPosition
	end
	
	return Position, CastPosition
end

function VectorPointProjectionOnLineSegment(v1, v2, v)
	assert(v1 and v2 and v, "VectorPointProjectionOnLineSegment: wrong argument types (3 <Vector> expected)")
	local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
	local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
	local pointLine = { x = ax + rL * (bx - ax), y = ay + rL * (by - ay) }
	local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
	local isOnSegment = rS == rL
	local pointSegment = isOnSegment and pointLine or { x = ax + rS * (bx - ax), y = ay + rS * (by - ay) }
	return pointSegment, pointLine, isOnSegment
end


function TPred:CheckCol(unit, minion, Position, delay, radius, range, speed, from, draw)
	if unit.networkID == minion.networkID then 
		return false
	end
	--[[Check first if the minion is going to be dead when skillshots reaches his position]]
	if minion.type ~= myHero.type and _G.SDK.HealthPrediction:GetPrediction(minion, delay + GetDistance(from, minion.pos) / speed - Game.Latency()/1000) < 0 then
		return false
	end
	
	local waypoints = self:GetCurrentWayPoints(minion)
	local MPos, CastPosition = #waypoints == 1 and Vector(minion.pos) or self:CalculateTargetPosition(minion, delay, radius, speed, from, "line")
	
	if GetDistanceSqr(from, MPos) <= (range)^2 and GetDistanceSqr(from, minion.pos) <= (range + 100)^2 then
		local buffer = (#waypoints > 1) and 8 or 0 
		
		if minion.type == myHero.type then
			buffer = buffer + minion.boundingRadius
		end
		
		if #waypoints > 1 then
			local proj1, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(from, Position, Vector(MPos))
			if isOnSegment and (GetDistanceSqr(MPos, proj1) <= (minion.boundingRadius + radius + buffer) ^ 2) then
				return true
			end
		end
		
		local proj2, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(from, Position, Vector(minion.pos))
		if isOnSegment and (GetDistanceSqr(minion.pos, proj2) <= (minion.boundingRadius + radius + buffer) ^ 2) then
			return true
		end
	end
end

function TPred:CheckMinionCollision(unit, Position, delay, radius, range, speed, from)
	Position = Vector(Position)
	from = from and Vector(from) or myHero.pos
	local result = false
	for i, minion in ipairs(_G.SDK.ObjectManager:GetEnemyMinions(range)) do
		if self:CheckCol(unit, minion, Position, delay, radius, range, speed, from, draw) then
			if not draw then
				return true
			else
				result = true
			end
		end
	end
	for i, minion in ipairs(_G.SDK.ObjectManager:GetMonsters(range)) do
		if self:CheckCol(unit, minion, Position, delay, radius, range, speed, from, draw) then
			if not draw then
				return true
			else
				result = true
			end
		end
	end
	for i, minion in ipairs(_G.SDK.ObjectManager:GetOtherEnemyMinions(range)) do
		if minion.team ~= myHero.team and self:CheckCol(unit, minion, Position, delay, radius, range, speed, from, draw) then
			if not draw then
				return true
			else
				result = true
			end
		end
	end
	return false
end

function TPred:GetBestCastPosition(unit, delay, radius, range, speed, from, collision, spelltype)
	assert(unit, "TPred: Target can't be nil")
	
	range = range and range - 4 or math.huge
	radius = radius == 0 and 1 or (radius + unit.boundingRadius) - 4
	speed = speed and speed or math.huge

	if from.networkID and from.networkID == myHero.networkID then
		from = Vector(myHero)
	end
	local IsFromMyHero = GetDistanceSqr(from, myHero.pos) < 50*50 and true or false
	
	delay = delay + (0.07 + Game.Latency() / 2000)

	local Position, CastPosition = self:CalculateTargetPosition(unit, delay, radius, speed, from, spelltype)
	local HitChance = 1

	--[[Out of range]]
	if IsFromMyHero then
		if (spelltype == "line" and GetDistanceSqr(from, Position) >= range * range) then
			HitChance = 0
		end
		if (spelltype == "circular" and (GetDistanceSqr(from, Position) >= (range + radius)^2)) then
			HitChance = 0
		end
		if (GetDistanceSqr(from, Position) > range ^ 2) then
			HitChance = 0
		end
	end
	radius = radius - unit.boundingRadius + 4	
	if collision and HitChance > 0 then
		if collision and self:CheckMinionCollision(unit, unit, delay, radius, range, speed, from) then
			HitChance = -1
		elseif self:CheckMinionCollision(unit, Position, delay, radius, range, speed, from) then
			HitChance = -1
		elseif self:CheckMinionCollision(unit, CastPosition, delay, radius, range, speed, from) then
			HitChance = -1
		end
	end

	return CastPosition, HitChance, Position
end
