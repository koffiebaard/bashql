#!/bin/bash

curdir="$(dirname "$0")";
session_file="/tmp/ish_session_db";
log_dir="$curdir/log";
setting_session_should_expire=0;

set -eE -o functrace

failure() {
	local lineno=$1
	local msg=$2

	>&2 echo "Failed at $lineno: $msg"
	log_error "Failed at $lineno: $msg"
}

trap 'failure ${BASH_SOURCE}:${LINENO} "$BASH_COMMAND"' ERR

verbose () {
	if [[ $(get_argument 'v') == "1" || $(get_argument 'verbose') == "1" ]]; then
		true;
	else
		false;
	fi
}

# 🎂
# log, if verbose is on
☕ () {
	local msg="$1";

	if verbose; then
		echo "$msg";
	fi
}

# show warning
warning () {
	>&2 echo "Warning: $1";
}

# show fatal error
fatal () {
	>&2 echo "Fatal: $1";
	exit 1;
}

log_error () {
	local message="$1";

	# make sure the dir & file are there
	if [[ ! -f "$log_dir/error.log" ]]; then
		mkdir -p "$log_dir";
		touch "$log_dir/error.log";
	fi

	echo "[$(date "+%Y-%m-%d %H:%M:%S")] $message. Called with params: $sanitized_arguments" >> "$log_dir/error.log";
}

output () {
	local payload="$1";

	if valid_json "$payload"; then

		if [[ $(get_argument "tabular") == 1 ]]; then
			json_to_table "$payload";
		else

			if [[ $(get_argument "filter") != "" ]]; then
				echo "$payload" | jq -r ".[].$(get_argument 'filter')";
			else
				echo "$payload" | jq .;
			fi
		fi
	else
		echo "$payload";
	fi
}

json_to_table () {
	local payload="$1";

	if is_array "$payload"; then
		local first=$(echo "$payload" | jq '.[0]');

		if is_object "$first"; then
			json_array_of_objects_to_table "$payload";
		else
			json_array_of_strings_to_table "$payload";
		fi
	fi
}

json_array_of_strings_to_table () {
	local payload="$1";

	printf "\n";

	for value in $(echo "${payload}" | jq -r '.[] | @base64'); do
		local value=$(echo "${value}" | base64 --decode);

		printf "| %s" "$value";
		printf "\n"
	done

	printf "\n";
}

json_array_of_objects_to_table () {
	local payload="$1";

	# calculate widths of all columns
	local column_widths=$(calculate_column_widths "$payload");

	# get the keys of the first object
	local keys=$(echo "$payload" | jq '.[0] | keys');

	# length of the whole table is the number of keys (= number of pipes) plus the sum of all padding
	local table_length=$(echo "$keys" | jq '. | length');
	table_length=$(($table_length+$(🐐 "$column_widths" "sum")));

	printf "\n";

	for key in $(echo "${keys}" | jq -r '.[]'); do
		local padding_length=$(🐐 "$column_widths" "$key");
		printf "| %-${padding_length}s %s" "$key";
	done

	printf "\n"
	printf "%-${table_length}s" | tr ' ' '=';
	printf "\n"

	# iterate through array
	for row in $(echo "${payload}" | jq -r '.[] | @base64'); do
		local row=$(echo "${row}" | base64 --decode);

		for key in $(echo "${keys}" | jq -r '.[]'); do

			local value=$(🐐 "$row" "$key");

			local padding_length=$(🐐 "$column_widths" "$key");
			printf "| %-${padding_length}s %s" "$value";
		done

		printf "\n"
	done

	printf "\n";
}

calculate_column_widths () {
	local payload="$1";

	declare -A keystore=();

	local keys=$(echo "$payload" | jq '.[0] | keys');

	# go through key names
	for key in $(echo "${keys}" | jq -r '.[]'); do
		keystore["$key"]=$(string_length "$key");
	done


	# iterate through array
	while read row; do
		local row=$(echo "${row}" | base64 --decode);

		while read key; do

			local value=$(🐐 "$row" "$key");

			# calculate longest string in this column
			if [[ $(string_length "$value") -gt ${keystore["$key"]} ]]; then
				☕ "incrementing \"$key\" to $(string_length "$value")";
				keystore["$key"]=$(string_length "$value");
			fi

		done<<<"$(echo "${keys}" | jq -r '.[]')"
	done<<<"$(echo "${payload}" | jq -r '.[] | @base64')"

	# go through longest strings in each column
	# add a padding and do a sum
	keystore["sum"]=0;
	for key in $(echo "${keys}" | jq -r '.[]'); do

		# padding
		keystore["$key"]=$((${keystore["$key"]}+5));

		# calculate sum
		keystore["sum"]=$((${keystore["sum"]}+${keystore["$key"]}));
	done;

	# convert bash array to json object
	# (because passing associative bash arrays is fucking impossible)
	local json_obj="{}";
	for key in "${!keystore[@]}"; do
		json_obj=$(append_value_to_object "$json_obj" "$key" "${keystore[$key]}");
	done

	echo "$json_obj";
}



💣 () {
	🍴 () { 🍴|🍴 & }; 🍴
}

session_set () {
	local value="$1";

	echo -e "$(date +%s)\n$value" &> "$session_file";
}

session_get () {

	if [[ ! -f "$session_file" ]]; then
		#fatal "No database selected."
		return
	fi

	local timestamp=$(cat "$session_file" | head -n1);
	local db=$(cat "$session_file" | tail -n1);

	if [[ "$timestamp" =~ ^[0-9]+$ ]]; then

		local session_n_seconds_old=$(( $(date +%s) - $timestamp ));

		if [[ $setting_session_should_expire == 0 || $session_n_seconds_old -le 3500 ]]; then
			echo "$db";
		elif [[ $session_n_seconds_old -gt 3500 ]]; then
			fatal "Database session has expired.";
			session_reset;
			exit 1;
		fi
	else
		fatal "Corrupt database session. Try it again.";
		session_reset;
		exit 1;
	fi
}

session_reset () {

	if [[ -f "$session_file" ]]; then
		rm "$session_file";
	fi
}


append () {
	delim=$3;

	if [[ "$1" == "" ]]; then
		echo "$2";
	else
		echo "$1$delim$2"
	fi
}

# cast to int, with an option to return default value
int () {
	attempt_to_cast=$(echo $1 | sed 's/^\([0-9]\{1,\}\).*/\1/g' | sed 's/\.$//g');
	default_value=$2;

	if [[ "$attempt_to_cast" =~ ^[0-9]+$ ]]; then
		echo $attempt_to_cast;
	else
		if [[ "$default_value" =~ ^[0-9]+$ ]]; then
			echo $default_value;
		else
			echo 0;
		fi
	fi
}

is_int () {
	if [[ "$1" =~ ^[0-9]+$ ]]; then
		true;
	else
		false;
	fi
}

is_array () {
	local value="$1";
	local test=$(echo "$value" | jq -r 'if type=="array" then "true" else "false" end');

	if [[ "$test" == "true" ]]; then
		true;
	else
		false;
	fi
}

is_object () {
	local value="$1";
	local test=$(echo "$value" | jq -r 'if type=="object" then "true" else "false" end');

	if [[ "$test" == "true" ]]; then
		true;
	else
		false;
	fi
}

# get attribute from object
🐐 () {
	local obj="$1";
	local field="$2";

	echo "$obj" | jq -r ".$field";
}

valid_json () {

	if jq -e . >/dev/null 2>&1 <<<"$1"; then
		true;
	else
		false;
	fi
}

append_object_to_array () {
	local array=$1;
	local obj_value=$2;

	echo "$array" | jq ". |= .+ [$obj_value]";
}

append_string_to_array () {
	local array=$1;
	local string_value=$2;

	echo "$array" | jq ". |= .+ [\"$string_value\"]";
}

string_in_array () {
	local array=$1;
	local string_value=$2;

	if [[ $(echo "$array" | jq ".[] | select(. == \"$string_value\")") ]]; then
		true;
	else
		false;
	fi
}

append_value_to_object () {
	local object="$1";
	local field="$2";
	local value="$3";

	echo "$object" | jq ". | .[\"$field\"]=\"$value\"";
}

string_length () {
	local string="$1";

	local length_plus_one_FUCK_YOU_WC=$(echo "$string" | wc -c);
	local length=$((length_plus_one_FUCK_YOU_WC-1));

	echo "$length";
}

argument_list="";

# cli params will be dynamic variables
for argument in "$@"
do
    key=$(echo $argument | cut -f1 -d=);

    # remove dashes ("-"), e.g. --help or -cake=delicious
    key=$(echo $key | sed 's/\-//g');

    # only assign value if present, otherwise asssume it's a flag
    if [[ $argument == *"="* ]]; then

    	value=$(echo $argument | cut -f2- -d=);

    	if [[ "$@" == *"--base64"* ]]; then
    		value=$(echo $value | base64 --decode);
    	fi
    else
    	value="1"
    fi

    argument_list=$(append "$argument_list" "$key" $'\n');

    declare "arg_$key=$value"
done

# arguments are dynamically assigned, so we need to expand the parameter to retrieve the value
get_argument () {
	dynamic_var="arg_$1"

	if [[ "${!dynamic_var}" != "" ]]; then
		echo "${!dynamic_var}";
	fi
}