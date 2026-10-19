--!strict
-- Animates every awake toy in Workspace (idle animations, personality, rarity and mutation effects), the sleeping
-- toys under their blankets (breathing, turning over, struggling when dragged), and flickers the sleeping toys' glow
-- tells. The toy code itself is in ReplicatedStorage.Shared.Toys (see handoff.md, "Toys: how to use them").
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Toys = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Toys")
local ToyAnimator = require(Toys:WaitForChild("ToyAnimator")) :: any
local ToyVFX = require(Toys:WaitForChild("ToyVFX")) :: any
local BlanketAnimator = require(script.Parent:WaitForChild("BlanketAnimator")) :: any

ToyAnimator.watch()
ToyVFX.watchGlowTells()
task.spawn(BlanketAnimator.watch)
