#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - ExStats Maps"
#define PLUGIN_AUTHOR "RoadSide Romeo"

enum
{
	CT,
	T
}

enum struct ePlayer
{
	int	AccountID;
	int MapCountPlay;
	int MapCountKills;
	int MapCountDeaths;
	int MapCountRoundsOverall;
	int MapCountRound[2];
	int MapCountTime;
	int MapCountBPlanted;
	int MapCountBDefused;
	int MapCountHRescued;
	int MapCountHKilled;
	bool PlayerActive;

	void Destroy()
	{
		this.MapCountPlay = 1;
		this.MapCountKills = 0;
		this.MapCountDeaths = 0;
		this.MapCountRoundsOverall = 0;
		this.MapCountRound[CT] = 0;
		this.MapCountRound[T] = 0;
		this.MapCountBPlanted = 0;
		this.MapCountBDefused = 0;
		this.MapCountHRescued = 0;
		this.MapCountHKilled = 0;
		this.MapCountTime = 0;
		this.PlayerActive = true;
	}
}

ePlayer g_iClient[MAXPLAYERS + 1];

char g_sTableName[96], g_sPluginTitle[64], g_sCurrentMap[128];
static const char g_sCreateTable[] = "CREATE TABLE IF NOT EXISTS `%s_maps` (`steam` varchar(32) NOT NULL default '', `name_map` varchar(128) NOT NULL default '', `countplays` int NOT NULL DEFAULT 0, `kills` int NOT NULL DEFAULT 0, `deaths` int NOT NULL DEFAULT 0, `rounds_overall` int NOT NULL DEFAULT 0, `rounds_ct` int NOT NULL DEFAULT 0, `rounds_t` int NOT NULL DEFAULT 0, `bomb_planted` int NOT NULL DEFAULT 0, `bomb_defused` int NOT NULL DEFAULT 0, `hostage_rescued` int NOT NULL DEFAULT 0, `hostage_killed` int NOT NULL DEFAULT 0, `playtime` int NOT NULL DEFAULT 0, PRIMARY KEY (`steam`, `name_map`))%s";
EngineVersion g_iEngine;
Handle g_hTimer;
Database g_hDatabase;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = "v3.1 F1"};
public void OnPluginStart()
{
	g_iEngine = GetEngineVersion();

	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	RegConsoleCmd("sm_topmaps", MapTOP_CMD);

	LoadTranslations("common.phrases");
	LoadTranslations("lr_module_exmaps.phrases");

	HookEvent("player_death", Hooks, EventHookMode_Pre);
	HookEvent("round_end", Hooks, EventHookMode_Pre);
	HookEvent("bomb_planted", Hooks, EventHookMode_Pre);
	HookEvent("bomb_defused", Hooks, EventHookMode_Pre);
	HookEvent("hostage_killed", Hooks, EventHookMode_Pre);
	HookEvent("hostage_rescued", Hooks, EventHookMode_Pre);
}

public void LR_OnCoreIsReady()
{
	delete g_hDatabase;
	g_hDatabase = LR_GetDatabase();

	delete g_hTimer;
	g_hTimer = CreateTimer(1.0, TimerMap, _, TIMER_REPEAT);

	LR_Hook(LR_OnPlayerLoaded, LoadDataPlayer);
	LR_Hook(LR_OnResetPlayerStats, ResetDataPlayer);
	LR_Hook(LR_OnDatabaseCleanup, DatabaseCleanup);
	LR_MenuHook(LR_MyStatsSecondary, LR_OnMenuCreated, LR_OnMenuItemSelected);
	LR_MenuHook(LR_TopMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
	LR_GetTableName(g_sTableName, sizeof(g_sTableName));
	LR_GetTitleMenu(g_sPluginTitle, sizeof(g_sPluginTitle));

	char sQuery[768], sEndQuery[64];
	if(LR_GetDatabaseType())
	{
		sEndQuery = ";";
	}
	else
	{
		char sCharset[8], sCharsetType[16];
		sCharset = LR_GetSettingsValue(LR_DB_Allow_UTF8MB4) ? "utf8mb4" : "utf8";
		sCharsetType = LR_GetSettingsValue(LR_DB_Charset_Type) ? "_unicode_ci" : "_general_ci";
		FormatEx(sEndQuery, sizeof(sEndQuery), " CHARSET=%s COLLATE %s%s", sCharset, sCharset, sCharsetType);
	}

	g_hDatabase.Format(sQuery, sizeof(sQuery), g_sCreateTable, g_sTableName, sEndQuery);
	g_hDatabase.Query(SQL_CreateTable, sQuery, 0, DBPrio_High);
}

public void SQL_CreateTable(Database db, DBResultSet dbRs, const char[] sError, int iData)
{
	if(!dbRs)
	{
		LogError(PLUGIN_NAME ... " : SQL_CreateTable - error while working with data (%s)", sError);
		return;
	}

	g_hDatabase.SetCharset(LR_GetSettingsValue(LR_DB_Allow_UTF8MB4) ? "utf8mb4" : "utf8");
	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(LR_GetClientStatus(iClient))
		{
			LoadDataPlayer(iClient, GetSteamAccountID(iClient));
		}
	}
}

public void OnMapStart()
{
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	int iPos = 0;
	for(int i = 0, iLen = strlen(g_sCurrentMap); i != iLen;)
	{
		if(g_sCurrentMap[i++] == '/')
		{
			iPos = i;
		}
	}

	if(iPos)
	{
		strcopy(g_sCurrentMap, sizeof(g_sCurrentMap) - iPos, g_sCurrentMap[iPos]);
	}
}

public Action TimerMap(Handle hTimer)
{
	if(LR_CheckCountPlayers())
	{
		for(int iClient = MaxClients + 1; --iClient;)
		{
			if(g_iClient[iClient].PlayerActive)
			{
				g_iClient[iClient].MapCountTime++;
			}
		}
	}

	return Plugin_Continue;
}

public void Hooks(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{
	if(LR_CheckCountPlayers())
	{
		switch(sEvName[0])
		{
			case 'p':
			{
				int iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
				int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));

				if(iAttacker && iClient && IsClientInGame(iClient) && IsClientInGame(iAttacker))
				{
					g_iClient[iAttacker].MapCountKills++;
					g_iClient[iClient].MapCountDeaths++;
				}
			}

			case 'r':
			{
				int iWinnerTeam = GetEventInt(hEvent, "winner");
				for(int iClient = MaxClients + 1; --iClient;)
				{
					if(IsClientInGame(iClient) && g_iClient[iClient].PlayerActive)
					{
						g_iClient[iClient].MapCountRoundsOverall++;
						if(GetClientTeam(iClient) == iWinnerTeam)
						{
							switch(iWinnerTeam)
							{
								case CS_TEAM_CT: g_iClient[iClient].MapCountRound[CT]++;
								case CS_TEAM_T: g_iClient[iClient].MapCountRound[T]++;
							}
						}
						SaveDataPlayer(iClient);
					}
				}
			}

			case 'b':
			{
				int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
				if(iClient)
				{
					switch(sEvName[6])
					{
						case 'l': g_iClient[iClient].MapCountBPlanted++;
						case 'e': g_iClient[iClient].MapCountBDefused++;
					}
				}
			}

			case 'h':
			{
				int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
				if(iClient)
				{
					switch(sEvName[8])
					{
						case 'k': g_iClient[iClient].MapCountHKilled++;
						case 'r': g_iClient[iClient].MapCountHRescued++;
					}
				}
			}
		}
	}
}

public Action MapTOP_CMD(int iClient, int iArgs)
{
	MapTOP(iClient);
	return Plugin_Handled;
}

public void OnClientSayCommand_Post(int iClient, const char[] sCommand, const char[] sArgs)
{
	if(!strcmp(sArgs, "topmaps"))
		MapTOP(iClient);
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	switch(OnMenuType)
	{
		case LR_TopMenu:
		{
			FormatEx(sText, sizeof(sText), "%T", "MapTOP", iClient);
			hMenu.AddItem("map_top", sText);
		}

		case LR_MyStatsSecondary:
		{
			FormatEx(sText, sizeof(sText), "%T", "MapStatisticsButton", iClient);
			hMenu.AddItem("map_stats", sText);
		}
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "map_top"))
	{
		MapTOP(iClient);
	}

	if(!strcmp(sInfo, "map_stats"))
	{
		MapsStats(iClient);
	}
}

void MapTOP(int iClient)
{
	char sText[128];
	Menu hMenu = new Menu(MapTOPHandler);
	hMenu.SetTitle("%s | %T\n ", g_sPluginTitle, "MapTOP", iClient);

	FormatEx(sText, sizeof(sText), "%T", "MapTOPClient", iClient);
	hMenu.AddItem(NULL_STRING, sText);

	FormatEx(sText, sizeof(sText), "%T", "MapTOPAll", iClient);
	hMenu.AddItem(NULL_STRING, sText);

	hMenu.ExitBackButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MapTOPHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel:
		{
			if(iSlot == MenuCancel_ExitBack)
			{
				LR_ShowMenu(iClient, LR_TopMenu);
			}
		}
		case MenuAction_Select: MapTOPCall(iClient, iSlot);
	}

	return 0;
}

void MapTOPCall(int iClient, int iMode)
{
	if(g_hDatabase)
	{
		if(LR_GetClientStatus(iClient))
		{
			char sQuery[512];
			switch(iMode)
			{
				case 0: g_hDatabase.Format(sQuery, sizeof(sQuery), "SELECT `name_map`, `kills` FROM `%s_maps` WHERE `steam` = 'STEAM_%i:%i:%i' AND `kills` != 0 ORDER BY `kills` DESC LIMIT 10 OFFSET 0", g_sTableName, g_iEngine == Engine_CSGO, g_iClient[iClient].AccountID & 1, g_iClient[iClient].AccountID >>> 1);
				case 1: g_hDatabase.Format(sQuery, sizeof(sQuery), "SELECT `%s`.`name`, `%s_maps`.`kills` FROM `%s`, `%s_maps` WHERE `%s_maps`.`name_map` = '%s' AND `%s`.`steam` = `%s_maps`.`steam` AND `%s_maps`.`kills` != 0 AND `%s`.`lastconnect` != 0 ORDER BY `%s_maps`.`kills` DESC LIMIT 10 OFFSET 0", g_sTableName, g_sTableName, g_sTableName, g_sTableName, g_sTableName, g_sCurrentMap, g_sTableName, g_sTableName, g_sTableName, g_sTableName, g_sTableName);
			}
			g_hDatabase.Query(SQL_MapTOPCall, sQuery, GetClientUserId(iClient) << 4 | iMode);
		}
	}
}

public void SQL_MapTOPCall(Database db, DBResultSet dbRs, const char[] sError, int iData)
{
	if(!dbRs)
	{
		LogError(PLUGIN_NAME ... " : SQL_MapTOPCall - error while working with data (%s)", sError);
		return;
	}

	int	iCount; char sText[192], sBuffer[128], sTemp[1024];
	int	iClient = GetClientOfUserId(iData >> 4);

	if(iClient && dbRs.HasResults)
	{
		while(dbRs.FetchRow())
		{
			iCount++;
			dbRs.FetchString(0, sBuffer, sizeof(sBuffer));
			FormatEx(sText, sizeof(sText), "%T\n", "MapTOPList", iClient, iCount, dbRs.FetchInt(1), sBuffer);
			
			if(strlen(sTemp) + strlen(sText) < 1024)
			{
				Format(sTemp, sizeof(sTemp), "%s%s", sTemp, sText); sText = NULL_STRING;
			}
		}
		if(!iCount) FormatEx(sTemp, sizeof(sTemp), "%T", "NoData", iClient);

		Menu hMenu = new Menu(SQL_MapTOPCallHandler);
		hMenu.SetTitle("%s | %T\n \n%s\n ", g_sPluginTitle, (iData & 0xF) ? "MapTOPAll" : "MapTOPClient", iClient, sTemp);

		FormatEx(sText, sizeof(sText), "%T", "Back", iClient);
		hMenu.AddItem(NULL_STRING, sText);

		hMenu.Display(iClient, MENU_TIME_FOREVER);
	}
}

public int SQL_MapTOPCallHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot)
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Select: MapTOP(iClient);
	}

	return 0;
}

void MapsStats(int iClient)
{
	static char sText[128], sBuffer[256], sBufferKDStats[256];
	Menu hMenu = new Menu(MapsStatsHandler);

	if(!StrContains(g_sCurrentMap, "cs_", false))
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%T", "MapStatistics_Cs", iClient, g_iClient[iClient].MapCountHRescued, g_iClient[iClient].MapCountHKilled);
	}
	else if(!StrContains(g_sCurrentMap, "de_", false))
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%T", "MapStatistics_De", iClient, g_iClient[iClient].MapCountBPlanted, g_iClient[iClient].MapCountBDefused);
	}
	else
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%T", "MapStatistics_Custom", iClient, g_iClient[iClient].MapCountRound[CT], g_iClient[iClient].MapCountRound[T]);
	}

	FormatEx(sBufferKDStats, sizeof(sBufferKDStats), "%T", "MapStatistics_KDStats", iClient, g_iClient[iClient].MapCountKills, g_iClient[iClient].MapCountDeaths, g_iClient[iClient].MapCountKills / (g_iClient[iClient].MapCountDeaths ? float(g_iClient[iClient].MapCountDeaths) : 1.0));
	hMenu.SetTitle("%s | %T\n ", g_sPluginTitle, "MapStatistics", iClient, g_sCurrentMap, g_iClient[iClient].MapCountTime / 3600, g_iClient[iClient].MapCountTime / 60 % 60, g_iClient[iClient].MapCountTime % 60, RoundToCeil(100.0 / (g_iClient[iClient].MapCountRoundsOverall ? g_iClient[iClient].MapCountRoundsOverall : 1) * (g_iClient[iClient].MapCountRound[CT] + g_iClient[iClient].MapCountRound[T])), sBuffer, sBufferKDStats);

	FormatEx(sText, sizeof(sText), "%T", "Back", iClient);
	hMenu.AddItem(NULL_STRING, sText);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MapsStatsHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Select: LR_ShowMenu(iClient, LR_MyStatsSecondary);
	}

	return 0;
}

void LoadDataPlayer(int iClient, int iAccountID)
{
	if(g_hDatabase)
	{
		char sQuery[512];
		g_iClient[iClient].AccountID = iAccountID;
		g_iClient[iClient].PlayerActive = false;

		g_hDatabase.Format(sQuery, sizeof(sQuery), "SELECT `countplays`, `kills`, `deaths`, `rounds_overall`, `rounds_ct`, `rounds_t`, `bomb_planted`, `bomb_defused`, `hostage_rescued`, `hostage_killed`, `playtime` FROM `%s_maps` WHERE `steam` = 'STEAM_%i:%i:%i' AND `name_map` = '%s';", g_sTableName, g_iEngine == Engine_CSGO, g_iClient[iClient].AccountID & 1, g_iClient[iClient].AccountID >>> 1, g_sCurrentMap);
		g_hDatabase.Query(SQL_LoadDataPlayer, sQuery, GetClientUserId(iClient));
	}
}

public void SQL_LoadDataPlayer(Database db, DBResultSet dbRs, const char[] sError, int iUserID)
{
	if(!dbRs)
	{
		LogError(PLUGIN_NAME ... " : SQL_LoadDataPlayer - error while working with data (%s)", sError);
		return;
	}

	int iClient = GetClientOfUserId(iUserID);
	if(iClient)
	{
		if(dbRs.HasResults && dbRs.FetchRow())
		{
			g_iClient[iClient].MapCountPlay = dbRs.FetchInt(0) + 1;
			g_iClient[iClient].MapCountKills = dbRs.FetchInt(1);
			g_iClient[iClient].MapCountDeaths = dbRs.FetchInt(2);
			g_iClient[iClient].MapCountRoundsOverall = dbRs.FetchInt(3);
			g_iClient[iClient].MapCountRound[CT] = dbRs.FetchInt(4);
			g_iClient[iClient].MapCountRound[T] = dbRs.FetchInt(5);
			g_iClient[iClient].MapCountBPlanted = dbRs.FetchInt(6);
			g_iClient[iClient].MapCountBDefused = dbRs.FetchInt(7);
			g_iClient[iClient].MapCountHRescued = dbRs.FetchInt(8);
			g_iClient[iClient].MapCountHKilled = dbRs.FetchInt(9);
			g_iClient[iClient].MapCountTime = dbRs.FetchInt(10);
			g_iClient[iClient].PlayerActive = true;
		}
		else
		{
			char sQuery[640];
			g_hDatabase.Format(sQuery, sizeof(sQuery), "INSERT INTO `%s_maps` (`steam`, `name_map`, `countplays`, `kills`, `deaths`, `rounds_overall`, `rounds_ct`, `rounds_t`, `bomb_planted`, `bomb_defused`, `hostage_rescued`, `hostage_killed`, `playtime`) VALUES ('STEAM_%i:%i:%i', '%s', '%d', '%d', '%d', '%d', '%d', '%d', '%d', '%d', '%d', '%d', '%d');", g_sTableName, g_iEngine == Engine_CSGO, g_iClient[iClient].AccountID & 1, g_iClient[iClient].AccountID >>> 1, g_sCurrentMap, g_iClient[iClient].MapCountPlay, g_iClient[iClient].MapCountKills, g_iClient[iClient].MapCountDeaths, g_iClient[iClient].MapCountRoundsOverall, g_iClient[iClient].MapCountRound[CT], g_iClient[iClient].MapCountRound[T], g_iClient[iClient].MapCountBPlanted, g_iClient[iClient].MapCountBDefused, g_iClient[iClient].MapCountHRescued, g_iClient[iClient].MapCountHKilled, g_iClient[iClient].MapCountTime);
			g_hDatabase.Query(SQL_CreateDataPlayer, sQuery, GetClientUserId(iClient));
		}
	}
}

public void SQL_CreateDataPlayer(Database db, DBResultSet dbRs, const char[] sError, int iUserID)
{
	if(!dbRs)
	{
		LogError(PLUGIN_NAME ... " : SQL_CreateDataPlayer - error while working with data (%s)", sError);
		return;
	}

	int iClient = GetClientOfUserId(iUserID);
	if(iClient)
	{
		g_iClient[iClient].Destroy();
	}
}

void SaveDataPlayer(int iClient)
{
	if(g_hDatabase)
	{
		char sQuery[1024];
		g_hDatabase.Format(sQuery, sizeof(sQuery), "UPDATE `%s_maps` SET `countplays` = %d, `kills` = %d, `deaths` = %d, `rounds_overall` = %d, `rounds_ct` = %d, `rounds_t` = %d, `bomb_planted` = %d, `bomb_defused` = %d, `hostage_rescued` = %d, `hostage_killed` = %d, `playtime` = %d WHERE `steam` = 'STEAM_%i:%i:%i' AND `name_map` = '%s';", g_sTableName, g_iClient[iClient].MapCountPlay, g_iClient[iClient].MapCountKills, g_iClient[iClient].MapCountDeaths, g_iClient[iClient].MapCountRoundsOverall, g_iClient[iClient].MapCountRound[CT], g_iClient[iClient].MapCountRound[T], g_iClient[iClient].MapCountBPlanted, g_iClient[iClient].MapCountBDefused, g_iClient[iClient].MapCountHRescued, g_iClient[iClient].MapCountHKilled, g_iClient[iClient].MapCountTime, g_iEngine == Engine_CSGO, g_iClient[iClient].AccountID & 1, g_iClient[iClient].AccountID >>> 1, g_sCurrentMap);
		g_hDatabase.Query(SQL_SaveDataPlayer, sQuery);
	}
}

public void SQL_SaveDataPlayer(Database db, DBResultSet dbRs, const char[] sError, int iCallback)
{
	if(!dbRs)
	{
		LogError(PLUGIN_NAME ... " : SQL_SaveDataPlayer - error while working with data (%s)", sError);
	}
}

void ResetDataPlayer(int iClient, int iAccountID)
{
	if(g_hDatabase)
	{
		char sQuery[512];
		g_hDatabase.Format(sQuery, sizeof(sQuery), "UPDATE `%s_maps` SET `countplays` = 0, `kills` = 0, `deaths` = 0, `rounds_overall` = 0, `rounds_ct` = 0, `rounds_t` = 0, `bomb_planted` = 0, `bomb_defused` = 0, `hostage_rescued` = 0, `hostage_killed` = 0, `playtime` = 0 WHERE `steam` = 'STEAM_%i:%i:%i';", g_sTableName, g_iEngine == Engine_CSGO, g_iClient[iClient].AccountID & 1, g_iClient[iClient].AccountID >>> 1);
		g_hDatabase.Query(SQL_ResetDataPlayer, sQuery, iClient ? GetClientUserId(iClient) : 0);
	}
}

public void SQL_ResetDataPlayer(Database db, DBResultSet dbRs, const char[] sError, int iUserID)
{
	if(!dbRs)
	{
		LogError(PLUGIN_NAME ... " : SQL_ResetDataPlayer - error while working with data (%s)", sError);
		return;
	}

	int iClient = GetClientOfUserId(iUserID);
	if(iClient)
	{
		g_iClient[iClient].Destroy();
	}
}

void DatabaseCleanup(LR_CleanupType iType, Transaction hQuery)
{
	if(iType == LR_AllData || iType == LR_StatsData)
	{
		char sQuery[768], sEndQuery[64];

		FormatEx(sQuery, sizeof(sQuery), "DROP TABLE IF EXISTS `%s_maps`;", g_sTableName);
		hQuery.AddQuery(sQuery);

		if(LR_GetDatabaseType())
		{
			sEndQuery = ";";
		}
		else
		{
			char sCharset[8], sCharsetType[16];
			sCharset = LR_GetSettingsValue(LR_DB_Allow_UTF8MB4) ? "utf8mb4" : "utf8";
			sCharsetType = LR_GetSettingsValue(LR_DB_Charset_Type) ? "_unicode_ci" : "_general_ci";
			FormatEx(sEndQuery, sizeof(sEndQuery), " CHARSET=%s COLLATE %s%s", sCharset, sCharset, sCharsetType);
		}
		
		FormatEx(sQuery, sizeof(sQuery), g_sCreateTable, g_sTableName, sEndQuery);
		hQuery.AddQuery(sQuery);
	}
}

public void OnClientDisconnect(int iClient)
{
	SaveDataPlayer(iClient);
	g_iClient[iClient].PlayerActive = false;
}

public void OnPluginEnd()
{
	for(int iClient = MaxClients + 1; --iClient;)
	{
		if(IsClientInGame(iClient))
		{
			OnClientDisconnect(iClient);	
		}
	}
}
