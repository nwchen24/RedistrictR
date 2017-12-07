#!/bin/bash
if [ $# -eq 0 ]
then
	echo "No arguments. Please provide a target ID."
	exit	
fi
# TODO: add logging

# Set up cluster name for remaining operations
# TODO: check that $1 actually exists
TARGETID=$1
printf -v TARGETCODE "%03d" $TARGETID
CLUSTERNAME="redistrictr-$TARGETCODE"
HOSTFILE="hosts-$TARGETCODE"

CLUSTERCHECK=`starcluster listclusters $CLUSTERNAME 2>&1 | grep "cluster '$CLUSTERNAME' does not exist" | wc -l`

# If a cluster already exists for this target, do not spin up a new one.
# Commented out to test later things on 001
if [ "$CLUSTERCHECK" -eq "0" ]
then
	echo "Cluster $CLUSTERNAME is already running."
	exit
fi

echo "No cluster yet, proceeding."

# Create a new cluster to the specifications
starcluster start -c redistrictr $CLUSTERNAME

# Get all servers for this cluster, to populate hosts file
starcluster listclusters $CLUSTERNAME 2>/dev/null | grep running | awk '{print $1}' > $HOSTFILE
NUMNODES=`wc -l < $HOSTFILE`

# If no nodes were found, clean up and exist with error
if [ "$NUMNODES" -eq "0" ]
then
	echo "ERROR: No nodes created for $CLUSTERNAME."
	rm $HOSTFILE
	exit
fi

echo "Nodes found, proceeding."

# Push code to cluster
starcluster put $CLUSTERNAME -u redistrictr ~/redistrictr/ /home/redistrictr/redistrictr

# Push hosts file to cluster
starcluster put $CLUSTERNAME -u redistrictr ~/$HOSTFILE /home/redistrictr/hosts

echo "Commencing algorithm"

# Run algorithm remotely
starcluster sshmaster $CLUSTERNAME -u redistrictr 'python3 -m scoop --hostfile ~/hosts redistrictr/algorithm/parallelization_testing/one_max_parallel.py'

# Once algorithm is done running, terminate cluster
starcluster terminate $CLUSTERNAME -c
rm $HOSTFILE