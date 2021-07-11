#! /usr/local/bin/zsh


# Convert an earth date into Golarion format (add 2700 years and 
# rename months according to the appropriate deities).
# 
# Uses the current system date if called without an argument.
# To convert specific dates, call this script with that date in
# ISO 8601 format as argument (i. e. ./golariondate 2021-07-31).

if [ "$#" -eq 0 ]
then
	DATE=$(date +"%Y-%m-%d")
else
	DATE=$(date -j -f "%Y-%m-%d" "$@" +"%Y-%m-%d") 
fi

MO=$(date -j -f "%Y-%m-%d" "$DATE" +"%m")

case $MO in
	01) MO=Abadius;;
	02) MO=Calistril;;
	03) MO=Pharast;;
	04) MO=Gozran;;
	05) MO=Desnus;;
	06) MO=Sarenith;;
	07) MO=Erastus;;
	08) MO=Arodus;;
	09) MO=Rova;;
	10) MO=Lamashan;;
	11) MO=Neth;;
	12) MO=Kuthona;;
esac

(( YE=$(date -j -f "%Y-%m-%d" "$DATE" "+%Y") + 2700 ))

echo "$(date -j -f "%Y-%m-%d" "$DATE" "+%d") $MO $YE AR"
