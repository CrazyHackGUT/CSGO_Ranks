#include <sourcemod>
#include <functions>
#include <csgoranks>
#include <sdkhooks>
#include <sdktools>

#pragma newdecls  required
#pragma semicolon 1

#define BlameError(%0)      return ThrowNativeError(SP_ERROR_NATIVE, %0)

CompetitiveGORank   g_iSelectedRanks[MAXPLAYERS + 1];
int                 g_iCompetitiveRankOffset;
int                 g_iPlayerManagerEntity;
bool                g_bWorking;

/******************************************************************************
 * Plugin Information
 ******************************************************************************/
public Plugin myinfo = {
    description = "Provides API for changing player ranks",
    version     = "1.0.0.0",
    author      = "CrazyHackGUT aka Kruzya",
    name        = "[CSGO] Competitive Ranks API",
    url         = "https://kruzefag.ru/"
};

/******************************************************************************
 * Generic Events
 ******************************************************************************/
public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] szError, int iMaxLength) {
    if (GetEngineVersion() != Engine_CSGO) {
        strcopy(szError, iMaxLength, "Plugin works only in CS:GO!");
        return APLRes_Failure;
    }

    CreateNative("IsCompetitiveRankWorking", Native_IsWorking);
    CreateNative("SetPlayerCompetitiveRank", Native_SetRank);
    CreateNative("GetPlayerCompetitiveRank", Native_GetRank);
    RegPluginLibrary("csgoranks");

    return APLRes_Success;
}

public void OnMapStart() {
    g_iCompetitiveRankOffset = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking");
    g_iPlayerManagerEntity = FindEntityByClassname(MaxClients + 1, "cs_player_manager");

    if (g_iPlayerManagerEntity != -1) {
        g_bWorking = SDKHookEx(g_iPlayerManagerEntity, SDKHook_ThinkPost, OnThinkPost);
    }
}

public void OnMapEnd() {
    if (g_iPlayerManagerEntity != -1) {
        SDKUnhook(g_iPlayerManagerEntity, SDKHook_ThinkPost, OnThinkPost);
        g_bWorking = false;
    }
}

public bool OnClientConnect(int iClient, char[] szRejectMsg, int iMaxRejectMsgLength) {
    UTIL_SetRank(iClient, NoRank);
    return true;
}

/******************************************************************************
 * Natives
 ******************************************************************************/
public int Native_IsWorking(Handle hPlugin, int iParams) {
    return UTIL_IsWorking();
}

public int Native_SetRank(Handle hPlugin, int iParams) {
    if (!UTIL_IsWorking()) {
        BlameError("Plugin can't work on this map!");
    }

    int iClient = GetNativeCell(1);
    if (iClient < 1 || iClient > MaxClients) {
        BlameError("Invalid Client entity ID (%d)", iClient);
    }

    CompetitiveGORank iRank = GetNativeCell(2);
    if (iRank < NoRank || iRank > GlobalElite) {
        BlameError("Invalid Rank ID (%d)", iRank);
    }

    g_iSelectedRanks[iClient] = iRank;
    return 1;
}

public int Native_GetRank(Handle hPlugin, int iParams) {
    if (!UTIL_IsWorking()) {
        BlameError("Plugin can't work on this map!");
    }

    int iClient = GetNativeCell(1);
    if (iClient < 1 || iClient > MaxClients) {
        BlameError("Invalid Client entity ID (%d)", iClient);
    }

    return view_as<int>(UTIL_GetRank(iClient));
}

/******************************************************************************
 * UTILs
 ******************************************************************************/
bool UTIL_IsWorking() {
    return (g_iCompetitiveRankOffset != -1) && g_bWorking;
}

void UTIL_SetRank(int iClient, CompetitiveGORank eRank) {
    if (eRank < NoRank || eRank > GlobalElite) {
        return;
    }

    g_iSelectedRanks[iClient] = eRank;
}

CompetitiveGORank UTIL_GetRank(int iClient) {
    return g_iSelectedRanks[iClient];
}

/******************************************************************************
 * Hooks
 ******************************************************************************/
public void OnThinkPost(int iCompetitiveRankEntity) {
	SetEntDataArray(iCompetitiveRankEntity, g_iCompetitiveRankOffset, view_as<int>(g_iSelectedRanks), MaxClients + 1);
}