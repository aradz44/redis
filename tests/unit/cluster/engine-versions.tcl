# Check if cluster's view of engine versions is consistent
proc are_engine_version_propagated {match_string} {
    for {set j 0} {$j < [llength $::servers]} {incr j} {
        set cfg [R $j cluster slots]
        foreach shard $cfg {
            for {set node_id 0} {$node_id < [llength [lindex $shard 3]]} {incr i} {
                if {! [string match $match_string [lindex [lindex $shard 3 $node_id] 15]] || 
                ! [string match "engine-version" [lindex [lindex $shard 3 $node_id] 14]]} {
                    return 0
                }
            }
        }
    }
    return 1
}

proc get_shards_field {shard_output shard_id node_id attrib_id} {
    return [lindex [lindex [lindex $shard_output $shard_id 3] $node_id] $attrib_id]
}


start_cluster 3 4 {tags {external:skip cluster} } {
test "Verify engine versions are propagated" {
    wait_for_condition 50 100 {
        [are_engine_version_propagated "255.255.255"] eq 1
    } else {
        fail "cluster engine versions were not propagated"
    }

    # Now that everything is propagated, assert everyone agrees
    wait_for_cluster_propagation
}

test "Test restart will keep engine-version information" {
    restart_server 0 true false
    set shards_result [R 0 CLUSTER SHARDS]
    assert_equal [get_shards_field $shards_result 0 0 14]  "engine-version"
    assert_equal [get_shards_field $shards_result 0 0 15]  "255.255.255"

    # As a sanity check, make sure everyone eventually agrees
    wait_for_cluster_propagation
}
}