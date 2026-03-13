-- =============================================
-- База данных: volunteer_db
-- Кодировка: utf8mb4_unicode_ci
-- =============================================

CREATE DATABASE IF NOT EXISTS volunteer_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE volunteer_db;

-- ─── 1. Пользователи ───────────────────────
CREATE TABLE users (
  id            BIGINT        NOT NULL AUTO_INCREMENT,
  email         VARCHAR(255)  NOT NULL,
  password_hash VARCHAR(255)  NOT NULL,
  role          ENUM('VOLUNTEER','ORGANIZER','ADMIN') NOT NULL,
  is_active     TINYINT(1)    NOT NULL DEFAULT 1,
  created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_login_at DATETIME      NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 2. Профили волонтёров ──────────────────
-- full_name заменён на три отдельных поля (last_name, first_name, middle_name)
CREATE TABLE volunteer_profiles (
  user_id      BIGINT       NOT NULL,
  last_name    VARCHAR(100) NOT NULL,
  first_name   VARCHAR(100) NOT NULL,
  middle_name  VARCHAR(100) NULL,
  birth_date   DATE         NULL,
  city         VARCHAR(100) NULL,
  phone        VARCHAR(30)  NULL,
  email_public VARCHAR(255) NULL,
  updated_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  CONSTRAINT fk_vp_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 3. Профили организаторов ──────────────
CREATE TABLE organizer_profiles (
  user_id       BIGINT       NOT NULL,
  org_name      VARCHAR(255) NOT NULL,
  inn           VARCHAR(12)  NULL,
  kpp           VARCHAR(9)   NULL,
  legal_address VARCHAR(500) NULL,
  contact_phone VARCHAR(30)  NULL,
  contact_email VARCHAR(255) NULL,
  updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  CONSTRAINT fk_op_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 4. Категории мероприятий ──────────────
CREATE TABLE event_categories (
  id   INT          NOT NULL AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_cat_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 5. Мероприятия ────────────────────────
-- recruitment_status расширен: добавлены DRAFT и COMPLETED
CREATE TABLE events (
  id                  BIGINT       NOT NULL AUTO_INCREMENT,
  category_id         INT          NULL,
  created_by          BIGINT       NOT NULL,
  title               VARCHAR(255) NOT NULL,
  description         TEXT         NULL,
  city                VARCHAR(100) NULL,
  location            VARCHAR(255) NULL,
  start_date          DATE         NULL,
  end_date            DATE         NULL,
  required_volunteers INT          NULL DEFAULT 0,
  recruitment_status  ENUM('DRAFT','OPEN','CLOSED','COMPLETED') NOT NULL DEFAULT 'DRAFT',
  created_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_ev_category FOREIGN KEY (category_id)  REFERENCES event_categories(id) ON DELETE SET NULL,
  CONSTRAINT fk_ev_creator  FOREIGN KEY (created_by)   REFERENCES users(id),
  -- Индексы для фильтрации на странице мероприятий
  INDEX idx_events_city        (city),
  INDEX idx_events_dates       (start_date, end_date),
  INDEX idx_events_status      (recruitment_status),
  INDEX idx_events_category    (category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 6. Организаторы мероприятий ───────────
CREATE TABLE event_organizers (
  event_id           BIGINT   NOT NULL,
  organizer_user_id  BIGINT   NOT NULL,
  access_level       ENUM('VIEWER','EDITOR') NOT NULL DEFAULT 'VIEWER',
  added_at           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (event_id, organizer_user_id),
  CONSTRAINT fk_eo_event FOREIGN KEY (event_id)          REFERENCES events(id) ON DELETE CASCADE,
  CONSTRAINT fk_eo_user  FOREIGN KEY (organizer_user_id) REFERENCES users(id)  ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 7. Смены ──────────────────────────────
CREATE TABLE shifts (
  id         BIGINT   NOT NULL AUTO_INCREMENT,
  event_id   BIGINT   NOT NULL,
  shift_date DATE     NOT NULL,
  time_start TIME     NOT NULL,
  time_end   TIME     NOT NULL,
  capacity   INT      NOT NULL DEFAULT 0,
  status     ENUM('ACTIVE','CANCELED') NOT NULL DEFAULT 'ACTIVE',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_sh_event FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  -- Индекс для выборки смен мероприятия по дате
  INDEX idx_shifts_event_date (event_id, shift_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 8. Записи на смены ────────────────────
CREATE TABLE registrations (
  id                 BIGINT       NOT NULL AUTO_INCREMENT,
  shift_id           BIGINT       NOT NULL,
  volunteer_user_id  BIGINT       NOT NULL,
  status             ENUM('ACTIVE','CANCELED') NOT NULL DEFAULT 'ACTIVE',
  registered_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  canceled_at        DATETIME     NULL,
  cancel_reason      VARCHAR(500) NULL,
  PRIMARY KEY (id),
  -- КРИТИЧНО: запрет повторной записи на одну смену
  UNIQUE KEY uq_reg_shift_volunteer (shift_id, volunteer_user_id),
  CONSTRAINT fk_reg_shift     FOREIGN KEY (shift_id)          REFERENCES shifts(id) ON DELETE CASCADE,
  CONSTRAINT fk_reg_volunteer FOREIGN KEY (volunteer_user_id) REFERENCES users(id)  ON DELETE CASCADE,
  -- Индекс для личного кабинета волонтёра
  INDEX idx_reg_volunteer_status (volunteer_user_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 9. Email-уведомления ──────────────────
CREATE TABLE email_notifications (
  id           BIGINT       NOT NULL AUTO_INCREMENT,
  user_id      BIGINT       NOT NULL,
  event_id     BIGINT       NULL,
  shift_id     BIGINT       NULL,
  type         ENUM('REGISTRATION_CONFIRM','REGISTRATION_CANCEL','SHIFT_CHANGED','EVENT_CHANGED') NOT NULL,
  email_to     VARCHAR(255) NOT NULL,
  subject      VARCHAR(255) NULL,
  send_status  ENUM('PENDING','SENT','FAILED') NOT NULL DEFAULT 'PENDING',
  error_message TEXT         NULL,
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  sent_at      DATETIME     NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_en_user  FOREIGN KEY (user_id)  REFERENCES users(id)   ON DELETE CASCADE,
  CONSTRAINT fk_en_event FOREIGN KEY (event_id) REFERENCES events(id)  ON DELETE SET NULL,
  CONSTRAINT fk_en_shift FOREIGN KEY (shift_id) REFERENCES shifts(id)  ON DELETE SET NULL,
  -- Индекс для мониторинга отправки
  INDEX idx_en_user_status (user_id, send_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 10. Журнал действий ───────────────────
CREATE TABLE audit_log (
  id            BIGINT       NOT NULL AUTO_INCREMENT,
  actor_user_id BIGINT       NULL,
  action        VARCHAR(100) NOT NULL,
  entity_type   VARCHAR(100) NULL,
  entity_id     BIGINT       NULL,
  details_json  TEXT         NULL,
  ip            VARCHAR(45)  NULL,
  user_agent    VARCHAR(500) NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_al_user FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE SET NULL,
  -- Индекс для разбора действий пользователя
  INDEX idx_al_user_date (actor_user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Тестовые данные (категории) ───────────
INSERT INTO event_categories (name) VALUES
  ('Дети и молодёжь'),
  ('Экология'),
  ('Помощь пожилым'),
  ('Животные'),
  ('Спорт'),
  ('Культура и искусство'),
  ('Медицина'),
  ('Другое');

-- ─── Тестовый администратор ────────────────
-- Пароль: Admin1234! (bcrypt-хеш, менять перед продакшеном!)
INSERT INTO users (email, password_hash, role) VALUES
  ('admin@volunteer.local', '$2y$10$examplehashhere', 'ADMIN');