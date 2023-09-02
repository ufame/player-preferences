#include <amxmodx>
#include <player_prefs>

enum settings {
  bool: AutoOpenMenu,
  Float: HudPosition_X,
  Float: HudPosition_Y
};

new const setting_names[settings][] = {
  "auto_menu_open",
  "hud_position_x",
  "hud_position_y"
};

new g_playerData[MAX_PLAYERS + 1][settings];

public plugin_init() {
  register_plugin("Player preferences: test", "1.0.0", "ufame");

  register_clcmd("say /pp", "pp_handler");

  set_task(1.0, "Task_ShowHud", .flags = "b");
}

public pp_init(bool: database_connected) {
  log_amx("Database connected: %d", database_connected);

  pp_set_key_default_value(setting_names[AutoOpenMenu], "1");
  pp_set_key_default_value(setting_names[HudPosition_X], "-1.0");
  pp_set_key_default_value(setting_names[HudPosition_Y], "0.20");
}

public pp_player_loaded(const id) {
  g_playerData[id][AutoOpenMenu] = pp_get_bool(id, setting_names[AutoOpenMenu]);
  g_playerData[id][HudPosition_X] = pp_get_float(id, setting_names[HudPosition_X]);
  g_playerData[id][HudPosition_Y] = pp_get_float(id, setting_names[HudPosition_Y]);

  if (g_playerData[id][AutoOpenMenu])
    pp_handler(id);
}

public pp_handler(id) {
  new menuId = menu_create("Menu", "menu_handler");

  menu_additem(menuId, fmt("Auto open menu \y%d", cell: g_playerData[id][AutoOpenMenu]));

  menu_addtext(menuId, fmt("Current X \y%.2f Y \y%.2f",
    g_playerData[id][HudPosition_X], g_playerData[id][HudPosition_Y]
  ), 0);
  menu_additem(menuId, "Hud X +");
  menu_additem(menuId, "Hud Y +");
  menu_additem(menuId, "Hud X -");
  menu_additem(menuId, "Hud Y -");

  menu_setprop(menuId, MPROP_EXIT, MEXIT_ALL);

  menu_display(id, menuId);
}

public menu_handler(id, menu, item) {
  if (item == MENU_EXIT)
  {
    menu_destroy(menu);

    return;
  }

  switch (item) {
    case 1: {
      g_playerData[id][AutoOpenMenu] = !g_playerData[id][AutoOpenMenu];

      pp_set_bool(id, setting_names[AutoOpenMenu], g_playerData[id][AutoOpenMenu]);
    }
    case 2: {
      g_playerData[id][HudPosition_X] += 0.01;

      if (g_playerData[id][HudPosition_X] > 1.0)
        g_playerData[id][HudPosition_X] = 1.0;
    }
    case 3: {
      g_playerData[id][HudPosition_Y] += 0.01;

      if (g_playerData[id][HudPosition_Y] > 1.0)
        g_playerData[id][HudPosition_Y] = 1.0;
    }
    case 4: {
      g_playerData[id][HudPosition_X] -= 0.01;

      if (g_playerData[id][HudPosition_X] < 0.01)
        g_playerData[id][HudPosition_X] = 0.01;
    }
    case 5: {
      g_playerData[id][HudPosition_Y] -= 0.01;

      if (g_playerData[id][HudPosition_Y] < 0.01)
        g_playerData[id][HudPosition_Y] = 0.01;
    }
  }

  if (item >= 2) {
    remove_task(id + 23145);
    set_task(1.5, "Task_SavePos", id + 23145);
  }

  menu_destroy(menu);
  pp_handler(id);
}

public Task_ShowHud() {
  for (new id = 1; id <= MaxClients; id++) {
    if (!is_user_connected(id))
      continue;

    set_hudmessage(.x = g_playerData[id][HudPosition_X], .y = g_playerData[id][HudPosition_Y], .holdtime = 1.0);
    show_hudmessage(id, "Test message");
  }
}

public Task_SavePos(id) {
  id -= 23145;

  pp_set_float(id, setting_names[HudPosition_X], g_playerData[id][HudPosition_X]);
  pp_set_float(id, setting_names[HudPosition_Y], g_playerData[id][HudPosition_Y]);
}
