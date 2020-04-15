#!/bin/bash

validate () {
        is="$2"
        should_be="$3"

        printf "%-90s%s" "$(tput setaf 7)$1$(tput sgr0)";

        if [[ "$is" == "$should_be" ]]; then
                printf "$(tput setaf 2)Passed.$(tput sgr0)%-20s\n";

        else
                printf "$(tput setaf 1)Failed. Should be \"$should_be\", is \"$is\"$(tput sgr0)%-20s\n";
        fi


}

# backup the session file, since we'll mess it up in the tests
if [[ -f "/tmp/ish_session_db" ]]; then
	mv /tmp/ish_session_db /tmp/ish_session_db.test.backup
fi

# Dropping test database just in case we failed to remove it previously
./i.sh --drop --database=automatic_test &> /dev/null


#@tag_generic_database
printf "\n$(tput setaf 3)Generic database$(tput sgr0)\n"
validate "Select non-existent database" $(./i.sh --use=supertestcake &> /dev/null || echo "naw") "naw"
validate "Select correct database" $(./i.sh --use=example) "OK"
validate "Drop non-existent database" $(./i.sh --drop --database=thisonedefinitelydoesnotexist &> /dev/null || echo "naw") "naw"


#@tag_generic_select
printf "\n$(tput setaf 3)Generic selects$(tput sgr0)\n"
validate "select ID from example.coffee where title = double espresso" $(./i.sh --select=id --from=coffee --find='double espresso' --limit=1 --filter=id) "3885aaa2-a8a3-4742-abc7-99673dfc85d2"
validate "select title from example.coffee where title = double espresso" "$(./i.sh --select=title --from=coffee --find='double espresso' --limit=1 --filter=title)" "Double Espresso"
validate "show tables has cake & coffee" $(./i.sh --show --tables | egrep 'cake|coffee' | wc -l) "2"
validate "set --limit to two" $(./i.sh --select=title --from=cake --limit=2 --filter=title | wc -l) "2"


#@tag_setup_database
printf "\n$(tput setaf 3)Set up database$(tput sgr0)\n"
validate "Create database" $(./i.sh --create --database=automatic_test) "OK"
validate "Create same database again" $(./i.sh --create --database=automatic_test &> /dev/null || echo "naw") "naw"
validate "Select said database" $(./i.sh --use=automatic_test) "OK"


#@tag_create_table
printf "\n$(tput setaf 3)Create table$(tput sgr0)\n"
validate "show tables (empty)" $(./i.sh --show --tables) "[]"
validate "create table" $(./i.sh --create --table=test --columns='col_text text, col_int int, col_bool bool') "OK"
validate "show tables (1 entry)" $(./i.sh --show --tables | jq -r '.[]') "test"
validate "create table, incorrect data type gives warning" $(./i.sh --create --table=testfaultydatatypezz --columns='col_text CUNT, col_int int, col_bool bool' 2>&1 | grep Warning | wc -l) "1"
validate "show tables (2 entries)" $(./i.sh --show --tables | jq -r '.[]' | wc -l) "2"


#@tag_describe_table
printf "\n$(tput setaf 3)Describe table$(tput sgr0)\n"
validate "describe table: Shows 4 fields" $(./i.sh --describe=test | jq -r '.[].name' | egrep 'id|col_text|col_int|col_bool' | wc -l) "4"
validate "describe table: id has type \"text\"" $(./i.sh --describe=test | jq -r '.[] | select(.name == "id")' | jq -r '.type') "text"
validate "describe table: col_text has type \"text\"" $(./i.sh --describe=test | jq -r '.[] | select(.name == "col_text")' | jq -r '.type') "text"
validate "describe table: col_int has type \"int\"" $(./i.sh --describe=test | jq -r '.[] | select(.name == "col_int")' | jq -r '.type') "int"
validate "describe table: col_bool has type \"bool\"" $(./i.sh --describe=test | jq -r '.[] | select(.name == "col_bool")' | jq -r '.type') "bool"


insert_id=$(./i.sh --insert --into=test --col_text="This is some random text yay." --col_int=9001 --col_bool=1);
returncode=$?;

#@tag_insert_record
printf "\n$(tput setaf 3)Insert record$(tput sgr0)\n"
validate "inserted record: returns success" "$returncode" "0"
validate "inserted record: has valid ID (length check)" $(echo "$insert_id" | wc -c) "37"
validate "inserted record: has valid ID (regex check)" $(if [[ "$insert_id" =~ [a-f0-9-]* ]]; then echo "yay"; else echo "naww"; fi) "yay"


another_insert_id=$(./i.sh --insert --into=test --col_text="Another column" --col_int=1001 --col_bool=0);
returncode=$?;

validate "inserted record #2: returns success" "$returncode" "0"


#@tag_select_filter
printf "\n$(tput setaf 3)Select and filter$(tput sgr0)\n"
validate "select=* --id=n with filter: proper value on id" $(./i.sh --select=* --from=test --id="$insert_id" --filter=id) "$insert_id"
validate "select=* --id=n with filter: proper value on col_text" "$(./i.sh --select=* --from=test --id="$insert_id" --filter=col_text)" "This is some random text yay."
validate "select=* --id=n with filter: proper value on col_int" $(./i.sh --select=* --from=test --id="$insert_id" --filter=col_int) "9001"
validate "select=* --id=n with filter: proper value on col_bool" $(./i.sh --select=* --from=test --id="$insert_id" --filter=col_bool) "1"

printf "\n";

validate "select=id --id=n with filter" $(./i.sh --select=id --from=test --id="$insert_id" --filter=id) "$insert_id"
validate "select=id --id=n where ID is non existent" $(./i.sh --select=id,col_int,col_bool --from=test --id="nottheresorry") "[]"
validate "select=col_text --id=n with filter" "$(./i.sh --select=col_text --from=test --id="$insert_id" --filter=col_text)" "This is some random text yay."
validate "select=id,col_int,col_bool --id=n returns 3 properties" $(./i.sh --select=id,col_int,col_bool --from=test --id="$insert_id" | jq '.[]' | wc -l) "5"

printf "\n";

validate "select=* --find='random text' with filter: proper value on col_int" $(./i.sh --select=* --from=test --find='random text' --filter=col_int) 9001
validate "select=* --find='9001' with filter: proper value on col_text" "$(./i.sh --select=* --from=test --find='random text' --filter=col_text)" "This is some random text yay."
validate "select=*: finds two objects" "$(./i.sh --select=* --from=test | jq length)" "2"
validate "select=id: finds two fields" "$(./i.sh --select=* --from=test | jq length)" "2"


#@tag_update_values
printf "\n$(tput setaf 3)Update$(tput sgr0)\n"
validate "update col_text" "$(./i.sh --update=test --id="$insert_id" --col_text='a completely new arbitrary set of characters. whoop whoop.')" "OK"
validate "update to col_text still there" "$(./i.sh --select=col_text --from=test --id="$insert_id" --filter=col_text)" "a completely new arbitrary set of characters. whoop whoop."
validate "update col_int" "$(./i.sh --update=test --id="$insert_id" --col_int=9999)" "OK"
validate "update to col_int still there" "$(./i.sh --select=col_int --from=test --id="$insert_id" --filter=col_int)" "9999"
validate "update col_bool" "$(./i.sh --update=test --id="$insert_id" --col_bool=0)" "OK"
validate "update to col_bool still there" "$(./i.sh --select=col_bool --from=test --id="$insert_id" --filter=col_bool)" "0"


#@tag_add_column
printf "\n$(tput setaf 3)Add column$(tput sgr0)\n"
validate "new column: add column \"cake\" type \"text\"" "$(./i.sh --alter --table=test --addcolumn="cake text")" "OK"
validate "new column: check value (empty)" "$(./i.sh --select=cake --from=test --id="$insert_id" --filter=cake)" ""
validate "new column: update value" "$(./i.sh --update=test --id="$insert_id" --cake=delicious)" "OK"
validate "new column: check value (delicious)" "$(./i.sh --select=cake --from=test --id="$insert_id" --filter=cake)" "delicious"

printf "\n";

validate "new column: add column \"power_level\" type \"int\"" "$(./i.sh --alter --table=test --addcolumn="power_level int")" "OK"
validate "new column: update value" "$(./i.sh --update=test --id="$insert_id" --power_level=9001)" "OK"
validate "new column: check value (9001)" "$(./i.sh --select=power_level --from=test --id="$insert_id" --filter=power_level)" "9001"

printf "\n";

validate "new column: add column \"awesome\" type \"bool\"" "$(./i.sh --alter --table=test --addcolumn="awesome bool")" "OK"
validate "new column: update value" "$(./i.sh --update=test --id="$insert_id" --awesome=1)" "OK"
validate "new column: check value (1)" "$(./i.sh --select=awesome --from=test --id="$insert_id" --filter=awesome)" "1"





# add new tests above this line


#@tag_rename_column
printf "\n$(tput setaf 3)Rename column$(tput sgr0)\n"
validate "rename column" "$(./i.sh --alter --table=test --rename=awesome --to=super_awesome)" "OK"
validate "rename column: select old name" "$(./i.sh --select=awesome --from=test --id="$insert_id")" "[]"
validate "rename column: select new name" "$(./i.sh --select=super_awesome --from=test --id="$insert_id" --filter=super_awesome)" "1"
validate "rename column: incorrect table" "$(./i.sh --alter --table=testzz --rename=super_awesome --to=turbo_awesome &> /dev/null || echo "naw")" "naw"
validate "rename column: incorrect old column name" "$(./i.sh --alter --table=test --rename=super_4w3s0m3 --to=turbo_awesome &> /dev/null || echo "naw")" "naw"
validate "rename column: incorrect new column name" "$(./i.sh --alter --table=test --rename=super_awesome --to='turbo@&*awesome' &> /dev/null || echo "naw")" "naw"


#@tag_drop_column
printf "\n$(tput setaf 3)Drop column$(tput sgr0)\n"
validate "drop column (last one)" "$(./i.sh --alter --table=test --drop=super_awesome)" "OK"
validate "drop column: select dropped column" "$(./i.sh --select=awesome --from=test --id="$insert_id")" "[]"
validate "drop column: check other values (cake)" "$(./i.sh --select=cake --from=test --id="$insert_id" --filter=cake)" "delicious"
validate "drop column: check other values (power_level)" "$(./i.sh --select=power_level --from=test --id="$insert_id" --filter=power_level)" "9001"
validate "drop column: check other values (col_text)" "$(./i.sh --select=col_text --from=test --id="$insert_id" --filter=col_text)" "a completely new arbitrary set of characters. whoop whoop."
validate "drop column: check other values (col_text)" "$(./i.sh --select=col_text --from=test --id="$another_insert_id" --filter=col_text)" "Another column"
validate "drop column: check other values (col_int)" "$(./i.sh --select=col_int --from=test --id="$insert_id" --filter=col_int)" "9999"

printf "\n";

validate "drop another column (first one)" "$(./i.sh --alter --table=test --drop=col_text)" "OK"
validate "drop another column: select dropped column" "$(./i.sh --select=col_text --from=test --id="$insert_id")" "[]"
validate "drop another column: check other values (cake)" "$(./i.sh --select=cake --from=test --id="$insert_id" --filter=cake)" "delicious"

validate "drop another column (middle one)" "$(./i.sh --alter --table=test --drop=col_bool)" "OK"
validate "drop another column: select dropped column" "$(./i.sh --select=col_bool --from=test --id="$insert_id")" "[]"
validate "drop another column: check other values (col_int)" "$(./i.sh --select=col_int --from=test --id="$insert_id" --filter=col_int)" "9999"


#@tag_rename_table
printf "\n$(tput setaf 3)Rename table$(tput sgr0)\n"
validate "rename table" "$(./i.sh --rename --table=test --to=supertest)" "OK"
validate "rename table: select from old name" "$(./i.sh --select=cake --from=test --id="$insert_id" &> /dev/null || echo "naw")" "naw"
validate "rename table: select from new name" "$(./i.sh --select=cake --from=supertest --id="$insert_id" --filter=cake)" "delicious"


#@tag_rename_database
printf "\n$(tput setaf 3)Rename database$(tput sgr0)\n"
validate "rename database" "$(./i.sh --rename --database=automatic_test --to=automatic_titty)" "OK"
validate "rename database: select from old name" "$(./i.sh --select=cake --from=supertest --id="$insert_id" &> /dev/null || echo "naw")" "naw"
validate "rename database: select from new name" "$(./i.sh --select=cake --from=automatic_titty.supertest --id="$insert_id" --filter=cake)" "delicious"
validate "rename database: --use" "$(./i.sh --use=automatic_titty)" "OK"
validate "rename database: select" "$(./i.sh --select=cake --from=automatic_titty.supertest --id="$insert_id" --filter=cake)" "delicious"


#@tag_delete_record
printf "\n$(tput setaf 3)Delete record$(tput sgr0)\n"
validate "delete record" "$(./i.sh --delete --from=supertest --id="$insert_id")" "OK"
validate "delete record: select" "$(./i.sh --select=cake --from=supertest --id="$insert_id")" "[]"


#@tag_drop_table
printf "\n$(tput setaf 3)Drop table$(tput sgr0)\n"
validate "drop table" "$(./i.sh --drop --table=supertest)" "OK"
validate "drop table: select" "$(./i.sh --select=cake --from=supertest &> /dev/null || echo "naw")" "naw"


#@tag_drop_database
printf "\n$(tput setaf 3)Drop database$(tput sgr0)\n"
validate "drop database" "$(./i.sh --drop --database=automatic_titty)" "OK"
validate "drop database: show tables" "$(./i.sh --show --tables &> /dev/null || echo "naw")" "naw"

printf "\n";



# reset the session file
if [[ -f "/tmp/ish_session_db.test.backup" ]]; then
	mv /tmp/ish_session_db.test.backup /tmp/ish_session_db
fi

