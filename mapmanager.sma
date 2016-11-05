#include <amxmodx>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#define PLUGIN "Map Manager"
#define VERSION "3.0.88"
#define AUTHOR "Mistrick"

#pragma semicolon 1

///******** Settings ********///

#define FUNCTION_NEXTMAP //replace default nextmap
//#define FUNCTION_RTV
#define FUNCTION_NOMINATION
//#define FUNCTION_NIGHTMODE
#define FUNCTION_NIGHTMODE_BLOCK_CMDS
#define FUNCTION_BLOCK_MAPS
#define FUNCTION_SOUND

#define SELECT_MAPS 5
#define PRE_START_TIME 3
#define VOTE_TIME 5

#define NOMINATED_MAPS_IN_VOTE 3
#define NOMINATED_MAPS_PER_PLAYER 3

#define BLOCK_MAP_COUNT 5

#define MIN_DENOMINATE_TIME 3 // seconds

new const PREFIX[] = "^4[MapManager]";

///**************************///

new const FILE_MAPS[] = "maps.ini"; //configdir

new const FILE_BLOCKED_MAPS[] = "blockedmaps.ini"; //datadir

new const FILE_NIGHT_MAPS[] = "nightmaps.ini"; //configdir

///**************************///

#define MAX_ITEMS 8
#define MAP_NAME_LENGTH 32

///**************************///

enum _:MapsListStruct
{
	m_MapName[MAP_NAME_LENGTH],
	m_MinPlayers,
	m_MaxPlayers,
	m_BlockCount
};

enum MapsListIndexes
{
	MapsListEnd,
	NightListStart,
	NightListEnd
};

enum _:NominationStruct
{
	n_MapName[MAP_NAME_LENGTH],
	n_Player,
	n_MapIndex
};

enum _:VoteMenuStruct
{
	v_MapName[MAP_NAME_LENGTH],
	v_MapIndex,
	v_Votes
};

enum BlockLists
{
	DayList,
	NightList
};

enum Cvars
{
	CHANGE_TYPE,
	SHOW_RESULT_TYPE,
	SECOND_VOTE,
	SECOND_VOTE_PERCENT,
	EXTENDED_TYPE,
	EXTENDED_MAX,
	EXTENDED_TIME,
	EXTENDED_ROUNDS,
	MAXROUNDS,
	WINLIMIT,
	TIMELIMIT,
	FREEZETIME,
	CHATTIME,
	NEXTMAP,
};

enum Forwards
{
	_StartTimer,
	_TimerCount,
	_StartVote,
	_FinishVote
};

enum _:Tasks(+=100)
{
	TASK_TIMER = 150,
	TASK_VOTEMENU
};

new g_pCvars[Cvars];
new g_hForward[Forwards];

new Array:g_aMapsList;
new g_iMapsListIndexes[MapsListIndexes];

new Array:g_aMapsPrefixes;
new g_iMapsPrefixesNum;

new g_iBlockedMaps[BlockLists];

new Array:g_aNominationList;

new bool:g_bVoteStarted;
new bool:g_bVoteFinished;

new g_eVoteMenu[SELECT_MAPS + 1][VoteMenuStruct];
new g_iVoteItems;
new g_iTotalVotes;

new g_iTimer;

new bool:g_bNight;

new bool:g_bPlayerVoted[33];

new g_szCurMap[MAP_NAME_LENGTH];

new g_bCanExtend;
new g_iExtendedNum;

new g_iTeamScore[2];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_cvar("mapm_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);

	g_pCvars[CHANGE_TYPE] = register_cvar("mapm_change_type", "0"); // 0 - after end vote, 1 - in round end, 2 - after end map
	g_pCvars[SHOW_RESULT_TYPE] = register_cvar("mapm_show_result_type", "1");//0 - disable, 1 - menu, 2 - hud

	g_pCvars[SECOND_VOTE] = register_cvar("mapm_second_vote", "0"); // 0 - disable, 1 - enable
	g_pCvars[SECOND_VOTE_PERCENT] = register_cvar("mapm_second_vote_percent", "50");

	g_pCvars[EXTENDED_TYPE] = register_cvar("mapm_extended_type", "0"); //0 - minutes, 1 - rounds
	g_pCvars[EXTENDED_MAX] = register_cvar("mapm_extended_map_max", "3");
	g_pCvars[EXTENDED_TIME] = register_cvar("mapm_extended_time", "15"); //minutes
	g_pCvars[EXTENDED_ROUNDS] = register_cvar("mapm_extended_rounds", "3"); //rounds
	
	g_pCvars[MAXROUNDS] = get_cvar_pointer("mp_maxrounds");
	g_pCvars[WINLIMIT] = get_cvar_pointer("mp_winlimit");
	g_pCvars[TIMELIMIT] = get_cvar_pointer("mp_timelimit");
	g_pCvars[FREEZETIME] = get_cvar_pointer("mp_freezetime");

	g_pCvars[NEXTMAP] = register_cvar("amx_nextmap", "", FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY);

	#if defined FUNCTION_NEXTMAP
	g_pCvars[CHATTIME] = get_cvar_pointer("mp_chattime");
	#endif // FUNCTION_NEXTMAP

	register_concmd("mapm_debug", "Command_Debug", ADMIN_MAP);
	register_concmd("mapm_startvote", "Command_StartVote", ADMIN_MAP);
	register_concmd("mapm_stopvote", "Command_StopVote", ADMIN_MAP);

	g_hForward[_StartTimer] = CreateMultiForward("mapmanager_start_timer", ET_IGNORE);
	g_hForward[_TimerCount] = CreateMultiForward("mapmanager_timer_count", ET_IGNORE, FP_CELL);
	g_hForward[_StartVote] = CreateMultiForward("mapmanager_start_vote", ET_IGNORE);
	g_hForward[_FinishVote] = CreateMultiForward("mapmanager_finish_vote", ET_IGNORE);

	register_menucmd(register_menuid("VoteMenu"), 1023, "VoteMenu_Handler");

	register_event("TeamScore", "Event_TeamScore", "a");
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");

	#if defined FUNCTION_NEXTMAP
	register_event("30", "Event_Intermisson", "a");
	#endif // FUNCTION_NEXTMAP
}
public plugin_cfg()
{
	g_aMapsList = ArrayCreate(MapsListStruct);
	g_aMapsPrefixes = ArrayCreate(MAP_NAME_LENGTH);
	g_aNominationList = ArrayCreate(NominationStruct);

	new Trie:trie_blocked_maps = TrieCreate();

	LoadBlockedMaps(trie_blocked_maps);
	LoadMapFile(trie_blocked_maps);
	LoadMapFile(trie_blocked_maps, true);

	TrieDestroy(trie_blocked_maps);

	register_dictionary("mapmanager.txt");

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
	#endif // FUNCTION_NEXTMAP
}
LoadBlockedMaps(Trie:trie_blocked_maps)
{
	new file_dir[128]; get_localinfo("amxx_datadir", file_dir, charsmax(file_dir));
	new file_path[128]; formatex(file_path, charsmax(file_path), "%s/%s", file_dir, FILE_BLOCKED_MAPS);

	new cur_map[MAP_NAME_LENGTH]; get_mapname(cur_map, charsmax(cur_map)); strtolower(cur_map);
	copy(g_szCurMap, charsmax(g_szCurMap), cur_map);
	
	TrieSetCell(trie_blocked_maps, cur_map, 1);

	new file, temp;

	if(file_exists(file_path))
	{
		new temp_file_path[128]; formatex(temp_file_path, charsmax(temp_file_path), "%s/temp.ini", file_dir);
		file = fopen(file_path, "rt");
		temp = fopen(temp_file_path, "wt");

		new buffer[40], map[MAP_NAME_LENGTH], str_count[8], count;
		
		while(!feof(file))
		{
			fgets(file, buffer, charsmax(buffer));
			parse(buffer, map, charsmax(map), str_count, charsmax(str_count));

			strtolower(map);
			
			if(!is_map_valid(map) || TrieKeyExists(trie_blocked_maps, map)) continue;
			
			count = str_to_num(str_count) - 1;
			
			if(count <= 0) continue;
			
			if(count > BLOCK_MAP_COUNT)
			{
				count = BLOCK_MAP_COUNT;
			}

			fprintf(temp, "^"%s^" ^"%d^"^n", map, count);
			
			TrieSetCell(trie_blocked_maps, map, count);
		}
		
		fprintf(temp, "^"%s^" ^"%d^"^n", cur_map, BLOCK_MAP_COUNT);
		
		fclose(file);
		fclose(temp);
		
		delete_file(file_path);
		rename_file(temp_file_path, file_path, 1);
	}
	else
	{
		file = fopen(file_path, "wt");
		if(file)
		{
			fprintf(file, "^"%s^" ^"%d^"^n", cur_map, BLOCK_MAP_COUNT);
		}
		fclose(file);
	}
}
LoadMapFile(Trie:trie_blocked_maps, load_night_maps = false)
{
	new file_path[128]; get_localinfo("amxx_configsdir", file_path, charsmax(file_path));
	format(file_path, charsmax(file_path), "%s/%s", file_path, load_night_maps ? FILE_NIGHT_MAPS : FILE_MAPS);

	if(!load_night_maps && !file_exists(file_path))
	{
		set_fail_state("Maps file doesn't exist.");
	}

	if(load_night_maps)
	{
		g_iMapsListIndexes[NightListStart] = ArraySize(g_aMapsList);
	}

	new cur_map[MAP_NAME_LENGTH]; get_mapname(cur_map, charsmax(cur_map));
	new file = fopen(file_path, "rt");
	
	if(file)
	{
		new map_info[MapsListStruct], text[48], map[MAP_NAME_LENGTH], min[3], max[3], prefix[MAP_NAME_LENGTH];
		new nextmap = false, founded_nextmap = false;

		while(!feof(file))
		{
			fgets(file, text, charsmax(text));
			parse(text, map, charsmax(map), min, charsmax(min), max, charsmax(max));
			
			strtolower(map);

			if(!map[0] || map[0] == ';' || !valid_map(map) || is_map_in_array(map, load_night_maps)) continue;
			
			if(equali(map, cur_map))
			{
				nextmap = true;
				continue;
			}
			if(nextmap)
			{
				nextmap = false;
				founded_nextmap = true;
				set_pcvar_string(g_pCvars[NEXTMAP], map);
			}

			if(get_map_prefix(map, prefix, charsmax(prefix)) && !is_prefix_in_array(prefix))
			{
				ArrayPushString(g_aMapsPrefixes, prefix);
				g_iMapsPrefixesNum++;
			}
			
			map_info[m_MapName] = map;
			map_info[m_MinPlayers] = str_to_num(min);
			map_info[m_MaxPlayers] = str_to_num(max) == 0 ? 32 : str_to_num(max);
			
			if(TrieKeyExists(trie_blocked_maps, map))
			{
				TrieGetCell(trie_blocked_maps, map, map_info[m_BlockCount]);
				g_iBlockedMaps[load_night_maps ? NightList : DayList]++;
			}

			ArrayPushArray(g_aMapsList, map_info);
			min = ""; max = ""; map_info[m_BlockCount] = 0;
		}
		fclose(file);
		
		new size = ArraySize(g_aMapsList);

		if(!load_night_maps && size == 0)
		{
			set_fail_state("Nothing loaded from file.");
		}

		g_iMapsListIndexes[load_night_maps ? NightListEnd : MapsListEnd] = size;

		if(!founded_nextmap)
		{

		}
	}
}
public plugin_end()
{
	if(g_iExtendedNum)
	{
		if(get_pcvar_num(g_pCvars[EXTENDED_TYPE]))
		{
			new win_limit = get_pcvar_num(g_pCvars[WINLIMIT]);
			if(win_limit)
			{
				set_pcvar_num(g_pCvars[WINLIMIT], win_limit - g_iExtendedNum * get_pcvar_num(g_pCvars[EXTENDED_ROUNDS]));
			}
			new max_rounds = get_pcvar_num(g_pCvars[MAXROUNDS]);
			if(max_rounds)
			{
				set_pcvar_num(g_pCvars[MAXROUNDS], max_rounds - g_iExtendedNum * get_pcvar_num(g_pCvars[EXTENDED_ROUNDS]));
			}
		}
		else
		{
			new restored_value = get_pcvar_num(g_pCvars[TIMELIMIT]) - g_iExtendedNum * get_pcvar_num(g_pCvars[EXTENDED_TIME]);
			set_pcvar_num(g_pCvars[TIMELIMIT], restored_value);
		}
	}
}
public Event_TeamScore()
{
	new team[2]; read_data(1, team, charsmax(team));
	g_iTeamScore[(team[0]=='C') ? 0 : 1] = read_data(2);
}
public Event_NewRound()
{
	if(g_bVoteFinished)
	{

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
#endif // FUNCTION_NEXTMAP
public Command_Debug(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;

	console_print(id, "^nLoaded maps:");	
	new map_info[MapsListStruct];
	for(new i; i < g_iMapsListIndexes[MapsListEnd]; i++)
	{
		ArrayGetArray(g_aMapsList, i, map_info);
		console_print(id, "%3d %32s ^t%d^t%d^t%d", i + 1, map_info[m_MapName], map_info[m_MinPlayers], map_info[m_MaxPlayers], map_info[m_BlockCount]);
	}
	console_print(id, "Night maps:");
	for(new i = g_iMapsListIndexes[NightListStart]; i < g_iMapsListIndexes[NightListEnd]; i++)
	{
		ArrayGetArray(g_aMapsList, i, map_info);
		console_print(id, "%3d %32s ^t%d^t%d^t%d", i + 1, map_info[m_MapName], map_info[m_MinPlayers], map_info[m_MaxPlayers], map_info[m_BlockCount]);
	}

	console_print(id, "^nLoaded prefixes:");
	for(new i, prefix[MAP_NAME_LENGTH]; i < g_iMapsPrefixesNum; i++)
	{
		ArrayGetString(g_aMapsPrefixes, i, prefix, charsmax(prefix));
		console_print(id, "%s", prefix);
	}

	return PLUGIN_HANDLED;
}
public Command_StartVote(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;

	PrepareVote();

	//TODO: log this

	return PLUGIN_HANDLED;
}
public Command_StopVote(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;

	//TODO: log this

	return PLUGIN_HANDLED;
}
PrepareVote(second_vote = false)
{
	if(g_bVoteStarted) return 0;

	ResetValues();

	if(second_vote)
	{
		// vote with 2 top voted maps

		return 1;
	}

	// standart vote
	new start, end;

	if(g_bNight)
	{
		start = g_iMapsListIndexes[NightListStart];
		end = g_iMapsListIndexes[NightListEnd];
	}
	else
	{
		start = 0;
		end = g_iMapsListIndexes[MapsListEnd];
	}

	new items = 0;
	new menu_max_items = min(min(end - start - g_iBlockedMaps[g_bNight ? NightList : DayList], SELECT_MAPS), MAX_ITEMS);

	if(menu_max_items <= 0)
	{
		//log_amx("PrepareVote: All maps are blocked.");
		return 0;
	}

	//TODO: add nominated maps to vote

	new Array:array_maps_range = ArrayCreate(VoteMenuStruct);
	new map_info[MapsListStruct];
	new vote_item_info[VoteMenuStruct];
	new players_num = _get_players_num();

	for(new i = start; i < end; i++)
	{
		ArrayGetArray(g_aMapsList, i, map_info);

		if(!map_info[m_BlockCount] && map_info[m_MinPlayers] <= players_num <= map_info[m_MaxPlayers])
		{
			copy(vote_item_info[v_MapName], charsmax(vote_item_info[v_MapName]), map_info[m_MapName]);
			vote_item_info[v_MapIndex] = i;
			ArrayPushArray(array_maps_range, vote_item_info);
		}
	}

	if(items < menu_max_items)
	{
		for(new random_map, size = ArraySize(array_maps_range); size && items < menu_max_items; items++)
		{
			random_map = random(size);
			ArrayGetArray(array_maps_range, random_map, vote_item_info);

			copy(g_eVoteMenu[items][v_MapName], charsmax(g_eVoteMenu[][v_MapName]), vote_item_info[v_MapName]);
			g_eVoteMenu[items][v_MapIndex] = vote_item_info[v_MapIndex];

			ArrayDeleteItem(array_maps_range, random_map);
			size = ArraySize(array_maps_range);
		}
	}

	ArrayDestroy(array_maps_range);

	if(items < menu_max_items)
	{
		for(new random_map; items < menu_max_items; items++)
		{
			do {
				random_map = random_num(start, end - 1);
				ArrayGetArray(g_aMapsList, random_map, map_info);
			} while(map_info[m_BlockCount] || is_map_in_menu(random_map));

			copy(g_eVoteMenu[items][v_MapName], charsmax(g_eVoteMenu[][v_MapName]), map_info[m_MapName]);
			g_eVoteMenu[items][v_MapIndex] = random_map;
		}
	}

	g_iVoteItems = items;

	if((g_bCanExtend = allow_map_extend()))
	{
		copy(g_eVoteMenu[items][v_MapName], charsmax(g_eVoteMenu[][v_MapName]), g_szCurMap);
	}

	server_print("Prepare vote:");
	for(new i; i < items; i++)
	{
		server_print("%d. %s", i + 1, g_eVoteMenu[i][v_MapName]);
	}

	StartTimerTask();

	return 1;
}
allow_map_extend()
{
	new bAllow = get_pcvar_num(g_pCvars[EXTENDED_TYPE]) == 1 && (get_pcvar_num(g_pCvars[MAXROUNDS]) || get_pcvar_num(g_pCvars[WINLIMIT]));
	
	#if defined FUNCTION_RTV
	if(!g_bRtvVote && get_pcvar_num(g_pCvars[EXTENDED_MAX]) > g_iExtendedNum && (get_pcvar_float(g_pCvars[TIMELIMIT]) > 0.0  || bAllow))
	#else
	if(get_pcvar_num(g_pCvars[EXTENDED_MAX]) > g_iExtendedNum && (get_pcvar_float(g_pCvars[TIMELIMIT]) > 0.0  || bAllow))
	#endif // FUNCTION_RTV
	{
		return 1;
	}
	else
	{
		return 0;
	}
	return 0;
}
ResetValues()
{
	for(new i; i < sizeof(g_eVoteMenu); i++)
	{
		g_eVoteMenu[i][v_MapName] = "";
		g_eVoteMenu[i][v_MapIndex] = -1;
		g_eVoteMenu[i][v_Votes] = 0;
	}
	arrayset(g_bPlayerVoted, false, 33);
	g_iTotalVotes = 0;
	//TODO: Add reset for rtv
}
StartTimerTask()
{
	new ret; ExecuteForward(g_hForward[_StartTimer], ret);

	#if PRE_START_TIME > 0
	Task_PreStartTimer(PRE_START_TIME + 1);
	#else
	StartVote();
	#endif
}
public Task_PreStartTimer(time)
{
	if(--time > 0)
	{
		new ret; ExecuteForward(g_hForward[_TimerCount], ret, time);
		set_task(1.0, "Task_PreStartTimer", time);
	}
	else
	{
		StartVote();
	}
}
StartVote()
{
	new ret; ExecuteForward(g_hForward[_StartVote], ret);

	g_bVoteStarted = true;

	//Show menu
	//TODO: add option - show percent only after vote

	//Start timer for end vote
	g_iTimer = VOTE_TIME + 1;
	Task_VoteTimer();
}
public Task_VoteTimer()
{
	if(--g_iTimer > 0)
	{
		for(new id = 1; id < 33; id++)
		{
			if(!is_user_connected(id) || g_bPlayerVoted[id] && !get_pcvar_num(g_pCvars[SHOW_RESULT_TYPE])) continue;

			Show_VoteMenu(id);
		}
		set_task(1.0, "Task_VoteTimer", TASK_TIMER);
	}
	else
	{
		show_menu(0, 0, "^n", 1);
		FinishVote();
	}
}
public Show_VoteMenu(id)
{
	static menu[512];
	new len, keys, percent, item;

	len = formatex(menu, charsmax(menu), "\y%L:^n^n", id, g_bPlayerVoted[id] ? "MAPM_MENU_VOTE_RESULTS" : "MAPM_MENU_CHOOSE_MAP");
	
	for(item = 0; item < g_iVoteItems + g_bCanExtend; item++)
	{
		percent = 0;
		if(g_iTotalVotes)
		{
			percent = floatround(g_eVoteMenu[item][v_Votes] * 100.0 / g_iTotalVotes);
		}

		if(item == g_iVoteItems)
		{
			len += formatex(menu[len], charsmax(menu) - len, "^n");
		}

		if(!g_bPlayerVoted[id])
		{
			len += formatex(menu[len], charsmax(menu) - len, "\r%d.\w %s\d[\r%d%%\d]", item + 1, g_eVoteMenu[item][v_MapName], percent);
			keys |= (1 << item);
		}
		else
		{
			len += formatex(menu[len], charsmax(menu) - len, "\d%s[\r%d%%\d]", g_eVoteMenu[item][v_MapName], percent);
		}

		if(item == g_iVoteItems)
		{
			len += formatex(menu[len], charsmax(menu) - len, "\y[%L]^n", id, "MAPM_MENU_EXTEND");
		}
		else
		{
			len += formatex(menu[len], charsmax(menu) - len, "^n");
		}
	}

	len += formatex(menu[len], charsmax(menu) - len, "^n\d%L \r%d\d %L", id, "MAPM_MENU_LEFT", g_iTimer, id, "MAPM_SECONDS");

	if(!keys) keys = (1 << 9);

	if(g_bPlayerVoted[id] && get_pcvar_num(g_pCvars[SHOW_RESULT_TYPE]) == 2)
	{
		while(replace(menu, charsmax(menu), "\r", "")){}
		while(replace(menu, charsmax(menu), "\d", "")){}
		while(replace(menu, charsmax(menu), "\w", "")){}
		while(replace(menu, charsmax(menu), "\y", "")){}
		
		set_hudmessage(0, 55, 255, 0.02, -1.0, 0, 6.0, 1.0, 0.1, 0.2, 4);
		show_hudmessage(id, "%s", menu);
	}
	else
	{
		show_menu(id, keys, menu, -1, "VoteMenu");
	}
}
public VoteMenu_Handler(id, key)
{
	if(g_bPlayerVoted[id])
	{
		Show_VoteMenu(id);
		return PLUGIN_HANDLED;
	}
	
	g_eVoteMenu[key][v_Votes]++;
	g_iTotalVotes++;
	g_bPlayerVoted[id] = true;

	// add chat output

	if(get_pcvar_num(g_pCvars[SHOW_RESULT_TYPE]))
	{
		Show_VoteMenu(id);
	}
	
	return PLUGIN_HANDLED;
}
FinishVote()
{
	new ret; ExecuteForward(g_hForward[_FinishVote], ret);

	g_bVoteStarted = false;
	g_bVoteFinished = true;

	server_print("Vote finished");
	//Check votes
	new max_vote = 0;
	for(new i = 1; i < g_iVoteItems + 1; i++)
	{
		if(g_eVoteMenu[max_vote][v_Votes] < g_eVoteMenu[i][v_Votes]) max_vote = i;
	}

	if(max_vote == g_iVoteItems)
	{
		// map extended
		g_bVoteFinished = false;

		g_iExtendedNum++;

		new win_limit = get_pcvar_num(g_pCvars[WINLIMIT]);
		new max_rounds = get_pcvar_num(g_pCvars[MAXROUNDS]);

		if(get_pcvar_num(g_pCvars[EXTENDED_TYPE]) == 1 && (win_limit || max_rounds))
		{
			new rounds = get_pcvar_num(g_pCvars[EXTENDED_ROUNDS]);
			
			if(win_limit > 0)
			{
				set_pcvar_num(g_pCvars[WINLIMIT], win_limit + rounds);
			}
			if(max_rounds > 0)
			{
				set_pcvar_num(g_pCvars[MAXROUNDS], max_rounds + rounds);
			}
			
			client_print_color(0, print_team_default, "%s^1 %L %L.", PREFIX, LANG_PLAYER, "MAPM_MAP_EXTEND", rounds, LANG_PLAYER, "MAPM_ROUNDS");
		}
		else
		{
			new min = get_pcvar_num(g_pCvars[EXTENDED_TIME]);
			
			client_print_color(0, print_team_default, "%s^1 %L %L.", PREFIX, LANG_PLAYER, "MAPM_MAP_EXTEND", min, LANG_PLAYER, "MAPM_MINUTES");
			set_pcvar_float(g_pCvars[TIMELIMIT], get_pcvar_float(g_pCvars[TIMELIMIT]) + float(min));
		}

		server_print("map extended");
		return 1;
	}

	/*new percent = floatround(g_eVoteMenu[max_vote][v_Votes] * 100.0 / g_iTotalVotes);

	if(g_eVoteMenu[max_vote][v_Votes] && get_pcvar_num(g_pCvars[SECOND_VOTE]) && percent < get_pcvar_num(g_pCvars[SECOND_VOTE_PERCENT]))
	{
		server_print("second vote");
		change_vote_items(max_vote, 0);
		




		PrepareVote(true);
		return 1;
	}*/

	if(!g_eVoteMenu[max_vote][v_Votes])
	{
		// no one voted
		max_vote = random(g_iVoteItems);
		server_print("no one voted, random next map %s", g_eVoteMenu[max_vote][v_MapName]);
	}

	server_print("max vote map %s, votes %d", g_eVoteMenu[max_vote][v_MapName], g_eVoteMenu[max_vote][v_Votes]);

	set_pcvar_string(g_pCvars[NEXTMAP], g_eVoteMenu[max_vote][v_MapName]);
	// output

	return 1;
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
is_map_in_array(map[], night_maps)
{
	new start = night_maps ? g_iMapsListIndexes[NightListStart] : 0, end = ArraySize(g_aMapsList);
	new map_info[MapsListStruct];
	for(new i = start; i < end; i++)
	{
		ArrayGetArray(g_aMapsList, i, map_info);
		if(equali(map, map_info[m_MapName])) return i + 1;
	}
	return 0;
}
is_prefix_in_array(prefix[])
{
	for(new i, str[MAP_NAME_LENGTH]; i < g_iMapsPrefixesNum; i++)
	{
		ArrayGetString(g_aMapsPrefixes, i, str, charsmax(str));
		if(equali(prefix, str)) return true;
	}
	return false;
}
get_map_prefix(map[], prefix[], size)
{
	copy(prefix, size, map);
	for(new i; prefix[i]; i++)
	{
		if(prefix[i] == '_')
		{
			prefix[i + 1] = 0;
			return 1;
		}
	}
	return 0;
}
_get_players_num()
{
	new players[32], pnum; get_players(players, pnum, "ch");
	return pnum;
}
is_map_in_menu(index)
{
	for(new i; i < sizeof(g_eVoteMenu); i++)
	{
		if(g_eVoteMenu[i][v_MapIndex] == index) return true;
	}
	return false;
}
/*change_vote_items(first, second)
{
	new vote_info[VoteMenuStruct];
	vote_info[v_MapName] = g_eVoteMenu[second][v_MapName];
	vote_info[v_Votes] = g_eVoteMenu[second][v_Votes];
	vote_info[v_MapIndex] = g_eVoteMenu[second][v_MapIndex];
	g_eVoteMenu[second][v_MapName] = g_eVoteMenu[first][v_MapName];
	g_eVoteMenu[second][v_Votes] = g_eVoteMenu[first][v_Votes];
	g_eVoteMenu[second][v_MapIndex] = g_eVoteMenu[first][v_MapIndex];
	g_eVoteMenu[first][v_MapName] = vote_info[v_MapName];
	g_eVoteMenu[first][v_Votes] = vote_info[v_Votes];
	g_eVoteMenu[first][v_MapIndex] = vote_info[v_MapIndex];
}*/
