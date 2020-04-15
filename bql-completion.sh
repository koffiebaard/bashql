#/usr/bin/env bash

# resolve source properly (with support for symlink)
source="${BASH_SOURCE[0]}";
if [[ -L "$source" ]]; then
	source="$(readlink "$source")"
fi

curdir="$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )";
TAB=$'\t';

source "$curdir/lib/autocompletion_tools.sh"

_bashql_completion() {

	local cur prev
	_get_comp_words_by_ref -n = cur prev

	#@tag_main_options
    local main_opts='--use= --show --select= --insert --create --update= --alter --drop --delete --rename --describe= --rawr --help';

	    #@tag_show
    	local show_opts="--databases --tables";

	    #@tag_describe
    	local describe_opts="--tabular --verbose";

	    #@tag_select
	    local select_opts="--from=";
	    	local select_opts_from="--id= --find= --limit= --tabular";

	    #@tag_insert
	    local insert_opts="--into=";

	    #@tag_create
	    local create_opts="--table --database";
	    	local create_opts_table="--columns --verbose";

	    #@tag_update
	    local update_opts="--id --verbose";

	    #@tag_drop
	    local drop_opts="--table= --database=";

	    #@tag_alter
	    local alter_opts="--table=";
	    	local alter_opts_table="--addcolumn= --rename= --to= --drop=";

	    #@tag_rename
	    local rename_opts="--table= --database=";
	    	local rename_opts_table="--to= --verbose";
	    	local rename_opts_database="--to= --verbose";

	    #@tag_delete
    	local delete_opts="--from=";
	    	local delete_opts_from="--id= --verbose";


	# list of all arguments entered in commandline (except for the values)
    cmd_args=""
    for meh in "${COMP_WORDS[@]}"; do

    	if [[ ${meh::2} == "--" ]]; then
    		cmd_args+=" $meh";
    	elif [[ "$meh" == "=" ]]; then
    		cmd_args+="$meh";
    	fi
    done


    # check if there's any of the main options present
    chosen_main_opt=$(opt_list_in_list "$cmd_args" "$main_opts");

    # --use= database autocompletion
    #@tag_use_database
    if [[ "$cur" =~ \-\-use=[a-zA-Z0-9_]*$ || \
    	  "$cur" =~ \-\-database=[a-zA-Z0-9_]*$ ]]; then
		db_list=$(find $curdir/data/*  -printf "%f\n");
		smaller_comp_word=$(echo "$cur" | sed 's/--[a-zA-Z0-9_]*=//g');
		COMPREPLY=( $(compgen -W "$db_list" -- "$smaller_comp_word") );

	#@tag_from_table
    elif [[ "$cur" =~ \-\-from=[a-zA-Z0-9_]*$ || \
    		"$cur" =~ \-\-table=[a-zA-Z0-9_]*$ || \
    		"$cur" =~ \-\-describe=[a-zA-Z0-9_]*$ || \
    		"$cur" =~ \-\-into=[a-zA-Z0-9_]*$ ]]; then

    	# is the command succeeding? otherwise there's no database selected.
    	db_check=$(bql --show --tables &> /dev/null);
    	return_code=$?;
    	if [[ $return_code == 0 ]]; then
			table_list=$(bql --show --tables | jq -r '.[]');
			smaller_comp_word=$(echo "$cur" | sed 's/--[a-zA-Z0-9_]*=//g');
			COMPREPLY=( $(compgen -W "$table_list" -- "$smaller_comp_word") );
		fi

	# no main option chosen yet?
    elif [[ "$chosen_main_opt" == "" ]]; then
		COMPREPLY=( $(compgen -W "${main_opts}" -- "$cur") )

	# if yes, show the next level of options
	else

		# get the options for the next level
		options_for_chosen_main=$(get_options "${chosen_main_opt}_opts");

		# ok so no completion for specific argument, do we have options to show at all?
		if [[ "$options_for_chosen_main" != "" ]]; then

			# is any of the options (for the chosen main argument) already supplied as an argument?
			chosen_opt=$(opt_list_in_list "$cmd_args" "$options_for_chosen_main");

			# if so, show the options for /that/ argument
			if [[ "$chosen_opt" != "" ]]; then
				options_for_chosen_opt=$(get_options "${chosen_main_opt}_opts_${chosen_opt}");
				COMPREPLY=( $(compgen -W "$options_for_chosen_opt" -- "${COMP_WORDS[COMP_CWORD]}") );

			# if no, show the options for the chosen main argument
			else
				COMPREPLY=( $(compgen -W "$options_for_chosen_main" -- "${COMP_WORDS[COMP_CWORD]}") );
			fi
		fi
    fi


	if [[ "$COMPREPLY" =~ =$ ]]; then
	    compopt -o nospace
	fi

    return 0
}

complete -F _bashql_completion bql