#!/bin/bash

aws ec2 run-instances --image-id $1 --count $2 
--instance-type $3 --key-name itmo444-ade-fall2015-thisone 
--security-group-ids $4 --subnet-id $5 
