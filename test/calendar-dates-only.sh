#!/bin/bash

set -e
set -o pipefail
cd "$(dirname $0)"
set -x

env | grep '^PG' || true

psql -c 'create database calendar_dates_only'
export PGDATABASE='calendar_dates_only'

../cli.js -d --trips-without-shape-id -- \
	calendar-dates-only/*.txt \
	| sponge | psql -b

query=$(cat << EOF
select extract(epoch from t_arrival)::integer as t_arrival
from arrivals_departures
where stop_id = 'museum'
order by t_arrival
EOF)

# 2019-07-15T15:30:00+02:00
arr1=$(psql --csv -t -c "$query" | head -n 1)
if [[ "$arr1" != "1563197400" ]]; then
	echo "invalid 1st t_arrival: $arr1" 1>&2
	exit 1
fi

# 2019-07-20T15:30:00+02:00
arrN=$(psql --csv -t -c "$query" | tail -n 1)
if [[ "$arrN" != "1563629400" ]]; then
	echo "invalid 2nd t_arrival: $arrN" 1>&2
	exit 1
fi

agency_id_null=$(cat << EOF
select count(*)
from arrivals_departures
where agency_id IS NULL
EOF)
agency_id_null_count="$(psql --csv -t -c "$agency_id_null")"
if [[ "$agency_id_null_count" != "0" ]]; then
	echo ">0 rows with agency_id = null" 1>&2
	exit 1
fi
