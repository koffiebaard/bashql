#!/bin/bash

select_database () {
	local db="$1";

	database_cached="$db";
	db_file="$db_dir/$db";
}

database () {

	if [[ "$database_cached" != "" ]]; then
		echo "$database_cached";
	fi
}

set_database () {

	# db already determined? stop
	if [[ "$database_cached" != "" ]]; then
		return;
	fi

	tables=("describe" "from" "into" "table");

	for table in ${tables[@]}; do

		if [[ "$(get_argument "$table")" == *"."* ]]; then
	 		possible_database=$(echo "$(get_argument "$table")" | sed 's/^\([a-zA-Z0-9_]*\)\..*/\1/g');

	 		if db_exists "$possible_database"; then
	 			select_database "$possible_database";
	 			return
	 		elif [[ "$possible_database" != "" ]]; then
	 			fatal "Database \"$possible_database\" doesn't exist."
	 			return;
	 		fi
	 	fi
 	done

	local db=$(session_get);

	if db_exists "$db"; then
		select_database "$db";
	else
		session_reset;
	fi
}

create_database () {
	local db="$1";

	if db_exists "$db"; then
		fatal "Database already exists.";
		exit 1;
	fi

	if ! valid_db_name "$db"; then
		exit 1;
	fi

	touch "$db_dir/$db";

	if db_exists "$db"; then
		output "OK";
	else
		fatal "Unknown error. Database could not be created.";
		exit 1;
	fi
}

drop_database () {
	local db="$1";

	if ! db_exists "$db"; then
		fatal "Database doesn't exist. Can't be dropped.";
		exit 1;
	fi

	rm "$db_dir/$db";

	if ! db_exists "$db"; then
		output "OK";
	else
		fatal "Unknown error. Database could not be dropped.";
		exit 1;
	fi
}

rename_database () {
	local db_name="$1"
	local new_db_name="$2";

	if ! db_exists "$db_name"; then
		fatal "Database \"$db_name\" does not exist.";
		exit 1;
	fi

	if ! valid_db_name "$new_db_name"; then
		exit 1;
	fi

	mv "$db_dir/$db_name" "$db_dir/$new_db_name"

	output "OK";
}

db_exists () {
	local db="$1";

	if [[ -f "$db_dir/$db" ]]; then
		true;
	else
		false;
	fi
}

valid_db_name () {
	local db_name="$1";

	if [[ $(string_length "$db_name") -le 2 ]]; then
		fatal "Database name must be at least 3 characters"
		false;
	fi

	if ! [[ "$db_name" =~ ^[a-zA-Z0-9_]+$ ]]; then
		fatal "Database name can only contain a-z A-Z 0-9 _";
		false;
	fi

	true;
}


