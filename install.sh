#!/bin/bash

curdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )";
install_dir="$HOME/.local/bin"

source "$curdir/lib/internals.sh";
source "$curdir/lib/install_tools.sh";


printf "\n$(tput setaf 5)Installing scripts$(tput sgr0)\n";
publish_script "bql" "$curdir/bql.sh" "$install_dir/bql"

printf "\n$(tput setaf 5)Autocomplete$(tput sgr0)\n";
add_autocomplete "Autocomplete" "bql-completion.sh"

printf "\n$(tput setaf 5)Dependencies$(tput sgr0)\n";
check_dependency "awk"
check_dependency "grep"
check_dependency "jq" "1.5"


printf "\n\nPlease run this command to enable autocomplete before logging out and in:\n\n";
printf "$(tput setaf 4)source ~/.bash_profile$(tput sgr0)\n";

printf "\nBashQL is installed. You can now use bql.\n";
printf "Run \`$(tput setaf 4)bql --create --database=awesome$(tput sgr0)\` to create a database, and \`$(tput setaf 4)bql --help$(tput sgr0)\` to find out more.\n\n"