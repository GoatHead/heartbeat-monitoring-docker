# API 애플리케이션 컴파일 스테이지
FROM golang:1.15.6-alpine AS backend-stage

COPY ./heartbeat-monitoring-backend /tmp/backend

WORKDIR /tmp/backend

# https://github.com/padthaitofuhot/apkfastestmirror << 가장 빠른 미러 검색
RUN wget https://raw.githubusercontent.com/padthaitofuhot/apkfastestmirror/master/apkfastestmirror.sh && \
        ash ./apkfastestmirror.sh --install && \
        ash ./apkfastestmirror.sh --replace && \
        apk add --no-cache gcc musl-dev && \
        go get && CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -a -ldflags '-s' -o api_server main.go

# 프론트엔드 빌드 스테이지
FROM node:14.15.3 AS frontend-stage

COPY ./heartbeat-monitoring-frontend /tmp/frontend

WORKDIR /tmp/frontend
RUN yarn
RUN yarn run build

# alpine + nginx. 프로덕션 스테이지
FROM nginx:1.13.12-alpine

RUN apk --update upgrade && \
    apk add --update bash && \
    apk --no-cache add tzdata && \
        cp /usr/share/zoneinfo/Asia/Seoul /etc/localtime && \
        echo "Asia/Seoul" > /etc/timezone && \
        rm -rf /var/cache/apk/*

COPY ./run.sh /apps/

RUN mkdir -p /apps/app && \
    mkdir -p /apps/api && \
    mkdir -p /apps/db && \
    rm -f /etc/nginx/conf.d/default.conf && \
    chmod 755 /apps/run.sh

COPY ./default.conf /etc/nginx/conf.d/

COPY --from=backend-stage /tmp/backend/api_server /apps/api/
COPY --from=frontend-stage /tmp/frontend/dist/bundle.js /apps/app/
COPY --from=frontend-stage /tmp/frontend/dist/index.html /apps/app/

EXPOSE 80

CMD ["/apps/run.sh"]