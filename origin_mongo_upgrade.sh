#!/bin/bash

# Log commands to stdout
set -o xtrace
# Exit on error
set -o errexit
# Exit on use of unset variables
set -o nounset
# Exit and report on pipe failure
set -o pipefail

# mongo.conf is using the default dbPath: /var/lib/mongodb
# this path is for temporary use by the mongo docker container
mkdir -p /data/db/dump
# see: https://hub.docker.com/_/mongo/ (search for /data/db)
# see: https://github.com/docker-library/mongo/blob/30d09dbd6343d3cbd1bbea2d6afde49f5d9a9295/3.4/Dockerfile#L59
cd /data/db
# our docker host holding the database
mongodump -h $PROD_MONGO_IP

# Get major versions from https://hub.docker.com/r/library/mongo/tags/
step=0
prev_real_major=""
for major_version in 2.6.12 3.0.15 3.2.21 3.4.24 3.6.23 4.0.27 4.2.17 4.4.10 5.0.3; do
    real_major=`echo $major_version | cut -f1,2 -d "."`
    sudo docker stop some-mongo || true
    sudo docker rm some-mongo || true
    docker run --rm -d --name some-mongo -v /data/db:/data/db mongo:$major_version
    set +o errexit
    false; while [[ $? > 0 ]]; do
        sleep 0.5
        docker exec -it some-mongo mongo --eval 'printjson((new Mongo()).getDBNames())'
        if [[ $real_major > 3.3 ]]; then
            docker exec -it some-mongo mongo --eval "db.adminCommand( { setFeatureCompatibilityVersion: \"$real_major\" } )"
        fi
    done
    set -o errexit
    if (( $step == 0 )); then
        docker exec -it some-mongo mongorestore /data/db/dump
    fi
    # upgrade to WiredTiger
    if [[ $real_major == 4.0 ]]; then
        # delete the database dump from earlier
        rm -rf /data/db/dump/
        # dump the database again
        docker exec -w /data/db -it some-mongo mongodump
        # stop the existing mongo container
        docker stop some-mongo
        # delete everything in /data/db except /data/db/dump
        find /data/db -mindepth 1 ! -regex '^/data/db/dump\(/.*\)?' -delete
        # run the 4.0 mongo container again
        docker run --rm -d --name some-mongo -v /data/db:/data/db mongo:$major_version
        # restore the database, which automatically makes it wiretiger.
        docker exec -it some-mongo mongorestore /data/db/dump
    fi
    ((step += 1))
done

# Finish up with docker
sudo rm -rf /data/db/dump/*
docker exec -it some-mongo bash -c 'cd /data/db; mongodump'
docker stop some-mongo

# Commented these out because I did them manually, you decide what you want to do here
# Load upgraded data into latest version of MongoDB (WiredTiger storage engine will be used)
# mongorestore /data/db/dump
# sudo rm -rf /data

