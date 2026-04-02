-- Active: 1763755673348@@127.0.0.1@3306@everdaychaos
-- sb_phoneV2 database schema
-- Uses same tables as sb_phone (shared data)

CREATE TABLE IF NOT EXISTS phone_contacts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    owner_citizenid VARCHAR(50) NOT NULL,
    name VARCHAR(50) NOT NULL,
    number VARCHAR(20) NOT NULL,
    favorite TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_contact (owner_citizenid, number),
    INDEX idx_owner (owner_citizenid)
);

CREATE TABLE IF NOT EXISTS phone_messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sender_number VARCHAR(20) NOT NULL,
    receiver_number VARCHAR(20) NOT NULL,
    message TEXT NOT NULL,
    is_read TINYINT(1) DEFAULT 0,
    status VARCHAR(10) DEFAULT 'delivered',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_sender (sender_number),
    INDEX idx_receiver (receiver_number)
);

CREATE TABLE IF NOT EXISTS phone_calls (
    id INT AUTO_INCREMENT PRIMARY KEY,
    caller_number VARCHAR(20) NOT NULL,
    receiver_number VARCHAR(20) NOT NULL,
    type ENUM('incoming', 'outgoing', 'missed') DEFAULT 'missed',
    duration INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_caller (caller_number),
    INDEX idx_receiver (receiver_number)
);

CREATE TABLE IF NOT EXISTS phone_gallery (
    id INT AUTO_INCREMENT PRIMARY KEY,
    owner_citizenid VARCHAR(50) NOT NULL,
    image_url TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_owner (owner_citizenid)
);

CREATE TABLE IF NOT EXISTS phone_settings (
    owner_citizenid VARCHAR(50) PRIMARY KEY,
    wallpaper VARCHAR(50) DEFAULT 'default',
    ringtone VARCHAR(50) DEFAULT 'default',
    airplane_mode TINYINT(1) DEFAULT 0,
    passkey VARCHAR(10) DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS phone_social_posts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    author_citizenid VARCHAR(50) NOT NULL,
    caption TEXT,
    author_name VARCHAR(50) NOT NULL,
    image_gradient VARCHAR(200) DEFAULT 'linear-gradient(135deg, #1a1a2e, #16213e)',
    location VARCHAR(100) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_author (author_citizenid),
    INDEX idx_created (created_at)
);

CREATE TABLE IF NOT EXISTS phone_social_likes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT NOT NULL,
    citizenid VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_like (post_id, citizenid),
    FOREIGN KEY (post_id) REFERENCES phone_social_posts(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS phone_social_stories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    author_citizenid VARCHAR(50) NOT NULL,
    author_name VARCHAR(50) NOT NULL,
    color VARCHAR(20) DEFAULT '#636366',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP DEFAULT (CURRENT_TIMESTAMP + INTERVAL 24 HOUR),
    INDEX idx_author (author_citizenid),
    INDEX idx_expires (expires_at)
);

CREATE TABLE IF NOT EXISTS phone_serials (
    serial VARCHAR(20) NOT NULL PRIMARY KEY,
    owner_citizenid VARCHAR(50) NOT NULL,
    owner_name VARCHAR(100) NOT NULL DEFAULT '',
    phone_number VARCHAR(20) NOT NULL,
    activated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_owner (owner_citizenid)
);

INSERT IGNORE INTO sb_items (name, label, type, category, stackable, max_stack, useable, shouldClose, description)
VALUES ('phone', 'Phone', 'item', 'electronics', 0, 1, 1, 1, 'A smartphone for calls, messages, and apps');
