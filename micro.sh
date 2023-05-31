#!/bin/bash

# Launch EC2 instance
instance_type="t2.micro"
image_id="ami-xxxxxxxx"  # Replace with desired AMI ID
key_name="my-key-pair"   # Replace with your key pair name
security_group_id="sg-xxxxxxxx"  # Replace with your security group ID
subnet_id="subnet-xxxxxxxx"  # Replace with your subnet ID

instance_id=$(aws ec2 run-instances --instance-type "$instance_type" --image-id "$image_id" --key-name "$key_name" --security-group-ids "$security_group_id" --subnet-id "$subnet_id" --query 'Instances[0].InstanceId' --output text)

echo "Instance launched with ID: $instance_id"

# Wait for the instance to be running
aws ec2 wait instance-running --instance-ids "$instance_id"

# Retrieve public IP address
public_ip=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "Public IP address: $public_ip"

# Upload script to instance
script_path="/path/to/script.sh"  # Replace with the path to your script file
remote_path="/home/ec2-user/script.sh"  # Replace with the desired remote path on the instance

aws s3 cp "$script_path" "s3://your-bucket/script.sh"

aws s3api wait object-exists --bucket your-bucket --key script.sh

# Run script on instance and print output
ssh -i /path/to/key.pem ec2-user@"$public_ip" "$remote_path"

# Terminate instance
aws ec2 terminate-instances --instance-ids "$instance_id"

echo "Instance terminated"
