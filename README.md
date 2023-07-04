# MetroHero Server

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

7. Build the application
	```bash
	mvn package
	```

8. Edit `target/classes/application.properties` and set the correct Postgres password

9. Symlink the properties and logging configuration files into the root directory of the project - not inside the `target` or nested directories
	```
	ln -s src/main/resources/application.properties .
	ln -s src/main/resources/logback.xml .
	```

10. Run the Spring Boot application targeting the `Application` Java class. This will populate the `metrohero` database. Once the application is running, stop it and continue to the next step to continue setup. See the Usage section of this README if you need help starting the server.

	`mvn spring-boot:run -Dspring-boot.run.jvmArguments="-Xmx8g"`

11. Populate the `station_to_station_travel_time` table in the `metrohero` database
	Before running the sql statements, double-check that the database name (first line of the file) is correct; update if required.
	```bash
	$ sudo su - postgresql
	$ psql -f sql/station_to_station_travel_time.sql
	```

	You should have 28 tables at the end of the table creation:
	```
	metrohero=# \dt
				    List of relations
	 Schema |                    Name                     | Type  |  Owner
	--------+---------------------------------------------+-------+----------
	 public | api_request                                 | table | postgres
	 public | api_user                                    | table | postgres
	 public | daily_service_report                        | table | postgres
	 public | destination_code_mapping                    | table | postgres
	 public | direction_metrics                           | table | postgres
	 public | duplicate_train_event                       | table | postgres
	 public | line_metrics                                | table | postgres
	 public | line_metrics_direction_metrics_by_direction | table | postgres
	 public | rail_incident                               | table | postgres
	 public | speed_restriction                           | table | postgres
	 public | station_problem_tweet                       | table | postgres
	 public | station_tag                                 | table | postgres
	 public | station_to_station_travel_time              | table | postgres
	 public | station_to_station_trip                     | table | postgres
	 public | system_metrics                              | table | postgres
	 public | system_metrics_line_metrics_by_line         | table | postgres
	 public | track_circuit                               | table | postgres
	 public | train_car_problem_tweet                     | table | postgres
	 public | train_departure                             | table | postgres
	 public | train_departure_info                        | table | postgres
	 public | train_disappearance                         | table | postgres
	 public | train_expressed_station_event               | table | postgres
	 public | train_offload                               | table | postgres
	 public | train_prediction_accuracy_measurement       | table | postgres
	 public | train_problem_tweet                         | table | postgres
	 public | train_status                                | table | postgres
	 public | train_tag                                   | table | postgres
	 public | trip_state                                  | table | postgres
	(28 rows)
	```

12. Follow step 1 of the Usage section to populate your WMATA API keys

13. Get an SSL certificate for your installation. MetroHero will require a P12-format file with the private key and the public certificate available to the Java Spring application. This developer prefers LetsEncrypt, doing something like:

	`certbot certonly -d dcmetrohero.net --preferred-challenges dns --manual`

Note, that LetsEncrypt certificates are valid for 90 days and require fairly-frequent renewal.

14. Generate your combined P12 file: `pkcs12 -in /etc/letsencrypt/live/dcmetrohero.net/fullchain.pem -inkey /etc/letsencrypt/live/dcmetrohero.net/privkey.pem -export -out keystore.p12`

15. Launch the server inside `screen` so you can attach to it after-the-fact:
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

## Configuration

Set the length of data to store
* Edit src/main/java/com/jamespizzurro/metrorailserver/repository/TrainStatusRepository.java
* On line 39, set '24 months' to the length of time that you wish to store data for'
