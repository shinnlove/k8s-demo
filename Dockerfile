From java:8

MAINTAINER Tony Zhao

ADD springbootdemo-0.0.1-SNAPSHOT.jar springboot.jar

ENV JAVA_VERSION 1.8.0_206u_openjdk_amd64

EXPOSE 8080

RUN ["/bin/bash", "-c", "echo $JAVA_VERSION >> hahaha.txt"]

ENTRYPOINT ["java", "-jar", "./springboot.jar"]

