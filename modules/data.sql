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