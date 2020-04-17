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
	local record="$1";
	local at_linecount="$2";
	local last_linecount=$(get_last_linecount "$db_file");


	# is it the last line in the file? add on a new line.
	if [[ "$at_linecount" == "$last_linecount" || "$at_linecount" == "end" ]]; then
		☕ "adding at the end..";

		# does the file exist, and is it not empty?
		# then we'll add a newline, otherwise not necessary
		if [[ -s "$db_file" ]]; then
			printf "\n" >> "$db_file";
		fi

		printf '%s' "$record" >> "$db_file";

	# if not, just add it on the line below
	else
		☕ "adding after line $at_linecount..";
		# calculate new line number to add the column at
		at_linecount=$((at_linecount+1));

		sed -i "${at_linecount}i$record" "$db_file"
	fi
}

delete_line_by_number () {
	local line_number="$1";
	local last_linecount=$(get_last_linecount "$db_file");

	sed -i "${line_number}d" "$db_file"

	# were we removing up until the end of the file? remove the last newline.
	if [[ "$line_number" == "$last_linecount" ]]; then
		truncate -s -1 "$db_file";
	fi
}

delete_lines_by_number_range () {
	local line_number_start="$1";
	local line_number_end="$2";
	local last_linecount=$(get_last_linecount "$db_file");

	sed -i "${line_number_start},${line_number_end}d" "$db_file"

	# were we removing up until the end of the file? remove the last newline.
	if [[ "$line_number_end" == "$last_linecount" ]]; then
		truncate -s -1 "$db_file";
	fi
}

get_last_linecount () {
	local file="$1";

	last_linecount=$(cat "$file" | wc -l);
	last_linecount=$((last_linecount+1));

	echo "$last_linecount";
}

get_lockfile () {
	local table="$1";

	echo "$db_dir/.ish_tablelock_$1";
}

_lock_table () {
	local table="$1";

	echo "$instance_id" > $(get_lockfile "$table");
}

_unlock_table () {
	local table="$1";

	rm $(get_lockfile "$table");
}

lock () {
	local table="$1";

	lockfile=$(get_lockfile "$table");
	successful_lock=0;

	# max. 10 attempts to obtain a lock, waiting 0.5s each time
	for attempt in {1..10}; do

		if [[ ! -f "$lockfile" ]]; then
			# ITS OURS
			_lock_table "$table";
			successful_lock=1;
			break;
		fi

		# wait before checking the lock again
		sleep 0.5;
	done

	if [[ "$successful_lock" == 0 ]]; then
		fatal "Cannot obtain lock on table. Already locked by another process. Try again later.";
		exit 1;
	fi
}

unlock () {
	local table="$1";

	if [[ $(cat $(get_lockfile "$table")) == "$instance_id" ]]; then
		_unlock_table "$table";
	else
		warning "Tried to unlock table, but it's not ours (anymore?).";
	fi
}