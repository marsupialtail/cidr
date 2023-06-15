#!/bin/bash

# AWS configuration
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_DEFAULT_REGION="us-west-2"

# EC2 instance types to launch
#INSTANCE_TYPES=("c6i.2xlarge" "c6id.2xlarge" "c6in.2xlarge" "i4i.2xlarge" "m6idn.2xlarge" "m6i.2xlarge" "m6id.2xlarge" "m6in.2xlarge" "r6i.2xlarge" "r6id.2xlarge" "r6idn.2xlarge" "r6in.2xlarge")
INSTANCE_TYPES=("m6id.2xlarge")

# Path to the Python script file
SCRIPT_FILE_PATH="/Users/EA/Desktop/Quokka_Research/AWS_Instances_Micro_Benchmarks/ipc_benchmark.py"

# Output directory path
OUTPUT_DIRECTORY="/Users/EA/Desktop/Quokka_Research/AWS_Instances_Micro_Benchmarks/ipc_dir/"  # Specify the desired directory path

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIRECTORY"

# Launch instances
INSTANCE_IDS=()
for INSTANCE_TYPE in "${INSTANCE_TYPES[@]}"; do
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "ami-06dc833f6b5200a96" \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "quokka" \
        --security-group-ids "sg-0c188ab7fd279eb06" \
        --user-data file://"$SCRIPT_FILE_PATH" \
        --output text \
        --query 'Instances[0].InstanceId')
    
    INSTANCE_IDS+=("$INSTANCE_ID")
    echo "Instance '$INSTANCE_ID' with type '$INSTANCE_TYPE' launched successfully."
done

# Wait for instances to start
for INSTANCE_ID in "${INSTANCE_IDS[@]}"; do
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
done

# SSH into each instance, execute the script, and capture output
for INSTANCE_ID in "${INSTANCE_IDS[@]}"; do
    INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --output text \
        --query 'Reservations[0].Instances[0].PublicIpAddress')

    # Copy the Python script to the instance
    scp -o StrictHostKeyChecking=no -i "/Users/EA/Desktop/Quokka_Research/quokka.pem" "$SCRIPT_FILE_PATH" "ubuntu@$INSTANCE_PUBLIC_IP:/home/ubuntu/script.py"
    echo "After scp."

    # Execute the Python script remotely and capture the output
    ssh -o StrictHostKeyChecking=no -i "/Users/EA/Desktop/Quokka_Research/quokka.pem" "ubuntu@$INSTANCE_PUBLIC_IP" \
        "python3 /home/ubuntu/script.py" > "$OUTPUT_DIRECTORY/$INSTANCE_ID-output.txt"

    echo "Execution complete on instance '$INSTANCE_ID'."

    # Terminate the instance
    #aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
    #echo "Instance '$INSTANCE_ID' terminated."
done
