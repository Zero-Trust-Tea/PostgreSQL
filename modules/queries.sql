
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