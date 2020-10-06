--[[	*** DataStore_Characters ***
Written by : Thaoky, EU-Marécages de Zangar
July 18th, 2009
--]]
if not DataStore then return end

local addonName = "DataStore_Characters"

_G[addonName] = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

local addon = _G[addonName]

local THIS_ACCOUNT = "Default"
local MAX_LOGOUT_TIMESTAMP = 5000000000	-- 5 billion, current values are at ~1.4 billion, in seconds, that leaves us 110+ years, I think we're covered..

local AddonDB_Defaults = {
	global = {
		Options = {
			RequestPlayTime = true,		-- Request play time at logon
			HideRealPlayTime = false,	-- Hide real play time to client addons (= return 0 instead of real value)
		},
		Characters = {
			['*'] = {				-- ["Account.Realm.Name"] 
				-- ** General Stuff **
				lastUpdate = nil,		-- last time this char was updated. Set at logon & logout
				name = nil,				-- to simplify processing a bit, the name is saved in the table too, in addition to being part of the key
				level = nil,
				race = nil,
				englishRace = nil,
				class = nil,
				englishClass = nil,	-- "WARRIOR", "DRUID" .. english & caps, regardless of locale
				faction = nil,
				gender = nil,			-- UnitSex
				lastLogoutTimestamp = nil,
				money = nil,
				played = 0,				-- /played, in seconds
				playedThisLevel = 0,	-- /played at this level, in seconds
				zone = nil,				-- character location
				subZone = nil,
                realm = nil,
                hearthstone = nil,      -- eg: "Brill"
				
				-- ** XP **
				XP = nil,				-- current level xp
				XPMax = nil,			-- max xp at current level 
				RestXP = nil,
				isResting = nil,		-- nil = out of an inn
				isXPDisabled = nil,
				
				-- ** Guild  **
				guildName = nil,		-- nil = not in a guild, as returned by GetGuildInfo("player")
				guildRankName = nil,
				guildRankIndex = nil,
			}
		}
	}
}

-- *** Utility functions ***
local function GetOption(option)
	return addon.db.global.Options[option]
end

-- *** Scanning functions ***
local function ScanPlayerLocation()
	local character = addon.ThisCharacter
	character.zone = GetRealZoneText()
    character.realm = GetRealmName()
	character.subZone = GetSubZoneText()
end

-- *** Event Handlers ***
local function OnPlayerGuildUpdate()
	-- at login this event is called between OnEnable and PLAYER_ALIVE, where GetGuildInfo returns a wrong value
	-- however, the value returned here is correct
	if IsInGuild() then
		-- find a way to improve this, it's minor, but it's called too often at login
		local name, rank, index = GetGuildInfo("player")
		if name and rank and index then
			local character = addon.ThisCharacter
			character.guildName = name
			character.guildRankName = rank
			character.guildRankIndex = index
		end
	end
end

local function ScanXPDisabled()
	addon.ThisCharacter.isXPDisabled = IsXPUserDisabled() or nil
end

local function OnPlayerUpdateResting()
	addon.ThisCharacter.isResting = IsResting()
end

local function OnPlayerXPUpdate()
	local character = addon.ThisCharacter
	
	character.XP = UnitXP("player")
	character.XPMax = UnitXPMax("player")
	character.RestXP = GetXPExhaustion() or 0
end

local function OnPlayerMoney()
	addon.ThisCharacter.money = GetMoney()
end

local function OnPlayerAlive()
	local character = addon.ThisCharacter

	character.name = UnitName("player")		-- to simplify processing a bit, the name is saved in the table too, in addition to being part of the key
	character.level = UnitLevel("player")
	character.race, character.englishRace = UnitRace("player")
	character.class, character.englishClass = UnitClass("player")
	character.gender = UnitSex("player")
	character.faction = UnitFactionGroup("player")
	character.lastLogoutTimestamp = MAX_LOGOUT_TIMESTAMP
	character.lastUpdate = time()
    character.hearthstone = GetBindLocation()
	
	OnPlayerMoney()
	OnPlayerXPUpdate()
	OnPlayerUpdateResting()
	OnPlayerGuildUpdate()
	ScanXPDisabled()
end

local function OnPlayerLogout()
	addon.ThisCharacter.lastLogoutTimestamp = time()
	addon.ThisCharacter.lastUpdate = time()
end

local function OnPlayerLevelUp(event, newLevel)
	addon.ThisCharacter.level = newLevel
end

local function OnPlayerHearthstoneBound(event)
    addon.ThisCharacter.hearthstone = GetBindLocation()
end

local function OnTimePlayedMsg(event, totalTime, currentLevelTime)
	addon.ThisCharacter.played = totalTime
	addon.ThisCharacter.playedThisLevel = currentLevelTime
end

-- ** Mixins **
local function _GetCharacterName(character)
	return character.name
end

local function _GetCharacterRealm(character)
    return character.realm
end

local function _GetCharacterLevel(character)
	return character.level or 0
end

local function _GetCharacterRace(character)
	return character.race or "", character.englishRace or ""
end

local function _GetCharacterClass(character)
	return character.class or "", character.englishClass or ""
end

local function _GetColoredCharacterName(character)
    if not RAID_CLASS_COLORS[character.englishClass].colorStr then return end
	return format("|c%s%s", RAID_CLASS_COLORS[character.englishClass].colorStr, character.name)
end
	
local function _GetCharacterClassColor(character)
	-- return just the color of this character's class (based on the character key)
	return format("|c%s", RAID_CLASS_COLORS[character.englishClass].colorStr)
end

local function _GetClassColor(class)
	-- return just the color of for any english class
    -- Seems to be caused by guild members in Altoholic_Guild not having full details stored?
    -- Might be a communications issue.
    if class == nil then return "|cFFFFFFFF" end 	
	return format("|c%s", RAID_CLASS_COLORS[class].colorStr) or "|cFFFFFFFF"
end

local function _GetCharacterFaction(character)
	return character.faction or ""
end
	
local function _GetColoredCharacterFaction(character)
	if character.faction == "Alliance" then
		return "|cFF2459FF" .. FACTION_ALLIANCE
	elseif character.faction == "Neutral" then	-- for young pandas :)
		return "|cFF909090" .. character.faction
	else
		return "|cFFFF0000" .. FACTION_HORDE
	end
end

local function _GetCharacterGender(character)
	return character.gender or ""
end

local function _GetLastLogout(character)
	return character.lastLogoutTimestamp or 0
end

local function _GetMoney(character)
	return character.money or 0
end

local function _GetHearthstone(character)
    return character.hearthstone or ""
end

local function _GetXP(character)
	return character.XP or 0
end

local function _GetXPRate(character)
	return floor((character.XP / character.XPMax) * 100)
end

local function _GetXPMax(character)
	return character.XPMax or 0
end

local function _GetRestXP(character)
	return character.RestXP or 0
end

local function _GetRestXPRate(character)
	-- after extensive tests, it seems that the known formula to calculate rest xp is incorrect.
	-- I believed that the maximum rest xp was exactly 1.5 level, and since 8 hours of rest = 5% of a level
	-- being 100% rested would mean having 150% xp .. but there's a trick...
	-- One would expect that 150% of rest xp would be split over the following levels, and that calculating the exact amount of rest
	-- would require taking into account that 30% are over the current level, 100% over lv+1, and the remaining 20% over lv+2 ..
	
	-- .. But that is not the case.Blizzard only takes into account 150% of rest xp AT THE CURRENT LEVEL RATE.
	-- ex: at level 15, it takes 13600 xp to go to 16, therefore the maximum attainable rest xp is:
	--	136 (1% of the level) * 150 = 20400 

	-- thus, to calculate the exact rate (ex at level 15): 
		-- divide xptonext by 100 : 		13600 / 100 = 136	==> 1% of the level
		-- multiply by 1.5				136 * 1.5 = 204
		-- divide rest xp by this value	20400 / 204 = 100	==> rest xp rate
	
	--[[
		17/09/2018 : After even more extensive tests since right after the launch of BfA, it is now clear that Blizzard is not 
		consistent in their reporting of rest xp.
		
		A simple example: my 110 druid with exactly 0xp / 717.000 should be able to earn 1.5 levels of rest xp at current level rate.
		This should set the maximum at 1.075.500 xp.
		Nevertheless, my druid actually has 1.505.792 xp, and this is not a value that I actually process in datastore before saving it.
		I had the same issue a week ago on my horde monk, which had 2.9M rest xp for a maximum of 3 levels (2.1M xp).
	
	--]] 
	
	local rate = 0
	local multiplier = 1.5
	
	if character.englishRace == "Pandaren" then
		multiplier = 3
	end
	
	local savedXP = 0
	local savedRate = 0
	local maxXP = character.XPMax * multiplier
	if character.RestXP then
		rate = character.RestXP / (maxXP / 100)
		savedXP = character.RestXP
		savedRate = rate
	end
	
	-- get the known rate of rest xp (the one saved at last logout) + the rate represented by the elapsed time since last logout
	-- (elapsed time / 3600) * 0.625 * (2/3)  simplifies to elapsed time / 8640
	-- 0.625 comes from 8 hours rested = 5% of a level, *2/3 because 100% rested = 150% of xp (1.5 level)

	local xpEarnedResting = 0
	local rateEarnedResting = 0
	local isFullyRested = false
	local timeUntilFullyRested = 0
	local now = time()
	
	-- time since last logout, MAX_LOGOUT_TIMESTAMP for current char, <> for all others
	if character.lastLogoutTimestamp ~= MAX_LOGOUT_TIMESTAMP then	
		local oneXPBubble = character.XPMax / 20		-- 5% at current level 
		local elapsed = (now - character.lastLogoutTimestamp)		-- time since last logout, in seconds
		local numXPBubbles = elapsed / 28800		-- 28800 seconds = 8 hours => get the number of xp bubbles earned
		
		xpEarnedResting = numXPBubbles * oneXPBubble
		
		if not character.isResting then
			xpEarnedResting = xpEarnedResting / 4
		end

		-- cap earned XP
		if (xpEarnedResting + savedXP) > maxXP then
			xpEarnedResting = xpEarnedResting - ((xpEarnedResting + savedXP) - maxXP)
		end
	
		-- non negativity
		if xpEarnedResting < 0 then xpEarnedResting = 0 end
		
		rateEarnedResting = xpEarnedResting / (maxXP / 100)
		
		if (savedXP + xpEarnedResting) >= maxXP then
			isFullyRested = true
			rate = 100
		else
			local xpUntilFullyRested = maxXP - (savedXP + xpEarnedResting)
			timeUntilFullyRested = math.floor((xpUntilFullyRested / oneXPBubble) * 28800) -- num bubbles * duration of one bubble in seconds
			
			rate = rate + rateEarnedResting
		end
	end
	
	return rate, savedXP, savedRate, rateEarnedResting, xpEarnedResting, maxXP, isFullyRested, timeUntilFullyRested
end

local function _IsResting(character)
	return character.isResting
end

local function _IsXPDisabled(character)
	return character.isXPDisabled
end
	
local function _GetGuildInfo(character)
	return character.guildName, character.guildRankName, character.guildRankIndex
end

local function _GetPlayTime(character)
	return (GetOption("HideRealPlayTime")) and 0 or character.played, character.playedThisLevel
end

local function _GetLocation(character)
	return character.zone, character.subZone
end

local PublicMethods = {
	GetCharacterName = _GetCharacterName,
	GetCharacterLevel = _GetCharacterLevel,
	GetCharacterRace = _GetCharacterRace,
	GetCharacterClass = _GetCharacterClass,
    GetCharacterRealm = _GetCharacterRealm,
	GetColoredCharacterName = _GetColoredCharacterName,
	GetCharacterClassColor = _GetCharacterClassColor,
	GetClassColor = _GetClassColor,
	GetCharacterFaction = _GetCharacterFaction,
	GetColoredCharacterFaction = _GetColoredCharacterFaction,
	GetCharacterGender = _GetCharacterGender,
	GetLastLogout = _GetLastLogout,
	GetMoney = _GetMoney,
    GetHearthstone = _GetHearthstone,
	GetXP = _GetXP,
	GetXPRate = _GetXPRate,
	GetXPMax = _GetXPMax,
	GetRestXP = _GetRestXP,
	GetRestXPRate = _GetRestXPRate,
	IsResting = _IsResting,
	IsXPDisabled = _IsXPDisabled,
	GetGuildInfo = _GetGuildInfo,
	GetPlayTime = _GetPlayTime,
	GetLocation = _GetLocation,
}

function addon:OnInitialize()
	addon.db = LibStub("AceDB-3.0"):New(addonName .. "DB", AddonDB_Defaults)

	DataStore:RegisterModule(addonName, addon, PublicMethods)
	DataStore:SetCharacterBasedMethod("GetCharacterName")
	DataStore:SetCharacterBasedMethod("GetCharacterLevel")
	DataStore:SetCharacterBasedMethod("GetCharacterRace")
	DataStore:SetCharacterBasedMethod("GetCharacterClass")
    DataStore:SetCharacterBasedMethod("GetCharacterRealm")
	DataStore:SetCharacterBasedMethod("GetColoredCharacterName")
	DataStore:SetCharacterBasedMethod("GetCharacterClassColor")
	DataStore:SetCharacterBasedMethod("GetCharacterFaction")
	DataStore:SetCharacterBasedMethod("GetColoredCharacterFaction")
	DataStore:SetCharacterBasedMethod("GetCharacterGender")
	DataStore:SetCharacterBasedMethod("GetLastLogout")
	DataStore:SetCharacterBasedMethod("GetMoney")
    DataStore:SetCharacterBasedMethod("GetHearthstone")
	DataStore:SetCharacterBasedMethod("GetXP")
	DataStore:SetCharacterBasedMethod("GetXPRate")
	DataStore:SetCharacterBasedMethod("GetXPMax")
	DataStore:SetCharacterBasedMethod("GetRestXP")
	DataStore:SetCharacterBasedMethod("GetRestXPRate")
	DataStore:SetCharacterBasedMethod("IsResting")
	DataStore:SetCharacterBasedMethod("IsXPDisabled")
	DataStore:SetCharacterBasedMethod("GetGuildInfo")
	DataStore:SetCharacterBasedMethod("GetPlayTime")
	DataStore:SetCharacterBasedMethod("GetLocation")
end

function addon:OnEnable()
	addon:RegisterEvent("PLAYER_ALIVE", OnPlayerAlive)
	addon:RegisterEvent("PLAYER_LOGOUT", OnPlayerLogout)
	addon:RegisterEvent("PLAYER_LEVEL_UP", OnPlayerLevelUp)
	addon:RegisterEvent("PLAYER_MONEY", OnPlayerMoney)
	addon:RegisterEvent("PLAYER_XP_UPDATE", OnPlayerXPUpdate)
	addon:RegisterEvent("PLAYER_UPDATE_RESTING", OnPlayerUpdateResting)
    addon:RegisterEvent("HEARTHSTONE_BOUND", OnPlayerHearthstoneBound)
	addon:RegisterEvent("ENABLE_XP_GAIN", ScanXPDisabled)
	addon:RegisterEvent("DISABLE_XP_GAIN", ScanXPDisabled)
	addon:RegisterEvent("PLAYER_GUILD_UPDATE", OnPlayerGuildUpdate)				-- for gkick, gquit, etc..
	addon:RegisterEvent("ZONE_CHANGED", ScanPlayerLocation)
	addon:RegisterEvent("ZONE_CHANGED_NEW_AREA", ScanPlayerLocation)
	addon:RegisterEvent("ZONE_CHANGED_INDOORS", ScanPlayerLocation)
	addon:RegisterEvent("TIME_PLAYED_MSG", OnTimePlayedMsg)					-- register the event if RequestTimePlayed is not called afterwards. If another addon calls it, we want to get the data anyway.
    
	addon:SetupOptions()
	
	if GetOption("RequestPlayTime") then
		RequestTimePlayed()	-- trigger a TIME_PLAYED_MSG event
	end
end

function addon:OnDisable()
	addon:UnregisterEvent("PLAYER_ALIVE")
	addon:UnregisterEvent("PLAYER_LOGOUT")
	addon:UnregisterEvent("PLAYER_LEVEL_UP")
	addon:UnregisterEvent("PLAYER_MONEY")
    addon:UnregisterEvent("HEARTHSTONE_BOUND")
	addon:UnregisterEvent("PLAYER_XP_UPDATE")
	addon:UnregisterEvent("PLAYER_UPDATE_RESTING")
	addon:UnregisterEvent("ENABLE_XP_GAIN")
	addon:UnregisterEvent("DISABLE_XP_GAIN")
	addon:UnregisterEvent("PLAYER_GUILD_UPDATE")
	addon:UnregisterEvent("ZONE_CHANGED")
	addon:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
	addon:UnregisterEvent("ZONE_CHANGED_INDOORS")
	addon:UnregisterEvent("TIME_PLAYED_MSG")
end