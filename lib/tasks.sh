#!/bin/bash

task_search_in_table () {
	local select="$(get_argument 'select')";
	local table_name="$(filter_table $(get_argument 'from'))";
	local search_string="$(get_argument 'find')";
	local limit="$(get_argument 'limit')";

	# validate table_name
	if ! table_exists "$table_name"; then
		echo "Error: Table \"$table_name\" does not exist.";
		exit 1;
	fi

	get "$(from_table $table_name)" "$table_name" "$select" "$search_string" "$limit";
}

task_list_records_in_table () {
	local select="$(get_argument 'select')";
	local table_name="$(filter_table $(get_argument 'from'))";
	local limit="$(get_argument 'limit')";

	# validate table_name
	if ! table_exists "$table_name"; then
		echo "Error: Table \"$table_name\" does not exist.";
		exit 1;
	fi

	get "$(from_table $table_name)" "$table_name" "$select" "" "$limit";
}


task_get_record_by_id () {
	local select="$(get_argument 'select')";
	local id="$(get_argument 'id')";
	local table_name="$(filter_table $(get_argument 'from'))";

	# validate table_name
	if ! table_exists "$table_name"; then
		echo "Error: Table \"$table_name\" does not exist.";
		exit 1;
	fi

	get "$(record_by_id $id)" "$table_name" "$select" "" "";
}


task_add_record () {
	local table_name="$(filter_table $(get_argument 'into'))";
	local title="$(get_argument 'title')";
	local value="$(get_argument 'value')";

	# validate table_name
	if ! table_exists "$table_name"; then
		output "Error: Table \"$table_name\" does not exist.";
		exit 1;
	fi

	add "$table_name" "$title" "$value";
}


task_update_record () {
	local table_name="$(filter_table $(get_argument 'update'))";
	local id="$(get_argument 'id')";
	local title="$(get_argument 'title')";
	local value="$(get_argument 'value')";

	if ! id_in_db "$id"; then
		output "Error: ID \"$id\" does not exist.";
		exit 1;
	fi

	if ! id_belongs_to_table "$id" "$table_name"; then
		output "Error: ID \"$id\" does not belong to table \"$table_name\".";
		exit 1;
	fi

	update "$id" "$table_name";
}


task_delete_record () {
	local id="$(get_argument 'id')";
	local table_name="$(filter_table $(get_argument 'from'))";


	if ! id_in_db "$id"; then
		output "Error: ID \"$id\" does not exist.";
		exit 1;
	fi

	if ! id_belongs_to_table "$id" "$table_name"; then
		output "Error: ID \"$id\" does not belong to table \"$table_name\".";
		exit 1;
	fi

	delete "$id" "$table_name";

	if [[ $? == 0 ]]; then
		output "OK";
	else
		output "Unknown error while deleting record.";
		exit 1;
	fi
}

task_create_table () {
	local table_name="$(filter_table $(get_argument 'table'))";
	local columns="$(get_argument 'columns')";

	create_table "$table_name" "$columns";
}

task_drop_table () {
	local table_name="$(filter_table $(get_argument 'table'))";

	drop_table "$table_name";
}

task_list_tables () {

	# convert list of strings to json array
	list_tables | jq --slurp --raw-input 'split("\n")[:-1]';
}

task_rename_table () {
	local table_name="$(filter_table $(get_argument 'table'))";
	local new_table_name="$(filter_table $(get_argument 'to'))";

	rename_table "$table_name" "$new_table_name";
}

task_list_databases () {

	# convert list of strings to json array
	ls "$db_dir" | jq --slurp --raw-input 'split("\n")[:-1]';
}

task_info_table () {
	local table_name="$(filter_table $(get_argument 'describe'))";

	local payload=$(get_columns "$table_name");
	local returncode=$?;

	output "$payload";
	exit $returncode;
}

task_add_column () {
	local table_name="$(filter_table $(get_argument 'table'))";
	local name=$(get_argument 'addcolumn' | awk '{print $1}');
	local type=$(get_argument 'addcolumn' | awk '{print $2}');

	add_column "$table_name" "$name" "$type";
}

task_rename_column () {
	local table_name="$(filter_table $(get_argument 'table'))";
	local name=$(get_argument 'rename');
	local new_name=$(get_argument 'to' | awk '{print $1}');
	local new_type=$(get_argument 'to' | awk '{print $2}');

	rename_column "$table_name" "$name" "$new_name" "$new_type"
}

task_drop_column () {
	local table_name="$(filter_table $(get_argument 'table'))";
	local name=$(get_argument 'drop');

	drop_column "$table_name" "$name";
}

task_persist_database () {
	local db="$(get_argument "use")";

	if db_exists "$db"; then
		☕ "Database \"$db\" exists. Selecting..";
		session_set "$db"
		select_database "$db";

		echo "OK";
	else
		fatal "Database \"$db\" doesn't exist.";
	fi
}

task_create_database () {
	local database_name="$(get_argument "database")";
	local stored_as_file="$(get_argument "file")";

	create_database "$database_name" "$stored_as_file";
}

task_drop_database () {
	local database_name="$(get_argument "database")";

	drop_database "$database_name";
}

task_rename_database () {
	local databasename="$(get_argument 'database')";
	local new_databasename="$(get_argument 'to')";

	rename_database "$databasename" "$new_databasename";
}

task_dino () {

	nl=" ";
	for number in {1..12}; do

		# jump up on even, down on odd
		if [[ $number == 12 ]]; then
			echo -e "                                           ";
			echo -e "        $nl                __              ";
			echo -e "        $nl               / _) -- rawr!";
			echo -e "  |     $nl        .-^^^-/ /";
			echo -e " \|     $nl     __/       /";
			echo -e "  |/    $nl    <__.|_|-|_|";
			echo -e "--|----^^-------------------^^----^^^----^^";
		elif (( $number % 2 )); then
			nl+=" ";

			echo -e "                                           ";
			echo -e "        $nl                __              ";
			echo -e "        $nl               / _)             ";
			echo -e "  |     $nl        .-^^^-/ /";
			echo -e " \|     $nl     __/       /";
			echo -e "  |/    $nl    <__.|_|-|_|";
			echo -e "--|----^^-------------------^^----^^^----^^";
		else
			nl+=" ";

			echo -e "        $nl                __              ";
			echo -e "        $nl               / _)             ";
			echo -e "        $nl        .-^^^-/ /               ";
			echo -e "  |     $nl     __/       /                ";
			echo -e " \|     $nl    <__.|_|-|_|";
			echo -e "  |/                                       ";
			echo -e "--|----^^-------------------^^----^^^----^^";
		fi

		sleep 0.2;

		echo -en "\e[7A";
	done

	printf "\n\n\n\n\n\n\n\n";
}

task_current_database () {

	if [[ $(database) != "" ]]; then
		echo $(database);
		exit 0;
	else
		exit 1;
	fi
}

task_current_version () {
	echo "$(current_version)";
}