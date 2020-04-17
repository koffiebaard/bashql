#!/bin/bash

db_dir="$curdir/data";
database_cached="";
db_file="";
delim="|o_o|";
setting_session_should_expire=0;

source "$curdir/lib/internals.sh";
source "$curdir/lib/database.sh";
source "$curdir/lib/table.sh";
source "$curdir/lib/record.sh";


commit_to_db () {
	local table_name="$1";
	local record="$2";
	local at_linecount="$3";
	local last_linecount=$(get_last_linecount "$table_name");

	# is it the last line in the file? add on a new line.
	if [[ "$at_linecount" == "$last_linecount" || "$at_linecount" == "end" ]]; then
		☕ "adding at the end..";

		# does the file exist, and is it not empty?
		# then we'll add a newline, otherwise not necessary
		if [[ -s "$(tablefile "$table_name")" ]]; then
			printf "\n" >> "$(tablefile "$table_name")";
		fi

		printf '%s' "$record" >> "$(tablefile "$table_name")";

	# if not, just add it on the line below
	else
		☕ "adding after line $at_linecount..";
		# calculate new line number to add the column at
		at_linecount=$((at_linecount+1));

		sed -i "${at_linecount}i$record" "$(tablefile "$table_name")"
	fi
}

delete_line_by_number () {
	local table_name="$1";
	local line_number="$2";
	local last_linecount=$(get_last_linecount "$table_name");

	sed -i "${line_number}d" "$(tablefile "$table_name")"

	# were we removing up until the end of the file? remove the last newline.
	if [[ "$line_number" == "$last_linecount" ]]; then
		truncate -s -1 "$(tablefile "$table_name")";
	fi
}

delete_lines_by_number_range () {
	local table_name="$1";
	local line_number_start="$2";
	local line_number_end="$3";
	local last_linecount=$(get_last_linecount "$table_name");

	sed -i "${line_number_start},${line_number_end}d" "$(tablefile "$table_name")"

	# were we removing up until the end of the file? remove the last newline.
	if [[ "$line_number_end" == "$last_linecount" ]]; then
		truncate -s -1 "$(tablefile "$table_name")";
	fi
}

get_last_linecount () {
	local table_name="$1";

	last_linecount=$(cat "$(tablefile "$table_name")" | wc -l);
	last_linecount=$((last_linecount+1));

	echo "$last_linecount";
}

get_lockfile () {
	local table_name="$1";

	# if the database is stored as a file, we'll lock the whole database
	if stored_as_file; then
		echo "$db_dir/.ish_databaselock_$(database)";

	# otherwise we lock the table, in the database directory
	else
		echo "$(databasefile)/.ish_tablelock_${table_name}";
	fi
}

_lock_table () {
	local table_name="$1";

	echo "$instance_id" > $(get_lockfile "$table_name");
}

_unlock_table () {
	local table_name="$1";

	rm $(get_lockfile "$table_name");
}

_is_lock_ours () {
	local table_name="$1";

	if [[ $(cat "$(get_lockfile "$table_name")") == "$instance_id" ]]; then
		true;
	else
		false;
	fi
}

lock () {
	local table_name="$1";

	lockfile=$(get_lockfile "$table_name");
	successful_lock=0;

	# max. 75 attempts to obtain a lock, waiting 0.2s each time
	# so timeout = 15s
	for attempt in {1..75}; do

		if [[ ! -f "$lockfile" ]]; then

			# ITS OURS
			_lock_table "$table_name";

			# but is it really?
			if _is_lock_ours "$table_name"; then

				successful_lock=1;
				break;
			fi
		fi

		# wait before checking the lock again
		sleep 0.2;
	done

	if [[ "$successful_lock" == 0 ]]; then
		fatal "Cannot obtain lock on table. Already locked by another process. Try again later.";
		exit 1;
	fi
}

unlock () {
	local table_name="$1";
	local lockfile=$(get_lockfile "$table_name");

	if [[ ! -f "$lockfile" ]]; then
		warning "Tried to unlock table \"$table_name\", but it's already unlocked.";
	fi

	if [[ $(cat "$lockfile") != "$instance_id" ]]; then
		warning "Tried to unlock table \"$table_name\", but it's not ours (anymore?).";
	fi

	_unlock_table "$table_name";
}

stored_as_file () {
	local database_location="$(databasefile)";

	if [[ -f "$database_location" ]]; then
		true;
	else
		false;
	fi
}

stored_as_dir () {
	local database_location="$(databasefile)";

	if [[ -d "$database_location" ]]; then
		true;
	else
		false;
	fi
}