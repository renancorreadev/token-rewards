##
## Stage: foundry — installs Foundry (forge, cast, anvil, chisel)
##
FROM ubuntu:22.04 AS foundry

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates git && \
    rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-c"]
ENV FOUNDRY_DIR="/opt/foundry"
RUN curl -L https://foundry.paradigm.xyz | bash && \
    source "${FOUNDRY_DIR}/bin/foundryup" 2>/dev/null; \
    ${FOUNDRY_DIR}/bin/foundryup

##
## Stage: toolbox — full Ethereum security development environment
##
FROM ubuntu:22.04 AS toolbox

ARG USERNAME=ethsec
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ARG TARGETARCH

# System packages
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        jq \
        python3 \
        python3-pip \
        python3-venv \
        software-properties-common \
        sudo \
        wget \
        zsh && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/zsh ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Copy Foundry from builder stage
COPY --from=foundry /opt/foundry/bin/ /home/${USERNAME}/.foundry/bin/

# Install solc via solc-select
RUN pip3 install --no-cache-dir solc-select && \
    solc-select install 0.8.24 && \
    solc-select use 0.8.24

# Install slither + halmos
RUN pip3 install --no-cache-dir slither-analyzer halmos

# Install echidna (auto-detect arch: amd64 → x86_64, arm64 → aarch64)
RUN ECHIDNA_VERSION="2.3.1" && \
    if [ "$TARGETARCH" = "arm64" ]; then ECHIDNA_ARCH="aarch64"; else ECHIDNA_ARCH="x86_64"; fi && \
    curl -fsSL "https://github.com/crytic/echidna/releases/download/v${ECHIDNA_VERSION}/echidna-${ECHIDNA_VERSION}-${ECHIDNA_ARCH}-linux.tar.gz" \
    | tar -xz -C /usr/local/bin

# Install medusa (only x64 linux available — skip on arm64)
RUN MEDUSA_VERSION="1.5.0" && \
    if [ "$TARGETARCH" = "amd64" ]; then \
        curl -fsSL "https://github.com/crytic/medusa/releases/download/v${MEDUSA_VERSION}/medusa-linux-x64.tar.gz" \
        | tar -xz -C /usr/local/bin && \
        chmod +x /usr/local/bin/medusa; \
    else \
        echo "#!/bin/sh\necho 'medusa: not available on arm64 linux (use mac-arm64 host binary or x86 emulation)'" > /usr/local/bin/medusa && \
        chmod +x /usr/local/bin/medusa; \
    fi

# Set ownership
RUN chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

USER ${USERNAME}
WORKDIR /home/${USERNAME}/workspace

# Add tools to PATH
ENV PATH="/home/${USERNAME}/.foundry/bin:/home/${USERNAME}/.local/bin:${PATH}"

CMD ["zsh"]
