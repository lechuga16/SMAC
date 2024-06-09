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

#if defined _smac_included
	#endinput
#endif
#define _smac_included

#include <smac_stocks>

/* Globals */
#define SMAC_VERSION   "0.8.7.3"
#define SMAC_URL	   "https://github.com/lechuga16/SMAC"
#define SMAC_AUTHOR	   "SMAC Development Team, lechuga"
#define SMAC_MOD_ERROR "This module will not work for this mod and should be removed."

enum GameType
{
	Game_Unknown = 0,
	Game_CSS	 = 1,
	Game_TF2	 = 2,
	Game_DODS	 = 3,
	Game_INS	 = 4,
	Game_L4D	 = 5,
	Game_L4D2	 = 6,
	Game_HL2DM	 = 7,
	Game_FOF	 = 8,
	Game_HL2CTF	 = 9,
	Game_HIDDEN	 = 10,
	Game_ND		 = 11,
	Game_CSGO	 = 12,
	Game_ZPS	 = 13,
	Game_ZMR	 = 14,
	Game_BM		 = 15,

	Game_Size	 = 16
};

stock char sGameType[][Game_Size] = {
	"unknown",
	"css",
	"tf2",
	"dods",
	"ins",
	"l4d",
	"l4d2",
	"hl2dm",
	"fof",
	"hl2ctf",
	"hidden",
	"nd",
	"csgo",
	"zps",
	"zmr",
	"bm"
};

enum DetectionType
{
	Detection_Unknown		  = 0,

	// smac_aimbot
	Detection_Aimbot		  = 100,

	// smac_autotrigger
	Detection_AutoTrigger	  = 200,

	// smac_client
	Detection_NameChangeSpam  = 300,

	// smac_commands
	Detection_CommandSpamming = 400,
	Detection_BannedCommand,

	// smac_cvars
	Detection_CvarViolation = 500,

	// smac_eyetest
	Detection_UserCmdReuse	= 600,
	Detection_UserCmdTamperingTickcount,
	Detection_UserCmdTamperingButtons,
	Detection_Eyeangles,

	// smac_speedhack
	Detection_Speedhack			= 700,

	// smac_spinhack
	Detection_Spinhack			= 800,

	// smac_eac_banlist
	Detection_GlobalBanned_EAC	= 900,

	// smac_esea_banlist
	Detection_GlobalBanned_ESEA = 1000,

	// smac_hl2dm_fixes
	Detection_GravityGunExploit = 1100,
};

/**
 * Retrieves the supported game type for the SMAC (SourceMod Anti-Cheat) plugin.
 *
 * @return The game type for the SMAC plugin.
 */
native GameType SMAC_GetGameType();

/**
 * Logs a message using the SMAC (SourceMod Anti-Cheat) system.
 *
 * @param format The format string for the log message.
 * @param ... Additional arguments to be formatted into the log message.
 */
native void	SMAC_Log(const char[] format, any...);

/**
 * Logs an action performed by a client.
 *
 * @param client The client index.
 * @param format The format string for the log message.
 * @param ... Additional arguments to be formatted into the log message.
 */
native void	SMAC_LogAction(int client, const char[] format, any...);

/**
 * Ban a client from the server using the supported ban system (Sourcemod, Materialbans, Local Bans).
 *
 * @param client The client index to ban.
 * @param reason The reason for the ban.
 * @param ... Additional arguments for the ban command.
 */
native void	SMAC_Ban(int client, const char[] reason, any...);

/**
 * Prints an admin notice using the specified format string and arguments.
 *
 * @param format The format string for the notice.
 * @param ... The arguments to be formatted and printed.
 */
native void	SMAC_PrintAdminNotice(const char[] format, any...);

/**
 * Creates a console variable with the specified name, default value, and optional description.
 *
 * @param name The name of the console variable.
 * @param defaultValue The default value of the console variable.
 * @param description (Optional) The description of the console variable.
 * @param flags (Optional) Additional flags for the console variable.
 * @param hasMin (Optional) Specifies whether the console variable has a minimum value.
 * @param min (Optional) The minimum value of the console variable.
 * @param hasMax (Optional) Specifies whether the console variable has a maximum value.
 * @param max (Optional) The maximum value of the console variable.
 * @return The created console variable.
 */
native ConVar SMAC_CreateConVar(const char[] name, const char[] defaultValue, const char[] description = "", int flags = 0, bool hasMin = false, float min = 0.0, bool hasMax = false, float max = 0.0);

/**
 * Detects and handles cheat detection for a client.
 *
 * @param client The client index.
 * @param type The type of cheat detection. Defaults to Detection_Unknown.
 * @param info Additional information about the cheat detection. Defaults to INVALID_HANDLE.
 * @return Action The action taken for the cheat detection.
 */
native Action SMAC_CheatDetected(int client, DetectionType type = Detection_Unknown, Handle info = INVALID_HANDLE);

/**
 * Called when a cheat is detected.
 *
 * @param client The client index of the player who triggered the cheat detection.
 * @param module The name of the cheat module that was detected.
 * @param type The type of cheat detection that occurred.
 * @param info A handle to additional information about the cheat detection.
 */
forward Action SMAC_OnCheatDetected(int client, const char[] module, DetectionType type, Handle info);

public SharedPlugin __pl_smac = {
	name = "smac",
	file = "smac.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN

public void __pl_smac_SetNTVOptional()
{
	MarkNativeAsOptional("SMAC_GetGameType");
	MarkNativeAsOptional("SMAC_Log");
	MarkNativeAsOptional("SMAC_LogAction");
	MarkNativeAsOptional("SMAC_Ban");
	MarkNativeAsOptional("SMAC_PrintAdminNotice");
	MarkNativeAsOptional("SMAC_CreateConVar");
	MarkNativeAsOptional("SMAC_CheatDetected");
}
#endif
