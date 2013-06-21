#!/bin/bash
# file: examples/equality_test.sh

temporary_file_to_test=`mktemp`

removing_main_call() {
  local file_to_test='../src/db.sh'
  sed -e 's/^main.*//g' $file_to_test > ${temporary_file_to_test} 
  source ${temporary_file_to_test}
}
removing_main_call

#testCheckBinaryIsNotFound()
#{
#    result="`PATH= main`"
#    assertEquals "Should display usage" "`usage_without_binary`" "$result" 
#}

testDisplayUsageIfNoArgProvidedOnCli()
{
    result="`main`"
    assertEquals "Should display usage" "`usage`" "$result"
}

testDisplayUsageIfNoCommandProvidedOnCli()
{
    result="`main -d databasename`"
    assertEquals "Should display usage" "`usage`" "$result"
}

#TODO display error with unknown error
testDisplayNothingIfUnknownCommand()
{
    result="`main -d databasename unknowncommand 2> /dev/null`"
    assertEquals "Should display nothing" "" "$result"
}


testSearchMigrationFiles() 
{
    migration_lookup_at "missing_dir" #2> /dev/null
    result=$?
    assertFalse "Should be false with missing directory" $result
}



testEquality()
{
  assertEquals 1 1
}


# load shunit2
. lib/shunit2
rm ${temporary_file_to_test}

