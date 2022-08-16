#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <geoip>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - ExStats GeoIP"
#define PLUGIN_AUTHOR "RoadSide Romeo"

char g_sTableName[32];
static const char g_sCreateTable[] = "CREATE TABLE IF NOT EXISTS `%s_geoip` (`steam` varchar(32) NOT NULL default '' PRIMARY KEY, `clientip` varchar(16) NOT NULL default '', `country` varchar(48) NOT NULL default '', `region` varchar(48) NOT NULL default '', `city` varchar(48) NOT NULL default '', `country_code` varchar(4) NOT NULL default '') %s";
Database g_hDatabase;
EngineVersion g_iEngine;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	g_iEngine = GetEngineVersion();
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}
}

public void LR_OnCoreIsReady()
{
	delete g_hDatabase;
	g_hDatabase = LR_GetDatabase();

	LR_Hook(LR_OnPlayerLoaded, LoadDataPlayer);
	LR_Hook(LR_OnDatabaseCleanup, DatabaseCleanup);
	LR_GetTableName(g_sTableName, sizeof(g_sTableName));

	if(!LR_GetDatabaseType())
	{
		char sQuery[512], sEndQuery[64];
		char sCharset[8], sCharsetType[16];
		sCharset = LR_GetSettingsValue(LR_DB_Allow_UTF8MB4) ? "utf8mb4" : "utf8";
		sCharsetType = LR_GetSettingsValue(LR_DB_Charset_Type) ? "_unicode_ci" : "_general_ci";
		FormatEx(sEndQuery, sizeof(sEndQuery), " CHARSET=%s COLLATE %s%s", sCharset, sCharset, sCharsetType);
		SQL_LockDatabase(g_hDatabase);
		FormatEx(sQuery, sizeof(sQuery), g_sCreateTable, g_sTableName, sEndQuery);
		SQL_FastQuery(g_hDatabase, sQuery);
		SQL_UnlockDatabase(g_hDatabase);

		g_hDatabase.SetCharset(LR_GetSettingsValue(LR_DB_Allow_UTF8MB4) ? "utf8mb4" : "utf8");

		for(int iClient = MaxClients + 1; --iClient;)
		{
			if(LR_GetClientStatus(iClient))
			{
				LoadDataPlayer(iClient, GetSteamAccountID(iClient));
			}
		}
	}
	else SetFailState(PLUGIN_NAME ... " : LR_OnCoreIsReady - not MySQL");
}

void LoadDataPlayer(int iClient, int iAccountID)
{
	char sQuery[1024], sIp[16], sCity[45], sRegion[45], sCountry[45], sCountryCode[3];

	GetClientIP(iClient, sIp, sizeof(sIp));
	GeoipCity(sIp, sCity, sizeof(sCity)) ? g_hDatabase.Escape(sCity, sCity, sizeof(sCity)) : Format(sCity, sizeof(sCity), "NA") != 0;
	GeoipRegion(sIp, sRegion, sizeof(sRegion)) ? g_hDatabase.Escape(sRegion, sRegion, sizeof(sRegion)) : Format(sRegion, sizeof(sRegion), "NA") != 0;
	GeoipCountry(sIp, sCountry, sizeof(sCountry)) ? g_hDatabase.Escape(sCountry, sCountry, sizeof(sCountry)) : Format(sCountry, sizeof(sCountry), "NA") != 0;
	sCountryCode = GeoipCode2(sIp, sCountryCode) ? sCountryCode : "NA";

	g_hDatabase.Format(sQuery, sizeof(sQuery), "INSERT IGNORE INTO `%s_geoip` SET `steam` = 'STEAM_%i:%i:%i', `clientip` = '%s', `country` = '%s', `region` = '%s', `city` = '%s', `country_code` = '%s' ON DUPLICATE KEY UPDATE `clientip` = '%s', `country` = '%s', `region` = '%s', `city` = '%s', `country_code` = '%s';", g_sTableName, g_iEngine == Engine_CSGO, iAccountID & 1, iAccountID >>> 1, sIp, sCountry, sRegion, sCity, sCountryCode, sIp, sCountry, sRegion, sCity, sCountryCode);
	g_hDatabase.Query(SQL_LoadDataPlayer, sQuery);
}

public void SQL_LoadDataPlayer(Database db, DBResultSet dbRs, const char[] sError, any data)
{
	if(!dbRs)
	{
		LogError(PLUGIN_NAME ... " : SQL_LoadDataPlayer - %s", sError);
	}
}

void DatabaseCleanup(LR_CleanupType iType, Transaction hQuery)
{
	if(iType == LR_AllData || iType == LR_StatsData)
	{
		char sQuery[512];

		FormatEx(sQuery, sizeof(sQuery), "DROP TABLE IF EXISTS `%s_geoip`;", g_sTableName);
		hQuery.AddQuery(sQuery);

		FormatEx(sQuery, sizeof(sQuery), g_sCreateTable, g_sTableName);
		hQuery.AddQuery(sQuery);
	}
}