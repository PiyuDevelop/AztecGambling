-- Common code betwene the Client and Master like slash commands and minimap button

-- Global 3 way UI Toggler 
-- ==========================
local ToggleClientAndCasino = function() 
    if (AGClient.db.global.window_shown) then
        AGClient:ToggleClient()
    elseif (AztecGambling.db.global.window_shown) then
        AztecGambling:HideUI()
    else
        AGClient:ShowUI()
    end
end

function AztecGambling:ToggleCasino() 
    AztecGambling:HideUI()
    AGClient:ShowUI()
end

function AGClient:ToggleClient() 
    AGClient:HideUI()
    AztecGambling:ShowUI()
end

-- MiniMap Icon Definition
-- =========================
function AztecGambling:ConstructMiniMapIcon() 
	self.minimap = { }
	self.minimap.icon_data = LibStub("LibDataBroker-1.1"):NewDataObject("AztecGamblingIcon", {
		type = "data source",
		text = "Aztec Gambling!",
		icon = "Interface\\Icons\\INV_Misc_Coin_02",
		OnClick = ToggleClientAndCasino,

		OnTooltipShow = function(tooltip)
			tooltip:AddLine("Aztec Gambling!",1,1,1)
			tooltip:Show()
		end,
	})

	self.minimap.icon = LibStub("LibDBIcon-1.0")
	self.minimap.icon:Register("AztecGamblingIcon", self.minimap.icon_data, self.db.global.minimap)
end

-- Debug Setup
-- ==================
function AztecGambling:PrintDebug(msg)
	if self.DEBUG_ENABLED then self:Print("[AG_DEBUG] "..msg) end
end

-- Custom Channel Handling
-- ==========================
function AztecGambling:GetCustomChannelName() 
    -- Figure out the Channel Name
    guildName, guildRankName, guildRankIndex = GetGuildInfo("player")
    guildName = string.gsub(guildName, "%s+", "")
    channel_name = guildName.."Gambling"
    return channel_name
end

function AztecGambling:JoinCustomChannel(channel_name) 
    -- Only if we're not only in a channel 
    if (self.db.global.custom_channel.index) then return end
    if (channel_name == nil) then channel_name = self:GetCustomChannelName() end

    -- Joining a channel without the slash command is wonky, so kind've abusing the slashcmd list
    SlashCmdList["JOIN"](channel_name)
    channel_number, channel_string, instanceID = GetChannelName(channel_name)

    -- Update our references so we send chat to the right place
    self.db.global.custom_channel.index = channel_number
    self.db.global.custom_channel.name = channel_name

    -- Remove it on logout/reload to avoid conflicts
	self:RegisterEvent("PLAYER_LEAVING_WORLD", "LeaveCustomChannel")
end

function AztecGambling:LeaveCustomChannel() 
    LeaveChannelByName(self.db.global.custom_channel.name)
    self.db.global.custom_channel.index = nil
    self.db.global.custom_channel.name = ""
end

function AztecGambling:PrintSlashCommandHelp()
    self:Print("Aztec Gambling Slash Commands: ")
    self:Print(" /ag <command> ")
    self:Print("    <no command>  - Toggles UI like the minimap button does")
    self:Print("    auto - Toggles auto pop up of rolling UI")
    self:Print("    stats - Prints the hall of fame and shame")
    self:Print("    ban <player> - Bans player from entering AG")
    self:Print("    unban <player> - Unbans player")
    self:Print("    resetStats - Clears hall of fame/shame")
    self:Print("    resetBans - Clears all bans ")
    self:Print("    join - Join custom gambling channel for your guild")
    self:Print("    leave - Leave custom gambling channel")
end

-- Slash Commands
-- ================

-- Handler Needed to support multiargument commands 
function AztecGambling:SlashCommandHandler(...)
    command_args = self:SplitString(select(1, ...), "%S+")
    command = command_args[1]

    if (command == nil) then 
        ToggleClientAndCasino()

    elseif (command == "ban") then 
        player = command_args[2]
	    self.db.global.ban_list[player] = true

    elseif (command == "unban") then 
        player = command_args[2]
	    self.db.global.ban_list[player] = nil

    elseif (command == "resetStats") then 
        self.db.global.rankings = {}

    elseif (command == "resetBans") then 
        self.db.global.ban_list = {}

    elseif (command == "stats") then 
        self:PrintRanklist()

    elseif (command == "auto") then 
        AGClient.db.global.auto_pop = not AGClient.db.global.auto_pop
        if AGClient.db.global.auto_pop then 
            self:Print("Enabled auto show of rolling UI.")
        else
            self:Print("Disabled auto show of rolling UI.")
        end

    elseif (command == "debug") then 
        self.DEBUG_ENABLED = not self.DEBUG_ENABLED

    elseif (command == "join") then 
        channel_name = command_args[2]
        self:JoinCustomChannel(channel_name)

    elseif (command == "leave") then 
        self:LeaveCustomChannel()

    elseif (command == "help") then
        self:PrintSlashCommandHelp()

    else 
        self:Print("Unrecognized AG Slash Command: ")
        self:Print(command)
        self:Print("Use /ag help for more information.")

    end
end

-- Called from constructor of main addon
function AztecGambling:RegisterSlashCommands() 
	self:RegisterChatCommand("ag", "SlashCommandHandler")

    -- Legacy Support - TODO: Remove
	self:RegisterChatCommand("agm", "ShowUI")
end