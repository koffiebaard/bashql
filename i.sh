#!/bin/bash

curdir="$(dirname "$0")";

source "$curdir/lib/db-connector.sh";
source "$curdir/tasks.sh";

sanitized_arguments=$(echo "$@" | sed 's/\(--[a-zA-Z_]*\)/\n\1\n/g' | grep "^--" | paste -sd " ");


# database fetches from the db from anywhere, including the table name
# run it in the current shell so it can set the global variables
set_database

if [[ $(database) == "" ]]; then

	# these routes (copied from below) don't need a database connection
	if  [[ $(get_argument "use") != "" ]] || \
	    [[ $(get_argument "help") == 1 ]] || \
		[[ $(get_argument "create") != "" && $(get_argument "database") != "" ]] || \
		[[ $(get_argument "drop") != "" && $(get_argument "database") != "" ]] || \
		[[ $(get_argument "show") == 1 && $(get_argument "databases") == 1 ]] || \
		[[ $(get_argument "rename") != "" && $(get_argument "database") != "" && $(get_argument "to") != "" ]]; then

		printf "";
	else
		fatal "Database not selected or doesn't exist.";
		exit 1;
	fi
fi



if [[ $(get_argument "use") != "" ]]; then
	task_persist_database

elif [[ $(get_argument "show") == 1 && $(get_argument "tables") == 1 ]]; then
	task_list_tables

elif [[ $(get_argument "show") == 1 && $(get_argument "databases") == 1 ]]; then
	task_list_databases

elif [[ $(get_argument "describe") != "" ]]; then
	task_info_table

elif [[ $(get_argument "select") != "" && $(get_argument "from") != "" && $(get_argument 'id') != "" ]]; then
	task_get_record_by_id

elif [[ $(get_argument "select") != "" && $(get_argument "from") != "" && $(get_argument "find") != "" ]]; then
	task_search_in_table

elif [[ $(get_argument "select") != "" && $(get_argument "from") != "" ]]; then
	task_list_records_in_table

elif [[ $(get_argument "delete") == 1 && $(get_argument "from") != "" && $(get_argument "id") != "" ]]; then
	task_delete_record

elif [[ $(get_argument "insert") == 1 && $(get_argument "into") != "" ]]; then
	task_add_record

elif [[ $(get_argument "update") != "" && $(get_argument "id") != "" ]]; then
	task_update_record

elif [[ $(get_argument "create") != "" && $(get_argument "table") != "" ]]; then
	task_create_table

elif [[ $(get_argument "alter") == "" && $(get_argument "drop") != "" && $(get_argument "table") != "" ]]; then
	task_drop_table

elif [[ $(get_argument "alter") != "" && $(get_argument "table") != "" && $(get_argument "addcolumn") != "" ]]; then
	task_add_column

elif [[ $(get_argument "alter") == 1 && $(get_argument "table") != "" && $(get_argument "rename") != "" && $(get_argument "to") != "" ]]; then
	task_rename_column

elif [[ $(get_argument "alter") == 1 && $(get_argument "table") != "" && $(get_argument "drop") != "" ]]; then
	task_drop_column

elif [[ $(get_argument "alter") == "" && $(get_argument "rename") != "" && $(get_argument "table") != "" && $(get_argument "to") != "" ]]; then
	task_rename_table

elif [[ $(get_argument "create") != "" && $(get_argument "database") != "" ]]; then
	task_create_database

elif [[ $(get_argument "drop") != "" && $(get_argument "database") != "" ]]; then
	task_drop_database

elif [[ $(get_argument "alter") == "" && $(get_argument "rename") != "" && $(get_argument "database") != "" && $(get_argument "to") != "" ]]; then
	task_rename_database

elif [[ $(get_argument 'dino') == 1 ]]; then
	task_dino

elif [[ $(get_argument 'help') == 1 ]]; then

	echo "i.sh v0.1"
	echo ""
	echo "$(tput setaf 7)Records$(tput sgr0)"
	echo "	$(tput setaf 7)Read$(tput sgr0)"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--select=$(tput sgr0)id,title $(tput setaf 6)--from=$(tput sgr0)table"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--select=$(tput sgr0)id,title $(tput setaf 6)--from=$(tput sgr0)table"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--select=$(tput sgr0)title $(tput setaf 6)--from=$(tput sgr0)table $(tput setaf 6)--id=$(tput sgr0)id"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--select=$(tput sgr0)* $(tput setaf 6)--from=$(tput sgr0)table $(tput setaf 6)--find=$(tput sgr0)\"search string\""
	echo ""
	echo "	$(tput setaf 7)Create$(tput sgr0)"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--insert $(tput sgr0)$(tput setaf 6)--into=$(tput sgr0)table $(tput setaf 6)--title=$(tput sgr0)title $(tput setaf 6)--content=$(tput sgr0)value"
	echo ""
	echo "	$(tput setaf 7)Update$(tput sgr0)"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--update=$(tput sgr0)table $(tput setaf 6)--id=$(tput sgr0)id $(tput setaf 6)--title=$(tput sgr0)\"new title\""
	echo ""
	echo "	$(tput setaf 7)Delete$(tput sgr0)"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--delete $(tput sgr0)$(tput setaf 6)--from=$(tput sgr0)table $(tput setaf 6)--id=$(tput sgr0)id"
	echo ""
	echo "$(tput setaf 7)Tables$(tput sgr0)"
	echo "	$(tput setaf 7)Describe table$(tput sgr0)"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--describe=$(tput sgr0)table"
	echo ""
	echo "	$(tput setaf 7)Create table$(tput sgr0)"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--create $(tput sgr0)$(tput setaf 6)--table=$(tput sgr0)table $(tput setaf 6)--columns=$(tput sgr0)\"column1 text, column2 int, etc bool\""
	echo ""
	echo "	$(tput setaf 7)Drop table$(tput sgr0)"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--drop $(tput sgr0)$(tput setaf 6)--table=$(tput sgr0)table"
	echo ""
	echo "	$(tput setaf 7)Add column$(tput sgr0)"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--alter $(tput sgr0)$(tput setaf 6)--table=$(tput sgr0)table $(tput setaf 6)--addcolumn=$(tput sgr0)'name type'"
	echo ""
	echo "	$(tput setaf 7)Rename column$(tput sgr0)"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--alter $(tput sgr0)$(tput setaf 6)--table=$(tput sgr0)table $(tput setaf 6)--rename=$(tput sgr0)name $(tput setaf 6)--to=$(tput sgr0)new_name"
	echo ""
	echo "$(tput setaf 7)Databases$(tput sgr0)"
	echo "	$(tput setaf 7)Create database$(tput sgr0)"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--create$(tput sgr0) $(tput setaf 6)--database=$(tput sgr0)database"
	echo ""
	echo "	$(tput setaf 7)Select database$(tput sgr0)"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--use=$(tput sgr0)database"
	echo ""
	echo "	$(tput setaf 7)Database in tablename$(tput sgr0)"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--select=$(tput sgr0)* $(tput setaf 6)--from=$(tput sgr0)database.table"
	echo ""
	echo "	$(tput setaf 7)Rename database$(tput sgr0)"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--rename$(tput sgr0) $(tput setaf 6)--database=$(tput sgr0)database $(tput setaf 6)--to=$(tput sgr0)newdatabase"
	echo ""
	echo "$(tput setaf 7)Structure$(tput sgr0)"
	echo "	$(tput setaf 7)Show tables$(tput sgr0)"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--show --tables$(tput sgr0)"
	echo ""
	echo "	$(tput setaf 7)Show databases$(tput sgr0)"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--show --databases$(tput sgr0)"
	echo "";
else

	echo "Sorry, i do not recognize your command. Try --help"

fi