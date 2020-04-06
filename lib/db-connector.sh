#!/bin/bash

curdir="$(dirname "$0")";

source "$curdir/lib/internals.sh";


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

#get () {
#	local records="$1";
#	local field_names="$2";
#	local search_string="$3";
#
#	if [[ "$search_string" != "" ]]; then
#		records=$(echo "$records" | grep "$search_string");
#	fi
#
#	field_ids=$(field_names_to_ids "$field_names")
#
#	local retrieved_fields=$(get_field_from_record "$records" $field_ids);
#
#	echo "$retrieved_fields" | sed '/^$/d';
#}

field_names_to_ids () {
	local field_names="$1";

	local field_ids=""

	for field_name in $(echo "$field_names" | tr ' ' '\n'); do

		local field_id=$(field_name_to_id "$field_name");

		field_ids=$(append "$field_ids" "$field_id" ",\\")
	done

	echo "$field_ids";
}

read_metadata () {

	local records=$(from_table "metadata");

	titles=$(echo "$records" | sed "s/^\([0-9a-z\-]*\)|o_o|\([0-9a-zA-Z _-]*\)|o_o|\(.*\)/\\2/g");

	local fields='[]';

	while read title; do

		fields=$(append_string_to_array "$fields" "$title");

	done<<<"$titles"

	echo "$fields";
}


get () {
	local records="$1";
	local select_fields="$2";
	local search_string="$3";
	local limit="$4";

	# Search
	if [[ "$search_string" != "" ]]; then
		records=$(echo "$records" | grep "$search_string");
	fi

	local metadata=$(read_metadata);

	local record_count=1;
	record_array='[]';

	while read record; do

		local list_of_values=$(echo "$record" | sed 's/|o_o|/\n/g');

		jq_args=( )
		jq_query='.'

		local key=0;
		while IFS=$'\n' read value; do
			local field=$(echo "$metadata" | jq -r ".[$key]");

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

	#echo "$record" | sed "s/^\([0-9a-z\-]*\)|o_o|\([0-9a-zA-Z _-]*\)|o_o|\(.*\)/\\$field_id/g"
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
	local new_record=$(build_new_record "$new_id");

	# line number of this table
	line_number_table=$(grep -n "^### $table_name" "$db_file" | awk '{print $1}' | sed 's/^\([0-9]*\):.*/\1/g');

	if is_int $line_number_table; then

		# calculate last line count
		local last_linecount=$(cat "$db_file" | wc -l);
		((last_linecount++));

		# is the table on the last line in the file? add the record on a new line.
		if [[ "$line_number_table" == "$last_linecount" ]]; then
			printf "\n$new_record" >> "$db_file";

		# if not, just add it on the line below
		else
			# calculate new line number to add record at
			line_number_new_record=$((line_number_table+1))

			sed -i "${line_number_new_record}i$new_record" "$db_file"
		fi

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
	local id="$1";
	local fetch_from_old_record="$2";
	local delim="|o_o|"

	args=$(echo "$argument_list" | egrep -v 'update|insert|into');
	local fields=$(read_metadata | jq -r '.[]');

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
				local value=$(get "$(record_by_id $id)" "$field" "" "" | jq -r ".[].$field");

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

	local updated_record=$(build_new_record "$id" 1);

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

	cat "$db_file" | sed -n "/### $table_name/,/###/p" | grep -v '^###'
}

list_tables () {
	grep '^###' "$db_file" | sed 's/^### //g' | grep -v metadata;
}

table_exists () {
	tablename="$1";

	if [[ $(echo $(list_tables) | grep "$tablename" | wc -l) == 1 ]]; then
		true;
	else
		false;
	fi
}

create_table () {
	tablename="$1";
	#fields="$2";

	if table_exists "$tablename"; then
		echo "Error: Table \"$tablename\" already exists.";
		exit 1
	fi

	printf "\n### $tablename" >> $db_file;

	#if [[ "$fields" != "" ]]; then

	#	while IFS=',' read field; do
	#		echo "$field";
	#	done<<<"$fields"
	#fi
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








