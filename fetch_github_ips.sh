#!/bin/bash

# Fetch the GitHub IP addresses
response=$(curl -s https://api.github.com/meta)

# Extract the hook IP addresses
hook_ips=$(echo $response | jq -c '.hooks[]')

# Initialize an empty JSON object
json_output="{"

# Loop through the IPs and add them to the JSON object with a unique key
counter=1
for ip in $hook_ips; do
  # Remove quotes from IP string
  ip=$(echo $ip | tr -d '"')
  json_output+="\"ip$counter\": \"$ip\","
  ((counter++))
done

# Remove the trailing comma and close the JSON object
json_output="${json_output%,}}"

# Output the JSON object
echo $json_output
