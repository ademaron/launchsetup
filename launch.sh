#!/bin/bash
declare -a instance_list
mapfile -t instance_list < <(aws ec2 run-instances --image-id $1 --count $2 --instance-type $3 --key-name $4 --security-group-ids $5 --subnet-id $6 --iam-instance-profile Name="$7" --associate-public-ip-address --user-data https://raw.githubusercontent.com/ademaron/environmentsetup/master/install-env.sh --output table | grep InstanceId | sed "s/|//g" | tr -d ' ' | sed "s/InstanceId//g")
echo "Launched" ${instance_list[@]}
aws ec2 wait instance-running --instance-ids ${instance_list[@]}
aws elb create-load-balancer --load-balancer-name itmo444am --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" --subnets $6
aws elb register-instances-with-load-balancer --load-balancer-name itmo444am --instances ${instance_list[@]}
aws elb configure-health-check --load-balancer-name itmo444am --health-check Target=HTTP:80/index.php,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3
aws autoscaling create-launch-configuration --launch-configuration-name launch_web_server --image-id $1 --user-data https://raw.githubusercontent.com/ademaron/environmentsetup/master/install-env.sh --security-group $5 --instance-type $3 --key-name $4 --iam-instance-profile $7 --associate-public-ip-address
aws cloudwatch put-metric-alarm --alarm-name ScaleUp --alarm-description "ScaleUP when CPU >= 30" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 300 --threshold 30 --comparison-operator GreaterThanThreshold --evaluation-periods 2 --unit Percent
aws cloudwatch put-metric-alarm --alarm-name ScaleDown --alarm-description "ScaleDown when CPU <= 10 " --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 300 --threshold 10 --comparison-operator LessThanThreshold --evaluation-periods 2 --unit Percent
aws autoscaling create-auto-scaling-group --auto-scaling-group-name autoscale_web_server --launch-configuration-name launch_web_server --max-size 6 --min-size 3 --desired-capacity 3 --default-cooldown 300 --health-check-type ELB --load-balancer-names itmo444am --vpc-zone-identifier $6 --health-check-grace-period 300
aws rds create-db-instance --db-instance-identifier itmo444am-mysql --allocated-storage 5 --db-instance-class db.m1.small --engine mysql --master-username itmo444am --master-user-password itmo444am-pass --port 3306 --output table
aws rds wait  db-instance-available --db-instance-identifier  itmo444am-mysql
echo "Successfully launched RDS instance!"