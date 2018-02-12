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

int                     g_iSelectedRanksTypes[MAXPLAYERS + 1];
CompetitiveGORank       g_iSelectedRanks[MAXPLAYERS + 1];
Handle                  g_hForwards[ForwardTypeEnum];
int                     g_iCompetitiveRankTypeOffset;
int                     g_iCompetitiveRankOffset;
int                     g_iPlayerManagerEntity;
bool                    g_bWorking;

/******************************************************************************
 * Plugin Information
 ******************************************************************************/
public Plugin myinfo = {
    description = "Provides API for changing player ranks",
    version     = "1.2.0.1",
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

    CreateNative("IsCompetitiveRankWorking",        Native_IsWorking);
    CreateNative("SetPlayerCompetitiveRank",        Native_SetRank);
    CreateNative("GetPlayerCompetitiveRank",        Native_GetRank);
    CreateNative("SetPlayerCompetitiveRankType",    Native_SetRankType);
    CreateNative("GetPlayerCompetitiveRankType",    Native_GetRankType);

    g_hForwards[PreForward]     = CreateGlobalForward("OnPreChangePlayerCompetitiveRank",   ET_Hook,    Param_Cell, Param_CellByRef);
    g_hForwards[PostForward]    = CreateGlobalForward("OnPostChangePlayerCompetitiveRank",  ET_Ignore,  Param_Cell, Param_Cell);

    RegPluginLibrary("csgoranks");

    return APLRes_Success;
}

public void OnPluginStart() {
    HookEvent("announce_phase_end", view_as<EventHook>(OnAnnouncePhaseEnd));
}

public void OnMapStart() {
    g_iCompetitiveRankTypeOffset    = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRankType");
    g_iCompetitiveRankOffset        = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking");
    g_iPlayerManagerEntity          = FindEntityByClassname(MaxClients + 1, "cs_player_manager");

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

    UTIL_SetRank(iClient, iRank);
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

public int Native_SetRankType(Handle hPlugin, int iParams) {
    if (!UTIL_IsWorking()) {
        BlameAPIError("Plugin can't work on this map!");
    }

    int iClient = GetNativeCell(1);
    if (iClient < 1 || iClient > MaxClients) {
        BlameAPIError("Invalid Client entity ID (%d)", iClient);
    }

    CompetitiveGORankType iRankType = GetNativeCell(2);
    if (!UTIL_IsValidCompetitiveRankType(iRankType)) {
        BlameAPIError("Invalid Rank Type ID (%d)", iRankType);
    }

    UTIL_SetRankType(iClient, iRankType);
    return 1;
}

public int Native_GetRankType(Handle hPlugin, int iParams) {
    if (!UTIL_IsWorking()) {
        BlameAPIError("Plugin can't work on this map!");
    }

    int iClient = GetNativeCell(1);
    if (iClient < 1 || iClient > MaxClients) {
        BlameAPIError("Invalid Client entity ID (%d)", iClient);
    }

    return view_as<int>(UTIL_GetRankType(iClient));
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

    CompetitiveGORankType eRankType = UTIL_GetRankType(iClient);
    if (bFirePreForward && !FireAPIEvent(PreForward, iClient, eRank, eRankType)) {
        return;
    }

    g_iSelectedRanks[iClient] = eRank;
    FireAPIEvent(PostForward, iClient, eRank, eRankType);
}

void UTIL_SetRankType(int iClient, CompetitiveGORankType eRankType, bool bFirePreForward = true) {
    if (!UTIL_IsValidCompetitiveRankType(eRankType)) {
        return;
    }

    CompetitiveGORank eRank = UTIL_GetRank(iClient);
    if (bFirePreForward && !FireAPIEvent(PreForward, iClient, eRank, eRankType)) {
        return;
    }

    g_iSelectedRanksTypes[iClient] = UTIL_CompetitiveGORankTypeToInteger(eRankType);
    FireAPIEvent(PostForward, iClient, eRank, eRankType);
}

CompetitiveGORank UTIL_GetRank(int iClient) {
    return g_iSelectedRanks[iClient];
}

CompetitiveGORankType UTIL_GetRankType(int iClient) {
    return UTIL_IntegerToCompetitiveGORankType(g_iSelectedRanksTypes[iClient]);
}

bool UTIL_IsValidCompetitiveRank(CompetitiveGORank eRank) {
    return (eRank >= NoRank && eRank <= GlobalElite);
}

bool UTIL_IsValidCompetitiveRankType(CompetitiveGORankType eRankType) {
    return (eRankType >= Default && eRankType <= Partners);
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

int UTIL_CompetitiveGORankTypeToInteger(CompetitiveGORankType eRankType) {
    int iRes = -1;
    switch (eRankType) {
        case Default:   iRes = 0;
        case Partners:  iRes = 7;
    }

    return iRes;
}

CompetitiveGORankType UTIL_IntegerToCompetitiveGORankType(int iRankType) {
    CompetitiveGORankType eRes = view_as<CompetitiveGORankType>(-1);
    switch (iRankType) {
        case 0: eRes = Default;
        case 7: eRes = Partners;
    }

    return eRes;
}

/******************************************************************************
 * Hooks
 ******************************************************************************/
public void OnThinkPost(int iCompetitiveRankEntity) {
    SetEntDataArray(iCompetitiveRankEntity, g_iCompetitiveRankOffset, view_as<int>(g_iSelectedRanks), MaxClients + 1);
    SetEntDataArray(iCompetitiveRankEntity, g_iCompetitiveRankTypeOffset, g_iSelectedRanksTypes, MaxClients + 1);
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
bool FireAPIEvent(ForwardTypeEnum eForwardType, int iClient, CompetitiveGORank &eRank, CompetitiveGORankType &eRankType) {
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
    (eForwardType == PreForward) ?
        Call_PushCellRef(eRankType) :
        Call_PushCell(eRankType);

    Call_Finish(eResult);

    if (eForwardType == PreForward && !UTIL_IsValidCompetitiveRank(eRank)) {
        BlameGenericError("Received invalid Competitive Rank from forward. Received: %d", eRank);
        return false;   // unreachable code.
    } else if (eForwardType == PreForward && !UTIL_IsValidCompetitiveRankType(eRankType)) {
        BlameGenericError("Received invalid Competitive Rank Type from forward. Received: %d", eRankType);
        return false;   // unreachable code too.
    }

    return (eResult != Plugin_Stop);
}