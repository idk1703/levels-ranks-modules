#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Armor Giver"
#define PLUGIN_AUTHOR "RoadSide Romeo (fork by fuckOff1703)"

Cookie g_hCookie;
int g_iArmor[MAXPLAYERS + 1];
bool g_bActive[MAXPLAYERS + 1], g_bHelmet[MAXPLAYERS + 1];

public Plugin myinfo = { name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION };

public void OnPluginStart()
{
	LoadTranslations("lr_module_armorgiver.phrases");
	g_hCookie = new Cookie("LR_ArmorGiver", "LR_ArmorGiver", CookieAccess_Private);
	
	HookEvent("player_spawn", OnPlayerSpawn);
	if(LR_IsLoaded()) LR_OnCoreIsReady();
	
	for(int iClient = 1; iClient <= MaxClients; iClient++) if(IsClientInGame(iClient)) OnClientCookiesCached(iClient);
}

public void LR_OnCoreIsReady()
{
	if(LR_GetSettingsValue(LR_TypeStatistics)) SetFailState(PLUGIN_NAME..." : This module will work if [ lr_type_statistics 0 ]");
	
	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
	ConfigLoad();
}

void ConfigLoad()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/armorgiver.ini");
	KeyValues hLR = new KeyValues("LR_ArmorGiver");
	
	if(!hLR.ImportFromFile(sPath)) SetFailState(PLUGIN_NAME..." : File is not found (%s)", sPath);

	if(hLR.JumpToKey("Settings") && hLR.GotoFirstSubKey())
	{
		int ilvl;
		do
		{
			g_iArmor[ilvl] = hLR.GetNum("armor", 0);
			g_bHelmet[ilvl] = view_as<bool>(hLR.GetNum("helmet", 1));
			ilvl++;
		}
		while(hLR.GotoNextKey());
		
		if(ilvl != LR_GetRankExp().Length) SetFailState(PLUGIN_NAME..." : The number of ranks does not match the specified number in the core (%s)", sPath);
	}
	else SetFailState(PLUGIN_NAME..." : Section Settings is not found (%s)", sPath);
	hLR.Close();
}

public void OnPlayerSpawn(Event hEvent, char[] sEvName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	int iRank = LR_GetClientInfo(iClient, ST_RANK);
	if(iClient && IsClientInGame(iClient) && g_bActive[iClient] && iRank)
	{
		if(GetClientArmor(iClient) < g_iArmor[iRank - 1]) SetEntProp(iClient, Prop_Send, "m_ArmorValue", g_iArmor[iRank - 1]);
		if(g_bHelmet[iRank - 1]) SetEntProp(iClient, Prop_Send, "m_bHasHelmet", 1);
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	int iRank = LR_GetClientInfo(iClient, ST_RANK), i;
	while(g_iArmor[i] <= 0) i++;
	if(iRank >= i)
	{
		FormatEx(sText, sizeof(sText), "%T", g_bActive[iClient] ? "AG_On" : "AG_Off", iClient, g_iArmor[iRank - 1]);
		hMenu.AddItem("Armor_Giver", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "AG_RankClosed", iClient, g_iArmor[i], i + 1);
		hMenu.AddItem("Armor_Giver", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Armor_Giver"))
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