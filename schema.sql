-- SQL DDL Schema for Barbershop Management & Booking System
-- Dialect: PostgreSQL (compatible with standard SQL)

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enums
CREATE TYPE communication_channel AS ENUM ('SMS', 'Telegram', 'WhatsApp', 'VK');
CREATE TYPE account_status AS ENUM ('ACTIVE', 'BLOCKED', 'PENDING');
CREATE TYPE loyalty_tier AS ENUM ('NEW', 'REGULAR', 'VIP');
CREATE TYPE employee_role_type AS ENUM ('Master', 'Manager');
CREATE TYPE slot_status AS ENUM ('FREE', 'BOOKED', 'COMPLETED', 'CANCELLED');
CREATE TYPE discount_type_enum AS ENUM ('PERCENT', 'FIXED_AMOUNT');
CREATE TYPE notification_status_enum AS ENUM ('PENDING', 'SENT', 'FAILED');

-- 1. Persons: Central user registry
CREATE TABLE persons (
    person_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    login VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    patronymic VARCHAR(50),
    phone_number VARCHAR(12) NOT NULL UNIQUE,
    registration_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    preferred_channel communication_channel NOT NULL DEFAULT 'SMS',
    status account_status NOT NULL DEFAULT 'ACTIVE'
);

-- 2. Clients: Client-specific domain data
CREATE TABLE clients (
    client_id BIGSERIAL PRIMARY KEY,
    person_id UUID NOT NULL UNIQUE REFERENCES persons(person_id) ON DELETE CASCADE,
    registration_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    preferred_channel communication_channel NOT NULL DEFAULT 'SMS',
    total_visits INT NOT NULL DEFAULT 0,
    loyalty_status loyalty_tier NOT NULL DEFAULT 'NEW',
    manager_notes TEXT
);

-- 3. Employees: Staff data
CREATE TABLE employees (
    employee_id BIGSERIAL PRIMARY KEY,
    person_id UUID NOT NULL UNIQUE REFERENCES persons(person_id) ON DELETE CASCADE,
    registration_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    hire_date DATE NOT NULL,
    position VARCHAR(50) NOT NULL,
    hourly_rate DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    rating DECIMAL(3, 2),
    status account_status NOT NULL DEFAULT 'ACTIVE'
);

-- 4. Employee Roles: Association table for staff roles
CREATE TABLE employee_roles (
    role_assignment_id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL REFERENCES employees(employee_id) ON DELETE CASCADE,
    role employee_role_type NOT NULL,
    CONSTRAINT uq_employee_role UNIQUE (employee_id, role)
);

-- 5. Services: Catalog of provided services
CREATE TABLE services (
    service_id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

-- 6. Master Services: M2M relationship between staff and eligible services
CREATE TABLE master_services (
    master_service_id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL REFERENCES employees(employee_id) ON DELETE CASCADE,
    service_id BIGINT NOT NULL REFERENCES services(service_id) ON DELETE CASCADE,
    CONSTRAINT uq_master_service UNIQUE (employee_id, service_id)
);

-- 7. Service Slots: Appointment schedule and booking slots
CREATE TABLE service_slots (
    slot_id BIGSERIAL PRIMARY KEY,
    slot_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    master_id BIGINT NOT NULL REFERENCES employees(employee_id) ON DELETE RESTRICT,
    client_id BIGINT REFERENCES clients(client_id) ON DELETE SET NULL,
    service_id BIGINT NOT NULL REFERENCES services(service_id) ON DELETE RESTRICT,
    status slot_status NOT NULL DEFAULT 'FREE',
    CONSTRAINT chk_slot_time CHECK (start_time < end_time)
);

-- 8. Client Discounts: Personalized customer discounts (Extended)
CREATE TABLE client_discounts (
    discount_id BIGSERIAL PRIMARY KEY,
    client_id BIGINT NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,
    discount_type discount_type_enum NOT NULL DEFAULT 'PERCENT',
    discount_value DECIMAL(10, 2) NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    comment VARCHAR(255)
);

-- 9. Client Notifications: History and outbox for omnichannel messages (Extended)
CREATE TABLE client_notifications (
    notification_id BIGSERIAL PRIMARY KEY,
    client_id BIGINT NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,
    notification_type VARCHAR(30) NOT NULL,
    channel communication_channel NOT NULL,
    message_text TEXT NOT NULL,
    sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status notification_status_enum NOT NULL DEFAULT 'SENT',
    error_message VARCHAR(255)
);

-- Indexes for performance
CREATE INDEX idx_slots_date_master ON service_slots(slot_date, master_id);
CREATE INDEX idx_slots_client ON service_slots(client_id);
CREATE INDEX idx_discounts_client ON client_discounts(client_id, is_active);
CREATE INDEX idx_notifications_client ON client_notifications(client_id);
