#!/bin/bash

curdir="$(dirname "$0")";


append () {
	delim=$3;

	if [[ "$1" == "" ]]; then
		echo "$2";
	else
		echo "$1$delim$2"
	fi
}

is_int () {
	if [[ "$1" =~ ^[0-9]+$ ]]; then
		true;
	else
		false;
	fi
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