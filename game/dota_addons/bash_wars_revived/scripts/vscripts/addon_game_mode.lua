print ( '[Init] Loading GameLogic' )

_G.nNEUTRAL_TEAM = 4
_G.nCOUNTDOWNTIMER = 901
FORCE_HERO_SELECTION = "npc_dota_hero_spirit_breaker"

if CGameMode == nil then
	_G.CGameMode = class({}) -- put CGameMode in the global scope
	--refer to: http://stackoverflow.com/questions/6586145/lua-require-with-global-local
end

function Precache( ctx )
  PrecacheUnitByNameSync('npc_dota_hero_spirit_breaker', ctx)
  PrecacheUnitByNameSync('npc_dota_hero_templar_assassin', ctx)
  PrecacheUnitByNameSync('npc_dota_hero_kunkka', ctx)
  PrecacheModel( "npc_dota_hero_spirit_breaker", ctx )

  PrecacheResource("particle", "particles/econ/items/kunkka/kunkka_weapon_whaleblade/kunkka_spell_torrent_splash_whaleblade.vpcf", ctx)
  PrecacheResource("particle", "particles/generic_gameplay/lasthit_coins_old_2d_version.vpcf", ctx)
  PrecacheResource("particle", "particles/units/heroes/hero_alchemist/alchemist_lasthit_coins.vpcf", ctx)

  PrecacheResource("particle", "particles/trap_mine_explosion.vpcf", ctx)
  PrecacheResource("particle", "particles/zuus_cloud_lol.vpcf", ctx)
end

require( "events" )
require( "util" )
require( "utility_functions" )

--function Activate()
--   GameLogic:Init()
--end

function Activate()
	-- Create our game mode and initialize it
	CGameMode:InitGameMode()
end

---------------------------------------------------------------------------
-- Initializer
---------------------------------------------------------------------------
function CGameMode:InitGameMode()
	print( "Overthrow is loaded." )

--	CustomNetTables:SetTableValue( "test", "value 1", {} );
--	CustomNetTables:SetTableValue( "test", "value 2", { a = 1, b = 2 } );

	self.m_TeamColors = {}
	self.m_TeamColors[DOTA_TEAM_GOODGUYS] = { 61, 210, 150 }	--		Teal
	self.m_TeamColors[DOTA_TEAM_BADGUYS]  = { 243, 201, 9 }		--		Yellow
	self.m_TeamColors[DOTA_TEAM_CUSTOM_1] = { 197, 77, 168 }	--      Pink
	self.m_TeamColors[DOTA_TEAM_CUSTOM_2] = { 255, 108, 0 }		--		Orange
	self.m_TeamColors[DOTA_TEAM_CUSTOM_3] = { 52, 85, 255 }		--		Blue
	self.m_TeamColors[DOTA_TEAM_CUSTOM_4] = { 101, 212, 19 }	--		Green
	self.m_TeamColors[DOTA_TEAM_CUSTOM_5] = { 129, 83, 54 }		--		Brown
	self.m_TeamColors[DOTA_TEAM_CUSTOM_6] = { 27, 192, 216 }	--		Cyan
	self.m_TeamColors[DOTA_TEAM_CUSTOM_7] = { 199, 228, 13 }	--		Olive
	self.m_TeamColors[DOTA_TEAM_CUSTOM_8] = { 140, 42, 244 }	--		Purple

	for team = 0, (DOTA_TEAM_COUNT-1) do
		color = self.m_TeamColors[ team ]
		if color then
			SetTeamCustomHealthbarColor( team, color[1], color[2], color[3] )
		end
	end

	self.m_VictoryMessages = {}
	self.m_VictoryMessages[DOTA_TEAM_GOODGUYS] = "#VictoryMessage_GoodGuys"
	self.m_VictoryMessages[DOTA_TEAM_BADGUYS]  = "#VictoryMessage_BadGuys"
	self.m_VictoryMessages[DOTA_TEAM_CUSTOM_1] = "#VictoryMessage_Custom1"
	self.m_VictoryMessages[DOTA_TEAM_CUSTOM_2] = "#VictoryMessage_Custom2"
	self.m_VictoryMessages[DOTA_TEAM_CUSTOM_3] = "#VictoryMessage_Custom3"
	self.m_VictoryMessages[DOTA_TEAM_CUSTOM_4] = "#VictoryMessage_Custom4"
	self.m_VictoryMessages[DOTA_TEAM_CUSTOM_5] = "#VictoryMessage_Custom5"
	self.m_VictoryMessages[DOTA_TEAM_CUSTOM_6] = "#VictoryMessage_Custom6"
	self.m_VictoryMessages[DOTA_TEAM_CUSTOM_7] = "#VictoryMessage_Custom7"
	self.m_VictoryMessages[DOTA_TEAM_CUSTOM_8] = "#VictoryMessage_Custom8"

	self.m_GatheredShuffledTeams = {}
	self.specialItem = ""
	self.spawnTime = 120
	self.nNextSpawnItemNumber = 1
	self.hasWarnedSpawn = false
	self.allSpawned = false
	self.leadingTeam = -1
	self.runnerupTeam = -1
	self.leadingTeamScore = 0
	self.runnerupTeamScore = 0
	self.isGameTied = true
	self.countdownEnabled = false
	self.itemSpawnIndex = 1
	self.itemSpawnLocation = Entities:FindByName( nil, "greevil" )
	self.tier1ItemBucket = {}
	self.tier2ItemBucket = {}
	self.tier3ItemBucket = {}
	self.tier4ItemBucket = {}

	self.TEAM_KILLS_TO_WIN = 20
	self.CLOSE_TO_VICTORY_THRESHOLD = 5

	---------------------------------------------------------------------------

	self:GatherAndRegisterValidTeams()

	local mode = GameRules:GetGameModeEntity()
	mode.CGameMode = self

	-- Show the ending scoreboard immediately
	GameRules:SetCustomGameEndDelay( 0 )
	GameRules:SetCustomVictoryMessageDuration( 20 )
	GameRules:SetPreGameTime( 10 )
    GameRules:SetSameHeroSelectionEnabled( true )
    GameRules:SetHeroSelectionTime( 20 )
	--GameRules:SetHideKillMessageHeaders( true )
	GameRules:SetHideKillMessageHeaders( true )
	GameRules:SetUseUniversalShopMode( false )

	mode:SetCustomGameForceHero(FORCE_HERO_SELECTION)
    mode:SetCameraDistanceOverride( 1500.0 )
	mode:SetTopBarTeamValuesOverride( true )
	mode:SetTopBarTeamValuesVisible( false)
	mode:SetRuneEnabled( 0, false ) --Double Damage
	mode:SetRuneEnabled( 1, false ) --Haste
	mode:SetRuneEnabled( 2, false ) --Illusion
	mode:SetRuneEnabled( 3, false ) --Invis
	mode:SetRuneEnabled( 4, false ) --Regen
	mode:SetRuneEnabled( 5, false ) --Bounty
	mode:SetLoseGoldOnDeath( false )
	mode:SetFountainPercentageHealthRegen( 20 )
	mode:SetFountainPercentageManaRegen( 20 )
	mode:SetFountainConstantManaRegen( 30 )

	ListenToGameEvent( "game_rules_state_change", Dynamic_Wrap( CGameMode, 'OnGameRulesStateChange' ), self )
	ListenToGameEvent( "npc_spawned", Dynamic_Wrap( CGameMode, "OnNPCSpawned" ), self )
	ListenToGameEvent( "dota_team_kill_credit", Dynamic_Wrap( CGameMode, 'OnTeamKillCredit' ), self )
	ListenToGameEvent( "entity_killed", Dynamic_Wrap( CGameMode, 'OnEntityKilled' ), self )
    ListenToGameEvent( "entity_hurt", Dynamic_Wrap( CGameMode, 'OnEntityHurt' ), self )
	--ListenToGameEvent( "player_connect", Dynamic_Wrap(  CGameMode, 'OnPlayerConnect' ), self)
	--ListenToGameEvent( "dota_item_picked_up", Dynamic_Wrap( CGameMode, "OnItemPickUp"), self )
	--ListenToGameEvent( "dota_npc_goal_reached", Dynamic_Wrap( CGameMode, "OnNpcGoalReached" ), self )

	Convars:RegisterCommand( "bashwars_set_timer", function(...) return SetTimer( ... ) end, "Set the timer.", FCVAR_CHEAT )
	Convars:RegisterCommand( "bashwars_force_end_game", function(...) return self:EndGame( DOTA_TEAM_GOODGUYS ) end, "Force the game to end.", FCVAR_CHEAT )

	GameRules:GetGameModeEntity():SetThink( "OnThink", self, 1 )

end

---------------------------------------------------------------------------
-- Get the color associated with a given teamID
---------------------------------------------------------------------------
function CGameMode:ColorForTeam( teamID )
	local color = self.m_TeamColors[ teamID ]
	if color == nil then
		color = { 255, 255, 255 } -- default to white
	end
	return color
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------
function CGameMode:EndGame( victoryTeam )
	GameRules:SetGameWinner( victoryTeam )
end


---------------------------------------------------------------------------
-- Put a label over a player's hero so people know who is on what team
---------------------------------------------------------------------------
function CGameMode:UpdatePlayerColor( nPlayerID )
	if not PlayerResource:HasSelectedHero( nPlayerID ) then
		return
	end

	local hero = PlayerResource:GetSelectedHeroEntity( nPlayerID )
	if hero == nil then
		return
	end

	local teamID = PlayerResource:GetTeam( nPlayerID )
	local color = self:ColorForTeam( teamID )
	PlayerResource:SetCustomPlayerColor( nPlayerID, color[1], color[2], color[3] )
end


---------------------------------------------------------------------------
-- Simple scoreboard using debug text
---------------------------------------------------------------------------
function CGameMode:UpdateScoreboard()
	local sortedTeams = {}
	for _, team in pairs( self.m_GatheredShuffledTeams ) do
		table.insert( sortedTeams, { teamID = team, teamScore = GetTeamHeroKills( team ) } )
	end

	-- reverse-sort by score
	table.sort( sortedTeams, function(a,b) return ( a.teamScore > b.teamScore ) end )

	for _, t in pairs( sortedTeams ) do
		local clr = self:ColorForTeam( t.teamID )

		-- Scaleform UI Scoreboard
		local score =
		{
			team_id = t.teamID,
			team_score = t.teamScore
		}
		FireGameEvent( "score_board", score )
	end
	-- Leader effects (moved from OnTeamKillCredit)
	local leader = sortedTeams[1].teamID
	--print("Leader = " .. leader)
	self.leadingTeam = leader
	self.runnerupTeam = sortedTeams[2].teamID
	self.leadingTeamScore = sortedTeams[1].teamScore
	self.runnerupTeamScore = sortedTeams[2].teamScore
	if sortedTeams[1].teamScore == sortedTeams[2].teamScore then
		self.isGameTied = true
	else
		self.isGameTied = false
	end
	local allHeroes = HeroList:GetAllHeroes()
	for _,entity in pairs( allHeroes) do
		if entity:GetTeamNumber() == leader and sortedTeams[1].teamScore ~= sortedTeams[2].teamScore then
			if entity:IsAlive() == true then
				-- Attaching a particle to the leading team heroes
				local existingParticle = entity:Attribute_GetIntValue( "particleID", -1 )
       			if existingParticle == -1 then
       				local particleLeader = ParticleManager:CreateParticle( "particles/leader/leader_overhead.vpcf", PATTACH_OVERHEAD_FOLLOW, entity )
					ParticleManager:SetParticleControlEnt( particleLeader, PATTACH_OVERHEAD_FOLLOW, entity, PATTACH_OVERHEAD_FOLLOW, "follow_overhead", entity:GetAbsOrigin(), true )
					entity:Attribute_SetIntValue( "particleID", particleLeader )
				end
			else
				local particleLeader = entity:Attribute_GetIntValue( "particleID", -1 )
				if particleLeader ~= -1 then
					ParticleManager:DestroyParticle( particleLeader, true )
					entity:DeleteAttribute( "particleID" )
				end
			end
		else
			local particleLeader = entity:Attribute_GetIntValue( "particleID", -1 )
			if particleLeader ~= -1 then
				ParticleManager:DestroyParticle( particleLeader, true )
				entity:DeleteAttribute( "particleID" )
			end
		end
	end
end

---------------------------------------------------------------------------
-- Update player labels and the scoreboard
---------------------------------------------------------------------------
function CGameMode:OnThink()
	for nPlayerID = 0, (DOTA_MAX_TEAM_PLAYERS-1) do
		self:UpdatePlayerColor( nPlayerID )
	end

	self:UpdateScoreboard()
	-- Stop thinking if game is paused
	if GameRules:IsGamePaused() == true then
        return 1
    end

	if self.countdownEnabled == true then
		CountdownTimer()
		if nCOUNTDOWNTIMER == 30 then
			CustomGameEventManager:Send_ServerToAllClients( "timer_alert", {} )
		end
		if nCOUNTDOWNTIMER <= 0 then
			--Check to see if there's a tie
			if self.isGameTied == false then
				GameRules:SetCustomVictoryMessage( self.m_VictoryMessages[self.leadingTeam] )
				CGameMode:EndGame( self.leadingTeam )
				self.countdownEnabled = false
			else
				self.TEAM_KILLS_TO_WIN = self.leadingTeamScore + 1
				local broadcast_killcount =
				{
					killcount = self.TEAM_KILLS_TO_WIN
				}
				CustomGameEventManager:Send_ServerToAllClients( "overtime_alert", broadcast_killcount )
			end
       	end
	end

	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		-- do stuff during the game
	end

	return 1
end

---------------------------------------------------------------------------
-- Scan the map to see which teams have spawn points
---------------------------------------------------------------------------
function CGameMode:GatherAndRegisterValidTeams()
--	print( "GatherValidTeams:" )

	local foundTeams = {}
	for _, playerStart in pairs( Entities:FindAllByClassname( "info_player_start_dota" ) ) do
		foundTeams[  playerStart:GetTeam() ] = true
	end

	local numTeams = TableCount(foundTeams)
	print( "GatherValidTeams - Found spawns for a total of " .. numTeams .. " teams" )

	local foundTeamsList = {}
	for t, _ in pairs( foundTeams ) do
		table.insert( foundTeamsList, t )
	end

	if numTeams == 0 then
		print( "GatherValidTeams - NO team spawns detected, defaulting to GOOD/BAD" )
		table.insert( foundTeamsList, DOTA_TEAM_GOODGUYS )
		table.insert( foundTeamsList, DOTA_TEAM_BADGUYS )
		numTeams = 2
	end

	local maxPlayersPerValidTeam = math.floor( 10 / numTeams )

	self.m_GatheredShuffledTeams = ShuffledList( foundTeamsList )

	print( "Final shuffled team list:" )
	for _, team in pairs( self.m_GatheredShuffledTeams ) do
		print( " - " .. team .. " ( " .. GetTeamName( team ) .. " )" )
	end

	print( "Setting up teams:" )
	for team = 0, (DOTA_TEAM_COUNT-1) do
		local maxPlayers = 0
		if ( nil ~= TableFindKey( foundTeamsList, team ) ) then
			maxPlayers = maxPlayersPerValidTeam
		end
		print( " - " .. team .. " ( " .. GetTeamName( team ) .. " ) -> max players = " .. tostring(maxPlayers) )
		GameRules:SetCustomGameTeamMaxPlayers( team, maxPlayers )
	end
end
