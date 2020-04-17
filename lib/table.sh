#!/bin/bash

# potentially remove the database from the table name
filter_table () {
	local table_name="$1";

	echo "$table_name" | sed 's/^\([a-zA-Z0-9_]*\)\.\(.*\)/\2/g';
}

get_columns () {
	table_name="$1";
	show_only_this_field="$2";

	if ! table_exists "$table_name"; then
		fatal "Table \"$table_name\" does not exist.";
		exit 1;
	fi

	local columns='[]';
	local records=$(cat "$(tablefile "$table_name")" | sed -n "/### $table_name\$/,/###/p" | grep '^--');

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
			fatal "Only the column name \"name\" can be filtered.";
			exit 1;
		fi

	done<<<"$records"

	echo "$columns";
}

list_tables () {

	if stored_as_file; then
		grep '^###' "$(tablefile "$table_name")" | sed 's/^### //g';
	else
		if [ ! -z "$(ls -A $(databasefile))" ]; then
			find "$(databasefile)"/*  -printf "%f\n";
		fi
	fi
}

table_exists () {
	local table_name="$1";

	if [[ $(echo "$(list_tables)" | grep "^$table_name\$" | wc -l) -ge 1 ]]; then
		true;
	else
		false;
	fi
}

create_table () {
	local table_name="$1";
	local columns="$2";

	if table_exists "$table_name"; then
		fatal "Table \"$table_name\" already exists.";
		exit 1
	fi

	if ! valid_table_name "$table_name"; then
		exit 1;
	fi

	# if the database is a directory, then the tables are separate files
	# the table file needs to be created first
	if stored_as_dir; then
		touch $(tablefile "$table_name");
	fi

	# add table row to database
	commit_to_db "$table_name" "### $table_name" "end";

	# add ID as first column
	commit_to_db "$table_name" "--id${delim}text" "end";

	# add columns, if present
	if [[ "$columns" != "" ]]; then

		columns=$(echo "$columns" | tr ',' '\n')

		while IFS=',' read column; do
			local name=$(echo "$column" | awk '{print $1}');
			local type=$(echo "$column" | awk '{print $2}');

			if [[ "$name" == "id" ]]; then
				warning "ID column is added automatically. Skipping..";
				continue;
			fi

			if ! valid_column_name "$name"; then
				warning "Column name \"$name\" is not valid. It must contain at least 3 characters and can only contain a-z A-Z 0-9 _. Skipping..";
				continue;
			fi

			if ! valid_column_type "$type"; then
				warning "Invalid data type on column \"$name\". Can only be \"text\", \"int\" or \"bool\". Skipping..";
				continue;
			fi

			# commit column record to database
			commit_to_db "$table_name" "--$name$delim$type" "end";

		done<<<"$columns"
	fi

	output "OK";
}


drop_table () {
	local table_name="$1";

	if ! table_exists "$table_name"; then
		fatal "Table \"$table_name\" doesn't exist.";
		exit 1
	fi

	if stored_as_file; then
		_drop_table_file "$table_name";
	else
		_drop_table_dir "$table_name";
	fi

	output "OK";
}

# Delete the table if the database is stored in a directory
_drop_table_dir () {
	local table_name="$1";

	# lock table so nobody else can write while we are
	lock "$table_name";

	# remove the table file inside the database dir
	rm $(tablefile "$table_name");

	# unlock the table again
	unlock "$table_name";
}

# Delete the table if the database is stored in one file
_drop_table_file () {
	local table_name="$1";

	# lock table so nobody else can write while we are
	lock "$table_name";

	# fetch line numbers of all records we'll remove
	line_number_start=$(cat -n "$(tablefile "$table_name")" | \
		sed -n "/^[[:space:]]*[0-9]*[[:space:]]*### $table_name/,/###/p" | \
		egrep -v "^[[:space:]]*[0-9]*[[:space:]]*###" | \
		awk '{print $1}' | \
		head -n1);

	line_number_end=$(cat -n "$(tablefile "$table_name")" | \
		sed -n "/^[[:space:]]*[0-9]*[[:space:]]*### $table_name/,/###/p" | \
		egrep -v "^[[:space:]]*[0-9]*[[:space:]]*###" | \
		awk '{print $1}' | \
		tail -n1);

	if ! is_int "$line_number_start" || ! is_int "$line_number_end"; then

		unlock "$table_name";
		fatal "Could not remove table, line numbers could not be determined. Cause unknown.";
		exit 1;
	fi

	# remove records and columns by line number range
	delete_lines_by_number_range "$table_name" "$line_number_start" "$line_number_end"

	# now for the table
	local line_number_table=$(egrep -n "^### $table_name" "$(tablefile "$table_name")" | awk '{print $1}' | sed 's/^\([0-9]*\):.*/\1/g');

	# if we can't determine the table location, we'll drop dead and cry out in attention seeking agony
	if ! is_int "$line_number_table"; then

		# unlock the table first, which is empty and still there. Nothing we can do.
		unlock "$table_name";

		fatal "Could not remove table, line number table could not be determined. Cause unknown.";
		exit 1;
	fi

	# Delete table line
	delete_line_by_number "$table_name" "$line_number_table"

	# Unlock table again
	unlock "$table_name"
}


add_column () {
	local table_name="$1";
	local name="$2";
	local type="$3";
	local compiled_column="--$name$delim$type";

	if ! table_exists "$table_name"; then
		fatal "Table \"$table_name\" doesn't exist.";
		exit 1;
	elif column_exists "$table_name" "$name"; then
		fatal "Column \"$name\" already exists.";
		exit 1;
	elif ! valid_column_name "$name"; then
		fatal "Column name \"$name\" is not valid. It must contain at least 3 characters and can only contain a-z A-Z 0-9 _.";
		exit 1;
	elif ! valid_column_type "$type"; then
		fatal "column type \"$type\" is not valid. Can only be \"text\", \"int\" or \"bool\".";
		exit 1;
	fi

	# get line count for last column
	local last_column_linecount=$(cat -n "$(tablefile "$table_name")" | \
		sed -n "/^[[:space:]]*[0-9]*[[:space:]]*### $table_name/,/###/p" | \
		grep '^[[:space:]]*[0-9]*[[:space:]]*--' | \
		tail -n1 | \
		awk '{print $1}');

	commit_to_db "$table_name" "$compiled_column" "$last_column_linecount";

	output "OK";
}

rename_column () {
	local table_name="$1";
	local name="$2";
	local new_name="$3";
	local new_type="$4";

	if ! table_exists "$table_name"; then
		fatal "Table \"$table_name\" doesn't exist.";
		exit 1;
	elif ! column_exists "$table_name" "$name"; then
		fatal "Column \"$name\" doesn't exist.";
		exit 1;
	elif column_exists "$table_name" "$new_name"; then
		fatal "Column \"$new_name\" already exists. Please choose another name.";
		exit 1;
	elif ! valid_column_name "$new_name"; then
		fatal "Column name \"$new_name\" is not valid. It must contain at least 3 characters and can only contain a-z A-Z 0-9 _.";
		exit 1;
	elif [[ $new_type != "" ]] && ! valid_column_type "$new_type"; then
		fatal "column type \"$new_type\" is not valid. Can only be \"text\", \"int\" or \"bool\".";
		exit 1;
	fi

	# get line count for last column
	local found_column_record=$(cat -n "$(tablefile "$table_name")" | \
		sed -n "/^[[:space:]]*[0-9]*[[:space:]]*### $table_name/,/###/p" | \
		grep "^[[:space:]]*[0-9]*[[:space:]]*--$name|");

	# did we find the column?
	if [[ "$found_column_record" != "" && $(echo "$found_column_record" | wc -l) == 1 ]]; then

		local column=$(echo "$found_column_record" | awk '{print $2}');
		local column_line_number=$(echo "$found_column_record" | awk '{print $1}');

		sed -i "${column_line_number}s/--[a-zA-Z0-9_]*|/--$new_name|/" "$(tablefile "$table_name")";

		if column_exists "$table_name" "$new_name"; then
			output "OK";
		else
			fatal "Column could not be renamed. Unknown error. #101";
		fi
	else
		fatal "Column could not be renamed. Unknown error. #100";
		exit 1;
	fi
}

drop_column () {
	local table_name="$1";
	local column_name="$2";

	if ! table_exists "$table_name"; then
		fatal "Table \"$table_name\" doesn't exist.";
		exit 1;
	elif ! column_exists "$table_name" "$column_name"; then
		fatal "Column \"$column_name\" doesn't exist.";
		exit 1;
	fi

	# get all columns, numbered
	local columns=$(cat "$(tablefile "$table_name")" | \
		sed -n "/^### $table_name/,/^###/p" | \
		grep "^--" | grep -n "");

	# get the records and the number for our column (nth column)
	local column_number=$(echo "$columns" | grep "\-\-$column_name|" | awk "BEGIN{FS=\":\"} {print \$1}");
	local records=$(cat "$(tablefile "$table_name")" | sed -n "/### $table_name\$/,/###/p" | grep -v '^--' | grep -v "^###");

	# replace value of the to-be-dropped column to a fixed value
	local column_droppings=$(echo "$records" | awk "BEGIN{FS=\"\\\\|o_o\\\\|\"; OFS=\"|o_o|\"} {\$$column_number=\"COLUMN_DROPPINGS\"; print \$0}");

	# remove that fixed value including the column (in between columns, or at the end)
	column_droppings=$(echo "$column_droppings" | sed 's/|o_o|COLUMN_DROPPINGS|o_o|/|o_o|/g');
	column_droppings=$(echo "$column_droppings" | sed 's/|o_o|COLUMN_DROPPINGS$/|o_o|/g');

	# translate actual newlines to \n and remove last \n
	column_droppings=$(echo "$column_droppings" | awk -v ORS='\\n' '1');
	column_droppings="${column_droppings::${#column_droppings}-2}";

	# fetch line numbers of all records in the table
	records_line_number_start=$(cat -n "$(tablefile "$table_name")" | \
		sed -n "/^[[:space:]]*[0-9]*[[:space:]]*### $table_name/,/###/p" | \
		egrep -v "^[[:space:]]*[0-9]*[[:space:]]*###" | \
		egrep -v "^[[:space:]]*[0-9]*[[:space:]]*--" | \
		awk '{print $1}' | \
		head -n1);

	records_line_number_end=$(cat -n "$(tablefile "$table_name")" | \
		sed -n "/^[[:space:]]*[0-9]*[[:space:]]*### $table_name/,/###/p" | \
		egrep -v "^[[:space:]]*[0-9]*[[:space:]]*###" | \
		egrep -v "^[[:space:]]*[0-9]*[[:space:]]*--" | \
		awk '{print $1}' | \
		tail -n1);

	table_line_number=$(grep -n "^### $table_name\$" "$(tablefile "$table_name")" | awk '{print $1}' | sed 's/^\([0-9]*\):.*/\1/g');

	column_line_number=$(cat -n "$(tablefile "$table_name")" | sed -n "/^[[:space:]]*[0-9]*[[:space:]]*### $table_name/,/###/p" | grep -n "^[[:space:]]*[0-9]*[[:space:]]*--$column_name|" | awk '{print $1}' | sed 's/^\([0-9]*\):.*/\1/g');

	#@tag_droppings
	if is_int "$records_line_number_start" && is_int "$records_line_number_end" && is_int "$table_line_number" && is_int "$column_line_number"; then

		# delete the column
		delete_line_by_number "$table_name" "$column_line_number"

		# remove old records
		delete_lines_by_number_range "$table_name" "$records_line_number_start" "$records_line_number_end"

		# commit new records to db
		commit_to_db "$table_name" "$column_droppings" "$table_line_number"

		if ! column_exists "$table_name" "$column_name"; then
			output "OK";
		else
			fatal "Column could not be dropped. Unknown error. #201";
		fi
	else
		log_error "Column drop error #200: records_line_number_start: $records_line_number_start, records_line_number_end: $records_line_number_end, table_line_number: $table_line_number, column_line_number: $column_line_number. One of these is not a proper int.";
		fatal "Column could not be dropped. Unknown error. #200";
		exit 1;
	fi
}

column_exists () {
	local table_name="$1";
	local column="$2";

	local columns_in_db=$(get_columns "$table_name" "name" | jq -r '.[]');

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
	local table_name="$1"
	local new_table_name="$2";

	if ! table_exists "$table_name"; then
		fatal "Table \"$table_name\" does not exist.";
		exit 1;
	fi

	if ! valid_table_name "$new_table_name"; then
		exit 1;
	fi

	#@tag_renametable
	sed -i "s/^### $table_name$/### $new_table_name/g" "$(tablefile "$table_name")";

	# if the database is stored as a directory, we have to rename the table file too
	if stored_as_dir; then
		mv "$(tablefile "$table_name")" "$(tablefile "$new_table_name")"
	fi

	output "OK";
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

# Compute the file location of a given table. It can be one of two:
#
# 1) The database is a directory, and the table is a file inside
# 2) The database is a file, and the table is there alongside all other tables
#
tablefile () {
	local table_name="$1";
	local database_location="$(databasefile)";

	if stored_as_file; then
		echo "$database_location";
	else
		echo "$db_dir/$(database)/$table_name";
	fi
}