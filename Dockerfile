FROM debian:stable-slim AS gem-builder
ENV LM_HOME=/opt/license-management
WORKDIR $LM_HOME
COPY exe exe/
COPY lib lib/
COPY *.gemspec ./
COPY *.json ./
COPY *.md ./
COPY *.yml ./
RUN apt-get update -q \
  && apt-get install -y --no-install-recommends ruby \
  && gem build *.gemspec

# Install org.codehaus.mojo:license-maven-plugin to $HOME/.m2/repository
# Install gradle.plugin.com.hierynomus.gradle.plugins:license-gradle-plugin to $HOME/.m2/repository
FROM debian:stable AS license-maven-plugin-builder
RUN apt-get update -q \
  && apt-get install -y --no-install-recommends maven \
  && mvn license:license-list \
  && mvn dependency:get -Dartifact=gradle.plugin.com.hierynomus.gradle.plugins:license-gradle-plugin:0.15.0 -DremoteRepositories=https://plugins.gradle.org/m2 \
  && mvn dependency:get -Dartifact=org.codehaus.plexus:plexus-utils:2.0.6

FROM debian:stable-slim as tools-builder
ENV ASDF_DATA_DIR="/opt/asdf"
ENV HOME=/root
ENV PATH="${ASDF_DATA_DIR}/shims:${ASDF_DATA_DIR}/bin:${HOME}/.local/bin:${PATH}"
ENV TERM="xterm"
WORKDIR $HOME
COPY config /root
COPY config/01_nodoc /etc/dpkg/dpkg.cfg.d/01_nodoc
RUN bash /root/install.sh

FROM tools-builder
ENV LM_HOME=/opt/license-management
COPY --from=license-maven-plugin-builder /root/.m2/repository /root/.m2/repository
COPY --from=gem-builder /opt/license-management/*.gem $LM_HOME/pkg/
COPY run.sh /
ENTRYPOINT ["/run.sh"]
