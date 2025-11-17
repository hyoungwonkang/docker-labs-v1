# build : Spring boot jar 추출

FROM eclipse-temurin:17-jdk-jammy as build

WORKDIR /application

ARG JAR_FILE=build/libs/hello-world-v1-0.0.1-SNAPSHOT.jar

COPY ${JAR_FILE} application.jar

RUN java -Djarmode=layertools -jar application.jar extract

# 실행 단계 : 경량 컨테이너 이미지

FROM eclipse-temurin:17-jdk-jammy

WORKDIR /application

COPY --from=build application/dependencies/ ./
COPY --from=build application/spring-boot-loader/ ./
COPY --from=build application/snapshot-dependencies/ ./
COPY --from=build application/application/ ./

ENTRYPOINT [ "java", "org.springframework.boot.loader.JarLauncher" ]