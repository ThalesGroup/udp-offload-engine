#!/bin/sh

clear

#==========================
#		Reset File
#==========================

if [[ -f "_temp2_.txt" ]]
then
	rm _temp2_.txt
fi
touch _temp2_.txt
if [[ -f "common.mk" ]]
then
	rm common.mk
fi

#==========================
#	Library research
#==========================
NB_FILE=$(ls -l | egrep .vhd | wc -l)
files=(*.vhd)

for ((j=1; j<$NB_FILE; j++))
do
	k=1
	egrep common.*_pkg "${files[$j]}" > _temp_.txt
	LIGNE=$(wc -l _temp_.txt | egrep [0-9]+ | cut -d " " -f1)
	
	for (( i=1; i<=$LIGNE; i++ ))
	do
		PKG=$(cat "${files[$j]}" | egrep common.*_pkg | head -n "$i" | tail -n 1 | cut -d . -f2)
		if [[ "$i" == '1' ]]
		then
			echo "$i=$PKG" >> _temp2_.txt
			PKG2=$PKG
			k=2
		else
			if [[ $PKG2 != $PKG ]]
			then
				echo "$k=$PKG" >> _temp2_.txt
				PKG2=$PKG
				k=$(($k+1))
			fi
		fi
	done
	if [[ "${files[$j]}" =~ "_pkg" ]]
	then
		echo "$k=${files[$j]}" | cut -d . -f1 >> _temp2_.txt
	fi
done

sort _temp2_.txt | uniq > _temp_.txt

LIGNE=$(wc -l _temp_.txt | egrep [0-9]+ | cut -d " " -f1)
i=1

while [[ $i<=$LIGNE ]]
do
	FLAG=1
	NAME_LIB=$(cat _temp_.txt | head -n "$i" | tail -n 1 | cut -d = -f2)
	for ((j=1; j<=$LIGNE; j++))
	do
		if [[ $NAME_LIB == $(cat _temp_.txt | head -n "$j" | tail -n 1 | cut -d = -f2) ]]
		then
			if [[ $i != $j ]]
			then
				NAME_SUPPR=$i"d"
				sed -i "$NAME_SUPPR" _temp_.txt
				LIGNE=$(($LIGNE-1))
				FLAG=0
				break
			fi
		fi	
	done
	if [ $FLAG == '1' ]
	then
		i=$(($i+1))
	fi
done

echo 'VHDL_LIB_ORDER += common' >> common.mk

LIGNE=$(wc -l _temp_.txt | egrep [0-9]+ | cut -d " " -f1)
for ((i=1; i<=$LIGNE; i++))
do
	VAR=$(cat _temp_.txt | head -n "$i" | tail -n 1 | cut -d = -f2)
	CMD='VHDL_SOURCES_common += $(PWD)/../../src/common/'$VAR'.vhd' 
	echo "$CMD" >> common.mk
done
echo 'VHDL_SOURCES_common += $(PWD)/../../src/common/*.vhd' >> common.mk

#==========================
#	Remove Tempory file
#==========================

rm _temp_.txt
rm _temp2_.txt

clear
