#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Armor Giver"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iLevel,
		g_iAGArmor;
bool		g_bActive[MAXPLAYERS+1],
		g_bAGHelmet;
Handle	g_hCookie;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	g_hCookie = RegClientCookie("LR_ArmorGiver", "LR_ArmorGiver", CookieAccess_Private);
	LoadTranslations("lr_module_armorgiver.phrases");
	HookEvent("player_spawn", PlayerSpawn);
	ConfigLoad();

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

	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/armorgiver.ini");
	KeyValues hLR = new KeyValues("LR_ArmorGiver");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iLevel = hLR.GetNum("rank", 0);
	g_iAGArmor = hLR.GetNum("value", 125);
	g_bAGHelmet = view_as<bool>(hLR.GetNum("helmet", 1));

	hLR.Close();
}

public void PlayerSpawn(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{	
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(iClient && IsClientInGame(iClient) && !g_bActive[iClient] && LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		SetEntProp(iClient, Prop_Send, "m_ArmorValue", g_iAGArmor);
		if(g_bAGHelmet)
		{
			SetEntProp(iClient, Prop_Send, "m_bHasHelmet", 1);
		}
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bActive[iClient] ? "AG_On" : "AG_Off", iClient, g_iAGArmor);
		hMenu.AddItem("Armor_Giver", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "AG_RankClosed", iClient, g_iAGArmor, g_iLevel);
		hMenu.AddItem("Armor_Giver", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Armor_Giver"))
	{
		g_bActive[iClient] = !g_bActive[iClient];
		LR_ShowMenu(iClient, LR_SettingMenu);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[2];
	GetClientCookie(iClient, g_hCookie, sCookie, sizeof(sCookie));
	g_bActive[iClient] = sCookie[0] == '1';
}

public void OnClientDisconnect(int iClient)
{
	char sCookie[2];
	sCookie[0] = '0' + view_as<char>(g_bActive[iClient]);
	SetClientCookie(iClient, g_hCookie, sCookie);
}

public void OnPluginEnd()
{
	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
		{
			OnClientDisconnect(iClient);
		}
	}
}