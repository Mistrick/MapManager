#include <amxmodx>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#define PLUGIN "Map Manager"
#define VERSION "2.5.8"
#define AUTHOR "Mistrick"

#pragma semicolon 1

///******** Settings ********///

#define FUNCTION_NEXTMAP //replace default nextmap
#define FUNCTION_RTV
#define FUNCTION_NOMINATION
#define FUNCTION_BLOCK_MAPS
#define FUNCTION_SOUND

#define SELECT_MAPS 5
#define PRE_START_TIME 5
#define VOTE_TIME 10

#define NOMINATED_MAPS_IN_MENU 3
#define NOMINATED_MAPS_PER_PLAYER 3

#define BLOCK_MAP_COUNT 10

new const PREFIX[] = "^4[MapManager]";

///**************************///

#if BLOCK_MAP_COUNT <= 1
	#undef FUNCTION_BLOCK_MAPS
#endif

enum (+=100)
{
	TASK_CHECKTIME,
	TASK_SHOWTIMER,
	TASK_TIMER,
	TASK_VOTEMENU
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
	EXENDED_MAX,
	EXENDED_TIME,
#if defined FUNCTION_RTV
	ROCK_MODE,
	ROCK_PERCENT,
	ROCK_PLAYERS,
	ROCK_CHANGE_TYPE,
	ROCK_DELAY,
#endif
	MAXROUNDS,
	WINLIMIT,
	TIMELIMIT,
	FREEZETIME,
	CHATTIME,
	NEXTMAP
};

new const MAPS_FILE[] = "maps.ini";//configdir

#if defined FUNCTION_BLOCK_MAPS
new const FILE_BLOCKEDMAPS[] = "blockedmaps.ini";//datadir
#endif

new g_pCvars[CVARS];
new g_iTeamScore[2];
new g_szCurrentMap[32];
new g_bVoteStarted;
new g_bVoteFinished;

new g_eMenuItems[SELECT_MAPS + 1][VOTEMENU_INFO];
new g_iMenuItemsCount;
new g_iTotalVotes;
new g_iTimer;
new g_bPlayerVoted[33];
new g_iExtendedMax;
new g_bStartVote;
new Float:g_fOldFreezeTime;
new Float:g_fOldTimeLimit;

#if defined FUNCTION_SOUND
new const g_szSound[][] =
{
	"", "sound/fvox/one.wav", "sound/fvox/two.wav", "sound/fvox/three.wav", "sound/fvox/four.wav", "sound/fvox/five.wav",
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
new g_iPage[33];
new g_szMapPrefixes[][] = {"deathrun_", "de_"};
#endif

#if defined FUNCTION_BLOCK_MAPS
new g_iBlockedSize;
#endif

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_cvar("mm_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	g_pCvars[CHANGE_TYPE] = register_cvar("mm_change_type", "2");//0 - after end vote, 1 - in round end, 2 - after end map
	g_pCvars[START_VOTE_BEFORE_END] = register_cvar("mm_start_vote_before_end", "2");//minutes
	g_pCvars[SHOW_RESULT_TYPE] = register_cvar("mm_show_result_type", "1");//0 - disable, 1 - menu, 2 - hud
	g_pCvars[SHOW_SELECTS] = register_cvar("mm_show_selects", "1");//0 - disable, 1 - all
	g_pCvars[START_VOTE_IN_NEW_ROUND] = register_cvar("mm_start_vote_in_new_round", "0");//0 - disable, 1 - enable
	g_pCvars[FREEZE_IN_VOTE] = register_cvar("mm_freeze_in_vote", "0");//0 - disable, 1 - enable, if mm_start_vote_in_new_round 1
	g_pCvars[BLACK_SCREEN_IN_VOTE] = register_cvar("mm_black_screen_in_vote", "0");//0 - disable, 1 - enable
	g_pCvars[LAST_ROUND] = register_cvar("mm_last_round", "0");//0 - disable, 1 - enable
	
	g_pCvars[EXENDED_MAX] = register_cvar("mm_extended_map_max", "3");
	g_pCvars[EXENDED_TIME] = register_cvar("mm_extended_time", "15");//minutes
	
	#if defined FUNCTION_RTV
	g_pCvars[ROCK_MODE] = register_cvar("mm_rtv_mode", "0");//0 - percents, 1 - players
	g_pCvars[ROCK_PERCENT] = register_cvar("mm_rtv_percent", "60");
	g_pCvars[ROCK_PLAYERS] = register_cvar("mm_rtv_players", "5");
	g_pCvars[ROCK_CHANGE_TYPE] = register_cvar("mm_rtv_change_type", "1");//0 - after vote, 1 - in round end
	g_pCvars[ROCK_DELAY] = register_cvar("mm_rtv_delay", "0");//minutes
	#endif
	
	g_pCvars[MAXROUNDS] = get_cvar_pointer("mp_maxrounds");
	g_pCvars[WINLIMIT] = get_cvar_pointer("mp_winlimit");
	g_pCvars[TIMELIMIT] = get_cvar_pointer("mp_timelimit");
	g_pCvars[FREEZETIME] = get_cvar_pointer("mp_freezetime");
	
	g_pCvars[NEXTMAP] = register_cvar("amx_nextmap", "", FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY);
	
	#if defined FUNCTION_NEXTMAP
	g_pCvars[CHATTIME] = get_cvar_pointer("mp_chattime");
	#endif
	
	register_event("TeamScore", "Event_TeamScore", "a");
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
	
	#if defined FUNCTION_NEXTMAP
	register_event("30", "Event_Intermisson", "a");
	#endif
	
	register_concmd("mm_debug", "Commang_Debug", ADMIN_MAP);
	register_concmd("mm_startvote", "Command_StartVote", ADMIN_MAP);
	register_concmd("mm_stopvote", "Command_StopVote", ADMIN_MAP);
	
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
	
	register_menucmd(register_menuid("VoteMenu"), 1023, "VoteMenu_Handler");
	
	#if defined FUNCTION_NOMINATION
	register_menucmd(register_menuid("MapsListMenu"), 1023, "MapsListMenu_Handler");
	#endif
	
	set_task(10.0, "Task_CheckTime", TASK_CHECKTIME, .flags = "b");
}
public Commang_Debug(id)
{
	console_print(id, "^nLoaded maps:");	
	new eMapInfo[MAP_INFO], iSize = ArraySize(g_aMaps);
	for(new i; i < iSize; i++)
	{
		ArrayGetArray(g_aMaps, i, eMapInfo);
		console_print(id, "%3d %32s ^t%d^t%d^t%d", i, eMapInfo[m_MapName], eMapInfo[m_MinPlayers], eMapInfo[m_MaxPlayers], eMapInfo[m_BlockCount]);
	}
	return PLUGIN_HANDLED;
}
public Command_StartVote(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;
	StartVote(id);	
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
		
		remove_task(TASK_VOTEMENU);
		remove_task(TASK_SHOWTIMER);
		remove_task(TASK_TIMER);
		
		for(new i = 1; i <= 32; i++)
			remove_task(TASK_VOTEMENU + i);
		
		show_menu(0, 0, "^n", 1);
		new szName[32];
		
		if(id) get_user_name(id, szName, charsmax(szName));
		else szName = "Server";
		
		client_print_color(0, id, "%s^3 %s^1 отменил голосование.", PREFIX, szName);
	}
	
	return PLUGIN_HANDLED;
}

#if defined FUNCTION_NEXTMAP
public Command_Nextmap(id)
{
	new szMap[32]; get_pcvar_string(g_pCvars[NEXTMAP], szMap, charsmax(szMap));
	client_print_color(0, id, "%s^1 Следующая карта: ^3%s^1.", PREFIX, szMap);
}
public Command_CurrentMap(id)
{
	client_print_color(0, id, "%s^1 Текущая карта:^3 %s^1.", PREFIX, g_szCurrentMap);
}
#endif

#if defined FUNCTION_RTV
public Command_RockTheVote(id)
{
	if(g_bVoteFinished || g_bVoteStarted) return PLUGIN_HANDLED;
	
	new iTime = get_pcvar_num(g_pCvars[ROCK_DELAY]) * 60 - (floatround(get_pcvar_float(g_pCvars[TIMELIMIT]) * 60.0) - get_timeleft());
	if(iTime > 0)
	{
		client_print_color(id, print_team_default, "%s^1 Вы не можете голосовать за досрочную смену карты. Осталось:^3 %d:%02d^1.", PREFIX, iTime / 60, iTime % 60);
		return PLUGIN_HANDLED;
	}
	
	if(!g_bRockVoted[id]) g_iRockVotes++;
	
	new iVotes;
	if(get_pcvar_num(g_pCvars[ROCK_MODE]))
	{
		iVotes = get_pcvar_num(g_pCvars[ROCK_PLAYERS]) - g_iRockVotes;
	}
	else
	{
		iVotes = floatround(GetPlayersNum() * get_pcvar_num(g_pCvars[ROCK_PERCENT]) / 100.0, floatround_ceil) - g_iRockVotes;
	}
	
	if(!g_bRockVoted[id])
	{
		g_bRockVoted[id] = true;		
		
		if(iVotes > 0)
		{
			new szName[33];	get_user_name(id, szName, charsmax(szName));
			new szVote[16];	GetEnding(iVotes, "голосов", "голос", "голоса", szVote, charsmax(szVote));
			client_print_color(0, print_team_default, "%s^3 %s^1 проголосовал за смену карты. Осталось:^3 %d^1 %s.", PREFIX, szName, iVotes, szVote);
		}
		else
		{
			g_bRockVote = true;
			if(!get_pcvar_num(g_pCvars[START_VOTE_IN_NEW_ROUND]))
			{
				StartVote(0);
				client_print_color(0, print_team_default, "%s^1 Начинаем досрочное голосование.", PREFIX);
			}
			else
			{
				g_bStartVote = true;
				client_print_color(0, print_team_default, "%s^1 Голосование начнется в следующем раунде.", PREFIX);
			}
		}
	}
	else
	{
		new szVote[16];	GetEnding(iVotes, "голосов", "голос", "голоса", szVote, charsmax(szVote));
		client_print_color(id, print_team_default, "%s^1 Вы уже голосовали. Осталось:^3 %d^1 %s.", PREFIX, iVotes, szVote);
	}
	
	return PLUGIN_HANDLED;
}
#endif

#if defined FUNCTION_NOMINATION
public Command_Say(id)
{
	if(g_bVoteStarted) return;
	
	new szText[32]; read_args(szText, charsmax(szText));
	remove_quotes(szText); trim(szText); strtolower(szText);
	
	new map_index = is_map_in_array(szText);
	
	if(map_index)
	{
		NominateMap(id, szText, map_index - 1);
	}
	else
	{
		for(new i; i < sizeof(g_szMapPrefixes); i++)
		{
			new szFormat[32]; formatex(szFormat, charsmax(szFormat), "%s%s", g_szMapPrefixes[i], szText);
			map_index = is_map_in_array(szFormat);
			if(map_index)
			{
				NominateMap(id, szFormat, map_index - 1); break;
			}
		}
	}
}
NominateMap(id, map[32], map_index)
{
	#if defined FUNCTION_BLOCK_MAPS
	new eMapInfo[MAP_INFO]; ArrayGetArray(g_aMaps, map_index, eMapInfo);
	if(eMapInfo[m_BlockCount])
	{
		client_print_color(id, print_team_default, "%s^1 Эта карта недоступна для номинации.", PREFIX);
		return PLUGIN_CONTINUE;
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
			g_iNominatedMaps[id]--;
			ArrayDeleteItem(g_aNominatedMaps, nominate_index - 1);
			
			client_print_color(0, id, "%s^3 %s^1 убрал номинацию с карты^3 %s^1.", PREFIX, szName, map);
			return PLUGIN_CONTINUE;
		}
		client_print_color(id, print_team_default, "%s^1 Эта карта уже номинирована.", PREFIX);
		return PLUGIN_CONTINUE;
	}
	
	if(g_iNominatedMaps[id] >= NOMINATED_MAPS_PER_PLAYER)
	{
		client_print_color(id, print_team_default, "%s^1 Вы не можете больше номинировать карты.", PREFIX);
		return PLUGIN_CONTINUE;
	}
	
	eNomInfo[n_MapName] = map;
	eNomInfo[n_Player] = id;
	eNomInfo[n_MapIndex] = map_index;
	ArrayPushArray(g_aNominatedMaps, eNomInfo);
	
	g_iNominatedMaps[id]++;
	
	client_print_color(0, id, "%s^3 %s^1 номинировал на голосование^3 %s^1.", PREFIX, szName, map);
	
	return PLUGIN_CONTINUE;
}
public Command_MapsList(id)
{
	Show_MapsListMenu(id, g_iPage[id] = 0);
}
public Show_MapsListMenu(id, iPage)
{
	if(iPage < 0) return PLUGIN_HANDLED;
	
	new iMax = ArraySize(g_aMaps);
	new i = min(iPage * 8, iMax);
	new iStart = i - (i % 8);
	new iEnd = min(iStart + 8, iMax);
	
	iPage = iStart / 8;
	g_iPage[id] = iPage;
	
	static szMenu[512],	iLen, eMapInfo[MAP_INFO]; iLen = 0;
	
	iLen = formatex(szMenu, charsmax(szMenu), "\yСписок карт \w[%d/%d]:^n", iPage + 1, ((iMax - 1) / 8) + 1);
	
	new Keys, Item, iNominated;

	for (i = iStart; i < iEnd; i++)
	{
		ArrayGetArray(g_aMaps, i, eMapInfo);
	
		iNominated = is_map_nominated(i);
		
		if(eMapInfo[m_BlockCount])
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r%d.\d %s[\r%d\d]", ++Item, eMapInfo[m_MapName], eMapInfo[m_BlockCount]);
		}
		else if(iNominated)
		{
			new eNomInfo[NOMINATEDMAP_INFO]; ArrayGetArray(g_aNominatedMaps, iNominated - 1, eNomInfo);
			if(id == eNomInfo[n_Player])
			{
				Keys |= (1 << Item);
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r%d.\w %s[\y*\w]", ++Item, eMapInfo[m_MapName]);
				
			}
			else
			{
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r%d.\d %s[\y*\d]", ++Item, eMapInfo[m_MapName]);
			}
		}
		else
		{
			Keys |= (1 << Item);
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r%d.\w %s", ++Item, eMapInfo[m_MapName]);
		}
	}
	while(Item <= 8)
	{
		Item++;
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
	}
	if (iEnd < iMax)
	{
		Keys |= (1 << 8)|(1 << 9);		
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9.\w Вперед^n\r0.\w %s", iPage ? "Назад" : "Выход");
	}
	else
	{
		Keys |= (1 << 9);
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\r0.\w %s", iPage ? "Назад" : "Выход");
	}
	show_menu(id, Keys, szMenu, -1, "MapsListMenu");
	return PLUGIN_HANDLED;
}
public MapsListMenu_Handler(id, key)
{
	switch (key)
	{
		case 8: Show_MapsListMenu(id, ++g_iPage[id]);
		case 9: Show_MapsListMenu(id, --g_iPage[id]);
		default:
		{
			new map_index = key + g_iPage[id] * 8;
			new eMapInfo[MAP_INFO]; ArrayGetArray(g_aMaps, map_index, eMapInfo);
			new szMapName[32]; formatex(szMapName, charsmax(szMapName), eMapInfo[m_MapName]);
			NominateMap(id, szMapName, map_index);
			if(g_iNominatedMaps[id] < NOMINATED_MAPS_PER_PLAYER)
			{
				Show_MapsListMenu(id, g_iPage[id]);
			}
		}
	}
	return PLUGIN_HANDLED;
}
#endif
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
		ClearNominatedMaps(id);
	}
	#endif
}
public plugin_end()
{
	if(g_fOldTimeLimit > 0.0)
	{
		set_pcvar_float(g_pCvars[TIMELIMIT], g_fOldTimeLimit);
	}
	if(g_iExtendedMax)
	{
		set_pcvar_float(g_pCvars[TIMELIMIT], get_pcvar_float(g_pCvars[TIMELIMIT]) - float(g_iExtendedMax * get_pcvar_num(g_pCvars[EXENDED_TIME])));
	}
}
public plugin_cfg()
{
	g_aMaps = ArrayCreate(MAP_INFO);
	
	#if defined FUNCTION_NOMINATION
	g_aNominatedMaps = ArrayCreate(NOMINATEDMAP_INFO);
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
		
		new szBuffer[42], szMapName[32], szCount[8], iCount, i = 0;
		
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
			
			if(++i >= BLOCK_MAP_COUNT) break;
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
	formatex(szFile, charsmax(szFile), "%s/%s", szDir, MAPS_FILE);
	
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
				
				if(!szMap[0] || szMap[0] == ';' || !ValidMap(szMap) || is_map_in_array(szMap) || equali(szMap, g_szCurrentMap)) continue;
				
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
				ClearBlockedMaps();
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
	if(iMaxRounds && (g_iTeamScore[0] + g_iTeamScore[1]) >= iMaxRounds - 2)
	{
		log_amx("StartVote: maxrounds %d [%d]", iMaxRounds, g_iTeamScore[0] + g_iTeamScore[1]);
		StartVote(0);
	}
	
	new iWinLimit = get_pcvar_num(g_pCvars[WINLIMIT]) - 2;
	if(iWinLimit > 0 && (g_iTeamScore[0] >= iWinLimit || g_iTeamScore[1] >= iWinLimit))
	{
		log_amx("StartVote: winlimit %d [%d/%d]", iWinLimit, g_iTeamScore[0], g_iTeamScore[1]);
		StartVote(0);
	}
	
	if(g_bStartVote)
	{
		log_amx("StartVote: timeleft %d, new round", get_timeleft());
		StartVote(0);
	}
	
	if(g_bVoteStarted && get_pcvar_num(g_pCvars[FREEZE_IN_VOTE]) && get_pcvar_num(g_pCvars[START_VOTE_IN_NEW_ROUND]))
	{
		g_fOldFreezeTime = get_pcvar_float(g_pCvars[FREEZETIME]);
		set_pcvar_float(g_pCvars[FREEZETIME], float(PRE_START_TIME + VOTE_TIME + 1));
	}
	
	#if defined FUNCTION_RTV
	if(g_bVoteFinished && (g_bRockVote && get_pcvar_num(g_pCvars[ROCK_CHANGE_TYPE]) == 1 || get_pcvar_num(g_pCvars[CHANGE_TYPE]) == 1 || get_pcvar_num(g_pCvars[LAST_ROUND])))
	#else
	if(g_bVoteFinished && (get_pcvar_num(g_pCvars[CHANGE_TYPE]) == 1 || get_pcvar_num(g_pCvars[LAST_ROUND])))
	#endif
	{
		Intermission();
		new szMapName[32]; get_pcvar_string(g_pCvars[NEXTMAP], szMapName, charsmax(szMapName));
		client_print_color(0, print_team_default, "%s^1 Следующая карта:^3 %s^1.", PREFIX, szMapName);
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
	
	new iTimeLeft = get_timeleft();
	if(iTimeLeft <= get_pcvar_num(g_pCvars[START_VOTE_BEFORE_END]) * 60)
	{
		if(!get_pcvar_num(g_pCvars[START_VOTE_IN_NEW_ROUND]))
		{
			log_amx("StartVote: timeleft %d", iTimeLeft);
			StartVote(0);
		}
		else
		{
			g_bStartVote = true;
		}
	}	
	
	return PLUGIN_CONTINUE;
}
public StartVote(id)
{
	if(g_bVoteStarted) return 0;
	
	g_bVoteStarted = true;
	g_bStartVote = false;
	
	ResetInfo();
	
	new Array:aMaps = ArrayCreate(VOTEMENU_INFO), iCurrentSize = 0;
	new eMenuInfo[VOTEMENU_INFO], eMapInfo[MAP_INFO], iGlobalSize = ArraySize(g_aMaps);
	new iPlayersNum = GetPlayersNum();
	
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
	new iMaxItems = min(SELECT_MAPS, iGlobalSize - g_iBlockedSize);
	#else
	new iMaxItems = min(SELECT_MAPS, iGlobalSize);
	#endif
	
	#if defined FUNCTION_NOMINATION
	new eNomInfo[NOMINATEDMAP_INFO];
	new iNomSize = ArraySize(g_aNominatedMaps);	
	g_iMenuItemsCount = min(min(iNomSize, NOMINATED_MAPS_IN_MENU), iMaxItems);
	
	for(new iRandomMap; Item < g_iMenuItemsCount; Item++)
	{
		iRandomMap = random_num(0, ArraySize(g_aNominatedMaps) - 1);
		ArrayGetArray(g_aNominatedMaps, iRandomMap, eNomInfo);
		
		formatex(g_eMenuItems[Item][v_MapName], charsmax(g_eMenuItems[][v_MapName]), eNomInfo[n_MapName]);
		g_eMenuItems[Item][v_MapIndex] = eNomInfo[n_MapIndex];
		
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
		SetBlackScreenFade(1);
	}
	
	#if PRE_START_TIME > 0
	g_iTimer = PRE_START_TIME;
	ShowTimer();
	#else
	ShowVoteMenu();
	#endif
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
	new szSec[16]; GetEnding(g_iTimer, "секунд", "секунда", "секунды", szSec, charsmax(szSec));
	new iPlayers[32], pNum; get_players(iPlayers, pNum, "ch");
	for(new id, i; i < pNum; i++)
	{
		id = iPlayers[i];
		set_hudmessage(50, 255, 50, -1.0, is_user_alive(id) ? 0.9 : 0.3, 0, 0.0, 1.0, 0.0, 0.0, 1);
		show_hudmessage(id, "До голосования осталось %d %s!", g_iTimer, szSec);
	}
	
	#if defined FUNCTION_SOUND
	if(g_iTimer <= 10)
	{
		for(new id, i; i < pNum; i++)
		{
			id = iPlayers[i];
			SendAudio(id, g_szSound[g_iTimer], PITCH_NORM);
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
	
	iLen = formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y%s:^n^n", g_bPlayerVoted[id] ? "Результаты голосования" : "Выберите карту");
	
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
	
	#if defined FUNCTION_RTV
	if(!g_bRockVote && g_iExtendedMax < get_pcvar_num(g_pCvars[EXENDED_MAX]))
	#else
	if(g_iExtendedMax < get_pcvar_num(g_pCvars[EXENDED_MAX]))
	#endif
	{
		iPercent = 0;
		if(g_iTotalVotes)
		{
			iPercent = floatround(g_eMenuItems[i][v_Votes] * 100.0 / g_iTotalVotes);
		}
		
		if(!g_bPlayerVoted[id])
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r%d.\w %s\d[\r%d%%\d]\y[Продлить]^n", i + 1, g_szCurrentMap, iPercent);	
			iKeys |= (1 << i);
		}
		else
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\d%s[\r%d%%\d]\y[Продлить]^n", g_szCurrentMap, iPercent);
		}
	}
	
	new szSec[16]; GetEnding(g_iTimer, "секунд", "секунда", "секунды", szSec, charsmax(szSec));
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\dОсталось \r%d\d %s", g_iTimer, szSec);
	
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
			client_print_color(0, id, "^4%s^1 ^3%s^1 выбрал продление карты.", PREFIX, szName);
		}
		else
		{
			client_print_color(0, id, "^4%s^3 %s^1 выбрал^3 %s^1.", PREFIX, szName, g_eMenuItems[key][v_MapName]);
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
	
	if(get_pcvar_num(g_pCvars[FREEZE_IN_VOTE]))
	{
		set_pcvar_float(g_pCvars[FREEZETIME], g_fOldFreezeTime);
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
	
	if(!g_iTotalVotes || (iMaxVote != g_iMenuItemsCount))
	{
		if(g_iTotalVotes)
		{
			client_print_color(0, print_team_default, "%s^1 Следующая карта:^3 %s^1.", PREFIX, g_eMenuItems[iMaxVote][v_MapName]);
		}
		else
		{
			iMaxVote = random_num(0, g_iMenuItemsCount - 1);
			client_print_color(0, print_team_default, "%s^1 Никто не голосовал. Следуйщей будет^3 %s^1.", PREFIX, g_eMenuItems[iMaxVote][v_MapName]);
		}
		set_pcvar_string(g_pCvars[NEXTMAP], g_eMenuItems[iMaxVote][v_MapName]);
		
		if(get_pcvar_num(g_pCvars[LAST_ROUND]))
		{
			g_fOldTimeLimit = get_pcvar_float(g_pCvars[TIMELIMIT]);
			set_pcvar_float(g_pCvars[TIMELIMIT], 0.0);
			client_print_color(0, print_team_default, "%s^1 Это последний раунд.", PREFIX);
		}
		#if defined FUNCTION_RTV
		else if(g_bRockVote && get_pcvar_num(g_pCvars[ROCK_CHANGE_TYPE]) == 0 || get_pcvar_num(g_pCvars[CHANGE_TYPE]) == 0)
		#else
		else if(get_pcvar_num(g_pCvars[CHANGE_TYPE]) == 0)
		#endif
		{
			client_print_color(0, print_team_default, "%s^1 Карта сменится через^3 5^1 секунд.", PREFIX);
			Intermission();
		}
		#if defined FUNCTION_RTV
		else if(g_bRockVote && get_pcvar_num(g_pCvars[ROCK_CHANGE_TYPE]) == 1 || get_pcvar_num(g_pCvars[CHANGE_TYPE]) == 1)
		#else
		else if(get_pcvar_num(g_pCvars[CHANGE_TYPE]) == 1)
		#endif
		{
			client_print_color(0, print_team_default, "%s^1 Карта сменится в следующем раунде.", PREFIX);
		}
		
	}
	else
	{
		g_bVoteFinished = false;
		g_iExtendedMax++;
		new iMin = get_pcvar_num(g_pCvars[EXENDED_TIME]);
		new szMin[16]; GetEnding(iMin, "минут", "минута", "минуты", szMin, charsmax(szMin));
		
		client_print_color(0, print_team_default, "^4%s^1 Текущая карта продлена на^3 %d^1 %s.", PREFIX, iMin, szMin);
		set_pcvar_float(g_pCvars[TIMELIMIT], get_pcvar_float(g_pCvars[TIMELIMIT]) + float(iMin));
	}
}
///**************************///
stock GetPlayersNum()
{
	new count = 0;
	for(new i = 1; i < 33; i++)
	{
		if(is_user_connected(i) && !is_user_bot(i) && !is_user_hltv(i)) count++;
	}
	return count;
}
stock ValidMap(map[])
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
stock is_map_in_array(map[])
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
ClearBlockedMaps()
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
stock is_map_in_menu(index)
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
ClearNominatedMaps(id)
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
#endif
stock GetEnding(num, const a[], const b[], const c[], output[], lenght)
{
	new num100 = num % 100, num10 = num % 10;
	if(num100 >=5 && num100 <= 20 || num10 == 0 || num10 >= 5 && num10 <= 9) format(output, lenght, "%s", a);
	else if(num10 == 1) format(output, lenght, "%s", b);
	else if(num10 >= 2 && num10 <= 4) format(output, lenght, "%s", c);
}
stock SendAudio(id, audio[], pitch)
{
	static iMsgSendAudio;
	if(!iMsgSendAudio) iMsgSendAudio = get_user_msgid("SendAudio");
	
	if(id)
	{
		message_begin(MSG_ONE_UNRELIABLE, iMsgSendAudio, _, id);
		write_byte(id);
		write_string(audio);
		write_short(pitch);
		message_end();
	}
	else
	{
		new iPlayers[32], pNum; get_players(iPlayers, pNum, "ch");
		for(new id, i; i < pNum; i++)
		{
			id = iPlayers[i];
			message_begin(MSG_ONE_UNRELIABLE, iMsgSendAudio, _, id);
			write_byte(id);
			write_string(audio);
			write_short(pitch);
			message_end();
		}
	}
}
stock Intermission()
{
	emessage_begin(MSG_ALL, SVC_INTERMISSION);
	emessage_end();
}
stock SetBlackScreenFade(fade)
{
	new time, hold, flags;
	static iMsgScreenFade; 
	if(!iMsgScreenFade) iMsgScreenFade = get_user_msgid("ScreenFade");
	
	switch (fade)
	{
		case 1:
		{
			time = 1;
			hold = 1;
			flags = 4;
		}	
		default:
		{
			time = 4096;
			hold = 1024;
			flags = 2;
		}
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
