#include <sourcemod>
#include <sdktools>
#include <lvl_ranks>
#include <clientprefs>

#define PLUGIN_NAME "[LR] Module - Grenades"

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "fuckOff1703",
	description = "...",
	version = "1.0.1",
	url = "@fuck_off1703"
};

Cookie g_hCookie;
bool g_bActive[MAXPLAYERS + 1], g_bCSGO;
char g_sPluginTitle[64];

enum
{
	HE = 0,
	FB,
	SG,
	MT,
	DC
};

static const char g_sGrenadesName[][] = 
{
	"weapon_hegrenade",
	"weapon_flashbang",
	"weapon_smokegrenade",
	"weapon_molotov",
	"weapon_decoy"
};

int g_iGrenadeType[5], g_iGrenadesCount[5][MAXPLAYERS + 1];

public void OnPluginStart()
{
	LoadTranslations("lr_module_grenades.phrases");
	g_hCookie = new Cookie("LR_Grenades", "LR_Grenades", CookieAccess_Private);
	
	if((g_bCSGO = (GetEngineVersion() == Engine_CSGO)))
	{
		g_iGrenadeType[HE] = 14;
		g_iGrenadeType[FB] = 15;
		g_iGrenadeType[SG] = 16;
		g_iGrenadeType[MT] = 17;
		g_iGrenadeType[DC] = 18;
	}
	else
	{
		g_iGrenadeType[HE] = 11;
		g_iGrenadeType[FB] = 12;
		g_iGrenadeType[SG] = 13;
		g_iGrenadeType[MT] = -1;
		g_iGrenadeType[DC] = -1;
	}

	HookEvent("player_spawn", OnPlayerSpawn);

	if(LR_IsLoaded()) LR_OnCoreIsReady();
	
	for(int iClient = 1; iClient <= MaxClients; iClient++) if(IsClientInGame(iClient)) OnClientCookiesCached(iClient);
}

public void LR_OnCoreIsReady()
{
	if (LR_GetSettingsValue(LR_TypeStatistics)) SetFailState(PLUGIN_NAME ... " : This module will work if [ lr_type_statistics 0 ]");
	
	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
	LR_GetTitleMenu(g_sPluginTitle, sizeof(g_sPluginTitle));
	ConfigLoad();
}

void ConfigLoad()
{
	int ilvl;
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/grenades.ini");
	KeyValues hLR = new KeyValues("LR_Grenades");

	if(!hLR.ImportFromFile(sPath)) SetFailState(PLUGIN_NAME..." : File is not found (%s)", sPath);

	if(hLR.JumpToKey("Settings") && hLR.GotoFirstSubKey())
	{
		do
		{
			g_iGrenadesCount[HE][ilvl] = hLR.GetNum("he");
			g_iGrenadesCount[FB][ilvl] = hLR.GetNum("flash");
			g_iGrenadesCount[SG][ilvl] = hLR.GetNum("smoke");
			g_iGrenadesCount[MT][ilvl] = hLR.GetNum("molotov");
			g_iGrenadesCount[DC][ilvl] = hLR.GetNum("decoy");
			ilvl++;
		}
		while(hLR.GotoNextKey());

		if(ilvl != LR_GetRankExp().Length) SetFailState(PLUGIN_NAME ... " : The number of ranks does not match the specified number in the core (%s)", sPath);
	}
	else SetFailState(PLUGIN_NAME ... " : Section Settings is not found (%s)", sPath);
	
	hLR.Close();
}

public void OnPlayerSpawn(Event hEvent, char[] sName, bool bDontBroadcast)
{	
	int iClient = GetClientOfUserId(hEvent.GetInt("userid")), iRank = LR_GetClientInfo(iClient, ST_RANK), iTeam = GetClientTeam(iClient);
	if(iClient && IsClientInGame(iClient) && iTeam > 1 && g_bActive[iClient] && iRank)
	{
		for(int i = 0; i < 5; i++)
		{
			if(g_iGrenadesCount[i][iRank - 1] > 0 && g_iGrenadeType[i] > 0)
			{
				GivePlayerItem(iClient, (i == MT && iTeam == 3) ? "weapon_incgrenade" : g_sGrenadesName[i]);
				SetEntProp(iClient, Prop_Send, "m_iAmmo", g_iGrenadesCount[i][iRank - 1], 4, g_iGrenadeType[i]);
			}
		}
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	int iRank = LR_GetClientInfo(iClient, ST_RANK), i;
	while(g_iGrenadesCount[HE][i] <= 0 && g_iGrenadesCount[FB][i] <= 0 && g_iGrenadesCount[SG][i] <= 0 && g_iGrenadesCount[MT][i] <= 0 && g_iGrenadesCount[DC][i] <= 0) i++;

	if (iRank >= i)
	{
		FormatEx(sText, sizeof(sText), "%T", "Grenades", iClient);
		hMenu.AddItem("Grenades", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "Grenades_RankClosed", iClient, i + 1);
		hMenu.AddItem("Grenades", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "Grenades")) GrenadesMenu(iClient);
}

void GrenadesMenu(int iClient)
{
	char sText[128];
	Menu hMenu = new Menu(GrenadesMenuHandler);
	hMenu.SetTitle("%s | %T\n ", g_sPluginTitle, "Grenades", iClient);

	int iRank = LR_GetClientInfo(iClient, ST_RANK);

	FormatEx(sText, sizeof(sText), "%T\n ", g_bActive[iClient] ? "Grenades_ON" : "Grenades_OFF", iClient); 
	hMenu.AddItem("Grenades", sText);

	FormatEx(sText, sizeof(sText), "%T", "Grenades_HE", iClient, g_iGrenadesCount[HE][iRank - 1]);
	hMenu.AddItem("Grenades", sText, ITEMDRAW_DISABLED);

	FormatEx(sText, sizeof(sText), "%T", "Grenades_FB", iClient, g_iGrenadesCount[FB][iRank - 1]); 
	hMenu.AddItem("Grenades", sText, ITEMDRAW_DISABLED);

	FormatEx(sText, sizeof(sText), "%T", "Grenades_SG", iClient, g_iGrenadesCount[SG][iRank - 1]); 
	hMenu.AddItem("Grenades", sText, ITEMDRAW_DISABLED);
	
	if (g_bCSGO)
	{
		FormatEx(sText, sizeof(sText), "%T", "Grenades_MT", iClient, g_iGrenadesCount[MT][iRank - 1]); 
		hMenu.AddItem("Grenades", sText, ITEMDRAW_DISABLED);

		FormatEx(sText, sizeof(sText), "%T", "Grenades_DC", iClient, g_iGrenadesCount[DC][iRank - 1]); 
		hMenu.AddItem("Grenades", sText, ITEMDRAW_DISABLED);
	}
	
	hMenu.ExitBackButton = true;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int GrenadesMenuHandler(Menu hMenu, MenuAction mAction, int iClient, int iSlot) 
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel: if(iSlot == MenuCancel_ExitBack) LR_ShowMenu(iClient, LR_SettingMenu);
		case MenuAction_Select:
		{
			g_bActive[iClient] = !g_bActive[iClient];

			char sCookie[2];
			sCookie[0] = '0' + view_as<char>(g_bActive[iClient]);
			g_hCookie.Set(iClient, sCookie);

			GrenadesMenu(iClient);
		}
	}

	return 0;
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