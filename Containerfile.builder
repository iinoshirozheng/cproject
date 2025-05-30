# 使用 Red Hat UBI 9 作為基礎映像
# 適合用於構建和運行應用程式，提供了 RHEL 的核心庫和工具
FROM registry.access.redhat.com/ubi9/ubi:latest AS base_builder

# 安裝 GCC, G++, CMake 和其他所需的工具
# UBI 9 使用 dnf 作為包管理器
RUN dnf install -y \
    gcc \
    gcc-c++ \
    cmake \
    make \
    git \
    curl \
    unzip \
    tar \
    # (根據 download_packages.sh 的實際需求添加更多工具)
    # 例如：如果 download_packages.sh 中有用到 Python，可能需要 python3-pip 等
    && dnf clean all # 清理 dnf 緩存以減少映像大小

# 複製 download_packages.sh 腳本到映像中
COPY download_packages.sh /opt/download_packages.sh

# 設置腳本為可執行文件
RUN chmod +x /opt/download_packages.sh

# 執行 download_packages.sh，下載即時所需的第三方庫
WORKDIR /opt
RUN /opt/download_packages.sh

# 設定環境變數，讓第三方庫的路徑方便引用
ENV THIRD_PARTY_DIR=/opt/third_party

# 驗證下載的目錄
RUN ls -lR ${THIRD_PARTY_DIR}

# （可選）將 Shell 設置為默認命令
# CMD ["bash"]
