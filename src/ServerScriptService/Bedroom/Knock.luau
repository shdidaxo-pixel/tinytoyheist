--!strict
-- Knocking a player over: the train, the cat's pounce, a trap's snap and the Kid's flashlight all come through here.
-- The client gets pushed and falls down for a moment (the Knocked remote), the carry system is told to drop the
-- player's toy (DropCarried), and a trap also sends them home. A short grace period stops double hits.

local Players = game:GetService("Players")

local Events = require(script.Parent.Events)

local Knock = {}
Knock.GRACE = 2.5 -- seconds after a knock when nothing else can knock you
Knock.sendHome = nil :: ((player: Player) -> ())?

local lastHit: { [Player]: number } = {}

export type Options = {
	message: string,
	push: number?, -- studs a second, away from `from`
	stun: number?, -- seconds on the floor
	drop: boolean?, -- drop a carried toy (default true)
	home: boolean?, -- send them back to their home after the stun
}

function Knock.root(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Can this player be knocked right now?
function Knock.ready(player: Player): boolean
	return os.clock() - (lastHit[player] or -math.huge) >= Knock.GRACE
end

-- Nothing can knock this player for the next `seconds` (the cat's throw: the flight and a moment after landing)
function Knock.protect(player: Player, seconds: number)
	lastHit[player] = math.max(lastHit[player] or -math.huge, os.clock() + seconds - Knock.GRACE)
end

function Knock.hit(player: Player, from: Vector3, options: Options): boolean
	local root = Knock.root(player)
	if not root or not Knock.ready(player) then
		return false
	end
	lastHit[player] = os.clock()
	local away = root.Position - from
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 0.1 then
		away = Vector3.new(0, 0, -1)
	end
	local stun = options.stun or 1.5
	Events.Knocked:FireClient(player, away.Unit * (options.push or 60), stun, options.message)
	if options.drop ~= false then
		-- the third value says they're being sent home (the Giant, a trap): Grip can't save the toy then
		Events.DropCarried:Fire(player, options.message, options.home == true)
	end
	if options.home and Knock.sendHome then
		task.delay(stun, function()
			if player.Parent and Knock.sendHome then
				Knock.sendHome(player)
			end
		end)
	end
	return true
end

Players.PlayerRemoving:Connect(function(player)
	lastHit[player] = nil
end)

return Knock
