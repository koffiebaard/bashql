#!/bin/bash


# resolve location of actual file, tracing a symlink if necessary
source="${BASH_SOURCE[0]}";
if [[ -L "$source" ]]; then
	source="$(readlink "$source")"
fi

curdir="$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )"

# ID of this bashql instance
instance_id=$(uuidgen);

source "$curdir/lib/db-handler.sh";
source "$curdir/lib/tasks.sh";

sanitized_arguments=$(echo "$@" | sed 's/\(--[a-zA-Z_]*\)/\n\1\n/g' | grep "^--" | paste -sd " ");


# database fetches from the db from anywhere, including the table name
# run it in the current shell so it can set the global variables
set_database

if [[ $(database) == "" ]]; then

	# these routes (copied from below) don't need a database connection
	if  [[ $(get_argument "use") != "" ]] || \
	    [[ $(get_argument "help") == 1 ]] || \
	    [[ $(get_argument "test") == 1 ]] || \
	    [[ $(get_argument "select") == 1 || $(get_argument "database") == 1 && $(get_argument "from") == "" ]] || \
	    [[ $(get_argument "rawr") == 1 || $(get_argument "dino") == 1 ]] || \
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


#lock "test";

#echo "lock succeeded! yay!";

#unlock "test"



if [[ $(get_argument "use") != "" ]]; then
	task_persist_database

elif [[ $(get_argument "select") == 1 && $(get_argument "database") == 1 && $(get_argument "from") == "" ]]; then
	task_current_database

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

#@tag_rawr_dino
elif [[ $(get_argument 'dino') == 1 || $(get_argument 'rawr') == 1 ]]; then
	task_dino

#@tag_test
elif [[ $(get_argument 'test') == 1 ]]; then

	$curdir/tests.sh

elif [[ $(get_argument 'help') == 1 ]]; then

	$curdir/help.sh
else

	echo "Sorry, i do not recognize your command. Try --help"
fi