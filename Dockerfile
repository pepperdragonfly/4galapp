FROM tomcat:9.0-jdk17

# 기본 ROOT 제거(톰캣 기본 페이지 삭제)
RUN rm -rf /usr/local/tomcat/webapps/ROOT

# 네 프로젝트의 정적/웹 자산 복사 (글자·그림 전부 포함)
COPY ./src/main/webapp /usr/local/tomcat/webapps/ROOT

EXPOSE 8080
CMD ["catalina.sh", "run"]
