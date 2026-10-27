CREATE TABLE IF NOT EXISTS bossmenu_society_accounts (
    job_name VARCHAR(64) NOT NULL,
    balance BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (job_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS bossmenu_transactions (
    id BIGINT NOT NULL AUTO_INCREMENT,
    job_name VARCHAR(64) NOT NULL,
    action VARCHAR(50) NOT NULL,
    amount BIGINT NOT NULL DEFAULT 0,
    actor_identifier VARCHAR(80) NULL,
    actor_name VARCHAR(120) NULL,
    target_identifier VARCHAR(80) NULL,
    target_name VARCHAR(120) NULL,
    reason VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_job_created (job_name, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS bossmenu_employee_notes (
    id BIGINT NOT NULL AUTO_INCREMENT,
    job_name VARCHAR(64) NOT NULL,
    employee_identifier VARCHAR(80) NOT NULL,
    note TEXT NOT NULL,
    author_identifier VARCHAR(80) NULL,
    author_name VARCHAR(120) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_employee_notes (job_name, employee_identifier, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS bossmenu_hr_history (
    id BIGINT NOT NULL AUTO_INCREMENT,
    job_name VARCHAR(64) NOT NULL,
    action VARCHAR(40) NOT NULL,
    actor_identifier VARCHAR(80) NULL,
    actor_name VARCHAR(120) NULL,
    target_identifier VARCHAR(80) NULL,
    target_name VARCHAR(120) NULL,
    from_grade INT NULL,
    to_grade INT NULL,
    amount BIGINT NULL,
    reason VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_hr_job_created (job_name, created_at),
    KEY idx_hr_target (target_identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS bossmenu_attendance (
    identifier VARCHAR(80) NOT NULL,
    job_name VARCHAR(64) NOT NULL,
    total_minutes INT NOT NULL DEFAULT 0,
    last_seen DATETIME NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier, job_name),
    KEY idx_attendance_job (job_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS bossmenu_attendance_log (
    id BIGINT NOT NULL AUTO_INCREMENT,
    identifier VARCHAR(80) NOT NULL,
    job_name VARCHAR(64) NOT NULL,
    minutes INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_attendance_log_job_created (job_name, created_at),
    KEY idx_attendance_log_identifier (identifier, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS bossmenu_announcements (
    id BIGINT NOT NULL AUTO_INCREMENT,
    job_name VARCHAR(64) NOT NULL,
    message VARCHAR(300) NOT NULL,
    author_identifier VARCHAR(80) NULL,
    author_name VARCHAR(120) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_announcement_job (job_name, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS bossmenu_material_orders (
    id BIGINT NOT NULL AUTO_INCREMENT,
    job_name VARCHAR(64) NOT NULL,
    item VARCHAR(80) NOT NULL,
    amount INT NOT NULL,
    total_price BIGINT NOT NULL,
    ordered_by_identifier VARCHAR(80) NULL,
    ordered_by_name VARCHAR(120) NULL,
    status ENUM('pending', 'delivered', 'failed') NOT NULL DEFAULT 'pending',
    deliver_at DATETIME NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    delivered_at DATETIME NULL,
    PRIMARY KEY (id),
    KEY idx_order_job_status (job_name, status),
    KEY idx_order_delivery (status, deliver_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS bossmenu_activity (
    id BIGINT NOT NULL AUTO_INCREMENT,
    job_name VARCHAR(64) NOT NULL,
    identifier VARCHAR(80) NOT NULL,
    name VARCHAR(120) NULL,
    action VARCHAR(50) NOT NULL,
    metadata JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_activity_job_created (job_name, created_at),
    KEY idx_activity_identifier (identifier, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
