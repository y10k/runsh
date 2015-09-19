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

test_parameter_expansion_length_ignored_default() {
    assert_eval '[ "${#param_value}" = 1 ]'

    assert_eval '[ "${#param_value:-1234}" = 1 ]'
    assert_eval '[ "${#param_empty:-1234}" = 0 ]'
    assert_eval '[ "${#param_noset:-1234}" = 0 ]'

    assert_eval '[ "${#param_value-1234}" = 1 ]'
    assert_eval '[ "${#param_empty-1234}" = 0 ]'
    assert_eval '[ "${#param_noset-1234}" = 0 ]'

    assert_eval '[ "${#param_value:=1234}" = 1 ]'
    assert_eval '[ "${#param_empty:=1234}" = 0 ]'
    assert_eval '[ "${#param_noset:=1234}" = 0 ]'

    assert_eval '[ "${#param_value=1234}" = 1 ]'
    assert_eval '[ "${#param_empty=1234}" = 0 ]'
    assert_eval '[ "${#param_noset=1234}" = 0 ]'

    assert_eval '[ "${#param_value:?1234}" = 1 ]'
    assert_eval '[ "${#param_empty:?1234}" = 0 ]'
    assert_eval '[ "${#param_noset:?1234}" = 0 ]'

    assert_eval '[ "${#param_value?1234}" = 1 ]'
    assert_eval '[ "${#param_empty?1234}" = 0 ]'
    assert_eval '[ "${#param_noset?1234}" = 0 ]'

    assert_eval '[ "${#param_value:+1234}" = 1 ]'
    assert_eval '[ "${#param_empty:+1234}" = 0 ]'
    assert_eval '[ "${#param_noset:+1234}" = 0 ]'

    assert_eval '[ "${#param_value+1234}" = 1 ]'
    assert_eval '[ "${#param_empty+1234}" = 0 ]'
    assert_eval '[ "${#param_noset+1234}" = 0 ]'

    assert_var a param_value
    assert_var '' param_empty
    assert_var '' param_noset
}
add_test_case test_parameter_expansion_length_ignored_default

test_field_splitting_default_IFS() {
    local split_target="a bc def"
    set -- ${split_target}
    local arg_num="$#" arg1="$1" arg2="$2" arg3="$3"

    assert_var 3 arg_num
    assert_var a arg1
    assert_var bc arg2
    assert_var def arg3
}
add_test_case test_field_splitting_default_IFS

test_field_splitting_default_IFS_more_delimiters() {
    local spc=' ' tab='	' nl='
'

    local split_target="${nl}${spc}${tab}a${spc}${spc}${tab}bc${nl}${tab}${nl}def${tab}${nl}${spc}"
    set -- ${split_target}
    local arg_num="$#" arg1="$1" arg2="$2" arg3="$3"

    assert_var 3 arg_num
    assert_var a arg1
    assert_var bc arg2
    assert_var def arg3
}
add_test_case test_field_splitting_default_IFS_more_delimiters

test_field_splitting_unset_IFS() {
    unset IFS

    local split_target="a bc def"
    set -- ${split_target}
    local arg_num="$#" arg1="$1" arg2="$2" arg3="$3"

    assert_var 3 arg_num
    assert_var a arg1
    assert_var bc arg2
    assert_var def arg3
}
add_test_case test_field_splitting_unset_IFS

test_field_splitting_unset_IFS_more_delimiters() {
    unset IFS
    local spc=' ' tab='	' nl='
'

    local split_target="${nl}${spc}${tab}a${spc}${spc}${tab}bc${nl}${tab}${nl}def${tab}${nl}${spc}"
    set -- ${split_target}
    local arg_num="$#" arg1="$1" arg2="$2" arg3="$3"

    assert_var 3 arg_num
    assert_var a arg1
    assert_var bc arg2
    assert_var def arg3
}
add_test_case test_field_splitting_unset_IFS_more_delimiters

test_field_splitting_set_IFS() {
    local tab='	' nl='
'
    IFS=" ${nl}123"

    local split_target="a${nl}${nl} bc${tab} ${nl}  23 ${tab}def"
    set -- ${split_target}
    local arg_num="$#" arg1="$1" arg2="$2" arg3="$3" arg4="$4"

    assert_var 4 arg_num
    assert_var a arg1
    assert_var "bc${tab}" arg2
    assert_var '' arg3
    assert_var "${tab}def" arg4
}
add_test_case test_field_splitting_set_IFS

test_field_splitting_set_IFS_more_delimiters() {
    IFS=' .'

    local split_target=" .a .  bc   .    def. "
    set -- ${split_target}
    local arg_num="$#" arg1="$1" arg2="$2" arg3="$3" arg4="$4"

    assert_var 4 arg_num
    assert_var '' arg1
    assert_var a arg2
    assert_var bc arg3
    assert_var def arg4
}
add_test_case test_field_splitting_set_IFS_more_delimiters

test_field_splitting_no_IFS() {
    IFS=''

    local split_target="a bc def"
    set -- ${split_target}
    local arg_num="$#" arg1="$1"

    assert_var 1 arg_num
    assert_var 'a bc def' arg1
}
add_test_case test_field_splitting_no_IFS

run_test

# Local Variables:
# indent-tabs-mode: nil
# End:
