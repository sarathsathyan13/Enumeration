#!/bin/bash

# Check if a domain name is provided as an argument
if [ -z "$1" ]; then
  echo "Invalid Syntax. Please Provide Domain Name."
  echo "Eg: $0 example.com"
  exit 1
fi

word=$1

# Run assetfinder
echo "Starting Assetfinder"
echo "=============="
assetfinder --subs-only "$word" | tee -a domains.txt

# Remove duplicate entries
sort -u domains.txt -o domains.txt

# Check for alive domains
echo "Checking For Alive Domains"
echo "=============="
cat domains.txt | httprobe | tee -a alive.txt

# Remove duplicate and sort
echo "Sorting Domains"
echo "=============="
while read url; do
  echo "${url#*//}" >> alive_subs.txt
done < alive.txt
sort -u alive_subs.txt -o sorted_alive_subs.txt
count=$(wc -l < sorted_alive_subs.txt)

# Execution completed
echo "Script Execution Completed"
echo "Total ${count} Subdomains Found"

# Remove unwanted files
rm domains.txt
rm alive.txt
rm alive_subs.txt
