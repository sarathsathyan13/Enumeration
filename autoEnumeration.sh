#!/bin/bash

word=$1

#argument check
if [[ -z $word ]]; then
	echo "Invalid Syntax.Please Provide Domain Name."
	echo "Eg: $0 example.com"
else

	#running assetfinder
	echo "Starting Assetfinder"
	echo "=============="
	assetfinder --subs-only $1 | tee -a domains.txt

	#removing duplicate entries
	sort -u domains.txt -o domains.txt

	#checking for alive domains
	echo "Checking For Alive Domains"
	echo "=============="
	cat domains.txt | httprobe | tee -a alive.txt

	#removing duplicate and sorting
	echo "Sorting Domains"
	echo "=============="
	while read url; do
		echo ${url#*//} >> alive_subs.txt
	done < alive.txt
	sort -u alive_subs.txt -o sorted_alive_subs.txt
	count=$(cat sorted_alive_subs.txt | wc -l)

	#execution completed
	echo "Script Execution Completed"
	echo "Total ${count} Subdomains Found"

	#remove unwnated files
	rm domains.txt
	rm alive.txt
	rm alive_subs.txt
fi
