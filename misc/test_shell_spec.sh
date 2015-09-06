#!/bin/sh

. "$(dirname $0)/unit_test.sh"

setup_parameter_expansion() {
    param_value=a
    param_empty=''
    unset param_noset
}
add_test_setup setup_parameter_expansion

test_parameter_expansion() {
    assert_eval '[ "${param_value}" = a ]'
}
add_test_case test_parameter_expansion

test_parameter_expansion_default_colon_minus() {
    assert_eval '[ "${param_value:-b}" = a ]'
    assert_eval '[ "${param_empty:-b}" = b ]'
    assert_eval '[ "${param_noset:-b}" = b ]'

    assert_var a param_value
    assert_var '' param_empty
    assert_var '' param_noset
}
add_test_case test_parameter_expansion_default_colon_minus

test_parameter_expansion_default_minus() {
    assert_eval '[ "${param_value-b}" = a ]'
    assert_eval '[ "${param_empty-b}" = "" ]'
    assert_eval '[ "${param_noset-b}" = b ]'

    assert_var a param_value
    assert_var '' param_empty
    assert_var '' param_noset
}
add_test_case test_parameter_expansion_default_minus

test_parameter_expansion_default_colon_equal() {
    assert_eval '[ "${param_value:=b}" = a ]'
    assert_eval '[ "${param_empty:=b}" = b ]'
    assert_eval '[ "${param_noset:=b}" = b ]'

    assert_var a param_value
    assert_var b param_empty
    assert_var b param_noset
}
add_test_case test_parameter_expansion_default_colon_equal

test_parameter_expansion_default_equal() {
    assert_eval '[ "${param_value=b}" = a ]'
    assert_eval '[ "${param_empty=b}" = "" ]'
    assert_eval '[ "${param_noset=b}" = b ]'

    assert_var a param_value
    assert_var '' param_empty
    assert_var b param_noset
}
add_test_case test_parameter_expansion_default_equal

test_parameter_expansion_default_colon_question() {
    assert_eval '[ "${param_value:?b}" = a ]'
    assert_not eval '(: "${param_empty:?b}")' 2>/dev/null
    assert_not eval '(: "${param_noset:?b}")' 2>/dev/null

    assert_var a param_value
    assert_var '' param_empty
    assert_var '' param_noset
}
add_test_case test_parameter_expansion_default_colon_question

test_parameter_expansion_default_question() {
    assert_eval '[ "${param_value?b}" = a ]'
    assert_eval '[ "${param_empty?b}" = "" ]'
    assert_not eval '(: "${param_noset?b}")' 2>/dev/null

    assert_var a param_value
    assert_var '' param_empty
    assert_var '' param_noset
}
add_test_case test_parameter_expansion_default_question

test_parameter_expansion_default_colon_plus() {
    assert_eval '[ "${param_value:+b}" = b ]'
    assert_eval '[ "${param_empty:+b}" = "" ]'
    assert_eval '[ "${param_noset:+b}" = "" ]'

    assert_var a param_value
    assert_var '' param_empty
    assert_var '' param_noset
}
add_test_case test_parameter_expansion_default_colon_plus

test_parameter_expansion_default_plus() {
    assert_eval '[ "${param_value+b}" = b ]'
    assert_eval '[ "${param_empty+b}" = b ]'
    assert_eval '[ "${param_noset+b}" = "" ]'

    assert_var a param_value
    assert_var '' param_empty
    assert_var '' param_noset
}
add_test_case test_parameter_expansion_default_plus

test_parameter_expansion_list_default_minus() {
    set -- ${param_empty:-foo "bar baz"}
    local arg_num="$#" arg1="$1" arg2="$2"

    assert_var 2 arg_num
    assert_var foo arg1
    assert_var 'bar baz' arg2

}
add_test_case test_parameter_expansion_list_default_minus

test_parameter_expansion_list_default_minus_IFS() {
    IFS=.
    set -- ${param_empty:-foo."bar.baz"}
    local arg_num="$#" arg1="$1" arg2="$2"

    assert_var 2 arg_num
    assert_var foo arg1
    assert_var 'bar.baz' arg2
}
add_test_case test_parameter_expansion_list_default_minus_IFS

test_parameter_expansion_list_default_equal() {
    set -- ${param_empty:=foo "bar baz"}
    local arg_num="$#" arg1="$1" arg2="$2" arg3="$3"

    assert_var 3 arg_num
    assert_var foo arg1
    assert_var bar arg2
    assert_var baz arg3

}
add_test_case test_parameter_expansion_list_default_equal

test_parameter_expansion_list_default_equal_IFS() {
    IFS=.
    set -- ${param_empty:=foo."bar.baz"}
    local arg_num="$#" arg1="$1" arg2="$2" arg3="$3"

    assert_var 3 arg_num
    assert_var foo arg1
    assert_var bar arg2
    assert_var baz arg3
}
add_test_case test_parameter_expansion_list_default_equal_IFS

test_parameter_expansion_list_default_plus() {
    set -- ${param_value:+foo "bar baz"}
    local arg_num="$#" arg1="$1" arg2="$2"

    assert_var 2 arg_num
    assert_var foo arg1
    assert_var 'bar baz' arg2

}
add_test_case test_parameter_expansion_list_default_plus

test_parameter_expansion_list_default_plus_IFS() {
    IFS=.
    set -- ${param_value:+foo."bar.baz"}
    local arg_num="$#" arg1="$1" arg2="$2"

    assert_var 2 arg_num
    assert_var foo arg1
    assert_var 'bar.baz' arg2
}
add_test_case test_parameter_expansion_list_default_plus_IFS

run_test

# Local Variables:
# indent-tabs-mode: nil
# End:
