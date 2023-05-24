# Run tests

`./gradlew test`

# Run the application

## With gradle

`./gradlew run`

## Build fat JAR and run it

`./gradlew buildFatJar`

`java -jar build/libs/vocab-all.jar`

## With Docker

Create a Docker image: `docker build -t vocab-app .`

Run it: `docker run -p 8080:8080 vocab-app`