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
#include <colors>
#include <sdktools>
#include <smac>
#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <materialadmin>
#include <sourcebanspp>
#define REQUIRE_PLUGIN

/* Plugin Info */
public Plugin myinfo =
{
	name		= "SourceMod Anti-Cheat",
	author		= SMAC_AUTHOR,
	description = "Open source anti-cheat plugin for SourceMod",
	version		= SMAC_VERSION,
	url			= SMAC_URL
};

/* Globals */
GameType
	g_Game = Game_Unknown;

ConVar
	g_hCvarVersion	   = null,
	g_hCvarWelcomeMsg  = null,
	g_hCvarBanDuration = null,
	g_hCvarLogVerbose  = null;

char
	g_sLogPath[PLATFORM_MAX_PATH];

bool
	g_bsourcebans	= false,
	g_bmaterialbans = false;

/* Plugin Functions */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// Detect game.
	char sGame[64];
	GetGameFolderName(sGame, sizeof(sGame));
	EngineVersion iEngine = GetEngineVersion();

	/*
		Notes: Removed GMOD support as SourceMod doesn't support Gmod anymore.

		Todo: Figure out which EngineVersion INSMod, FoF, HL2CTF, HIDDEN and ZPS use
		from https://sm.alliedmods.net/new-api/halflife/EngineVersion

		Those could be switched over too. Also, is cstrike_beta even still a thing?
	*/

	switch (iEngine)
	{
		case Engine_TF2:
			g_Game = Game_TF2;
		case Engine_CSS:
			g_Game = Game_CSS;
		case Engine_CSGO:
			g_Game = Game_CSGO;
		case Engine_DODS:
			g_Game = Game_DODS;
		case Engine_Left4Dead:
			g_Game = Game_L4D;
		case Engine_Left4Dead2:
			g_Game = Game_L4D2;
		case Engine_HL2DM:
			g_Game = Game_HL2DM;
		case Engine_NuclearDawn:
			g_Game = Game_ND;
		case Engine_Insurgency:
			g_Game = Game_INS;
		case Engine_BlackMesa:
			g_Game = Game_BM;
		case Engine_SDK2013:
		{
			if (StrEqual(sGame, "fof"))
				g_Game = Game_FOF;
			else if (StrEqual(sGame, "zps"))
				g_Game = Game_ZPS;
			else if (StrEqual(sGame, "zps"))
				g_Game = Game_ZMR;
			else
				g_Game = Game_Unknown;
		}
		case Engine_SourceSDK2006:
		{
			if (StrEqual(sGame, "hl2ctf"))
				g_Game = Game_HL2CTF;
			else if (StrEqual(sGame, "hidden"))
				g_Game = Game_HIDDEN;
			else
				g_Game = Game_Unknown;
		}
		case Engine_Unknown:
			g_Game = Game_Unknown;
		default:
			g_Game = Game_Unknown;
	}

	// Path used for logging.
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/SMAC.log");

	// Optional dependencies.
	MarkNativeAsOptional("SBPP_BanPlayer");

	API_Init();
	RegPluginLibrary("smac");

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("smac.phrases");

	// Convars.
	g_hCvarVersion = CreateConVar("smac_version", SMAC_VERSION, "SourceMod Anti-Cheat", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	OnVersionChanged(g_hCvarVersion, "", "");
	g_hCvarVersion.AddChangeHook(OnVersionChanged);

	g_hCvarWelcomeMsg  = CreateConVar("smac_welcomemsg", "0", "Display a message saying that your server is protected.", 0, true, 0.0, true, 1.0);
	g_hCvarBanDuration = CreateConVar("smac_ban_duration", "0", "The duration in minutes used for automatic bans. (0 = Permanent)", 0, true, 0.0);
	g_hCvarLogVerbose  = CreateConVar("smac_log_verbose", "0", "Include extra information about a client being logged.", 0, true, 0.0, true, 1.0);

	// Commands.
	RegAdminCmd("smac_status", Command_Status, ADMFLAG_GENERIC, "View the server's player status.");
}

public void OnAllPluginsLoaded()
{
	// Wait for other modules to create their convars.
	AutoExecConfig(true, "smac");

	g_bsourcebans	= LibraryExists("sourcebans++");
	g_bmaterialbans = LibraryExists("materialadmin");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "sourcebans++"))
		g_bsourcebans = false;
	else if (StrEqual(name, "materialadmin"))
		g_bmaterialbans = false;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "sourcebans++"))
		g_bsourcebans = true;
	else if (StrEqual(name, "materialadmin"))
		g_bmaterialbans = true;
}

public void OnVersionChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	if (!StrEqual(newValue, SMAC_VERSION))
		convar.SetString(SMAC_VERSION, false, false);
}

public void OnClientPutInServer(int client)
{
	if (g_hCvarWelcomeMsg.BoolValue)
		CreateTimer(10.0, Timer_WelcomeMsg, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_WelcomeMsg(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);

	if (IS_CLIENT(client) && IsClientInGame(client))
		CPrintToChat(client, "%t%t", "SMAC_Tag", "SMAC_WelcomeMsg");

	return Plugin_Stop;
}

public Action Command_Status(int client, int args)
{
	PrintToConsole(client, "%s  %-40s %s", "UserID", "AuthID", "Name");

	char sAuthID[MAX_AUTHID_LENGTH];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i))
			continue;

		if (!GetClientAuthId(i, AuthId_Steam2, sAuthID, sizeof(sAuthID), true))
		{
			if (GetClientAuthId(i, AuthId_Steam2, sAuthID, sizeof(sAuthID), false))
				Format(sAuthID, sizeof(sAuthID), "%s (Not Validated)", sAuthID);
			else
				strcopy(sAuthID, sizeof(sAuthID), "Unknown");
		}

		PrintToConsole(client, "%6d  %-40s %N", GetClientUserId(i), sAuthID, i);
	}

	return Plugin_Handled;
}

/* API - Natives & Forwards */

GlobalForward g_OnCheatDetected;

void   API_Init()
{
	CreateNative("SMAC_GetGameType", Native_GetGameType);
	CreateNative("SMAC_Log", Native_Log);
	CreateNative("SMAC_LogAction", Native_LogAction);
	CreateNative("SMAC_Ban", Native_Ban);
	CreateNative("SMAC_PrintAdminNotice", Native_PrintAdminNotice);
	CreateNative("SMAC_CreateConVar", Native_CreateConVar);
	CreateNative("SMAC_CheatDetected", Native_CheatDetected);

	g_OnCheatDetected = CreateGlobalForward("SMAC_OnCheatDetected", ET_Event, Param_Cell, Param_String, Param_Cell, Param_Cell);
}

// native GameType SMAC_GetGameType();
public any Native_GetGameType(Handle plugin, int numParams)
{
	return view_as<GameType>(g_Game);
}

// native void SMAC_Log(const char[] format, any ...);
public any Native_Log(Handle plugin, int numParams)
{
	char sFilename[64], sBuffer[256];
	GetPluginBasename(plugin, sFilename, sizeof(sFilename));
	FormatNativeString(0, 1, 2, sizeof(sBuffer), _, sBuffer);
	LogToFileEx(g_sLogPath, "[%s] %s", sFilename, sBuffer);
	return 0;
}

// native void SMAC_LogAction(int client, const char[] format, any ...);
public any Native_LogAction(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IS_CLIENT(client) || !IsClientConnected(client))
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);

	char sAuthID[MAX_AUTHID_LENGTH];
	if (!GetClientAuthId(client, AuthId_Steam2, sAuthID, sizeof(sAuthID), true))
	{
		if (GetClientAuthId(client, AuthId_Steam2, sAuthID, sizeof(sAuthID), false))
			Format(sAuthID, sizeof(sAuthID), "%s (Not Validated)", sAuthID);
		else
			strcopy(sAuthID, sizeof(sAuthID), "Unknown");
	}

	char sIP[17];
	if (!GetClientIP(client, sIP, sizeof(sIP)))
	{
		strcopy(sIP, sizeof(sIP), "Unknown");
	}

	char sVersion[16], sFilename[64], sBuffer[512];
	GetPluginInfo(plugin, PlInfo_Version, sVersion, sizeof(sVersion));
	GetPluginBasename(plugin, sFilename, sizeof(sFilename));
	FormatNativeString(0, 2, 3, sizeof(sBuffer), _, sBuffer);

	// Verbose client logging.
	if (GetConVarBool(g_hCvarLogVerbose) && IsClientInGame(client))
	{
		char  sMap[MAX_MAPNAME_LENGTH], sWeapon[32];
		float vOrigin[3], vAngles[3];
		int	  iTeam, iLatency;

		GetCurrentMap(sMap, sizeof(sMap));
		GetClientAbsOrigin(client, vOrigin);
		GetClientEyeAngles(client, vAngles);
		GetClientWeapon(client, sWeapon, sizeof(sWeapon));
		iTeam	 = GetClientTeam(client);
		iLatency = RoundToNearest(GetClientAvgLatency(client, NetFlow_Outgoing) * 1000.0);

		LogToFileEx(g_sLogPath, "[%s | %s] %N (ID: %s | IP: %s) %s\n\tMap: %s | Origin: %.0f %.0f %.0f | Angles: %.0f %.0f %.0f | Weapon: %s | Team: %i | Latency: %ims",
					sFilename, sVersion, client, sAuthID, sIP, sBuffer, sMap, vOrigin[0], vOrigin[1], vOrigin[2], vAngles[0], vAngles[1], vAngles[2], sWeapon, iTeam, iLatency);
	}
	else
		LogToFileEx(g_sLogPath, "[%s | %s] %N (ID: %s | IP: %s) %s", sFilename, sVersion, client, sAuthID, sIP, sBuffer);

	return 0;
}

// native void SMAC_Ban(int client, const char[] reason, any ...);
public any Native_Ban(Handle plugin, int numParams)
{
	char sVersion[16], sReason[256];
	int	 client	  = GetNativeCell(1);
	int	 duration = g_hCvarBanDuration.IntValue;

	GetPluginInfo(plugin, PlInfo_Version, sVersion, sizeof(sVersion));
	FormatNativeString(0, 2, 3, sizeof(sReason), _, sReason);
	Format(sReason, sizeof(sReason), "SMAC %s: %s", sVersion, sReason);

	if (g_bsourcebans)
		SBPP_BanPlayer(0, client, duration, sReason);
	else if (g_bmaterialbans)
		MABanPlayer(0, client, MA_BAN_STEAM, duration, sReason);
	else
	{
		char sKickMsg[256];
		FormatEx(sKickMsg, sizeof(sKickMsg), "%T", "SMAC_Banned", client);
		BanClient(client, duration, BANFLAG_AUTO, sReason, sKickMsg, "SMAC");
	}

	if (IsClientConnected(client))
		KickClient(client, sReason);

	return 0;
}

// native void SMAC_PrintAdminNotice(const char[] format, any ...);
public any Native_PrintAdminNotice(Handle plugin, int numParams)
{
	char sBuffer[192];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && CheckCommandAccess(i, "smac_admin_notices", ADMFLAG_GENERIC, true))
		{
			SetGlobalTransTarget(i);
			FormatNativeString(0, 1, 2, sizeof(sBuffer), _, sBuffer);
			CPrintToChat(i, "%t %s", "SMAC_Tag", sBuffer);
		}
	}
	return 0;
}

// native ConVar SMAC_CreateConVar(const char[] name, const char[] defaultValue, const char[] description="",int flags = 0, bool hasMin = false, float min = 0.0, bool hasMax = false, float max = 0.0);
public any Native_CreateConVar(Handle plugin, int numParams)
{
	char name[64], defaultValue[16], description[192];
	GetNativeString(1, name, sizeof(name));
	GetNativeString(2, defaultValue, sizeof(defaultValue));
	GetNativeString(3, description, sizeof(description));

	int	  flags	 = GetNativeCell(4);
	bool  hasMin = view_as<bool>(GetNativeCell(5));
	float min	 = view_as<float>(GetNativeCell(6));
	bool  hasMax = view_as<bool>(GetNativeCell(7));
	float max	 = view_as<float>(GetNativeCell(8));

	char  sFilename[64];
	GetPluginBasename(plugin, sFilename, sizeof(sFilename));
	Format(description, sizeof(description), "[%s] %s", sFilename, description);

	return CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);
}

// native Action SMAC_CheatDetected(int client, DetectionType type = Detection_Unknown, Handle info = INVALID_HANDLE);
public int Native_CheatDetected(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IS_CLIENT(client) || !IsClientConnected(client))
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);

	// Block duplicate detections.
	if (IsClientInKickQueue(client))
		return view_as<int>(Plugin_Handled);

	char sFilename[64];
	GetPluginBasename(plugin, sFilename, sizeof(sFilename));

	DetectionType type = Detection_Unknown;
	Handle		  info = INVALID_HANDLE;

	if (numParams == 3)
	{
		// caller is using newer cheat detected native
		type = view_as<DetectionType>(GetNativeCell(2));
		info = view_as<Handle>(GetNativeCell(3));
	}

	// forward Action SMAC_OnCheatDetected(int client, const char[] module, DetectionType type, Handle info);
	Action result = Plugin_Continue;
	Call_StartForward(g_OnCheatDetected);
	Call_PushCell(client);
	Call_PushString(sFilename);
	Call_PushCell(type);
	Call_PushCell(info);
	Call_Finish(result);

	return view_as<int>(result);
}
