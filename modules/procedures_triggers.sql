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

--
--
--

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
