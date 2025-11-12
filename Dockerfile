FROM tomcat:9.0-jdk17

ARG BUILD_TS=dev
ENV BUILD_TS=$BUILD_TS

# 기본 ROOT 제거 후 우리 웹앱 복사
RUN rm -rf /usr/local/tomcat/webapps/ROOT
COPY ./src/main/webapp /usr/local/tomcat/webapps/ROOT
