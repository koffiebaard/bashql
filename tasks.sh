#!/bin/bash

curdir="$(dirname "$0")";

source "$curdir/lib/db-connector.sh";

task_search_in_table () {
	local select="$(get_argument 'select')";
	local tablename="$(filter_table $(get_argument 'from'))";
	local search_string="$(get_argument 'find')";
	local limit="$(get_argument 'limit')";

	# validate tablename
	if ! table_exists "$tablename"; then
		echo "Error: Table \"$tablename\" does not exist.";
		exit 1;
	fi

	get "$(from_table $tablename)" "$tablename" "$select" "$search_string" "$limit";
}

task_list_records_in_table () {
	local select="$(get_argument 'select')";
	local tablename="$(filter_table $(get_argument 'from'))";
	local limit="$(get_argument 'limit')";

	# validate tablename
	if ! table_exists "$tablename"; then
		echo "Error: Table \"$tablename\" does not exist.";
		exit 1;
	fi

	get "$(from_table $tablename)" "$tablename" "$select" "" "$limit";
}


task_get_record_by_id () {
	local select="$(get_argument 'select')";
	local id="$(get_argument 'id')";
	local tablename="$(filter_table $(get_argument 'from'))";

	get "$(record_by_id $id)" "$tablename" "$select" "" "";
}


task_add_record () {
	local tablename="$(filter_table $(get_argument 'into'))";
	local title="$(get_argument 'title')";
	local value="$(get_argument 'value')";

	# validate tablename
	if ! table_exists "$tablename"; then
		output "Error: Table \"$tablename\" does not exist.";
		exit 1;
	fi

	add "$tablename" "$title" "$value";
}


task_update_record () {
	local tablename="$(filter_table $(get_argument 'update'))";
	local id="$(get_argument 'id')";
	local title="$(get_argument 'title')";
	local value="$(get_argument 'value')";

	if ! id_in_db "$id"; then
		output "Error: ID \"$id\" does not exist.";
		exit 1;
	fi

	if ! id_belongs_to_table "$id" "$tablename"; then
		output "Error: ID \"$id\" does not belong to table \"$tablename\".";
		exit 1;
	fi

	update "$id" "$tablename";
}


task_delete_record () {
	local id="$(get_argument 'id')";
	local table="$(filter_table $(get_argument 'from'))";


	if ! id_in_db "$id"; then
		output "Error: ID \"$id\" does not exist.";
		exit 1;
	fi

	if ! id_belongs_to_table "$id" "$tablename"; then
		output "Error: ID \"$id\" does not belong to table \"$tablename\".";
		exit 1;
	fi

	delete "$id";

	if [[ $? == 0 ]]; then
		output "OK";
	else
		output "Unknown error while deleting record.";
		exit 1;
	fi
}


task_create_table () {
	local tablename="$(filter_table $(get_argument 'table'))";
	local columns="$(get_argument 'columns')";

	create_table "$tablename" "$columns";
}

task_drop_table () {
	local tablename="$(filter_table $(get_argument 'table'))";

	drop_table "$tablename";
}

task_list_tables () {

	# convert list of strings to json array
	list_tables | jq --slurp --raw-input 'split("\n")[:-1]';
}

task_rename_table () {
	local tablename="$(filter_table $(get_argument 'table'))";
	local new_tablename="$(filter_table $(get_argument 'to'))";

	rename_table "$tablename" "$new_tablename";
}

task_list_databases () {

	# convert list of strings to json array
	ls "$db_dir" | jq --slurp --raw-input 'split("\n")[:-1]';
}

task_info_table () {
	local tablename="$(filter_table $(get_argument 'describe'))";

	local payload=$(get_columns "$tablename");
	local returncode=$?;

	output "$payload";
	exit $returncode;
}

task_add_column () {
	local tablename="$(filter_table $(get_argument 'table'))";
	local name=$(get_argument 'addcolumn' | awk '{print $1}');
	local type=$(get_argument 'addcolumn' | awk '{print $2}');

	add_column "$tablename" "$name" "$type";
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

	create_database "$database_name";
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
