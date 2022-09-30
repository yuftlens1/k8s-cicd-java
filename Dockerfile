# 基础镜像可以按需修改，可以更改为公司自有镜像
FROM registry.cn-beijing.aliyuncs.com/dotbalo/jre:8u211-data
# jar 包名称改成实际的名称，本示例为 spring-cloud-eureka-0.0.1-SNAPSHOT.jar
COPY target/spring-cloud-eureka-0.0.1-SNAPSHOT.jar ./
COPY metrics/jmx_prometheus_javaagent-0.17.0.jar ./
COPY metrics/config.yaml ./
# 启动 Jar 包
CMD java -javaagent:./jmx_prometheus_javaagent-0.17.0.jar=12345:config.yaml -jar spring-cloud-eureka-0.0.1-SNAPSHOT.jar
