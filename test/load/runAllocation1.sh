#!/bin/bash
while true
do
    #make gcloud-auth-cluster 2>/dev/null
    #go run allocationload.go 2>~/Projects/test_results/test_results_2_1.txt
    ./load 2>./test_results_2_1.txt
    # Do this in case you accidentally pass an argument
    # that finishes too quickly.
    sleep 500
done
