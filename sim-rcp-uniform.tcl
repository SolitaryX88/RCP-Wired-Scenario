
Class RCP_pair

#Variables:
#rcps rcpr:  Sender RCP, Receiver RCP 
#sn   dn  :  source/dest node which RCP sender/receiver exist
#:  (only for setup_wnode)
#delay    :  delay between sn and san (dn and dan)
#:  (only for setup_wnode)
#san  dan :  nodes to which sn/dn are attached   
#aggr_ctrl:  Agent_Aggr_pair for callback
#start_cbfunc:  callback at start
#fin_cbfunc:  callback at start
#group_id :  group id
#pair_id  :  group id
#id       :  flow id
#Public Functions:
#setup{snode dnode link_rate}       <- either of them
#setup_wnode{snode dnode link_rate} <- must be called
#setgid {gid}             <- if applicable (default 0)
#setpairid {pid}          <- if applicable (default 0)
#setfid {fid}             <- if applicable (default 0)
#set_debug_mode { mode }    ;# change to debug_mode
#start { nr_pkts } ;# let start sending nr_pkts 

#set_fincallback { controller func} #; only Agent_Aggr_pair uses to 
##; registor itself and fin_notify
#set_startcallback { controller func} #; only Agent_Aggr_pair uses to 
##; registor itself and start_notify
#fin_notify {}  #; Callback .. this is called 
##; by agent when it finished
#Private Function
#flow_finished {} {

RCP_pair instproc init {args} {
    $self instvar pair_id group_id id debug_mode
    $self instvar rcps rcpr;# Sender RCP,  Receiver RCP

    eval $self next $args

    $self set rcps [new Agent/RCP]  ;# Sender RCP
    $self set rcpr [new Agent/RCP]  ;# Receiver RCP

    $rcps set_callback $self

    $self set pair_id  0
    $self set group_id 0
    $self set id       0
    $self set debug_mode 0
}

RCP_pair instproc set_debug_mode { mode } {
    $self instvar debug_mode
    $self set debug_mode $mode
}

RCP_pair instproc setup {snode dnode link_rate} {
#Directly connect agents to snode, dnode.
#For faster simulation.
    global ns 
    $self instvar rcps rcpr;# Sender RCP,  Receiver RCP
    $self instvar san dan  ;# memorize dumbell node (to attach)

    $self set san $snode
    $self set dan $dnode

    $ns attach-agent $snode $rcps;
    $ns attach-agent $dnode $rcpr;

    $ns connect $rcps $rcpr
}

RCP_pair instproc setup_wnode {snode dnode link_dly link_rate} {

#New nodes are allocated for sender/receiver agents.
#They are connected to snode/dnode with link having delay of link_dly.
#Caution: If the number of pairs is large, simulation gets way too slow,
#and memory consumption gets very very large..
#Use "setup" if possible in such cases.

    global ns
    $self instvar sn dn    ;# Source Node, Dest Node
    $self instvar rcps rcpr;# Sender RCP,  Receiver RCP
    $self instvar san dan  ;# memorize dumbell node (to attach)
    $self instvar delay    ;# local link delay

    $self set delay link_dly

    $self set sn [$ns node]
    $self set dn [$ns node]

    $self set san $snode
    $self set dan $dnode

    $ns duplex-link $snode $sn  [set link_rate]Gb $delay  DropTail
    $ns duplex-link $dn $dnode  [set link_rate]Gb $delay  DropTail

    $ns attach-agent $sn $rcps;
    $ns attach-agent $dn $rcpr;

    $ns connect $rcps $rcpr
}

RCP_pair instproc set_fincallback { controller func} {
    $self instvar aggr_ctrl fin_cbfunc
    $self set aggr_ctrl  $controller
    $self set fin_cbfunc  $func
}

RCP_pair instproc set_startcallback { controller func} {
    $self instvar aggr_ctrl start_cbfunc
    $self set aggr_ctrl $controller
    $self set start_cbfunc $func
}

RCP_pair instproc setgid { gid } {
    $self instvar group_id
    $self set group_id $gid
}

RCP_pair instproc setpairid { pid } {
    $self instvar pair_id
    $self set pair_id $pid
}

RCP_pair instproc setfid { fid } {
    $self instvar rcps rcpr
    $self instvar id
    $self set id $fid
    $rcps set fid_ $fid;
    $rcpr set fid_ $fid;
}

RCP_pair instproc start { nr_pkts } {
    global ns
    $self instvar rcps id group_id
    $self instvar start_time pkts
    $self instvar aggr_ctrl start_cbfunc
    $self instvar debug_mode

    $self set start_time [$ns now] ;# memorize
    $self set pkts       $nr_pkts  ;# memorize

    set pktsize [$rcps set packetSize_]

    if { $debug_mode == 1 } {
	puts "stats: [$ns now] start grp $group_id fid $id $nr_pkts pkts ($pktsize +40)"
    }

    if { [info exists aggr_ctrl] && [info exists start_cbfunc] } {
	$aggr_ctrl $start_cbfunc
    }

    $rcps set numpkts_ $nr_pkts
    $rcps sendfile
}


RCP_pair instproc stop {} {
    $self instvar rcps rcpr

    $rcps reset
    $rcpr reset
}

RCP_pair instproc fin_notify {} {
    global ns
    $self instvar sn dn san dan
    $self instvar rcps rcpr
    $self instvar aggr_ctrl fin_cbfunc
    $self instvar pair_id
    $self instvar pkts

    $self instvar dt
    $self instvar pps

    $self flow_finished

    $rcps reset
    $rcpr reset

    if { [info exists aggr_ctrl] && [info exists fin_cbfunc] } {
	$aggr_ctrl $fin_cbfunc $pair_id $pkts $dt $pps
    }
}

RCP_pair instproc flow_finished {} {
    global ns
    $self instvar start_time pkts id group_id
    $self instvar dt pps
    $self instvar debug_mode

    set ct [$ns now]
    $self set dt  [expr $ct - $start_time]
    $self set pps [expr $pkts / $dt ]

    if { $debug_mode == 1 } {
	puts "stats: $ct fin grp $group_id fid $id fldur $dt sec $pps pps"
    }
}

############################################
#Modification for  Agent/RCP

#Let RCP sender to callback fin_notify
#when it received fin-ack.
############################################
Agent/RCP instproc set_callback {rcp_pair} {
    $self instvar ctrl
    $self set ctrl $rcp_pair
}

Agent/RCP instproc done {} {
    global ns sink
    $self instvar ctrl
#puts "[$ns now] $self fin-ack received";
    if { [info exists ctrl] } {
	$ctrl fin_notify
    }
}

######### Just for debugging ####################################
Agent/RCP instproc begin-datasend {} {
    global ns
#$self instvar sstart
#$self set sstart [$ns now]
#puts "[$ns now] $self fid_ [$self set fid_] begin-datasend";
}
Agent/RCP instproc finish-datasend {} {
    global ns
#puts "[$ns now] $self fid_ [$self set fid_] finish-datasend";
}

Agent/RCP instproc syn-sent {} {
    global ns
#puts "[$ns now] $self fid_ [$self set fid_] sys-sent";
}

Agent/RCP instproc fin-received {} {
    global ns
    $self instvar ctrl
#puts "[$ns now] $self fid_ [$self set fid_] fin-received";
#$ctrl flow_finished
}


Class Agent_Aggr_pair
#Note:
#Contoller and placeholder of Agent_pairs
#Let Agent_pairs to arrives according to
#random process. 
#Currently, the following two processes are defined
#- PParrival:
#flow arrival is poissson and 
#each flow contains pareto 
#distributed number of packets.
#- PEarrival
#flow arrival is poissson and 
#each flow contains pareto 
#distributed number of packets.
#- PBarrival
#flow arrival is poissson and 
#each flow contains bimodal
#distributed number of packets.

#Variables:#
#apair:    array of Agent_pair
#nr_pairs: the number of pairs
#rv_flow_intval: (r.v.) flow interval
#rv_npkts: (r.v.) the number of packets within a flow
#last_arrival_time: the last flow starting time
#logfile: log file (should have been opend)
#stat_nr_finflow ;# statistics nr  of finished flows
#stat_sum_fldur  ;# statistics sum of finished flow durations
#fid             ;# current flow id of this group
#last_arrival_time ;# last flow arrival time
#actfl             ;# nr of current active flow
#stat_nr_arrflow  ;# statistics nr of arrived flows
#stat_nr_arrpkts  ;# statistics nr of arrived packets

#Public functions:
#attach-logfile {logf}  <- call if want logfile
#setup {snode dnode gid nr link_rate} <- must 
#set_PParrival_process {lambda mean_npkts shape rands1 rands2}  <- call either
#set_PEarrival_process {lambda mean_npkts rands1 rands2}        <- 
#set_PBarrival_process {lambda mean_npkts S1 S2 rands1 rands2}  <- of them
#init_schedule {}       <- must 
#statistics   {}         ;# Print statistics

#fin_notify { pid pkts fldur pps } ;# Callback
#start_notify {}                   ;# Callback

#Private functions:
#init {args}
#resetvars {}

Agent_Aggr_pair instproc init {args} {
    eval $self next $args
}

Agent_Aggr_pair instproc attach-logfile { logf } {
#Public 
    $self instvar logfile
    $self set logfile $logf
}

Agent_Aggr_pair instproc setup {snode dnode gid nr agent_pair_type link_rate} {
#Public
#Note:
#Create nr pairs of Agent_pair
#and connect them to snode-dnode bottleneck.
#We may refer this pair by group_id gid.
#All Agent_pairs have the same gid,
#and each of them has its own flow id [0 .. nr-1]

    $self instvar apair     ;# array of Agent_pair
    $self instvar group_id  ;# group id of this group (given)
    $self instvar nr_pairs  ;# nr of pairs in this group (given)

    $self set group_id $gid 
    $self set nr_pairs $nr

    for {set i 0} {$i < $nr_pairs} {incr i} {
 	$self set apair($i) [new $agent_pair_type]
	$apair($i) setup $snode $dnode $link_rate
	$apair($i) setgid $group_id  ;# let each pair know our group id
	$apair($i) setpairid $i      ;# let each pair know his pair id
    }
    $self resetvars                  ;# other initialization
}

Agent_Aggr_pair instproc init_schedule {} {
#Public
#Note:
#Initially schedule flows for all pairs
#according to the arrival process.
    global ns
    $self instvar nr_pairs apair
    for {set i 0} {$i < $nr_pairs} {incr i} {

	#### Callback Setting ########################
	$apair($i) set_fincallback $self   fin_notify
	$apair($i) set_startcallback $self start_notify
	###############################################

	$self schedule $i
    }
}


Agent_Aggr_pair instproc set_PParrival_process {lambda mean_npkts shape rands1 rands2} {
#Public
#setup random variable rv_flow_intval and rv_npkts.
#To get the r.v.  call "value" function.
#ex)  $rv_flow_intval  value

#- PParrival:
#flow arrival: poissson with rate $lambda
#flow length : pareto with mean $mean_npkts pkts and shape parameter $shape. 

    $self instvar rv_flow_intval rv_npkts

    set pareto_shape $shape
    set rng1 [new RNG]

    $rng1 seed $rands1
    $self set rv_flow_intval [new RandomVariable/Exponential]
    $rv_flow_intval use-rng $rng1
    $rv_flow_intval set avg_ [expr 1.0/$lambda]

    set rng2 [new RNG]
    $rng2 seed $rands2
    $self set rv_npkts [new RandomVariable/Pareto]
    $rv_npkts use-rng $rng2
    $rv_npkts set avg_ $mean_npkts
    $rv_npkts set shape_ $pareto_shape
}

Agent_Aggr_pair instproc set_PEarrival_process {lambda mean_npkts rands1 rands2} {

#setup random variable rv_flow_intval and rv_npkts.
#To get the r.v.  call "value" function.
#ex)  $rv_flow_intval  value

#- PEarrival
#flow arrival: poissson with rate lambda
#flow length : exp with mean mean_npkts pkts.

    $self instvar rv_flow_intval rv_npkts

    set rng1 [new RNG]
    $rng1 seed $rands1

    $self set rv_flow_intval [new RandomVariable/Exponential]
    $rv_flow_intval use-rng $rng1
    $rv_flow_intval set avg_ [expr 1.0/$lambda]


    set rng2 [new RNG]
    $rng2 seed $rands2
    $self set rv_npkts [new RandomVariable/Exponential]
    $rv_npkts use-rng $rng2
    $rv_npkts set avg_ $mean_npkts
}

Agent_Aggr_pair instproc set_PUarrival_process {lambda minPkts maxPkts rands1 rands2} {

    $self instvar rv_flow_intval rv_npkts

    set rng1 [new RNG]
    $rng1 seed $rands1
    $self set rv_flow_intval [new RandomVariable/Exponential]
    $rv_flow_intval use-rng $rng1
    $rv_flow_intval set avg_ [expr 1.0/$lambda]

    set rng2 [new RNG]
    $rng2 seed $rands2
    $self set rv_npkts [new RandomVariable/Uniform]
    $rv_npkts use-rng $rng2
    $rv_npkts set min_ $minPkts
    $rv_npkts set max_ $maxPkts
}

Agent_Aggr_pair instproc set_PBarrival_process {lambda mean_npkts S1 S2 rands1 rands2} {
#Public
#setup random variable rv_flow_intval and rv_npkts.
#To get the r.v.  call "value" function.
#ex)  $rv_flow_intval  value

#- PParrival:
#flow arrival: poissson with rate $lambda
#flow length : pareto with mean $mean_npkts pkts and shape parameter $shape. 

    $self instvar rv_flow_intval rv_npkts

    set rng1 [new RNG]

    $rng1 seed $rands1
    $self set rv_flow_intval [new RandomVariable/Exponential]
    $rv_flow_intval use-rng $rng1
    $rv_flow_intval set avg_ [expr 1.0/$lambda]

    set rng2 [new RNG]

    $rng2 seed $rands2
    $self set rv_npkts [new Binomial_RV]
    $rv_npkts use-rng $rng2

    $rv_npkts set p_ [expr  (1.0*$mean_npkts - $S2)/($S1-$S2)]
    $rv_npkts set S1_ $S1
    $rv_npkts set S2_ $S2

    if { $p < 0 } {
	puts "In PBarrival, prob for bimodal p_ is negative %p_ exiting.. "
	exit 0
    } else {
	puts "# PBarrival S1: $S1 S2: $S2 p_: $p_ mean $mean_npkts"
    }

}

Agent_Aggr_pair instproc resetvars {} {
#Private
#Reset variables
    $self instvar stat_nr_finflow ;# statistics nr  of finished flows
    $self instvar stat_sum_fldur  ;# statistics sum of finished flow durations
    $self instvar fid             ;# current flow id of this group
    $self instvar last_arrival_time ;# last flow arrival time
    $self instvar actfl             ;# nr of current active flow
    $self instvar stat_nr_arrflow  ;# statistics nr of arrived flows
    $self instvar stat_nr_arrpkts  ;# statistics nr of arrived packets

    $self set last_arrival_time 0.0
    $self set fid 0 ;#  flow id starts from 0
    $self set stat_nr_finflow 0
    $self set stat_sum_fldur 0.0
    $self set stat_sum_pps 0.0
    $self set actfl 0
    $self set stat_nr_arrflow 0
    $self set stat_nr_arrpkts 0
}

Agent_Aggr_pair instproc schedule { pid } {
#Private
#Note:
#Schedule  pair (having pid) next flow time
#according to the flow arrival process.

    global ns
    $self instvar apair
    $self instvar fid
    $self instvar last_arrival_time
    $self instvar rv_flow_intval rv_npkts
    $self instvar stat_nr_arrflow
    $self instvar stat_nr_arrpkts


    set dt [$rv_flow_intval value]
    set tnext [expr $last_arrival_time + $dt]
    set t [$ns now]
    
    #The next 5 lines are commented. Getting Not enought flows error all the time!
    if 0 {
    if { $t > $tnext } {
	puts "Error, Not enough flows ! Aborting! pair id $pid"
	flush stdout
	exit 
    }
    }
    $self set last_arrival_time $tnext

    $apair($pid) setfid $fid
    incr fid

    set tmp_ [expr ceil ([$rv_npkts value])]

    incr stat_nr_arrflow
    $self set stat_nr_arrpkts [expr $stat_nr_arrpkts + $tmp_]

    $ns at $tnext "$apair($pid) start $tmp_"
}


Agent_Aggr_pair instproc fin_notify { pid pkts fldur pps } {
#Callback Function
#pid  : pair_id
#pkts : nr of pkts of the flow which has just finished
#fldur: duration of the flow which has just finished
#pps  : avg packet/sec of the flow which has just finished
#Note:
#If we registor $self as "setcallback" of 
#$apair($id), $apair($i) will callback this
#function with argument id when the flow between the pair finishes.
#i.e.
#If we set:  "$apair(13) setcallback $self" somewhere,
#"fin_notify 13 $pkts $fldur $pps" is called when the $apair(13)'s flow is finished.
# 
    global ns
    $self instvar logfile
    $self instvar stat_sum_fldur stat_nr_finflow stat_sum_pps
    $self instvar group_id
    $self instvar actfl
    $self instvar apair

    #Here, we re-schedule $apair($pid).
    #according to the arrival process.

    $self set actfl [expr $actfl - 1]

    incr stat_nr_finflow
    $self set stat_sum_fldur [expr $stat_sum_fldur + $fldur]
    $self set stat_sum_pps   [expr $stat_sum_pps   + $pps]

    set fin_fid [$apair($pid) set id]

    ###### OUPUT STATISTICS #################
    if { [info exists logfile] } {
        puts $logfile "flow_stats: [$ns now] gid $group_id fid $fin_fid pkts $pkts fldur $fldur avgfldur [expr $stat_sum_fldur/$stat_nr_finflow] actfl $actfl avgpps [expr $stat_sum_pps/$stat_nr_finflow] finfl $stat_nr_finflow"
}

    $self schedule $pid ;# re-schedule a pair having pair_id $pid. 
}


Agent_Aggr_pair instproc start_notify {} {
#Callback Function
#Note:
#If we registor $self as "setcallback" of 
#$apair($id), $apair($i) will callback this
#function with argument id when the flow between the pair finishes.
#i.e.
#If we set:  "$apair(13) setcallback $self" somewhere,
#"start_notyf 13" is called when the $apair(13)'s flow is started.
    $self instvar actfl;
    incr actfl;
}


Agent_Aggr_pair instproc statistics {} {
    $self instvar stat_nr_finflow ;# statistics nr  of finished flows
    $self instvar stat_sum_fldur  ;# statistics sum of finished flow durations
    $self instvar fid             ;# current flow id of this group
    $self instvar last_arrival_time ;# last flow arrival time
    $self instvar actfl             ;# nr of current active flow
    $self instvar stat_nr_arrflow  ;# statistics nr of arrived flows
    $self instvar stat_nr_arrpkts  ;# statistics nr of arrived packets

    puts "Aggr_pair statistics1: $self arrflows $stat_nr_arrflow finflow $stat_nr_finflow remain [expr $stat_nr_arrflow - $stat_nr_finflow]"
    puts "Aggr_pair statistics2: $self arrpkts $stat_nr_arrpkts avg_flowsize [expr $stat_nr_arrpkts/$stat_nr_arrflow]"
}


#add/remove packet headers as required
#this must be done before create simulator, i.e., [new Simulator]
remove-all-packet-headers       ;# removes all except common
add-packet-header Flags IP RCP  ;#hdrs reqd for RCP traffic

set ns [new Simulator]
#puts "Date: [clock format [clock seconds]]"
set sim_start [clock seconds]
puts "Host: [exec uname -a]"

#set tf [open traceall.tr w]
#$ns trace-all $tf
#set nf [open out.nam w]
#$ns namtrace-all $nf

if {$argc != 10} {
    puts "usage: ns xxx.tcl sim_end link_rate(Gbps) RTT(per hop,sec) load numbneck alpha beta init_nr_flows minPkts maxPkts"
        exit 0
}

set sim_end [lindex $argv 0]
set link_rate [lindex $argv 1]
set mean_link_delay [expr [lindex $argv 2] / 2.0]
set load [lindex $argv 3]
set numbneck 1
set rcpalpha [lindex $argv 5]
set rcpbeta  [lindex $argv 6]
set init_nr_flow [lindex $argv 7]
set minPkts [lindex $argv 8]
set maxPkts [lindex $argv 9]

set mean_npkts [expr ($maxPkts + $minPkts)/2]

puts "Simulation input:" 
puts "RCP Single bottleneck"
puts "sim_end $sim_end"
puts "link_rate $link_rate Gbps"
puts "RTT  [expr $mean_link_delay * 2.0] sec"
puts "load $load"
puts "numbneck $numbneck"
puts "rcpalpha $rcpalpha"
puts "rcpbeta $rcpbeta"
puts "init_nr_flow $init_nr_flow"
puts "minPkts $minPkts"
puts "maxPkts $maxPkts"
puts "mean flow size $mean_npkts pkts"
puts " "

#
# Added By Babis 
#

set link_rate_b 1
set mean_link_delay_b 0.08
set load_b 0.8
# numbneck the same
#RCP alpha & beta they stay the same
set init_nr_flow_b 1000
set minPkts_b 10
set maxPkts_b 30
set mean_npkts_b 20

puts "Added by Babis"
puts "Second RCP flow"
puts "link_rate: $link_rate_b Gbps"
puts "RTT [expr $mean_link_delay_b * 2.0] sec" 
puts "load $load_b"
puts "numbneck / alpha / beta are the same"
puts "init_nr_flows $init_nr_flow_b"
puts "Min / Max pkts: $minPkts_b / $maxPkts_b"
puts "Mean flow size: $mean_npkts_b"
puts ""

set link_rate_1Gb 1
set link_rate_2Gb 2
set link_rate_2.4Gb [set link_rate]

##### Param of Arrival Process ##############################

#packet size is in bytes.
set pktSize 960
puts "pktSize(payload) $pktSize Bytes"
puts "pktSize(include header) [expr $pktSize + 40] Bytes"

#Random Seed
set arrseed  4
set pktseed  7
puts "arrseed $arrseed pktseed $pktseed"

set lambda [expr ($link_rate*$load*1000000000)/($mean_npkts*($pktSize+40)*8.0)]
puts "Arrival: Poisson with lambda $lambda, FlowSize: Uniform with minPkts $minPkts maxPkts $maxPkts avg $mean_npkts pkts"

Agent/RCP set packetSize_ $pktSize
Queue/DropTail/RCP set alpha_ $rcpalpha
Queue/DropTail/RCP set beta_  $rcpbeta

#Added by Babis

set lambda_b [expr ($link_rate_b*$load_b*1000000000)/($mean_npkts_b*($pktSize+40)*8.0)]
puts "Arrival: Poisson with lambda $lambda_b, FlowSize: Uniform with minPkts $minPkts_b maxPkts $maxPkts_b avg $mean_npkts_b pkts"

############ Buffer SIZE ######################

#In case RCP, as much as possible
set queueSize 100000000000

Queue set limit_ $queueSize
puts "queueSize $queueSize packets"

############# Topoplgy #########################

# Testing Topology
#  node_(1)
#     \	2.4G	 2.4G        2.4G
#	node_(0) -- node_(3) -- node_(4)
#     / 2.4G
#  node_(2)
#

set numnodes 5.0
##The number of the nodes generated

for {set i 0} {$i < $numnodes } {incr i} {
set node_($i) [$ns node]	
}

$ns duplex-link $node_(0) $node_(1)	[set link_rate]Gb $mean_link_delay DropTail/RCP
$ns duplex-link $node_(0) $node_(2)	[set link_rate]Gb $mean_link_delay DropTail/RCP
$ns duplex-link $node_(0) $node_(3) 	[set link_rate]Gb $mean_link_delay DropTail/RCP
$ns duplex-link $node_(3) $node_(4) 	[set link_rate]Gb $mean_link_delay DropTail/RCP

set bnecklink_0_1 [$ns link $node_(0) $node_(1)] 

set bnecklink_0_2 [$ns link $node_(0) $node_(2)]
set bnecklink_0_3 [$ns link $node_(0) $node_(3)]
set bnecklink_3_4 [$ns link $node_(3) $node_(4)]

#############################################################
#Only for RCP
#must set capacity for each queue to get load information
#############################################################
set l_0_1 [$ns link $node_(0) $node_(1)]
set q_0_1 [$l_0_1 queue]
$q_0_1 set-link-capacity [expr $link_rate * 125000000.0]
set l_1_0 [$ns link $node_(1) $node_(0)]
set q_1_0 [$l_1_0 queue]
$q_1_0 set-link-capacity [expr $link_rate * 125000000.0]
$q_0_1 set print_status_ 1
set rcplog_0_1 [open rcp_status.tr w]
$q_0_1 attach $rcplog_0_1
$q_1_0 set print_status_ 0


#Added by Babis

set l_0_2 [$ns link $node_(0) $node_(2)]
set q_0_2 [$l_0_2 queue]
$q_0_2 set-link-capacity [expr $link_rate * 125000000.0]
set l_2_0 [$ns link $node_(2) $node_(0)]
set q_2_0 [$l_2_0 queue]
$q_2_0 set-link-capacity [expr $link_rate * 125000000.0]
$q_0_2 set print_status_ 1
set rcplog_0_2 [open rcp_status_0_2.tr w]
$q_0_2 attach $rcplog_0_2
$q_2_0 set print_status_ 0



set l_0_3 [$ns link $node_(0) $node_(3)]
set q_0_3 [$l_0_3 queue]
$q_0_3 set-link-capacity [expr $link_rate * 125000000.0]
set l_3_0 [$ns link $node_(3) $node_(0)]
set q_3_0 [$l_3_0 queue]
$q_3_0 set-link-capacity [expr $link_rate * 125000000.0]
$q_0_3 set print_status_ 1
set rcplog_0_3 [open rcp_status_0_3.tr w]
$q_0_3 attach $rcplog_0_3
$q_3_0 set print_status_ 0


set l_3_4 [$ns link $node_(3) $node_(4)]
set q_3_4 [$l_3_4 queue]
$q_3_4 set-link-capacity [expr $link_rate * 125000000.0]
set l_4_3 [$ns link $node_(4) $node_(3)]
set q_4_3 [$l_4_3 queue]
$q_4_3 set-link-capacity [expr $link_rate * 125000000.0]
$q_3_4 set print_status_ 1
set rcplog_3_4 [open rcp_status_3_4.tr w]
$q_3_4 attach $rcplog_3_4
$q_4_3 set print_status_ 0

#############  Agents          #########################
set agtagr0 [new Agent_Aggr_pair]

puts "Creating initial $init_nr_flow agents ..."; flush stdout

$agtagr0 setup $node_(1) $node_(4) 0 $init_nr_flow "RCP_pair" $link_rate

set flowlog_1_4 [open flow_1_4.tr w]
$agtagr0 attach-logfile $flowlog_1_4


# Added by Babis 

set agtagr_2_3 [new Agent_Aggr_pair]
$agtagr_2_3 setup $node_(2) $node_(3) 1 $init_nr_flow "RCP_pair" $link_rate_1Gb
set flowlog_2_3 [open flow_2_3.tr w]
$agtagr_2_3 attach-logfile $flowlog_2_3



puts "Initial agent creation done";flush stdout

#For Poisson/Uniform
$agtagr0 set_PUarrival_process $lambda $minPkts $maxPkts $arrseed $pktseed

$agtagr0 init_schedule

#Added by Babis
$agtagr_2_3 set_PUarrival_process $lambda_b $minPkts_b $maxPkts_b $arrseed $pktseed
$agtagr_2_3 init_schedule

puts "Simulation started!"

#$ns at 0.0 "check_fin"

proc check_fin {} {
    global ns agtagr0 agtagr_2_3 numflows
    set nrf [$agtagr0 set stat_nr_finflow]
    if { $nrf > $numflows } {
	$agtagr0 statistics
	finish
    }
	
    set nrf_b [$agtagr_2_3 set stat_nr_finflow]
    if { $nrf_b > $numflows } {
	$agtagr_2_3 statistics
	finish
    }
#puts "nr_finflow $nrf"
    $ns after 1 "check_fin"
}


#############  Queue Monitor   #########################
set qf [open queue.tr w]
set qm [$ns monitor-queue $node_(0) $node_(1) $qf 0.1]
$bnecklink_0_1 queue-sample-timeout

#Added by Babis
set qf_b [open queue_b.tr w]
set qm_b [$ns monitor-queue $node_(0) $node_(2) $qf_b 0.1]
$bnecklink_0_2 queue-sample-timeout

$ns at $sim_end "finish"

proc finish {} {
    global ns qf qf_b flowlog flowlog_2_3
    global sim_start

    global rcplog_0_1 rcplog_0_2

    $ns flush-trace
    close $qf
    close $qf_b
    close $flowlog
    close $flowlog_2_3

#    close $nf
#    close $tf	

    close $rcplog_0_1
    close $rcplog_0_2

    set t [clock seconds]
    puts "Simulation Finished!"
    puts "Time [expr $t - $sim_start] sec"
    puts "Date [clock format [clock seconds]]"
    exit 0
}

$ns run
