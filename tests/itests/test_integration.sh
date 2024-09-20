#!/usr/bin/env bats

LXCOPS_ROOT="../../"

@test "build and deploy with custom name" {
    lxc stop lxcops_test_integration
    lxc delete lxcops_test_integration
    $LXCOPS_ROOT/lxcops.sh -n "lxcops_test_integration" -b
    [ lxc list | grep -q "^| lxcops_test_integration " ]
}