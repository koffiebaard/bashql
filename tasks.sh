#!/bin/bash

curdir="$(dirname "$0")";

source "$curdir/lib/db-connector.sh";

task_search_in_table () {
	local select="$(get_argument 'select')";
	local tablename="$(get_argument 'from')";
	local search_string="$(get_argument 'find')";
	local limit="$(get_argument 'limit')";

	# validate tablename
	if ! table_exists "$tablename"; then
		echo "Error: Table \"$tablename\" does not exist.";
		exit 1;
	fi

	local payload=$(get "$(from_table $tablename)" "$tablename" "$select" "$search_string" "$limit");
	output "$payload";
}

task_list_records_in_table () {
	local select="$(get_argument 'select')";
	local tablename="$(get_argument 'from')";
	local limit="$(get_argument 'limit')";

	# validate tablename
	if ! table_exists "$tablename"; then
		echo "Error: Table \"$tablename\" does not exist.";
		exit 1;
	fi

	local payload=$(get "$(from_table $tablename)" "$tablename" "$select" "" "$limit");
	output "$payload";
}


task_get_record_by_id () {
	local select="$(get_argument 'select')";
	local id="$(get_argument 'id')";
	local tablename="$(get_argument 'from')";

	local payload=$(get "$(record_by_id $id)" "$tablename" "$select" "" "");
	output "$payload";
}


task_add_record () {
	local tablename="$(get_argument 'into')";
	local title="$(get_argument 'title')";
	local value="$(get_argument 'value')";

	# validate tablename
	if ! table_exists "$tablename"; then
		output "Error: Table \"$tablename\" does not exist.";
		exit 1;
	fi

	local payload=$(add "$tablename" "$title" "$value");
	output "$payload";
}


task_update_record () {
	local table="$(get_argument 'update')";
	local id="$(get_argument 'id')";
	local title="$(get_argument 'title')";
	local value="$(get_argument 'value')";

	if ! id_in_db "$id"; then
		output "Error: ID \"$id\" does not exist.";
		exit 1;
	fi

	if ! id_belongs_to_table "$id" "$table"; then
		output "Error: ID \"$id\" does not belong to table \"$table\".";
		exit 1;
	fi

	update "$id" "$table";

	if [[ $? == 0 ]]; then
		output "OK";
	else
		output "Unknown error while updating record.";
		exit 1;
	fi
}


task_delete_record () {
	local id="$(get_argument 'id')";
	local table="$(get_argument 'from')";


	if ! id_in_db "$id"; then
		output "Error: ID \"$id\" does not exist.";
		exit 1;
	fi

	if ! id_belongs_to_table "$id" "$table"; then
		output "Error: ID \"$id\" does not belong to table \"$table\".";
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
	local tablename="$(get_argument 'table')";
	local columns="$(get_argument 'columns')";

	local payload=$(create_table "$tablename" "$columns");
	output "$payload";
}

task_drop_table () {
	local tablename="$(get_argument 'table')";

	local payload=$(drop_table "$tablename");
	output "$payload";
}

task_list_tables () {

	# convert list of strings to json array
	local payload=$(list_tables | jq --slurp --raw-input 'split("\n")[:-1]');
	output "$payload";
}

task_info_table () {
	local tablename="$(get_argument 'describe')";

	local payload=$(get_columns "$tablename");
	output "$payload";
}

task_add_column () {
	local tablename="$(get_argument 'table')";
	local name=$(get_argument 'addcolumn' | awk '{print $1}');
	local type=$(get_argument 'addcolumn' | awk '{print $2}');

	local payload=$(add_column "$tablename" "$name" "$type");
	output "$payload";
}