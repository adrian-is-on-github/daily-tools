#!/bin/bash

##########################################################################################
### Script to check uptimerobot statuses so you don't need to go to their ugly website ###
##########################################################################################

### Edit the sections:
# Color coding based on downtime percentage for 3 day
# Color coding based on downtime percentage for 7 day
### ...to update your colour thresholds

API_KEY="<<<yourApiKeyHere>>>"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
URL="https://api.uptimerobot.com/v2/getMonitors"

# Get the current time and calculate time 3 and 7 days ago (in seconds since the epoch)
current_time=$(date +%s)
three_days_ago=$((current_time - 3*24*60*60))
seven_days_ago=$((current_time - 7*24*60*60))

# Paginating the requests, 50 at a time otherwise you'll only get one page
total_monitors=0
offset=0

echo ""
echo "--------------------------------------------------"
echo "- Checking uptimerobot at/on $TIMESTAMP -"
echo "--------------------------------------------------"
echo ""

# Initialize counters
red_count=0
yellow_count=0
green_count=0
non_zero_two_status_count=0

while true; do
    # Make API request with offset
    response=$(curl -s -X POST "$URL" -d "api_key=$API_KEY&format=json&logs=1&offset=$offset")

    # Check if request was successful
    if ! echo "$response" | jq -e .stat | grep -q "ok"; then
        echo "Failed to retrieve monitor data."
        exit 1
    fi

    # Parse and display monitor details
    monitor_count=$(echo "$response" | jq '.monitors | length')
    total_monitors=$((total_monitors + monitor_count))

    # If no monitors are returned, break out of the loop
    if [ "$monitor_count" -eq 0 ]; then
        break
    fi

    for ((i=0; i<$monitor_count; i++)); do
        name=$(echo "$response" | jq -r ".monitors[$i].friendly_name")
        status=$(echo "$response" | jq -r ".monitors[$i].status")

        # If status is not 0 or 2, make the text red
        if [[ "$status" != "0" && "$status" != "2" ]]; then
            status_color="\033[31m"  # Red
        else
            status_color="\033[32m"  # Default
        fi

        # Calculate downtime in last 3 days
        three_day_downtime=$(echo "$response" | jq "[.monitors[$i].logs[] | select(.datetime > $three_days_ago and .type == 1)] | length")
        three_day_downtime_percentage=$(bc <<< "scale=4; ($three_day_downtime * 60) / (3*24*60)")

        # Calculate downtime in last 7 days
        seven_day_downtime=$(echo "$response" | jq "[.monitors[$i].logs[] | select(.datetime > $seven_days_ago and .type == 1)] | length")
        seven_day_downtime_percentage=$(bc <<< "scale=4; ($seven_day_downtime * 60) / (7*24*60)")

        # Color coding based on downtime percentage for 3 day
        if (( $(echo "$three_day_downtime_percentage >= .3471" | bc -l) )); then # 15 minutes or greater
            color_3_day="\033[31m"  # Red
        elif (( $(echo "$three_day_downtime_percentage >= 0.1157" | bc -l) )); then # 5 minutes or greater
            color_3_day="\033[33m"  # Yellow
        else
            color_3_day="\033[32m"  # Green
        fi

        # Color coding based on downtime percentage for 7 day
        if (( $(echo "$seven_day_downtime_percentage >= .1488" | bc -l) )); then # 15 minutes or greater
            color_7_day="\033[31m"  # Red
        elif (( $(echo "$seven_day_downtime_percentage >= 0.0496" | bc -l) )); then # 5 minutes or greater
            color_7_day="\033[33m"  # Yellow
        else
            color_7_day="\033[32m"  # Green
        fi

        # Increment counters based on conditions
        if [[ "$status" != "0" && "$status" != "2" ]]; then
            non_zero_two_status_count=$((non_zero_two_status_count + 1))
        fi

        if (( $(echo "$three_day_downtime_percentage >= .3471" | bc -l) )) || (( $(echo "$seven_day_downtime_percentage >= .1488" | bc -l) )); then
            red_count=$((red_count + 1))
        elif (( $(echo "$three_day_downtime_percentage >= 0.1157" | bc -l) )) || (( $(echo "$seven_day_downtime_percentage >= 0.0496" | bc -l) )); then
            yellow_count=$((yellow_count + 1))
        else
            green_count=$((green_count + 1))
        fi

        # Display the results
        echo -e "Monitor Name: $name | ${status_color}Status: $status\033[0m"
        echo -e "Downtime in last 3/7 days: ${color_3_day}$three_day_downtime_percentage% \033[0m""/ ${color_7_day}$seven_day_downtime_percentage% \033[0m"
        echo "--------------------------------------"
    done
    offset=$((offset + 50))
done

# Display total number of monitors
echo ""
echo "-------------------------------------------------------------"
echo "- Total monitors    : $total_monitors returned on/at $TIMESTAMP -"

# Check each count and display with color if > 0
if [ "$red_count" -gt 0 ]; then
    echo -e "- Red monitors      : \033[31m$red_count\033[0m"
else
    echo "- Red monitors      : $red_count"
fi

if [ "$yellow_count" -gt 0 ]; then
    echo -e "- Yellow monitors   : \033[33m$yellow_count\033[0m"
else
    echo "- Yellow monitors   : $yellow_count"
fi

if [ "$green_count" -gt 0 ]; then
    echo -e "- Green monitors    : \033[32m$green_count\033[0m"
else
    echo "- Green monitors    : $green_count"
fi

if [ "$non_zero_two_status_count" -gt 0 ]; then
    echo -e "- Status not 0 or 2 : \033[31m$non_zero_two_status_count\033[0m"
else
    echo "- Status not 0 or 2 : $non_zero_two_status_count"
fi
echo "-------------------------------------------------------------"
echo ""