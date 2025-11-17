# 빌드 단계
FROM node:20-alpine as build

WORKDIR /app

# package.json 복사
COPY package.json ./

# package-lock.json이 있으면 복사 (선택적)
COPY package*.json ./

# 의존성 설치
RUN npm install

# 소스코드 복사
COPY . .

# Next.js 애플리케이션 빌드 (정적 export)
RUN npm run build

# 실행 단계
FROM nginx:alpine

# Next.js 정적 빌드 결과물 복사 (out 디렉터리)
COPY --from=build /app/out /usr/share/nginx/html

# nginx 설정 파일 복사
COPY ./nginx/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD [ "nginx", "-g", "daemon off;"]