# #!/bin/bash

# AMI_ID="ami-0220d79f3f480ecf5"
# ZONE_ID="Z077495923IYBERYWZVDY" # replace with your zone ID
# DOMAIN_NAME="devops90s.shop" # replace with your domain name

# for instance in $@
# do
#     echo "Launching instance: $instance"
#     INSTANCE_ID=$(aws ec2 run-instances \
#         --image-id ami-0220d79f3f480ecf5 \
#         --instance-type t3.micro \
#         --security-groups "roboshop-common" "roboshop-$instance" \
#         --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=roboshop-$instance}]" \
#         --query 'Instances[0].InstanceId' \
#         --output text
#     )
#     echo "Instance ID: $INSTANCE_ID"

#     if [ $instance == "frontend" ]; then
#         IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
#          --query 'Reservations[*].Instances[*].PublicIpAddress' \
#          --output text
#         )
#         R53_RECORD="$DOMAIN_NAME"
#     else
#         IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
#          --query 'Reservations[*].Instances[*].PrivateIpAddress' \
#          --output text
#         )
#         R53_RECORD="$instance.$DOMAIN_NAME"
#     fi
    
#     #### Updating R53 Record ####
#     aws route53 change-resource-record-sets \
#     --hosted-zone-id $ZONE_ID \
#     --change-batch '
#         {
#             "Comment": "Update A record to new IP",
#             "Changes": [
#                 {
#                     "Action": "UPSERT",
#                     "ResourceRecordSet": {
#                         "Name": "'$R53_RECORD'",
#                         "Type": "A",
#                         "TTL": 1,
#                         "ResourceRecords": [
#                             {
#                                 "Value": "'$IP'"
#                             }
#                         ]
#                     }
#                 }
#             ]
#         }
#     '

# done
 ```bash
#!/bin/bash

AMI_ID="ami-0220d79f3f480ecf5"
ZONE_ID="Z077495923IYBERYWZVDY"
DOMAIN_NAME="devops90s.shop"
REGION="us-east-1"

COMMON_SG_ID="sg-09fe9d64c7e2f30c4"

for instance in "$@"
do
    echo "Launching instance: $instance"

    # Get the component-specific Security Group ID
    COMPONENT_SG_ID=$(aws ec2 describe-security-groups \
        --region "$REGION" \
        --filters "Name=group-name,Values=roboshop-$instance" \
        --query 'SecurityGroups[0].GroupId' \
        --output text)

    # Validate Security Group
    if [ -z "$COMPONENT_SG_ID" ] || [ "$COMPONENT_SG_ID" = "None" ]; then
        echo "ERROR: Security Group roboshop-$instance not found"
        exit 1
    fi

    echo "Common Security Group: $COMMON_SG_ID"
    echo "Component Security Group: $COMPONENT_SG_ID"

    # Launch EC2 instance
    INSTANCE_ID=$(aws ec2 run-instances \
        --region "$REGION" \
        --image-id "$AMI_ID" \
        --instance-type t3.micro \
        --security-group-ids "$COMMON_SG_ID" "$COMPONENT_SG_ID" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=roboshop-$instance}]" \
        --query 'Instances[0].InstanceId' \
        --output text)

    # Stop if instance creation fails
    if [ $? -ne 0 ] || [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
        echo "ERROR: Failed to launch $instance"
        exit 1
    fi

    echo "Instance ID: $INSTANCE_ID"

    # Wait until the instance is running
    aws ec2 wait instance-running \
        --region "$REGION" \
        --instance-ids "$INSTANCE_ID"

    # Get the appropriate IP address
    if [ "$instance" = "frontend" ]; then
        IP=$(aws ec2 describe-instances \
            --region "$REGION" \
            --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)

        R53_RECORD="$DOMAIN_NAME"
    else
        IP=$(aws ec2 describe-instances \
            --region "$REGION" \
            --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].PrivateIpAddress' \
            --output text)

        R53_RECORD="$instance.$DOMAIN_NAME"
    fi

    if [ -z "$IP" ] || [ "$IP" = "None" ]; then
        echo "ERROR: Could not retrieve IP address for $instance"
        exit 1
    fi

    echo "Instance IP: $IP"
    echo "Updating Route 53 record: $R53_RECORD"

    # Update Route 53 DNS record
    aws route53 change-resource-record-sets \
        --hosted-zone-id "$ZONE_ID" \
        --change-batch "{
            \"Comment\": \"Update A record to new IP\",
            \"Changes\": [
                {
                    \"Action\": \"UPSERT\",
                    \"ResourceRecordSet\": {
                        \"Name\": \"$R53_RECORD\",
                        \"Type\": \"A\",
                        \"TTL\": 60,
                        \"ResourceRecords\": [
                            {
                                \"Value\": \"$IP\"
                            }
                        ]
                    }
                }
            ]
        }"

    if [ $? -ne 0 ]; then
        echo "ERROR: Route 53 update failed for $R53_RECORD"
        exit 1
    fi

    echo "SUCCESS: $instance launched and DNS update submitted"
done
```
