#!/bin/bash

# sad. no cake noms.
cake_noms=0;

# this comes after the cake noms
cake_shats=0;

test_db_per_dir="$1";
test_db_per_file="$2";

validate () {
	is="$2"
	should_be="$3"

	printf "%-90s%s" "$(tput setaf 7)$1$(tput sgr0)";

	if [[ "$is" == "$should_be" ]]; then
		printf "$(tput setaf 2)Passed.$(tput sgr0)%-20s\n";
		let cake_noms++;
	else
		printf "$(tput setaf 1)Failed. Should be \"$should_be\", is \"$is\"$(tput sgr0)%-20s\n";
		let cake_shats++;
	fi
}


# backup the session file, since we'll mess it up in the tests
if [[ -f "/tmp/ish_session_db" ]]; then
	mv /tmp/ish_session_db /tmp/ish_session_db.test.backup
fi

# Dropping test database just in case we failed to remove it previously
bql --drop --database=automatic_test &> /dev/null


#@tag_generic_database
printf "\n$(tput setaf 5)Generic database$(tput sgr0)\n"
validate "Select non-existent database" $(bql --use=supertestcake &> /dev/null || echo "naw") "naw"
validate "Show selected database (fails)" $(bql --select --database &> /dev/null || echo "naw") "naw"
validate "Select correct database" $(bql --use=example) "OK"
validate "Show selected database (succeeds)" $(bql --select --database) "example"
validate "Drop non-existent database" $(bql --drop --database=thisonedefinitelydoesnotexist &> /dev/null || echo "naw") "naw"


#@tag_generic_select
printf "\n$(tput setaf 5)Generic selects$(tput sgr0)\n"
validate "select ID from example.coffee where title = double espresso" $(bql --select=id --from=coffee --find='double espresso' --limit=1 --filter=id) "3885aaa2-a8a3-4742-abc7-99673dfc85d2"
validate "select title from example.coffee where title = double espresso" "$(bql --select=title --from=coffee --find='double espresso' --limit=1 --filter=title)" "Double Espresso"
validate "show tables has cake & coffee" $(bql --show --tables | egrep 'cake|coffee' | wc -l) "2"
validate "set --limit to two" $(bql --select=title --from=cake --limit=2 --filter=title | wc -l) "2"


#@tag_setup_database
printf "\n$(tput setaf 5)Set up database$(tput sgr0)\n"

if [[ "$test_db_per_file" == "1" ]]; then
	validate "Create database" $(bql --create --database=automatic_test --file) "OK"
else
	validate "Create database" $(bql --create --database=automatic_test) "OK"
fi

validate "Create same database again" $(bql --create --database=automatic_test &> /dev/null || echo "naw") "naw"
validate "Select said database" $(bql --use=automatic_test) "OK"


#@tag_create_table
printf "\n$(tput setaf 5)Create table$(tput sgr0)\n"
validate "show tables (empty)" $(bql --show --tables) "[]"
validate "create table" $(bql --create --table=test --columns='col_text text, col_int int, col_bool bool') "OK"
validate "show tables (1 entry)" $(bql --show --tables | jq -r '.[]') "test"
validate "create table, incorrect data type gives warning" $(bql --create --table=testfaultydatatypezz --columns='col_text CUNT, col_int int, col_bool bool' 2>&1 | grep Warning | wc -l) "1"
validate "show tables (2 entries)" $(bql --show --tables | jq -r '.[]' | wc -l) "2"


#@tag_describe_table
printf "\n$(tput setaf 5)Describe table$(tput sgr0)\n"
validate "describe table: Shows 4 fields" $(bql --describe=test | jq -r '.[].name' | egrep 'id|col_text|col_int|col_bool' | wc -l) "4"
validate "describe table: id has type \"text\"" $(bql --describe=test | jq -r '.[] | select(.name == "id")' | jq -r '.type') "text"
validate "describe table: col_text has type \"text\"" $(bql --describe=test | jq -r '.[] | select(.name == "col_text")' | jq -r '.type') "text"
validate "describe table: col_int has type \"int\"" $(bql --describe=test | jq -r '.[] | select(.name == "col_int")' | jq -r '.type') "int"
validate "describe table: col_bool has type \"bool\"" $(bql --describe=test | jq -r '.[] | select(.name == "col_bool")' | jq -r '.type') "bool"


insert_id=$(bql --insert --into=test --col_text="This is some random text yay." --col_int=9001 --col_bool=1);
returncode=$?;

#@tag_insert_record
printf "\n$(tput setaf 5)Insert record$(tput sgr0)\n"
validate "inserted record: returns success" "$returncode" "0"
validate "inserted record: has valid ID (length check)" $(echo "$insert_id" | wc -c) "37"
validate "inserted record: has valid ID (regex check)" $(if [[ "$insert_id" =~ [a-f0-9-]* ]]; then echo "yay"; else echo "naww"; fi) "yay"


another_insert_id=$(bql --insert --into=test --col_text="Another column" --col_int=1001 --col_bool=0);
returncode=$?;

validate "inserted record #2: returns success" "$returncode" "0"


#@tag_select_filter
printf "\n$(tput setaf 5)Select and filter$(tput sgr0)\n"
validate "select=* --id=n with filter: proper value on id" $(bql --select=* --from=test --id="$insert_id" --filter=id) "$insert_id"
validate "select=* --id=n with filter: proper value on col_text" "$(bql --select=* --from=test --id="$insert_id" --filter=col_text)" "This is some random text yay."
validate "select=* --id=n with filter: proper value on col_int" $(bql --select=* --from=test --id="$insert_id" --filter=col_int) "9001"
validate "select=* --id=n with filter: proper value on col_bool" $(bql --select=* --from=test --id="$insert_id" --filter=col_bool) "1"

printf "\n";

validate "select=id --id=n with filter" $(bql --select=id --from=test --id="$insert_id" --filter=id) "$insert_id"
validate "select=id --id=n where ID is non existent" $(bql --select=id,col_int,col_bool --from=test --id="nottheresorry") "[]"
validate "select=col_text --id=n with filter" "$(bql --select=col_text --from=test --id="$insert_id" --filter=col_text)" "This is some random text yay."
validate "select=id,col_int,col_bool --id=n returns 3 properties" $(bql --select=id,col_int,col_bool --from=test --id="$insert_id" | jq '.[]' | wc -l) "5"

printf "\n";

validate "select=* --find='random text' with filter: proper value on col_int" $(bql --select=* --from=test --find='random text' --filter=col_int) 9001
validate "select=* --find='9001' with filter: proper value on col_text" "$(bql --select=* --from=test --find='random text' --filter=col_text)" "This is some random text yay."
validate "select=*: finds two objects" "$(bql --select=* --from=test | jq length)" "2"
validate "select=id: finds two fields" "$(bql --select=* --from=test | jq length)" "2"


#@tag_update_values
printf "\n$(tput setaf 5)Update$(tput sgr0)\n"
validate "update col_text" "$(bql --update=test --id="$insert_id" --col_text='a completely new arbitrary set of characters. whoop whoop.')" "OK"
validate "update to col_text still there" "$(bql --select=col_text --from=test --id="$insert_id" --filter=col_text)" "a completely new arbitrary set of characters. whoop whoop."
validate "update col_int" "$(bql --update=test --id="$insert_id" --col_int=9999)" "OK"
validate "update to col_int still there" "$(bql --select=col_int --from=test --id="$insert_id" --filter=col_int)" "9999"
validate "update col_bool" "$(bql --update=test --id="$insert_id" --col_bool=0)" "OK"
validate "update to col_bool still there" "$(bql --select=col_bool --from=test --id="$insert_id" --filter=col_bool)" "0"


#@tag_unicode_base64
printf "\n$(tput setaf 5)Unicode and base64$(tput sgr0)\n"

# generic base64 test
insert_base64_id=$(bql --insert --into=test --col_text="VGhpcyBpcyBzb21lIHJhbmRvbSB0ZXh0IGJ1dCBiYXNlNjQgZW5jb2RlZCE=" --col_int=OTAwMQ== --col_bool=MQ== --base64);
insert_base64_returncode=$?;

validate "insert base64" "$insert_base64_returncode" "0"
validate "  - col_text has correct value" "$(bql --select=col_text --from=test --id=$insert_base64_id --filter=col_text)" "This is some random text but base64 encoded!"
validate "  - col_int has correct value" "$(bql --select=col_int --from=test --id=$insert_base64_id --filter=col_int)" "9001"
validate "  - col_bool has correct value" "$(bql --select=col_bool --from=test --id=$insert_base64_id --filter=col_bool)" "1"

# smileys, newlines
insert_base64_id=$(bql --insert --into=test --col_text="8J+QlfCfkqggIGNvbnRlbnQgdGVzdArwn5C98J+SpgoKVGVlZWVlc3QKCgrwn5CV" --col_int=OTAwMQ== --col_bool=MQ== --base64);
insert_base64_returncode=$?;

validate "insert base64: newlines and emoji" "$insert_base64_returncode" "0"
validate "  - col_text has correct value" "$(bql --select=col_text --from=test --id=$insert_base64_id --filter=col_text | head -c -1 | base64)" "8J+QlfCfkqggIGNvbnRlbnQgdGVzdArwn5C98J+SpgoKVGVlZWVlc3QKCgrwn5CV"

# big blob of unicode
insert_base64_id=$(bql --insert --into=test --col_text="8J+YgfCfmYLwn5mDCvCfjZHwn42GCvCfkJLwn5CQCvCfmIHwn6SX8J+YgQoKTWF0aGVtYXRpY3MgYW5kIFNjaWVuY2VzOgoKICDiiK4gReKLhWRhID0gUSwgIG4g4oaSIOKIniwg4oiRIGYoaSkgPSDiiI8gZyhpKSwg4oiAeOKIiOKEnTog4oyIeOKMiSA9IOKIkuKMiuKIknjijIssIM6xIOKIpyDCrM6yID0gwqwowqzOsSDiiKggzrIpLAoKICDihJUg4oqGIOKEleKCgCDiioIg4oSkIOKKgiDihJog4oqCIOKEnSDiioIg4oSCLCDiiqUgPCBhIOKJoCBiIOKJoSBjIOKJpCBkIOKJqiDiiqQg4oeSIChBIOKHlCBCKSwKCiAgMkjigoIgKyBP4oKCIOKHjCAySOKCgk8sIFIgPSA0Ljcga86pLCDijIAgMjAwIG1tCgpMaW5ndWlzdGljcyBhbmQgZGljdGlvbmFyaWVzOgoKICDDsGkgxLFudMmZy4huw6bKg8mZbsmZbCBmyZnLiG7Jm3TEsWsgyZlzb8qKc2nLiGXEscqDbgogIFkgW8uIyo9wc2lsyZRuXSwgWWVuIFtqyZtuXSwgWW9nYSBby4hqb8uQZ8mRXQoKQVBMOgoKICAoKFbijbNWKT3ijbPijbRWKS9W4oaQLFYgICAg4oy34oaQ4o2z4oaS4o204oiG4oiH4oqD4oC+4o2O4o2V4oyICgpOaWNlciB0eXBvZ3JhcGh5IGluIHBsYWluIHRleHQgZmlsZXM6CgogICDigKIg4oCYc2luZ2xl4oCZIGFuZCDigJxkb3VibGXigJ0gcXVvdGVzICAgICAgICAgCiAgIOKAoiBDdXJseSBhcG9zdHJvcGhlczog4oCcV2XigJl2ZSBiZWVuIGhlcmXigJ0gCiAgIOKAoiBMYXRpbi0xIGFwb3N0cm9waGUgYW5kIGFjY2VudHM6ICfCtGAKICAg4oCiIOKAmmRldXRzY2hl4oCYIOKAnkFuZsO8aHJ1bmdzemVpY2hlbuKAnAogICDigKIg4oCgLCDigKEsIOKAsCwg4oCiLCAz4oCTNCwg4oCULCDiiJI1Lys1LCDihKIKICAg4oCiIEFTQ0lJIHNhZmV0eSB0ZXN0OiAxbEl8LCAwT0QsIDhCCiAgIOKAoiB0aGUgZXVybyBzeW1ib2w6IOKUgiAxNC45NSDigqwg4pSCICAgIAoKR3JlZWsgKGluIFBvbHl0b25pYyk6CgogIFRoZSBHcmVlayBhbnRoZW06CgogIM6j4b2yIM6zzr3Pic+B4b23zrbPiSDhvIDPgOG9uCDPhOG9tM69IM664b25z4jOtw==" --col_int=OTAwMQ== --col_bool=MQ== --base64);
insert_base64_returncode=$?;

validate "insert base64: big blob of unicode with newlines" "$insert_base64_returncode" "0"
validate "  - col_text has correct value" "$(bql --select=col_text --from=test --id=$insert_base64_id --filter=col_text | head -c -1 | base64 -w 0)" "8J+YgfCfmYLwn5mDCvCfjZHwn42GCvCfkJLwn5CQCvCfmIHwn6SX8J+YgQoKTWF0aGVtYXRpY3MgYW5kIFNjaWVuY2VzOgoKICDiiK4gReKLhWRhID0gUSwgIG4g4oaSIOKIniwg4oiRIGYoaSkgPSDiiI8gZyhpKSwg4oiAeOKIiOKEnTog4oyIeOKMiSA9IOKIkuKMiuKIknjijIssIM6xIOKIpyDCrM6yID0gwqwowqzOsSDiiKggzrIpLAoKICDihJUg4oqGIOKEleKCgCDiioIg4oSkIOKKgiDihJog4oqCIOKEnSDiioIg4oSCLCDiiqUgPCBhIOKJoCBiIOKJoSBjIOKJpCBkIOKJqiDiiqQg4oeSIChBIOKHlCBCKSwKCiAgMkjigoIgKyBP4oKCIOKHjCAySOKCgk8sIFIgPSA0Ljcga86pLCDijIAgMjAwIG1tCgpMaW5ndWlzdGljcyBhbmQgZGljdGlvbmFyaWVzOgoKICDDsGkgxLFudMmZy4huw6bKg8mZbsmZbCBmyZnLiG7Jm3TEsWsgyZlzb8qKc2nLiGXEscqDbgogIFkgW8uIyo9wc2lsyZRuXSwgWWVuIFtqyZtuXSwgWW9nYSBby4hqb8uQZ8mRXQoKQVBMOgoKICAoKFbijbNWKT3ijbPijbRWKS9W4oaQLFYgICAg4oy34oaQ4o2z4oaS4o204oiG4oiH4oqD4oC+4o2O4o2V4oyICgpOaWNlciB0eXBvZ3JhcGh5IGluIHBsYWluIHRleHQgZmlsZXM6CgogICDigKIg4oCYc2luZ2xl4oCZIGFuZCDigJxkb3VibGXigJ0gcXVvdGVzICAgICAgICAgCiAgIOKAoiBDdXJseSBhcG9zdHJvcGhlczog4oCcV2XigJl2ZSBiZWVuIGhlcmXigJ0gCiAgIOKAoiBMYXRpbi0xIGFwb3N0cm9waGUgYW5kIGFjY2VudHM6ICfCtGAKICAg4oCiIOKAmmRldXRzY2hl4oCYIOKAnkFuZsO8aHJ1bmdzemVpY2hlbuKAnAogICDigKIg4oCgLCDigKEsIOKAsCwg4oCiLCAz4oCTNCwg4oCULCDiiJI1Lys1LCDihKIKICAg4oCiIEFTQ0lJIHNhZmV0eSB0ZXN0OiAxbEl8LCAwT0QsIDhCCiAgIOKAoiB0aGUgZXVybyBzeW1ib2w6IOKUgiAxNC45NSDigqwg4pSCICAgIAoKR3JlZWsgKGluIFBvbHl0b25pYyk6CgogIFRoZSBHcmVlayBhbnRoZW06CgogIM6j4b2yIM6zzr3Pic+B4b23zrbPiSDhvIDPgOG9uCDPhOG9tM69IM664b25z4jOtw=="

# braille
insert_base64_id=$(bql --insert --into=test --col_text="4qGM4qCB4qCn4qCRIOKgvOKggeKgkiAg4qGN4qCc4qCH4qCR4qC54qCw4qCOIOKho+KgleKgjArioY3ioJzioIfioJHioLkg4qC64qCB4qCOIOKgmeKgkeKggeKgmeKgkiDioJ7ioJUg4qCD4qCRCuKgm+KglCDioLrioIrioLnioLIg4qG54qC74qCRIOKgiuKgjiDioJ3ioJUg4qCZ4qCz4qCD4qCe" --col_int=OTAwMQ== --col_bool=MQ== --base64);
insert_base64_returncode=$?;

validate "insert base64: braille" "$insert_base64_returncode" "0"
validate "  - col_text has correct value" "$(bql --select=col_text --from=test --id=$insert_base64_id --filter=col_text | head -c -1 | base64 -w 0)" "4qGM4qCB4qCn4qCRIOKgvOKggeKgkiAg4qGN4qCc4qCH4qCR4qC54qCw4qCOIOKho+KgleKgjArioY3ioJzioIfioJHioLkg4qC64qCB4qCOIOKgmeKgkeKggeKgmeKgkiDioJ7ioJUg4qCD4qCRCuKgm+KglCDioLrioIrioLnioLIg4qG54qC74qCRIOKgiuKgjiDioJ3ioJUg4qCZ4qCz4qCD4qCe"

printf "\n"

validate "update base64: emoji + newlines" "$(bql --update=test --id="$insert_base64_id" --col_text='8J+QlfCfkqggIGNvbnRlbnQgdGVzdArwn5C98J+SpgoKVGVlZWVlc3QKCgrwn5CV' --base64)" "OK"
validate "  - col_text has correct value" "$(bql --select=col_text --from=test --id="$insert_base64_id" --filter=col_text | head -c -1 | base64 -w 0)" "8J+QlfCfkqggIGNvbnRlbnQgdGVzdArwn5C98J+SpgoKVGVlZWVlc3QKCgrwn5CV"

validate "update base64: runes" "$(bql --update=test --id="$insert_base64_id" --col_text='4Zq74ZuWIOGas+GaueGaq+GapiDhmqbhmqvhm48g4Zq74ZuWIOGbkuGaouGbnuGbliDhmqnhmr4g4Zqm4Zqr4ZuXIOGbmuGaquGavuGbnuGbliDhmr7hmqnhmrHhmqbhmrnhm5bhmqrhmrHhm57hmqLhm5cg4Zq54ZuB4ZqmIOGapuGaqiDhmrnhm5bhm6Xhmqs=' --base64)" "OK"
validate "  - col_text has correct value" "$(bql --select=col_text --from=test --id="$insert_base64_id" --filter=col_text | head -c -1 | base64 -w 0)" "4Zq74ZuWIOGas+GaueGaq+GapiDhmqbhmqvhm48g4Zq74ZuWIOGbkuGaouGbnuGbliDhmqnhmr4g4Zqm4Zqr4ZuXIOGbmuGaquGavuGbnuGbliDhmr7hmqnhmrHhmqbhmrnhm5bhmqrhmrHhm57hmqLhm5cg4Zq54ZuB4ZqmIOGapuGaqiDhmrnhm5bhm6Xhmqs="

validate "update base64: braille" "$(bql --update=test --id="$insert_base64_id" --col_text='4qGM4qCB4qCn4qCRIOKgvOKggeKgkiAg4qGN4qCc4qCH4qCR4qC54qCw4qCOIOKho+KgleKgjArioY3ioJzioIfioJHioLkg4qC64qCB4qCOIOKgmeKgkeKggeKgmeKgkiDioJ7ioJUg4qCD4qCRCuKgm+KglCDioLrioIrioLnioLIg4qG54qC74qCRIOKgiuKgjiDioJ3ioJUg4qCZ4qCz4qCD4qCe' --base64)" "OK"
validate "  - col_text has correct value" "$(bql --select=col_text --from=test --id="$insert_base64_id" --filter=col_text | head -c -1 | base64 -w 0)" "4qGM4qCB4qCn4qCRIOKgvOKggeKgkiAg4qGN4qCc4qCH4qCR4qC54qCw4qCOIOKho+KgleKgjArioY3ioJzioIfioJHioLkg4qC64qCB4qCOIOKgmeKgkeKggeKgmeKgkiDioJ7ioJUg4qCD4qCRCuKgm+KglCDioLrioIrioLnioLIg4qG54qC74qCRIOKgiuKgjiDioJ3ioJUg4qCZ4qCz4qCD4qCe"



#@tag_add_column
printf "\n$(tput setaf 5)Add column$(tput sgr0)\n"
validate "new column: add column \"cake\" type \"text\"" "$(bql --alter --table=test --addcolumn="cake text")" "OK"
validate "new column: check value (empty)" "$(bql --select=cake --from=test --id="$insert_id" --filter=cake)" ""
validate "new column: update value" "$(bql --update=test --id="$insert_id" --cake=delicious)" "OK"
validate "new column: check value (delicious)" "$(bql --select=cake --from=test --id="$insert_id" --filter=cake)" "delicious"

printf "\n";

validate "new column: add column \"power_level\" type \"int\"" "$(bql --alter --table=test --addcolumn="power_level int")" "OK"
validate "new column: update value" "$(bql --update=test --id="$insert_id" --power_level=9001)" "OK"
validate "new column: check value (9001)" "$(bql --select=power_level --from=test --id="$insert_id" --filter=power_level)" "9001"

printf "\n";

validate "new column: add column \"awesome\" type \"bool\"" "$(bql --alter --table=test --addcolumn="awesome bool")" "OK"
validate "new column: update value" "$(bql --update=test --id="$insert_id" --awesome=1)" "OK"
validate "new column: check value (1)" "$(bql --select=awesome --from=test --id="$insert_id" --filter=awesome)" "1"





# add new tests above this line


#@tag_rename_column
printf "\n$(tput setaf 5)Rename column$(tput sgr0)\n"
validate "rename column" "$(bql --alter --table=test --rename=awesome --to=super_awesome)" "OK"
validate "rename column: select old name" "$(bql --select=awesome --from=test --id="$insert_id")" "[]"
validate "rename column: select new name" "$(bql --select=super_awesome --from=test --id="$insert_id" --filter=super_awesome)" "1"
validate "rename column: incorrect table" "$(bql --alter --table=testzz --rename=super_awesome --to=turbo_awesome &> /dev/null || echo "naw")" "naw"
validate "rename column: incorrect old column name" "$(bql --alter --table=test --rename=super_4w3s0m3 --to=turbo_awesome &> /dev/null || echo "naw")" "naw"
validate "rename column: incorrect new column name" "$(bql --alter --table=test --rename=super_awesome --to='turbo@&*awesome' &> /dev/null || echo "naw")" "naw"


#@tag_drop_column
printf "\n$(tput setaf 5)Drop column$(tput sgr0)\n"
validate "drop column (last one)" "$(bql --alter --table=test --drop=super_awesome)" "OK"
validate "drop column: select dropped column" "$(bql --select=awesome --from=test --id="$insert_id")" "[]"
validate "drop column: check other values (cake)" "$(bql --select=cake --from=test --id="$insert_id" --filter=cake)" "delicious"
validate "drop column: check other values (power_level)" "$(bql --select=power_level --from=test --id="$insert_id" --filter=power_level)" "9001"
validate "drop column: check other values (col_text)" "$(bql --select=col_text --from=test --id="$insert_id" --filter=col_text)" "a completely new arbitrary set of characters. whoop whoop."
validate "drop column: check other values (col_text)" "$(bql --select=col_text --from=test --id="$another_insert_id" --filter=col_text)" "Another column"
validate "drop column: check other values (col_int)" "$(bql --select=col_int --from=test --id="$insert_id" --filter=col_int)" "9999"

printf "\n";

validate "drop another column (first one)" "$(bql --alter --table=test --drop=col_text)" "OK"
validate "drop another column: select dropped column" "$(bql --select=col_text --from=test --id="$insert_id")" "[]"
validate "drop another column: check other values (cake)" "$(bql --select=cake --from=test --id="$insert_id" --filter=cake)" "delicious"

validate "drop another column (middle one)" "$(bql --alter --table=test --drop=col_bool)" "OK"
validate "drop another column: select dropped column" "$(bql --select=col_bool --from=test --id="$insert_id")" "[]"
validate "drop another column: check other values (col_int)" "$(bql --select=col_int --from=test --id="$insert_id" --filter=col_int)" "9999"


#@tag_rename_table
printf "\n$(tput setaf 5)Rename table$(tput sgr0)\n"
validate "rename table" "$(bql --rename --table=test --to=supertest)" "OK"
validate "rename table: select from old name" "$(bql --select=cake --from=test --id="$insert_id" &> /dev/null || echo "naw")" "naw"
validate "rename table: select from new name" "$(bql --select=cake --from=supertest --id="$insert_id" --filter=cake)" "delicious"


#@tag_rename_database
printf "\n$(tput setaf 5)Rename database$(tput sgr0)\n"
validate "rename database" "$(bql --rename --database=automatic_test --to=automatic_titty)" "OK"
validate "rename database: select from old name" "$(bql --select=cake --from=supertest --id="$insert_id" &> /dev/null || echo "naw")" "naw"
validate "rename database: select from new name" "$(bql --select=cake --from=automatic_titty.supertest --id="$insert_id" --filter=cake)" "delicious"
validate "rename database: --use" "$(bql --use=automatic_titty)" "OK"
validate "rename database: select" "$(bql --select=cake --from=automatic_titty.supertest --id="$insert_id" --filter=cake)" "delicious"


#@tag_delete_record
printf "\n$(tput setaf 5)Delete record$(tput sgr0)\n"
validate "delete record" "$(bql --delete --from=supertest --id="$insert_id")" "OK"
validate "delete record: select" "$(bql --select=cake --from=supertest --id="$insert_id")" "[]"


#@tag_drop_table
printf "\n$(tput setaf 5)Drop table$(tput sgr0)\n"
validate "drop table" "$(bql --drop --table=supertest)" "OK"
validate "drop table: select" "$(bql --select=cake --from=supertest &> /dev/null || echo "naw")" "naw"


#@tag_drop_database
printf "\n$(tput setaf 5)Drop database$(tput sgr0)\n"
validate "drop database" "$(bql --drop --database=automatic_titty)" "OK"
validate "drop database: show tables" "$(bql --show --tables &> /dev/null || echo "naw")" "naw"


# reset the session file
if [[ -f "/tmp/ish_session_db.test.backup" ]]; then
	mv /tmp/ish_session_db.test.backup /tmp/ish_session_db
fi


# send out statistics

# line separator
printf "$(tput setaf 7)\n\n";
printf "%-90s" | tr ' ' '-';
printf "$(tput sgr0)"

# header, shows which storage we're testing
if [[ "$test_db_per_file" == 1 ]]; then
	printf "\n\n$(tput setaf 5)Test results file storage$(tput sgr0)\n";
else
	printf "\n\n$(tput setaf 5)Test results dir storage$(tput sgr0)\n"
fi

# test results
printf "$(tput setaf 2)[$cake_noms]$(tput sgr0) $(tput setaf 7)tests succeeded$(tput sgr0)";

if [[ $cake_shats -gt 0 ]]; then
	printf ", $(tput setaf 1)[$cake_shats]$(tput sgr0) $(tput setaf 7)tests failed.$(tput sgr0)\n\n";
else
	printf "$(tput setaf 7).$(tput sgr0)\n\n";
fi

# should we continue to test the other storage method?
if [[ "$test_db_per_file" != 1 && "$test_db_per_dir" == "" ]]; then

	printf "$(tput setaf 7)Continue with database-per-file? [Y/n] $(tput sgr0)";

	read -n1 continue_with_db_per_file;

	if [[ "$continue_with_db_per_file" == "" || "$continue_with_db_per_file" == "y" || "$continue_with_db_per_file" == "Y" ]]; then
		bql --test --file;
	fi

	echo "";
fi