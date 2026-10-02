-- ==========================================================
-- RetailSale Business Community & Regional Chat System
-- Migration 001: Create Community, Messaging & Mention Tables
-- Compatible with PostgreSQL & MySQL 8.0+
-- ==========================================================

-- 1. Community Conversations & Regional Channels Table
CREATE TABLE IF NOT EXISTS community_conversations (
    id VARCHAR(120) PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    region_city VARCHAR(100) NOT NULL,
    region_state VARCHAR(100) DEFAULT '',
    is_direct BOOLEAN DEFAULT FALSE,
    direct_recipient_id VARCHAR(100) DEFAULT NULL,
    direct_recipient_name VARCHAR(255) DEFAULT NULL,
    direct_recipient_gstin VARCHAR(30) DEFAULT NULL,
    direct_recipient_phone VARCHAR(30) DEFAULT NULL,
    direct_recipient_city VARCHAR(100) DEFAULT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_comm_conv_region ON community_conversations(region_city, is_direct);

-- 2. Community Messages Table
CREATE TABLE IF NOT EXISTS community_messages (
    id VARCHAR(120) PRIMARY KEY,
    conversation_id VARCHAR(120) NOT NULL REFERENCES community_conversations(id) ON DELETE CASCADE,
    sender_id VARCHAR(100) NOT NULL,
    sender_name VARCHAR(255) NOT NULL,
    sender_trade_name VARCHAR(255) DEFAULT '',
    sender_city VARCHAR(100) DEFAULT '',
    sender_gstin VARCHAR(30) DEFAULT '',
    sender_phone VARCHAR(30) DEFAULT '',
    content TEXT NOT NULL,
    attachment JSONB DEFAULT NULL,
    is_deleted_for_everyone BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_comm_msg_conv_created ON community_messages(conversation_id, created_at DESC);

-- 3. 'Delete For Me' Exclusion Mapping (Local View Hiding)
CREATE TABLE IF NOT EXISTS community_message_deleted_users (
    message_id VARCHAR(120) NOT NULL REFERENCES community_messages(id) ON DELETE CASCADE,
    user_id VARCHAR(100) NOT NULL,
    deleted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (message_id, user_id)
);

-- 4. @Mention Notifications & Handles (WhatsApp style merchant tags)
CREATE TABLE IF NOT EXISTS community_message_mentions (
    id SERIAL PRIMARY KEY,
    message_id VARCHAR(120) NOT NULL REFERENCES community_messages(id) ON DELETE CASCADE,
    mentioned_handle VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_comm_mentions_handle ON community_message_mentions(mentioned_handle);
