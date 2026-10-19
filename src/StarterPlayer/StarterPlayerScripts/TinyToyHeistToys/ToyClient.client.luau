--!strict
-- Animates every awake toy in Workspace (idle animations, rarity and mutation effects) and flickers the sleeping
-- toys' glow tells. The toy code itself is in ReplicatedStorage.Shared.Toys (see handoff.md, "Toys: how to use them").
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Toys = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Toys")
local ToyAnimator = require(Toys:WaitForChild("ToyAnimator")) :: any
local ToyVFX = require(Toys:WaitForChild("ToyVFX")) :: any

ToyAnimator.watch()
ToyVFX.watchGlowTells()
