docker-compose up -d

docker exec -it pgsql-db-1 bash

psql -h localhost -d my_notes_db -U admin -p 5432