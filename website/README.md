# OpenStudio City Database

## Local Development

Install bundler and rails at a command prompt:

```
gem install bundler
gem install rails
```

Download and install [MongoDB](https://www.mongodb.org).  Open a command propmpt and go to the MongoDB bin directory (on Windows this is 'C:\Program Files\MongoDB\Server\3.0\bin').  Start Mongo with the following command 

```
mongod
```

Open a separate console, change directories to the '\openstudio-urban-measures\website\' directory and install the gem dependencies:

```
bundle install
bundle update
```

then start the Rails server

```
bundle exec rails s
```

View the app in your browser at http://localhost:3000

Open a separate console, change directories to the '\openstudio-urban-measures\website\' directory and initialize the database:

```
bundle exec rake db:setup
```

Create the mongo indexes:
```
bundle exec rake db:mongoid:create_indexes
```

then add default data:

```
bundle exec rake testing:batch_upload_features
```

To reset the database at any time use:

```
bundle exec rake db:reset
```

## Deployment with Docker, Docker Machine, and Docker Compose

Docker deployment should be tested locally before deploying in a production environment.

### Docker Installation

* [Install Docker](https://docs.docker.com/installation/)
* [Install Docker-Machine](https://docs.docker.com/machine/install-machine/) (Only if you are not on a Linux machine.)
* [Install Docker-Compose](https://docs.docker.com/compose/install/)

### Create Docker-Machine Image (only on non-linux machines)
The command below will create a 100GB volume for development. This is a very large volume and can be adjusted. Make sure to create a volume greater than 30GB.

```
docker-machine create --virtualbox-disk-size 100000 --virtualbox-cpu-count 4 --virtualbox-memory 4096 -d virtualbox dev
```

### Start Docker-Machine Image (only on non-linux machines)
```
docker-machine start dev  # if not already running
eval $(docker-machine env dev) # this sets up environment variables
```

### Create the data volumes
If you have data volumes (i.e., for mongo and solr), create them:
```
docker run -v /data/db --name <VOLUME NAME> busybox true
```

### Export environment variables
If you have rails environment variables (such as HOST_URL or SECRET_KEY_BASE), don't forget to export them. Example:
```
export HOST_URL=localhost
```

### Run Docker Compose 
```
docker-compose build
```
Be patient.  If the containers build successfully, then start the containers:
``` 
docker-compose up
```

**Note that you may need to build the containers a couple times for everything to converge**

#### You're done!!! ####
Get the Docker IP address (`docker-machine ip dev`) and point your browser at [http://`ip-address`:8000](http://`ip-address`:8000)

To log in to the container:
```
docker-compose run <CONTAINER NAME> bash
```
### Configuration on Production Server
1. Copy supervisor script (from docker/supervisor-citydb.sh) to: /etc/supervisor.d/citydb.conf on the server.

2. Add environment variables (HOST_URL, SECRET_KEY_BASE, etc) to your bash profile on the server.

## Redeployment

These instructions are specific to deployment on the insight center server.

1.  Kill the docker-compose processes (only those related to openstudio-urban-measures)
2.  Update the repo in /dockshare/openstudio-urban-measures
3.  Double check that permissions were maintained (group = dockshare on all updated files)
4.  If there were changes, run 'docker-compose build' from /dockshare/openstudio-urban-measures/website
5.  Run 'nohup docker-compose up &' so that the processes don't terminate when the session ends.
6.  Logs will be in website/nohup.out
        
