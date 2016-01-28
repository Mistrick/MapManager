#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#define PLUGIN "Map Manager: Sub Plugin"
#define VERSION "0.1"
#define AUTHOR "Mistrick"

#pragma semicolon 1

forward mapmanager_prestartvote();
forward mapmanager_finishvote();

new HamHook:g_iHamSpawn, g_pFreezeInVote, g_pStartVoteInNewRound;

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	DisableHamForward(g_iHamSpawn = RegisterHam(Ham_Spawn, "player", "Ham_PlayerSpawn_Post", 1));
	g_pFreezeInVote = get_cvar_pointer("mm_freeze_in_vote");
	g_pStartVoteInNewRound = get_cvar_pointer("mm_start_vote_in_new_round");
}
public mapmanager_prestartvote()
{
	if(get_pcvar_num(g_pFreezeInVote) && !get_pcvar_num(g_pStartVoteInNewRound))
	{
		EnableHamForward(g_iHamSpawn);
		new players[32], pnum; get_players(players, pnum, "a");
		for(new id, i; i < pnum; i++)
		{
			id = players[i];
			set_pev(id, pev_flags, pev(id, pev_flags) | FL_FROZEN);
		}
	}
}
public mapmanager_finishvote()
{
	if(get_pcvar_num(g_pFreezeInVote) && !get_pcvar_num(g_pStartVoteInNewRound))
	{
		DisableHamForward(g_iHamSpawn);
		new players[32], pnum; get_players(players, pnum, "a");
		for(new id, i; i < pnum; i++)
		{
			id = players[i];
			set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);
		}
	}
}
public Ham_PlayerSpawn_Post(id)
{
	if(is_user_alive(id))
	{
		set_pev(id, pev_flags, pev(id, pev_flags) | FL_FROZEN);
	}
}