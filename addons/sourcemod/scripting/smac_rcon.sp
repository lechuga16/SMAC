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

/* Plugin Info */
public Plugin myinfo =
{
	name        = "SMAC Rcon Locker",
	author      = SMAC_AUTHOR,
	description = "Protects against rcon crashes and exploits",
	version     = SMAC_VERSION,
	url         = SMAC_URL
};

/* Globals */
ConVar
	g_hCvarRconPass = null;
char
	g_sRconRealPass[128];
bool
	g_bRconLocked = false;

/* Plugin Functions */
public void OnPluginStart()
{
	// Convars.
	g_hCvarRconPass = FindConVar("rcon_password");
	HookConVarChange(g_hCvarRconPass, OnRconPassChanged);
}

public void OnConfigsExecuted()
{
	if (!g_bRconLocked)
	{
		GetConVarString(g_hCvarRconPass, g_sRconRealPass, sizeof(g_sRconRealPass));
		g_bRconLocked = true;
	}
}

public void OnRconPassChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	if (g_bRconLocked && !StrEqual(newValue, g_sRconRealPass))
	{
		SMAC_Log("Rcon password changed to \"%s\". Reverting back to original config value.", newValue);
		SetConVarString(g_hCvarRconPass, g_sRconRealPass);
	}
}