DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS folders CASCADE;
DROP TABLE IF EXISTS notes CASCADE;
DROP TABLE IF EXISTS note_versions CASCADE;
DROP TABLE IF EXISTS favourite CASCADE;
DROP TABLE IF EXISTS tags CASCADE;
DROP TABLE IF EXISTS note_tags CASCADE;

CREATE TABLE users(
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) unique,
    email VARCHAR(100) UNIQUE,
    created_at timestamptz default current_timestamp
);

CREATE TABLE folders(
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    title VARCHAR(100) NOT NULL,
    created_at timestamptz default current_timestamp,
    unique(user_id, title)
);

CREATE TABLE notes(
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    folder_id INTEGER REFERENCES folders(id),
    title VARCHAR(100),
    content TEXT,
    created_at timestamptz default current_timestamp,
    deleted_at timestamptz default NULL
);

CREATE TABLE note_versions(
    id SERIAL PRIMARY KEY,
    note_id INTEGER REFERENCES notes(id) ON DELETE CASCADE,
    title VARCHAR(100),
    content TEXT,
    edited_by INTEGER REFERENCES users(id),
    created_at timestamptz default current_timestamp
);

CREATE TABLE favourite(
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    note_id INTEGER REFERENCES notes(id) ON DELETE CASCADE,
    PRIMARY KEY(user_id, note_id)
);

CREATE TABLE tags(
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) NOT NULL,
    title VARCHAR(100) NOT NULL,
    unique(user_id, title)
);

CREATE TABLE note_tags(
    note_id INTEGER REFERENCES notes(id) ON DELETE CASCADE,
    tag_id INTEGER REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY(note_id, tag_id)
);

CREATE TABLE note_permissions
(
    user_id INTEGER REFERENCES users(id),
    note_id INTEGER REFERENCES notes(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL,
    PRIMARY KEY(user_id, note_id)
);