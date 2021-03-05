local addonName, addon = ...
BadaBot = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0")
BadaBot.name = addonName
BadaBot.version = GetAddOnMetadata(addonName, "Version")
local player = UnitName"player"

BadaBot.dbDefault = {
	realm = {
		active = false,
		channel = '',
		invite = true,
		inviteStr = '11',
		reset = true,
		resetStr = '22',
		follow = true,
		followStr = '33',
	}
}

local MSG_PREFIX = "|cff00ff00■ |cffffaa00"..addonName.."|r "
local MSG_SUFFIX = " |cff00ff00■|r"
local p = function(str) print(MSG_PREFIX..str..MSG_SUFFIX) end

function BadaBot:OnInitialize()
	local db = LibStub("AceDB-3.0"):New("BadaBotDB", self.dbDefault)
	self.db = db.realm

	self:BuildOptions()

	if self.db.active then self:TurnOn() end

	LibStub("AceConfig-3.0"):RegisterOptionsTable(self.name, self.optionsTable)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions(self.name, self.name, nil)

	SLASH_BadaBot1 = "/ㅂㄷ"
	SLASH_BadaBot2 = "/바다"
	SLASH_BadaBot3 = "/qe"

	SlashCmdList["BadaBot"] = function(msg)
		self:Toggle()
--[[
		local cmd, val = msg:match("^(%S*)%s*(.*)")
		if cmd == "차단" or cmd == "int" or cmd == "interrupt" then
			channel = channelList[val:upper()]
			if channel then
				self.db.announceInterrupt = true
				self.db.announceChannel = channel
			else
				self.db.announceInterrupt = false
			end
			self:SetAnnounceInterrupt()
		else
			InterfaceOptionsFrame_OpenToCategory(self.name)
			InterfaceOptionsFrame_OpenToCategory(self.name)
		end]]
	end

end

function BadaBot:Toggle()
	if self.db.active then
		self:TurnOff()
	else
		self:TurnOn()
	end
	return self.db.active
end
function BadaBot:TurnOn()
	self:RegisterEvent("CHAT_MSG_CHANNEL")
	self:RegisterEvent("CHAT_MSG_WHISPER")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	p("활성화 - /qe /ㅂㄷ /바다 로 토글")
	self.db.active = true
end
function BadaBot:TurnOff()
	self:UnregisterEvent("CHAT_MSG_CHANNEL")
	self:UnregisterEvent("CHAT_MSG_WHISPER")
	self:UnregisterEvent("GROUP_ROSTER_UPDATE")
	p("비활성화 - /qe /ㅂㄷ /바다 로 토글")
	self.db.active = false
end

function BadaBot:CHAT_MSG_WHISPER(_,text,_,_,_,unitName,_,_,_,channel)
	self:Handler(trim(text), unitName)
end

function BadaBot:CHAT_MSG_CHANNEL(_,text,_,_,_,unitName,_,_,_,channel)
	if strfind(channel, self.db.channel) then
		self:Handler(trim(text), unitName)
	end
end

function BadaBot:Handler(text, unitName)
	if text == self.db.inviteStr then
		self:InviteGroup(unitName)
	elseif text == self.db.resetStr then
		self:ResetInstance(unitName)
	elseif text == self.db.followStr then
		self:Follow(unitName)
	end
end

function BadaBot:InviteGroup(unitName)
	if self.db.invite then
		local n = GetNumGroupMembers() or 1
		if n > 4 and not IsInRaid() then
			ConvertToRaid()
			for i=1,n do
				PromoteToAssistant("raid"..i)
			end
		end
		SendChatMessage("자동 초대 ["..unitName.."]", "WHISPER", nil, unitName)
		InviteUnit(unitName)
	end
end

function BadaBot:Follow(unitName)
	if self.db.follow then
		local unit, index  = "", UnitInRaid(unitName)
		if IsInRaid() and index then
			unit = "raid"..index
		elseif UnitInParty(unitName) then
			for i=1,GetNumGroupMembers() do
				if unitName == UnitName("party"..i) then
					unit = "party"..i
				end
			end
		end
		if unit ~= "" then
			FollowUnit(unit)
			SendChatMessage("따라가기 ["..unitName.."]", "WHISPER", nil, unitName)
		end
	end
end

function BadaBot:GROUP_ROSTER_UPDATE(...)
	if IsInRaid() then
--		PromoteToAssistant("raid"..n)
		--for i=1, n do
			--PromoteToAssistant("raid"..i)
		--end
	end
end

function BadaBot:ResetInstance(unitName)
	if self.db.reset then
		if UnitInParty(unitName) or UnitInRaid(unitName) then
			if self.ticker and not self.ticker:IsCancelled() then
				SendChatMessage("진행 중인 리셋 있음", "WHISPER", nil, unitName)
			else
				if UnitIsGroupLeader("player") then
					SendChatMessage("오프라인 되면 자동 리셋", "WHISPER", nil, unitName)
					self.ticker = C_Timer.NewTicker(1, function()
						if not UnitIsConnected(unitName) then
							ResetInstances()
							BadaBot.ticker:Cancel()
							BadaBot.ticker = nil
						end
					end, 30)
				else
					SendChatMessage("파장이 아닌데유", "WHISPER", nil, unitName)
				end
			end
		else
			SendChatMessage("같은 파티가 아닌데유", "WHISPER", nil, unitName)
		end
	end
end

function BadaBot:BuildOptions()
	self.optionsTable = {
		name = self.name,
		handler = self,
		type = 'group',
		get = function(info) return self.db[info[#info] ] end,
		set = function(info, value) self.db[info[#info] ] = value end,
		args = {
			auto = {
				name = '동작',
				type = 'group',
				order = 101,
				args = {
					active = {
						name = self.name..' 동작',
						type = 'toggle',
						order = 1,
						set = function(info, value) return self:Toggle() end,
					},
					nameDesc = {
						name = '/qe /ㅂㄷ /바다 명령어로도 토글 가능',
						type = 'description',
						width = 'full',
						order = 11,
					},
					chDesc = {
						name = '기본: 귓속말로 동작|n채널: 채널명 입력시 해당 채널 메시지로도 동작',
						type = 'description',
						width = 'full',
						order = 51,
					},
					channel = {
						name = '채널명',
						type = 'input',
						order = 61,
					},
				}
			},
			options = {
				name = '기능',
				type = 'group',
				order = 201,
				args = {
					inviteGroup = {
						name = '자동 초대',
						type = 'group',
						inline = true,
						order = 101,
						args = {
							invite = {
								name = '사용',
								type = 'toggle',
								order = 1,
							},
							inviteStr = {
								name = '초대 문자열',
								type = 'input',
								order = 2,
							},
						}
					},

					resetGroup = {
						name = '자동 리셋',
						type = 'group',
						inline = true,
						order = 201,
						args = {
							reset = {
								name = '사용',
								type = 'toggle',
								order = 1,
							},
							resetStr = {
								name = '리셋 문자열',
								type = 'input',
								order = 2,
							},
						}
					},

					followGroup = {
						name = '자동 따라가기',
						type = 'group',
						inline = true,
						order = 301,
						args = {
							follow = {
								name = '사용',
								type = 'toggle',
								order = 1,
							},
							followStr = {
								name = '따라가기 문자열',
								type = 'input',
								order = 2,
							},
						}
					},


				}
			},
		}
	}
end
