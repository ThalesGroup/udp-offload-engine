#!/bin/sh

command='''
filter=tb_uoe_*
red=$(tput setaf 1)
blue=$(tput setaf 6)
green=$(tput setaf 2)
reset=$(tput sgr0)

declare -a process

execute_make() {

    cd $dossier
    make start -e GUI=0 > /dev/null && touch "end_$dossier" # start the simulation and create a temporary file to wait for the simulation to finish
    wait # wait until the end of simulation
    printf "%s %s %s\n\n" "───────────────────────────────────────────────────────────────────────" "${blue}$dossier${reset}" "─────────────────────────────────────────────────────────────────────────────"
    cat workspace/log_sim | tail -n 15 # display the last fifteen lines of log_sim
    printf "%s\n\n" ""
    cd ..

}

source .venv/bin/activate # Activate virtual environment
for dossier in $filter; do

    (execute_make $dossier) &
    echo "Simulation launched : $dossier"

done

wait # wait until all simulations have been completed

# Display summary of all simulations

printf "%s\n" "┌────────────────────────────────────────────────────────────┐"
printf "%s\n" "│                     Simulation Results                     │"

i=1

for dossier in $filter; do
    if [ -f "$dossier/end_$dossier" ]; then

        cd $dossier

        line=$(tail -n 14 "workspace/log_sim" | head -n 2)

        if echo "$line" | grep -q "Simulation OK !"; then
            if [ $i == 1 ]; then
                printf "%s\n" "├───────────────────────────────────────────┬────────────────┤"
                i=0
            else
                printf "%s\n" "├───────────────────────────────────────────┼────────────────┤"
            fi
            printf "%-50s %-13s %-21s %s\n" "│  ${blue}$dossier" "${reset}│" "${green}Valid${reset}" '│'
        else
            if [ $i == 1 ]; then
                printf "%s\n" "├───────────────────────────────────────────┬────────────────┤"
                i=0
            else
                printf "%s\n" "├───────────────────────────────────────────┼────────────────┤"
            fi
            printf "%-50s %-13s %-21s %s\n" "│  ${blue}$dossier" "${reset}│" "${red}Error${reset}" '│'
        fi

        cd ..

        rm -f "$dossier/end_$dossier" # remove all temporary files
    fi
done

printf "%s\n" "└───────────────────────────────────────────┴────────────────┘"

deactivate'''

gnome-terminal --maximize -- bash -c "$command; wait; read output"