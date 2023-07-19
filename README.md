# MetroHero Server

## Local Development Environment Setup

The setup instructions below assume that docker or docker desktop have already been installed and configured on your machine. Starting in the metrohero-server directory...

1. Follow instruction is Usage notes 1 to obtain WMATA keys.

2. Add WMATA keys to the application-dev.properties file, replacing the "\<populate\>" 

3. Build the spring boot jar file:
	```
	mvn clean package
	```

4. Build the spring boot docker image:
	```
	docker build --tag=metrorailserver:1.0-SNAPSHOT .
	```

5. Spin up the spring boot image and postgres with docker compose:
	```
	docker compose up
	```

6. Once postgres and spring boot have started, open another terminal and populate the station_to_station_travel_time table in postgres:
	```
	docker exec -it metrohero-server-db-1 bash -c "psql -U postgres -d metrohero -f ./home/station_to_station_travel_time.sql"
	```

7. Once step 4 is complete, restart docker compose to ensure changes are picked up:
	```
	docker compose restart
	```

Your local development metrohero server is now up and running. Debugging can be attached using port 5005. Usage notes 1, 2, 3, and 7 below still apply.

To connect a front-end for development, follow the instructions in the metrohero-webapp repository.

To apply new changes to the docker image run the following commands

1. Bring docker compose down:
	```
	docker compose down
	```

2. Build the spring boot jar file:
	```
	mvn clean package
	```

3. Build the spring boot docker image:
	```
	docker build --tag=metrorailserver:1.0-SNAPSHOT .
	```

4. Spin up the spring boot image and postgres with docker compose:
	```
	docker compose up
	```

## Server Setup

The setup instructions below are for Ubuntu 16.04. They may work for newer versions of Ubuntu or other Debian-based distros too, but some modifications of the commands provided may be required. YMMV.

1. Install Java 17 JRE:
	```
	sudo apt install openjdk-17-jre-headless
	```

2. Set the server timezone. The local server timezone will be used to calculate upcoming train departure times, so is important to set properly.
	```bash
	timedatectl set-timezone America/New_York
	```
   
3. Install PostgreSQL 10:
	```
	sudo add-apt-repository 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main'
	wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
	sudo apt update
	# NOTE: postgresql 10 specifically, and not a newer version, is currently a requirement
	sudo apt install postgresql-10
	```

4. Set `postgres` user's password to `postgres`:
    ```
    sudo su - postgres
    psql
    \password
    ```

5. Create a new, empty `metrohero` database:
    ```
    sudo su - postgres
    createdb metrohero
    ```

6. Create and load custom PostgreSQL routines:
    ```
    sudo su - postgres
    psql -f sql/sql_routines.sql
    ```

7. Edit `classes/application.properties` and set the correct Postgres password

8. Symlink the properties and logging configuration files into the root directory of the project
	```
	ln -s classes/application.properties .
	ln -s classes/logback.xml .
	```

7. Run the Spring Boot application targeting the `Application` Java class. This will populate the `metrohero` database. Once the application is running, stop it and continue to the next step to continue setup. See the Usage section of this README if you need help starting the server.

8. Populate the `station_to_station_travel_time` table in the `metrohero` database
	```bash
	$ sudo su - postgresql
	$ psql -f sql/station_to_station_travel_time.sql
	```

9. Run any additional numbered scripts in the `sql` directory, in the order they are numbered.

10. Follow step 1 of the Usage section to populate your WMATA API keys

11. Get an SSL certificate for your installation. MetroHero will require a P12-format file with the private key and the public certificate available to the Java Spring application. This developer prefers LetsEncrypt, doing something like:

	`certbot certonly -d dcmetrohero.net --preferred-challenges dns --manual`

Note, that LetsEncrypt certificates are valid for 90 days and require fairly-frequent renewal.

12. Generate your combined P12 file: `pkcs12 -in /etc/letsencrypt/live/dcmetrohero.net/fullchain.pem -inkey /etc/letsencrypt/live/dcmetrohero.net/privkey.pem -export -out keystore.p12`

13. Launch the server inside `screen` so you can attach to it after-the-fact:
	```screen -U
	 mvn spring-boot:run -Dspring-boot.run.jvmArguments="-Xmx8g"
	```

## Usage

1. Replace the values for the `wmata.production.apikey` and `wmata.development.apikey` properties in src/main/resources/application.properties with your own API keys from WMATA. If you're already logged into developer.wmata.com, [click here](https://developer.wmata.com/developer), then copy the value for your "Primary key" into `wmata.production.apikey` and your "Secondary key" into `wmata.development.apikey`. If you have not yet been issued API keys from WMATA, [start here](https://developer.wmata.com/signup).
2. If you want any of the features powered by Twitter to work, replace the values for the `oauth.consumerKey`, `oauth.consumerSecret`, `oauth.accessToken`, and `oauth.accessTokenSecret` properties in src/main/resources/twitter4j.properties with your own credentials from Twitter. If you're already logged into developer.twitter.com and already have already created a Standalone App, go to the 'Keys and tokens' section of that app to generate an access token and secret. If you have not yet created a Twitter Developer account, [start here](https://developer.twitter.com/en/portal/petition/essential/basic-info).
3. The server is configured for debug mode by default. You can control this with the `developmentmode` property in src/main/resources/application.properties. Stay in this mode during development, and toggle it off in your production environment.
4. You should probably replace the self-signed cert `metrohero.jks` located in the root project directory with an actual cert from an actual authority. The provided self-signed cert should be sufficient for development purposes if you ignore any SSL warnings from your browser when trying to actually connect to the server, but it is not appropriate to use in production. A website like [SSL for Free](https://www.sslforfree.com/) might be a good place to start.
5. If you're using IntelliJ or another fully-featured IDE, you can use the autoconfigured Spring configuration (targeting the `Application` Java class) to start the server for development purposes, otherwise you can use `sudo mvn spring-boot:run -Dspring-boot.run.jvmArguments="-Xmx16g"`, e.g. in a production environment.
6. If you're running the server locally, navigate to https://localhost:9443/ to start using the webapp with it connected to your server.
7. If the logs are a little too noisy for your use case, e.g. in production, consider setting the `logging.level.com.jamespizzurro.metrorailserver` property in src/main/resources/application.properties to WARN instead of INFO, or set it to DEBUG to get even more log output for debugging purposes.

## Adding a new infill station
When adding a new infill Metrorail station, such as Potomac Yard, there are a number of files that need to be updated.

Beginning with the Webapp frontend:
* Use [Rail Station Information](https://api.wmata.com/Rail.svc/json/jStationInfo?StationCode=C11) API endpoint in order to grab the info block about the new station(s). This will include Lat/Long, address, and other information needed for MetroHero.
* `src/{blue,yellow,silver,red,green,orange}_stations.json`
	* Edit the relevant file(s). If a station is used by multiple lines, all files should be updated
	* Use the WMATA Rail Station Information API endpoint to populate this
* src/components/Line.js
	* For an infill station, the station links on either side may need to be updated; for instance, links from C10 to C12 need to be split and modified so C10-C11 and C11-C12, rather than C10-C12, for a C11 infill station
* src/stores/LineStore.js
* src/stores/MareyDiagramStore.js

Server repo:
* src/main/resources/stations.csv
	* Add the new station to the list, along with names that the station is referenced as
* src/main/resources/StandardRoutes.json
  * For each station platform track circuit, set the station code (i.e. "C11") to associate the two
* src/main/resources/station_durations.csv
  * Use [WMATA Trip Planner](https://wmata.com) to determine the time in minutes between the new station and its left and right pairs. Insert this, using the station codes as columns 1 and 2, as the 3rd column

## Station location track circuits
(Look for the track circuits of 600' length)

* C10-C1: 1010
* C11-C1: 3493
* C12-C1: 976

* C10-C2: 1204
* C11-C2: 3512
* C12-C2: 1170

## Configure length of train tracking history
By default, MetroHero will attmept to store up to 24 months of historical train location data. This configuration can be found in `src/main/java/com/jamespizzurro/metrorailserver/repository/TrainStatusRepository.java`, and adjusted up or down as appropriate for your environment. A lower history setting is likely more appropriate for a dev, rather than a production, environment.
