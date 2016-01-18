# Map Manager
AMXX Plugin

Functions:
- Nextmap
- Rtv
- Nomination
- Block previous maps

Settings
- FUNCTION_NEXTMAP :: replace default nextmap
- FUNCTION_RTV :: add rtv
- FUNCTION_NOMINATION :: add nomination
- FUNCTION_BLOCK_MAPS :: block previous maps
- FUNCTION_SOUND :: add sound
- SELECT_MAPS 5 :: maps count in vote menu
- PRE_START_TIME 5 :: timer before vote start
- VOTE_TIME 10 :: vote duration
- NOMINATED_MAPS_IN_MENU 3
- NOMINATED_MAPS_PER_PLAYER 3
- BLOCK_MAP_COUNT 10 :: how much maps will be blocked

Cvars:
- mm_change_type :: 0 - after end vote, 1 - in round end, 2 - after end map
- mm_start_vote_before_end :: minutes
- mm_show_result_type :: 0 - disable, 1 - menu, 2 - hud
- mm_show_selects :: 0 - disable, 1 - all
- mm_start_vote_in_new_round :: 0 - disable, 1 - enable
- mm_freeze_in_vote :: 0 - disable, 1 - enable, if mm_start_vote_in_new_round 1
- mm_black_screen_in_vote :: 0 - disable, 1 - enable
- mm_last_round :: 0 - disable, 1 - enable
- mm_extended_map_max
- mm_extended_time :: minutes
- mm_rtv_mode :: 0 - percents, 1 - players
- mm_rtv_percent
- mm_rtv_players
- mm_rtv_change_type :: 0 - after vote, 1 - in round end
- mm_rtv_delay :: minutes
- mm_nomination_dont_close_menu :: 0 - disable, 1 - enable

TODO:
- Night mode
