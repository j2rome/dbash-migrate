#!/usr/bin/env bash

# Copyright (c) 2013, Jérome Da Costa. All rights reserved.
# https://github.com/j2rome/db-migrate

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
## Redistributions of source code must retain the above copyright
#  notice, this list of conditions and the following disclaimer.
## Redistributions in binary form must reproduce the above copyright
#  notice, this list of conditions and the following disclaimer in the
#  documentation and/or other materials provided with the distribution.
## Neither the name of Jérome Da Costa nor the
#  names of its contributors may be used to endorse or promote products
#  derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE HOLDERS AND CONTRIBUTORS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE REGENTS AND CONTRIBUTORS BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

database=""
host=""
command=""
db_credentials=""

progname=$0

function usage() 
{
        cat <<EOF

SYNOPSYS
       $0 [options] -d database [-h hostname] command 

DESCRIPTION 
       db-migrate is inspired from rake db:migrate command in Ruby On Rails.
       It enables perform migrating and rollbacking a script on a given database.

       -u, --user=name     
              User for login into database
       -p, --password 
              Password to use when connecting to database server. If password is
              not given it's asked from the tty.
       -h, --host
              database hostname

COMMAND SYNOPSYS

       create          # Create the database
       drop            # Drops the database 
       migrate         # Migrate the database (options: VERSION=x, VERBOSE=false).
       status          # Display status of migrations
       rollback        # Rolls the schema back to the previous version (specify steps w/ STEP=n).
       setup           # Create the database, load the schema, and initialize 
                         with the seed data (use db:reset to also drop the db first)
       version         # Retrieves the current schema version number

COPYRIGHT
       TODO Include copyright

EOF
    exit 1;
}


declare -r project_dir=$PWD
migrate_directory=$project_dir/db/migrate

declare program_name=$0

function migration_lookup_at() {
    declare dirname=$1
    find $dirname -name "[0-9]*_*.sh" | sort -n
}

function migration_file_lookup_at() {
    declare dirname=$1
    declare version=$2
    find $dirname -name "$version*_*.sh"
}

# Keep only the filename without its extension
# Call with multiple arguments is supported
#
# Ex: /home/john/db/migrate/20120704155915_foo.sh -> 20120704155915_foo
function version_migration_name() {
    declare files="$1"
    basename $files | sed  s'/\.sh//'  | sort -n
}

function connect() 
{
    mysql $db_credentials $host "$@"
}

function database_exists() {
    batch_options="--batch --skip-column-names"
    connect $batch_options -e "SHOW DATABASES like '$database';" | grep -q $database > /dev/null
}
function index_exists_for() {
    declare table_name=$1
    batch_options="--batch --skip-column-names"
    connect $batch_options $database -e "SHOW INDEX from $table_name;" | grep -q $table_name
}

function initialize_schema_migrations_table() {
    connect $database -e 'CREATE TABLE IF NOT EXISTS schema_migrations (version varchar(255) NOT NULL);'
    if ( ! index_exists_for "schema_migrations" )
    then 
	connect $database -e  "CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations (version);"
    fi
}

function retrieve_current_schema_version() {
    retrieve_schema_versions "DESC LIMIT 1"
}

function retrieve_schema_versions() {
    declare sql_query_options=$*
    if [ -z "$sql_query_options" ] 
    then
	sql_query_options="ASC"
    fi
    
    batch_options="--batch --skip-column-names"
    result=$(connect $batch_options $database -e "SELECT version FROM schema_migrations where version != 0 ORDER BY version $sql_query_options;")
    if [ $? -ne 1 ] # schema versions found
    then
	echo $result
    fi
}

function assume_migrated_upto_version() {
    declare upto=$1
    #TODO upgrade upto
    add_version $upto
}
function create() {
    
    if ( database_exists )
    then
	echo "$database already exists"
    else
	connect -e "CREATE DATABASE $database";
    fi
}

function drop() {
    
        echo -n "Really (YES/NO) NO ? "
	read response
	if [ -n "$response" -a "$response" = "YES" ]
	then
    	    connect -e "DROP DATABASE $database" && echo "Database dropped!"
	else 
	    echo "Aborted"
	fi
}

function display_pending_migrations() {
    declare pending_migrations=$*
    
    if [ -n "$pending_migrations" ] 
    then
    	echo " You have $(echo $pending_migrations | wc -w) pending migrations:"
    	for I in $pending_migrations
    	do
	    echo "$(extract_version_from_filename $I) $(extract_migration_name_from_filename $I)"
    	done
    	echo "Run \`$progname migrate\` to update your database then try again."
    fi
}    

function setup() {
    
    create 

    echo "-- initialize_schema_migrations_table()"
    initialize_schema_migrations_table # -> 0.0014s
    echo '-- assume_migrated_upto_version(0, ["/home/jdacosta/projects/src2/depot/db/migrate"])'
    current_schema_version=`retrieve_current_schema_version`
    
    if [ -z $current_schema_version ] 
    then
	assume_migrated_upto_version 0
#    else 
#	assume_migrated_upto_version $current_schema_version
    fi
 #  -> 0.2530s
    
    pending_migrations=`pending_migrations_exists`
    display_pending_migrations $pending_migrations
}

function pending_migrations_exists() {
    declare schema_versions=`retrieve_schema_versions`
    declare migration_files=`migration_lookup_at $migrate_directory`
    
    pending_migrations_exists_with "$migration_files" "$schema_versions"
}

function version() {
    declare version
    version=`retrieve_current_schema_version` && echo "Current version: $version" 
}

function rollback() {
   declare step=$1
   if [ -z $step ]
   then
       step=1
   fi
   create > /dev/null
   initialize_schema_migrations_table
   declare schema_versions=`retrieve_schema_versions "DESC LIMIT $step"`
   command="connect $database -e"   
   for version in $schema_versions
   do
       file=`migration_file_lookup_at $migrate_directory $version`
       # TODO if file does not exists
       filename=`version_migration_name $file`

       echo "==  $filename: reverting =====" 
       result=`source $file && $command "$DOWN"`
       if [ $? -eq 0 ];
       then
	   echo $result
	   remove_version "$version"
	   echo "==  $filename: reverted (0.0000s) ====="
	   echo
       else
	    echo "$progname aborted!"
	    echo "An error has occurred, this and all later migrations canceled"
	    echo
	    exit 1;
	fi
       
   done
}

function migrate() {
    create > /dev/null
    initialize_schema_migrations_table
    
    files=`pending_migrations_exists`
    
    command="connect $database -e"

    for I in $files
    do
	filename=`version_migration_name $I`
	version=`extract_version_from_filename $filename` 
	
	echo "==  $filename: migrating ====="    
	result=`source $I && $command "$UP"`  # up $command`
	if [ $? -eq 0 ];
	then
	    echo $result
	    add_version "$version"
	    echo "==  $filename: migrated (0.0000s) ====="
	    echo
	else
	    echo "$progname aborted!"
	    echo "An error has occurred, this and all later migrations canceled"
	    exit 1;
	fi
    done
}


function add_version() {
    declare version=$1
    connect $database -e "INSERT INTO schema_migrations (version) VALUES ($version);"
}

function remove_version() {
    declare version=$1
    connect $database -e "DELETE FROM schema_migrations where version='$version';"
}

# Extract only the version assuming that the filename is like :
# /home/john/db/migrate/20120704155915_foo.sh -> 20120704155915
# or 
# 20120704155915_foo.sh -> 20120704155915
function extract_version_from_filename() {
    basename $1 | cut -f 1 -d "_"
}

# Extract only the migration_name assuming that the filename is like :
# /home/john/db/migrate/20120704155915_add_foo_to_user.sh -> add_foo_to_user
# or 
# 20120704155915_add_foo_to_user.sh -> add_foo_to_user
function extract_migration_name_from_filename() {
    version_migration_name $1 | cut -f 2- -d "_" 
}

function pending_migration_exists_for_file() {
    declare filename=$1
    declare schema_versions=$2
    
    for version in $schema_versions 
    do
     	version_file=`extract_version_from_filename $filename`
     	if [ $version_file = $version ] 
     	then
     	    echo "0";
	    return;
     	fi
    done
    echo "1";
}

function pending_migrations_exists_with() {
    declare migration_files=$1
    declare schema_versions=$2
    declare pending_migrations=""

    for filename in $migration_files
    do
    	match=`pending_migration_exists_for_file "$filename" "$schema_versions"`
    	if [ "$match" = 1 ] 
    	 then
    	    pending_migrations=$pending_migrations" "$filename
    	fi
    done
    
    echo $pending_migrations
}


function status() {
    ## Retrieves all migrations versions from files and from database
    declare migration_files=`migration_lookup_at $migrate_directory`
    declare file_versions=""
    for I in $migration_files
    do
	file_versions=$file_versions" "`extract_version_from_filename $I`
    done
    declare schema_versions=`retrieve_schema_versions`
    migrations_versions=`echo $schema_versions$file_versions | sed s'/\ /\n/g' | sort -nu`
    
    echo
    echo "database: $database"
    echo
    echo "  Status   Migration ID    Migration Name"
    echo "--------------------------------------------------"
    for version in $migrations_versions
    do
	file=`migration_file_lookup_at $migrate_directory $version`
	if [ -z $file ]
	then
	    migration_name="********** NO FILE **********"
	    status="   up"
	else 
	    migration_name=`extract_migration_name_from_filename $file`
	    match=`pending_migration_exists_for_file "$file" "$schema_versions"`

     	    if [ "$match" = 1 ]
     	    then
     		status=" down"
     	    else
     		status="   up"
     	    fi
	fi
	echo "$status     $version  $migration_name"
    done
}

function parse_arguments() {
    while [ $# -ne 0 ]
    do
	case "$1" in
	    
	    -p|--password)
		db_credentials="$db_credentials -p$2"
		shift
		;;
	    -u|--username)
		db_credentials="$db_credentials -u $2"
		shift
		;;
	    -d|--database)
		database=$2
		shift
		;;
	    -h|--host)
		host="-h $2"
		shift
		;;
	    *)
		command=$1
		;;
	esac
	shift
    done
    
# default options
    # if [ -z $host ]
    # then
    # 	host="-h localhost"
    # fi
}


function main() {
    parse_arguments $*
    

# echo "database $database"
# echo "host $host"
# echo "command $command"
# echo "credentials $db_credentials"

    
    if [ -z $database ]
    then
	usage
    fi
    
    if [ -z $command ]
    then
	usage
    fi
    
    $command
}

main $*
