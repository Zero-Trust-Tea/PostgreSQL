## Notes :clipboard:

System for note management, written in PostgreSQL.

## Features ✨

- User control
- Notes managemant
- History of changes
- Access control
- Structure identifiers (folders, tags)
- Add to favorites

> [!NOTE]
> This project designs a managemant system for notes interaction. It contains creation of table scheme, data insertion, data retrieving, procedures and triggers.

### Entity relation model
---

<img width="800" height="550" alt="notes  entity-relational scheme" src="https://github.com/user-attachments/assets/b3d62617-5f41-47a0-8e53-0145ce97a249" />

<br>

## Usage 🚣 

<b>Via docker compose</b>

```
services:
    db:
        image: postgres:15-alpine
        container_name: pgsql-db-1
        environment:
            POSTGRES_DB: ${PGDATABASE}
            POSTGRES_USER: ${PGUSER}
            POSTGRES_PASSWORD: ${PGPASSWORD}
        volumes:
        - ./:/script
        - ./main.sql:/docker-entrypoint-initdb.d/main.sql
        ports:
        - "${PGPORT}:5432"

```

<b>Execute</b>

```
docker-compose up -d
```

<b>Enter the interface</b>

```
docker exec -it pgsql-db-1 bash
```


<b>Login to terminal-based iteractive CLI</b>

```
psql -h localhost -d my_notes_db -U admin -p 5432
```
