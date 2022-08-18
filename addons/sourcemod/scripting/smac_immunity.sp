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
#include <smac>
#include <sourcemod>

/* Globals */
#define INMUNITY_VERSION "1.0.1"

ConVar
	g_hiplayer = null,
	g_hstv     = null;

/* Plugin Info */
public Plugin myinfo =
{
	name        = "SMAC Immunity",
	author      = "GoD-Tony",
	description = "Grants immunity from SMAC to players",
	version     = INMUNITY_VERSION,
	url         = "https://github.com/Silenci0/SMAC"
};

public void OnPluginStart()
{
	// Convars.
	CreateConVar("smac_immunity", INMUNITY_VERSION, "SourceMod Anti-Cheat Immunity", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_hstv     = CreateConVar("smac_immunity_sourcetv", "1", "Grant immunity to SourceTV for SMAC.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hiplayer = CreateConVar("smac_immunity_player", "0", "Grant immunity to players for SMAC.", FCVAR_NONE, true, 0.0, true, 1.0);
	AutoExecConfig(true, "smac_immunity");
}

public Action SMAC_OnCheatDetected(int client, const char[] module)
{
	// ADMFLAG_CUSTOM1 = the "o" flag, see SM flags here for more info: https://wiki.alliedmods.net/Adding_Admins_(SourceMod)
	if (g_hiplayer.BoolValue && CheckCommandAccess(client, "smac_immunity", ADMFLAG_CUSTOM1, true))
	{
		return Plugin_Handled;
	}
	if (g_hstv.BoolValue && IsClientSourceTV(client))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}