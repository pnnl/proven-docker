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

COPY --from=alibababuild /build/alibaba/target/openrdf-alibaba-2.0.jar /root/.m2/repository/org/openrdf/alibaba/alibaba/2.0/alibaba-2.0.jar
#ADD ./proven-dependencies/alibaba-2.0.jar /root/.m2/repository/org/openrdf/alibaba/alibaba/2.0/alibaba-2.0.jar
RUN apk update \
    && apk upgrade \
    && apk add --no-cache git \
    && mkdir /build \
    && cd /build \
    && git clone https://github.com/pnnl/proven-message.git -b master --single-branch \
    && cd /build/proven-message \
    && ./gradlew clean \
    && ./gradlew publishToMavenLocal \
    && cd /build \
    && git clone https://github.com/pnnl/proven-cluster.git -b master --single-branch \
    && cd /build/proven-cluster/proven-member \
    && ./gradlew clean \
    && ./gradlew war


FROM payara/micro
ARG TIMESTAMP

COPY --from=provenbuild /build/proven-message/build/libs/proven-message-0.1-all-in-one.jar /opt/payara/deployments/proven-message-0.1-all-in-one.jar
COPY --from=provenbuild /build/proven-cluster/proven-member/hybrid-service/build/libs/hybrid.war /opt/payara/deployments/hybrid.war
RUN echo $TIMESTAMP > /opt/payara/deployments/dockerbuildversion.txt
ADD proven-system-properties /opt/payara/deployments/proven-system-properties
ADD hazelcast-proven-data.xml /opt/payara/deployments/hazelcast-proven-data.xml
VOLUME /proven/PROVEN
EXPOSE 8080
CMD ["--deploy", "/opt/payara/deployments/hybrid.war", "--hzconfigfile", "/opt/payara/deployments/hazelcast-proven-data.xml", "--systemproperties", "/opt/payara/deployments/proven-system-properties", "--addlibs", "/opt/payara/deployments/proven-message-0.1-all-in-one.jar"]
