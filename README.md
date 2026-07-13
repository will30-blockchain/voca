<div align="center">

<img src="Resources/logo-hero.png" alt="VOCA" width="116" height="116" />

# VOCA

**自訂 API 的 macOS 語音聽寫工具**

開口說話，乾淨的文字就出現在游標位置，任何 app 都能用。<br/>
語音、API 金鑰、資料，全都留在你自己手上。

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)
[![Build](https://github.com/will30-blockchain/voca/actions/workflows/ci.yml/badge.svg)](https://github.com/will30-blockchain/voca/actions)

**繁體中文** · [English](README.en.md)

<br/>

<img src="Resources/hud.png" alt="VOCA 錄音膠囊" width="560" />

<br/><br/>

<img src="Resources/screenshot.png" alt="VOCA 主畫面" width="760" />

</div>

VOCA 是一款原生的 macOS 選單列聽寫與翻譯工具。API 你自己設，模型你自己挑，
市面上最快、最便宜的都能用。用多少付多少，語音資料不會經過任何第三方伺服器。

---

## 為什麼用 VOCA

- **自訂 API。** 支援 Groq、OpenAI、Anthropic、Deepgram，也能用 Apple Speech
  完全離線。最省的組合一次聽寫不到一分錢。
- **智慧字典優化。** 聽寫完你順手改掉的錯字，VOCA 會記起來，下次自動用對。
- **中文優化。** 繁簡分得清楚，中英夾雜原樣保留，中英文和數字之間自動補上
  半形空格。
- **格式自動識別。** 看到問候和署名就排成 email，口頭列的點整理成編號清單，
  同時去掉口頭禪、處理你的改口。
- **即時翻譯。** 用一種語言講，貼出來是另一種語言。
- **原生介面。** 一個正常的選單列 app，沒有毛玻璃、沒有光暈，也沒有那種濃濃的
  AI 味。

## 功能一覽

| 功能 | 說明 |
|---|---|
| 快捷鍵 | 點一下右 Option 開始或結束聽寫 |
| 翻譯 | 點右 Option，放開前再補按右 Shift |
| 即時音量 | 波形跟著音量跳動，讓你知道麥克風真的有收音 |
| 潤稿 | LLM 補標點、去贅字、處理你的改口 |
| 自動排信 | 看到問候語和署名，就排成 email 格式 |
| 清單 | 「第一點、第二點……」自動變成編號清單 |
| 字典 | 詞彙會同時影響 STT 和 LLM；貼上後改字，專有名詞自動收進字典 |
| 記憶 | 記住你常講的詞，用過兩次以上就收起來，也能自己補上個人資訊 |
| Pangu 空格 | 中英文和數字之間自動補半形空格，預設開啟 |
| 重試 | 中途斷線也沒關係，聲音留著，點一下重跑 |
| ESC | 錄到一半想取消，隨處按 ESC |
| 日誌 | 設定 → Logs 可以看到每一步流程和各階段耗時 |

## 安裝

到 [Releases](https://github.com/will30-blockchain/voca/releases) 下載可以直接
開的 `.dmg`，不用裝 Xcode。想自己 build 的話，看下面的
[從原始碼建置](#從原始碼建置)。

VOCA 目前用的是自簽章，還沒有 Apple Developer ID，所以 macOS Gatekeeper 不會
讓你直接雙擊打開。下面教你怎麼處理，只要做一次。至於這道手續什麼時候能拿掉，
看 [發佈狀態](#發佈狀態)。

### 首次開啟，繞過 Gatekeeper

1. 打開 `.dmg`，把 `VOCA.app` 拖進 `/Applications`。
2. 在「應用程式」資料夾裡對著 `VOCA.app` 按右鍵，選「打開」。
3. 跳出「macOS 無法驗證開發者」時，直接點「打開」就好。這個按鈕只有走右鍵才會
   出現。
4. 這樣就好。之後正常雙擊就能開，右鍵這步每次安裝只要做一次。

> **如果出現「App 已損毀，無法打開」**：那是下載時被系統加了隔離標記。在終端機
> 執行一次下面的指令清掉，再回去做右鍵開啟：
> ```bash
> xattr -dr com.apple.quarantine /Applications/VOCA.app
> ```
> 這只會拿掉隔離標記，不會動到簽章、內容，或你已經給過的權限。

### 授權權限與金鑰

1. **麥克風**：第一次按快捷鍵時系統就會問你。
2. **輔助使用**：到 系統設定 → 隱私權與安全性 → 輔助使用，把 VOCA 打開，然後
   結束再重新開啟。macOS 只在啟動當下讀這個權限，沒重開就不會生效。
3. **API 金鑰**：到 設定 → Providers 貼上你的 Groq 金鑰，金鑰可以到
   <https://console.groq.com/keys> 拿。

接著點右 Option、開口講、再點一下，文字就落在游標位置。

### 發佈狀態

| 方式 | 狀態 |
|---|---|
| 從 GitHub Releases 下載自簽章 `.dmg`，右鍵打開 | 目前提供 |
| Apple Developer ID 簽章加公證，雙擊就能開 | 規劃中，需要每年 $99 的 Apple Developer Program |
| Homebrew Cask | 規劃中，等 Developer ID 好了再做 |
| Mac App Store | 不打算做，App Sandbox 的規則基本上不允許全域快捷鍵和輔助使用 |

右鍵這套麻煩，純粹是因為還沒有 Developer ID。等有了公證版本，雙擊就會直接開。

## 從原始碼建置

想貢獻程式碼，或想跑最新的 `main`，就走這條。

需要先準備：
- macOS 14 Sonoma 以上
- Xcode 15+ 和 Swift 工具鏈
- 一組 Groq、OpenAI、Anthropic 或 Deepgram 的 API 金鑰，或者用離線的 Apple Speech

```bash
git clone https://github.com/will30-blockchain/voca.git
cd voca
./scripts/setup-signing.sh   # 一次性：建立穩定的本機簽章憑證
./scripts/build-app.sh       # 建置並簽章 VOCA.app
open dist/VOCA.app
```

build 完照上面的 [授權權限與金鑰](#授權權限與金鑰) 設定就好。

### 建置腳本會動到你電腦的哪些東西

我們的原則很硬：**VOCA 的建置流程絕對不能弄壞你電腦上其他 app。** 具體來說：

- 會寫入的檔案只放在專案的 `build/` 目錄裡。
- 不會碰你的登入 keychain，也不會動裡面任何密碼。
- 不會在 `~/Library/` 裝任何東西。
- 執行 `codesign` 時會暫時改動使用者的 keychain 搜尋清單，這是 macOS 的要求，
  光給 `--keychain` 不夠。`build-app.sh` 會攔 `EXIT`、`INT`、`TERM`，保證清單
  一定會還原才結束，就算中途失敗或被 Ctrl-C 也一樣。跑完等於沒動過。

`setup-signing.sh` 會在 `build/voca-signing.keychain-db` 開一個只屬於這個專案的
keychain，裡面就一張自簽的開發憑證。想清得一乾二淨，執行
`./scripts/uninstall-signing.sh`。它也會順手偵測並清掉 2026-05 前舊版腳本留下的
一個 bug，那版會永久汙染使用者的 keychain 搜尋清單，現在已經修好。

## 架構

分成兩個 Swift 套件。`VOCACore` 是純邏輯，完全不碰 AppKit，收音、STT/LLM
供應商串接、潤稿、修正學習、還有 JSON 儲存都在這裡。`VOCA` 則是用 AppKit 加
SwiftUI 寫的選單列 app。整條流程從錄音、轉錄、潤稿、貼上到學習，都由
`VoiceTypeEngine` 統籌。

```
Sources/
  VOCACore/           Audio · Hotkeys · Transcription · LLM · Refinement ·
                      Learning · Memory · Dictionary · History · Logging ·
                      Settings · Util · Permissions · VoiceTypeEngine
  VOCA/               AppDelegate · MenuBar · Dashboard · HUD · Toast ·
                      Settings（7 個面板） · DesignTokens
Tests/VOCACoreTests/  純 Swift 單元測試
scripts/              setup-signing · build-app · uninstall-signing · make-icon
```

視覺沿用 SuperCard 那套「Professional Warmth」，暖白底色、品牌橘、SF Pro。完整
設計筆記見 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)，自動學習的準確度規劃見
[`docs/AUTO_LEARN_PLAN.md`](docs/AUTO_LEARN_PLAN.md)。

## 隱私

- 聲音不落地。錄下來的 WAV 只存在記憶體，直接送到你指定的供應商。
- v1 版的 API 金鑰是明文存在
  `~/Library/Application Support/VOCA/settings.json`。Keychain 整合已經排進
  規劃，在那之前請把這個檔案當敏感資料看待。
- 其他東西像字典、記憶、歷史、日誌，全部只留在你自己的電腦上。
- VOCA 不會偷偷回傳任何資料，唯一的對外連線就是你選的那家供應商。

## 威脅模型

這裡把 VOCA 防得了什麼、防不了什麼講清楚，讓你自己判斷合不合用。

守得住的：
- 你的 API 金鑰只留在你電腦裡。寫進日誌前會先依前綴 `sk-`、`sk-ant-`、`gsk_`、
  `AIza` 遮蔽，所以你貼日誌去回報 bug 時，不會不小心把金鑰洩漏出去。
- 聲音不會被留下。錄音只在記憶體裡，拿到回應後就釋放。
- 貼出來的文字只會進到你按快捷鍵當下那個 app，VOCA 不會偷偷切換視窗或跳到
  背景。
- 除了你選的供應商，沒有任何其他對外連線。沒有遙測、沒有當機回報，打包好的
  程式裡也沒有任何分析 SDK。

守不住的，也請別指望：
- 你電腦上已經在跑、權限又跟你一樣的惡意程式。只要對方拿到輔助使用權限，不管
  有沒有 VOCA，它都讀得到你打的字。
- 你選的供應商會看到你講的內容，Groq、OpenAI、Anthropic、Deepgram 都一樣，用
  遠端 STT/LLM 本來就是這樣。想完全離線就改用 Apple Speech。
- 硬碟的靜態加密。我們假設你已經開了 FileVault。

要回報漏洞，看 [SECURITY.md](SECURITY.md)。

## 開發藍圖

- [ ] 用 Keychain 存 API 金鑰
- [ ] 可自訂快捷鍵
- [ ] 串流即時逐字稿，例如 Deepgram、OpenAI Realtime
- [ ] 用 `whisper.cpp` 跑本地 Whisper，做到完全離線
- [ ] 上架 Homebrew Cask
- [ ] Sparkle 自動更新
- [ ] Windows 版 `voca-windows`

## 參與貢獻

歡迎發 PR，細節看 [`CONTRIBUTING.md`](CONTRIBUTING.md)。比較大的改動麻煩先開個
issue 聊聊方向。參與就代表你同意我們的 [行為準則](CODE_OF_CONDUCT.md)。

## 贊助開發

VOCA 是用下班時間做和維護的。如果它幫你省了時間、少打了很多字，歡迎小額贊助，
讓我付付偶爾的 Apple Developer 費用、咖啡，還有測試時燒掉的 API 額度。

以太坊 / EVM，Mainnet、Polygon、BSC、Arbitrum、Base 都可以：

```
0x081540Eb4c21B8Be8a652d408A4711bFaffeB5f4
```

其他事情，寫信到 **valley.mirror7602@eagereverest.com**。

## 致謝

VOCA 是和 [Claude Code](https://claude.com/claude-code) 一起做出來的，架構、
設計決策和大部分實作，都是跟 Claude 結對程式設計反覆磨出來的。不過講白了，它在
使用者眼中並不算什麼「AI app」，說穿了就是一個會呼叫你所選 AI API 的語音打字
工具。

視覺上的「Professional Warmth」，暖白底色、品牌橘、SF Pro，和
[SuperCard](https://github.com/will30-blockchain) 系列 app 共用同一套。

## 授權條款

採用 MIT，見 [`LICENSE`](LICENSE)。
