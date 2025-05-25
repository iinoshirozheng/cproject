# Containerfile.builder

# 1. 選擇一個基礎映像檔，包含 C++ 編譯器和基本工具
FROM gcc:11 AS base_builder

# 安裝 CMake, Git 和 download_packages.sh 可能需要的工具 (如 curl, unzip, tar)
RUN apt-get update && apt-get install -y \
    cmake \
    git \
    curl \
    unzip \
    tar \
    # (根據 download_packages.sh 的實際需求添加更多工具)
    && rm -rf /var/lib/apt/lists/*

# 2. 定義第三方函式庫在此 Builder Image 中的最終存放位置
#    download_packages.sh 將會在這個目錄下工作並產生它的輸出

# 3. 複製 download_packages.sh 腳本到容器中
COPY download_packages.sh /opt/download_packages.sh
RUN chmod +x /opt/download_packages.sh

# 4. 執行 download_packages.sh 腳本。
#    因為我們已經在 ${PREBUILT_THIRD_PARTY_DIR} 目錄下，
#    所以腳本生成的 "third_party_library" (或類似) 目錄會直接建立在此處。
#    例如，執行後，您可能會得到 /opt/third_party_libs/include, /opt/third_party_libs/lib 等。
#    您需要確保 download_packages.sh 腳本的行為符合這個預期，
#    或者，如果它總是在其執行目錄下創建一個名為 "output_libs" 的目錄，
#    那麼 PREBUILT_THIRD_PARTY_DIR 應該是 /opt/output_libs (並且 WORKDIR 也應相應調整)。
#    這裡我們假設 download_packages.sh 會在當前 WORKDIR (${PREBUILT_THIRD_PARTY_DIR}) 下
#    直接生成 include/ 和 lib/ 子目錄 (或者一個包含這些的頂層目錄，例如 "third_party")。
#
#    如果 download_packages.sh 在執行它的目錄下創建了一個名為 "third_party" 的頂層輸出目錄，
#    而我們希望 PREBUILT_THIRD_PARTY_DIR (/opt/third_party_libs) 就是那個 "third_party" 目錄，
#    可以這樣調整：
#    ENV THIRD_PARTY_OUTPUT_NAME=my_libs # 假設 download_packages.sh 輸出的目錄名
#    WORKDIR /opt # 先進入 /opt
#    RUN download_packages.sh # 它會在 /opt 下產生 my_libs (即 /opt/my_libs)
#    ENV PREBUILT_THIRD_PARTY_DIR=/opt/${THIRD_PARTY_OUTPUT_NAME} # 然後設定環境變數
#
#    為了更清晰，我們假設 download_packages.sh 會將 include/, lib/ 等直接產生在
#    我們為它設定的 PREBUILT_THIRD_PARTY_DIR。
#    RUN download_packages.sh
#    如果 download_packages.sh 在當前目錄下建立了一個名為 "third_party" 的子目錄，
#    並且我們希望 PREBUILT_THIRD_PARTY_DIR 指向這個 "third_party" 子目錄，可以這樣：
#    ENV PREBUILT_THIRD_PARTY_DIR_PARENT=/opt/prepared_libs
WORKDIR /opt
RUN /opt/download_packages.sh
# 這會在 /opt/ 下產生 "third_party"
ENV THIRD_PARTY_DIR=/opt/third_party

# (可選) 驗證，確保函式庫已按預期放置
RUN ls -lR ${THIRD_PARTY_DIR}

# CMD ["bash"] # 可以用來進入映像檔進行調試