#!/bin/sh

# $1 - setup function
add_test_setup() {
    local setup="$1"
    TEST_SETUP_LIST="${TEST_SETUP_LIST} ${setup}"
}

# $1 - teardown function
add_test_teardown() {
    local teardown="$1"
    TEST_TEARDOWN_LIST="${TEST_TEARDOWN_LIST} ${teardown}"
}

# $1 - test case function
add_test_case() {
    local test_case="$1"
    TEST_CASE_LIST="${TEST_CASE_LIST} ${test_case}"
}

print_assert() {
    echo "$@" >&9
}

print_assert_ok() {
    print_assert -n .
}

print_assert_fail() {
    print_assert F
}

# $* - command
assert() {
    if "$@"; then
        print_assert_ok
    else
        print_assert_fail
        print_assert "ASSERT fail: $*"
        exit 1
    fi
}

# $* - command
assert_not() {
    if "$@"; then
        print_assert_fail
        print_assert "ASSERT_NOT fail: $*"
        exit 1
    else
        print_assert_ok
    fi
}

# $1 - expected status
# $* - command
assert_status() {
    local expected_status="$1"
    shift

    "$@"
    local actual_status="$?"

    if [ "${actual_status}" -eq "${expected_status}" ]; then
        print_assert_ok
    else
        print_assert_fail
        print_assert "ASSERT_STATUS fail: $*: expected <${expected_status}> but was <${actual_status}>"
        exit 1
    fi
}

# $1 - expected standard output
# $* - command
assert_stdout() {
    local expected_stdout="$1"
    shift

    local actual_stdout="$("$@")"

    if [ "${actual_stdout}" = "${expected_stdout}" ]; then
        print_assert_ok
    else
        print_assert_fail
        print_assert "ASSERT_STDOUT fail: $*: expected <${expected_stdout}> but was <${actual_stdout}>"
        exit 1
    fi
}

# $1 - expected value of variable
# $2 - variable name
assert_var() {
    local expected_value="$1" var_name="$2"

    local actual_value
    eval "actual_value=\"\${${var_name}}\""

    if [ "${actual_value}" = "${expected_value}" ]; then
        print_assert_ok
    else
        print_assert_fail
        print_assert "ASSERT_VAR fail: ${var_name}: expected <${expected_value}> but was <${actual_value}>"
        exit 1
    fi
}

# $1 - expression
assert_eval() {
    local expr="$1"

    if eval "${expr}"; then
        print_assert_ok
    else
        print_assert_fail
        print_assert "ASSERT_EVAL fail: ${expr}"
        exit 1
    fi
}

# test runner
run_test() {
    local test_case test_count=0 fail_count=0

    exec 9>&1
    for test_case in ${TEST_CASE_LIST}; do
        test_count=$((test_count + 1))
        (
            local setup
            for setup in ${TEST_SETUP_LIST}; do
                "${setup}"
            done

            "${test_case}"

            local teardown
            for teardown in ${TEST_TEARDOWN_LIST}; do
                ("${teardown}")
            done

            exit 0
        ) || {
            fail_count=$((fail_count + 1))
            print_assert "TEST FAIL: ${test_case}"
        }
    done
    print_assert
    exec 9>&-

    if [ "${fail_count}" -gt 0 ]; then
        echo "NG some tests (${fail_count}/${test_count})!"
        exit 1
    else
        echo "OK all tests ($((test_count - fail_count))/${test_count})."
        exit 0
    fi
}

if [ "${0##*/}" = unit_test.sh ]; then
    (
        echo '########## example of assert OK ##########'

        test_assert_ok() {
            assert true
        }
        add_test_case test_assert_ok

        test_assert_not_ok() {
            assert_not false
        }
        add_test_case test_assert_not_ok

        test_assert_status_ok() {
            assert_status 0 true
        }
        add_test_case test_assert_status_ok

        test_assert_stdout_ok() {
            assert_stdout ' 1  2   3' echo ' 1  2   3'
        }
        add_test_case test_assert_stdout_ok

        test_assert_var_ok() {
            foo='Hello world.'
            assert_var 'Hello world.' foo
        }
        add_test_case test_assert_var_ok

        test_assert_eval_ok() {
            assert_eval '[ foo = foo ]'
        }
        add_test_case test_assert_eval_ok

        run_test
    )

    # assert NG
    (
        echo '########## example of assert NG ##########'

        test_assert_ng() {
            assert false
        }
        add_test_case test_assert_ng

        test_assert_not_ng() {
            assert_not true
        }
        add_test_case test_assert_not_ng

        test_assert_status_ng() {
            assert_status 0 false
        }
        add_test_case test_assert_status_ng

        test_assert_stdout_ng() {
            assert_stdout ' 1  2   3' echo ' 4  5   6'
        }
        add_test_case test_assert_stdout_ng

        test_assert_var_ng() {
            foo=HALO
            assert_var 'Hello world.' foo
        }
        add_test_case test_assert_var_ng

        test_assert_eval_ng() {
            assert_eval '[ foo = bar ]'
        }
        add_test_case test_assert_eval_ng

        run_test
    )
fi

# Local Variables:
# indent-tabs-mode: nil
# End:
