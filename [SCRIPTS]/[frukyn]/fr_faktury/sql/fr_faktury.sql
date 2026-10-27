CREATE TABLE IF NOT EXISTS `fr_invoices` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizen_id` VARCHAR(80) NOT NULL,
  `account_id` VARCHAR(80) NOT NULL,
  `amount` INT UNSIGNED NOT NULL,
  `paid_amount` INT UNSIGNED NULL,
  `reason` VARCHAR(180) NOT NULL,
  `created_by` VARCHAR(100) NOT NULL,
  `due_at` DATETIME NOT NULL,
  `paid_at` DATETIME NULL,
  `collected_at` DATETIME NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `unpaid_due` (`paid_at`, `due_at`),
  KEY `citizen_unpaid` (`citizen_id`, `paid_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
