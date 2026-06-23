FROM jenkins/jenkins:lts

USER root

RUN apt-get update && \
    apt-get install -y \
      ca-certificates \
      curl \
      gnupg \
      unzip \
      maven \
      git && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    ARCH="$(dpkg --print-architecture)" && \
    if [ "$ARCH" = "amd64" ]; then AWS_ARCH="x86_64"; else AWS_ARCH="aarch64"; fi && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o awscliv2.zip && \
    unzip awscliv2.zip && \
    ./aws/install && \
    ARCH="$(dpkg --print-architecture)" && \
    if [ "$ARCH" = "amd64" ]; then KUBECTL_ARCH="amd64"; else KUBECTL_ARCH="arm64"; fi && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${KUBECTL_ARCH}/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/kubectl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* aws awscliv2.zip && \
    mkdir -p /root/.ssh && \
    ssh-keyscan -t ed25519 github.com >> /root/.ssh/known_hosts && \
    chmod 700 /root/.ssh && \
    chmod 644 /root/.ssh/known_hosts


USER jenkins