#!/bin/bash

validate () {
        is=$2
        should_be=$3

        printf "%-90s%s" "$(tput setaf 7)$1$(tput sgr0)";

        if [[ "$is" == "$should_be" ]]; then
                printf "$(tput setaf 2)Passed.$(tput sgr0)%-20s\n";

        else
                printf "$(tput setaf 1)Failed. Should be \"$should_be\", is \"$is\"$(tput sgr0)%-20s\n";
        fi


}


# Database
printf "\n$(tput setaf 3)Database$(tput sgr0)\n"
validate "select non-existent database" $(./i.sh --use=supertestcake &> /dev/null || echo "naw") "naw"
validate "select correct database" $(./i.sh --use=example) "OK"


# Select table
printf "\n$(tput setaf 3)Select$(tput sgr0)\n"
validate "select ID from example.coffee where title = double espresso" $(./i.sh --select=id --from=coffee --find='double espresso' --limit=1 --filter=id) "3885aaa2-a8a3-4742-abc7-99673dfc85d2"
validate "select title from example.coffee where title = double espresso" "$(./i.sh --select=title --from=coffee --find='double espresso' --limit=1 --filter=title)" "Double Espresso"
validate "show tables has cake & coffee" $(./i.sh --show --tables | egrep 'cake|coffee' | wc -l) "2"
validate "set --limit to two" $(./i.sh --select=title --from=cake --limit=2 --filter=title | wc -l) "2"


printf "\n";