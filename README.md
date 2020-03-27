![i.sh](docs/logo.png)
Database engine completely built in bash.


## Features
	- SQL-like syntax on the commandline
	- Runs completely on bash. Relies on grep, awk, etc.
	- Just one dependency.
	- Create tables
	- Insert / update records
	- Search, fetch by ID, list all records in table


## Dependencies

	- jq (for json support)


## Examples

```bash
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

```

