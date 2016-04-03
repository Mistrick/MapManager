# Map Manager
MapManager is an [AMX Mod X](https://github.com/alliedmodders/amxmodx) Plugin to vote for the next map.

### What it can:
- Nextmap - Say `nextmap` in chat to see what map goes next.
- Rtv - Say `rtv` or `/rtv` in chat to rock the vote.
- Nomination - you may nominate maps in the next vote
- Night mode
- Block N previously played maps

### Defines
You may comment some of these to disable functionality you don't need. Less functionality - better perfomance.
```c
#define FUNCTION_NEXTMAP            // replace default nextmap plugin
#define FUNCTION_RTV                // support rtv
#define FUNCTION_NOMINATION         // support nomination
#define FUNCTION_NIGHTMODE          // support night mode
#define FUNCTION_BLOCK_MAPS         // block N previously played maps
#define FUNCTION_SOUND              // use sounds
#define SELECT_MAPS 5               // how many maps in vote menu
#define PRE_START_TIME 5            // timer before vote start
#define VOTE_TIME 10                // vote duration
#define NOMINATED_MAPS_IN_MENU 3
#define NOMINATED_MAPS_PER_PLAYER 3 // how many maps single player can nominate
#define BLOCK_MAP_COUNT 10          // how much previous played maps will be blocked
#define MAX_ROUND_TIME 3.5          // max time for increase mp_roundtime
```

### Cvars:
```c
mapm_change_type 2                // 0 - after end vote, 1 - in round end, 2 - after end map
mapm_start_vote_before_end 2      // in minutes
mapm_show_result_type 1           // 0 - disable, 1 - menu, 2 - hud
mapm_show_selects 1               // 0 - disable, 1 - all
mapm_start_vote_in_new_round 0    // 0 - disable, 1 - enable
mapm_freeze_in_vote 0             // 0 - disable, 1 - enable, if mm_start_vote_in_new_round 1
mapm_black_screen_in_vote 0       // 0 - disable, 1 - enable
mapm_last_round 0                 // 0 - disable, 1 - enable
mapm_change_to_default_map 0      // 0 - disable, 1 - enable
mapm_default_map de_dust2
mapm_extended_type 0              // 0 - time, 1 - rounds
mapm_extended_map_max 3
mapm_extended_time 15             // in minutes
mapm_extended_rounds 3
mapm_rtv_mode 0                   // 0 - percents, 1 - players
mapm_rtv_percent 60
mapm_rtv_players 5
mapm_rtv_change_type 1            // 0 - after vote, 1 - in round end
mapm_rtv_delay 0                  // minutes
mapm_nomination_dont_close_menu 0 // 0 - disable, 1 - enable
mapm_night_time "00:00 8:00"      // time to enable night mode
```
