#!/bin/bash

AMI_ID="ami-0220d79f3f480ecf5"
ZONE_ID="Z077495923IYBERYWZVDY" # replace with your zone ID
DOMAIN_NAME="devops90s.shop" # replace with your domain name
SG_ID="sg-09fe9d64c7e2f30c4"
for instance in $@
do
    echo "Launching instance: $instance"
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id ami-0220d79f3f480ecf5 \
        --instance-type t3.micro \
        --security-group-ids "$SG_ID" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=roboshop-$instance}]" \
        --query 'Instances[0].InstanceId' \
        --output text
    )
    echo "Instance ID: $INSTANCE_ID"

    if [ $instance == "frontend" ]; then
        IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
         --query 'Reservations[*].Instances[*].PublicIpAddress' \
         --output text
        )
        R53_RECORD="$DOMAIN_NAME"
    else
        IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
         --query 'Reservations[*].Instances[*].PrivateIpAddress' \
         --output text
        )
        R53_RECORD="$instance.$DOMAIN_NAME"
    fi
    
    echo "IP Address: $IP"

    aws route53 change-resource-record-sets \
    --hosted-zone-id $ZONE_ID \
    --change-batch '
    {
        "Comment": "Updating record",
        "Changes": [
            {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "'$RECORD_NAME'",
                "Type": "A",
                "TTL": 1,
                "ResourceRecords": [
                {
                    "Value": "'$IP'"
                }
                ]
            }
            }
        ]
    }
    '
    
done


