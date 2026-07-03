# 股票分析師資料庫 Ingestion Status

Updated: 2026-07-03 22:14:37 +08:00

## Source

- Channel: https://www.youtube.com/@we178/videos
- Public video URLs listed: 2007
- Batch list: `batch-list-we178.txt`

## Coverage

| Layer | Count | Status |
| --- | ---: | --- |
| Public video URLs | 2007 | Complete for latest local channel refresh |
| Metadata JSON | 2007 | Complete when this equals URL count |
| Subtitle files | 529 | Public subtitles only |
| Text source records | 2007 | Search source layer |
| Text sources with transcript | 529 | Uses public subtitles only |
| Text sources missing transcript | 1478 | Needs subtitle retry or ASR audio transcription |
| Secondary knowledge notes | 2007 | Search and retrieval layer |
| Remaining metadata URLs | 0 | Listed in `batch-list-we178-remaining-metadata.txt` |

## Search And Retrieval

- Browse: `knowledge/we178/index.md`
- Machine index: `knowledge/we178/index.jsonl`
- Per-video secondary notes: `knowledge/we178/notes/`
- Missing transcript report: `knowledge/we178/transcript-missing.md`
- Search help: `knowledge/we178/SEARCH.md`

## Daily Refresh

- Suggested task name: `WE178DailyKnowledgeUpdate`
- Entry point: `scripts/run-we178-daily-update.ps1`
- Installer: `scripts/install-we178-daily-task.ps1`
- Daily behavior: refreshes the channel video list, fetches metadata/subtitles only for newly discovered videos, rebuilds text sources and secondary knowledge, and updates missing-transcript lists.
- It does not download audio or original videos.

## Resume Commands

Run the 股票分析師資料庫 refresh manually:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\update-we178-knowledge.ps1 -ContinueOnSubtitleError
```

Retry missing public subtitles later, without downloading audio/video:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\update-we178-knowledge.ps1 -SkipChannelRefresh -SkipMetadata -RetryMissingSubtitles -ContinueOnSubtitleError
```

## Notes

- Audio extraction/transcription is intentionally separate. Use `extract-audio.ps1 -EstimateOnly` first and only download audio with `-ConfirmStorageImpact` after reviewing the size estimate.
- Original video downloads are also blocked by default until storage impact is estimated and `-ConfirmStorageImpact` is supplied.
