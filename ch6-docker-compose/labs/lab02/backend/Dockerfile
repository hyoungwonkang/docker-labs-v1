# 빌드 단계: 소스코드부터 JAR 파일 빌드
FROM eclipse-temurin:17-jdk-jammy as build

WORKDIR /application

# Gradle wrapper와 설정 파일 복사
COPY gradlew ./
COPY gradle gradle
COPY build.gradle settings.gradle ./

# 의존성 다운로드 (캐싱 최적화)
RUN ./gradlew dependencies --no-daemon

# 소스코드 복사
COPY src src

# JAR 파일 빌드
RUN ./gradlew bootJar --no-daemon

# JAR 파일 레이어 추출
RUN java -Djarmode=layertools -jar build/libs/hello-world-v1-0.0.1-SNAPSHOT.jar extract

# 실행 단계: 경량 컨테이너 이미지
FROM eclipse-temurin:17-jre-jammy

WORKDIR /application

# 레이어별로 복사 (Docker 캐싱 최적화)
COPY --from=build application/dependencies/ ./
COPY --from=build application/spring-boot-loader/ ./
COPY --from=build application/snapshot-dependencies/ ./
COPY --from=build application/application/ ./

EXPOSE 8080

ENTRYPOINT [ "java", "org.springframework.boot.loader.launch.JarLauncher" ]