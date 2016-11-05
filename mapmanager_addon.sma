#include <amxmodx>

#define PLUGIN "Map Manager: Addon"
#define VERSION "0.1"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define FUNCTION_BLOCK_CHAT
#define FUNCTION_BLOCK_VOICE

forward mapmanager_start_timer();
forward mapmanager_timer_count(time);
forward mapmanager_start_vote();
forward mapmanager_finish_vote();

new const g_szSound[][] =
{
	"sound/fvox/one.wav", "sound/fvox/two.wav", "sound/fvox/three.wav", "sound/fvox/four.wav", "sound/fvox/five.wav",
	"sound/fvox/six.wav", "sound/fvox/seven.wav", "sound/fvox/eight.wav", "sound/fvox/nine.wav", "sound/fvox/ten.wav"
};

#if defined FUNCTION_BLOCK_CHAT
new g_bBlockChat;
#endif // FUNCTION_BLOCK_CHAT

#if defined FUNCTION_BLOCK_VOICE
new g_pVoiceEnable;
#endif // FUNCTION_BLOCK_VOICE

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	#if defined FUNCTION_BLOCK_CHAT
	register_clcmd("say", "Hook_ChatMsg");
	register_clcmd("say_team", "Hook_ChatMsg");
	#endif // FUNCTION_BLOCK_CHAT

	#if defined FUNCTION_BLOCK_VOICE
	g_pVoiceEnable = get_cvar_pointer("sv_voiceenable");
	#endif // FUNCTION_BLOCK_VOICE
}
#if defined FUNCTION_BLOCK_CHAT
public Hook_ChatMsg(id)
{
	if(!g_bBlockChat) return PLUGIN_CONTINUE;

	new args[2]; read_args(args, charsmax(args));

	return (args[0] == '/') ? PLUGIN_HANDLED_MAIN : PLUGIN_HANDLED;
}
#endif // FUNCTION_BLOCK_CHAT
public mapmanager_start_timer()
{
	#if defined FUNCTION_BLOCK_CHAT
	g_bBlockChat = true;
	#endif // FUNCTION_BLOCK_CHAT

	#if defined FUNCTION_BLOCK_VOICE
	set_pcvar_num(g_pVoiceEnable, 0);
	#endif // FUNCTION_BLOCK_VOICE
}
public mapmanager_timer_count(time)
{
	if(time >= 0 && time <= 10)
	{
		SendAudio(0, g_szSound[time - 1], PITCH_NORM);
	}
	for(new id = 1; id < 33; id++)
	{
		if(!is_user_connected(id)) continue;
		set_hudmessage(50, 255, 50, -1.0, 0.3, 0, 0.0, 1.0, 0.0, 0.0, 4);
		show_hudmessage(id, "%L %L!", id, "MAPM_HUD_TIMER", time, id, "MAPM_SECONDS");
	}
}
public mapmanager_start_vote()
{
	SendAudio(0, "sound/Gman/Gman_Choose2.wav", PITCH_NORM);
}
public mapmanager_finish_vote()
{
	#if defined FUNCTION_BLOCK_CHAT
	g_bBlockChat = false;
	#endif // FUNCTION_BLOCK_CHAT

	#if defined FUNCTION_BLOCK_VOICE
	set_pcvar_num(g_pVoiceEnable, 1);
	#endif // FUNCTION_BLOCK_VOICE
}
stock SendAudio(id, audio[], pitch)
{
	static msg_send_audio; if(!msg_send_audio) msg_send_audio = get_user_msgid("SendAudio");

	message_begin( id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, msg_send_audio, _, id);
	write_byte(id);
	write_string(audio);
	write_short(pitch);
	message_end();
}
