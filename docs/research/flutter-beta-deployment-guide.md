# Flutter 封測部署指南：Google Play 與 App Store

本文件說明如何將 Flutter 應用程式部署到 Google Play 和 App Store 進行封閉測試（Closed Beta）。

---

## 目錄

1. [開發者帳號申請](#1-開發者帳號申請)
2. [準備工作](#2-準備工作)
3. [Google Play 封測部署](#3-google-play-封測部署)
4. [App Store TestFlight 封測部署](#4-app-store-testflight-封測部署)
5. [常見問題](#5-常見問題)

---

## 1. 開發者帳號申請

### Google Play Developer Account

| 項目 | 說明 |
|------|------|
| **申請網址** | https://play.google.com/console/signup |
| **費用** | 一次性 $25 USD |
| **審核時間** | 通常 24-48 小時（個人帳號），企業帳號可能需要更長 |
| **必要條件** | Google 帳號、信用卡/金融卡 |

**申請步驟：**

1. 前往 [Google Play Console](https://play.google.com/console/signup)
2. 登入 Google 帳號
3. 選擇帳號類型：
   - **個人帳號**：適合獨立開發者
   - **組織帳號**：需要提供 D-U-N-S 編號（企業識別碼）
4. 填寫開發者資料（姓名、地址、電話）
5. 支付 $25 USD 註冊費
6. 完成身份驗證（可能需要上傳身份證件）
7. 等待審核通過

### Apple Developer Program

| 項目 | 說明 |
|------|------|
| **申請網址** | https://developer.apple.com/programs/enroll/ |
| **費用** | 年費 $99 USD（個人/組織）或 $299 USD（企業內部分發） |
| **審核時間** | 個人約 24-48 小時，組織約 1-2 週 |
| **必要條件** | Apple ID、雙重認證、macOS 裝置 |

**申請步驟：**

1. 前往 [Apple Developer Program](https://developer.apple.com/programs/enroll/)
2. 使用 Apple ID 登入（需啟用雙重認證）
3. 選擇註冊類型：
   - **個人**：以個人名義發布
   - **組織**：以公司名義發布（需要 D-U-N-S 編號）
4. 填寫個人/組織資料
5. 同意授權合約
6. 支付年費 $99 USD
7. 等待 Apple 審核

> **注意**：組織帳號需要先申請 D-U-N-S 編號，可在 [Dun & Bradstreet](https://www.dnb.com/duns-number.html) 免費申請，約需 5-7 個工作天。

---

## 2. 準備工作

### 2.1 Flutter 專案配置

確保 `pubspec.yaml` 中的應用資訊正確：

```yaml
name: storybuddy
description: Your app description
version: 1.0.0+1  # version+buildNumber
```

### 2.2 應用程式圖示

準備不同尺寸的應用程式圖示：

**Android：**
- 512x512 px（Play Store 列表）
- 各種 mipmap 尺寸（由 Flutter 自動處理）

**iOS：**
- 1024x1024 px（App Store）
- 各種 @1x, @2x, @3x 尺寸

推薦使用 [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) 套件自動生成：

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
```

```bash
flutter pub get
dart run flutter_launcher_icons
```

### 2.3 簽名金鑰準備

#### Android Keystore

```bash
# 生成 keystore（只需執行一次，妥善保存！）
keytool -genkey -v -keystore ~/storybuddy-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

在 `android/` 目錄下建立 `key.properties`（勿提交到 Git）：

```properties
storePassword=<密碼>
keyPassword=<密碼>
keyAlias=upload
storeFile=/Users/<username>/storybuddy-upload-keystore.jks
```

修改 `android/app/build.gradle`：

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

#### iOS 憑證與描述檔

1. 登入 [Apple Developer Portal](https://developer.apple.com/account/)
2. 在 **Certificates, Identifiers & Profiles** 中：
   - 建立 **App ID**（Bundle ID，如 `com.yourcompany.storybuddy`）
   - 建立 **Distribution Certificate**
   - 建立 **Provisioning Profile**（選擇 App Store Distribution）

或使用 Xcode 自動管理：
1. 開啟 `ios/Runner.xcworkspace`
2. 選擇 Runner target → Signing & Capabilities
3. 勾選 "Automatically manage signing"
4. 選擇你的 Team

---

## 3. Google Play 封測部署

### 3.1 建置 Android App Bundle

```bash
# 清理並建置 release 版本
flutter clean
flutter pub get
flutter build appbundle --release
```

輸出檔案位置：`build/app/outputs/bundle/release/app-release.aab`

### 3.2 在 Google Play Console 建立應用程式

1. 登入 [Google Play Console](https://play.google.com/console/)
2. 點擊「建立應用程式」
3. 填寫：
   - 應用程式名稱
   - 預設語言
   - 應用程式類型（應用程式/遊戲）
   - 免費/付費

### 3.3 設定內部測試（最快，最多 100 人）

**適合**：開發團隊快速測試

1. 前往 **測試** → **內部測試**
2. 點擊「建立新版本」
3. 上傳 `.aab` 檔案
4. 填寫版本資訊
5. 點擊「儲存」→「審查版本」→「開始發布至內部測試」
6. 在「測試人員」標籤中：
   - 建立電子郵件清單
   - 加入測試人員的 Google 帳號

**測試人員加入方式：**
- 分享內部測試連結給測試人員
- 測試人員點擊連結接受邀請
- 從 Play Store 下載測試版

### 3.4 設定封閉測試（最多 無限人，需審核）

**適合**：較大規模的封測，需完成 App 資訊

1. 前往 **測試** → **封閉測試**
2. 建立測試群組（Alpha 或自訂名稱）
3. 上傳 `.aab` 檔案
4. 完成以下必要資訊：
   - **主要商店資訊**：應用程式名稱、說明、圖示、螢幕截圖
   - **內容分級**：填寫問卷取得分級
   - **目標客群**：選擇目標年齡層
   - **隱私權政策**：提供隱私權政策 URL
5. 送出審核（通常 1-3 天）

### 3.5 Google Play 封測檢查清單

- [ ] 上傳 App Bundle (.aab)
- [ ] 應用程式圖示 (512x512)
- [ ] 功能圖片 (1024x500)
- [ ] 螢幕截圖（至少 2 張，建議 4-8 張）
- [ ] 應用程式說明（簡短說明 80 字，完整說明 4000 字）
- [ ] 隱私權政策 URL
- [ ] 完成內容分級問卷
- [ ] 設定目標客群和內容
- [ ] 建立測試人員清單

---

## 4. App Store TestFlight 封測部署

### 4.1 建置 iOS Archive

```bash
# 清理並建置 release 版本
flutter clean
flutter pub get
flutter build ios --release
```

接著使用 Xcode 進行 Archive：

1. 開啟 `ios/Runner.xcworkspace`
2. 選擇目標裝置為「Any iOS Device」
3. 選單 **Product** → **Archive**
4. 等待 Archive 完成

### 4.2 上傳到 App Store Connect

**方法一：使用 Xcode Organizer**

1. Archive 完成後，Organizer 視窗會自動開啟
2. 選擇剛建立的 Archive
3. 點擊「Distribute App」
4. 選擇「App Store Connect」
5. 選擇「Upload」
6. 保持預設選項，點擊「Next」
7. 選擇簽名憑證和 Provisioning Profile
8. 點擊「Upload」

**方法二：使用 Transporter App**

1. 從 Mac App Store 下載 [Transporter](https://apps.apple.com/app/transporter/id1450874784)
2. 在 Xcode Organizer 中，選擇 Archive 後點擊「Distribute App」
3. 選擇「Custom」→「App Store Connect」→「Export」
4. 匯出 `.ipa` 檔案
5. 開啟 Transporter，拖入 `.ipa` 檔案上傳

### 4.3 在 App Store Connect 設定 TestFlight

1. 登入 [App Store Connect](https://appstoreconnect.apple.com/)
2. 前往「我的 App」→ 選擇你的應用程式
3. 點擊「TestFlight」標籤

### 4.4 設定內部測試（最快，最多 100 人）

**適合**：開發團隊成員（需要 App Store Connect 角色）

1. 在 TestFlight 中，找到剛上傳的 build
2. 等待 Apple 自動處理（約 10-30 分鐘）
3. 處理完成後，在「內部群組」中：
   - 點擊「+」建立群組
   - 新增測試人員（必須是 App Store Connect 使用者）
4. 測試人員會收到 TestFlight 邀請郵件

### 4.5 設定外部測試（最多 10,000 人，需審核）

**適合**：外部測試人員、公開 Beta 測試

1. 在 TestFlight → 「外部群組」
2. 點擊「+」建立新群組
3. 新增測試人員（輸入 Email 即可，不需 App Store Connect 帳號）
4. 選擇要測試的 Build
5. 填寫測試資訊：
   - Beta 版 App 說明
   - 意見回饋電子郵件
   - 隱私權政策 URL
   - 聯絡資訊
6. 送出 Beta App Review（通常 24-48 小時）

### 4.6 公開連結（Public Link）

若需要更大規模的公開測試：

1. 在外部測試群組中
2. 啟用「公開連結」
3. 設定測試人數上限（最多 10,000）
4. 分享連結給任何人

### 4.7 TestFlight 檢查清單

- [ ] 在 App Store Connect 建立 App 記錄
- [ ] Bundle ID 與 Xcode 專案一致
- [ ] 上傳有效的 Build
- [ ] 填寫 App 基本資訊
- [ ] 提供測試說明
- [ ] 設定意見回饋 Email
- [ ] 提供隱私權政策 URL
- [ ] 建立測試群組並新增測試人員
- [ ] （外部測試）等待 Beta App Review 通過

---

## 5. 常見問題

### Q1: 內部測試和封閉測試有什麼差別？

| 平台 | 內部測試 | 封閉/外部測試 |
|------|----------|--------------|
| **Google Play** | 最多 100 人，即時發布 | 無上限，需基本審核 |
| **App Store** | 最多 100 人（需 ASC 帳號），無需審核 | 最多 10,000 人，需 Beta Review |

### Q2: 測試版需要完整的商店資訊嗎？

- **Google Play 內部測試**：不需要，可直接上傳
- **Google Play 封閉測試**：需要基本商店資訊
- **TestFlight 內部測試**：只需 App 記錄
- **TestFlight 外部測試**：需要 Beta App 說明

### Q3: 審核需要多久？

| 類型 | 時間 |
|------|------|
| Google Play 內部測試 | 即時（幾分鐘） |
| Google Play 封閉測試 | 通常 1-3 天 |
| TestFlight 內部測試 | 10-30 分鐘（自動處理） |
| TestFlight 外部測試 | 通常 24-48 小時 |

### Q4: 可以同時使用內部和外部測試嗎？

可以。常見做法：
1. 使用內部測試讓開發團隊快速驗證
2. 穩定後發布到封閉/外部測試給更多測試人員

### Q5: 測試版會自動更新嗎？

- **Google Play**：是，測試人員會自動收到更新
- **TestFlight**：是，測試人員會收到更新通知

### Q6: D-U-N-S 編號是什麼？怎麼申請？

D-U-N-S（Data Universal Numbering System）是企業識別碼，用於驗證組織身份。

- **用途**：Apple 和 Google 組織帳號驗證
- **費用**：免費
- **申請**：https://www.dnb.com/duns-number.html
- **時間**：5-7 個工作天

### Q7: 開發者帳號費用總整理

| 平台 | 費用類型 | 金額 |
|------|----------|------|
| Google Play | 一次性 | $25 USD |
| Apple Developer (個人/組織) | 年費 | $99 USD |
| Apple Developer (企業) | 年費 | $299 USD |

---

## 快速參考連結

- [Google Play Console](https://play.google.com/console/)
- [Google Play 發布檢查清單](https://developer.android.com/distribute/best-practices/launch/launch-checklist)
- [App Store Connect](https://appstoreconnect.apple.com/)
- [TestFlight 官方文件](https://developer.apple.com/testflight/)
- [Flutter 官方部署指南 - Android](https://docs.flutter.dev/deployment/android)
- [Flutter 官方部署指南 - iOS](https://docs.flutter.dev/deployment/ios)
