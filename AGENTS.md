# 第二影音資料庫 專案工作規則

## 專案定位

- 專案名稱：第二影音資料庫
- 主要用途：用 `yt-dlp` 與 `ffmpeg` 做保守、合法的影片/音訊/字幕/metadata 擷取，供後續 agent 做轉錄、摘要、腳本分析、剪輯規劃、分類與知識庫整理。
- 主要工作目錄：`C:\Users\shaino\Documents\第二影音資料庫`
- 預設 branch：`main`
- GitHub repo：待指定
- GitHub Pages：尚未啟用；需要公開文件或前端頁面時再設定
- Firebase：未使用

## 工作桌與三個家

- 工作桌：本專案資料夾。
- 固定規則：本檔 `AGENTS.md`。
- 進度與下一步：Obsidian 專案駕駛艙，路徑待指定。
- 版本管理：本地 Git；GitHub remote 待指定後再建立或連接。

## 開工規則

使用者說「開工」時：

1. 先讀 `AGENTS.md`。
2. 若 Obsidian 駕駛艙已指定，讀取該筆記的「上次做到哪」與「下一步」。
3. 檢查 `git status --short --branch --untracked-files=all`。
4. 只處理使用者當次要求，不掃入無關檔案。

## 收工規則

使用者說「收工」時：

1. 回報完成事項、未完成事項、下一步。
2. 檢查 Git 狀態。
3. 若使用者要求提交，只 stage 本次相關檔案。
4. 若 Obsidian 駕駛艙已指定，更新進度與踩坑筆記。

## project-init-sync 規則

- 先檢查，後修改。
- 既有 `README.md`、`.gitignore`、腳本和 skill 不覆蓋，只追加缺少的工作模式資訊。
- GitHub repo、Pages、Obsidian vault 資訊不足時，不假裝完成；保留本地初始化並明確回報待指定項。
- Firebase MCP 預設跳過，除非使用者明確要求。

## 主要檔案

- `README.md`：使用方式、版權與使用限制。
- `batch-list.txt`：批次 URL 清單。
- `scripts/MediaTools.ps1`：共用工具解析與 URL 清單處理。
- `scripts/download-video.ps1`：下載影片。
- `scripts/extract-audio.ps1`：擷取音訊。
- `scripts/extract-subtitles.ps1`：擷取字幕。
- `scripts/metadata-only.ps1`：輸出 metadata JSON。
- `skills/media-ingestion/SKILL.md`：專案內媒體擷取技能。
- `outputs/media/`：本地輸出目錄，不提交下載內容。

## 安全與版權

- 只處理自己擁有、已授權、公開授權允許，或可在合理研究/引用範圍內處理的內容。
- 不協助下載後重發他人完整影片、音訊或字幕。
- 財經新聞流程以研究、摘要、來源引用與內部分析為主，避免搬運內容。
- AI 動畫/VFX/音樂參考只分析節奏、鏡頭、字幕、段落與音訊結構，不複製特定創作者風格、受保護 IP、人物聲音或受著作權保護表現。
- 不提交 API key、token、密碼、`.env`、`.codex/`、`.claude/` 或其他本機私密設定。
- 下載輸出保留在 `outputs/media/`，由 `.gitignore` 排除。

