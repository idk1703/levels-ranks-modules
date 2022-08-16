#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - ExoJumpBoots"
#define PLUGIN_AUTHOR "RoadSide Romeo & R1KO"

int g_iLevel;
bool g_bActive[MAXPLAYERS+1];
Cookie g_hCookie;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState(PLUGIN_NAME ... " : Plug-in works only on CS:GO");
	}

	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	g_hCookie = new Cookie("LR_ExoJumpBoots", "LR_ExoJumpBoots", CookieAccess_Private);
	LoadTranslations("lr_module_exojumpboots.phrases");
	HookEvent("player_spawn", PlayerSpawn);

	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
		{
			OnClientCookiesCached(iClient);
		}
	}
}

public void LR_OnCoreIsReady()
{
	if(LR_GetSettingsValue(LR_TypeStatistics))
	{
		SetFailState(PLUGIN_NAME ... " : This module will work if [ lr_type_statistics 0 ]");
	}
	ConfigLoad();

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/exojumpboots.ini");
	KeyValues hLR = new KeyValues("LR_ExoJumpBoots");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iLevel = hLR.GetNum("rank", 0);

	hLR.Close();
}

public void PlayerSpawn(Event hEvent, char[] sEvName, bool bDontBroadcast)
{	
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if(iClient && IsClientInGame(iClient) && g_bActive[iClient] && LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		SetEntProp(iClient, Prop_Send, "m_passiveItems", view_as<int>(true), 1, 1); // wtf ?
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", g_bActive[iClient] ? "ExoJumpBoots_On" : "ExoJumpBoots_Off", iClient);
		hMenu.AddItem("ExoJumpBoots", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "ExoJumpBoots_RankClosed", iClient, g_iLevel);
		hMenu.AddItem("ExoJumpBoots", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "ExoJumpBoots"))
	{
		g_bActive[iClient] = !g_bActive[iClient];

		char sCookie[2];
		sCookie[0] = '0' + view_as<char>(g_bActive[iClient]);
		g_hCookie.Set(iClient, sCookie);

		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	g_hCookie.Get(iClient, sCookie, sizeof(sCookie));
	g_bActive[iClient] = (!sCookie[0]) ? true : (sCookie[0]  == '1');
}

public void OnClientDisconnect(int iClient)
{
	g_bActive[iClient] = false;
}