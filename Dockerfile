###
# Build the proven hybrid service
# Extend the payara/micro container to run the hybrid service
###

FROM openjdk:8-jdk-alpine AS alibababuild

RUN apk update \
    && apk upgrade \
    && apk add --no-cache git apache-ant maven\
    && mkdir /build \
    && cd /build \
    && git clone https://bitbucket.org/openrdf/alibaba.git -b '2.0' \
    && cd alibaba  \
    && sed -i 's/javassist.url           = http:/javassist.url           = https:/' dependencies.properties \
    && sed -i 's/slf4j.url               = http:/slf4j.url               = https:/' dependencies.properties \
    && sed -i 's/openrdf-sesame.url      = http:/openrdf-sesame.url      = https:/' dependencies.properties \
    && mvn -Dmaven.test.skip=true source:jar package install \
    && ant build-sdk

FROM openjdk:8-jdk-alpine AS provenbuild
ARG TIMESTAMP

COPY --from=alibababuild /build/alibaba/target/openrdf-alibaba-2.0.jar /root/.m2/repository/org/openrdf/alibaba/alibaba/2.0/alibaba-2.0.jar
RUN echo $TIMESTAMP > /dockerbuildversion.txt \
    && echo $TIMESTAMP \
    && apk update \
    && apk upgrade \
    && apk add --no-cache git \
    && mkdir /build \
    && cd /build \
    && git clone https://github.com/pnnl/proven-message.git -b 'v1.3.1' --single-branch \
    && cd /build/proven-message \
    && git log -1 --pretty=format:"%h" >> /dockerbuildversion.txt \
    && echo ' : proven-message' >> /dockerbuildversion.txt \
    && ./gradlew clean \
    && ./gradlew build \
    && ./gradlew publishToMavenLocal \
    && cd /build \
    && git clone https://github.com/pnnl/proven-cluster.git -b 'v1.3.4' --single-branch \
    && cd /build/proven-cluster/proven-member \
    && git log -1 --pretty=format:"%h" >> /dockerbuildversion.txt \
    && echo ' : proven-cluster' >> /dockerbuildversion.txt \
    && ./gradlew clean \
    && ./gradlew war \
    && ls -l /build/proven-message/build/libs


FROM payara/micro:5.181 

COPY --from=provenbuild /build/proven-message/build/libs/proven-message-0.2-all-in-one.jar /opt/payara/deployments/proven-message-0.2-all-in-one.jar
COPY --from=provenbuild /build/proven-cluster/proven-member/hybrid-service/build/libs/hybrid.war /opt/payara/deployments/hybrid.war
COPY --from=provenbuild /dockerbuildversion.txt /opt/payara/deployments/dockerbuildversion.txt
RUN cat /opt/payara/deployments/dockerbuildversion.txt
USER root
RUN mkdir -p /proven && chown payara:payara /proven
USER payara
VOLUME /proven
ADD proven-system-properties /opt/payara/deployments/proven-system-properties
ADD hazelcast-proven-data.xml /opt/payara/deployments/hazelcast-proven-data.xml
EXPOSE 8080
CMD ["--deploy", "/opt/payara/deployments/hybrid.war", "--hzconfigfile", "/opt/payara/deployments/hazelcast-proven-data.xml", "--systemproperties", "/opt/payara/deployments/proven-system-properties", "--addlibs", "/opt/payara/deployments/proven-message-0.2-all-in-one.jar"]
