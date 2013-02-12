#! /bin/sh
# file: examples/equality_test.sh
#load sut

file_to_test='../src/db.sh'
sut=`mktemp`

# removing main call to import file without executing it
sed -e 's/^main.*//g' $file_to_test > $sut 
# source it
source $sut

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
    migration_lookup_at "missing_dir" 2> /dev/null
    result=$?
    assertFalse "Should be false with missing directory" $result
}



testEquality()
{
  assertEquals 1 1
}


# load shunit2
. lib/shunit2
