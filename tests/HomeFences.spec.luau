--!strict
-- Builds homes at every level with the real builder and checks where every fence piece lands (Dylan, 19 Oct: "fences
-- r bugged? lets double check the placements"). Each piece must stay inside its own home's wedge (so it never touches
-- the neighbour's fence), behind the open front and in front of the back wall, on or above the floor, near its edge
-- (out of the middle of the home), and clear of the padlock, the Index box, the spawn pad, the back studs and the
-- Speed wheel at every wheel level; the corner props and back dressing stay clear of the fences too.
-- Studio EDIT mode, from the command bar:
--   local s = game.ServerStorage.TinyToyHeistTests["HomeFences.spec"]:Clone()
--   print(require(s)(game.ReplicatedStorage.Shared:Clone(), game.ServerStorage.TinyToyHeistTools.Bedroom))
return function(shared: Folder, tools: Folder): any
	local function fresh(m: Instance): any
		return (require :: any)(m:Clone())
	end
	local MapConfig = fresh(shared:WaitForChild("MapConfig")).unscaled
	local Kit = fresh(tools:WaitForChild("Kit"))
	local Homes = fresh(tools:WaitForChild("Homes"))
	Kit.yieldEvery = 0

	local LIFT, BD, inset = MapConfig.BURROW_FLOOR_LIFT, MapConfig.BURROW_DEPTH, MapConfig.FENCE_INSET
	local hw = MapConfig.homeHalfWidth
	local failures: { string } = {}
	local checks = 0
	local seen: { [string]: boolean } = {}
	local function check(ok: boolean, message: string)
		checks += 1
		-- each problem once per piece, not once per corner
		local key = message:gsub("%(.*%)", "")
		if not ok and not seen[key] and #failures < 60 then
			seen[key] = true
			table.insert(failures, message)
		end
	end

	type Box = { min: Vector3, max: Vector3, corners: { Vector3 } }
	-- a part's box in home space
	local function box(frame: CFrame, p: BasePart): Box
		local s = p.Size / 2
		local corners = {}
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local c = frame:PointToObjectSpace((p.CFrame * CFrame.new(s.X * x, s.Y * y, s.Z * z)).Position)
					table.insert(corners, c)
					lo, hi = lo:Min(c), hi:Max(c)
				end
			end
		end
		return { min = lo, max = hi, corners = corners }
	end
	-- a long part (a rail, a ruler) turned along the fence has a much wider box than it really is, so test it as short
	-- pieces: its box cut into lengths of at most 3 along its longest side
	local function chunks(frame: CFrame, p: BasePart): { Box }
		local s = p.Size
		local axis = if s.X >= s.Y and s.X >= s.Z
			then Vector3.xAxis
			elseif s.Y >= s.Z then Vector3.yAxis
			else Vector3.zAxis
		local length = s:Dot(axis)
		local n = math.max(1, math.ceil(length / 3))
		if n == 1 then
			return { box(frame, p) }
		end
		local out = {}
		local piece = s - axis * length + axis * (length / n)
		for k = 1, n do
			local offset = axis * (-length / 2 + (k - 0.5) * length / n)
			local fake = { Size = piece, CFrame = p.CFrame * CFrame.new(offset) }
			table.insert(out, box(frame, fake :: any))
		end
		return out
	end
	local function boxes(frame: CFrame, root: Instance?): { Box }
		local out = {}
		if root then
			if root:IsA("BasePart") then
				table.insert(out, box(frame, root))
			end
			for _, d in root:GetDescendants() do
				if d:IsA("BasePart") and d.Transparency < 1 then
					table.insert(out, box(frame, d))
				end
			end
		end
		return out
	end
	local function overlap(a: Box, b: Box, gap: number): boolean
		return a.min.X < b.max.X + gap
			and b.min.X < a.max.X + gap
			and a.min.Y < b.max.Y + gap
			and b.min.Y < a.max.Y + gap
			and a.min.Z < b.max.Z + gap
			and b.min.Z < a.max.Z + gap
	end

	local function hits(list: { Box }, b: Box): boolean
		for _, a in list do
			if overlap(a, b, 0) then
				return true
			end
		end
		return false
	end
	local wheelLevels = { 1, 4, 7 }
	if #Homes.WHEEL_LOOK > 7 then
		for w = 10, #Homes.WHEEL_LOOK, 3 do
			table.insert(wheelLevels, w)
		end
		table.insert(wheelLevels, #Homes.WHEEL_LOOK)
	end
	local widest = { level = 0, x = 0 }

	for _, index in { 1, 4, 8 } do
		local frame = MapConfig.homeFrame(index)
		for level = 1, #MapConfig.HOLE_LEVELS do
			local holder = Instance.new("Model")
			local home = Homes.build(Kit, MapConfig, holder, index, level)
			local tag = ("home %d Lv %d"):format(index, level)
			local fence = home:FindFirstChild("Fence")
			check(fence ~= nil, tag .. ": no fence")
			local pieces: { { box: Box, chunks: { Box }, name: string, side: string } } = {}
			for _, sideName in { "Left", "Right" } do
				local group = fence and fence:FindFirstChild(sideName)
				check(group ~= nil, tag .. ": no " .. sideName .. " fence")
				local lowest = math.huge
				for _, p in (if group then group:GetDescendants() else {}) do
					if p:IsA("BasePart") then
						local b = box(frame, p)
						local what = ("%s %s %s"):format(tag, sideName, p.Name)
						table.insert(pieces, { box = b, chunks = chunks(frame, p), name = what, side = sideName })
						lowest = math.min(lowest, b.min.Y)
						check(typeof(p:GetAttribute("U")) == "number", what .. ": no U")
						check(not p.CanCollide, what .. ": collides")
						for _, c in b.corners do
							local edge = hw(math.max(c.Z, 0))
							check(
								math.abs(c.X) <= edge + 0.05,
								("%s crosses into the neighbour (x %.2f, edge %.2f)"):format(what, c.X, edge)
							)
							check(c.Z >= -0.05, ("%s pokes past the open front (z %.2f)"):format(what, c.Z))
							check(c.Z <= BD + 0.05, ("%s goes into the back wall (z %.2f)"):format(what, c.Z))
							check(c.Y >= LIFT - 0.05, ("%s is sunk into the floor (y %.2f)"):format(what, c.Y))
							check(
								math.abs(c.X) >= edge - inset - 14,
								("%s sticks into the home (x %.2f)"):format(what, c.X)
							)
						end
					end
				end
				check(
					math.abs(lowest - LIFT) < 0.1,
					("%s %s fence floats or sinks (bottom %.2f)"):format(tag, sideName, lowest)
				)
			end

			-- props, studs and dressing must stay clear of the fences
			local clear: { { name: string, boxes: { Box } } } = {
				{ name = "padlock", boxes = boxes(frame, home:FindFirstChild("LockButton")) },
				{ name = "Index box", boxes = boxes(frame, home:FindFirstChild("IndexStand")) },
				{ name = "spawn pad", boxes = { box(frame, home:FindFirstChild("Spawn") :: BasePart) } },
				{ name = "pen", boxes = { box(frame, home:FindFirstChild("Pen") :: BasePart) } },
				{ name = "dressing", boxes = boxes(frame, home:FindFirstChild("Dressing")) },
			}
			local studs = {}
			for _, p in (home:FindFirstChild("Shell") :: Instance):GetChildren() do
				if p:IsA("BasePart") and p.Name == "BackStud" then
					table.insert(studs, box(frame, p))
				end
			end
			table.insert(clear, { name = "back stud", boxes = studs })
			for _, thing in clear do
				for _, b in thing.boxes do
					for _, piece in pieces do
						check(not hits(piece.chunks, b), piece.name .. " clips the " .. thing.name)
					end
				end
			end

			-- the Speed wheel at its levels
			for _, w in wheelLevels do
				Homes.buildWheel(Kit, MapConfig, home, frame, w)
				local wheel = boxes(frame, home:FindFirstChild("TrainingWheel"))
				for _, b in wheel do
					if math.abs(b.min.X) > widest.x or math.abs(b.max.X) > widest.x then
						widest = { level = w, x = math.max(math.abs(b.min.X), math.abs(b.max.X)) }
					end
					for _, piece in pieces do
						check(not hits(piece.chunks, b), ("%s clips the Lv %d wheel"):format(piece.name, w))
					end
				end
			end
			holder:Destroy()
		end
	end

	return {
		checks = checks,
		failed = #failures,
		failures = table.concat(failures, "\n"),
		widestWheel = ("Lv %d reaches x %.1f"):format(widest.level, widest.x),
	}
end
