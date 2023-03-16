CREATE TABLE IF NOT EXISTS `pp_players` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `authid` varchar(36) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY (`authid`)
) CHARACTER SET utf8 COLLATE utf8_general_ci;

CREATE TABLE IF NOT EXISTS `pp_keys` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `key` varchar(64) NOT NULL,
  `default_value` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY (`key`)
) CHARACTER SET utf8 COLLATE utf8_general_ci;

CREATE TABLE IF NOT EXISTS `pp_preferences` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `player_id` int(11) NOT NULL,
  `key_id` int(11) NOT NULL,
  `value` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),

  FOREIGN KEY (`player_id`)
    REFERENCES `pp_players`(`id`)
    ON UPDATE CASCADE ON DELETE CASCADE,

  FOREIGN KEY (`key_id`)
    REFERENCES `pp_keys`(`id`)
    ON UPDATE CASCADE ON DELETE CASCADE
) CHARACTER SET utf8 COLLATE utf8_general_ci;
