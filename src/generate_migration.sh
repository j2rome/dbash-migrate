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


declare -r project_dir=$PWD
relative_migrate_directory="db/migrate"
migrate_directory=$project_dir/$relative_migrate_directory

declare GREEN='\e[1;32m'
declare NC='\e[0m' # No Color

if [ $# -eq 0 ]
then
    echo "Provides a name for migration file"
    exit 1
fi

file_name=$1

function generate_timestamp() {
    echo $(date +%G%m%d%H%M%S)
}

migration_file_name=`generate_timestamp`_$file_name.sh

if [ ! -d $migrate_directory ] 
then
    mkdir -p $migrate_directory
fi

cat > $migrate_directory/$migration_file_name <<EOF

UP='sql code'

DOWN='sql code'

EOF

echo -ne "${GREEN}      create${NC}"
echo "     $relative_migrate_directory/$migration_file_name"
