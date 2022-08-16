#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <lvl_ranks>

#define PLUGIN_NAME "[LR] Module - Electro Effect"
#define PLUGIN_AUTHOR "RoadSide Romeo & R1KO"

int g_iLevel;
bool g_bActive[MAXPLAYERS+1];
Cookie g_hCookie;

public Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, version = PLUGIN_VERSION};
public void OnPluginStart()
{
	if(LR_IsLoaded())
	{
		LR_OnCoreIsReady();
	}

	g_hCookie = new Cookie("LR_ElectroEffect", "LR_ElectroEffect", CookieAccess_Private);
	LoadTranslations("lr_module_electroeffect.phrases");
	HookEvent("player_death", PlayerDeath);
	HookEvent("bullet_impact", BulletImpact);

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
	if(!sPath[0]) BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/electroeffect.ini");
	KeyValues hLR = new KeyValues("LR_ElectroEffect");

	if(!hLR.ImportFromFile(sPath))
		SetFailState(PLUGIN_NAME ... " : File is not found (%s)", sPath);

	g_iLevel = hLR.GetNum("rank", 0);

	hLR.Close();
}

public void PlayerDeath(Event hEvent, char[] sEvName, bool bDontBroadcast)
{
	int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker")), iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if(iAttacker && iClient && iAttacker != iClient && IsClientInGame(iAttacker) && IsClientInGame(iClient) && g_bActive[iAttacker] && (LR_GetClientInfo(iAttacker, ST_RANK) >= g_iLevel))
	{
		float fPos[3];
		GetClientAbsOrigin(iClient, fPos);
		MakeTeslaEffect(fPos);
	}
}

public void BulletImpact(Event hEvent, char[] sEvName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if(iClient && IsClientInGame(iClient) && g_bActive[iClient] && (LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel))
	{
		float fPos[3];
		fPos[0] = hEvent.GetFloat("x");
		fPos[1] = hEvent.GetFloat("y");
		fPos[2] = hEvent.GetFloat("z");
		MakeTeslaSplashEffect(fPos);
	}
}

void MakeTeslaSplashEffect(float fPos[3]) 
{
	float fEndPos[3];
	fEndPos[0] = fPos[0] + 20.0;
	fEndPos[1] = fPos[1] + 20.0;
	fEndPos[2] = fPos[2] + 20.0;
	TE_SetupEnergySplash(fPos, fEndPos, true);
	TE_SendToAll();
}

void MakeTeslaEffect(const float fPos[3]) 
{
	int iEntity = CreateEntityByName("point_tesla");
	DispatchKeyValue(iEntity, "beamcount_min", "5"); 
	DispatchKeyValue(iEntity, "beamcount_max", "10");
	DispatchKeyValue(iEntity, "lifetime_min", "0.2");
	DispatchKeyValue(iEntity, "lifetime_max", "0.5");
	DispatchKeyValue(iEntity, "m_flRadius", "100.0");
	DispatchKeyValue(iEntity, "m_SoundName", "DoSpark");
	DispatchKeyValue(iEntity, "texture", "sprites/physbeam.vmt");
	DispatchKeyValue(iEntity, "m_Color", "255 255 255");
	DispatchKeyValue(iEntity, "thick_min", "1.0");  
	DispatchKeyValue(iEntity, "thick_max", "10.0");
	DispatchKeyValue(iEntity, "interval_min", "0.1"); 
	DispatchKeyValue(iEntity, "interval_max", "0.2"); 

	DispatchSpawn(iEntity);
	TeleportEntity(iEntity, fPos);
	AcceptEntityInput(iEntity, "TurnOn"); 
	AcceptEntityInput(iEntity, "DoSpark");

	SetVariantString("OnUser1 !self:kill::2.0:-1");
	AcceptEntityInput(iEntity, "AddOutput"); 
	AcceptEntityInput(iEntity, "FireUser1");
}

void LR_OnMenuCreated(LR_MenuType OnMenuType, int iClient, Menu hMenu)
{
	char sText[64];
	if(LR_GetClientInfo(iClient, ST_RANK) >= g_iLevel)
	{
		FormatEx(sText, sizeof(sText), "%T", g_bActive[iClient] ? "EE_On" : "EE_Off", iClient);
		hMenu.AddItem("ElectroEffect", sText);
	}
	else
	{
		FormatEx(sText, sizeof(sText), "%T", "EE_RankClosed", iClient, g_iLevel);
		hMenu.AddItem("ElectroEffect", sText, ITEMDRAW_DISABLED);
	}
}

void LR_OnMenuItemSelected(LR_MenuType OnMenuType, int iClient, const char[] sInfo)
{
	if(!strcmp(sInfo, "ElectroEffect"))
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