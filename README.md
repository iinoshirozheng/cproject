# cproject：C/C++ 專案腳手架工具

cproject 是一款基於 Bash 與 CMake 的命令行工具，用於快速生成 C/C++ 專案骨架並自動執行編譯/測試流程。CMake 專案主要使用名為 `CMakeLists.txt` 的設定檔來配置建置規則，本工具可自動建立此檔案並複製必要的模組。使用 `cproject create <專案名>` 指令，會在當前或指定目錄創建新的專案結構，包含 `CMakeLists.txt`、`cmake/`、`src/`、`tests/`、`bin/` 等基本目錄，並生成範例程式碼與測試檔案。建立專案後，可在專案目錄下使用 `cproject run` 或直接執行生成的 `run.sh` 腳本來編譯並運行程式；加上 `--test` 選項則編譯並執行所有單元測試。本工具的核心特性包括：  

- 🛠 **快速初始化**：透過單一指令快速生成 C++17 專案結構（`src/`、`tests/`、`cmake/`、`bin/` 等），並自動建立 `CMakeLists.txt`。  
- 📝 **範例程式碼**：自動建立 `main.cpp` 和 `basic_test.cpp` 等範例檔案，演示基本功能與單元測試。  
- 🔧 **CMake 模組化**：從模板複製 `GlobalOptions.cmake`、`BuildMainExecutable.cmake`、`CollectSources.cmake`、`ConfigureTests.cmake` 等模組化設定，便於管理編譯流程。  
- 🧩 **第三方庫整合**：提供 `download_packages.sh` 腳本下載常用函式庫 (如 GoogleTest、spdlog、hiredis 等)，並透過 `LinkThirdparty.cmake` 將其連結到專案。  
- 🚀 **一鍵編譯執行**：內建 `run.sh` 腳本，一鍵建立 `build/`、執行 CMake 配置、編譯，並運行程式或測試。  

## 安裝與前置條件

- **系統與依賴**：Linux/macOS 系統 (Windows 可透過 WSL 等類似環境)。需安裝支援 C++17 的編譯器（如 gcc/clang）及 CMake (建議 ≥3.15)。此外，需安裝 Git（下載第三方庫）與 Make 或 Ninja（編譯工具）。  
- **安裝步驟**：將本專案克隆到本地後，對腳本檔賦予執行權限，例如：  
  ```bash
  chmod +x cproject.sh create_project.sh generate_cmake.sh download_packages.sh run_template.sh
  ```  
  可選擇將 `cproject.sh` 添加到系統路徑或設置別名（如 `alias cproject='bash /path/to/cproject.sh'`），以便在任何目錄下執行 `cproject` 指令。  

## 指令列表

- `cproject create <專案名稱>`：透過 `create_project.sh` 腳本快速建立新專案，例如 `cproject create MyApp`。完成後，將在當前目錄生成名為 `MyApp` 的資料夾，其中包含基本的 `CMakeLists.txt` 和範例程式碼。  
- `cproject run`：編譯並執行當前資料夾中的專案。等效於執行 `./run.sh`。默認情況下只編譯主程式並執行。  
- `cproject run --test`：編譯專案並執行所有單元測試，對應執行 `run.sh` 中的測試模式。  

## 目錄結構範例與說明

使用 `cproject create` 初始化專案後，假設專案名為 `MyApp`，則目錄結構可能如下：

```bash
MyApp/
├── CMakeLists.txt      # 自動生成的 CMake 主設定檔
├── run.sh              # 建置並執行專案的腳本
├── cmake/              # 模組化的 CMake 檔案
│   ├── GlobalOptions.cmake
│   ├── BuildMainExecutable.cmake
│   ├── CollectSources.cmake
│   └── ConfigureTests.cmake
├── src/                # 原始程式碼目錄
│   └── main.cpp        # 範例主程式
├── tests/              # 單元測試目錄
│   └── basic_test.cpp  # 範例測試程式
└── bin/                # 編譯輸出 (可執行檔放置)
```

## 主要腳本說明

- **create_project.sh**：生成新的專案骨架，建立資料夾，加入主程式與測試範例，並呼叫 generate_cmake.sh。  
- **generate_cmake.sh**：複製 CMake 模組並自動生成主 CMakeLists.txt。  
- **download_packages.sh**：一鍵下載並編譯常用第三方庫。  
- **run.sh**：快速建立與執行專案，支援 `--test` 模式。  

## 執行流程簡介

1. `cproject create MyApp` 建立新專案目錄與預設程式碼。  
2. `cd MyApp` 切換進入專案目錄。  
3. `cproject run` 編譯並執行 `main.cpp`。  
4. `cproject run --test` 執行單元測試。  

## 推薦用法與範例

```bash
# 建立新專案
cproject create DemoApp
cd DemoApp

# 編譯與執行
cproject run

# 編譯與執行測試
cproject run --test
```

本工具讓你可快速建立並執行現代化 C++ 專案，並能流暢整合多個常用函式庫，提升開發效率與品質。