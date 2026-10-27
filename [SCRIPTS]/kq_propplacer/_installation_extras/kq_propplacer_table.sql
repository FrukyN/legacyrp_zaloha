CREATE TABLE IF NOT EXISTS `kq_propplacer` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `model` varchar(50) NOT NULL DEFAULT '0',
    `coords` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`coords`)),
    `rotation` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`rotation`)),
    `metadata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
    PRIMARY KEY (`id`)
    ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;
