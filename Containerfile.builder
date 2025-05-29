# Containerfile.builder

# 1. 使用 Red Hat UBI Minimal 作為基礎映像
#    這是輕量化的映像，適合構建高效的容器環境
FROM registry.access.redhat.com/ubi9/ubi:latest AS base_builder

# 2. 安裝額外的開發工具
RUN dnf install -y \
    gcc-c++ \         # 安装 C++ 编译器
    cmake \           # 安装 CMake
    git \             # 安装 Git
    unzip \           # 用于解压缩
    tar \             # 用于文件压缩处理
    && dnf clean all  # 清理暂存文件以减少镜像大小


# 3. 將本地的 download_packages.sh 腳本複製到容器中
#    此腳本用於下載和準備第三方庫
COPY download_packages.sh /opt/download_packages.sh

# 4. 修改腳本權限，確保腳本可以被執行
RUN chmod +x /opt/download_packages.sh

# 5. 設定工作目錄到 /opt，然後執行 download_packages.sh 腳本
#    此腳本會在 /opt/ 下下載並準備 "third_party" 文件夾
WORKDIR /opt
RUN /opt/download_packages.sh

# 6. 設定環境變數 THIRD_PARTY_DIR，方便後續引用第三方庫的路徑
ENV THIRD_PARTY_DIR=/opt/third_party

# 7. 驗證腳本是否正確執行，並確認第三方庫是否存在
#    此命令會遞歸列出 /opt/third_party 目錄下的文件
RUN ls -lR ${THIRD_PARTY_DIR}

# 8. 可選：將 Shell 作為默認入口，方便手動調試
# CMD ["bash"]  # 調試時可打開這行
