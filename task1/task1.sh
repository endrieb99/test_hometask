#!/usr/bin/env bash

set -euo pipefail

# Array of numbers 1 to 10
numbers=(1 2 3 4 5 6 7 8 9 10)

#Check the array
check_array() {
    local len=${#numbers[@]}
    # Check if the array contains 10 elements
    if [[ "$len" -ne 10 ]]; then
        echo "Error: The array must contain 10 numbers, got $len." >&2
        return 1
    fi

    #Check if all the elements are integers between 1 and 10
    for num in "${numbers[@]}"; do
        if ! [[ "$num" =~ ^[1-9]$|^10$ ]]; then
            echo "Error: Elements in the array are not integers from 1 to 10. They must be between 1 and 10, got: $num" >&2
            return 1
        fi
    done

    # Check for duplicates elements in the array
    local sorted=($(printf "%s\n" "${numbers[@]}" | sort -n))
    for ((i = 1; i < len; i++)); do
    if [[ "${sorted[i]}" -eq "${sorted[i - 1]}" ]]; then
        echo "Error: Duplicate value '${sorted[i]}' found in the array." >&2
        return 1
    fi
done
}

# Fisher-Yates shuffle
shuffle() {
    local len=${#numbers[@]}
    for ((i = len - 1; i > 0; i--)); do
        # Generate random index between 0 and i
        local j=$((RANDOM % (i + 1)))
        # Swap
        local temp=${numbers[i]}
        numbers[i]=${numbers[j]}
        numbers[j]=$temp
    done
}

# Main execution
main() {
    check_array
    shuffle
    for num in "${numbers[@]}"; do
        echo "$num"
    done
}

# Run main if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main
fi