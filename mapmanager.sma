#include <amxmodx>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#define PLUGIN "Map Manager"
#define VERSION "3.0.28"
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

#define MIN_DENOMINATE_TIME 3 // seconds

new const PREFIX[] = "^4[MapManager]";

///**************************///

new const FILE_MAPS[] = "maps.ini"; //configdir

new const FILE_BLOCKED_MAPS[] = "blockedmaps.ini"; //datadir

new const FILE_NIGHT_MAPS[] = "nightmaps.ini"; //configdir

///**************************///

enum _:MapsListStruct
{
	m_MapName[32],
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

enum Cvars
{
	CHANGE_TYPE
};

new g_pCvars[Cvars];

new Array:g_aMapsList;
new g_iMapsListIndexes[MapsListIndexes];

new Array:g_aMapsPrefixes;
new g_iMapsPrefixesNum;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_cvar("mapm_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);

	register_concmd("mapm_debug", "Command_Debug", ADMIN_MAP);
	register_concmd("mapm_startvote", "Command_StartVote", ADMIN_MAP);
	register_concmd("mapm_stopvote", "Command_StopVote", ADMIN_MAP);
}
public plugin_cfg()
{
	g_aMapsList = ArrayCreate(MapsListStruct);
	g_aMapsPrefixes = ArrayCreate(32);

	new Trie:tBlockedMaps = TrieCreate();

	LoadBlockedMaps(tBlockedMaps);
	LoadMapFile(tBlockedMaps);
	LoadMapFile(tBlockedMaps, true);

	TrieDestroy(tBlockedMaps);
}
LoadBlockedMaps(Trie:tBlockedMaps)
{
	new file_dir[128]; get_localinfo("amxx_datadir", file_dir, charsmax(file_dir));
	new file_path[128]; formatex(file_path, charsmax(file_path), "%s/%s", file_dir, FILE_BLOCKED_MAPS);

	new cur_map[32]; get_mapname(cur_map, charsmax(cur_map));

	TrieSetCell(tBlockedMaps, cur_map, 1);

	new file, temp;

	if(file_exists(file_path))
	{
		new temp_file_path[128]; formatex(temp_file_path, charsmax(temp_file_path), "%s/temp.ini", file_dir);
		file = fopen(file_path, "rt");
		temp = fopen(temp_file_path, "wt");

		new buffer[40], map[32], str_count[8], count;
		
		while(!feof(file))
		{
			fgets(file, buffer, charsmax(buffer));
			parse(buffer, map, charsmax(map), str_count, charsmax(str_count));
			
			if(!is_map_valid(map) || TrieKeyExists(tBlockedMaps, map)) continue;
			
			count = str_to_num(str_count) - 1;
			
			if(count <= 0) continue;
			
			if(count > BLOCK_MAP_COUNT)
			{
				count = BLOCK_MAP_COUNT;
			}

			fprintf(temp, "^"%s^" ^"%d^"^n", map, count);
			
			TrieSetCell(tBlockedMaps, map, count);
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
LoadMapFile(Trie:tBlockedMaps, load_night_maps = false)
{
	new file_path[128]; get_localinfo("amxx_configsdir", file_path, charsmax(file_path));
	format(file_path, charsmax(file_path), "%s/%s", file_path, load_night_maps ? FILE_NIGHT_MAPS : FILE_MAPS);

	if(!file_exists(file_path))
	{
		set_fail_state("Maps file doesn't exist.");
	}


	if(load_night_maps)
	{
		g_iMapsListIndexes[NightListStart] = ArraySize(g_aMapsList);
	}

	new cur_map[32]; get_mapname(cur_map, charsmax(cur_map));
	new file = fopen(file_path, "rt");
	
	if(file)
	{
		new eMapInfo[MapsListStruct], text[48], map[32], min[3], max[3], prefix[32];

		while(!feof(file))
		{
			fgets(file, text, charsmax(text));
			parse(text, map, charsmax(map), min, charsmax(min), max, charsmax(max));
			
			if(!map[0] || map[0] == ';' || !valid_map(map) || is_map_in_array(map, load_night_maps) || equali(map, cur_map)) continue;
			
			if(get_map_prefix(map, prefix, charsmax(prefix)) && !is_prefix_in_array(prefix))
			{
				ArrayPushString(g_aMapsPrefixes, prefix);
				g_iMapsPrefixesNum++;
			}
			
			eMapInfo[m_MapName] = map;
			eMapInfo[m_MinPlayers] = str_to_num(min);
			eMapInfo[m_MaxPlayers] = str_to_num(max) == 0 ? 32 : str_to_num(max);
			
			if(TrieKeyExists(tBlockedMaps, map))
			{
				TrieGetCell(tBlockedMaps, map, eMapInfo[m_BlockCount]);
			}

			ArrayPushArray(g_aMapsList, eMapInfo);
			min = ""; max = ""; eMapInfo[m_BlockCount] = 0;
		}
		fclose(file);
		
		new size = ArraySize(g_aMapsList);
		if(!load_night_maps && size == 0)
		{
			set_fail_state("Nothing loaded from file.");
		}

		g_iMapsListIndexes[load_night_maps ? NightListEnd : MapsListEnd] = size;
	}
}
public Command_Debug(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;

	console_print(id, "^nLoaded maps:");	
	new eMapInfo[MapsListStruct];
	for(new i; i < g_iMapsListIndexes[MapsListEnd]; i++)
	{
		ArrayGetArray(g_aMapsList, i, eMapInfo);
		console_print(id, "%3d %32s ^t%d^t%d^t%d", i + 1, eMapInfo[m_MapName], eMapInfo[m_MinPlayers], eMapInfo[m_MaxPlayers], eMapInfo[m_BlockCount]);
	}
	console_print(id, "Night maps:");
	for(new i = g_iMapsListIndexes[NightListStart]; i < g_iMapsListIndexes[NightListEnd]; i++)
	{
		ArrayGetArray(g_aMapsList, i, eMapInfo);
		console_print(id, "%3d %32s ^t%d^t%d^t%d", i + 1, eMapInfo[m_MapName], eMapInfo[m_MinPlayers], eMapInfo[m_MaxPlayers], eMapInfo[m_BlockCount]);
	}

	new prefix[32];
	console_print(id, "^nLoaded prefixes:");
	for(new i; i < g_iMapsPrefixesNum; i++)
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
	if(second_vote)
	{
		// vote with 2 top voted maps
	}

	// standart vote
}
StartVote()
{

}
FinishVote()
{

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
	new eMapInfo[MapsListStruct];
	for(new i = start; i < end; i++)
	{
		ArrayGetArray(g_aMapsList, i, eMapInfo);
		if(equali(map, eMapInfo[m_MapName])) return i + 1;
	}
	return 0;
}
is_prefix_in_array(prefix[])
{
	for(new i, str[32]; i < g_iMapsPrefixesNum; i++)
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
