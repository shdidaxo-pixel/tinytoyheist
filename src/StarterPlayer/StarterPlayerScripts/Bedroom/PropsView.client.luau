--!strict
-- The little props, alive: the rubber ducks look about and give a nod now and then. Only their heads move (head,
-- beak, eyes), so the squash when one goes off (Effects, on its Body) still plays as it did.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local bedroom = Workspace:WaitForChild("Bedroom")
local ducks = bedroom:WaitForChild("Hazards"):WaitForChild("Ducks")

type Duck = { parts: { BasePart }, rest: { CFrame }, neck: CFrame, seed: number, nodAt: number, nextNod: number }
local list: { Duck } = {}
for _, duck in ducks:GetChildren() do
	local head = duck:FindFirstChild("Head") :: BasePart?
	if not head then
		continue
	end
	local parts, rest = {}, {}
	for _, p in duck:GetChildren() do
		if p:IsA("BasePart") and (p.Name == "Head" or p.Name == "Beak" or p.Name == "Eye") then
			table.insert(parts, p)
			table.insert(rest, p.CFrame)
		end
	end
	-- the neck: the bottom of the head, upright in the world
	local neck = CFrame.new(head.Position - Vector3.new(0, head.Size.Y / 2, 0))
	table.insert(
		list,
		{ parts = parts, rest = rest, neck = neck, seed = math.random() * 10, nodAt = -100, nextNod = 0 }
	)
end

local cframes: { CFrame } = {}
local all: { BasePart } = {}
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local cam = Workspace.CurrentCamera
	local eye = if cam then cam.CFrame.Position else Vector3.zero
	table.clear(cframes)
	table.clear(all)
	for _, d in list do
		if (d.neck.Position - eye).Magnitude > 200 then
			continue
		end
		if t >= d.nextNod then
			d.nodAt = t
			d.nextNod = t + 3 + math.random() * 5
		end
		local nod = math.sin(math.clamp((t - d.nodAt) / 0.5, 0, 1) * math.pi * 2) * 0.25
		local yaw = math.sin(t * 0.6 + d.seed) * 0.5 + math.sin(t * 1.7 + d.seed * 2) * 0.15
		local turn = d.neck * CFrame.Angles(0, yaw, 0) * CFrame.Angles(nod, 0, 0) * d.neck:Inverse()
		for i, p in d.parts do
			table.insert(all, p)
			table.insert(cframes, turn * d.rest[i])
		end
	end
	if #all > 0 then
		Workspace:BulkMoveTo(all, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
