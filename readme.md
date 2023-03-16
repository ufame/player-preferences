# Player preferences

Allows you to easily manage and store player preferences, such as hats, music and other settings.

With this plugin, players can easily save and load their preferences, even on different servers. This means they can quickly and easily return to their preferred settings without having to manually adjust settings every time they join a new server.

## Usage

- From the import folder, take the init_.sql file and import it into your database

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