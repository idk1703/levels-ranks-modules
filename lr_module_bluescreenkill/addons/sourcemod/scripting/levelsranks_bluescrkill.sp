#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Blue Screen Kill"
#define PLUGIN_AUTHOR "RoadSide Romeo & R1KO"

int g_iLevel, g_iColor[4];
bool g_bActive[MAXPLAYERS+1];
Cookie g_hCookie;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};

public void OnPluginStart()
{
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	g_hCookie = new Cookie("LR_BlueScrKill", "LR_BlueScrKill", CookieAccess_Private);
	LoadTranslations("lr_module_bluescrkill.phrases");
	HookEvent("player_death", PlayerDeath);

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
	ConfigLoad();
	LR_Hook(LR_OnSettingsModuleUpdate, ConfigLoad);
	LR_MenuHook(LR_SettingMenu, LR_OnMenuCreated, LR_OnMenuItemSelected);
}

void ConfigLoad()
{
	static char sPath[PLATFORM_MAX_PATH];
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/bluescrkill.ini");
	KeyValues hLR = new KeyValues("LR_BlueScrKill");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iLevel = hLR.GetNum("rank", 0);
	hLR.GetColor4("color", g_iColor);

	hLR.Close();
}

public void PlayerDeath(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{	
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if(iAttacker && iClient != iAttacker && IsClientInGame(iAttacker) && g_bActive[iAttacker] && LR_GetClientInfo(iAttacker, ST_RANK) >= g_iLevel)
	{
		Handle hMessage = StartMessageOne("Fade", iAttacker);
		if(GetUserMessageType() == UM_Protobuf) 
		{
			Protobuf hProtobuf = UserMessageToProtobuf(hMessage);
			hProtobuf.SetInt("duration", 600);
			hProtobuf.SetInt("hold_time", 0);
			hProtobuf.SetInt("flags", 0x0001);
			hProtobuf.SetColor("clr", g_iColor);
		}
		else
		{
			BfWrite hMessageStack = UserMessageToBfWrite(hMessage);
			hMessageStack.WriteShort(600);
			hMessageStack.WriteShort(0);
			hMessageStack.WriteShort((0x0001));
			hMessageStack.WriteByte(g_iColor[0]);
			hMessageStack.WriteByte(g_iColor[1]);
			hMessageStack.WriteByte(g_iColor[2]);
			hMessageStack.WriteByte(g_iColor[3]);
		}
		EndMessage(); 
	}
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", !g_bActive[iClient] ? "BSK_On" : "BSK_Off", iClient);
		hMenu.AddItem("BlueScreenKill", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "BSK_RankClosed", iClient, g_iLevel);
		hMenu.AddItem("BlueScreenKill", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "BlueScreenKill"))
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