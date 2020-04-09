#!/bin/bash

curdir="$(dirname "$0")";

source "$curdir/lib/internals.sh";

delim="|o_o|";


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
		records=$(echo "$records" | grep "$search_string");
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
			if [[ "$select_fields" == "*" || $(echo "$select_fields" | egrep "^$field\$|^$field,|,$field\$" | wc -l) == 1 ]]; then

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
		echo "Error: database \"$table_name\" could not be found.";
		exit 1;
	fi
}


build_new_record () {
	local tablename="$1";
	local id="$2";
	local fetch_from_old_record="$3";

	args=$(echo "$argument_list" | egrep -v 'update|insert|into');
	local fields=$(get_columns "$tablename" "name" | jq -r '.[]');

	local new_record="$id";

	# iterate through metadata fields so we add data in the right order
	while read field; do

		# skip ID, since we already added it (and create doesn't have it as an argument)
		if [[ "$field" == "id" ]]; then
			continue;
		fi

		# is the value for this field supplied as an argument?
		if [[ $(echo "$args" | egrep "^$field\$" | wc -l) == 1 ]]; then
			local value="$(get_argument "$field")";
			new_record=$(append "$new_record" "$value" "$delim");

		# otherwise we add a default value
		else

			# shall we fetch the value from the previous record in the db?
			if [[ "$fetch_from_old_record" == 1 ]]; then
				local value=$(get "$(record_by_id $id)" "$tablename" "$field" "" "" | jq -r ".[].$field");

				# jq has null implemented, but shell of course doesn't.
				if [[ "$value" == "null" ]]; then
					value="";
				fi

				new_record=$(append "$new_record" "$value" "$delim");

			# or just add an empty spot for this field
			else
				new_record=$(append "$new_record" "" "$delim");
			fi
		fi
	done<<<"$fields"

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

	# add tablename to database
	commit_to_db "### $tablename" "end";

	# add ID as first column
	commit_to_db "--id${delim}text" "end";

	# add columns
	columns=$(echo "$columns" | tr ',' '\n')

	while IFS=',' read column; do
		local name=$(echo "$column" | awk '{print $1}');
		local type=$(echo "$column" | awk '{print $2}');

		if [[ "$name" == "id" ]]; then
			>&2 echo "Warning: ID column is added automatically. Skipping..";
			continue;
		fi

		if ! valid_column_type "$type"; then
			>&2 echo "Warning: column \"$name\" has invalid data type \"$type\". Skipping..";
			continue;
		fi

		# commit column record to database
		commit_to_db "--$name$delim$type" "end";

	done<<<"$columns"

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
	elif ! valid_column_type "$type"; then
		echo "Error: column type \"$type\" is not valid.";
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

	if [[ "$type" == "text" || "$type" == "int" ]]; then
		true;
	else
		false;
	fi
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
