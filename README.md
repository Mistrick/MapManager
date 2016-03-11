# Map Manager
MapManager is an [AMX Mod X](/alliedmodders/amxmodx) Plugin to vote for the next map.

### What it can:
- Nextmap - Say `nextmap` in chat to see what map goes next.
- Rtv - Say `rtv` or `/rtv` in chat to rock the vote.
- Nomination - you may nominate maps in the next vote
- Night mode
- Block N previously played maps

### Defines
You may comment some of these to disable functionality you don't need. Less functionality - better perfomance.
```c
#define FUNCTION_NEXTMAP            // replace default nextmap command
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
```

### Cvars:
```c
mm_change_type 2                // 0 - after end vote, 1 - in round end, 2 - after end map
mm_start_vote_before_end 2      // in minutes
mm_show_result_type 1           // 0 - disable, 1 - menu, 2 - hud
mm_show_selects 1               // 0 - disable, 1 - all
mm_start_vote_in_new_round 0    // 0 - disable, 1 - enable
mm_freeze_in_vote 0             // 0 - disable, 1 - enable, if mm_start_vote_in_new_round 1
mm_black_screen_in_vote 0       // 0 - disable, 1 - enable
mm_last_round 0                 // 0 - disable, 1 - enable
mm_change_to_default_map 0      // 0 - disable, 1 - enable
mm_default_map de_dust2
mm_extended_map_max 3
mm_extended_time 15             // in minutes
mm_rtv_mode 0                   // 0 - percents, 1 - players
mm_rtv_percent 60
mm_rtv_players 5
mm_rtv_change_type 1            // 0 - after vote, 1 - in round end
mm_rtv_delay 0                  // minutes
mm_nomination_dont_close_menu 0 // 0 - disable, 1 - enable
mm_night_time "00:00 8:00"      // time to enable night mode
```
