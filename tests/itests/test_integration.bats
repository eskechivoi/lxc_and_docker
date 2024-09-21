#!/usr/bin/env bats

BATS_DEBUG=true
LXCOPS_SCRIPT="../../lxcops.sh"

setup() {
    if lxc list | grep -q "^| lxcopsTestIntegration "; then
        lxc stop lxcopsTestIntegration
        lxc delete lxcopsTestIntegration
    fi
}

@test "build and deploy with custom name" {
    $LXCOPS_SCRIPT -n "lxcopsTestIntegration" -b
    [ "$(lxc list | grep "lxcopsTestIntegration")" ]
}

teardown() {
    lxc stop lxcopsTestIntegration
    lxc delete lxcopsTestIntegration
}