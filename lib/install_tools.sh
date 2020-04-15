

link_up_the_symmey () {
	local name=$1;
	local original=$2;
	local symlink=$3;

	ln -s "$original" "$symlink"

	if [[ $? == 0 && -L "$symlink" ]]; then
		printf "$(tput setaf 2)Success.$(tput sgr0)\n";
	else
		printf "$(tput setaf 1)Error: Something went wrong. Symlink is not created.$(tput sgr0)\n";
	fi
}

publish_script () {
	local name=$1;
	local original=$2;
	local symlink=$3;

	printf "$(tput setaf 7)Creating symlink for \"$name\".. $(tput sgr0)";

	# destination exists and is a symlink
	if [[ -L "$symlink" ]]; then

		# if the source doesn't match, fix it: remove and re-symlink.
		if [[ $(readlink "$symlink") != "$original" ]]; then
			rm "$symlink";
			link_up_the_symmey "$name" "$original" "$symlink"
		else
			printf "$(tput setaf 2)Already exists.$(tput sgr0)\n";
		fi

	# destination exists and is a regular file
	elif [[ -f "$symlink" ]]; then

		printf "$(tput setaf 1)Error: Cannot write symlink. File exists and is not a symlink: $symlink$(tput sgr0)\n";

	# destination doesn't exist
	else
		link_up_the_symmey "$name" "$original" "$symlink"
	fi
}

add_autocomplete () {
	local autocomplete_name=$1;
	local autocomplete_script_name=$2;
	local autocomplete_command="$curdir/$autocomplete_script_name";

	if [[ -f "$autocomplete_command" ]]; then

		printf "$(tput setaf 7)Adding \"$autocomplete_name\" to ~/.bash_profile.. $(tput sgr0)"

		if [[ ! -f ~/.bash_profile ]]; then
			touch ~/.bash_profile;
		fi

		# is it not added to bash profile yet?
		if [[ $(grep "$autocomplete_script_name" ~/.bash_profile) == "" ]]; then

			# add to bash profile
			echo "source $autocomplete_command" >>~/.bash_profile

			if [[ $? == 0 ]]; then
				printf "$(tput setaf 2)Success.$(tput sgr0)\n";
			else
				printf "$(tput setaf 1)Error: Something went wrong.$(tput sgr0)\n";
			fi

		# is it there, but under a wrong folder?
		elif [[ $(grep "$autocomplete_command" ~/.bash_profile) == "" ]]; then
			printf "$(tput setaf 3)already there, but to a wrong folder. Fixing.. $(tput sgr0)";

			# remove the line and re-add it
		 	sed -i -e "s/.*$autocomplete_script_name.*//" ~/.bash_profile
			echo "source $autocomplete_command" >>~/.bash_profile

			if [[ $? == 0 ]]; then
				printf "$(tput setaf 2)Success.$(tput sgr0)\n";
			else
				printf "$(tput setaf 1)Error: Something went wrong.$(tput sgr0)\n";
			fi

		# it's there and correct.
		else
			printf "$(tput setaf 2)Already done.$(tput sgr0)\n";
		fi
	fi
}

cmd_exists () {
	local proposed_cmd=$1;

	if [[ $(command -v "$proposed_cmd" | wc -l) -eq 1 ]]; then
		true
	else
		false
	fi
}

guess_package_manager () {

	# linux et al
	if [[ $(uname -s) == "Linux" ]]; then
		if cmd_exists "apt-get"; then
			echo "apt-get";
		elif cmd_exists "apt"; then
			echo "apt";
		elif cmd_exists "yum"; then
			echo "yum";
		elif cmd_exists "pacman"; then
			echo "pacman";
		else
			echo "apt|yum|brew";
		fi

	# mac
	elif [[ $(uname -s) == "Darwin" ]]; then
		echo "brew";
	else
		echo "apt|yum|brew";
	fi
}


check_dependency () {
	command="$1";
	lowest_version_supported="$2";

	printf "%-40s" "$(tput setaf 7)$command$(tput sgr0)";
	if ! cmd_exists "$command"; then
		printf "$(tput setaf 1)Not installed. Please run something like \`$(guess_package_manager) install $command\`$(tput sgr0)\n";
	else

		if [[ "$lowest_version_supported" == "" ]]; then
			echo "$(tput setaf 2)Installed.$(tput sgr0)";
		else
			if [[ "$command" == "jq" ]]; then
				version=$(jq --version | sed 's/jq-\([0-9]*\.[0-9]*\).*/\1/g');
			elif [[ "$command" == "awk" ]]; then
				version=$(awk --version | head -n1 | sed 's/GNU Awk \([0-9]*\.[0-9]*\).*/\1/g');
			else
				version=$($command --version);
			fi

			# compare version to what we need
			if cmd_exists bc && (( $(echo "$version < $lowest_version_supported" |bc -l) )); then
				echo "$(tput setaf 3)$command is version $version, but we only tested $lowest_version_supported and up.$(tput sgr0)";
			else
				echo "$(tput setaf 2)Installed.$(tput sgr0)";
			fi
		fi
	fi
}