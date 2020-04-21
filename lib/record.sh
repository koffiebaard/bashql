#!/bin/bash

record_by_id () {
	local id="$1";

	grep "^$id|" $(tablefile "$table_name");
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
	local table_name="$2";

	local record=$(from_table "$table_name" | grep "^$id|");

	# record found? it's in this table!
	if [[ "$record" != "" ]]; then
		true;
	else
		false;
	fi
}

get () {
	local records="$1";
	local table_name="$2";
	local select_fields="$3";
	local search_string="$4";
	local limit="$5";

	# Search
	if [[ "$search_string" != "" ]]; then
		records=$(echo "$records" | grep -i  "$search_string");
	fi

	# nothing found? return empty array
	if [[ "$records" == "" ]]; then
		output "[]";
		exit 0;
	fi

	local column_names=$(get_columns "$table_name" "name");

	local record_count=1;
	record_array='[]';

	while IFS= read -r record; do

		local list_of_values=$(echo "$record" | sed 's/|o_o|/\n/g');

		jq_args=( )
		jq_query='.'

		local key=0;
		while IFS= read -r value; do
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

				# add arguments and their values properly to jq
		        #
		        # some IDs are integers but start with zero, so we can't let jq have them as ints
		        if [[ $value =~ ^[0-9\.]+$ && $value =~ ^0 ]] && ! [[ $value =~ ^0$ ]]; then
		        	jq_query+=" | .[\$field$field]=\"$value\"";

		        # ints, booleans, objects and arrays should be added directly to reflect their data type
		        elif 	[[ \
		        		# encapsulated in [ or { hints at json objects / arrays, so bypass jq args and insert directly
		        		$value =~ ^\[.*\]$ || $value =~ ^\{.*\}$ \

		        		# numbers need to be inserted directly as well, lest they be escaped and quoted (so they'd become strings)
		        		|| $value =~ ^[0-9\.]+$ \

		        		# booleans, same
		        		|| $value == "true" || $value == "false" \
		        	]]; then
		        	jq_query+=" | .[\$field$field]=$value";

		        # all else is encoded properly through jq args
		        else
		        	jq_query+=" | .[\$field$field]=\$value$field";
		        fi
			fi

			key=$((key+1));
		done <<< "$list_of_values"

		local record_object=$(jq "${jq_args[@]}" "$jq_query" <<<{});

		# Don't add empty objects (in case only faulty column names were provided)
		if [[ "$record_object" != "{}" ]]; then
			record_array=$(append_object_to_array "$record_array" "$record_object");
		fi

		if [[ "$limit" != "" && $record_count == $limit ]]; then
			break;
		fi

		record_count=$((record_count+1));

	done <<< "$records"

	output "$record_array";
}


add () {
	local table_name="$1"

	# build new record
	local new_id=$(uuidgen);
	local new_record=$(build_new_record "$table_name" "$new_id");

	# lock table because other operations can affect ours
	lock "$table_name";

	# line number of this table
	line_number_table=$(grep -n "^### $table_name\$" $(tablefile "$table_name") | awk '{print $1}' | sed 's/^\([0-9]*\):.*/\1/g');

	if ! is_int $line_number_table; then

		# unlock again, nothing we can do
		unlock "$table_name";

		fatal "Table \"$table_name\" could not be located.";
		exit 1;
	fi

	commit_to_db "$table_name" "$new_record" "$line_number_table"

	# unlock again, we're done
	unlock "$table_name";

	if id_in_db "$new_id"; then
		output "$new_id";
	else
		fatal "Record was not created, cause unknown.";
		exit 1;
	fi

}


build_new_record () {
	local table_name="$1";
	local id="$2";
	local fetch_from_old_record="$3";

	args=$(echo "$argument_list" | egrep -v 'update|insert|into');
	local columns=$(get_columns "$table_name");

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
			value=$(get "$(record_by_id $id)" "$table_name" "$column_name" "" "" | jq -r ".[].$column_name");

			# jq has null implemented, but shell of course doesn't.
			if [[ "$value" == "null" ]]; then
				value="";
			fi
		fi

		# for better or worse, we have a value
		# verify the value against the data type
		value=$(sanitize_column_value "$column_name" "$column_type" "$value");

		# sanitize the value
		value=$(sanitize "$value");

		# ok, at least now it's not worse
		new_record=$(append "$new_record" "$value" "$delim");
	done

	# yay a new record!
	output "$new_record";
}

id_to_line_number () {
	id="$1";

	local line_number=$(egrep -n "^$id" $(tablefile "$table_name") | awk '{print $1}' | sed 's/^\([0-9]*\):.*/\1/g');

	if is_int "$line_number"; then
		echo "$line_number";
	fi
}

delete () {
	local id="$1";
	local table_name="$2";

	# lock table so nobody else can write while we are
	lock "$table_name";

	# get line number by matching the ID
	local line_number=$(egrep -n "^$id" $(tablefile "$table_name") | awk '{print $1}' | sed 's/^\([0-9]*\):.*/\1/g');

	if ! is_int "$line_number"; then

		unlock "$table_name";
		fatal "Could not delete record: ID not found in database.";
		exit 1;
	fi

	# delete by line number
	delete_line_by_number "$table_name" "$line_number"

	# unlock table again
	unlock "$table_name";
}

update () {
	local id="$1";
	local table_name="$2";

	# lock table so nobody else can write while we are
	lock "$table_name";

	local updated_record=$(build_new_record "$table_name" "$id" 1);

	local line_number=$(id_to_line_number "$id");

	if ! is_int "$line_number"; then

		unlock "$table_name";
		fatal "Error updating record: ID not found in database.";
		exit 1;
	fi

	local escaped_updated_record=$(echo "$updated_record" | sed -e 's/[\/&]/\\&/g');

	#@tag_update_sanitize
	#escaped_updated_record=$(sanitize "$escaped_updated_record");

	# replace line by line number
	sed -i "${line_number}s/.*/$escaped_updated_record/" "$(tablefile "$table_name")";

	# unlock table again
	unlock "$table_name"

	output "OK";
}

# read all records from a table
from_table () {
	table_name="$1";

	cat $(tablefile "$table_name") | sed -n "/### $table_name\$/,/###/p" | grep -v '^###' | grep -v '^--'
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
			warning "Column \"$column\" needs to be an integer, not whatever the shit \"$value\" is.";
		fi

	elif [[ "$type" == "bool" ]]; then

		# good bool.
		if [[ "$value" == "0" || "$value" == "1" ]]; then
			echo "$value";

		# bool shit. fucking cunts can't do anything right.
		else
			warning "Column \"$column\" needs to be a bool, 0 or 1. Please don't send \"$value\" again.";
		fi

	elif [[ "$type" == "text" ]]; then

		# text accepts all. Let's do fuck-all.
		printf "$value";
	fi
}

