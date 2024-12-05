#include <amxmodx>
#include <sqlx>
#include <player_prefs>
#include <json>

#pragma semicolon 1

const MAX_QUERY_LENGTH = 4096;

new const CONFIG_FILE[] = "addons/amxmodx/configs/player_prefs.json";

enum {
  State_LoadKeys,
  State_LoadPlayer,
  State_InsertPlayer,
  State_LoadPreferences,
  State_InsertKey,
  State_InsertPreference,
  State_SetDefaultValue
};

enum _: Forwards {
  Forward_Initialized,
  Forward_PlayerLoaded,
  Forward_PlayerSaved
};

enum _: IntertKey {
  query_state,
  player_id,
  player_userid,
  key_id,
  value[256]
};

new g_iPlayerDatabaseId[MAX_PLAYERS + 1] = {0, ...};
new Trie: g_tPlayerPreferences[MAX_PLAYERS + 1];

new Trie: g_tKeys;
new Trie: g_tKeysIds;

new g_szSqlHost[32], g_szSqlUser[32], g_szSqlPassword[128], g_szSqlDatabase[32];
new g_iForwards[Forwards];

new g_szQuery[MAX_QUERY_LENGTH];
new Handle: g_hSqlTuple;

new bool: g_bDebugMode;

public plugin_init() {
  register_plugin("Player preferences", "1.2.0", "ufame");

  CreateForwards();
  ReadDbCredentials();

  g_bDebugMode = bool: (plugin_flags() & AMX_FLAG_DEBUG);
}

public client_putinserver(iPlayer) {
  if (is_user_hltv(iPlayer) || is_user_bot(iPlayer))
    return;

  g_iPlayerDatabaseId[iPlayer] = 0;
  TrieDestroy(g_tPlayerPreferences[iPlayer]);

  LoadPreferences(iPlayer);
}

public plugin_natives() {
  register_native("pp_is_loaded", "native_is_loaded");
  register_native("pp_get_preference", "native_get_preference");
  register_native("pp_set_preference", "native_set_preference");

  register_native("pp_set_key_default_value", "native_set_key_default_value");
}

public bool: native_is_loaded(iPlugin, iArgs) {
  enum {
    arg_player_id = 1
  };

  new iPlayer = get_param(arg_player_id);

  return IsUserLoaded(iPlayer);
}

public bool: native_get_preference(iPlugin, iArgs) {
  enum {
    arg_player_id = 1,
    arg_key,
    arg_dest,
    arg_destlen
  };

  new iPlayer = get_param(arg_player_id);

  if (!is_user_connected(iPlayer) || g_tPlayerPreferences[iPlayer] == Invalid_Trie)
    return false;

  new szKey[32], szValue[256];
  new iLen = get_param(arg_destlen);

  get_string(arg_key, szKey, charsmax(szKey));

  if (g_tPlayerPreferences[iPlayer] != Invalid_Trie && TrieKeyExists(g_tPlayerPreferences[iPlayer], szKey)) {
    TrieGetString(g_tPlayerPreferences[iPlayer], szKey, szValue, charsmax(szValue));
  } else if (g_tKeys != Invalid_Trie && TrieKeyExists(g_tKeys, szKey)) {
    TrieGetString(g_tKeys, szKey, szValue, charsmax(szValue));
  }

  set_string(arg_dest, szValue, iLen);

  return true;
}

public bool: native_set_preference(iPlugin, iArgs) {
  enum {
    arg_player_id = 1,
    arg_key,
    arg_value,
    arg_default_value
  };

  new iPlayer = get_param(arg_player_id);

  if (!is_user_connected(iPlayer))
    return false;

  if (!IsUserLoaded(iPlayer)) {
    log_error(AMX_ERR_NONE, "Attempt to set preference for not loaded player (%d).", iPlayer);
    return false;
  }

  new szKey[32], szValue[256], szDefaultValue[256];

  get_string(arg_key, szKey, charsmax(szKey));
  get_string(arg_value, szValue, charsmax(szValue));
  get_string(arg_default_value, szDefaultValue, charsmax(szDefaultValue));

  return bool: SetPreference(iPlayer, szKey, szValue, szDefaultValue);
}

public bool: native_set_key_default_value(iPlugin, iArgs) {
  enum {
    arg_key = 1,
    arg_default_value
  };

  new szKey[32], szDefaultValue[256];

  get_string(arg_key, szKey, charsmax(szKey));
  get_string(arg_default_value, szDefaultValue, charsmax(szDefaultValue));

  if (g_hSqlTuple != Empty_Handle) {
    formatex(g_szQuery, charsmax(g_szQuery),
      "INSERT INTO `pp_keys` (`key`, `default_value`) VALUES ('%s', '%s') \
      ON DUPLICATE KEY UPDATE `default_value` = VALUES (`default_value`);",
      szKey, szDefaultValue
    );

    __debug("[PP] [set_key_default_value] Insert key <%s> - Default value: %s^nQUERY: %s", szKey, szDefaultValue, g_szQuery);

    new iData[1];
    iData[0] = State_SetDefaultValue;

    SQL_ThreadQuery(g_hSqlTuple, "ThreadQuery_Handler", g_szQuery, iData, sizeof iData);
  }

  if (g_tKeys == Invalid_Trie)
   g_tKeys = TrieCreate();

  return bool: TrieSetString(g_tKeys, szKey, szDefaultValue);
}

bool:IsUserLoaded(const iPlayer) {
  if (!is_user_connected(iPlayer))
    return false;

  return g_iPlayerDatabaseId[iPlayer] > 0 && g_tPlayerPreferences[iPlayer] != Invalid_Trie;
}

stock LoadPreferences(iPlayer) {
  if (g_hSqlTuple == Empty_Handle) {
    ExecuteForward(g_iForwards[Forward_PlayerLoaded], _, iPlayer);

    return;
  }

  new szAuth[MAX_AUTHID_LENGTH];
  get_user_authid(iPlayer, szAuth, charsmax(szAuth));

  formatex(g_szQuery, charsmax(g_szQuery),
    "SELECT `id` FROM `pp_players` WHERE `authid` = '%s';",
    szAuth
  );

  new iData[3];
  iData[0] = State_LoadPlayer;
  iData[1] = iPlayer;
  iData[2] = get_user_userid(iPlayer);

  SQL_ThreadQuery(g_hSqlTuple, "ThreadQuery_Handler", g_szQuery, iData, sizeof iData);
}

stock SetPreference(iPlayer, szKey[], szValue[], szDefaultValue[]) {
  if (g_hSqlTuple != Empty_Handle) {
    // TODO: Было бы неплохо, при наличии ключа в g_tKeysIds, слать сразу значения, и только в ином случае начинать с ключа
    // И даже если начинать с ключа, в колбеке всё ровно перепроверять g_tKeysIds (szData[3]) т.к. сраная асинхронщина
    formatex(g_szQuery, charsmax(g_szQuery),
      "INSERT INTO `pp_keys` (`key`, `default_value`) VALUES ('%s', '%s') \
      ON DUPLICATE KEY UPDATE `default_value` = VALUES (`default_value`);",
      szKey, szDefaultValue
    );

    new szData[IntertKey];

    szData[query_state] = State_InsertKey;
    szData[player_id] = iPlayer;
    szData[player_userid] = get_user_userid(iPlayer);
    TrieGetCell(g_tKeysIds, szKey, szData[key_id]);
    formatex(szData[value], charsmax(szData[value]), szValue);

    __debug("[PP] Insert key <%s> - value: %s | PlayerId: %d, UserId: %d",
      szKey, szData[player_id], szData[player_userid], szValue
    );

    SQL_ThreadQuery(g_hSqlTuple, "ThreadQuery_Handler", g_szQuery, szData, sizeof szData);
  }

  if (g_tPlayerPreferences[iPlayer] == Invalid_Trie)
    g_tPlayerPreferences[iPlayer] = TrieCreate();

  return bool: TrieSetString(g_tPlayerPreferences[iPlayer], szKey, szValue);
}

public ThreadQuery_Handler(iFailState, Handle: hQuery, szError[], iError, szData[], iDataSize, Float: flQueueTime) {
  if (iFailState != TQUERY_SUCCESS) {
    SQL_ThreadError(hQuery, szError, iError, flQueueTime);
    
    return;
  }

  switch (szData[0]) {
    case State_LoadKeys: {
      new szKey[64], szDefaultValue[256], sKeyId[11];

      TrieDestroy(g_tKeysIds);
      g_tKeysIds = TrieCreate();

      while (SQL_MoreResults(hQuery)) {
        SQL_ReadResult(hQuery, SQL_FieldNameToNum(hQuery, "id"), sKeyId, charsmax(sKeyId));
        SQL_ReadResult(hQuery, SQL_FieldNameToNum(hQuery, "key"), szKey, charsmax(szKey));
        SQL_ReadResult(hQuery, SQL_FieldNameToNum(hQuery, "default_value"), szDefaultValue, charsmax(szDefaultValue));

        TrieSetString(g_tKeys, szKey, szDefaultValue);
        TrieSetCell(g_tKeysIds, szKey, str_to_num(sKeyId));

        SQL_NextRow(hQuery);
      }

      log_amx("Successfully loaded %d keys", SQL_AffectedRows(hQuery));
    }
    
    case State_LoadPlayer: {
      new iPlayer = szData[1];
      new iUserid = szData[2];

      __debug("-----");
      __debug("[PP] PlayerId: %d | State: Load Player (#1) | UserIdSaved: %d, UserIdCurrent: %d", iPlayer, iUserid, get_user_userid(iPlayer));

      if (iUserid != get_user_userid(iPlayer))
        return;

      new szAuth[MAX_AUTHID_LENGTH];
      get_user_authid(iPlayer, szAuth, charsmax(szAuth));

      __debug("[PP] PlayerId: %d | State: Load Player (#2) | UserIdSaved: %d, UserIdCurrent: %d, AuthId: <%s>", iPlayer, iUserid, get_user_userid(iPlayer), szAuth);

      if (!SQL_NumResults(hQuery)) {
        formatex(g_szQuery, charsmax(g_szQuery),
          "INSERT INTO `pp_players` (`authid`) VALUES ('%s');",
          szAuth
        );

        szData[0] = State_InsertPlayer;

        SQL_ThreadQuery(g_hSqlTuple, "ThreadQuery_Handler", g_szQuery, szData, iDataSize);

        __debug("-----");
        __debug("[PP] PlayerId: %d | State: Insert Player (#1) | UserIdSaved: %d, UserIdCurrent: %d, AuthId: <%s>^nQUERY: %s", iPlayer, iUserid, get_user_userid(iPlayer), szAuth, g_szQuery);
        
        return;
      }

      // Это немного ломало логику функи IsUserLoaded, в момент между этим и State_LoadPreferences
      // Добавил там допом проверку на созданность trie с префами
      g_iPlayerDatabaseId[iPlayer] = SQL_ReadResult(hQuery, SQL_FieldNameToNum(hQuery, "id"));

      formatex(g_szQuery, charsmax(g_szQuery),
        "SELECT `pp_keys`.`key`, `pp_preferences`.`value` \
          FROM `pp_keys` \
          JOIN `pp_preferences` \
          ON `pp_keys`.`id` = `pp_preferences`.`key_id` \
        WHERE `pp_preferences`.`player_id` = %d;",
        g_iPlayerDatabaseId[iPlayer]
      );

      szData[0] = State_LoadPreferences;

      SQL_ThreadQuery(g_hSqlTuple, "ThreadQuery_Handler", g_szQuery, szData, iDataSize);

      __debug("-----");
      __debug("[PP] PlayerId: %d | State: Load Preferences (#1) | UserIdSaved: %d, UserIdCurrent: %d, AuthId: <%s>^nQUERY: %s", iPlayer, iUserid, get_user_userid(iPlayer), szAuth, g_szQuery);
    }

    case State_InsertPlayer: {
      new iPlayer = szData[1];
      new iUserid = szData[2];

      __debug("[PP] PlayerId: %d | State: Insert Player (#2) | UserIdSaved: %d, UserIdCurrent: %d", iPlayer, iUserid, get_user_userid(iPlayer));

      if (iUserid != get_user_userid(iPlayer))
        return;

      __debug("[PP] PlayerId: %d | State: Insert Player (#3) | UserIdSaved: %d, UserIdCurrent: %d", iPlayer, iUserid, get_user_userid(iPlayer));

      g_iPlayerDatabaseId[iPlayer] = SQL_GetInsertId(hQuery);

      ExecuteForward(g_iForwards[Forward_PlayerLoaded], _, iPlayer);
    }

    case State_LoadPreferences: {
      new iPlayer = szData[1];
      new iUserid = szData[2];

      __debug("[PP] PlayerId: %d | State: Load Preferences (#2) | UserIdSaved: %d, UserIdCurrent: %d", iPlayer, iUserid, get_user_userid(iPlayer));

      if (iUserid != get_user_userid(iPlayer))
        return;
      
      __debug("[PP] PlayerId: %d | State: Load Preferences (#3) | UserIdSaved: %d, UserIdCurrent: %d", iPlayer, iUserid, get_user_userid(iPlayer));

      new szKey[64], szValue[256];

      if (g_tPlayerPreferences[iPlayer] == Invalid_Trie)
        g_tPlayerPreferences[iPlayer] = TrieCreate();

      while (SQL_MoreResults(hQuery)) {
        SQL_ReadResult(hQuery, SQL_FieldNameToNum(hQuery, "key"), szKey, charsmax(szKey));
        SQL_ReadResult(hQuery, SQL_FieldNameToNum(hQuery, "value"), szValue, charsmax(szValue));

        TrieSetString(g_tPlayerPreferences[iPlayer], szKey, szValue);

        SQL_NextRow(hQuery);
      }

      ExecuteForward(g_iForwards[Forward_PlayerLoaded], _, iPlayer);
      __debug("[PP] PlayerId: %d successfully loaded.", iPlayer);
    }

    case State_InsertKey: {
      new iPlayer = szData[1];
      new iUserid = szData[2];

      __debug("[PP] PlayerId: %d | State: Insert key (#2) | UserIdSaved: %d, UserIdCurrent: %d", iPlayer, iUserid, get_user_userid(iPlayer));

      if (iUserid != get_user_userid(iPlayer))
        return;

      if (g_iPlayerDatabaseId[iPlayer] <= 0)
        return;

      new iKeyId = szData[3] == 0 ? SQL_GetInsertId(hQuery) : szData[3];

      formatex(g_szQuery, charsmax(g_szQuery),
        "INSERT INTO `pp_preferences` (`player_id`, `key_id`, `value`) VALUES (%d, %d, '%s') \
        ON DUPLICATE KEY UPDATE `value` = VALUES (`value`);",
        g_iPlayerDatabaseId[iPlayer], iKeyId, szData[4]
      );

      __debug("[PP] PlayerId: %d | State: Insert key (#3) | UserIdSaved: %d, UserIdCurrent: %d, Value: <%s>^nQUERY: %s", iPlayer, iUserid, get_user_userid(iPlayer), szData[4], g_szQuery);

      szData[0] = State_InsertPreference;

      SQL_ThreadQuery(g_hSqlTuple, "ThreadQuery_Handler", g_szQuery, szData, iDataSize);
    }

    case State_InsertPreference: {
      new iPlayer = szData[1];
      new iUserid = szData[2];

      __debug("[PP] PlayerId: %d | State: Insert Preference (#2) | UserIdSaved: %d, UserIdCurrent: %d", iPlayer, iUserid, get_user_userid(iPlayer));

      if (iUserid != get_user_userid(iPlayer))
        return;

      ExecuteForward(g_iForwards[Forward_PlayerSaved], _, iPlayer);
      __debug("[PP] PlayerId: %d successfully saved.", iPlayer);
    }

    case State_SetDefaultValue: {
      
    }
  }
}

ReadDbCredentials() {
  if (!file_exists(CONFIG_FILE)) {
    abort(AMX_ERR_GENERAL, "[PP] DB credentials file not found (%s).", CONFIG_FILE);
    return;
  }

  new JSON: credsConfig = json_parse(CONFIG_FILE, true, true);

  if (credsConfig == Invalid_JSON) {
    abort(AMX_ERR_GENERAL, "[PP] JSON synax error in DB credentials file (%s).", CONFIG_FILE);
    return;
  }

  if (!json_is_object(credsConfig)) {
    abort(AMX_ERR_GENERAL, "[PP] DB credentials file must contain a JSON-object (%s).", CONFIG_FILE);
    return;
  }

  json_object_get_string(credsConfig, "host", g_szSqlHost, charsmax(g_szSqlHost));
  json_object_get_string(credsConfig, "user", g_szSqlUser, charsmax(g_szSqlUser));
  json_object_get_string(credsConfig, "pass", g_szSqlPassword, charsmax(g_szSqlPassword));
  json_object_get_string(credsConfig, "db", g_szSqlDatabase, charsmax(g_szSqlDatabase));

  json_free(credsConfig);

  ConnectionTest();
}

CreateForwards() {
  g_iForwards[Forward_Initialized] = CreateMultiForward("pp_init", ET_IGNORE, FP_CELL);
  g_iForwards[Forward_PlayerLoaded] = CreateMultiForward("pp_player_loaded", ET_IGNORE, FP_CELL);
  g_iForwards[Forward_PlayerSaved] = CreateMultiForward("pp_player_saved", ET_IGNORE, FP_CELL);
}

ConnectionTest() {
  SQL_SetAffinity("mysql");
  g_hSqlTuple = SQL_MakeDbTuple(g_szSqlHost, g_szSqlUser, g_szSqlPassword, g_szSqlDatabase);

  new szError[512], iErrorCode;
  new Handle: hConnection = SQL_Connect(g_hSqlTuple, iErrorCode, szError, charsmax(szError));

  if (hConnection == Empty_Handle) {
    SQL_FreeHandle(g_hSqlTuple);
    g_hSqlTuple = Empty_Handle;

    abort(AMX_ERR_NATIVE, "[PP] Connection error[%d]: %s", iErrorCode, szError);

    ExecuteForward(g_iForwards[Forward_Initialized], _, false);

    return;
  }

  SQL_FreeHandle(hConnection);
  log_amx("[PP] Connection to database successfully estabilished");

  formatex(g_szQuery, charsmax(g_szQuery),
    "SELECT `id`, `key`, `default_value` FROM `pp_keys`"
  );

  new iData[1];
  iData[0] = State_LoadKeys;

  SQL_ThreadQuery(g_hSqlTuple, "ThreadQuery_Handler", g_szQuery, iData, sizeof iData);

  ExecuteForward(g_iForwards[Forward_Initialized], _, true);
}

SQL_ThreadError(Handle: hQuery, szError[], iError, Float: flQueueTime) {
  SQL_GetQueryString(hQuery, g_szQuery, charsmax(g_szQuery));

  log_amx("[PP] Queue time: %.4f", flQueueTime);
  log_amx("[PP] Error[%d]: %s", iError, szError);
  log_amx("[PP] Query with error: %s", g_szQuery);
}

__debug(const debug_message[], any: ...) {
  if (!g_bDebugMode)
    return;

  new szMessage[1024];
  vformat(szMessage, charsmax(szMessage), debug_message, 2);

  log_to_file("pp_debug.log", szMessage);
}
