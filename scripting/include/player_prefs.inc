#if defined _player_prefs_included
  #endinput
#endif

#define _player_prefs_included

/**
* Used to initialize player preferences module.
*
* @param database_connected A boolean value indicating whether the database is connected or not.
*/
forward pp_init(bool: database_connected);

/**
* Called when a player is loaded and has its preferences loaded.
*
* @param id The player's ID whose preferences are loaded.
*/
forward pp_player_loaded(const id);

/**
* Called when a player is saved and its preferences are saved.
*
* @param id The player's ID whose preferences are saved.
*/
forward pp_player_saved(const id);

/**
* Checks if a player's preferences have been loaded.
*
* @param id Player ID to check
*
* @return True if the player's preferences have been loaded, false otherwise.
*/
native bool: pp_is_loaded(const id);

/**
* Gets the value of a player's preference and copies it into the specified buffer.
*
* @param id Player ID to get preference for
* @param key Key of the preference to get
* @param dest Buffer to copy the preference value into
* @param len Maximum length of the buffer
*
* @return True if the preference was found and copied, false otherwise.
*/
native bool: pp_get_preference(const id, const key[], dest[], len);

/**
* Sets the value of a player's preference.
*
* @param id Player ID to set preference for
* @param key Key of the preference to set
* @param value Value to set the preference to
* @param default_value Default value of the preference key (optional)
*/
native pp_set_preference(const id, const key[], const value[], default_value[] = "");

/**
* Sets the default value for a preference key.
*
* @param key Key of the preference to set the default value for
* @param default_value Default value to set
*
* @note if the key has not yet been created
*       the plugin will create and add it to the database via this native,
*       otherwise it will simply update the default value
*/
native pp_set_key_default_value(const key[], const default_value[]);

/**
* Gets the value of a player's preference and converts it to a number.
*
* @param id Player ID to get preference for
* @param key Key of the preference to get
*
* @return The preference value as a number, or -1 if the preference was not found
*/
stock pp_get_num(const id, const key[]) {
  new temp[64];
  new bool: result = pp_get_preference(id, key, temp, charsmax(temp));

  if (!result) {
    return -1;
  }

  return str_to_num(temp);
}

/**
* Gets the value of a player's preference and converts it to a floating-point number.
*
* @param id Player ID to get preference for
* @param key Key of the preference to get
*
* @return The preference value as a floating-point number, or -1.0 if the preference was not found
*/
stock Float: pp_get_float(const id, const key[]) {
  new temp[64];
  new bool: result = pp_get_preference(id, key, temp, charsmax(temp));

  if (!result) {
    return -1.0;
  }

  return str_to_float(temp);
}

/**
* Gets the value of a player's preference and converts it to a boolean.
*
* @param id Player ID to get preference for
* @param key Key of the preference to get
*
* @return The preference value as a boolean, or false if the preference was not found
*/
stock bool: pp_get_bool(const id, const key[]) {
  new temp[64];
  pp_get_preference(id, key, temp, charsmax(temp));

  return bool: str_to_num(temp);
}

/**
* Sets the value of a player's preference as a number.
*
* @param id Player ID to set preference for
* @param key Key of the preference to set
* @param value Value to set the preference to
*/
stock pp_set_num(const id, const key[], value) {
  new temp[64];
  num_to_str(value, temp, charsmax(temp));

  pp_set_preference(id, key, temp);
}

/**
* Sets the value of a player's preference as a floating-point number.
*
* @param id Player ID to set preference for
* @param key Key of the preference to set
* @param value Value to set the preference to
*/
stock pp_set_float(const id, const key[], Float: value) {
  new temp[64];
  float_to_str(value, temp, charsmax(temp));

  pp_set_preference(id, key, temp);
}

/**
* Sets the value of a player's preference as a boolean.
*
* @param id Player ID to set preference for
* @param key Key of the preference to set
* @param value Value to set the preference to
*/
stock pp_set_bool(const id, const key[], bool: value) {
  new temp[64];
  num_to_str(value, temp, charsmax(temp));

  pp_set_preference(id, key, temp);
}

