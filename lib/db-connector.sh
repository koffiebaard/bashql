#!/bin/bash

curdir="$(dirname "$0")";
db_dir="$curdir/data";
database_cached="";
db_file="";
delim="|o_o|";

source "$curdir/lib/internals.sh";





# potentially remove the database from the table name
filter_table () {
	local table="$1";

	echo "$table" | sed 's/^\([a-zA-Z0-9_]*\)\.\(.*\)/\2/g';
}

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
		echo "OK";
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
		echo "OK";
	else
		fatal "Unknown error. Database could not be dropped.";
		exit 1;
	fi
}

rename_database () {
	local db_name="$1"
	local new_db_name="$2";

	if ! db_exists "$db_name"; then
		echo "Error: Database \"$db_name\" does not exist.";
		exit 1;
	fi

	if ! valid_db_name "$new_db_name"; then
		exit 1;
	fi

	mv "$db_dir/$db_name" "$db_dir/$new_db_name"

	echo "OK";
}

db_exists () {
	local db="$1";

	if [[ -f "$db_dir/$db" ]]; then
		true;
	else
		false;
	fi
}

record_by_id () {
	id="$1";

	grep "^$id|" "$db_file"
}

id_in_db () {
	local id="$1";

	local record=$(record_by_id "$id");

	if [[ "$record" != "" ]]; then
		true;
	else
		false;
	fi
}

id_belongs_to_table () {
	local id="$1";
	local tablename="$2";

	local record=$(from_table "$tablename" | grep "^$id|");

	# record found? it's in this table!
	if [[ "$record" != "" ]]; then
		true;
	else
		false;
	fi
}


get_columns () {
	table_name="$1";
	show_only_this_field="$2";

	if ! table_exists "$table_name"; then
		echo "Error: Table \"$table_name\" does not exist.";
		exit 1;
	fi

	local columns='[]';
	local records=$(cat "$db_file" | sed -n "/### $table_name\$/,/###/p" | grep '^--');

	while read record; do

		record=$(echo "${record:2}" | sed 's/|o_o|/\t/g');

		local column_name=$(echo "$record" | awk '{print $1}');
		local data_type=$(echo "$record" | awk '{print $2}');

		if [[ "$show_only_this_field" != "" && "$show_only_this_field" == "name" ]]; then
			columns=$(append_string_to_array "$columns" "$column_name");
		elif [[ "$show_only_this_field" == "" ]]; then
			local column='{}';
			column=$(append_value_to_object "$column" "name" "$column_name");
			column=$(append_value_to_object "$column" "type" "$data_type");

			columns=$(append_object_to_array "$columns" "$column");
		else
			echo "Error: Only the column name \"name\" can be filtered.";
			exit 1;
		fi

	done<<<"$records"

	echo "$columns";
}


get () {
	local records="$1";
	local tablename="$2";
	local select_fields="$3";
	local search_string="$4";
	local limit="$5";

	# Search
	if [[ "$search_string" != "" ]]; then
		records=$(echo "$records" | grep -i  "$search_string");
	fi

	# nothing found? return empty array
	if [[ "$records" == "" ]]; then
		echo "[]";
		exit 0;
	fi

	local column_names=$(get_columns "$tablename" "name");

	local record_count=1;
	record_array='[]';

	while read record; do

		local list_of_values=$(echo "$record" | sed 's/|o_o|/\n/g');

		jq_args=( )
		jq_query='.'

		local key=0;
		while IFS=$'\n' read value; do
			local field=$(echo "$column_names" | jq -r ".[$key]");

			# just in case the column count is off, just don't show any unknown fields
			if [[ "$field" == "null" ]]; then
				continue;
			fi

			# if a select was given, only continue for those fields that are in it
			if [[ "$select_fields" == "*" || $(echo "$select_fields" | egrep "^$field\$|^$field,|,$field,|,$field\$" | wc -l) == 1 ]]; then

				jq_args+=( --arg "field$field" "$field" )
				jq_args+=( --arg "value$field" "$value" )

				jq_query+=" | .[\$field$field]=\$value$field";
			fi

			key=$((key+1));
		done<<<"$list_of_values"

		local record_object=$(jq "${jq_args[@]}" "$jq_query" <<<{});
		record_array=$(append_object_to_array "$record_array" "$record_object");

		if [[ "$limit" != "" && $record_count == $limit ]]; then
			break;
		fi

		record_count=$((record_count+1));

	done<<<"$records"

	echo "$record_array";
}


get_field_from_record () {
	record="$1";
	field_id="$2";

	echo "$record" | sed "s/^\([0-9a-z\-]*\)|o_o|\([0-9a-zA-Z _-]*\)[|o_o|]*\(.*\)[|o_o|]*\(.*\)[|o_o|]*\(.*\)/\\$field_id/g"
}


field_name_to_id () {
	field_name="$1";
	field_record=$(from_table "metadata" | grep "$field_name");

	get_field_from_record "$field_record" 1
}


add () {
	local table_name="$1"

	# build new record
	local new_id=$(uuidgen);
	local new_record=$(build_new_record "$table_name" "$new_id");

	# line number of this table
	line_number_table=$(grep -n "^### $table_name\$" "$db_file" | awk '{print $1}' | sed 's/^\([0-9]*\):.*/\1/g');

	if is_int $line_number_table; then

		commit_to_db "$new_record" "$line_number_table"

		if id_in_db "$new_id"; then
			echo "$new_id";
		else
			echo "Error: Record was not created, cause unknown.";
			exit 1;
		fi
	else
		echo "Error: table \"$table_name\" could not be found.";
		exit 1;
	fi
}


build_new_record () {
	local tablename="$1";
	local id="$2";
	local fetch_from_old_record="$3";

	args=$(echo "$argument_list" | egrep -v 'update|insert|into');
	local columns=$(get_columns "$tablename");

	local new_record="$id";

	# iterate through columns so we add the proper data
	for column in $(echo "${columns}" | jq -r '.[] | @base64'); do
		local column=$(echo "${column}" | base64 --decode);

		local column_name=$(🐐 "$column" "name");
		local column_type=$(🐐 "$column" "type");

		# skip ID, since we already added it (and create doesn't have it as an argument)
		if [[ "$column_name" == "id" ]]; then
			continue;
		fi

		# lets determine the value this column will get
		local value="";

		# is the value for this field supplied as an argument?
		if [[ $(echo "$args" | egrep "^$column_name\$" | wc -l) == 1 ]]; then
			value="$(get_argument "$column_name")";

		# or shall we fetch the value from the previous record in the db?
		elif [[ "$fetch_from_old_record" == 1 ]]; then
			value=$(get "$(record_by_id $id)" "$tablename" "$column_name" "" "" | jq -r ".[].$column_name");

			# jq has null implemented, but shell of course doesn't.
			if [[ "$value" == "null" ]]; then
				value="";
			fi
		fi

		# for better or worse, we have a value
		value=$(sanitize_column_value "$column_name" "$column_type" "$value");

		# ok, at least now it's not worse
		new_record=$(append "$new_record" "$value" "$delim");
	done

	# yay a new record!
	echo "$new_record";
}

id_to_line_number () {
	id="$1";

	local line_number=$(egrep -n "^$id" "$db_file" | awk '{print $1}' | sed 's/^\([0-9]*\):.*/\1/g');

	if is_int "$line_number"; then
		echo "$line_number";
	fi
}

delete () {
	local id="$1";

	# get line number by matching the ID
	local line_number=$(egrep -n "^$id" "$db_file" | awk '{print $1}' | sed 's/^\([0-9]*\):.*/\1/g');

	if is_int "$line_number"; then

		# delete by line number
		delete_line_by_number "$line_number"
	else
		echo "Error deleting record: ID could not be found in database.";
		exit 1;
	fi
}

update () {
	local id="$1";
	local tablename="$2";

	local updated_record=$(build_new_record "$tablename" "$id" 1);

	local line_number=$(id_to_line_number "$id");

	if is_int "$line_number"; then

		local escaped_updated_record=$(echo "$updated_record" | sed -e 's/[\/&]/\\&/g');

		# replace line by line number
		sed -i "${line_number}s/.*/$escaped_updated_record/" "$db_file";
	else
		echo "Error updating record: ID could not be found in database.";
		exit 1;
	fi
}






# read all records from a table
from_table () {
	table_name="$1";

	cat "$db_file" | sed -n "/### $table_name\$/,/###/p" | grep -v '^###' | grep -v '^--'
}

list_tables () {

	if [[ -f "$db_file" ]]; then
		grep '^###' "$db_file" | sed 's/^### //g' | grep -v metadata;
	fi
}

table_exists () {
	tablename="$1";

	if [[ $(echo "$(list_tables)" | grep "^$tablename\$" | wc -l) -ge 1 ]]; then
		true;
	else
		false;
	fi
}

create_table () {
	tablename="$1";
	columns="$2";

	if table_exists "$tablename"; then
		echo "Error: Table \"$tablename\" already exists.";
		exit 1
	fi

	if ! valid_table_name "$tablename"; then
		exit 1;
	fi

	# add tablename to database
	commit_to_db "### $tablename" "end";

	# add ID as first column
	commit_to_db "--id${delim}text" "end";

	# add columns, if present
	if [[ "$columns" != "" ]]; then

		columns=$(echo "$columns" | tr ',' '\n')

		while IFS=',' read column; do
			local name=$(echo "$column" | awk '{print $1}');
			local type=$(echo "$column" | awk '{print $2}');

			if [[ "$name" == "id" ]]; then
				>&2 echo "Warning: ID column is added automatically. Skipping..";
				continue;
			fi

			if ! valid_column_name "$name"; then
				>&2 echo "Warning: column name \"$name\" is not valid. It must contain at least 3 characters and can only contain a-z A-Z 0-9 _. Skipping..";
				continue;
			fi

			if ! valid_column_type "$type"; then
				>&2 echo "Warning: invalid data type on column \"$name\". Can only be \"text\", \"int\" or \"bool\". Skipping..";
				continue;
			fi

			# commit column record to database
			commit_to_db "--$name$delim$type" "end";

		done<<<"$columns"
	fi

	echo "OK";
}


drop_table () {
	local tablename="$1";

	if ! table_exists "$tablename"; then
		echo "Error: Table \"$tablename\" doesn't exist.";
		exit 1
	fi

	# fetch line numbers of all records we'll remove
	line_number_start=$(cat -n "$db_file" | \
		sed -n "/^[[:space:]]*[0-9]*[[:space:]]*### $tablename/,/###/p" | \
		egrep -v "^[[:space:]]*[0-9]*[[:space:]]*###" | \
		awk '{print $1}' | \
		head -n1);

	line_number_end=$(cat -n "$db_file" | \
		sed -n "/^[[:space:]]*[0-9]*[[:space:]]*### $tablename/,/###/p" | \
		egrep -v "^[[:space:]]*[0-9]*[[:space:]]*###" | \
		awk '{print $1}' | \
		tail -n1);

	if is_int "$line_number_start" && is_int "$line_number_end"; then

		# remove records by line number range
		delete_lines_by_number_range "$line_number_start" "$line_number_end"
	fi

	# now for the table
	local line_number_table=$(egrep -n "^### $tablename" "$db_file" | awk '{print $1}' | sed 's/^\([0-9]*\):.*/\1/g');

	if is_int "$line_number_table"; then

		delete_line_by_number "$line_number_table"
	else
		echo "Error removing table";
		exit 1;
	fi
}


add_column () {
	local tablename="$1";
	local name="$2";
	local type="$3";
	local compiled_column="--$name$delim$type";

	if ! table_exists "$tablename"; then
		echo "Error: table \"$tablename\" doesn't exist.";
		exit 1;
	elif column_exists "$tablename" "$name"; then
		echo "Error: column \"$name\" already exists.";
		exit 1;
	elif ! valid_column_name "$name"; then
		echo "Column name \"$name\" is not valid. It must contain at least 3 characters and can only contain a-z A-Z 0-9 _.";
		exit 1;
	elif ! valid_column_type "$type"; then
		echo "Error: column type \"$type\" is not valid. Can only be \"text\", \"int\" or \"bool\".";
		exit 1;
	fi

	# get line count for last column
	local last_column_linecount=$(cat -n "$db_file" | \
		sed -n "/^[[:space:]]*[0-9]*[[:space:]]*### $tablename/,/###/p" | \
		grep '^[[:space:]]*[0-9]*[[:space:]]*--' | \
		tail -n1 | \
		awk '{print $1}');

	commit_to_db "$compiled_column" "$last_column_linecount";

	echo "OK";
}


column_exists () {
	local tablename="$1";
	local column="$2";

	local columns_in_db=$(get_columns "$tablename" "name" | jq -r '.[]');

	if [[ $(echo "$columns_in_db" | grep "^$column\$" | wc -l) -ge 1 ]]; then
		true;
	else
		false;
	fi
}

valid_column_type () {
	local type="$1";

	if [[ "$type" == "text" || "$type" == "int" || "$type" == "bool" ]]; then
		true;
	else
		false;
	fi
}

rename_table () {
	local tablename="$1"
	local new_tablename="$2";

	if ! table_exists "$tablename"; then
		echo "Error: Table \"$tablename\" does not exist.";
		exit 1;
	fi

	if ! valid_table_name "$new_tablename"; then
		exit 1;
	fi

	sed -i "s/^### $tablename$/### $new_tablename/g" "$db_file";

	echo "OK";
}

commit_to_db () {
	local record="$1";
	local at_linecount="$2";
	local last_linecount=$(get_last_linecount "$db_file");


	# is it the last line in the file? add on a new line.
	if [[ "$at_linecount" == "$last_linecount" || "$at_linecount" == "end" ]]; then
		☕ "adding at the end..";

		# does the file exist, and is it not empty?
		# then we'll add a newline, otherwise not necessary
		if [[ -s "$db_file" ]]; then
			printf "\n" >> "$db_file";
		fi

		printf '%s' "$record" >> "$db_file";

	# if not, just add it on the line below
	else
		☕ "adding after line $at_linecount..";
		# calculate new line number to add the column at
		at_linecount=$((at_linecount+1));

		sed -i "${at_linecount}i$record" "$db_file"
	fi
}


delete_line_by_number () {
	local line_number="$1";
	local last_linecount=$(get_last_linecount "$db_file");

	sed -i "${line_number}d" "$db_file"

	# were we removing up until the end of the file? remove the last newline.
	if [[ "$line_number" == "$last_linecount" ]]; then
		truncate -s -1 "$db_file";
	fi
}


delete_lines_by_number_range () {
	local line_number_start="$1";
	local line_number_end="$2";
	local last_linecount=$(get_last_linecount "$db_file");

	sed -i "${line_number_start},${line_number_end}d" "$db_file"

	# were we removing up until the end of the file? remove the last newline.
	if [[ "$line_number_end" == "$last_linecount" ]]; then
		truncate -s -1 "$db_file";
	fi
}

get_last_linecount () {
	local file="$1";

	last_linecount=$(cat "$file" | wc -l);
	((last_linecount++));

	echo "$last_linecount";
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

valid_table_name () {
	local table_name="$1";

	if [[ $(string_length "$table_name") -le 2 ]]; then
		fatal "Table name must be at least 3 characters"
		false;
	fi

	if ! [[ "$table_name" =~ ^[a-zA-Z0-9_]+$ ]]; then
		fatal "Table name can only contain a-z A-Z 0-9 _";
		false;
	fi

	true;
}

valid_column_name () {
	local column_name="$1";

	if [[ $(string_length "$column_name") -le 2 ]]; then
		#>&2 echo "Column name must be at least 3 characters"
		false;
	elif ! [[ "$column_name" =~ ^[a-zA-Z0-9_]+$ ]]; then
		#>&2 echo "Column name can only contain a-z A-Z 0-9 _";
		false;
	else
		true;
	fi
}

# our columns support 'int', 'text' and 'bool'
# so lets sanitize the column values against those types
sanitize_column_value () {
	local column="$1";
	local type="$2";
	local value="$3";

	if [[ "$type" == "int" ]]; then

		# simply cast to int
		echo $(int "$value");

		# but warn those cunts if they're being cunty
		if ! is_int "$value"; then
			>&2 echo "Warning: Column \"$column\" needs to be an integer, not whatever the shit \"$value\" is.";
		fi

	elif [[ "$type" == "bool" ]]; then

		# good bool.
		if [[ "$value" == "0" || "$value" == "1" ]]; then
			echo "$value";
		# bool shit. fucking cunts can't do anything right.
		else
			>&2 echo "Warning: Column \"$column\" needs to be a bool, 0 or 1. Please don't send \"$value\" again.";
		fi

	elif [[ "$type" == "text" ]]; then

		# text accepts all. Let's do fuck-all.
		echo "$value";
	fi
}

