###
# Build the proven hybrid service
# Extend the payara/micro container to run the hybrid service
###

FROM openjdk:8-jdk-alpine AS provenbuild

ADD ./proven-message /build/proven-message
ADD ./proven-cluster /build/proven-cluster
ADD ./proven-dependencies/alibaba-2.0.jar /root/.m2/repository/org/openrdf/alibaba/alibaba/2.0/alibaba-2.0.jar
RUN cd /build/proven-message \
    && ./gradlew clean \
    && ./gradlew publishToMavenLocal
RUN cd /build/proven-cluster/proven-member \
    && ./gradlew clean \
    && ./gradlew war



FROM payara/micro
ARG TIMESTAMP

COPY --from=provenbuild /build/proven-message/build/libs/proven-message-0.1-all-in-one.jar /opt/payara/deployments/proven-message-0.1-all-in-one.jar
COPY --from=provenbuild /build/proven-cluster/proven-member/hybrid-service/build/libs/hybrid.war /opt/payara/deployments/hybrid.war
RUN echo $TIMESTAMP > /opt/payara/deployments/dockerbuildversion.txt
ADD proven-docker/proven-system-properties /opt/payara/deployments/proven-system-properties
ADD proven-docker/hazelcast-proven-data.xml /opt/payara/deployments/hazelcast-proven-data.xml
VOLUME /proven/PROVEN
EXPOSE 8080
CMD ["--deploy", "/opt/payara/deployments/hybrid.war", "--hzconfigfile", "/opt/payara/deployments/hazelcast-proven-data.xml", "--systemproperties", "/opt/payara/deployments/proven-system-properties", "--addlibs", "/opt/payara/deployments/proven-message-0.1-all-in-one.jar"]
