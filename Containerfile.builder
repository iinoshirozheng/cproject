# 使用 GCC:11 作為基礎映像，已內建 gcc 和 g++
# 適合用於構建 C/C++ 應用程式或執行其他開發任務
FROM gcc:11 AS base_builder

# 安裝其他所需的工具（基於需要的額外開發環境）
RUN apt-get update && apt-get install -y \
    cmake \
    git \
    curl \
    unzip \
    tar \
    # (根據 download_packages.sh 的實際需求添加更多工具)
    && rm -rf /var/lib/apt/lists/*

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
