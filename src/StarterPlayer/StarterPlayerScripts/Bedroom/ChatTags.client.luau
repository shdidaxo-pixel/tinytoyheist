--!strict
-- A gold [VIP] tag in front of the names of VIP pass owners in chat (the Player attribute PassVIP, set by the
-- server's Bedroom/Shop).
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

TextChatService.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
	local source = message.TextSource
	if not source then
		return nil
	end
	local player = Players:GetPlayerByUserId(source.UserId)
	if not player or not player:GetAttribute("PassVIP") then
		return nil
	end
	local props = Instance.new("TextChatMessageProperties")
	props.PrefixText = '<font color="#FFD43B">[VIP]</font> ' .. message.PrefixText
	return props
end
