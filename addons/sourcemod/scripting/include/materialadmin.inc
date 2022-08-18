#if defined _materialadmin_included
#endinput
#endif
#define _materialadmin_included

public SharedPlugin __pl_materialadmin = 
{
	name = "materialadmin",
	file = "materialadmin.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_materialadmin_SetNTVOptional()
{
	MarkNativeAsOptional("MAOffBanPlayer");
	MarkNativeAsOptional("MABanPlayer");
	MarkNativeAsOptional("MAUnBanPlayer");
	MarkNativeAsOptional("MAGetAdminExpire");
	MarkNativeAsOptional("MASetClientMuteType");
	MarkNativeAsOptional("MAOffSetClientMuteType");
	MarkNativeAsOptional("MAGetClientMuteType");
	MarkNativeAsOptional("MAGetConfigSetting");
	MarkNativeAsOptional("MAGetDatabase");
	MarkNativeAsOptional("MALog");
}
#endif

#define MAPREFIX 		"[MA] "
#define MADEBUG 		0

#define MACOREVERSION 	"0.8.6"

// Git related code.
#if defined GIT_COMMIT_ABBREVIATEDHASH
  #define MAVERSION	MACOREVERSION ... "-" ... GIT_COMMIT_ABBREVIATEDHASH
#else
  #define MAVERSION MACOREVERSION
#endif

#if defined __MADEBUG
  #undef MADEBUG
  #define MADEBUG __MADEBUG
#endif

/*********************************************************
* Get database handle.
*********************************************************/
native Database MAGetDatabase();

#define MA_BAN_STEAM		1
#define MA_BAN_IP			2
/*********************************************************
* Add offline ban.
*
* @param iClient	Admin Client ID
* @param iType		Ban Type (MA_BAN_STEAM - Steam, MA_BAN_IP - IP)
* @param sSteamID	SteamID
* @param sIp		IP
* @param sName		Nickname
* @param iTime		Time (0 - permanent) in minutes
* @param sReason	Reason (can leave a blank (""))
* @return			true, false
*********************************************************/
native bool MAOffBanPlayer(int iClient, int iType, char[] sSteamID, char[] sIp, char[] sName, int iTime, char[] sReason);

/*********************************************************
* Add ban.
*
* @param iClient	Admin Client ID
* @param iTarget	Target Client ID
* @param iType		Ban Type (MA_BAN_STEAM - Steam, MA_BAN_IP - IP)
* @param iTime		Time (0 - permanent) in minutes
* @param sReason	Reason (can leave a blank (""))
* @return			true, false
*********************************************************/
native bool MABanPlayer(int iClient, int iTarget, int iType, int iTime, char[] sReason);

/*********************************************************
* Remove ban.
*
* @param iClient	Admin Client ID
* @param sId		IP or Steam (in old type (STEAM_X:Y:Z))
* @param sReason	Reason (can leave a blank (""))
* @return			true, false
*********************************************************/
native bool MAUnBanPlayer(int iClient, char[] sId, char[] sReason);

/*********************************************************
* Get time when admin expires.
*
* @param idAdmin	Admin ID.
* @return			Time in format UNIX TIMESTAMP
*********************************************************/
native int MAGetAdminExpire(AdminId idAdmin);

#define MA_GAG			5
#define MA_MUTE			6
#define MA_SILENCE		7
#define MA_UNGAG		8
#define MA_UNMUTE		9
#define MA_UNSILENCE	10
/*********************************************************
* Add Mute.
*
* @param iClient	Admin Client ID
* @param iTarget	Target Client ID
* @param sReason	Reason (can leave a blank (""))
* @param iType		Type (MA_GAG,MA_UNGAG - text chat, MA_MUTE,MA_UNMUTE - voice chat, MA_SILENCE,MA_UNSILENCE - text + voice chat)
* @param iTime		Time (0 - permanent) in minutes. When you take off mute, you can leave this empty (0).
* @return			true, false
*********************************************************/
native bool MASetClientMuteType(int iClient, int iTarget, char[] sReason, int iType, int iTime = 0);

/*********************************************************
* Add offline mute.
*
* @param iClient	Admin Client ID
* @param sSteamID	SteamID
* @param sIp		IP (can leave a blank ("") if you take off, but uses in logs)
* @param sName		Nickname (can leave a blank ("") if you take off, but uses in logs)
* @param sReason	Reason (can leave a blank (""))
* @param iType		Type (MA_GAG,MA_UNGAG - text chat, MA_MUTE,MA_UNMUTE - voice chat, MA_SILENCE,MA_UNSILENCE - text + voice chat)
* @param iTime		Time (0 - permanent) in minutes. When you take off mute, you can leave this empty (0).
* @return			true, false
*********************************************************/
native bool MAOffSetClientMuteType(int iClient, char[] sSteamID, char[] sIp, char[] sName, char[] sReason, int iType, int iTime = 0);

/*********************************************************
* Returns a mute type by Client ID
*
* @param iClient	Client ID.
* @return 			0 - None, 1 - Voice Chat, 2 - Text Chat, 3 - Voice + Text Chat
*********************************************************/
native int MAGetClientMuteType(int iClient);

/*********************************************************
* Event issuing mute when client connected.
* 
* @param iClient	Client ID.
* @param iType		Type (0 - None, 1 - Voice Chat, 2 - Text Chat, 3 - Voice + Text Chat)
* @param iTime		Time
* @param sReason	Reason
* @noreturn
*********************************************************/
forward void MAOnClientConnectGetMute(int iClient, int iType, int iTime, char[] sReason);

/*********************************************************
* Event issuing mute.
* 
* @param iClient	Admin Client ID.
* @param iTarget	Target Client ID. Can be 0, if offline.
* @param sIp		IP 
* @param sSteamID	SteamID
* @param sName		Nickname
* @param iType		Type (0 - None, 1 - Voice Chat, 2 - Text Chat, 3 - Voice + Text Chat)
* @param iTime		Time
* @param sReason	Reason 
* @noreturn
*********************************************************/
forward void MAOnClientMuted(int iClient, int iTarget, char[] sIp, char[] sSteamID, char[] sName, int iType, int iTime, char[] sReason);
 
/*********************************************************
* Event removing mute.
* 
* @param iClient	Admin Client ID.
* @param iTarget	Target Client ID. Can be 0, if offline.
* @param sIp		IP
* @param sSteamID	SteamID
* @param sName		Nickname
* @param iType		Type (0 - None, 1 - Voice Chat, 2 - Text Chat, 3 - Voice + Text Chat)
* @param iTime		Time
* @param sReason	Reason
* @noreturn
*********************************************************/
forward void MAOnClientUnMuted(int iClient, int iTarget, char[] sIp, char[] sSteamID, char[] sName, int iType, char[] sReason);

/*********************************************************
* Event issuing a ban.
* 
* @param iClient	Admin Client ID
* @param iTarget	Target Client ID. Can be 0, if offline.
* @param sIp		IP
* @param sSteamID	SteamID
* @param sName		Nickname
* @param iTime		Time
* @param sReason	Reason
* @noreturn
*********************************************************/
forward void MAOnClientBanned(int iClient, int iTarget, char[] sIp, char[] sSteamID, char[] sName, int iTime, char[] sReason);

/*********************************************************
* Event adding a ban.
* 
* @param iClient	Admin Client ID
* @param sIp		IP
* @param sSteamID	SteamID
* @param iTime		Time
* @param sReason	Reason
* @noreturn
*********************************************************/
forward void MAOnClientAddBanned(int iClient, char[] sIp, char[] sSteamID, int iTime, char[] sReason);

/*********************************************************
* Event removing a ban.
* 
* @param iClient	Admin Client ID
* @param sIp		IP
* @param sSteamID	Steam
* @param sReason	Reason
* @noreturn
*********************************************************/
forward void MAOnClientUnBanned(int iClient, char[] sIp, char[] sSteamID, char[] sReason);

/*********************************************************
* Event entering a banned client.
* @param  iClient	Client ID.
* @return Plugin_Changed To do nothing. >= Plugin_Handled Allows connect.
*********************************************************/
forward Action MAOnClientConnectBan(int iClient);
 
/*********************************************************
* Event connecting to Database.
* 
* @param db		DB
* @noreturn
*********************************************************/
forward void MAOnConnectDatabase(Database db);

/*********************************************************
* Get settings from config.
* Use only in event MAOnConfigSetting or after him.
* 
* @param sKey		Key name.
* @param sValue		Buffer to write a value. Recommended size for "big" values - 512.
* @return			true, false
*********************************************************/
native bool MAGetConfigSetting(char[] sKey, char[] sValue);
 
/*********************************************************
* Event reading config.
* @noreturn
*********************************************************/
forward void MAOnConfigSetting();

/*********************************************************
* Event full loading admins, groups or overrides in cache.
* AdminCache_Overrides	Global overrides 
* AdminCache_Groups		All groups (automatically invalidates admins too)
* AdminCache_Admins		All admins
* @noreturn
*********************************************************/
forward void MAOnFindLoadingAdmin(AdminCachePart acPart);
 
#define MA_LogAdmin			0
#define MA_LogConfig		1
#define MA_LogDateBase		2
#define MA_LogAction		3
/*********************************************************
* Log.
* @param iType		Type log
* @return			true, false
*********************************************************/
native bool MALog(int iType, const char[] sLog, any ...);
