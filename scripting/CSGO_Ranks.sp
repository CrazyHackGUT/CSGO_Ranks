#include <sourcemod>
#include <functions>
#include <csgoranks>
#include <sdkhooks>
#include <sdktools>

#pragma newdecls  required
#pragma semicolon 1

#define BlameAPIError(%0)       return ThrowNativeError(SP_ERROR_NATIVE, %0)
#define BlameGenericError(%0)   ThrowError(%0)

enum ForwardTypeEnum {
    Handle:PreForward,
    Handle:PostForward
}

// stock const char          gc_usermsg_ranks[]            = "ServerRankRevealAll";
stock char          gc_usermsg_ranks[]                  = "ServerRankRevealAll";    // bad-bad-bad

CompetitiveGORank   g_iSelectedRanks[MAXPLAYERS + 1];
Handle              g_hForwards[ForwardTypeEnum];
int                 g_iCompetitiveRankOffset;
int                 g_iPlayerManagerEntity;
bool                g_bWorking;

/******************************************************************************
 * Plugin Information
 ******************************************************************************/
public Plugin myinfo = {
    description = "Provides API for changing player ranks",
    version     = "1.1.0.0",
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

    g_hForwards[PreForward]     = CreateGlobalForward("OnPreChangePlayerCompetitiveRank",   ET_Hook,    Param_Cell, Param_CellByRef);
    g_hForwards[PostForward]    = CreateGlobalForward("OnPostChangePlayerCompetitiveRank",  ET_Ignore,  Param_Cell, Param_Cell);

    RegPluginLibrary("csgoranks");

    return APLRes_Success;
}

public void OnPluginStart() {
    HookEvent("announce_phase_end", view_as<EventHook>(OnAnnouncePhaseEnd));
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
    UTIL_SetRank(iClient, NoRank, false);
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
        BlameAPIError("Plugin can't work on this map!");
    }

    int iClient = GetNativeCell(1);
    if (iClient < 1 || iClient > MaxClients) {
        BlameAPIError("Invalid Client entity ID (%d)", iClient);
    }

    CompetitiveGORank iRank = GetNativeCell(2);
    if (!UTIL_IsValidCompetitiveRank(iRank)) {
        BlameAPIError("Invalid Rank ID (%d)", iRank);
    }

    g_iSelectedRanks[iClient] = iRank;
    return 1;
}

public int Native_GetRank(Handle hPlugin, int iParams) {
    if (!UTIL_IsWorking()) {
        BlameAPIError("Plugin can't work on this map!");
    }

    int iClient = GetNativeCell(1);
    if (iClient < 1 || iClient > MaxClients) {
        BlameAPIError("Invalid Client entity ID (%d)", iClient);
    }

    return view_as<int>(UTIL_GetRank(iClient));
}

/******************************************************************************
 * UTILs
 ******************************************************************************/
bool UTIL_IsWorking() {
    return (g_iCompetitiveRankOffset != -1) && g_bWorking;
}

void UTIL_SetRank(int iClient, CompetitiveGORank eRank, bool bFirePreForward = true) {
    if (!UTIL_IsValidCompetitiveRank(eRank)) {
        return;
    }

    if (bFirePreForward && !FireAPIEvent(PreForward, iClient, eRank)) {
        return;
    }

    g_iSelectedRanks[iClient] = eRank;
    FireAPIEvent(PostForward, iClient, eRank);
}

CompetitiveGORank UTIL_GetRank(int iClient) {
    return g_iSelectedRanks[iClient];
}

bool UTIL_IsValidCompetitiveRank(CompetitiveGORank eRank) {
    return (eRank >= NoRank && eRank <= GlobalElite);
}

void UTIL_UpdateScoreTable(int iClient = 0) {
    // Handle hBuffer = ((iClient == 0) ? StartMessageAll(gc_usermsg_ranks) : StartMessageOne(gc_usermsg_ranks, iClient));
    Handle hBuffer;
    if (iClient == 0) {
        hBuffer = StartMessageAll(gc_usermsg_ranks);
    } else {
        hBuffer = StartMessageOne(gc_usermsg_ranks, iClient);
    }

    if (hBuffer != null) {
        EndMessage();
    }
}

/******************************************************************************
 * Hooks
 ******************************************************************************/
public void OnThinkPost(int iCompetitiveRankEntity) {
	SetEntDataArray(iCompetitiveRankEntity, g_iCompetitiveRankOffset, view_as<int>(g_iSelectedRanks), MaxClients + 1);
}

public Action OnPlayerRunCmd(int iClient, int &iButtons) {
    if ((iButtons & IN_SCORE) && !(GetEntProp(iClient, Prop_Data, "m_nOldButtons") & IN_SCORE)) {
        UTIL_UpdateScoreTable(iClient);
    }
}

public void OnAnnouncePhaseEnd() {
    UTIL_UpdateScoreTable();
}

/******************************************************************************
 * Forwards
 ******************************************************************************/
bool FireAPIEvent(ForwardTypeEnum eForwardType, int iClient, CompetitiveGORank &eRank) {
    Handle hForward = g_hForwards[eForwardType];
    if (GetForwardFunctionCount(hForward) == 0) {
        return false;
    }

    Action eResult;

    Call_StartForward(hForward);
    Call_PushCell(iClient);
    (eForwardType == PreForward) ?
        Call_PushCellRef(eRank) :
        Call_PushCell(eRank);

    Call_Finish(eResult);

    if (eForwardType == PreForward && !UTIL_IsValidCompetitiveRank(eRank)) {
        BlameGenericError("Received invalid Competitive Rank from forward. Received: %d");
        return false;   // unreachable code.
    }

    return (eResult != Plugin_Stop);
}