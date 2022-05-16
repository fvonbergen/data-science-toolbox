#!/bin/bash

# Prints error message
error () {
    echo >&2 "$@"
}

# Validates the fill character parameter.
validate_fill_char_param(){
    local FILL_CHAR="$1"
    if [ "${#FILL_CHAR}" -ne 1 ];
    then
        error "fill character argument must be a single character, \"${FILL_CHAR}\" provided"
        return 1
    fi
}

# Prints message in the middle of the terminal and fills remaining space with the provided fill character
print_msg(){
    # First parameter: message.
    # Message that will be printed in the middle of the terminal.
    local MSG="$1"
    # Second parameter: fill character.
    # Characters that will fill the line.
    local FILL_CHAR=${2:-" "}
    if ! (validate_fill_char_param "${FILL_CHAR}");
    then
        return 1
    fi
    local SHELL_COLUMNS=$( eval tput cols)
    local MSG_LENGTH=${#MSG}
    local MSG_START=$(((SHELL_COLUMNS - MSG_LENGTH) / 2))
    local MSG_PRINTED=False
    local i=1
    while [ ${i} -le ${SHELL_COLUMNS} ]
    do
        if [ ${MSG_PRINTED} = False ] && [ "${i}" -gt "${MSG_START}" ];
        then
            echo -n "${MSG}"
            local MSG_PRINTED=True
            local i=$((i + MSG_LENGTH))
        else
            echo -n "${FILL_CHAR}"
            local i=$((i + 1))
        fi
    done
    echo ""
}
