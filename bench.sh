#!/bin/bash

sudo apt-get update
sudo apt-get install -y python3-pip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o  awscliv2.zip
sudo ./aws/install
pip3 install --upgrade awscli
pip3 install polars
pip3 install duckdb
pip3 install pyarrow==11.0.0
aws s3 cp s3://yugan/io-micro-1.py .
python3 io-micro-1.py

