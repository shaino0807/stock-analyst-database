# 股票分析師資料庫 Search And Retrieval

Use this folder as the secondary knowledge layer for the 股票分析師資料庫 YouTube source set.

## Files

- `index.jsonl`: machine-readable secondary knowledge index.
- `index.md`: browseable table sorted by upload date.
- `topics.md`: topic count overview.
- `notes/`: one secondary note per video.
- `transcript-missing.md`: videos that still need subtitle retry or ASR transcription.

## Search Commands

Run from the project root.

Search titles, topics, entities, stances, hashtags:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\search-secondary-knowledge.ps1 -IndexPath "knowledge/we178/index.jsonl" -Query "台積電" -Limit 20
```

Search a topic:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\search-secondary-knowledge.ps1 -IndexPath "knowledge/we178/index.jsonl" -Topic "Taiwan equities" -Limit 20
```

Search an entity:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\search-secondary-knowledge.ps1 -IndexPath "knowledge/we178/index.jsonl" -Entity "TSMC" -Limit 20
```

Search only items with usable transcript/subtitle text:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\search-secondary-knowledge.ps1 -IndexPath "knowledge/we178/index.jsonl" -Query "Fed" -TranscriptOnly -Limit 20
```

Search full source text, including description and transcript when available:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\search-secondary-knowledge.ps1 -IndexPath "knowledge/we178/index.jsonl" -Query "記憶體" -IncludeSourceText -Limit 20
```

Return JSON for downstream agents:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\search-secondary-knowledge.ps1 -IndexPath "knowledge/we178/index.jsonl" -Query "川普" -Json
```

## Refresh

Manual refresh:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\update-we178-knowledge.ps1 -ContinueOnSubtitleError
```

Install daily Windows scheduled refresh:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-we178-daily-task.ps1
```

The refresh workflow does not download audio or original videos. It refreshes the channel list, fetches metadata and public subtitles for newly discovered videos, rebuilds text sources, and updates the secondary knowledge layer.
