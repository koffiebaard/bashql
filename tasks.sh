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

	get "$(from_table $tablename)" "$tablename" "$select" "$search_string" "$limit";
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

	get "$(from_table $tablename)" "$tablename" "$select" "" "$limit";
}


task_get_record_by_id () {
	local select="$(get_argument 'select')";
	local id="$(get_argument 'id')";
	local tablename="$(get_argument 'from')";

	get "$(record_by_id $id)" "$tablename" "$select" "" ""
}


task_add_record () {
	local tablename="$(get_argument 'into')";
	local title="$(get_argument 'title')";
	local value="$(get_argument 'value')";

	# validate tablename
	if ! table_exists "$tablename"; then
		echo "Error: Table \"$tablename\" does not exist.";
		exit 1;
	fi

	add "$tablename" "$title" "$value"
}


task_update_record () {
	local table="$(get_argument 'update')";
	local id="$(get_argument 'id')";
	local title="$(get_argument 'title')";
	local value="$(get_argument 'value')";

	if ! id_in_db "$id"; then
		echo "Error: ID \"$id\" does not exist.";
		exit 1;
	fi

	if ! id_belongs_to_table "$id" "$table"; then
		echo "Error: ID \"$id\" does not belong to table \"$table\".";
		exit 1;
	fi

	update "$id" "$table";

	if [[ $? == 0 ]]; then
		echo "OK";
	fi
}


task_delete_record () {
	local id="$(get_argument 'id')";
	local table="$(get_argument 'from')";


	if ! id_in_db "$id"; then
		echo "Error: ID \"$id\" does not exist.";
		exit 1;
	fi

	if ! id_belongs_to_table "$id" "$table"; then
		echo "Error: ID \"$id\" does not belong to table \"$table\".";
		exit 1;
	fi

	delete "$id";

	if [[ $? == 0 ]]; then
		echo "OK";
	fi
}


task_create_table () {
	local tablename="$(get_argument 'table')";
	local columns="$(get_argument 'columns')";

	create_table "$tablename" "$columns";
}

task_drop_table () {
	local tablename="$(get_argument 'table')";

	drop_table "$tablename";
}

