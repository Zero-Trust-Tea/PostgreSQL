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

/*
 ------------------------
 | Trigger declaration. |
 ------------------------
*/

/*
 Function to check before interacting with favourite table,
 whether the table note_permissions, includes this user who interacts with favourite,
 (his id and note identifier) or not.

 If table includes user entry who requested data, from favourite table,
 then further interaction with table can be commited.

 Otherwise exception will be thrown.

 NEW - is is the SQL string, which PSQL created, and transfered it
 to the defined 'favourite_access_check' trigger.

 Then trigger execute this function, and 

*/
CREATE OR REPLACE FUNCTION check_favourite_access()
RETURNS trigger AS

$$
BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM note_permissions
            WHERE user_id = NEW.user_id
            AND note_id = NEW.note_id AND role IN ('owner', 'editor', 'viewer')
        ) THEN
            RAISE EXCEPTION 'No access to this note';
        END IF;

        RETURN NEW;
END;
$$
LANGUAGE plpgsql;


CREATE TRIGGER favourite_access_check
BEFORE INSERT ON favourite
FOR EACH ROW
EXECUTE FUNCTION check_favourite_access();

--
--
--

/*
 Function to check that single note doesn't have 2 owners.
 
 It checks if not inserted the access rights of the owner,
 to the single note, for the second time.

*/
CREATE OR REPLACE FUNCTION check_note_permissions_owner()
RETURNS trigger AS
$$
BEGIN

    IF EXISTS (
        SELECT 1 FROM note_permissions
        WHERE note_id = NEW.note_id
        AND role IN ('owner')
    ) THEN
        RAISE EXCEPTION 'Can not exist mote than 1 owner on single note';
    END IF;

    RETURN NEW;

END;
$$
LANGUAGE plpgsql;


CREATE TRIGGER note_permissions_owner_check
BEFORE INSERT ON note_permissions
FOR EACH ROW
EXECUTE FUNCTION check_note_permissions_owner();

--
--
--

/*
 Function to give the default access rights ("owner"), after
 the user has created the note.
    
*/
CREATE OR REPLACE FUNCTION assign_note_owner()
RETURNS trigger AS

$$
DECLARE
    user_id INTEGER;
    note_id INTEGER;
    role VARCHAR(20);
BEGIN
    user_id := NEW.user_id;
    note_id := NEW.id;
    role := 'owner';

    INSERT INTO note_permissions ("user_id", "note_id", "role")
    VALUES (user_id, note_id, role);

    RETURN NEW;

END;
$$

LANGUAGE plpgsql;

CREATE TRIGGER assign_note_owner
AFTER INSERT ON notes
FOR EACH ROW
EXECUTE FUNCTION assign_note_owner();

--
--
--


CREATE OR REPLACE FUNCTION save_note_history()
RETURNS TRIGGER AS

$$
BEGIN
    INSERT INTO note_versions ("note_id", "title", "content", "edited_by", "created_at")
    VALUES (NEW.id, NEW.title, NEW.content, NEW.user_id, NEW.created_at);

    RETURN NEW;
END;
$$

LANGUAGE plpgsql;

CREATE TRIGGER save_to_history
AFTER INSERT ON notes
FOR EACH ROW
EXECUTE FUNCTION save_note_history();

--
--


CREATE OR REPLACE FUNCTION note_versions_update()
RETURNS TRIGGER AS

$$
BEGIN

    IF (NEW.title IS DISTINCT FROM OLD.title OR 
        NEW.content IS DISTINCT FROM OLD.content)
    THEN

    INSERT INTO note_versions ("note_id", "title", "content", "edited_by", "created_at")
    VALUES (NEW.id, NEW.title, NEW.content, NEW.user_id, CURRENT_TIMESTAMP);

    END IF;

    RETURN NEW;
END;
$$

LANGUAGE plpgsql;

CREATE TRIGGER update_note_versions
AFTER UPDATE ON notes
FOR EACH ROW
EXECUTE FUNCTION note_versions_update();


/*
 --------------------------
 | Procedure declaration. |
 --------------------------
*/

/*
 Procedure to insert note to favourites (LIFO privilege).

 @param username_v The user, username identifier.
 @param title_v The note title, which belongs to user note.

 Procedure performs: SQL query which INSERT 

*/
CREATE OR REPLACE PROCEDURE insert_to_favourite(username_v VARCHAR(100), title_v VARCHAR(100))
AS

$$
DECLARE
    note_id_v INTEGER;
    user_id_v INTEGER;
BEGIN

    SELECT id INTO user_id_v FROM users
    WHERE users.username = username_v;

    IF user_id_v is NULL THEN
        RAISE WARNING 'User with username % not exists', username_v;
        RETURN;
    END IF;

    SELECT id INTO note_id_v FROM notes
    WHERE notes.user_id = user_id_v AND notes.title = title_v ORDER BY created_at DESC LIMIT 1;

    IF note_id_v IS NULL THEN
        RAISE WARNING 'Note for user % (id %), with title %, not found', username_v, user_id_v, title_v;
        RETURN;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM favourite
        WHERE favourite.note_id = note_id_v
    ) THEN
        INSERT INTO favourite ("user_id", "note_id")
        VALUES (user_id_v, note_id_v);

        RAISE INFO 'Note with id %, title %, added to favourites', note_id_v, title_v;
    ELSE
        RAISE NOTICE 'Note with id %, is arleady in favourites', note_id_v;
    END IF;
END;
$$

LANGUAGE plpgsql;


--
--

/*
 Function to remove note from favourites (LIFO privilege).

 @param username_v The user, username identifier.
 @param title_v The note title, which belongs to user note.

*/
CREATE OR REPLACE PROCEDURE delete_from_favourite(username_v VARCHAR(100), title_v VARCHAR(100))
AS

$$
DECLARE
    note_id_v INTEGER;
    user_id_v INTEGER;
BEGIN

    SELECT id INTO user_id_v FROM users
    WHERE users.username = username_v;

    IF user_id_v is NULL THEN
        RAISE WARNING 'User with username % not exists', username_v;
        RETURN;
    END IF;

    SELECT id INTO note_id_v FROM notes
    WHERE notes.user_id = user_id_v AND notes.title = title_v ORDER BY created_at DESC LIMIT 1;

    IF note_id_v IS NULL THEN
        RAISE WARNING 'Note for user % (id %), with title %, not found', username_v, user_id_v, title_v;
        RETURN;
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM favourite
        WHERE favourite.user_id = user_id_v AND favourite.note_id = note_id_v
    ) THEN
        DELETE FROM favourite
        WHERE favourite.user_id = user_id_v AND favourite.note_id = note_id_v;

        RAISE INFO 'Note with id %, title %, deleted from favourites', note_id_v, title_v;
    ELSE
        RAISE NOTICE 'Note with id %, is not in favourites', note_id_v;
    END IF;
END;
$$

LANGUAGE plpgsql;

--
--
--

CREATE OR REPLACE PROCEDURE insert_tag(username_v VARCHAR(100), tag_v VARCHAR(100))
AS

$$
DECLARE
    user_id_v INTEGER;
BEGIN

    SELECT id INTO user_id_v FROM users
    WHERE users.username = username_v;

    IF user_id_v IS NULL THEN
        RAISE WARNING 'User % not found', username_v;
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1 FROM tags
        WHERE tags.user_id = user_id_v AND tags.title = tag_v
    ) THEN
        RAISE NOTICE 'Tag with title %, for user %, arleady exists', tag_v, username_v;
        RETURN;
    ELSE
        INSERT INTO tags ("user_id", "title")
        VALUES (user_id_v, tag_v);

        RAISE INFO 'Tag %, for user %, inserted', tag_v, username_v;
    END IF;

    

END;
$$
LANGUAGE plpgsql;

--
--

CREATE OR REPLACE PROCEDURE delete_tag(username_v VARCHAR(100), tag_v VARCHAR(100))
AS

$$
DECLARE
    user_id_v INTEGER;
BEGIN

    SELECT id INTO user_id_v FROM users
    WHERE users.username = username_v;

    IF user_id_v IS NULL THEN
        RAISE WARNING 'User % not found', username_v;
        RETURN;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM tags
        WHERE tags.user_id = user_id_v AND tags.title = tag_v
    ) THEN
        RAISE NOTICE 'Tag with title %, for user %, does not exist', tag_v, username_v;
        RETURN;
    ELSE
        DELETE FROM tags
        WHERE tags.user_id = user_id_v AND tags.title = tag_v;

        RAISE INFO 'Tag %, for user %, has deleted', tag_v, username_v;
    END IF;

END;
$$
LANGUAGE plpgsql;

--
--
--

CREATE OR REPLACE PROCEDURE assign_note_tag(username_v VARCHAR(100), tag_v VARCHAR(100), note_title VARCHAR(100))
AS

$$
DECLARE
    user_id_v INTEGER;
    note_id_v INTEGER;
    tag_id_v INTEGER;
BEGIN

    SELECT id INTO user_id_v FROM users
    WHERE users.username = username_v;

    IF user_id_v IS NULL THEN
    RAISE WARNING 'User % not found', username_v;
    RETURN;
    END IF;

    SELECT id INTO note_id_v FROM notes
    WHERE notes.user_id = user_id_v AND notes.title = note_title LIMIT 1;

    IF note_id_v is NULL THEN
    RAISE WARNING 'Note with title %, for user %, not found', title, username_v;
    RETURN;
    END IF;

    SELECT id INTO tag_id_v FROM tags
    WHERE tags.user_id = user_id_v AND tags.title = tag_v LIMIT 1;

    IF tag_id_v IS NULL THEN
        RAISE WARNING 'Tag with label %, for user %, not exists', tag_v, username_v;
        RETURN;
    ELSE
        INSERT INTO note_tags ("note_id", "tag_id")
        VALUES (note_id_v, tag_id_v);

        RAISE INFO 'Tag %, inserted for note %, for user %', tag_v, note_title, username_v;
    END IF;

END;
$$
LANGUAGE plpgsql;

--
--

CREATE OR REPLACE PROCEDURE delete_note_tag(username_v VARCHAR(100), tag_v VARCHAR(100), note_title VARCHAR(100))
AS

$$
DECLARE
    user_id_v INTEGER;
    note_id_v INTEGER;
    tag_id_v INTEGER;
BEGIN

    SELECT id INTO user_id_v FROM users
    WHERE users.username = username_v;

    IF user_id_v IS NULL THEN
    RAISE WARNING 'User % not found', username_v;
    RETURN;
    END IF;

    SELECT id INTO note_id_v FROM notes
    WHERE notes.user_id = user_id_v AND notes.title = note_title LIMIT 1;

    IF note_id_v is NULL THEN
    RAISE WARNING 'Note with title %, for user %, not found', title, username_v;
    RETURN;
    END IF;

    SELECT id INTO tag_id_v FROM tags
    WHERE tags.user_id = user_id_v AND tags.title = tag_v LIMIT 1;

    IF tag_id_v IS NULL THEN
        RAISE WARNING 'Tag with label %, for user %, not exists', tag_v, username_v;
        RETURN;
    ELSE
        DELETE FROM note_tags
        WHERE note_tags.note_id = note_id_v AND note_tags.tag_id = tag_id_v;

        RAISE INFO 'Tag %, deleted from note %, for user %', tag_v, note_title, username_v;
    END IF;

END;
$$
LANGUAGE plpgsql;

--
--
--

CREATE OR REPLACE PROCEDURE insert_user (
    username_ VARCHAR(100),
    email_ VARCHAR(100)
    )
AS

$$
BEGIN
    IF EXISTS (
        SELECT 1 FROM users u
        WHERE u.username = username_
        ) THEN RAISE WARNING 'User with username % already exists', username_;
        RETURN;

    ELSIF EXISTS (
        SELECT 1 FROM users u
        WHERE u.email = email_
        ) THEN RAISE WARNING 'User with email % already exists', email_;
        RETURN;
    END IF;

    INSERT INTO users ("username", "email")
    VALUES (username_, email_);

    RAISE INFO 'User with username %, and email % successfully created', username_, email_;
END;
$$

LANGUAGE plpgsql;

--
--

CREATE OR REPLACE PROCEDURE delete_user_by_username (
    username_ VARCHAR(100)
    )
AS

$$
BEGIN
    IF EXISTS (
        SELECT 1 FROM users
        WHERE users.username = username_
        ) THEN
        DELETE FROM users
        WHERE users.username = username_;
        RAISE INFO 'User with username % has deleted', username_;
        RETURN;
    END IF;

    RAISE WARNING 'User with username % not found, delete operation skipped', username_;
END;
$$

LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE delete_user_by_email (
    email_ VARCHAR(100)
    )
AS

$$
BEGIN
    IF EXISTS (
        SELECT 1 FROM users
        WHERE users.email = email_
        ) THEN
        DELETE FROM users
        WHERE users.email = email_;
        RAISE INFO 'User with email % has deleted', email_;
        RETURN;
    END IF;

    RAISE WARNING 'User with email % not found, delete operation skipped', email_;
END;
$$

LANGUAGE plpgsql;

--
--
--

CREATE OR REPLACE PROCEDURE insert_note(username_ VARCHAR(100), title_ VARCHAR(100), content TEXT)
AS

$$
DECLARE
    user_id INTEGER;
BEGIN

    SELECT id FROM users INTO user_id
    WHERE users.username = username_ LIMIT 1;

    IF user_id IS NULL THEN RAISE WARNING 'User with username % not found', username_;
    RETURN;
    END IF;

    INSERT INTO notes ("user_id", "title", "content")
    VALUES (user_id, title_, content);

    RAISE INFO 'Note of user %, with title %, successfully inserted to notes', username_, title_;
END;
$$

LANGUAGE plpgsql;

--
--
--

CREATE OR REPLACE PROCEDURE soft_delete_note (username_ VARCHAR(100), title_ VARCHAR(100))
AS

$$
DECLARE
    user_id_ INTEGER;
BEGIN

    SELECT id FROM users INTO user_id_
    WHERE users.username = username_ LIMIT 1;

    IF user_id_ IS NULL THEN RAISE WARNING 'User with username % not found', username_;
    RETURN;
    END IF;

    UPDATE notes
    SET deleted_at = CURRENT_TIMESTAMP
    WHERE id = (SELECT id FROM notes WHERE notes.user_id = user_id_ AND notes.title = title_ ORDER BY notes.created_at DESC LIMIT 1);

    RAISE INFO 'Note of user %, with title %, transfered to deleted notes', username_, title_;
END;
$$

LANGUAGE plpgsql;

--
--

CREATE OR REPLACE PROCEDURE permanently_delete_note(username_ VARCHAR(100), title_ VARCHAR(100))
AS

$$
DECLARE
    user_id_ INTEGER;
BEGIN

    SELECT id FROM users INTO user_id_
    WHERE users.username = username_ LIMIT 1;

    IF user_id_ IS NULL THEN RAISE WARNING 'User with username % not found', username_;
    RETURN;
    END IF;

    DELETE FROM notes
    WHERE id = (SELECT id FROM notes WHERE notes.user_id = user_id_ AND notes.title = title_ ORDER BY notes.created_at DESC LIMIT 1);

    RAISE INFO 'Note of user %, with title %, permanently deleted from notes', username_, title_;
END;
$$

LANGUAGE plpgsql;


/*
 --------------------------
 | Trigger documentation. |
 --------------------------
*/

COMMENT ON TRIGGER favourite_access_check ON favourite
IS 'Used to check before inserting note to favourite by user, is user have access to perform this operation';

COMMENT ON TRIGGER note_permissions_owner_check ON note_permissions
IS 'Used for check, whether the user in note_permissions have acces as owner, to more than 1 note';

COMMENT ON TRIGGER assign_note_owner ON notes
IS 'Performing the access rights assignment after note creation';

COMMENT ON TRIGGER save_to_history ON notes
IS 'Saving the first version of note after creation, to versions table';

COMMENT ON TRIGGER update_note_versions ON notes
IS 'Updating the history of note versions, with new entries';


/*
 ----------------------------
 | Procedure documentation. |
 ----------------------------
*/

/*
 Functions and procedures to manage with CRUD operations.
*/

COMMENT ON PROCEDURE insert_user (VARCHAR, VARCHAR) IS 'Used for user insertion';
COMMENT ON PROCEDURE delete_user_by_username (VARCHAR) IS 'Used for user removal by username';
COMMENT ON PROCEDURE delete_user_by_email (VARCHAR) IS 'Used for user removal by email';

-- SELECT obj_description('insert_user(VARCHAR, VARCHAR)'::regprocedure) AS insert_user;
-- SELECT obj_description('delete_user_by_username (VARCHAR)'::regprocedure) AS delete_user_by_username;
-- SELECT obj_description('delete_user_by_email (VARCHAR)'::regprocedure) AS delete_user_by_email;

COMMENT ON PROCEDURE insert_note (VARCHAR, VARCHAR, TEXT) IS 'Insert note for specified user';
COMMENT ON PROCEDURE soft_delete_note (VARCHAR, VARCHAR) IS 'Used for soft note removal to archive';
COMMENT ON PROCEDURE permanently_delete_note (VARCHAR, VARCHAR) IS 'Used for permanently note removal';

-- SELECT obj_description('insert_note(VARCHAR, VARCHAR, TEXT)'::regprocedure) AS insert_note;
-- SELECT obj_description('soft_delete_note (VARCHAR, VARCHAR)'::regprocedure) AS soft_delete_note;
-- SELECT obj_description('permanently_delete_note (VARCHAR, VARCHAR)'::regprocedure) AS permanently_delete_note;

COMMENT ON PROCEDURE insert_tag (VARCHAR, VARCHAR) IS 'Insert tag for specified user, to his tags';
COMMENT ON PROCEDURE delete_tag (VARCHAR, VARCHAR) IS 'Delete tag from specified user';

-- SELECT obj_description('insert_tag (VARCHAR, VARCHAR)'::regprocedure) AS insert_tag;
-- SELECT obj_description('delete_tag (VARCHAR, VARCHAR)'::regprocedure) AS delete_tag;

COMMENT ON PROCEDURE assign_note_tag (VARCHAR, VARCHAR, VARCHAR) IS 'Assign user tag, to refered note';
COMMENT ON PROCEDURE delete_note_tag (VARCHAR, VARCHAR, VARCHAR) IS 'Unbind user tag, to refered note';

-- SELECT obj_description('assign_note_tag (VARCHAR, VARCHAR, VARCHAR)'::regprocedure) AS assign_note_tag;
-- SELECT obj_description('delete_note_tag (VARCHAR, VARCHAR, VARCHAR)'::regprocedure) AS delete_note_tag;

COMMENT ON PROCEDURE insert_to_favourite(VARCHAR, VARCHAR) IS 'Add to favourite, users note';
COMMENT ON PROCEDURE delete_from_favourite(VARCHAR, VARCHAR) IS 'Delete from favourite, users note';

-- SELECT obj_description('insert_to_favourite (VARCHAR, VARCHAR)'::regprocedure) AS insert_to_favourite;
-- SELECT obj_description('delete_from_favourite (VARCHAR, VARCHAR)'::regprocedure) AS delete_from_favourite;


/*
 ----------------------------
 | Tables records insertion. |
 ----------------------------
*/

-- users table insertion

INSERT INTO users ("username", "email", "created_at")
VALUES ('John Doe', 'johndoe@gmail.com', '2025-10-10');

INSERT INTO users ("username", "email", "created_at")
VALUES ('Jakob Tores', 'jakobtores@gmail.com', '2025-12-8');

INSERT INTO users ("username", "email", "created_at")
VALUES ('Susannah Cochran', 'susannahcochran@gmail.com', '2025-07-12');

INSERT INTO users ("username", "email", "created_at")
VALUES ('Amie Melton', 'amiemelton@gmail.com', '2025-05-14');

INSERT INTO users ("username", "email", "created_at")
VALUES ('Macie Price', 'macieprice@gmail.com', '2025-07-15');

INSERT INTO users ("username", "email", "created_at")
VALUES ('Kimberley Wade', 'kimberlewade@hotmail.com', '2025-07-15');

INSERT INTO users ("username", "email", "created_at")
VALUES ('Ela Waleria', 'elawaleria@yahoo.com', '2025-07-15');

INSERT INTO users ("username", "email", "created_at")
VALUES ('Rubin Howe', 'rubinhowe@outlook.com', '2025-02-05');

INSERT INTO users ("username", "email", "created_at")
VALUES ('Drew Atkins', 'drewatkins@gmail.com', '2025-03-04');

INSERT INTO users ("username", "email", "created_at")
VALUES ('Carly Hahn', 'carlyhahn@yahoo.com', '2025-04-17');

INSERT INTO users ("username", "email", "created_at")
VALUES ('Carrol Case', 'carrolcase@protonmail.com', '2025-05-02');

INSERT INTO users ("username", "email", "created_at")
VALUES ('Anna Zhang', 'annazhang@proton.me', '2025-02-21');


-- notes table insertion

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (1, 'Flowers', 'Water the flowers.', '2026-02-15');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (2, 'Dog', 'Walk the dog.', '2026-02-17');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (2, 'Pancake', 'Make the pancakes.', '2026-02-18');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (3, 'Bread', 'Get the bread.', '2026-02-18');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (3, 'Cutlet', 'Fry the catlet.', '2026-02-18');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (4, 'Milk', 'Get the milk.', '2026-02-19');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (4, 'Salad', 'Make a salad.', '2026-02-18');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (5, 'Car', 'Wash the car.', '2026-02-20');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (5, 'Car', 'Park the car.', '2026-02-21');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (6, 'Bank', 'Rob the bank.', '2026-02-20');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (6, 'Street food', 'Buy the hot dog.', '2026-02-21');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (7, 'Deer', 'Hunt the deer.', '2026-03-09');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (7, 'Dinner', 'Prepare the deer for dinner.', '2026-02-09');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (8, 'Zoo', 'Went to the zoo with family.', '2026-02-25');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (8, 'Ice cream', 'Treat the family with ice cream.', '2026-03-25');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (9, 'Grocery', 'Buy fresh vegetables for salad.', '2026-03-01');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (9, 'Flower shop', 'Buy the flowers to the wife.', '2026-04-02');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (10, 'Exhibition', 'Go to the art exhibition in Viena.', '2026-01-10');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (10, 'Stree food', 'Buy a schnitzel.', '2026-01-09');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (11, 'Pizza', 'Order peperoni pizza at the afternoon.', '2026-01-12');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (11, 'Haircut', 'Make the haircut.', '2026-01-12');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (12, 'Sandwich', 'Cook the fried cheese, tomato, salad, crunchy sandwich.', '2026-01-28');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (12, 'Garden', 'Water the garden.', '2026-02-20');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (12, 'Drop by shop', '', '2026-03-20');

INSERT INTO notes ("user_id", "title", "content", "created_at")
VALUES (12, '', 'Go to park.', '2026-02-17');

CALL insert_note('Anna Zhang', 'Note', 'content of the note');

CALL soft_delete_note('Anna Zhang', 'Note');

CALL permanently_delete_note('Anna Zhang', 'Note');

CALL soft_delete_note('Macie Price', 'Car');

--
--

UPDATE notes
SET title = 'Flowers', content = 'Fertilizing flowers.'
WHERE notes.id = 1 AND user_id = 1;

UPDATE notes
SET title = 'Pancake', content = 'Make the oatmeal pancakes.'
WHERE notes.id = 3 AND user_id = 2;

UPDATE notes
SET title = 'Cutlet', content = 'Fry the catlet and add onion and salt.'
WHERE notes.id = 5 AND user_id = 3;

UPDATE notes n
SET title = 'Salad', content = 'Make a caesar salad. Add fried croutons, and fried chicken and also the caesar sauce.'
WHERE n.id = 7 AND n.user_id = 4;

UPDATE notes n
SET title = 'Vanila Ice cream', content = 'Treat the family with vanila ice cream.'
WHERE n.id = 15 AND n.user_id = 8;

UPDATE notes n
SET title = 'Garden.', content = 'Water the garden and plant tomatoes.'
WHERE n.id = 23 AND n.user_id = 12;

UPDATE notes n
SET title = 'Garden.', content = 'Water the garden and plant potato.'
WHERE n.id = 23 AND n.user_id = 12;

UPDATE notes n
SET title = 'Garden.', content = 'Dig up the garden.'
WHERE n.id = 23 AND n.user_id = 12;

UPDATE notes n
SET title = 'Garden plumbing.', content = 'Upgrade the garden plumbing system.'
WHERE n.id = 23 AND n.user_id = 12;


INSERT INTO favourite ("user_id", "note_id")
VALUES (1, 1);

INSERT INTO favourite ("user_id", "note_id")
VALUES (2, 3);

INSERT INTO favourite ("user_id", "note_id")
VALUES (3, 4);

INSERT INTO favourite ("user_id", "note_id")
VALUES (4, 6);

INSERT INTO favourite ("user_id", "note_id")
VALUES (5, 8);

INSERT INTO favourite ("user_id", "note_id")
VALUES (6, 10);

INSERT INTO favourite ("user_id", "note_id")
VALUES (6, 11);

INSERT INTO favourite ("user_id", "note_id")
VALUES (7, 12);

CALL insert_to_favourite('Robin Howe', 'Zoo');

CALL delete_from_favourite('John Doe', 'Flowers');

-- tags insertion

INSERT INTO tags ("user_id", "title")
VALUES (1, 'flowers');

INSERT INTO tags ("user_id", "title")
VALUES (2, 'pancake');

INSERT INTO tags ("user_id", "title")
VALUES (3, 'bread');

INSERT INTO tags ("user_id", "title")
VALUES (4, 'milk');

INSERT INTO tags ("user_id", "title")
VALUES (5, 'wash');

INSERT INTO tags ("user_id", "title")
VALUES (5, 'park');

INSERT INTO tags ("user_id", "title")
VALUES (6, 'robbery');

INSERT INTO tags ("user_id", "title")
VALUES (6, 'street food');

INSERT INTO tags ("user_id", "title")
VALUES (7, 'hunt');

-- note_tags insertion to connect tags and notes

INSERT INTO note_tags("note_id", "tag_id")
VALUES (1, 1);

INSERT INTO note_tags("note_id", "tag_id")
VALUES (3, 2);

INSERT INTO note_tags("note_id", "tag_id")
VALUES (4, 3);

INSERT INTO note_tags("note_id", "tag_id")
VALUES (6, 4);

INSERT INTO note_tags("note_id", "tag_id")
VALUES (8, 5);

INSERT INTO note_tags("note_id", "tag_id")
VALUES (9, 6);

INSERT INTO note_tags("note_id", "tag_id")
VALUES (10, 7);

INSERT INTO note_tags("note_id", "tag_id")
VALUES (11, 8);

INSERT INTO note_tags("note_id", "tag_id")
VALUES (12, 9);

CALL delete_tag('Jakob Tores', 'pancake');

-- folders insertion

INSERT INTO folders ("user_id", "title")
VALUES (1, 'Housework');

INSERT INTO folders ("user_id", "title")
VALUES (2, 'Daily tasks');

INSERT INTO folders ("user_id", "title")
VALUES (2, 'Cooking');

INSERT INTO folders ("user_id", "title")
VALUES (2, 'Vacuum cleaning');

INSERT INTO folders ("user_id", "title")
VALUES (3, 'To buy');

INSERT INTO folders ("user_id", "title")
VALUES (3, 'Cooking');

INSERT INTO folders ("user_id", "title")
VALUES (4, 'Products');

INSERT INTO folders ("user_id", "title")
VALUES (5, 'Autowash');

INSERT INTO folders ("user_id", "title")
VALUES (5, 'Garage');

-- update values of folders, depending on: existing user, user_id general for folders and notes
-- and special user note_title and folder_title
UPDATE notes
SET folder_id = folders.id
FROM folders, users
WHERE notes.user_id = users.id AND
    notes.user_id = folders.user_id AND notes.title LIKE '%Flowers%'
  AND folders.title LIKE '%Housework%';

UPDATE notes
SET folder_id = folders.id
FROM folders, users
WHERE notes.user_id = users.id AND
    notes.user_id = folders.user_id AND notes.title LIKE '%Dog%'
  AND folders.title LIKE '%Daily tasks%';

UPDATE notes
SET folder_id = folders.id
FROM folders, users
WHERE notes.user_id = users.id AND
    notes.user_id = folders.user_id AND notes.title LIKE '%Pancake%'
  AND folders.title LIKE '%Cooking%';

UPDATE notes
SET folder_id = folders.id
FROM folders, users
WHERE notes.user_id = users.id AND
    notes.user_id = folders.user_id AND notes.title LIKE '%Bread%'
  AND folders.title LIKE '%To buy%';

UPDATE notes
SET folder_id = folders.id
FROM folders, users
WHERE notes.user_id = users.id AND
    notes.user_id = folders.user_id AND notes.title LIKE '%Cutlet%'
  AND folders.title LIKE '%Cooking%';

UPDATE notes
SET folder_id = folders.id
FROM folders, users
WHERE notes.user_id = users.id AND
    notes.user_id = folders.user_id AND notes.title LIKE '%Milk%'
  AND folders.title LIKE '%Products%';

UPDATE notes
SET folder_id = folders.id
FROM folders, users
WHERE notes.user_id = users.id AND
    notes.user_id = folders.user_id AND notes.title LIKE '%Car%'
  AND folders.title LIKE '%Autowash%';


/*
 ----------------------
 | Records selection. |
 ----------------------
*/


/*
 Untrivial select query with one table,
 that analyze "gmail" email users association, and other users email percent assicoation.

 This query processes two records, from table `users`, calculating from the percent of users,
 from total amount of users who have association with gmail provider in their emails entries, and who dont have association
 with the gmail provider in their mail.
 
 The first record using the calculation formula as 100% * [number_of_users_with_gmail]/[total_number_of_users].
 The second record using the calculation formula as 100% * [number_of_users_not_with_gmail]/[total_number_of_users].

 */
CREATE VIEW user_percent_with_gmail_mail AS
SELECT
    100.0 * COUNT(CASE WHEN email LIKE '%gmail.com%' THEN 1 END) / COUNT (*) AS gmail_percent,
    100.0 * COUNT(CASE WHEN email NOT LIKE '%gmail.com%' THEN 1 END) / COUNT(*) AS other_percent,
    COUNT (*) AS amount_of_users
FROM users;

SELECT  'Percent of users with "gmail" email and others';
SELECT * FROM user_percent_with_gmail_mail;

/*
 This untrivial select query, for one table,
 performs check of nnotes quality, depending on it title present,
 and content length.

 This query performs the SELECT of
 id, user_id, display_title (That returns the first non-null argument, in case if note title exists it returns it,
 else title is replaced), content_length (using LENGTH build-in function),
 quality_status (it performs a CASE check, where if title is NULL or empty, sets it value as "missing",
 then in other case, if content length is less than 10, check persorms using LENGTH function, then it sets that content is "too short",
 in third case, it's sets quality_status as "valid") from notes, and checks that note is not in deleted.
*/
CREATE VIEW view_notes_quality_check AS
SELECT id, user_id, COALESCE(title, 'Untitled Note') AS display_title, LENGTH(content) AS content_length,
    CASE 
        WHEN title IS NULL OR title = '' THEN 'Missing Title'
        WHEN LENGTH(content) < 10 THEN 'Too Short'
        ELSE 'Valid'
    END AS quality_status
FROM notes
WHERE deleted_at IS NULL;

SELECT 'Notes with missing title, or small amount of content, check';
SELECT * FROM view_notes_quality_check;

/*
 This query for one table,
 performs a analyzis of activity in editing notes,
 comparing how often people change their notes, depending
 on results from note_versions table.

 This query, as a result returns from `note_versions` table:
 note_id (as value of differen note versions, grouped by that identifier),
 total_edits (as a result of COUNT id, that is a result of resulting entries, that grouped in groups by note_id identifier),
 last_edit_timestamp (returns the MAX value of last time edit from the group of notes),
 first_edit_timestamp (returns LOW value of first time edit, from group of entries),
 edit_activity (is a conclusion, depending on a amount of note entries in group, made by CASE statement).

*/
CREATE VIEW view_note_edit_stats AS
SELECT 
    note_id,
    COUNT(id) AS total_edits,
    MAX(created_at) AS last_edit_timestamp,
    MIN(created_at) AS first_edit_timestamp,
    CASE 
        WHEN COUNT(id) > 4 THEN 'High'
        WHEN COUNT(id) BETWEEN 2 AND 4 THEN 'Medium'
        ELSE 'Low'
    END AS edit_activity
FROM note_versions
GROUP BY note_id;

SELECT 'Statistics, of note editing activity';
SELECT * FROM view_note_edit_stats;

/*
 This query, uses a connection of three tables,
 notes, favourite, users,
 to select the favourite notes of users.

 This select performs, selection
 of records username, user_id, title,
 content, notes.id, from `notes` table,
 connecting by inner match with table `favourite` by id of note,
 and by inner match with table of `users` by id of user.

*/
SELECT 'Favourite of users';
SELECT users.username, notes.user_id, notes.title, notes.content, notes.id FROM notes join favourite on notes.id = favourite.note_id join users on users.id = notes.user_id;

/*
 This query, performs a associative select of tags,
 and notes associated to it, and users.

 This one selects, title (title of tag), username, notes.content (that belongs to this tag), notes.id, FROM `tags` table,
 and then connects the query with the `note_tags` table, by inner match of note identifier, connects with `notes` table by
 connection with note_tags and notes table note identifier, and connection of users and notes user identifier.

*/
SELECT 'Tags associated to notes';
SELECT tags.title AS "tag", users.username, notes.content, notes.id FROM tags
join note_tags on tags.id = note_tags.tag_id join notes on notes.id = note_tags.note_id join users on users.id = notes.user_id;

/*
 This query performs selection of notes, from folders,
 that only contain notes. It performs the connection of tables,
 folders, notes, and users.

*/
SELECT 'Notes from folders: ';
SELECT users.id AS "users.id", folder_id, folders.title AS "folder_title", folders.created_at, notes.id AS "note_id", notes.title AS "note_title", notes.content FROM folders
inner join notes on notes.folder_id = folders.id join users on users.id = folders.user_id;

/*
 This query performs a select of notes,
 that are in favourite of user, and if user has no favourite,
 so he will have replaced the note title.

 It recieves a username, title (first title, that recieves by select request from user favourite notes), from users, performs an outer join connection with table
 `favourite` by identifier user id, and performs outer join connection with `favourite_notes` and `notes` by note identifier. 

*/
SELECT 'Users with notes in favourite and other users';
SELECT users.username, COALESCE(notes.title, 'No favourite notes') AS "favourite_note" FROM users LEFT JOIN favourite on users.id = favourite.user_id
                                                                  LEFT JOIN notes on favourite.note_id = notes.id;
/*
 This query performs a selection of folders and notes, showing their connection,
 including folders without notes and notes that are not assigned to any folder.
 
 It performs a FULL OUTER JOIN between `folders` and `notes` by folder identifier,
 and a LEFT JOIN with `users` table to retrieve the username, using COALESCE 
 to handle the user identifier from either the folder or the note.

*/
SELECT 'Folders with notes and without, and notes with and without folders';
SELECT u.username, f.title AS folder_title, f.created_at AS folder_created, n.title AS note_title, n.id AS note_id
FROM folders f
FULL OUTER JOIN notes n ON f.id = n.folder_id
LEFT JOIN users u ON COALESCE(f.user_id, n.user_id) = u.id
ORDER BY u.username, folder_title, note_title;

/*
 This query performs a comparative analysis of user organization styles,
 depending on their usage of folders and tags.
 
 Using a FULL OUTER JOIN between `folders` and `tags` by user identifier, 
 and a CASE statement, it categorizes users into "Well Organized", 
 "Uses Folders Only", "Uses Tags Only", or "No Structure" based on 
 the presence of records in respective tables.

*/
SELECT 'Comparing, of users note saving, structure organization';
SELECT DISTINCT u.username, f.title AS folder_name, t.title AS tag_name,
    CASE 
        WHEN f.id IS NOT NULL AND t.id IS NOT NULL THEN 'Well Organized'
        WHEN f.id IS NOT NULL THEN 'Uses Folders Only'
        WHEN t.id IS NOT NULL THEN 'Uses Tags Only'
        ELSE 'No Structure'
    END AS user_style
FROM folders f
FULL OUTER JOIN tags t ON f.user_id = t.user_id 
LEFT JOIN users u ON COALESCE(f.user_id, t.user_id) = u.id
ORDER BY u.username, folder_name;

/*
 This query performs a selection of notes that have a history of changes,
 retrieving only those that have two or more versions.
 
 It uses a subquery with GROUP BY and HAVING COUNT(*) >= 2 to filter 
 the `note_versions` table, and returns the note_id, title, and content 
 ordered by the version timestamp to track the evolution of the note.

*/
SELECT 'Notes with the history of changes';
SELECT note_id, title, content, created_at AS version_timestamp
FROM note_versions
WHERE note_id IN (
    SELECT note_id 
    FROM note_versions 
    GROUP BY note_id 
    HAVING COUNT(*) >= 2
)
ORDER BY note_id, created_at ASC;

/*
 This query creates a view that performs a statistical analysis of user activity,
 calculating the total amount of notes, favorites, and folders for each user.
 
 It performs multiple LEFT JOIN connections between `users`, `notes`, `favourite`, 
 and `folders` tables, using COUNT(DISTINCT ...) to ensure unique records 
 are counted for each auxiliary identifier, grouped by user details.

*/
CREATE VIEW users_notes_statistics AS
SELECT users.username, users.email, COUNT(DISTINCT notes.id)
    AS notes, COUNT(DISTINCT favourite.user_id) AS favourite, COUNT(DISTINCT folders.id) AS folders FROM users LEFT join notes on users.id = notes.user_id
    LEFT JOIN favourite on favourite.user_id = users.id LEFT JOIN folders on folders.user_id  = users.id
    GROUP BY users.id, users.username, users.email;

SELECT 'Users note statistics of working with auxiliary identifiers';
SELECT * FROM users_notes_statistics;

/*
 This query creates a view that performs a detailed analysis of folder content,
 including the total number of notes, the count of deleted notes, and average content size.
 
 It connects `folders`, `users`, and `notes` tables, applying a FILTER for 
 deleted notes and the ROUND(AVG(LENGTH(...))) function for content metrics. 
 The result is filtered by HAVING to include only folders that contain at least one note.
 
*/
CREATE VIEW folders_statistics AS
SELECT u.username, f.title AS folder_name, COUNT(n.id) AS total_notes, COUNT(n.id) FILTER (WHERE n.deleted_at IS NOT NULL) AS deleted_notes,
    ROUND(AVG(LENGTH(n.content)), 2) AS avg_content_size
FROM folders f
JOIN users u ON f.user_id = u.id
LEFT JOIN notes n ON f.id = n.folder_id
GROUP BY u.id, f.id
HAVING COUNT(n.id) > 0
ORDER BY avg_content_size DESC;

SELECT 'Folders statistics';
SELECT * FROM folders_statistics;