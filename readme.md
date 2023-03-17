# Player preferences

Allows you to easily manage and store player preferences, such as hats, music and other settings.

With this plugin, players can easily save and load their preferences, even on different servers. This means they can quickly and easily return to their preferred settings without having to manually adjust settings every time they join a new server.

## Usage

1. From the import folder, take the init_.sql file and import it into your database
2. Put the contents of the scripting folder in the directory of your server (your_server_folder/cstrike/addons/amxmodx/scripting)
3. Compile `player_preferences.sma` [how to compile?](https://dev-cs.ru/threads/246/)
4. Add `player_preferences.amxx` into your `plugins.ini` file
5. Restart server or change map
6. After restarting the server or changing the map, a config will be created in the folder `/cstrike/addons/amxmodx/configs/plugins` with the name `plugin-player_preferences.cfg`. In this config, enter the data to connect to your database
7. Use [API](https://github.com/ufame/player-preferences/blob/master/scripting/include/player_prefs.inc) to create your own plugins that allow you to save user preferences!

## Example

```Pawn
#include <amxmodx>
#include <player_prefs>

new const KEY[] = "enable_music";

new const DEFAULT_VALUE[] = "true";

new bool: g_bMusic[MAX_PLAYERS + 1];

public plugin_init() {
    register_plugin("PP Music", "1.0.0", "ufame");

    register_clcmd("say /music", "music_command");
}

public pp_init() {
    pp_set_key_default_value(KEY, DEFAULT_VALUE);
}

public pp_player_loaded(const id) {
    g_bMusic[id] = pp_get_bool(id, KEY);
}

public music_command(id) {
    g_bMusic[id] = !g_bMusic[id];

    pp_set_bool(id, g_bMusic[id]);
}

```

Another see [pp_test.sma](https://github.com/ufame/player-preferences/blob/master/scripting/pp_test.sma). This plugin is only for testing, but it fully works