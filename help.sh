#!/bin/bash

curdir="$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )"

source "$curdir/lib/internals.sh";

echo "bql $(current_version)"

echo ""

#@tag_help_records
echo "$(tput setaf 5)Records$(tput sgr0)"
printf "\t%-50s%s" "$(tput setaf 7)List all records$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--select=$(tput sgr0)id,title $(tput setaf 6)--from=$(tput sgr0)table"

printf "\t%-50s%s" "$(tput setaf 7)Get the record matching ID$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--select=$(tput sgr0)title $(tput setaf 6)--from=$(tput sgr0)table $(tput setaf 6)--id=$(tput sgr0)id"

printf "\t%-50s%s" "$(tput setaf 7)All records matching search string$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--select=$(tput sgr0)* $(tput setaf 6)--from=$(tput sgr0)table $(tput setaf 6)--find=$(tput sgr0)\"search string\""

printf "\t%-50s%s" "$(tput setaf 7)Database in tablename$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--select=$(tput sgr0)* $(tput setaf 6)--from=$(tput sgr0)database.table"

echo ""

printf "\t%-50s%s" "$(tput setaf 7)Insert record$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--insert $(tput sgr0)$(tput setaf 6)--into=$(tput sgr0)table $(tput setaf 6)--title=$(tput sgr0)title $(tput setaf 6)--content=$(tput sgr0)value"

printf "\t%-50s%s" "$(tput setaf 7)Update record$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--update=$(tput sgr0)table $(tput setaf 6)--id=$(tput sgr0)id $(tput setaf 6)--title=$(tput sgr0)\"new title\""

printf "\t%-50s%s" "$(tput setaf 7)Delete record$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--delete $(tput sgr0)$(tput setaf 6)--from=$(tput sgr0)table $(tput setaf 6)--id=$(tput sgr0)id"

echo ""

#@tag_help_tables
echo "$(tput setaf 5)Tables$(tput sgr0)"

printf "\t%-50s%s" "$(tput setaf 7)Show all tables in database$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--show --tables$(tput sgr0)"

printf "\t%-50s%s" "$(tput setaf 7)List columns in table$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--describe=$(tput sgr0)table"

echo "";

printf "\t%-50s%s" "$(tput setaf 7)Create table$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--create $(tput sgr0)$(tput setaf 6)--table=$(tput sgr0)table $(tput setaf 6)--columns=$(tput sgr0)\"column1 text, column2 int, etc bool\""

printf "\t%-50s%s" "$(tput setaf 7)Rename table$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--rename $(tput sgr0)$(tput setaf 6)--table=$(tput sgr0)table $(tput setaf 6)--to=$(tput sgr0)new_table"

printf "\t%-50s%s" "$(tput setaf 7)Drop table$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--drop $(tput sgr0)$(tput setaf 6)--table=$(tput sgr0)table"

echo "";

#@tag_help_columns
echo "$(tput setaf 5)Columns$(tput sgr0)"

printf "\t%-50s%s" "$(tput setaf 7)Add column$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--alter $(tput sgr0)$(tput setaf 6)--table=$(tput sgr0)table $(tput setaf 6)--addcolumn=$(tput sgr0)'name type'"

printf "\t%-50s%s" "$(tput setaf 7)Rename column$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--alter $(tput sgr0)$(tput setaf 6)--table=$(tput sgr0)table $(tput setaf 6)--rename=$(tput sgr0)column_name $(tput setaf 6)--to=$(tput sgr0)new_column_name"

printf "\t%-50s%s" "$(tput setaf 7)Drop column$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--alter $(tput sgr0)$(tput setaf 6)--table=$(tput sgr0)table $(tput setaf 6)--drop=$(tput sgr0)column_name"

echo ""

#@tag_help_databases
echo "$(tput setaf 5)Databases$(tput sgr0)"

printf "\t%-50s%s" "$(tput setaf 7)Show all databases$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--show --databases$(tput sgr0)"

printf "\t%-50s%s" "$(tput setaf 7)Show all tables in database$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--show --tables$(tput sgr0)"

echo "";

printf "\t%-50s%s" "$(tput setaf 7)Create database$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--create$(tput sgr0) $(tput setaf 6)--database=$(tput sgr0)database"

printf "\t%-50s%s" "$(tput setaf 7)Select database$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--use=$(tput sgr0)database"

printf "\t%-50s%s" "$(tput setaf 7)Show which database is selected$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--select --database$(tput sgr0)"

printf "\t%-50s%s" "$(tput setaf 7)Rename database$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--rename$(tput sgr0) $(tput setaf 6)--database=$(tput sgr0)database $(tput setaf 6)--to=$(tput sgr0)newdatabase"

printf "\t%-50s%s" "$(tput setaf 7)Drop database$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--drop$(tput sgr0) $(tput setaf 6)--database=$(tput sgr0)database"

echo "";

#@tag_help_etcetera
echo "$(tput setaf 5)Etcetera$(tput sgr0)"

printf "\t%-50s%s" "$(tput setaf 7)This very help section$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--help$(tput sgr0)"

printf "\t%-50s%s" "$(tput setaf 7)Rawr$(tput sgr0)"
printf "%s\n" "$(tput setaf 6)bql$(tput sgr0) $(tput setaf 6)--rawr$(tput sgr0)"

echo "";