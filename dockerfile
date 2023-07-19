FROM eclipse-temurin:17-jre-alpine
RUN apk add --no-cache tzdata
ENV TZ=America/New_York
RUN cp /usr/share/zoneinfo/America/New_York /etc/localtime
COPY target/metrorailserver-1.0-SNAPSHOT.jar metrorailserver-1.0-SNAPSHOT.jar
COPY ./metrohero.p12 metrohero.p12
ENTRYPOINT ["java","-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=0.0.0.0:5005","-jar","/metrorailserver-1.0-SNAPSHOT.jar"]


