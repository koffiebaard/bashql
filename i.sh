#!/bin/bash

curdir="$(dirname "$0")";

db_file="$curdir/data";

source "$curdir/lib/db-connector.sh";
source "$curdir/tasks.sh";


if [[ $(get_argument "tables") == 1 ]]; then
	list_tables

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

elif [[ $(get_argument "drop") != "" && $(get_argument "table") != "" ]]; then
	task_drop_table

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
	echo "	$(tput setaf 7)Create$(tput sgr0)"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--create $(tput sgr0)$(tput setaf 6)--table=$(tput sgr0)table"
	echo ""
	echo "	$(tput setaf 7)Drop$(tput sgr0)"
	echo "		$(tput setaf 6)i.sh$(tput sgr0) $(tput setaf 6)--drop $(tput sgr0)$(tput setaf 6)--table=$(tput sgr0)table"
else

	echo "Sorry, i do not recognize your command."

fi