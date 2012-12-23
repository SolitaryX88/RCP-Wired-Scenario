#!/usr/bin/perl -w

$sim_end = 300;
$cap = 2.4;
$rtt = 0.1;
$alpha = 0.1;
$beta = 1;
$load = 0.8;
$numbneck = 1;
$BWdelay = ($rtt*$cap*1000000000)/(1000*8);

$meanFlowSize = 3000; 
$min = 2000;
$max = 4000;
$init_nr_flows = 8500;

`ns sim-rcp-uniform.tcl $sim_end $cap $rtt $load $numbneck $alpha $beta $init_nr_flows $min $max > logFile`;
#`mv logFile logFile-uniform-fs$meanFlowSize`;
#`mv flow.tr flow-uniform-fs$meanFlowSize.tr`; 
#`mv queue.tr queue-uniform-fs$meanFlowSize.tr`;
#`mv rcp_status.tr rcp-uniform-fs$meanFlowSize.tr`;
