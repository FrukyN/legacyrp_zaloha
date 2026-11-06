CREATE TABLE IF NOT EXISTS `mdt_incidents` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `title` VARCHAR(150) NOT NULL,
    `description` LONGTEXT NULL,
    `creator_id` INT NOT NULL,
    `creator_name` VARCHAR(100) NOT NULL,
    `suspects` LONGTEXT NULL, -- JSON pole podezřelých [{charId, name, charges}]
    `officers` LONGTEXT NULL, -- JSON pole zasahujících policistů
    `victims` LONGTEXT NULL, -- JSON pole obětí / svědků
    `evidence` LONGTEXT NULL, -- Textový popis důkazů, fotky, balistika
    `total_fine` INT DEFAULT 0,
    `total_jail` INT DEFAULT 0,
    `status` VARCHAR(20) DEFAULT 'open', -- 'open', 'closed'
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_warrants` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `suspect_id` INT NOT NULL,
    `suspect_name` VARCHAR(100) NOT NULL,
    `reason` VARCHAR(255) NOT NULL,
    `charges` LONGTEXT NULL, -- JSON pole obvinění
    `creator_name` VARCHAR(100) NOT NULL,
    `status` VARCHAR(20) DEFAULT 'active', -- 'active', 'executed', 'cancelled'
    `expires_at` DATETIME NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_warrant_suspect` (`suspect_id`),
    INDEX `idx_warrant_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_weapons` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `serial` VARCHAR(50) NOT NULL UNIQUE,
    `model` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `owner_id` INT NULL,
    `owner_name` VARCHAR(100) NULL,
    `is_stolen` TINYINT(1) DEFAULT 0,
    `ballistics_notes` TEXT NULL,
    `registered_by` VARCHAR(100) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_weapon_serial` (`serial`),
    INDEX `idx_weapon_owner` (`owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_bolos` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `type` VARCHAR(20) NOT NULL, -- 'person', 'vehicle'
    `title` VARCHAR(100) NOT NULL,
    `target_name` VARCHAR(100) NULL,
    `plate` VARCHAR(20) NULL,
    `reason` TEXT NOT NULL,
    `danger_level` VARCHAR(20) DEFAULT 'medium', -- 'low', 'medium', 'high', 'extreme'
    `creator_name` VARCHAR(100) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_citizen_notes` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `charId` INT NOT NULL,
    `note` TEXT NOT NULL,
    `author_name` VARCHAR(100) NOT NULL,
    `tags` VARCHAR(255) NULL, -- oddělené čárkami (např. 'Ozbrojený, Recidivista')
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_notes_char` (`charId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_vehicle_notes` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `plate` VARCHAR(12) NOT NULL,
    `note` TEXT NOT NULL,
    `is_stolen` TINYINT(1) DEFAULT 0,
    `author_name` VARCHAR(100) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `uniq_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_bulletins` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `title` VARCHAR(150) NOT NULL,
    `content` TEXT NOT NULL,
    `author_name` VARCHAR(100) NOT NULL,
    `is_pinned` TINYINT(1) DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_user_settings` (
    `charId` INT PRIMARY KEY,
    `callsign` VARCHAR(20) NOT NULL,
    `department` VARCHAR(50) DEFAULT 'LSPD',
    `role` VARCHAR(30) DEFAULT 'officer', -- 'officer', 'supervisor', 'command', 'admin'
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mdt_logs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `officer_id` INT NOT NULL,
    `officer_name` VARCHAR(100) NOT NULL,
    `action` VARCHAR(50) NOT NULL,
    `details` TEXT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_logs_action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
