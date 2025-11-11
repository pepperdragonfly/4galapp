FROM tomcat:9.0-jdk17

RUN rm -rf /usr/local/tomcat/webapps/ROOT
COPY ./src/main/webapp /usr/local/tomcat/webapps/ROOT
