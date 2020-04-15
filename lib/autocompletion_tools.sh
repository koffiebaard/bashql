#!/bin/bash

# check if an argument is in a list of possible arguments
opt_in_list () {
	local opt_list=$1;
	local entered_opt=$2;

	if [[ "$opt_list" == *"$entered_opt "* || "$opt_list" =~ $entered_opt$ ]]; then

		local chosen_opt=$(echo "$entered_opt" | sed 's/--//g' | sed 's/=$//g');
		echo $chosen_opt;
	fi
}

# match a list of possible arguments to a list of actual supplied arguments
opt_list_in_list () {
	local opt_list="$1";
	local check_against_list="$2";

	# go through all entered commands and check if there's one in $check_against_list
	for entered_cmd in $(echo "$opt_list" | tr ' ' '\n'); do

		entered_cmd=$(echo "$entered_cmd" | sed 's/=.*$/=/g');

		if [[ $(opt_in_list "$check_against_list" "$entered_cmd") != "" ]]; then
			echo $(opt_in_list "$check_against_list" "$entered_cmd");
			break;
		fi
	done
}

# get options for a chosen argument
get_options () {
	local chosen_opt_variable=$1;

	chosen_opt_variable=$(echo "$chosen_opt_variable" | sed 's/=.*$/=/g');

	options_for_chosen="${!chosen_opt_variable}";

	echo "$options_for_chosen";
}