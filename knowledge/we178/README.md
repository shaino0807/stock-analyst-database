# 股票分析師資料庫 Secondary Knowledge

This folder is generated from local text sources listed in `outputs\media\we178\text-sources\index.jsonl`.

Use `index.jsonl` for programmatic filtering, `index.md` for browsing, and `notes/` for per-video secondary notes.

The secondary notes intentionally do not duplicate full transcripts. They preserve source paths so the original transcript remains the evidence layer.

Regenerate with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-secondary-knowledge.ps1 -IndexPath "outputs\media\we178\text-sources\index.jsonl" -OutputDir "knowledge/we178" -CollectionTitle "股票分析師資料庫" -DefaultTopic "Public finance news and market commentary" -ClassificationProfile "mixed"
```
