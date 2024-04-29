#!/bin/bash


function logEnv {
    echo "$1=$2">>workshop.env
}
function witnessLog {
    echo "$1" >> bwan.log
    echo "$1" >> bwarn.log
    echo "$1" >> cwes.log
    echo "$1" >> cwil.log
    echo "$1" >> awiso.log
    echo "$1" >> awums.log
}
