#!/usr/bin/env bats

BATS_DEBUG=true
LXCOPS_SCRIPT="../../lxcops.sh"

@test "build and deploy with custom name" {
    if lxc list | grep -q "^| lxcopsTestIntegration "; then
        lxc stop lxcopsTestIntegration
        lxc delete lxcopsTestIntegration
    fi
    $LXCOPS_SCRIPT -n "lxcopsTestIntegration" -b
    [ "$(lxc list | grep "lxcopsTestIntegration")" ]
    lxc stop lxcopsTestIntegration
    lxc delete lxcopsTestIntegration
}