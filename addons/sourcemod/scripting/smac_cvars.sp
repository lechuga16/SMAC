/*
	SourceMod Anti-Cheat
	Copyright (C) 2011-2016 SMAC Development Team
	Copyright (C) 2007-2011 CodingDirect LLC

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#pragma semicolon 1
#pragma newdecls required

/* SM Includes */
#include <sourcemod>
#include <smac>
#include <smac_cvars>
#include <colors>

#undef REQUIRE_PLUGIN
#include <basecomm>
#define REQUIRE_PLUGIN

/* Plugin Info */
public Plugin myinfo =
{
	name		= "SMAC ConVar Checker",
	author		= SMAC_AUTHOR,
	description = "Checks for players using exploitative cvars",
	version		= SMAC_VERSION,
	url			= SMAC_URL
};

/* Globals */
#define CVAR_REPLICATION_DELAY	30

#define TIME_REQUERY_FIRST		20.0
#define TIME_REQUERY_SUBSEQUENT 10.0

#define MAX_REQUERY_ATTEMPTS	4

#define CVARS_DIR				"data/SMAC"

// cvar data
StringMap
	g_smTrie,
	g_smCurDataTrie[MAXPLAYERS + 1];

ArrayList
	g_arrADT;

int
	g_iADTSize;

// client data
Handle
	g_hTimer[MAXPLAYERS + 1];

int
	g_iRequeryCount[MAXPLAYERS + 1],
	g_iADTIndex[MAXPLAYERS + 1] = { -1, ... };

// plugin state
bool
	g_bPluginStarted;

EngineVersion
	g_Engine;

ConVar
	sv_cheats,
	g_cvarOnlyKick;

/* Plugin Functions */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_Engine	= GetEngineVersion();
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("smac.phrases");

	g_smTrie = CreateTrie();
	g_arrADT = CreateArray();

	if (!CheckDirectory(CVARS_DIR))
		SMAC_Log("Failed to create directory \"%s\"", CVARS_DIR);

	GameType
		gameType = SMAC_GetGameType();

	char
		sPatchFile[64];

	BuildPath(Path_SM, sPatchFile, sizeof(sPatchFile), "%s/%s.cvar.cfg", CVARS_DIR, sGameType[gameType]);

	KeyValues
		kvCvars = new KeyValues("Cvars");

	if (!kvCvars.ImportFromFile(sPatchFile))
	{
		delete kvCvars;
		SetFailState("Failed to import file \"%s\"", sPatchFile);
	}

	if (!kvCvars.GotoFirstSubKey())
	{
		delete kvCvars;
		SMAC_Log("No cvars found in \"%s\"", sPatchFile);
	}

	do
	{
		char
			sName[64],
			sValue[8],
			sValue2[8];

		CvarOrder
			COrder;

		CvarComp
			CCompType;

		CvarAction
			CAction;

		kvCvars.GetSectionName(sName, sizeof(sName));
		COrder	  = view_as<CvarOrder>(kvCvars.GetNum("CvarOrder"));
		CCompType = view_as<CvarComp>(kvCvars.GetNum("CvarComp"));
		CAction	  = view_as<CvarAction>(kvCvars.GetNum("CvarAction"));
		kvCvars.GetString("Value", sValue, sizeof(sValue));
		kvCvars.GetString("Value2", sValue2, sizeof(sValue2));

		if (!AddCvar(COrder, sName, CCompType, CAction, sValue, sValue2))
			SMAC_Log("Failed to add cvar \"%s\"", sName);
	}
	while (kvCvars.GotoNextKey());
	delete kvCvars;

	g_cvarOnlyKick = CreateConVar("smac_cvar_onlykick", "0", "Only kick players for cvar violations", _, true, 0.0, true, 1.0);
	sv_cheats = FindConVar("sv_cheats");
	sv_cheats.AddChangeHook(OnCheatsChanged);

	// Commands.
	RegAdminCmd("smac_addcvar", Command_AddCvar, ADMFLAG_ROOT, "Add cvar to checking.");
	RegAdminCmd("smac_removecvar", Command_RemCvar, ADMFLAG_ROOT, "Remove cvar from checking.");
	RegAdminCmd("smac_listcvars", Command_ListCvars, ADMFLAG_GENERIC, "List cvars being checked.");

	// scramble ordering.
	if (g_iADTSize)
		ScrambleCvars();

	g_bPluginStarted = true;
}

void OnCheatsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(oldValue) == 1 && StringToInt(newValue) == 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsClientAuthorized(i))
				OnClientPostAdminCheck(i);
		}
		CPrintToChatAll("%t %t", "SMAC_Tag", "SMAC_CheatDisabled");
	}
	else if (StringToInt(oldValue) == 0 && StringToInt(newValue) == 1)
		CPrintToChatAll("%t %t", "SMAC_Tag", "SMAC_CheatEnabled");
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsFakeClient(client) && !sv_cheats.IntValue)
		SetTimer(g_hTimer[client], CreateTimer(0.1, Timer_QueryNextCvar, client, TIMER_REPEAT));
}

public void OnClientDisconnect(int client)
{
	if (!IsFakeClient(client))
	{
		g_smCurDataTrie[client] = null;
		g_iADTIndex[client]		= -1;
		g_iRequeryCount[client] = 0;
		SetTimer(g_hTimer[client]);
	}
}

public Action Command_AddCvar(int client, int args)
{
	if (args >= 3 && args <= 5)
	{
		char sCvar[MAX_CVAR_NAME_LEN];
		GetCmdArg(1, sCvar, sizeof(sCvar));

		if (!IsValidConVarName(sCvar))
		{
			CReplyToCommand(client, "%t %t", "SMAC_Tag", "SMAC_ConVarNameInvalid", sCvar);
			return Plugin_Handled;
		}

		char sCompType[16], sAction[16];

		GetCmdArg(2, sCompType, sizeof(sCompType));
		GetCmdArg(3, sAction, sizeof(sAction));

		char sValue[MAX_CVAR_VALUE_LEN], sValue2[MAX_CVAR_VALUE_LEN];

		if (args >= 4)
			GetCmdArg(4, sValue, sizeof(sValue));

		if (args >= 5)
			GetCmdArg(5, sValue2, sizeof(sValue2));

		if (AddCvar(Order_Last, sCvar, GetCompTypeInt(sCompType), GetCActionInt(sAction), sValue, sValue2))
		{
			CReplyToCommand(client, "%t %t", "SMAC_Tag", "SMAC_CvarAdded", sCvar);
			return Plugin_Handled;
		}
	}

	CReplyToCommand(client, "%t %t: smac_addcvar <cvar> <comptype> <action> <value> <value2>", "SMAC_Tag", "SMAC_Usage");
	return Plugin_Handled;
}

public Action Command_ListCvars(int client, int args)
{
	StringMapSnapshot
		snapshot = g_smTrie.Snapshot();

	if (snapshot.Length == 0)
	{
		CReplyToCommand(client, "%t %t", "SMAC_Tag", "SMAC_NoConVar");
		return Plugin_Handled;
	}

	if (client != 0 && SM_REPLY_TO_CHAT == GetCmdReplySource())
		CPrintToChat(client, "%t %t", "SMAC_Tag", "SMAC_PrintConsole");

	PrintToConsole(client, "***********[SMAC %d CVARS]***********", snapshot.Length);
	for (int i = 0; i <= (snapshot.Length - 1); i++)
	{
		int iSize	   = snapshot.KeyBufferSize(i);
		char[] sBuffer = new char[iSize];
		snapshot.GetKey(i, sBuffer, iSize);
		PrintToConsole(client, "Name[%d]: %s", (i + 1), sBuffer);
	}
	PrintToConsole(client, "*************************************", snapshot.Length);

	delete snapshot;
	return Plugin_Handled;
}

bool AddCvar(CvarOrder COrder, char[] sCvar, CvarComp CCompType, CvarAction CAction, const char[] sValue = "", const char[] sValue2 = "")
{
	if (CCompType == Comp_Invalid || CAction == Action_Invalid)
		return false;

	// Trie is case sensitive.
	StringToLower(sCvar);

	char
		sNewValue[MAX_CVAR_VALUE_LEN];

	ConVar
		convar;

	if (CCompType == Comp_Replicated)
	{
		convar = FindConVar(sCvar);

		if (convar == null || !(GetConVarFlags(convar) & FCVAR_REPLICATED))
			return false;

		convar.GetString(sNewValue, sizeof(sNewValue));
	}
	else
		strcopy(sNewValue, sizeof(sNewValue), sValue);

	StringMap
		smDataTrie;

	if (g_smTrie.GetValue(sCvar, smDataTrie))
	{
		// smDataTrie.SetValue(Cvar_Order, COrder);
		smDataTrie.SetString(Cvar_Name, sCvar);
		smDataTrie.SetValue(Cvar_CompType, CCompType);
		smDataTrie.SetValue(Cvar_Action, CAction);
		smDataTrie.SetString(Cvar_Value, sNewValue);
		smDataTrie.SetString(Cvar_Value2, sValue2);
		// smDataTrie.SetValue(Cvar_ReplicatedTime, 0);
	}
	else
	{
		// Setup cvar data
		smDataTrie = CreateTrie();

		smDataTrie.SetValue(Cvar_Order, COrder);
		smDataTrie.SetString(Cvar_Name, sCvar);
		smDataTrie.SetValue(Cvar_CompType, CCompType);
		smDataTrie.SetValue(Cvar_Action, CAction);
		smDataTrie.SetString(Cvar_Value, sNewValue);
		smDataTrie.SetString(Cvar_Value2, sValue2);
		smDataTrie.SetValue(Cvar_ReplicatedTime, 0);

		// Add cvar to lists
		g_smTrie.SetValue(sCvar, smDataTrie);
		g_arrADT.Push(smDataTrie);
		g_iADTSize = GetArraySize(g_arrADT);

		// Begin replication
		if (CCompType == Comp_Replicated)
		{
			convar.AddChangeHook(OnConVarChanged);
			if (g_Engine == Engine_SourceSDK2006 || g_Engine == Engine_Original || g_Engine == Engine_DarkMessiah)
				ReplicateToAll(convar, sNewValue);
		}

		// Scramble
		if (g_bPluginStarted)
			ScrambleCvars();
	}

	return true;
}

public Action Command_RemCvar(int client, int args)
{
	if (args == 1)
	{
		char sCvar[MAX_CVAR_NAME_LEN];
		GetCmdArg(1, sCvar, sizeof(sCvar));

		if (RemCvar(sCvar))
			CReplyToCommand(client, "%t %t", "SMAC_Tag", "SMAC_ConVarRemoved", sCvar);
		else
			CReplyToCommand(client, "%t %t", "SMAC_Tag", "SMAC_ConVarNotFound", sCvar);

		return Plugin_Handled;
	}

	CReplyToCommand(client, "%t %t: smac_removecvar <cvar>", "SMAC_Tag", "SMAC_Usage");
	return Plugin_Handled;
}

bool RemCvar(char[] sCvar)
{
	StringMap
		smDataTrie;

	// Trie is case sensitive.
	StringToLower(sCvar);

	// Are you listed?
	if (!g_smTrie.GetValue(sCvar, smDataTrie))
		return false;

	// Invalidate active queries.
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_smCurDataTrie[i] == smDataTrie)
			g_smCurDataTrie[i] = null;
	}

	// Disable replication
	CvarComp
		SCCompType;
	smDataTrie.GetValue(Cvar_CompType, SCCompType);

	if (SCCompType == Comp_Replicated)
		FindConVar(sCvar).RemoveChangeHook(OnConVarChanged);

	// Remove relevant entries
	g_smTrie.Remove(sCvar);
	g_arrADT.Erase(g_arrADT.FindValue(smDataTrie));
	g_iADTSize = GetArraySize(g_arrADT);
	delete smDataTrie;

	return true;
}

public Action Timer_QueryNextCvar(Handle timer, any client)
{
	if (!IsClientInGame(client) || sv_cheats.IntValue)
	{
		g_hTimer[client] = null;
		return Plugin_Stop;
	}

	// No cvars in the list
	if (!g_iADTSize)
		return Plugin_Continue;

	// Get next cvar
	if (++g_iADTIndex[client] >= g_iADTSize)
		g_iADTIndex[client] = 0;

	StringMap
		smDataTrie = g_arrADT.Get(g_iADTIndex[client]);

	if (IsReplicating(smDataTrie))
		return Plugin_Continue;

	// Attempt to query it
	char sCvar[MAX_CVAR_NAME_LEN];
	smDataTrie.GetString(Cvar_Name, sCvar, sizeof(sCvar));

	if (QueryClientConVar(client, sCvar, OnConVarQueryFinished, GetClientSerial(client)) == QUERYCOOKIE_FAILED)
		return Plugin_Continue;

	// Success!
	g_smCurDataTrie[client] = smDataTrie;
	g_hTimer[client]		= CreateTimer(TIME_REQUERY_FIRST, Timer_RequeryCvar, client);
	return Plugin_Stop;
}

public Action Timer_RequeryCvar(Handle timer, any client)
{
	if (!IsClientInGame(client) || sv_cheats.IntValue)
	{
		g_hTimer[client] = null;
		return Plugin_Stop;
	}

	// Have we had enough?
	if (++g_iRequeryCount[client] > MAX_REQUERY_ATTEMPTS)
	{
		g_hTimer[client] = null;
		KickClient(client, "%t", "SMAC_FailedToReply");
		return Plugin_Stop;
	}

	// Did the query get invalidated?
	if (g_smCurDataTrie[client] != null && !IsReplicating(g_smCurDataTrie[client]))
	{
		char
			sCvar[MAX_CVAR_NAME_LEN];
		g_smCurDataTrie[client].GetString(Cvar_Name, sCvar, sizeof(sCvar));

		if (QueryClientConVar(client, sCvar, OnConVarQueryFinished, GetClientSerial(client)) != QUERYCOOKIE_FAILED)
		{
			g_hTimer[client] = CreateTimer(TIME_REQUERY_SUBSEQUENT, Timer_RequeryCvar, client);
			return Plugin_Stop;
		}
	}

	g_hTimer[client] = CreateTimer(0.1, Timer_QueryNextCvar, client, TIMER_REPEAT);
	return Plugin_Stop;
}

public void OnConVarQueryFinished(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any serial)
{
	if (GetClientFromSerial(serial) != client)
		return;

	// Trie is case sensitive.
	char
		sCvar[MAX_CVAR_NAME_LEN];

	StringMap
		smDataTrie;

	strcopy(sCvar, sizeof(sCvar), cvarName);
	StringToLower(sCvar);

	// Did we expect this query?
	if (!g_smTrie.GetValue(sCvar, smDataTrie) || smDataTrie != g_smCurDataTrie[client])
		return;

	// Prepare the next query.
	g_smCurDataTrie[client] = null;
	g_iRequeryCount[client] = 0;
	SetTimer(g_hTimer[client], CreateTimer(0.1, Timer_QueryNextCvar, client, TIMER_REPEAT));

	// Initialize data
	CvarComp
		SCCompType;

	char
		sValue[MAX_CVAR_VALUE_LEN],
		sValue2[MAX_CVAR_VALUE_LEN],
		sKickMessage[255];

	smDataTrie.GetValue(Cvar_CompType, SCCompType);
	smDataTrie.GetString(Cvar_Value, sValue, sizeof(sValue));
	smDataTrie.GetString(Cvar_Value2, sValue2, sizeof(sValue2));

	// Check query results
	if (result == ConVarQuery_Okay)
	{
		if (IsReplicating(smDataTrie))
			return;

		switch (SCCompType)
		{
			case Comp_Equal:
			{
				if (StringToFloat(cvarValue) == StringToFloat(sValue))
					return;

				FormatEx(sKickMessage, sizeof(sKickMessage), "%T", "SMAC_ShouldEqual", client, sCvar, sValue, cvarValue);
			}
			case Comp_StrEqual, Comp_Replicated:
			{
				if (StrEqual(cvarValue, sValue))
					return;

				FormatEx(sKickMessage, sizeof(sKickMessage), "%T", "SMAC_ShouldEqual", client, sCvar, sValue, cvarValue);
			}
			case Comp_Greater:
			{
				if (StringToFloat(cvarValue) >= StringToFloat(sValue))
					return;

				FormatEx(sKickMessage, sizeof(sKickMessage), "%T", "SMAC_ShouldBeGreater", client, sCvar, sValue, cvarValue);
			}
			case Comp_Less:
			{
				if (StringToFloat(cvarValue) <= StringToFloat(sValue))
					return;

				FormatEx(sKickMessage, sizeof(sKickMessage), "%T", "SMAC_ShouldBeLess", client, sCvar, sValue, cvarValue);
			}
			case Comp_Between:
			{
				if (StringToFloat(cvarValue) >= StringToFloat(sValue) && StringToFloat(cvarValue) <= StringToFloat(sValue2))
					return;

				FormatEx(sKickMessage, sizeof(sKickMessage), "%T", "SMAC_ShouldBeBetween", client, sCvar, sValue, sValue2, cvarValue);
			}
			case Comp_Outside:
			{
				if (StringToFloat(cvarValue) < StringToFloat(sValue) || StringToFloat(cvarValue) > StringToFloat(sValue2))
					return;

				FormatEx(sKickMessage, sizeof(sKickMessage), "%T", "SMAC_ShouldBeOutside", client, sCvar, sValue, sValue2, cvarValue);
			}
			default:
				FormatEx(sKickMessage, sizeof(sKickMessage), "ConVar %s violation", sCvar);
		}
	}
	else if (SCCompType == Comp_NonExist)
	{
		if (result == ConVarQuery_NotFound)
			return;

		FormatEx(sKickMessage, sizeof(sKickMessage), "ConVar %s violation", sCvar);
	}

	// The client failed relevant checks.
	CvarAction
		CAction;

	smDataTrie.GetValue(Cvar_Action, CAction);
	KeyValues kvInfo = CreateKeyValues("");

	kvInfo.SetString("cvar", sCvar);
	kvInfo.SetNum("comptype", view_as<int>(SCCompType));
	kvInfo.SetNum("actiontype", view_as<int>(CAction));
	kvInfo.SetString("cvarvalue", cvarValue);
	kvInfo.SetString("value", sValue);
	kvInfo.SetString("value2", sValue2);
	kvInfo.SetString("kickmessage", sKickMessage);
	kvInfo.SetNum("client", client);

	if (SMAC_CheatDetected(client, Detection_CvarViolation, kvInfo) == Plugin_Continue)
	{
		SMAC_PrintAdminNotice("%t", "SMAC_CvarViolation", client, sCvar);

		char sResult[16], sCompType[16];
		GetQueryResultString(result, sResult, sizeof(sResult));
		GetCompTypeString(SCCompType, sCompType, sizeof(sCompType));

		switch (CAction)
		{
			case Action_Mute:
			{
				if (!BaseComm_IsClientMuted(client))
				{
					CPrintToChatAll("%t %t", "SMAC_Tag", "SMAC_Muted", client);
					BaseComm_SetClientMute(client, true);
				}
			}
			case Action_Kick:
			{
				SMAC_LogAction(client, "was kicked for failing checks on convar \"%s\". result \"%s\" | CompType: \"%s\" | cvarValue \"%s\" | value: \"%s\" | value2: \"%s\"", sCvar, sResult, sCompType, cvarValue, sValue, sValue2);
				KickClient(client, "\n%s", sKickMessage);
			}
			case Action_Ban:
			{
				if (g_cvarOnlyKick.BoolValue)
				{
					SMAC_LogAction(client, "was kicked for failing checks on convar \"%s\". result \"%s\" | CompType: \"%s\" | cvarValue \"%s\" | value: \"%s\" | value2: \"%s\"", sCvar, sResult, sCompType, cvarValue, sValue, sValue2);
					KickClient(client, "\n%s", sKickMessage);
				}
				else
				{
					SMAC_LogAction(client, "was banned for failing checks on convar \"%s\". result \"%s\" | CompType: \"%s\" | cvarValue \"%s\" | value: \"%s\" | value2: \"%s\"", sCvar, sResult, sCompType, cvarValue, sValue, sValue2);
					SMAC_Ban(client, "ConVar %s violation", sCvar);
				}
			}
		}
	}

	delete kvInfo;
}

public void OnConVarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	char
		sCvar[MAX_CVAR_NAME_LEN];

	StringMap
		smDataTrie;

	convar.GetName(sCvar, sizeof(sCvar));
	StringToLower(sCvar);

	if (!g_smTrie.GetValue(sCvar, smDataTrie))
		return;

	smDataTrie.SetString(Cvar_Value, newValue);
	smDataTrie.SetValue(Cvar_ReplicatedTime, GetTime() + CVAR_REPLICATION_DELAY);

	if (g_Engine == Engine_SourceSDK2006 || g_Engine == Engine_Original || g_Engine == Engine_DarkMessiah)
		ReplicateToAll(convar, newValue);
}

/**
 * Scrambles the Cvars in the game.
 * This function rearranges the Cvars stored in the g_arrADT array in a random order.
 * It uses a StringMap data structure to store the Cvars based on their order.
 * The function first retrieves the order of each Cvar from the smDataTrie map and stores them in hCvarADTs array.
 * Then, it clears the g_arrADT array and populates it with the Cvars in a random order.
 */
void ScrambleCvars()
{
	StringMap[][] hCvarADTs = new StringMap[view_as<int>(Order_MAX)][g_iADTSize];

	StringMap
		smDataTrie;

	int
		iOrder,
		iADTIndex[view_as<int>(Order_MAX)];

	for (int i = 0; i < g_iADTSize; i++)
	{
		smDataTrie = g_arrADT.Get(i);
		smDataTrie.GetValue(Cvar_Order, iOrder);

		hCvarADTs[iOrder][iADTIndex[iOrder]++] = smDataTrie;
	}

	g_arrADT.Clear();

	for (int i = 0; i < view_as<int>(Order_MAX); i++)
	{
		if (iADTIndex[i] > 0)
		{
			SortIntegers(view_as<int>(hCvarADTs[i]), iADTIndex[i], Sort_Random);

			for (int j = 0; j < iADTIndex[i]; j++)
			{
				PushArrayCell(g_arrADT, hCvarADTs[i][j]);
			}
		}
	}
}

/**
 * Checks if the given `smDataTrie` is replicating.
 *
 * @param smDataTrie The `StringMap` containing the data trie.
 * @return `true` if the `smDataTrie` is replicating, `false` otherwise.
 */
bool IsReplicating(StringMap smDataTrie)
{
	int iReplicatedTime;
	smDataTrie.GetValue(Cvar_ReplicatedTime, iReplicatedTime);

	return (iReplicatedTime > GetTime());
}