# CMake 專案初始化工具說明

本專案提供一個 `generate_project.sh` 腳本，可快速初始化一個 C++17 專案的 CMake 結構，包括：

- CMake 模組複製 (`cmake_template/ → cmake/`)
- 自動生成主 `CMakeLists.txt`
- 設定編譯參數、第三方庫、模組路徑
- 支援外部路徑呼叫與當前目錄預設


---
## 建議專案結構

```
your_project/ ← cd 到此執行 generate_project.sh
├── CMakeLists.txt         # ← 自動產生
├── cmake/                 # ← 自動複製
│   ├── GlobalOptions.cmake
│   ├── BuildMainExecutable.cmake
│   ├── CollectSources.cmake
│   └── ConfigureTests.cmake
├── src/                   # ← 程式碼
└── tests/                 # ← 放置單元測試


...

Library_dir/
├── third_party/           # ← 自定義外部套件
├── download_packages.sh   # ← 自動下載第三方庫
└── generate_project.sh    # ← 初始化腳本（可放外部）
```

---


## 使用方式

### 1. 基本呼叫（使用當前目錄）

```bash
./generate_project.sh
```

將會在當前資料夾建立：

- `cmake/`（複製自 `cmake_template/`）
- `CMakeLists.txt`（包含標準設定）

如果找不到第三方庫會自動幫你下載

---

### 2. 指定專案目錄

```bash
./generate_project.sh /path/to/your/project
```

將會：

- 複製模板到 `/path/to/your/project/cmake`
- 在該資料夾產生 `CMakeLists.txt`

---

## CMakeLists.txt 自動產出內容

以下為腳本自動建立的主 `CMakeLists.txt`：

```cmake
cmake_minimum_required(VERSION 3.15)
project(FinanceStockQuota VERSION 1.0.0 LANGUAGES CXX)

message(STATUS "CMake 版本: \${CMAKE_VERSION}")
message(STATUS "專案名稱: \${PROJECT_NAME}")

# C++17 設定
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS ON)

# 第三方庫位置
set(THIRD_PARTY_DIR \${CMAKE_SOURCE_DIR}/../third_party)
message(STATUS "第三方庫目錄: \${THIRD_PARTY_DIR}")

# 引入外部函數
include(\${THIRD_PARTY_DIR}/LinkThirdparty.cmake OPTIONAL)
message(STATUS "已引入 LinkThirdparty.cmake")

# 設定模組目錄與引入
set(CMAKE_MODULE_PATH "\${CMAKE_SOURCE_DIR}/cmake" \${CMAKE_MODULE_PATH})
add_subdirectory(cmake)
```

---

## cmake_template/ 內容

請在 `cmake_template/` 中準備以下模組檔案：

- `GlobalOptions.cmake`
- `BuildMainExecutable.cmake`
- `CollectSources.cmake`
- `ConfigureTests.cmake`

這些將會自動複製到 `cmake/` 中。

---
## 常見用途

| 情境             | 指令                              |
| ---------------- | --------------------------------- |
| 在目前目錄初始化 | `./~腳本路徑/generate_project.sh` |
| 跑執行檔案       | 專案路徑生成的 `run.sh`           |
| 跑測試檔案       | 專案路徑生成的 `run.sh --test`    |