![i.sh](docs/logo.png)

Database engine completely built in bash.

Note: It's a work in progress, so please don't use it yet. The storage format can still change.


## Features
	* SQL-like syntax on the commandline
	* Runs completely on bash. Relies on grep, awk, etc.
	* Just one dependency.
	* Create tables
	* Insert / update records
	* Search, fetch by ID, list all records in table


## Dependencies

	* jq (for json support)


## Examples

```bash

# Create database
$ i.sh --create --database=test
OK

# Select database
$ i.sh --use=test
OK

# Create table
$ i.sh --create --table=tabletest --columns='table text, chair text, awesome int'
OK

# Show table info (incorrect table name)
$ i.sh --describe=tabletesTTT
Error: Table "tabletesTTT" does not exist.

# Show table info (incorrect database name)
$ i.sh --describe=cake.tabletest
Fatal: Database "cake" doesn\'t exist.

# Show table info (default is json)
$ i.sh --describe=tabletest
[
  {
    "name": "id",
    "type": "text"
  },
  {
    "name": "table",
    "type": "text"
  },
  {
    "name": "chair",
    "type": "text"
  },
  {
    "name": "awesome",
    "type": "int"
  }
]

# Show table info (in table format)
$ i.sh --describe=tabletest --tabular

| name         | type
=======================
| id           | text
| table        | text
| chair        | text
| awesome      | int

# Insert record into table
$ i.sh --insert --into=tabletest --table="Flattened oak tree" --chair="Unflattened pine blob" --awesome=9001
15c0a959-4167-474b-b963-79f17a1f0713

# select from table, in table format
$ i.sh --select=* --from=tabletest --tabular

| awesome      | chair                      | id                                        | table
==========================================================================================================
| 9001         | unflattened pine blob      | 15c0a959-4167-474b-b963-79f17a1f0713      | Flattened oak tree

```

## Reference docs (ish)
```bash
Records
	Read
		i.sh --select=id,title --from=table
		i.sh --select=id,title --from=table
		i.sh --select=title --from=table --id=id
		i.sh --select=* --from=table --find="search string"

	Create
		i.sh --insert --into=table --title=title --content=value

	Update
		i.sh --update=table --id=id --title="new title"

	Delete
		i.sh --delete --from=table --id=id

Tables
	Describe table
		i.sh --describe=table

	Create table
		i.sh --create --table=table

	Drop table
		i.sh --drop --table=table

	Add column
		i.sh --alter --table=table --addcolumn='name type'

Databases
	Select database
		i.sh --use=database

	Database in tablename
		i.sh --select=* --from=database.table

Structure
	Show tables
		i.sh --show --tables

	Show databases
		i.sh --show --databases

```

