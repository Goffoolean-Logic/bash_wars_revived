--[[ events.lua ]]

---------------------------------------------------------------------------
-- Event: Game state change handler
---------------------------------------------------------------------------
function CGameMode:OnGameRulesStateChange()
	local nNewState = GameRules:State_Get()
	--print( "OnGameRulesStateChange: " .. nNewState )

	if nNewState == DOTA_GAMERULES_STATE_HERO_SELECTION then

	end

	if nNewState == DOTA_GAMERULES_STATE_PRE_GAME then
		local numberOfPlayers = PlayerResource:GetPlayerCount()
		if numberOfPlayers > 7 then
			--self.TEAM_KILLS_TO_WIN = 25
			nCOUNTDOWNTIMER = 901
		elseif numberOfPlayers > 4 and numberOfPlayers <= 7 then
			--self.TEAM_KILLS_TO_WIN = 20
			nCOUNTDOWNTIMER = 721
		else
			--self.TEAM_KILLS_TO_WIN = 15
			nCOUNTDOWNTIMER = 601
		end

		self.TEAM_KILLS_TO_WIN = 20

		CustomNetTables:SetTableValue( "game_state", "victory_condition", { kills_to_win = self.TEAM_KILLS_TO_WIN } );

		self._fPreGameStartTime = GameRules:GetGameTime()
	end

	if nNewState == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		--print( "OnGameRulesStateChange: Game In Progress" )
		self.countdownEnabled = true
		CustomGameEventManager:Send_ServerToAllClients( "show_timer", {} )
	end
end

--------------------------------------------------------------------------------
-- Event: OnNPCSpawned
--------------------------------------------------------------------------------
function CGameMode:OnNPCSpawned( event )
	local spawnedUnit = EntIndexToHScript( event.entindex )
	if spawnedUnit:IsRealHero() then
        spawnedUnit:SetMaximumGoldBounty(100)
		-- Destroys the last hit effects
		local deathEffects = spawnedUnit:Attribute_GetIntValue( "effectsID", -1 )
		if deathEffects ~= -1 then
			ParticleManager:DestroyParticle( deathEffects, true )
			spawnedUnit:DeleteAttribute( "effectsID" )
		end
	end
end

---------------------------------------------------------------------------
-- Event: OnTeamKillCredit, see if anyone won
---------------------------------------------------------------------------
function CGameMode:OnTeamKillCredit( event )
--print( "OnTeamKillCredit" )
--DeepPrint( event )

	local nKillerID = event.killer_userid
	local nTeamID = event.teamnumber
	local nTeamKills = event.herokills
	local nKillsRemaining = self.TEAM_KILLS_TO_WIN - nTeamKills

   GameRules:GetGameModeEntity():SetTopBarTeamValue( nTeamID, nTeamKills )

	local broadcast_kill_event =
	{
		killer_id = event.killer_userid,
		team_id = event.teamnumber,
		team_kills = nTeamKills,
		kills_remaining = nKillsRemaining,
		victory = 0,
		close_to_victory = 0,
		very_close_to_victory = 0,
	}

    --DeepPrint(broadcast_kill_event);
    if nKillsRemaining <= 0 then
		GameRules:SetCustomVictoryMessage( self.m_VictoryMessages[nTeamID] )
		GameRules:SetGameWinner( nTeamID )
		broadcast_kill_event.victory = 1
	elseif nKillsRemaining == 1 then
		EmitGlobalSound( "ui.npe_objective_complete" )
		broadcast_kill_event.very_close_to_victory = 1
	elseif nKillsRemaining <= self.CLOSE_TO_VICTORY_THRESHOLD then
		EmitGlobalSound( "ui.npe_objective_given" )
		broadcast_kill_event.close_to_victory = 1
	end

	CustomGameEventManager:Send_ServerToAllClients( "kill_event", broadcast_kill_event )
end

---------------------------------------------------------------------------
-- Event: OnEntityKilled
---------------------------------------------------------------------------
function CGameMode:OnEntityKilled( event )
--print( "OnKillCredit" )
--DeepPrint( event )

	local killedUnit = EntIndexToHScript( event.entindex_killed )
	local killedTeam = killedUnit:GetTeam()
    local hero = EntIndexToHScript( event.entindex_attacker )
    local heroTeam = hero:GetTeam()

	if killedUnit:IsRealHero() then
		self.allSpawned = true
		--print("Hero has been killed")
		if 1==2 and hero:IsRealHero() and heroTeam ~= killedTeam then
        	--print("Granting killer xp")
			if killedUnit:GetTeam() == self.leadingTeam and self.isGameTied == false then
				local memberID = hero:GetPlayerID()
				--PlayerResource:ModifyGold( memberID, 500, true, 0 )
				hero:AddExperience( 100, 0, false, false )

                local kill_alert =
                {
                    hero_id = hero:GetClassname()
                }
                CustomGameEventManager:Send_ServerToAllClients( "kill_alert", kill_alert )
			else
				hero:AddExperience( 50, 0, false, false )
			end
		end

		--Granting XP to all heroes who assisted
		local allHeroes = HeroList:GetAllHeroes()
		for _,attacker in pairs( allHeroes ) do
			for i = 0, killedUnit:GetNumAttackers() - 1 do
				if attacker == HeroList:GetHero(killedUnit:GetAttacker( i )) then
					--print("Granting assist xp")
					attacker:AddExperience( 25, 0, false, false )
				end
			end
		end

        CGameMode:SetRespawnTime( killedTeam, killedUnit )
	end
end

---------------------------------------------------------------------------
-- Event: OnEntityHurt
---------------------------------------------------------------------------
function CGameMode:OnEntityHurt( event )
--print( "OnEntityHurt" )
--DeepPrint( event )

	local killedUnit = EntIndexToHScript( event.entindex_killed )
    killedUnit.iLastAttacker = event.entindex_attacker
    killedUnit.iLastAttackerTime = GameRules:GetGameTime()
end

function CGameMode:SetRespawnTime( killedTeam, killedUnit )
	--print("Setting time for respawn")
    killedUnit:SetTimeUntilRespawn(5)
	--if killedTeam == self.leadingTeam and self.isGameTied == false then
	--	killedUnit:SetTimeUntilRespawn(20)
	--else
	--	killedUnit:SetTimeUntilRespawn(10)
	--end
end


