#include <amxmodx>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#define PLUGIN "Map Manager"
#define VERSION "2.5.60"
#define AUTHOR "Mistrick"

#pragma semicolon 1

///******** Settings ********///

#define FUNCTION_NEXTMAP //replace default nextmap
#define FUNCTION_RTV
#define FUNCTION_NOMINATION
//#define FUNCTION_NIGHTMODE
#define FUNCTION_NIGHTMODE_BLOCK_CMDS
#define FUNCTION_BLOCK_MAPS
#define FUNCTION_SOUND

#define SELECT_MAPS 5
#define PRE_START_TIME 5
#define VOTE_TIME 10

#define NOMINATED_MAPS_IN_VOTE 3
#define NOMINATED_MAPS_PER_PLAYER 3

#define BLOCK_MAP_COUNT 5

#define MIN_DENOMINATE_TIME 3

new const PREFIX[] = "^4[MapManager]";

///**************************///

#if BLOCK_MAP_COUNT <= 1
	#undef FUNCTION_BLOCK_MAPS
#endif

enum (+=100)
{
	TASK_CHECKTIME = 100,
	TASK_SHOWTIMER,
	TASK_TIMER,
	TASK_VOTEMENU,
	TASK_CHANGETODEFAULT,
	TASK_CHECKNIGHT
};

enum _:MAP_INFO
{
	m_MapName[32],
	m_MinPlayers,
	m_MaxPlayers,
	m_BlockCount
};
enum _:VOTEMENU_INFO
{
	v_MapName[32],
	v_MapIndex,
	v_Votes
};
enum _:NOMINATEDMAP_INFO
{
	n_MapName[32],
	n_Player,
	n_MapIndex
};
enum _:BLOCKEDMAP_INFO
{
	b_MapName[32],
	b_Count
};

new Array: g_aMaps;

enum _:CVARS
{
	CHANGE_TYPE,
	START_VOTE_BEFORE_END,
	SHOW_RESULT_TYPE,
	SHOW_SELECTS,
	START_VOTE_IN_NEW_ROUND,
	FREEZE_IN_VOTE,
	BLACK_SCREEN_IN_VOTE,
	LAST_ROUND,
	CHANGE_TO_DEDAULT,
	DEFAULT_MAP,
	EXTENDED_TYPE,
	EXTENDED_MAX,
	EXTENDED_TIME,
	EXTENDED_ROUNDS,
#if defined FUNCTION_RTV
	ROCK_MODE,
	ROCK_PERCENT,
	ROCK_PLAYERS,
	ROCK_CHANGE_TYPE,
	ROCK_DELAY,
#endif
#if defined FUNCTION_NOMINATION
	NOMINATION_DONT_CLOSE_MENU,
	NOMINATION_DEL_NON_CUR_ONLINE,
#endif
#if defined FUNCTION_NIGHTMODE
	NIGHTMODE_TIME,
#endif
	MAXROUNDS,
	WINLIMIT,
	TIMELIMIT,
	FREEZETIME,
	CHATTIME,
	NEXTMAP,
	ROUNDTIME
};

new const FILE_MAPS[] = "maps.ini";//configdir

#if defined FUNCTION_BLOCK_MAPS
new const FILE_BLOCKEDMAPS[] = "blockedmaps.ini";//datadir
#endif

#if defined FUNCTION_NIGHTMODE
new const FILE_NIGHTMAPS[] = "nightmaps.ini";//configdir
#endif

new g_pCvars[CVARS];
new g_iTeamScore[2];
new g_szCurrentMap[32];
new g_bVoteStarted;
new g_bVoteFinished;
new g_bNotUnlimitTime;

new g_eMenuItems[SELECT_MAPS + 1][VOTEMENU_INFO];
new g_iMenuItemsCount;
new g_iTotalVotes;
new g_iTimer;
new g_bPlayerVoted[33];
new g_iExtendedMax;
new g_bExtendMap;
new g_bStartVote;
new g_bChangedFreezeTime;
new Float:g_fOldTimeLimit;
new g_iForwardPreStartVote;
new g_iForwardStartVote;
new g_iForwardFinishVote;

#if defined FUNCTION_SOUND
new const g_szSound[][] =
{
	"sound/fvox/one.wav", "sound/fvox/two.wav", "sound/fvox/three.wav", "sound/fvox/four.wav", "sound/fvox/five.wav",
	"sound/fvox/six.wav", "sound/fvox/seven.wav", "sound/fvox/eight.wav", "sound/fvox/nine.wav", "sound/fvox/ten.wav"
};
#endif

#if defined FUNCTION_RTV
new g_bRockVoted[33];
new g_iRockVotes;
new g_bRockVote;
#endif

#if defined FUNCTION_NOMINATION
new Array:g_aNominatedMaps;
new g_iNominatedMaps[33];
new g_iLastDenominate[33];
new Array:g_aMapPrefixes;
new g_iMapPrefixesNum;
#endif

#if defined FUNCTION_BLOCK_MAPS
new g_iBlockedSize;
#endif

#if defined FUNCTION_NIGHTMODE
new Array:g_aNightMaps;
new g_bNightMode;
new g_bNightModeOneMap;
new g_bCurMapInNightMode;
new Float:g_fOldNightTimeLimit;

#if defined FUNCTION_NIGHTMODE_BLOCK_CMDS
new g_szBlockedCmds[][] = 
{
	"amx_map", "amx_votemap", "amx_mapmenu", "amx_votemapmenu"
};
#endif
#endif

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_cvar("mapm_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	g_pCvars[CHANGE_TYPE] = register_cvar("mapm_change_type", "2");//0 - after end vote, 1 - in round end, 2 - after end map
	g_pCvars[START_VOTE_BEFORE_END] = register_cvar("mapm_start_vote_before_end", "2");//minutes
	g_pCvars[SHOW_RESULT_TYPE] = register_cvar("mapm_show_result_type", "1");//0 - disable, 1 - menu, 2 - hud
	g_pCvars[SHOW_SELECTS] = register_cvar("mapm_show_selects", "1");//0 - disable, 1 - all
	g_pCvars[START_VOTE_IN_NEW_ROUND] = register_cvar("mapm_start_vote_in_new_round", "0");//0 - disable, 1 - enable
	g_pCvars[FREEZE_IN_VOTE] = register_cvar("mapm_freeze_in_vote", "0");//0 - disable, 1 - enable, if mapm_start_vote_in_new_round 1
	g_pCvars[BLACK_SCREEN_IN_VOTE] = register_cvar("mapm_black_screen_in_vote", "0");//0 - disable, 1 - enable
	g_pCvars[LAST_ROUND] = register_cvar("mapm_last_round", "0");//0 - disable, 1 - enable
	
	g_pCvars[CHANGE_TO_DEDAULT] = register_cvar("mapm_change_to_default_map", "0");//minutes, 0 - disable
	g_pCvars[DEFAULT_MAP] = register_cvar("mapm_default_map", "de_dust2");
	
	g_pCvars[EXTENDED_TYPE] = register_cvar("mapm_extended_type", "0");//0 - minutes, 1 - rounds
	g_pCvars[EXTENDED_MAX] = register_cvar("mapm_extended_map_max", "3");
	g_pCvars[EXTENDED_TIME] = register_cvar("mapm_extended_time", "15");//minutes
	g_pCvars[EXTENDED_ROUNDS] = register_cvar("mapm_extended_rounds", "3");//rounds
	
	#if defined FUNCTION_RTV
	g_pCvars[ROCK_MODE] = register_cvar("mapm_rtv_mode", "0");//0 - percents, 1 - players
	g_pCvars[ROCK_PERCENT] = register_cvar("mapm_rtv_percent", "60");
	g_pCvars[ROCK_PLAYERS] = register_cvar("mapm_rtv_players", "5");
	g_pCvars[ROCK_CHANGE_TYPE] = register_cvar("mapm_rtv_change_type", "1");//0 - after vote, 1 - in round end
	g_pCvars[ROCK_DELAY] = register_cvar("mapm_rtv_delay", "0");//minutes
	#endif
	
	#if defined FUNCTION_NOMINATION
	g_pCvars[NOMINATION_DONT_CLOSE_MENU] = register_cvar("mapm_nom_dont_close_menu", "0");//0 - disable, 1 - enable
	g_pCvars[NOMINATION_DEL_NON_CUR_ONLINE] = register_cvar("mapm_nom_del_noncur_online", "0");//0 - disable, 1 - enable
	#endif
	
	#if defined FUNCTION_NIGHTMODE
	g_pCvars[NIGHTMODE_TIME] = register_cvar("mapm_night_time", "00:00 8:00");
	#endif
	
	g_pCvars[MAXROUNDS] = get_cvar_pointer("mp_maxrounds");
	g_pCvars[WINLIMIT] = get_cvar_pointer("mp_winlimit");
	g_pCvars[TIMELIMIT] = get_cvar_pointer("mp_timelimit");
	g_pCvars[FREEZETIME] = get_cvar_pointer("mp_freezetime");
	g_pCvars[ROUNDTIME] = get_cvar_pointer("mp_roundtime");
	
	g_pCvars[NEXTMAP] = register_cvar("amx_nextmap", "", FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY);
	
	#if defined FUNCTION_NEXTMAP
	g_pCvars[CHATTIME] = get_cvar_pointer("mp_chattime");
	#endif
	
	register_event("TeamScore", "Event_TeamScore", "a");
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
	
	#if defined FUNCTION_NEXTMAP
	register_event("30", "Event_Intermisson", "a");
	#endif
	
	register_concmd("mapm_debug", "Commang_Debug", ADMIN_MAP);
	register_concmd("mapm_startvote", "Command_StartVote", ADMIN_MAP);
	register_concmd("mapm_stopvote", "Command_StopVote", ADMIN_MAP);
	register_clcmd("say timeleft", "Command_Timeleft");
	register_clcmd("say thetime", "Command_TheTime");
	register_clcmd("votemap", "Command_Votemap");
	
	#if defined FUNCTION_NEXTMAP
	register_clcmd("say nextmap", "Command_Nextmap");
	register_clcmd("say currentmap", "Command_CurrentMap");
	#endif
	
	#if defined FUNCTION_RTV
	register_clcmd("say rtv", "Command_RockTheVote");
	register_clcmd("say /rtv", "Command_RockTheVote");
	#endif
	
	#if defined FUNCTION_NOMINATION
	register_clcmd("say", "Command_Say");
	register_clcmd("say_team", "Command_Say");
	register_clcmd("say maps", "Command_MapsList");
	register_clcmd("say /maps", "Command_MapsList");
	#endif
	
	#if defined FUNCTION_NIGHTMODE && defined FUNCTION_NIGHTMODE_BLOCK_CMDS
	for(new i; i < sizeof(g_szBlockedCmds); i++)
	{
		register_clcmd(g_szBlockedCmds[i], "Command_BlockedCmds");
	}
	#endif
	
	g_iForwardPreStartVote = CreateMultiForward("mapmanager_prestartvote", ET_IGNORE);
	g_iForwardStartVote = CreateMultiForward("mapmanager_startvote", ET_IGNORE);
	g_iForwardFinishVote = CreateMultiForward("mapmanager_finishvote", ET_IGNORE);
	
	register_menucmd(register_menuid("VoteMenu"), 1023, "VoteMenu_Handler");
	
	set_task(10.0, "Task_CheckTime", TASK_CHECKTIME, .flags = "b");
	
	#if defined FUNCTION_NIGHTMODE
	set_task(60.0, "Task_CheckNight", TASK_CHECKNIGHT, .flags = "b");
	#endif
}

#if defined FUNCTION_NIGHTMODE
public plugin_natives()
{
	register_native("is_night_mode", "Native_IsNightMode");
}
public Native_IsNightMode()
{
	return g_bNightMode;
}
#endif

#if defined FUNCTION_NIGHTMODE && defined FUNCTION_NIGHTMODE_BLOCK_CMDS
public Command_BlockedCmds(id)
{
	if(g_bNightMode)
	{
		console_print(id, "%L", LANG_PLAYER, "MAPM_NIGHT_BLOCK_CMD");
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}
#endif
public Command_Votemap(id)
{
	return PLUGIN_HANDLED;
}
public Commang_Debug(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;
	
	console_print(id, "^nLoaded maps:");	
	new eMapInfo[MAP_INFO], iSize = ArraySize(g_aMaps);
	for(new i; i < iSize; i++)
	{
		ArrayGetArray(g_aMaps, i, eMapInfo);
		console_print(id, "%3d %32s ^t%d^t%d^t%d", i, eMapInfo[m_MapName], eMapInfo[m_MinPlayers], eMapInfo[m_MaxPlayers], eMapInfo[m_BlockCount]);
	}
	
	#if defined FUNCTION_NOMINATION
	new szPrefix[32];
	console_print(id, "^nLoaded prefixes:");
	for(new i; i < g_iMapPrefixesNum; i++)
	{
		ArrayGetString(g_aMapPrefixes, i, szPrefix, charsmax(szPrefix));
		console_print(id, "%s", szPrefix);
	}
	#endif
	
	return PLUGIN_HANDLED;
}
public Command_StartVote(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;
	
	#if defined FUNCTION_NIGHTMODE
	if(g_bNightMode && g_bNightModeOneMap)
	{
		console_print(id, "%L", LANG_PLAYER, "MAPM_NIGHT_BLOCK_CMD");
		return PLUGIN_HANDLED;
	}
	#endif
	
	if(get_pcvar_num(g_pCvars[START_VOTE_IN_NEW_ROUND]) == 0)
	{
		StartVote(id);
	}
	else
	{
		SetNewRoundVote();
		client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_VOTE_WILL_BEGIN");
	}
	
	return PLUGIN_HANDLED;
}
public Command_StopVote(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;
	
	if(g_bVoteStarted)
	{		
		g_bVoteStarted = false;
		
		#if defined FUNCTION_RTV
		g_bRockVote = false;
		g_iRockVotes = 0;
		arrayset(g_bRockVoted, false, 33);
		#endif
		
		if(get_pcvar_num(g_pCvars[BLACK_SCREEN_IN_VOTE]))
		{
			SetBlackScreenFade(0);
		}
		
		if(g_bChangedFreezeTime)
		{
			set_pcvar_float(g_pCvars[FREEZETIME], get_pcvar_float(g_pCvars[FREEZETIME]) - float(PRE_START_TIME + VOTE_TIME + 1));
			g_bChangedFreezeTime = false;
		}
		
		remove_task(TASK_VOTEMENU);
		remove_task(TASK_SHOWTIMER);
		remove_task(TASK_TIMER);
		
		for(new i = 1; i <= 32; i++)
			remove_task(TASK_VOTEMENU + i);
		
		show_menu(0, 0, "^n", 1);
		new szName[32];
		
		if(id) get_user_name(id, szName, charsmax(szName));
		else szName = "Server";
		
		client_print_color(0, id, "%s^3 %L", PREFIX, LANG_PLAYER, "MAPM_CANCEL_VOTE", szName);
		log_amx("%s canceled vote.", szName);
	}
	
	return PLUGIN_HANDLED;
}
public Command_Timeleft(id)
{
	new iWinLimit = get_pcvar_num(g_pCvars[WINLIMIT]);
	new iMaxRounds = get_pcvar_num(g_pCvars[MAXROUNDS]);
	
	if((iWinLimit || iMaxRounds) && get_pcvar_num(g_pCvars[EXTENDED_TYPE]) == 1)
	{
		new szText[128], len;
		len = formatex(szText, charsmax(szText), "%L ", LANG_PLAYER, "MAPM_TIME_TO_END");
		if(iWinLimit)
		{
			new iLeftWins = iWinLimit - max(g_iTeamScore[0], g_iTeamScore[1]);
			new szWins[16]; get_ending(iLeftWins, "MAPM_WIN1", "MAPM_WIN2", "MAPM_WIN3", szWins, charsmax(szWins));
			len += formatex(szText[len], charsmax(szText) - len, "%d %L", iLeftWins, LANG_PLAYER, szWins);
		}
		if(iWinLimit && iMaxRounds)
		{
			len += formatex(szText[len], charsmax(szText) - len, " %L ", LANG_PLAYER, "MAPM_TIMELEFT_OR");
		}
		if(iMaxRounds)
		{
			new iLeftRounds = iMaxRounds - g_iTeamScore[0] - g_iTeamScore[1];
			new szRounds[16]; get_ending(iLeftRounds, "MAPM_ROUND1", "MAPM_ROUND2", "MAPM_ROUND3", szRounds, charsmax(szRounds));
			len += formatex(szText[len], charsmax(szText) - len, "%d %L", iLeftRounds, LANG_PLAYER, szRounds);
		}
		client_print_color(0, print_team_default, "%s^1 %s.", PREFIX, szText);
	}
	else
	{
		if (get_pcvar_num(g_pCvars[TIMELIMIT]))
		{
			new a = get_timeleft();
			client_print_color(0, id, "%s^1 %L:^3 %d:%02d", PREFIX, LANG_PLAYER, "MAPM_TIME_TO_END", (a / 60), (a % 60));
		}
		else
		{
			client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_NO_TIMELIMIT");
		}
	}
}
public Command_TheTime(id)
{
	new szTime[64]; get_time("%Y/%m/%d - %H:%M:%S", szTime, charsmax(szTime));
	client_print_color(0, print_team_default, "%s^3 %L", PREFIX, LANG_PLAYER, "MAPM_THETIME", szTime);
}

#if defined FUNCTION_NEXTMAP
public Command_Nextmap(id)
{
	if(g_bVoteFinished)
	{
		new szMap[32]; get_pcvar_string(g_pCvars[NEXTMAP], szMap, charsmax(szMap));
		client_print_color(0, id, "%s^1 %L ^3%s^1.", PREFIX, LANG_PLAYER, "MAPM_NEXTMAP", szMap);
	}
	else
	{
		client_print_color(0, id, "%s^1 %L ^3%L^1.", PREFIX, LANG_PLAYER, "MAPM_NEXTMAP", LANG_PLAYER, "MAPM_NOT_SELECTED");
	}
}
public Command_CurrentMap(id)
{
	client_print_color(0, id, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_CURRENT_MAP", g_szCurrentMap);
}
#endif

#if defined FUNCTION_RTV
public Command_RockTheVote(id)
{
	if(g_bVoteFinished || g_bVoteStarted || g_bStartVote) return PLUGIN_HANDLED;
	
	#if defined FUNCTION_NIGHTMODE
	if(g_bNightMode && g_bNightModeOneMap)
	{
		client_print_color(id, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_NIGHT_NOT_AVAILABLE");
		return PLUGIN_HANDLED;
	}
	#endif
	
	new iTime = get_pcvar_num(g_pCvars[ROCK_DELAY]) * 60 - (floatround(get_pcvar_float(g_pCvars[TIMELIMIT]) * 60.0) - get_timeleft());
	if(iTime > 0)
	{
		client_print_color(id, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_RTV_DELAY", iTime / 60, iTime % 60);
		return PLUGIN_HANDLED;
	}
	
	if(!g_bRockVoted[id]) g_iRockVotes++;
	
	new iVotes = (get_pcvar_num(g_pCvars[ROCK_MODE])) ? get_pcvar_num(g_pCvars[ROCK_PLAYERS]) - g_iRockVotes : floatround(get_players_num() * get_pcvar_num(g_pCvars[ROCK_PERCENT]) / 100.0, floatround_ceil) - g_iRockVotes;
	
	if(iVotes <= 0)
	{
		g_bRockVote = true;
		if(!get_pcvar_num(g_pCvars[START_VOTE_IN_NEW_ROUND]))
		{
			StartVote(0);
			client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_RTV_START_VOTE");
		}
		else
		{
			SetNewRoundVote();
			client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_START_VOTE_NEW_ROUND");
		}
		return PLUGIN_HANDLED;
	}
	
	new szVote[16];	get_ending(iVotes, "MAPM_VOTE1", "MAPM_VOTE2", "MAPM_VOTE3", szVote, charsmax(szVote));
	
	if(!g_bRockVoted[id])
	{
		g_bRockVoted[id] = true;		
		
		new szName[33];	get_user_name(id, szName, charsmax(szName));
		client_print_color(0, print_team_default, "%s^3 %L %L.", PREFIX, LANG_PLAYER, "MAPM_RTV_VOTED", szName, iVotes, LANG_PLAYER, szVote);
	}
	else
	{
		client_print_color(id, print_team_default, "%s^1 %L %L.", PREFIX, LANG_PLAYER, "MAPM_RTV_ALREADY_VOTED", iVotes, LANG_PLAYER, szVote);
	}
	
	return PLUGIN_HANDLED;
}
#endif

#if defined FUNCTION_NOMINATION
public Command_Say(id)
{
	if(g_bVoteStarted || g_bVoteFinished) return;
	
	#if defined FUNCTION_NIGHTMODE
	if(g_bNightMode) return;
	#endif
	
	new szText[32]; read_args(szText, charsmax(szText));
	remove_quotes(szText); trim(szText); strtolower(szText);
	
	if(string_with_space(szText)) return;
	
	new map_index = is_map_in_array(szText);
	
	if(map_index)
	{
		NominateMap(id, szText, map_index - 1);
	}
	else if(strlen(szText) >= 4)
	{
		new szFormat[32], szPrefix[32], Array:aNominateList = ArrayCreate(), iArraySize;
		for(new i; i < g_iMapPrefixesNum; i++)
		{
			ArrayGetString(g_aMapPrefixes, i, szPrefix, charsmax(szPrefix));
			formatex(szFormat, charsmax(szFormat), "%s%s", szPrefix, szText);
			map_index = 0;
			while((map_index = find_similar_map(map_index, szFormat)))
			{
				ArrayPushCell(aNominateList, map_index - 1);
				iArraySize++;
			}
		}
		
		if(iArraySize == 1)
		{
			map_index = ArrayGetCell(aNominateList, 0);
			new eMapInfo[MAP_INFO]; ArrayGetArray(g_aMaps, map_index, eMapInfo);
			copy(szFormat, charsmax(szFormat), eMapInfo[m_MapName]);
			NominateMap(id, szFormat, map_index);
		}
		else if(iArraySize > 1)
		{
			Show_NominationList(id, aNominateList, iArraySize);
		}
		
		ArrayDestroy(aNominateList);
	}
}
public Show_NominationList(id, Array: array, size)
{
	new szText[64]; formatex(szText, charsmax(szText), "%L", LANG_PLAYER, "MAPM_MENU_FAST_NOM");
	new iMenu = menu_create(szText, "NominationList_Handler");
	new eMapInfo[MAP_INFO], szString[64], map_index, nominate_index;
	
	for(new i, szNum[8]; i < size; i++)
	{
		map_index = ArrayGetCell(array, i);
		ArrayGetArray(g_aMaps, map_index, eMapInfo);
		
		num_to_str(map_index, szNum, charsmax(szNum));
		nominate_index = is_map_nominated(map_index);
		
		if(eMapInfo[m_BlockCount])
		{
			formatex(szString, charsmax(szString), "%s[\r%d\d]", eMapInfo[m_MapName], eMapInfo[m_BlockCount]);
			menu_additem(iMenu, szString, szNum, (1 << 31));
		}
		else if(nominate_index)
		{
			new eNomInfo[NOMINATEDMAP_INFO]; ArrayGetArray(g_aNominatedMaps, nominate_index - 1, eNomInfo);
			if(id == eNomInfo[n_Player])
			{
				formatex(szString, charsmax(szString), "%s[\y*\w]", eMapInfo[m_MapName]);
				menu_additem(iMenu, szString, szNum);
			}
			else
			{
				formatex(szString, charsmax(szString), "%s[\y*\d]", eMapInfo[m_MapName]);
				menu_additem(iMenu, szString, szNum, (1 << 31));
			}
		}
		else
		{
			menu_additem(iMenu, eMapInfo[m_MapName], szNum);
		}
	}
	
	formatex(szText, charsmax(szText), "%L", LANG_PLAYER, "MAPM_MENU_BACK");
	menu_setprop(iMenu, MPROP_BACKNAME, szText);
	formatex(szText, charsmax(szText), "%L", LANG_PLAYER, "MAPM_MENU_NEXT");
	menu_setprop(iMenu, MPROP_NEXTNAME, szText);
	formatex(szText, charsmax(szText), "%L", LANG_PLAYER, "MAPM_MENU_EXIT");
	menu_setprop(iMenu, MPROP_EXITNAME, szText);
	
	menu_display(id, iMenu);
}
public NominationList_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new szData[8], szName[32], iAccess, iCallback;
	menu_item_getinfo(menu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	
	new map_index = str_to_num(szData);
	trim_bracket(szName);
	new is_map_nominated = NominateMap(id, szName, map_index);
	
	if(is_map_nominated == 2 || get_pcvar_num(g_pCvars[NOMINATION_DONT_CLOSE_MENU]))
	{
		if(is_map_nominated == 1)
		{
			new szString[48]; formatex(szString, charsmax(szString), "%s[\y*\w]", szName);
			menu_item_setname(menu, item, szString);
		}
		else if(is_map_nominated == 2)
		{
			menu_item_setname(menu, item, szName);
		}
		menu_display(id, menu);
	}
	else
	{
		menu_destroy(menu);
	}
	
	return PLUGIN_HANDLED;
}
NominateMap(id, map[32], map_index)
{
	new eMapInfo[MAP_INFO]; ArrayGetArray(g_aMaps, map_index, eMapInfo);
	
	#if defined FUNCTION_BLOCK_MAPS
	if(eMapInfo[m_BlockCount])
	{
		client_print_color(id, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_NOM_NOT_AVAILABLE_MAP");
		return 0;
	}
	#endif
	
	new eNomInfo[NOMINATEDMAP_INFO];
	new szName[32];	get_user_name(id, szName, charsmax(szName));
	
	new nominate_index = is_map_nominated(map_index);
	if(nominate_index)
	{
		ArrayGetArray(g_aNominatedMaps, nominate_index - 1, eNomInfo);
		if(id == eNomInfo[n_Player])
		{
			new iSysTime = get_systime();
			if(g_iLastDenominate[id] + MIN_DENOMINATE_TIME <= iSysTime)
			{
				g_iLastDenominate[id] = iSysTime;
				g_iNominatedMaps[id]--;
				ArrayDeleteItem(g_aNominatedMaps, nominate_index - 1);
				
				client_print_color(0, id, "%s^3 %L", PREFIX, LANG_PLAYER, "MAPM_NOM_REMOVE_NOM", szName, map);
				return 2;
			}
			client_print_color(id, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_NOM_SPAM");
			return 0;
		}
		client_print_color(id, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_NOM_ALREADY_NOM");
		return 0;
	}
	
	if(g_iNominatedMaps[id] >= NOMINATED_MAPS_PER_PLAYER)
	{
		client_print_color(id, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_NOM_CANT_NOM");
		return 0;
	}
	
	eNomInfo[n_MapName] = map;
	eNomInfo[n_Player] = id;
	eNomInfo[n_MapIndex] = map_index;
	ArrayPushArray(g_aNominatedMaps, eNomInfo);
	
	g_iNominatedMaps[id]++;
	
	if(get_pcvar_num(g_pCvars[NOMINATION_DEL_NON_CUR_ONLINE]))
	{
		new iMinPlayers = eMapInfo[m_MinPlayers] == 0 ? 1 : eMapInfo[m_MinPlayers];
		client_print_color(0, id, "%s^3 %L", PREFIX, LANG_PLAYER, "MAPM_NOM_MAP2", szName, map, iMinPlayers, eMapInfo[m_MaxPlayers]);
	}
	else
	{
		client_print_color(0, id, "%s^3 %L", PREFIX, LANG_PLAYER, "MAPM_NOM_MAP", szName, map);
	}
	
	return 1;
}
public Command_MapsList(id)
{
	#if defined FUNCTION_NIGHTMODE
	if(g_bNightMode)
	{
		client_print_color(id, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_NIGHT_NOT_AVAILABLE");
		return;
	}
	#endif
	Show_MapsListMenu(id);
}
Show_MapsListMenu(id)
{
	new szText[64]; formatex(szText, charsmax(szText), "%L", LANG_PLAYER, "MAPM_MENU_MAP_LIST");
	new iMenu = menu_create(szText, "MapsListMenu_Handler");
	
	new eMapInfo[MAP_INFO], szString[48], iSize = ArraySize(g_aMaps);
	
	for(new i, nominate_index; i < iSize; i++)
	{
		ArrayGetArray(g_aMaps, i, eMapInfo);
		nominate_index = is_map_nominated(i);
		
		if(eMapInfo[m_BlockCount])
		{
			formatex(szString, charsmax(szString), "%s[\r%d\d]", eMapInfo[m_MapName], eMapInfo[m_BlockCount]);
			menu_additem(iMenu, szString, _, (1 << 31));
		}
		else if(nominate_index)
		{
			new eNomInfo[NOMINATEDMAP_INFO]; ArrayGetArray(g_aNominatedMaps, nominate_index - 1, eNomInfo);
			if(id == eNomInfo[n_Player])
			{
				formatex(szString, charsmax(szString), "%s[\y*\w]", eMapInfo[m_MapName]);
				menu_additem(iMenu, szString);
			}
			else
			{
				formatex(szString, charsmax(szString), "%s[\y*\d]", eMapInfo[m_MapName]);
				menu_additem(iMenu, szString, _, (1 << 31));
			}
		}
		else
		{
			menu_additem(iMenu, eMapInfo[m_MapName]);
		}
	}
	formatex(szText, charsmax(szText), "%L", LANG_PLAYER, "MAPM_MENU_BACK");
	menu_setprop(iMenu, MPROP_BACKNAME, szText);
	formatex(szText, charsmax(szText), "%L", LANG_PLAYER, "MAPM_MENU_NEXT");
	menu_setprop(iMenu, MPROP_NEXTNAME, szText);
	formatex(szText, charsmax(szText), "%L", LANG_PLAYER, "MAPM_MENU_EXIT");
	menu_setprop(iMenu, MPROP_EXITNAME, szText);
	
	menu_display(id, iMenu);
}
public MapsListMenu_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new szData[2], szName[32], iAccess, iCallback;
	menu_item_getinfo(menu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	
	new map_index = item;
	trim_bracket(szName);
	new is_map_nominated = NominateMap(id, szName, map_index);
	
	if(g_iNominatedMaps[id] < NOMINATED_MAPS_PER_PLAYER || get_pcvar_num(g_pCvars[NOMINATION_DONT_CLOSE_MENU]))
	{
		if(is_map_nominated == 1)
		{
			new szString[48]; formatex(szString, charsmax(szString), "%s[\y*\w]", szName);
			menu_item_setname(menu, item, szString);
		}
		else if(is_map_nominated == 2)
		{
			menu_item_setname(menu, item, szName);
		}
		menu_display(id, menu, map_index / 7);
	}
	else
	{
		menu_destroy(menu);
	}
	
	return PLUGIN_HANDLED;
}
#endif
public client_putinserver(id)
{
	if(!is_user_bot(id) && !is_user_hltv(id))
		remove_task(TASK_CHANGETODEFAULT);
}
public client_disconnect(id)
{
	remove_task(id + TASK_VOTEMENU);
	
	#if defined FUNCTION_RTV
	if(g_bRockVoted[id])
	{
		g_bRockVoted[id] = false;
		g_iRockVotes--;
	}
	#endif
	
	#if defined FUNCTION_NOMINATION
	if(g_iNominatedMaps[id])
	{
		clear_nominated_maps(id);
	}
	#endif
	
	#if defined FUNCTION_NIGHTMODE
	if(!g_bNightMode) set_task(1.0, "Task_DelayedChangeToDelault");
	#else
	set_task(1.0, "Task_DelayedChangeToDelault");
	#endif
}
public Task_DelayedChangeToDelault()
{
	new Float:fChangeTime = get_pcvar_float(g_pCvars[CHANGE_TO_DEDAULT]);
	if(fChangeTime > 0.0 && get_players_num() == 0)
	{
		set_task(fChangeTime * 60.0, "Task_ChangeToDefault", TASK_CHANGETODEFAULT);
	}
}
public Task_ChangeToDefault()
{
	new szMapName[32]; get_pcvar_string(g_pCvars[DEFAULT_MAP], szMapName, charsmax(szMapName));
	if(get_players_num() == 0 && is_map_valid(szMapName) && !equali(szMapName, g_szCurrentMap))
	{
		log_amx("Map changed to default[%s]", szMapName);
		set_pcvar_string(g_pCvars[NEXTMAP], szMapName);
		Intermission();
	}
}
public plugin_end()
{
	#if defined FUNCTION_NIGHTMODE
	if(g_fOldNightTimeLimit > 0.0)
	{
		set_pcvar_float(g_pCvars[TIMELIMIT], g_fOldNightTimeLimit);
	}
	#endif
	
	if(g_bChangedFreezeTime)
	{
		set_pcvar_float(g_pCvars[FREEZETIME], get_pcvar_float(g_pCvars[FREEZETIME]) - float(PRE_START_TIME + VOTE_TIME + 1));
	}
	if(g_fOldTimeLimit > 0.0)
	{
		set_pcvar_float(g_pCvars[TIMELIMIT], g_fOldTimeLimit);
	}
	if(g_iExtendedMax)
	{
		if(get_pcvar_num(g_pCvars[EXTENDED_TYPE]) == 0)
		{
			set_pcvar_float(g_pCvars[TIMELIMIT], get_pcvar_float(g_pCvars[TIMELIMIT]) - float(g_iExtendedMax * get_pcvar_num(g_pCvars[EXTENDED_TIME])));
		}
		else
		{
			new iWinLimit = get_pcvar_num(g_pCvars[WINLIMIT]);
			if(iWinLimit > 0)
			{
				set_pcvar_num(g_pCvars[WINLIMIT], iWinLimit - get_pcvar_num(g_pCvars[EXTENDED_ROUNDS]) * g_iExtendedMax);
			}
			new iMaxRounds = get_pcvar_num(g_pCvars[MAXROUNDS]);
			if(iMaxRounds > 0)
			{
				set_pcvar_num(g_pCvars[MAXROUNDS], iMaxRounds - get_pcvar_num(g_pCvars[EXTENDED_ROUNDS]) * g_iExtendedMax);
			}
		}
	}
}
public plugin_cfg()
{
	new filepath[256]; get_localinfo("amxx_configsdir", filepath, charsmax(filepath));
	add(filepath, charsmax(filepath), "/mapmanager.cfg");
	
	if(file_exists(filepath))
	{
		server_cmd("exec %s", filepath);
		server_exec();
	}
	
	g_aMaps = ArrayCreate(MAP_INFO);
	
	#if defined FUNCTION_NOMINATION
	g_aNominatedMaps = ArrayCreate(NOMINATEDMAP_INFO);
	g_aMapPrefixes = ArrayCreate(32);
	#endif
	
	if( is_plugin_loaded("Nextmap Chooser") > -1 )
	{
		pause("cd", "mapchooser.amxx");
		log_amx("MapManager: mapchooser.amxx has been stopped.");
	}
	
	#if defined FUNCTION_NEXTMAP
	if( is_plugin_loaded("NextMap") > -1 )
	{
		pause("cd", "nextmap.amxx");
		log_amx("MapManager: nextmap.amxx has been stopped.");
	}	
	#endif
	
	LoadMapsFromFile();
	
	#if defined FUNCTION_NIGHTMODE
	LoadNightMaps();
	#endif
	
	new Float:fChangeTime = get_pcvar_float(g_pCvars[CHANGE_TO_DEDAULT]);
	if(fChangeTime > 0.0)
	{
		set_task(fChangeTime * 60.0, "Task_ChangeToDefault", TASK_CHANGETODEFAULT);
	}
	
	register_dictionary("mapmanager.txt");
}
LoadMapsFromFile()
{
	new szDir[128], szFile[128];	
	get_mapname(g_szCurrentMap, charsmax(g_szCurrentMap));
	
	#if defined FUNCTION_BLOCK_MAPS
	get_localinfo("amxx_datadir", szDir, charsmax(szDir));
	formatex(szFile, charsmax(szFile), "%s/%s", szDir, FILE_BLOCKEDMAPS);
	
	new Array:aBlockedMaps = ArrayCreate(BLOCKEDMAP_INFO);
	new eBlockedInfo[BLOCKEDMAP_INFO];
	
	if(file_exists(szFile))
	{
		new szTemp[128]; formatex(szTemp, charsmax(szTemp), "%s/temp.ini", szDir);
		new iFile = fopen(szFile, "rt");
		new iTemp = fopen(szTemp, "wt");
		
		new szBuffer[42], szMapName[32], szCount[8], iCount;
		
		while(!feof(iFile))
		{
			fgets(iFile, szBuffer, charsmax(szBuffer));
			parse(szBuffer, szMapName, charsmax(szMapName), szCount, charsmax(szCount));
			
			if(!is_map_valid(szMapName) || is_map_blocked(aBlockedMaps, szMapName) || equali(szMapName, g_szCurrentMap)) continue;
			
			iCount = str_to_num(szCount) - 1;
			
			if(iCount <= 0) continue;
			
			if(iCount > BLOCK_MAP_COUNT)
			{
				fprintf(iTemp, "^"%s^" ^"%d^"^n", szMapName, BLOCK_MAP_COUNT);
				iCount = BLOCK_MAP_COUNT;
			}
			else
			{
				fprintf(iTemp, "^"%s^" ^"%d^"^n", szMapName, iCount);
			}
			
			formatex(eBlockedInfo[b_MapName], charsmax(eBlockedInfo[b_MapName]), szMapName);
			eBlockedInfo[b_Count] = iCount;
			ArrayPushArray(aBlockedMaps, eBlockedInfo);
		}
		
		fprintf(iTemp, "^"%s^" ^"%d^"^n", g_szCurrentMap, BLOCK_MAP_COUNT);
		
		fclose(iFile);
		fclose(iTemp);
		
		delete_file(szFile);
		rename_file(szTemp, szFile, 1);
	}
	else
	{
		new iFile = fopen(szFile, "wt");
		if(iFile)
		{
			fprintf(iFile, "^"%s^" ^"%d^"^n", g_szCurrentMap, BLOCK_MAP_COUNT);
		}
		fclose(iFile);
	}
	#endif
	
	get_localinfo("amxx_configsdir", szDir, charsmax(szDir));
	formatex(szFile, charsmax(szFile), "%s/%s", szDir, FILE_MAPS);
	
	if(file_exists(szFile))
	{
		new f = fopen(szFile, "rt");
		
		if(f)
		{
			new eMapInfo[MAP_INFO];
			new szText[48], szMap[32], szMin[3], szMax[3];
			while(!feof(f))
			{
				fgets(f, szText, charsmax(szText));
				parse(szText, szMap, charsmax(szMap), szMin, charsmax(szMin), szMax, charsmax(szMax));
				
				if(!szMap[0] || szMap[0] == ';' || !valid_map(szMap) || is_map_in_array(szMap) || equali(szMap, g_szCurrentMap)) continue;
				
				#if defined FUNCTION_BLOCK_MAPS
				new blocked_index = is_map_blocked(aBlockedMaps, szMap);
				if(blocked_index)
				{
					ArrayGetArray(aBlockedMaps, blocked_index - 1, eBlockedInfo);
					eMapInfo[m_BlockCount] = eBlockedInfo[b_Count];
				}
				else
				{
					eMapInfo[m_BlockCount] = 0;
				}
				#endif
				
				#if defined FUNCTION_NOMINATION
				new szPrefix[32];
				if(get_map_prefix(szMap, szPrefix, charsmax(szPrefix)) && !is_prefix_in_array(szPrefix))
				{
					ArrayPushString(g_aMapPrefixes, szPrefix);
					g_iMapPrefixesNum++;
				}
				#endif
				
				eMapInfo[m_MapName] = szMap;
				eMapInfo[m_MinPlayers] = str_to_num(szMin);
				eMapInfo[m_MaxPlayers] = str_to_num(szMax) == 0 ? 32 : str_to_num(szMax);
				
				ArrayPushArray(g_aMaps, eMapInfo);
				szMin = ""; szMax = "";
			}
			fclose(f);
			
			new iSize = ArraySize(g_aMaps);
			
			if(iSize == 0)
			{
				set_fail_state("Nothing loaded from file.");
			}
			
			#if defined FUNCTION_BLOCK_MAPS
			g_iBlockedSize = ArraySize(aBlockedMaps);
			if(iSize - g_iBlockedSize < SELECT_MAPS)
			{
				log_amx("LoadMaps: warning to little maps without block [%d]", iSize - g_iBlockedSize);
			}
			if(iSize - g_iBlockedSize < 1)
			{
				log_amx("LoadMaps: blocked maps cleared");
				clear_blocked_maps();
			}
			ArrayDestroy(aBlockedMaps);
			#endif
			
			#if defined FUNCTION_NEXTMAP
			new iRandomMap = random_num(0, iSize - 1);
			ArrayGetArray(g_aMaps, iRandomMap, eMapInfo);
			set_pcvar_string(g_pCvars[NEXTMAP], eMapInfo[m_MapName]);
			#endif
		}		
	}
	else
	{
		set_fail_state("Maps file doesn't exist.");
	}
}

#if defined FUNCTION_NIGHTMODE
LoadNightMaps()
{
	g_aNightMaps = ArrayCreate(32);
	
	new szDir[128]; get_localinfo("amxx_configsdir", szDir, charsmax(szDir));
	new szFile[128]; formatex(szFile, charsmax(szFile), "%s/%s", szDir, FILE_NIGHTMAPS);
	new iMapsCount;
	if(file_exists(szFile))
	{
		new szMapName[32], f = fopen(szFile, "rt");
		if(f)
		{
			while(!feof(f))
			{
				fgets(f, szMapName, charsmax(szMapName));
				trim(szMapName); remove_quotes(szMapName);
				
				if(!szMapName[0] || szMapName[0] == ';' || !valid_map(szMapName) || is_map_in_night_array(szMapName))
					continue;
				
				ArrayPushString(g_aNightMaps, szMapName);
				iMapsCount++;
			}
			fclose(f);
		}
	}
	if(iMapsCount < 1)
	{
		log_amx("LoadNightMaps: Need more maps");
		remove_task(TASK_CHECKNIGHT);
	}
	else if(iMapsCount == 1)
	{
		g_bNightModeOneMap = true;
	}
	
	if(is_map_in_night_array(g_szCurrentMap))
	{
		g_bCurMapInNightMode = true;
	}
	if(iMapsCount >= 1)
	{
		set_task(10.0, "Task_CheckNight");
	}
}
#endif

#if defined FUNCTION_NEXTMAP
public Event_Intermisson()
{
	new Float:fChatTime = get_pcvar_float(g_pCvars[CHATTIME]);
	set_pcvar_float(g_pCvars[CHATTIME], fChatTime + 2.0);
	set_task(fChatTime, "DelayedChange");
}
public DelayedChange()
{
	new szNextMap[32]; get_pcvar_string(g_pCvars[NEXTMAP], szNextMap, charsmax(szNextMap));
	set_pcvar_float(g_pCvars[CHATTIME], get_pcvar_float(g_pCvars[CHATTIME]) - 2.0);
	server_cmd("changelevel %s", szNextMap);
}
#endif
public Event_NewRound()
{
	new iMaxRounds = get_pcvar_num(g_pCvars[MAXROUNDS]);
	if(!g_bVoteFinished && iMaxRounds && (g_iTeamScore[0] + g_iTeamScore[1]) >= iMaxRounds - 2)
	{
		log_amx("StartVote: maxrounds %d [%d]", iMaxRounds, g_iTeamScore[0] + g_iTeamScore[1]);
		StartVote(0);
	}
	
	new iWinLimit = get_pcvar_num(g_pCvars[WINLIMIT]) - 2;
	if(!g_bVoteFinished && iWinLimit > 0 && (g_iTeamScore[0] >= iWinLimit || g_iTeamScore[1] >= iWinLimit))
	{
		log_amx("StartVote: winlimit %d [%d/%d]", iWinLimit, g_iTeamScore[0], g_iTeamScore[1]);
		StartVote(0);
	}
	
	if(g_bStartVote)
	{
		log_amx("StartVote: timeleft %d, new round", get_timeleft());
		StartVote(0);
	}
	
	if(!g_bChangedFreezeTime && g_bVoteStarted && get_pcvar_num(g_pCvars[FREEZE_IN_VOTE]) && get_pcvar_num(g_pCvars[START_VOTE_IN_NEW_ROUND]))
	{
		g_bChangedFreezeTime = true;
		set_pcvar_float(g_pCvars[FREEZETIME], get_pcvar_float(g_pCvars[FREEZETIME]) + float(PRE_START_TIME + VOTE_TIME + 1));
	}
	
	#if defined FUNCTION_NIGHTMODE
	if(g_bNightMode && g_bVoteFinished && (g_bNightModeOneMap && get_pcvar_num(g_pCvars[CHANGE_TYPE]) >= 1 || !g_bCurMapInNightMode))
	{
		Intermission();
		new szMapName[32]; get_pcvar_string(g_pCvars[NEXTMAP], szMapName, charsmax(szMapName));
		client_print_color(0, print_team_default, "%s^3 %L", PREFIX, LANG_PLAYER, "MAPM_NIGHT_NEXTMAP", szMapName);
		return;
	}
	#endif
	
	#if defined FUNCTION_RTV
	if(g_bVoteFinished && (g_bRockVote && get_pcvar_num(g_pCvars[ROCK_CHANGE_TYPE]) == 1 || get_pcvar_num(g_pCvars[CHANGE_TYPE]) == 1 || get_pcvar_num(g_pCvars[LAST_ROUND])))
	#else
	if(g_bVoteFinished && (get_pcvar_num(g_pCvars[CHANGE_TYPE]) == 1 || get_pcvar_num(g_pCvars[LAST_ROUND])))
	#endif
	{
		Intermission();
		new szMapName[32]; get_pcvar_string(g_pCvars[NEXTMAP], szMapName, charsmax(szMapName));
		client_print_color(0, print_team_default, "%s^1 %L^3 %s^1.", PREFIX, LANG_PLAYER, "MAPM_NEXTMAP", szMapName);
	}
}
public Event_TeamScore()
{
	new team[2]; read_data(1, team, charsmax(team));
	g_iTeamScore[(team[0]=='C') ? 0 : 1] = read_data(2);
}
public Task_CheckTime()
{
	if(g_bVoteStarted || g_bVoteFinished) return PLUGIN_CONTINUE;
	
	#if defined FUNCTION_NIGHTMODE
	if(g_bNightMode && g_bNightModeOneMap) return PLUGIN_CONTINUE;
	#endif
	
	if(get_pcvar_float(g_pCvars[TIMELIMIT]) <= 0.0) return PLUGIN_CONTINUE;
	
	new Float:fTimeToVote = get_pcvar_float(g_pCvars[START_VOTE_BEFORE_END]);
	
	new iTimeLeft = get_timeleft();
	if(iTimeLeft <= floatround(fTimeToVote * 60.0))
	{
		if(!get_pcvar_num(g_pCvars[START_VOTE_IN_NEW_ROUND]))
		{
			log_amx("StartVote: timeleft %d", iTimeLeft);
			StartVote(0);
		}
		else
		{
			SetNewRoundVote();
		}
	}
	
	return PLUGIN_CONTINUE;
}

#if defined FUNCTION_NIGHTMODE
public Task_CheckNight()
{
	new szTime[16]; get_pcvar_string(g_pCvars[NIGHTMODE_TIME], szTime, charsmax(szTime));
	new szStart[8], szEnd[8]; parse(szTime, szStart, charsmax(szStart), szEnd, charsmax(szEnd));
	new iStartHour, iStartMinutes, iEndHour, iEndMinutes;
	get_int_time(szStart, iStartHour, iStartMinutes);
	get_int_time(szEnd, iEndHour, iEndMinutes);
	
	new iCurHour, iCurMinutes; time(iCurHour, iCurMinutes);
	
	new bOldNightMode = g_bNightMode;
	
	if(iStartHour != iEndHour && (iStartHour == iCurHour && iCurMinutes >= iStartMinutes || iEndHour == iCurHour && iCurMinutes < iEndMinutes))
	{
		g_bNightMode = true;
	}
	else if(iStartHour == iEndHour && iStartMinutes <= iCurMinutes < iEndMinutes)
	{
		g_bNightMode = true;
	}
	else if(iStartHour > iEndHour && (iStartHour < iCurHour < 24 || 0 <= iCurHour < iEndHour))
	{
		g_bNightMode = true;
	}
	else if(iStartHour < iCurHour < iEndHour)
	{
		g_bNightMode = true;
	}
	else
	{
		g_bNightMode = false;
	}
	
	if(g_bNightMode && !bOldNightMode)// NightMode ON
	{
		if(g_bNightModeOneMap)
		{
			if(g_bCurMapInNightMode)
			{
				g_fOldNightTimeLimit = get_pcvar_float(g_pCvars[TIMELIMIT]);
				set_pcvar_float(g_pCvars[TIMELIMIT], 0.0);
				client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_NIGHT_ON", iEndHour, iEndMinutes);
			}
			else
			{
				new szMapName[32]; ArrayGetString(g_aNightMaps, 0, szMapName, charsmax(szMapName));
				set_pcvar_string(g_pCvars[NEXTMAP], szMapName);
				
				if(get_pcvar_num(g_pCvars[CHANGE_TYPE]) == 0)
				{
					Intermission();
					client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_NIGHT_CHANGELEVEL", szMapName);
				}
				else
				{
					g_bVoteFinished = true;
					client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_NIGHT_NEXT_ROUND_CHANGE", szMapName);
				}
			}
		}
		else if(!g_bCurMapInNightMode)
		{
			if(get_pcvar_num(g_pCvars[START_VOTE_IN_NEW_ROUND]) == 0)
			{
				client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_NIGHT_CHANGELEVEL2");
				StartVote(0);
			}
			else
			{
				SetNewRoundVote()
				client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_NIGHT_NEXT_ROUND_CHANGE2");
			}
		}
	}
	else if(!g_bNightMode && bOldNightMode)// NightMode OFF
	{
		if(g_bNightModeOneMap)
		{
			set_pcvar_float(g_pCvars[TIMELIMIT], g_fOldNightTimeLimit);
		}
		client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_NIGHT_OFF");
	}
}
#endif
SetNewRoundVote()
{
	g_bStartVote = true;
	g_fOldTimeLimit = get_pcvar_float(g_pCvars[TIMELIMIT]);
	if(g_fOldTimeLimit > 0.0)
	{
		g_bNotUnlimitTime = true;
		set_pcvar_float(g_pCvars[TIMELIMIT], 0.0);
	}
}
public StartVote(id)
{
	if(g_bVoteStarted) return 0;
	
	#if defined FUNCTION_NIGHTMODE
	if(g_bNightModeOneMap && g_bNightMode)
	{
		return 0;
	}
	#endif
	
	g_bVoteStarted = true;
	g_bStartVote = false;
	
	ResetInfo();
	CheckAllowExtendMap();
	
	#if defined FUNCTION_NIGHTMODE
	if(g_bNightMode)
	{
		new iNightSize = ArraySize(g_aNightMaps);
		g_iMenuItemsCount = min(min(g_bCurMapInNightMode ? iNightSize - 1 : iNightSize, SELECT_MAPS), 8);
		
		for(new Item, iRandomMap, szMapName[32]; Item < g_iMenuItemsCount; Item++)
		{
			do
			{
				iRandomMap = random_num(0, iNightSize - 1);
				ArrayGetString(g_aNightMaps, iRandomMap, szMapName, charsmax(szMapName));
			}
			while(is_map_in_menu_by_string(szMapName) || equali(szMapName, g_szCurrentMap));
			
			formatex(g_eMenuItems[Item][v_MapName], charsmax(g_eMenuItems[][v_MapName]), szMapName);
		}
		
		ForwardPreStartVote();
		return 0;
	}
	#endif
	
	new Array:aMaps = ArrayCreate(VOTEMENU_INFO), iCurrentSize = 0;
	new eMenuInfo[VOTEMENU_INFO], eMapInfo[MAP_INFO], iGlobalSize = ArraySize(g_aMaps);
	new iPlayersNum = get_players_num();
	
	for(new i = 0; i < iGlobalSize; i++)
	{
		ArrayGetArray(g_aMaps, i, eMapInfo);
		if(eMapInfo[m_MinPlayers] <= iPlayersNum <= eMapInfo[m_MaxPlayers] && !eMapInfo[m_BlockCount])
		{
			formatex(eMenuInfo[v_MapName], charsmax(eMenuInfo[v_MapName]), eMapInfo[m_MapName]);
			eMenuInfo[v_MapIndex] = i; iCurrentSize++;
			ArrayPushArray(aMaps, eMenuInfo);
		}
	}
	new Item = 0;
	
	#if defined FUNCTION_BLOCK_MAPS
	new iMaxItems = min(min(SELECT_MAPS, iGlobalSize - g_iBlockedSize), 8);
	#else
	new iMaxItems = min(min(SELECT_MAPS, iGlobalSize), 8);
	#endif
	
	#if defined FUNCTION_NOMINATION
	new eNomInfo[NOMINATEDMAP_INFO];
	
	if(get_pcvar_num(g_pCvars[NOMINATION_DEL_NON_CUR_ONLINE]))
	{
		for(new i; i < ArraySize(g_aNominatedMaps); i++)
		{
			ArrayGetArray(g_aNominatedMaps, i, eNomInfo);
			ArrayGetArray(g_aMaps, eNomInfo[n_MapIndex], eMapInfo);
			
			if(iPlayersNum > eMapInfo[m_MaxPlayers] || iPlayersNum < eMapInfo[m_MinPlayers])
			{
				ArrayDeleteItem(g_aNominatedMaps, i--);
			}
		}
	}
	
	new iNomSize = ArraySize(g_aNominatedMaps);	
	g_iMenuItemsCount = min(min(iNomSize, NOMINATED_MAPS_IN_VOTE), iMaxItems);
	
	for(new iRandomMap; Item < g_iMenuItemsCount; Item++)
	{
		iRandomMap = random_num(0, ArraySize(g_aNominatedMaps) - 1);
		ArrayGetArray(g_aNominatedMaps, iRandomMap, eNomInfo);
		
		formatex(g_eMenuItems[Item][v_MapName], charsmax(g_eMenuItems[][v_MapName]), eNomInfo[n_MapName]);
		g_eMenuItems[Item][v_MapIndex] = eNomInfo[n_MapIndex];
		g_iNominatedMaps[eNomInfo[n_Player]]--;
		
		ArrayDeleteItem(g_aNominatedMaps, iRandomMap);
		
		new priority_index = is_map_in_priority(aMaps, eNomInfo[n_MapIndex]);
		if(priority_index)
		{
			ArrayDeleteItem(aMaps, priority_index - 1);
		}
	}	
	#endif
	
	if(iCurrentSize && Item < iMaxItems)
	{
		g_iMenuItemsCount = max(min(iCurrentSize, iMaxItems), Item);
		for(new iRandomMap; Item < g_iMenuItemsCount; Item++)
		{
			iRandomMap = random_num(0, ArraySize(aMaps) - 1);
			ArrayGetArray(aMaps, iRandomMap, eMenuInfo);
			
			formatex(g_eMenuItems[Item][v_MapName], charsmax(g_eMenuItems[][v_MapName]), eMenuInfo[v_MapName]);
			g_eMenuItems[Item][v_MapIndex] = eMenuInfo[v_MapIndex];
			
			ArrayDeleteItem(aMaps, iRandomMap);
		}
	}
	
	if(Item < iMaxItems)
	{
		g_iMenuItemsCount = min(iGlobalSize, iMaxItems);
		for(new iRandomMap; Item < g_iMenuItemsCount; Item++)
		{
			do
			{
				iRandomMap = random_num(0, iGlobalSize - 1);
				ArrayGetArray(g_aMaps, iRandomMap, eMapInfo);
			}
			while(is_map_in_menu(iRandomMap) || eMapInfo[m_BlockCount]);
			
			formatex(g_eMenuItems[Item][v_MapName], charsmax(g_eMenuItems[][v_MapName]), eMapInfo[v_MapName]);
			g_eMenuItems[Item][v_MapIndex] = iRandomMap;
		}
	}
	
	ArrayDestroy(aMaps);
	
	ForwardPreStartVote();
	
	return 0;
}
CheckAllowExtendMap()
{
	new bAllow = g_bNotUnlimitTime || get_pcvar_num(g_pCvars[EXTENDED_TYPE]) == 1 && (get_pcvar_num(g_pCvars[MAXROUNDS]) || get_pcvar_num(g_pCvars[WINLIMIT]));
	
	#if defined FUNCTION_RTV && defined FUNCTION_NIGHTMODE
	if((get_pcvar_float(g_pCvars[TIMELIMIT]) > 0.0  || bAllow) && !g_bRockVote && g_iExtendedMax < get_pcvar_num(g_pCvars[EXTENDED_MAX]) && (g_bNightMode && g_bCurMapInNightMode || !g_bNightMode))
	#else
	#if defined FUNCTION_RTV
	if((get_pcvar_float(g_pCvars[TIMELIMIT]) > 0.0  || bAllow) && !g_bRockVote && g_iExtendedMax < get_pcvar_num(g_pCvars[EXTENDED_MAX]))
	#else
	#if defined FUNCTION_NIGHTMODE
	if((get_pcvar_float(g_pCvars[TIMELIMIT]) > 0.0  || bAllow) && g_iExtendedMax < get_pcvar_num(g_pCvars[EXTENDED_MAX]) && (g_bNightMode && g_bCurMapInNightMode || !g_bNightMode))
	#else
	if((get_pcvar_float(g_pCvars[TIMELIMIT]) > 0.0  || bAllow) && g_iExtendedMax < get_pcvar_num(g_pCvars[EXTENDED_MAX]))
	#endif
	#endif
	#endif
	{
		g_bExtendMap = true;
	}
	else
	{
		g_bExtendMap = false;
	}
	
	g_bNotUnlimitTime = false;
}
ResetInfo()
{
	g_iTotalVotes = 0;
	for(new i; i < sizeof(g_eMenuItems); i++)
	{
		g_eMenuItems[i][v_MapName] = "";
		g_eMenuItems[i][v_MapIndex] = -1;
		g_eMenuItems[i][v_Votes] = 0;
	}
	arrayset(g_bPlayerVoted, false, 33);
}
ForwardPreStartVote()
{
	if(get_pcvar_num(g_pCvars[BLACK_SCREEN_IN_VOTE]))
	{
		SetBlackScreenFade(2);
		set_task(1.0, "SetBlackScreenFade", 1);
	}
	
	#if PRE_START_TIME > 0
	g_iTimer = PRE_START_TIME;
	ShowTimer();
	#else
	ShowVoteMenu();
	#endif
	
	new iRet;
	ExecuteForward(g_iForwardPreStartVote, iRet);
}
public ShowTimer()
{
	if(g_iTimer > 0)
	{
		set_task(1.0, "ShowTimer", TASK_SHOWTIMER);
	}
	else
	{
		#if defined FUNCTION_SOUND
		SendAudio(0, "sound/Gman/Gman_Choose2.wav", PITCH_NORM);
		#endif
		ShowVoteMenu();
		return;
	}
	new szSec[16]; get_ending(g_iTimer, "MAPM_SECOND1", "MAPM_SECOND2", "MAPM_SECOND3", szSec, charsmax(szSec));
	new iPlayers[32], pNum; get_players(iPlayers, pNum, "ch");
	for(new id, i; i < pNum; i++)
	{
		id = iPlayers[i];
		set_hudmessage(50, 255, 50, -1.0, is_user_alive(id) ? 0.9 : 0.3, 0, 0.0, 1.0, 0.0, 0.0, 4);
		show_hudmessage(id, "%L %L!", LANG_PLAYER, "MAPM_HUD_TIMER", g_iTimer, LANG_PLAYER, szSec);
	}
	
	#if defined FUNCTION_SOUND
	if(g_iTimer <= 10)
	{
		for(new id, i; i < pNum; i++)
		{
			id = iPlayers[i];
			SendAudio(id, g_szSound[g_iTimer - 1], PITCH_NORM);
		}
	}
	#endif
	
	g_iTimer--;
}
ShowVoteMenu()
{
	g_iTimer = VOTE_TIME;
	
	set_task(1.0, "Task_Timer", TASK_TIMER, .flags = "a", .repeat = VOTE_TIME);
	
	new Players[32], pNum, iPlayer; get_players(Players, pNum, "ch");
	for(new i = 0; i < pNum; i++)
	{
		iPlayer = Players[i];
		VoteMenu(iPlayer + TASK_VOTEMENU);
		set_task(1.0, "VoteMenu", iPlayer + TASK_VOTEMENU, _, _, "a", VOTE_TIME);
	}
	new iRet;
	ExecuteForward(g_iForwardStartVote, iRet);
}
public Task_Timer()
{
	if(--g_iTimer == 0)
	{
		FinishVote();
		show_menu(0, 0, "^n", 1);
		remove_task(TASK_TIMER);
	}
}
public VoteMenu(id)
{
	id -= TASK_VOTEMENU;
	
	if(g_iTimer == 0)
	{
		show_menu(id, 0, "^n", 1); remove_task(id+TASK_VOTEMENU);
		return PLUGIN_HANDLED;
	}
	
	static szMenu[512];
	new iKeys, iPercent, i, iLen;
	
	iLen = formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y%L:^n^n", LANG_PLAYER, g_bPlayerVoted[id] ? "MAPM_MENU_VOTE_RESULTS" : "MAPM_MENU_CHOOSE_MAP");
	
	for(i = 0; i < g_iMenuItemsCount; i++)
	{		
		iPercent = 0;
		if(g_iTotalVotes)
		{
			iPercent = floatround(g_eMenuItems[i][v_Votes] * 100.0 / g_iTotalVotes);
		}
		
		if(!g_bPlayerVoted[id])
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d.\w %s\d[\r%d%%\d]^n", i + 1, g_eMenuItems[i][v_MapName], iPercent);	
			iKeys |= (1 << i);
		}
		else
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d%s[\r%d%%\d]^n", g_eMenuItems[i][v_MapName], iPercent);
		}
	}
	
	if(g_bExtendMap)
	{
		iPercent = 0;
		if(g_iTotalVotes)
		{
			iPercent = floatround(g_eMenuItems[i][v_Votes] * 100.0 / g_iTotalVotes);
		}
		
		if(!g_bPlayerVoted[id])
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r%d.\w %s\d[\r%d%%\d]\y[%L]^n", i + 1, g_szCurrentMap, iPercent, LANG_PLAYER, "MAPM_MENU_EXTEND");	
			iKeys |= (1 << i);
		}
		else
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\d%s[\r%d%%\d]\y[%L]^n", g_szCurrentMap, iPercent, LANG_PLAYER, "MAPM_MENU_EXTEND");
		}
	}
	
	new szSec[16]; get_ending(g_iTimer, "MAPM_SECOND1", "MAPM_SECOND2", "MAPM_SECOND3", szSec, charsmax(szSec));
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\d%L \r%d\d %L", LANG_PLAYER, "MAPM_MENU_LEFT", g_iTimer, LANG_PLAYER, szSec);
	
	if(!iKeys) iKeys |= (1 << 9);
	
	if(g_bPlayerVoted[id] && get_pcvar_num(g_pCvars[SHOW_RESULT_TYPE]) == 2)
	{
		while(replace(szMenu, charsmax(szMenu), "\r", "")){}
		while(replace(szMenu, charsmax(szMenu), "\d", "")){}
		while(replace(szMenu, charsmax(szMenu), "\w", "")){}
		while(replace(szMenu, charsmax(szMenu), "\y", "")){}
		
		set_hudmessage(0, 55, 255, 0.02, -1.0, 0, 6.0, 1.0, 0.1, 0.2, 4);
		show_hudmessage(id, "%s", szMenu);
	}
	else
	{
		show_menu(id, iKeys, szMenu, -1, "VoteMenu");
	}
	
	return PLUGIN_HANDLED;
}
public VoteMenu_Handler(id, key)
{
	if(g_bPlayerVoted[id])
	{
		VoteMenu(id + TASK_VOTEMENU);
		return PLUGIN_HANDLED;
	}
	
	g_eMenuItems[key][v_Votes]++;
	g_iTotalVotes++;
	g_bPlayerVoted[id] = true;
	
	if(get_pcvar_num(g_pCvars[SHOW_SELECTS]))
	{
		new szName[32];	get_user_name(id, szName, charsmax(szName));
		if(key == g_iMenuItemsCount)
		{
			client_print_color(0, id, "%s^3 %L", PREFIX, LANG_PLAYER, "MAPM_CHOSE_EXTEND", szName);
		}
		else
		{
			client_print_color(0, id, "%s^3 %L", PREFIX, LANG_PLAYER, "MAPM_CHOSE_MAP", szName, g_eMenuItems[key][v_MapName]);
		}
	}
	
	if(get_pcvar_num(g_pCvars[SHOW_RESULT_TYPE]))
	{
		VoteMenu(id + TASK_VOTEMENU);
	}
	else
	{
		remove_task(id + TASK_VOTEMENU);
	}
	
	return PLUGIN_HANDLED;
}
FinishVote()
{
	g_bVoteStarted = false;
	g_bVoteFinished = true;
	
	if(g_bChangedFreezeTime)
	{
		set_pcvar_float(g_pCvars[FREEZETIME], get_pcvar_float(g_pCvars[FREEZETIME]) - float(PRE_START_TIME + VOTE_TIME + 1));
		g_bChangedFreezeTime = false;
	}
	if(get_pcvar_num(g_pCvars[BLACK_SCREEN_IN_VOTE]))
	{
		SetBlackScreenFade(0);
	}
	
	new iMaxVote = 0, iRandom;
	for(new i = 1; i < g_iMenuItemsCount + 1; i++)
	{
		iRandom = random_num(0, 1);
		switch(iRandom)
		{
			case 0: if(g_eMenuItems[iMaxVote][v_Votes] < g_eMenuItems[i][v_Votes]) iMaxVote = i;
			case 1: if(g_eMenuItems[iMaxVote][v_Votes] <= g_eMenuItems[i][v_Votes]) iMaxVote = i;
		}
	}
	
	if(g_fOldTimeLimit > 0.0)
	{
		set_pcvar_float(g_pCvars[TIMELIMIT], g_fOldTimeLimit);
		g_fOldTimeLimit = 0.0;
	}
	
	if(!g_iTotalVotes || (iMaxVote != g_iMenuItemsCount))
	{
		if(g_iTotalVotes)
		{
			client_print_color(0, print_team_default, "%s^1 %L^3 %s^1.", PREFIX, LANG_PLAYER, "MAPM_NEXTMAP", g_eMenuItems[iMaxVote][v_MapName]);
		}
		else
		{
			iMaxVote = random_num(0, g_iMenuItemsCount - 1);
			client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_NOBODY_VOTE", g_eMenuItems[iMaxVote][v_MapName]);
		}
		set_pcvar_string(g_pCvars[NEXTMAP], g_eMenuItems[iMaxVote][v_MapName]);
		
		if(get_pcvar_num(g_pCvars[LAST_ROUND]))
		{
			g_fOldTimeLimit = get_pcvar_float(g_pCvars[TIMELIMIT]);
			set_pcvar_float(g_pCvars[TIMELIMIT], 0.0);
			client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "MAPM_LASTROUND");
		}
		#if defined FUNCTION_RTV
		else if(g_bRockVote && get_pcvar_num(g_pCvars[ROCK_CHANGE_TYPE]) == 0 || get_pcvar_num(g_pCvars[CHANGE_TYPE]) == 0)
		#else
		else if(get_pcvar_num(g_pCvars[CHANGE_TYPE]) == 0)
		#endif
		{
			new iSec = get_pcvar_num(g_pCvars[CHATTIME]);
			new szSec[16]; get_ending(iSec, "MAPM_SECOND1", "MAPM_SECOND2", "MAPM_SECOND3", szSec, charsmax(szSec));
			client_print_color(0, print_team_default, "%s^1 %L^1 %L.", PREFIX, LANG_PLAYER, "MAPM_MAP_CHANGE", iSec, LANG_PLAYER, szSec);
			Intermission();
		}
		#if defined FUNCTION_RTV
		else if(g_bRockVote && get_pcvar_num(g_pCvars[ROCK_CHANGE_TYPE]) == 1 || get_pcvar_num(g_pCvars[CHANGE_TYPE]) == 1)
		#else
		else if(get_pcvar_num(g_pCvars[CHANGE_TYPE]) == 1)
		#endif
		{
			client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER,"MAPM_MAP_CHANGE_NEXTROUND");
		}
	}
	else
	{
		g_bVoteFinished = false;
		g_iExtendedMax++;
		
		new iWinLimit = get_pcvar_num(g_pCvars[WINLIMIT]);
		new iMaxRounds = get_pcvar_num(g_pCvars[MAXROUNDS]);
		
		g_iRockVotes = 0;
		g_bRockVote = false;
		arrayset(g_bRockVoted, false, sizeof(g_bRockVoted));
		
		if(get_pcvar_num(g_pCvars[EXTENDED_TYPE]) == 1 && (iWinLimit || iMaxRounds))
		{
			new iRounds = get_pcvar_num(g_pCvars[EXTENDED_ROUNDS]);
			
			if(iWinLimit > 0)
			{
				set_pcvar_num(g_pCvars[WINLIMIT], iWinLimit + iRounds);
			}
			if(iMaxRounds > 0)
			{
				set_pcvar_num(g_pCvars[MAXROUNDS], iMaxRounds + iRounds);
			}
			
			new szRounds[16]; get_ending(iRounds, "MAPM_ROUND1", "MAPM_ROUND2", "MAPM_ROUND3", szRounds, charsmax(szRounds));
			client_print_color(0, print_team_default, "%s^1 %L %L.", PREFIX, LANG_PLAYER, "MAPM_MAP_EXTEND", iRounds, LANG_PLAYER, szRounds);
		}
		else
		{
			new iMin = get_pcvar_num(g_pCvars[EXTENDED_TIME]);
			new szMin[16]; get_ending(iMin, "MAPM_MINUTE1", "MAPM_MINUTE2", "MAPM_MINUTE3", szMin, charsmax(szMin));
			
			client_print_color(0, print_team_default, "%s^1 %L %L.", PREFIX, LANG_PLAYER, "MAPM_MAP_EXTEND", iMin, LANG_PLAYER, szMin);
			set_pcvar_float(g_pCvars[TIMELIMIT], get_pcvar_float(g_pCvars[TIMELIMIT]) + float(iMin));
		}
	}
	
	new iRet;
	ExecuteForward(g_iForwardFinishVote, iRet);
}
///**************************///
stock get_players_num()
{
	new players[32], pnum; get_players(players, pnum, "ch");
	return pnum;
}
stock valid_map(map[])
{
	if(is_map_valid(map)) return true;
	
	new len = strlen(map) - 4;
	
	if(len < 0) return false;
	
	if(equali(map[len], ".bsp"))
	{
		map[len] = '^0';
		if(is_map_valid(map)) return true;
	}
	
	return false;
}
is_map_in_array(map[])
{
	new eMapInfo[MAP_INFO], iSize = ArraySize(g_aMaps);
	for(new i; i < iSize; i++)
	{
		ArrayGetArray(g_aMaps, i, eMapInfo);
		if(equali(map, eMapInfo[m_MapName]))
		{
			return i + 1;
		}
	}
	return 0;
}
#if defined FUNCTION_BLOCK_MAPS
is_map_blocked(Array:array, map[])
{
	new eBlockedInfo[BLOCKEDMAP_INFO], iSize = ArraySize(array);
	for(new i; i < iSize; i++)
	{
		ArrayGetArray(array, i, eBlockedInfo);
		if(equali(map, eBlockedInfo[b_MapName]))
		{
			return i + 1;
		}
	}
	return 0;
}
clear_blocked_maps()
{
	new eMapInfo[MAP_INFO], iSize = ArraySize(g_aMaps);
	for(new i; i < iSize; i++)
	{
		ArrayGetArray(g_aMaps, i, eMapInfo);
		if(eMapInfo[m_BlockCount])
		{
			eMapInfo[m_BlockCount] = 0;
			ArraySetArray(g_aMaps, i, eMapInfo);
		}
	}
	g_iBlockedSize = 0;
}
#endif
is_map_in_menu(index)
{
	for(new i; i < sizeof(g_eMenuItems); i++)
	{
		if(g_eMenuItems[i][v_MapIndex] == index) return true;
	}
	return false;
}
#if defined FUNCTION_NOMINATION
is_map_nominated(map_index)
{
	new eNomInfo[NOMINATEDMAP_INFO], iSize = ArraySize(g_aNominatedMaps);
	for(new i; i < iSize; i++)
	{
		ArrayGetArray(g_aNominatedMaps, i, eNomInfo);
		if(map_index == eNomInfo[n_MapIndex])
		{
			return i + 1;
		}
	}
	return 0;
}
is_map_in_priority(Array:array, map_index)
{
	new ePriorityInfo[VOTEMENU_INFO], iSize = ArraySize(array);
	for(new i; i < iSize; i++)
	{
		ArrayGetArray(array, i, ePriorityInfo);
		if(map_index == ePriorityInfo[v_MapIndex])
		{
			return i + 1;
		}
	}
	return 0;
}
clear_nominated_maps(id)
{
	new eNomInfo[NOMINATEDMAP_INFO];
	for(new i = 0; i < ArraySize(g_aNominatedMaps); i++)
	{
		ArrayGetArray(g_aNominatedMaps, i, eNomInfo);
		if(id == eNomInfo[n_Player])
		{
			ArrayDeleteItem(g_aNominatedMaps, i--);
			if(!--g_iNominatedMaps[id]) break;
		}
	}
}
is_prefix_in_array(prefix[])
{
	new string[32];
	for(new i; i < g_iMapPrefixesNum; i++)
	{
		ArrayGetString(g_aMapPrefixes, i, string, charsmax(string));
		if(equali(prefix, string))
		{
			return true;
		}
	}
	return false;
}
get_map_prefix(map[], prefix[], size)
{
	new map_copy[32]; copy(map_copy, charsmax(map_copy), map);
	for(new i; map_copy[i]; i++)
	{
		if(map_copy[i] == '_')
		{
			map_copy[i + 1] = 0;
			copy(prefix, size, map_copy);
			return 1;
		}
	}
	return 0;
}
find_similar_map(map_index, string[32])
{
	new eMapInfo[MAP_INFO], iSize = ArraySize(g_aMaps);
	for(new i = map_index; i < iSize; i++)
	{
		ArrayGetArray(g_aMaps, i, eMapInfo);
		if(containi(eMapInfo[m_MapName], string) != -1)
		{
			return i + 1;
		}
	}
	return 0;
}
trim_bracket(text[])
{
	for(new i; text[i]; i++)
	{
		if(text[i] == '[')
		{
			text[i] = 0;
			break;
		}
	}
}
string_with_space(string[])
{
	for(new i; string[i]; i++)
	{
		if(string[i] == ' ') return 1;
	}
	return 0;
}
#endif
#if defined FUNCTION_NIGHTMODE
is_map_in_night_array(map[])
{
	new szMapName[32], iMax = ArraySize(g_aNightMaps);
	for(new i = 0; i < iMax; i++)
	{
		ArrayGetString(g_aNightMaps, i, szMapName, charsmax(szMapName));
		if(equali(szMapName, map))
		{
			return i + 1;
		}
	}
	return 0;
}
is_map_in_menu_by_string(map[])
{
	for(new i; i < sizeof(g_eMenuItems); i++)
	{
		if(equali(g_eMenuItems[i][v_MapName], map)) return true;
	}
	return false;
}
get_int_time(string[], &hour, &minutes)
{
	new left[4], right[4]; strtok(string, left, charsmax(left), right, charsmax(right), ':');
	hour = str_to_num(left);
	minutes = str_to_num(right);
}
#endif
stock get_ending(num, const a[], const b[], const c[], output[], lenght)
{
	new num100 = num % 100, num10 = num % 10;
	if(num100 >=5 && num100 <= 20 || num10 == 0 || num10 >= 5 && num10 <= 9) formatex(output, lenght, "%s", a);
	else if(num10 == 1) formatex(output, lenght, "%s", b);
	else if(num10 >= 2 && num10 <= 4) formatex(output, lenght, "%s", c);
}
stock SendAudio(id, audio[], pitch)
{
	static iMsgSendAudio;
	if(!iMsgSendAudio) iMsgSendAudio = get_user_msgid("SendAudio");

	message_begin( id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, iMsgSendAudio, _, id);
	write_byte(id);
	write_string(audio);
	write_short(pitch);
	message_end();
}
stock Intermission()
{
	emessage_begin(MSG_ALL, SVC_INTERMISSION);
	emessage_end();
}
public SetBlackScreenFade(fade)
{
	new time, hold, flags;
	static iMsgScreenFade; 
	if(!iMsgScreenFade) iMsgScreenFade = get_user_msgid("ScreenFade");
	
	switch (fade)
	{
		case 1: { time = 1; hold = 1; flags = 4; }
		case 2: { time = 4096; hold = 1024; flags = 1; }
		default: { time = 4096; hold = 1024; flags = 2; }
	}

	message_begin(MSG_BROADCAST, iMsgScreenFade);
	write_short(time);
	write_short(hold);
	write_short(flags);
	write_byte(0);
	write_byte(0);
	write_byte(0);
	write_byte(255);
	message_end();
}
