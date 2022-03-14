local addonName, addon = ...
BadaBot = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0")
BadaBot.name = addonName
BadaBot.version = GetAddOnMetadata(addonName, "Version")
local player = UnitName"player"

BadaBot.dbDefault = {
	char = {
		active = false,
		channel = '',
		invite = true,
		inviteRaid = false,
		inviteAssist = false,
		inviteStr = '11',
		reset = true,
		resetStr = '22',
		follow = true,
		followAnswer = true,
		followStr = '33',
		unFollow = true,
		unFollowStr = '44',
		readyCheck = true,
		readyCheckResponse = 'yes',
	}
}

local MSG_PREFIX = "|cff00ff00■ |cffffaa00"..addonName.."|r "
local MSG_SUFFIX = " |cff00ff00■|r"
local p = function(str) print(MSG_PREFIX..str..MSG_SUFFIX) end
local trim = function(str) return str:gsub("^%s*",""):gsub("%s*$","") end

function BadaBot:OnInitialize()
	local db = LibStub("AceDB-3.0"):New("BadaBotDB", self.dbDefault)
	if db.realm[player] then
		db.char = db.realm[player]
		db.realm[player] = nil
	end

	self.db = db.char

	self:BuildOptions()

	-- Disband btn
	local btn = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
	btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	btn:SetWidth(30)
	btn:SetHeight(20)
	btn:SetText("해체")
	btn:SetNormalFontObject("GameFontNormal")
	--btn:RegisterForClicks("LeftButtonUp")	-- by default
	btn:SetScript("OnClick", self.Disband)
	btn:Hide()
	self.disbandBtn = btn

	if self.db.active then self:TurnOn() end

	LibStub("AceConfig-3.0"):RegisterOptionsTable(self.name, self.optionsTable)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions(self.name, self.name, nil)

	SLASH_BadaBot1 = "/ㅂㄷ"
	SLASH_BadaBot2 = "/바다"
	SLASH_BadaBot3 = "/qe"

	SlashCmdList["BadaBot"] = function(msg)
		self:Toggle()
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
	self:RegisterEvent("READY_CHECK")
	p("활성화 - /qe /ㅂㄷ /바다 로 토글")
	self.db.active = true
	self.disbandBtn:Show()
end
function BadaBot:TurnOff()
	self:UnregisterEvent("CHAT_MSG_CHANNEL")
	self:UnregisterEvent("CHAT_MSG_WHISPER")
	self:UnregisterEvent("GROUP_ROSTER_UPDATE")
	self:UnregisterEvent("READY_CHECK")
	p("비활성화 - /qe /ㅂㄷ /바다 로 토글")
	self.db.active = false
	self.disbandBtn:Hide()
end

function BadaBot:CHAT_MSG_WHISPER(_,text,_,_,_,unitName,_,_,_,channel)
	self:Handler(trim(text), unitName)
end

function BadaBot:CHAT_MSG_CHANNEL(_,text,_,_,_,unitName,_,_,_,channel)
	if strfind(string.upper(channel), string.upper(self.db.channel)) then
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
	elseif text == self.db.unFollowStr then
		self:Unfollow(unitName)
	end
end

function BadaBot:InviteGroup(unitName)
	if self.db.invite and unitName ~= player then
		if (not IsInRaid()) and (GetNumGroupMembers() < 5) then
			ConvertToRaid()
		end
		SendChatMessage("자동 초대 ["..unitName.."]", "WHISPER", nil, unitName)
		InviteUnit(unitName)
	end
end

function BadaBot:Follow(unitName)
	if self.db.follow and unitName ~= player then
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
			if self.db.followAnswer then
				SendChatMessage("따라가기 ["..unitName.."]", "WHISPER", nil, unitName)
			end
		end
	end
end

function BadaBot:Unfollow(unitName)
	if self.db.unFollow then
		FollowUnit("player")
		SendChatMessage("따라가기 중지", "WHISPER", nil, unitName)
	end
end

function BadaBot:GROUP_ROSTER_UPDATE(...)
	if self.resetUnit then
		if not UnitIsConnected(self.resetUnit) then
			self.resetUnit = nil
			self.resetTimeout:Cancel()
			self.resetTimeout = nil
			C_Timer.After(1, function()
				p("인스턴스 리셋")
				ResetInstances()
			end)
		end
	end
	if UnitIsGroupLeader("player") then
		if self.db.inviteRaid then
			ConvertToRaid()
		elseif self.db.inviteAssist and IsInRaid() and not IsEveryoneAssistant() then
			SetEveryoneIsAssistant(true)
		end
	end
end

--[[
name, rank, subgroup, level, class, fileName, 
  zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(raidIndex);
]]
function BadaBot:ResetInstance(unitName)
	if not (self.db.reset and unitName ~= player) then return end
	if not UnitIsGroupLeader("player") then
		SendChatMessage("파장이 아님", "WHISPER", nil, unitName)
		return
	end
	if not (UnitInRaid(unitName) or UnitInParty(unitName)) then
		SendChatMessage("같은 파티가 아님", "WHISPER", nil, unitName)
		return
	end

	if self.resetUnit then
		SendChatMessage("진행 중인 리셋 있음 - ["..self.resetUnit.."] 가 요청", "WHISPER", nil, unitName)
	else
		SendChatMessage("오프라인 되면 자동 리셋(30초 기한)", "WHISPER", nil, unitName)

		self.resetUnit = unitName
		self.resetTimeout = C_Timer.NewTimer(30, function(tself)
			SendChatMessage("리셋 취소(30초 경과)", "WHISPER", nil, unitName)
			tself:Cancel()
			BadaBot.resetUnit = nil
			BadaBot.resetTimeout = nil
		end)
	end
end

------------------------------------

function BadaBot:Disband()
	local n = GetNumGroupMembers() or 1
	if n < 2 then return end
	if not UnitIsGroupLeader("player") then return end
	local group = ""
	if IsInRaid() then
		group = "raid"
	else
		group = "party"
	end
	SendChatMessage("파티/공격대 해체", group)
	for i = n,1,-1 do
		local unitName = UnitName(group..i)
		if not (unitName == player) then
			UninviteUnit(group..i)
		end
	end
end

function BadaBot:READY_CHECK()
	if self.db.readyCheck then
		if self.db.readyCheckResponse == 'yes' then
			ConfirmReadyCheck(1)
		else
			ConfirmReadyCheck()
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
							inviteRaid = {
								name = '공격대 구성',
								type = 'toggle',
								order = 2,
							},
							inviteAssist = {
								name = '올부공(전원 부공격대장)',
								type = 'toggle',
								order = 3,
							},
							inviteStr = {
								name = '초대 문자열',
								type = 'input',
								order = 4,
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
							followAnswer = {
								name = '귓속말 대답',
								type = 'toggle',
								order = 2,
							},
							followStr = {
								name = '따라가기 문자열',
								type = 'input',
								order = 3,
							},
						}
					},

					unFollowGroup = {
						name = '따라가기 중지',
						type = 'group',
						inline = true,
						order = 401,
						args = {
							unFollow = {
								name = '사용',
								type = 'toggle',
								order = 1,
							},
							unFollowStr = {
								name = '따라가기 문자열',
								type = 'input',
								order = 2,
							},
						}
					},

					readyCheckGroup = {
						name = '전투준비 수락',
						type = 'group',
						inline = true,
						order = 501,
						args = {
							readyCheck = {
								name = '사용',
								type = 'toggle',
								order = 1,
							},
							readyCheckResponse = {
								name = '응답 선택',
								type = 'select',
								values = {
									no = "아니오",
									yes = "예",
								},
								order = 2,
							},
						}
					},

				}
			},
		}
	}
end
