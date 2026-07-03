[CmdletBinding()]
param(
    [string]$IndexPath = 'outputs/media/nicolasyounglive/text-sources/index.jsonl',
    [string]$OutputDir = 'knowledge/nicolasyounglive',
    [string]$CollectionTitle = 'Nicolas Young Live',
    [string]$DefaultTopic = 'Unclassified source material',
    [ValidateSet('mixed', 'education-tech')]
    [string]$ClassificationProfile = 'mixed',
    [int]$CueCount = 5
)

. "$PSScriptRoot\MediaTools.ps1"

function U {
    param([Parameter(Mandatory = $true)][string]$Codepoints)

    $chars = $Codepoints.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
        [char][Convert]::ToInt32($_, 16)
    }
    return -join $chars
}

function Get-SafeFileName {
    param([Parameter(Mandatory = $true)][string]$Name)

    $safe = $Name
    foreach ($char in [System.IO.Path]::GetInvalidFileNameChars()) {
        $safe = $safe.Replace($char, '_')
    }

    $safe = $safe.Trim()
    if ($safe.Length -gt 120) {
        return $safe.Substring(0, 120).Trim()
    }

    return $safe
}

function Get-SectionText {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Heading
    )

    $pattern = "(?ms)^## $([regex]::Escape($Heading))\s*(.*?)(?=^## |\z)"
    $match = [regex]::Match($Content, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return ''
}

function Get-MatchingLabels {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][object[]]$Rules
    )

    $labels = New-Object System.Collections.Generic.List[string]
    foreach ($rule in $Rules) {
        foreach ($alias in $rule.aliases) {
            $isShortAscii = $alias -match '^[A-Za-z0-9.&#+-]{1,3}$'
            $matched = if ($isShortAscii) {
                $pattern = "(?i)(?<![A-Za-z0-9])$([regex]::Escape($alias))(?![A-Za-z0-9])"
                [regex]::IsMatch($Text, $pattern)
            } else {
                $Text.IndexOf($alias, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            }

            if ($matched) {
                $labels.Add($rule.label)
                break
            }
        }
    }

    return @($labels | Select-Object -Unique)
}

function Get-SearchCues {
    param(
        [Parameter(Mandatory = $true)][string]$Transcript,
        [Parameter(Mandatory = $true)][string[]]$Needles,
        [int]$Limit = 5
    )

    $cues = New-Object System.Collections.Generic.List[string]
    $lines = $Transcript -split "`r?`n"
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -lt 12) {
            continue
        }

        $matched = $false
        foreach ($needle in $Needles) {
            if ($trimmed.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $matched = $true
                break
            }
        }

        if (-not $matched) {
            continue
        }

        if ($trimmed.Length -gt 90) {
            $trimmed = $trimmed.Substring(0, 90).Trim() + '...'
        }

        if (-not $cues.Contains($trimmed)) {
            $cues.Add($trimmed)
        }

        if ($cues.Count -ge $Limit) {
            break
        }
    }

    return $cues.ToArray()
}

function Convert-ToYamlList {
    param([string[]]$Items)

    if ($null -eq $Items -or $Items.Count -eq 0) {
        return @('  - none')
    }

    return @($Items | ForEach-Object { "  - `"$($_ -replace '"', '\"')`"" })
}

$kwMemory = U '8A18 61B6 9AD4'
$kwDram = U '5167 5B58'
$kwMicron = U '7F8E 5149'
$kwHynix = U '6D77 529B 58EB'
$kwSamsung = U '4E09 661F'
$kwNvidia = U '82F1 5049 9054'
$kwHuang = U '9EC3 4EC1 52F3'
$kwTsmc = U '53F0 7A4D 96FB'
$kwTrump = U '5DDD 666E'
$kwFedCn = U '7F8E 806F 5132'
$kwFedTw = U '806F 6E96 6703'
$kwRateCut = U '964D 606F'
$kwTariff = U '95DC 7A05'
$kwIran = U '4F0A 6717'
$kwWar = U '6230 722D'
$kwKorea = U '97D3 570B'
$kwJapan = U '65E5 672C'
$kwTakaichi = U '9AD8 5E02 65E9 82D7'
$kwUsStocks = U '7F8E 80A1'
$kwStocks = U '80A1 7968'
$kwTaiwanStocks = U '53F0 80A1'
$kwGold = U '9EC3 91D1'
$kwSilver = U '767D 9280'
$kwBuyDip = U '6284 5E95'
$kwAddPosition = U '88DC 5009'
$kwBigDrop = U '5927 8DCC'
$kwCrash = U '66B4 8DCC'
$kwRise = U '5927 6F32'
$kwSurge = U '66B4 6F32'
$kwWealth = U '767C 8CA1'
$kwBuy = U '8CB7 5165'
$kwIncrease = U '52A0 5009'
$kwHold = U '6301 6709'
$kwRebalance = U '8ABF 5009'
$kwStrategy = U '7B56 7565'
$kwMethod = U '65B9 6CD5'
$kwScreen = U '7BE9 9078'
$kwIndicator = U '6307 6A19'
$kwMath = U '6578 5B78'
$kwTeaching = U '6559 5B78'
$kwTeacher = U '6559 5E2B'
$kwCourse = U '8AB2 7A0B'
$kwPrepareLesson = U '5099 8AB2'
$kwElementary = U '570B 5C0F'
$kwJuniorHigh = U '570B 4E2D'
$kwDigitalWhiteboard = U '6578 4F4D 767D 677F'
$kwBoardGame = U '684C 904A'
$kwInteractive = U '4E92 52D5'
$kwClassroom = U '73ED 7D1A'
$kwWorksheet = U '8A66 5377'
$kwPresentation = U '7C21 5831'
$kwVideo = U '5F71 7247'
$kwVoice = U '8A9E 97F3'
$kwImageGeneration = U '751F 5716'
$kwDatabase = U '8CC7 6599 5EAB'
$kwKnowledgeBase = U '77E5 8B58 5EAB'
$kwAgent = U '4EE3 7406'
$kwSkill = U '6280 80FD'
$kwAutomation = U '81EA 52D5 5316'
$kwAssignment = U '4F5C 696D'
$kwGrade = U '6279 6539'
$kwRubiksCube = U '9B54 65B9'

$topicRules = @(
    [pscustomobject]@{ label = 'AI agents and coding tools'; aliases = @('AI', 'Agent', 'agents', $kwAgent, 'Claude', 'Codex', 'OpenCode', 'AntiGravity', 'Claude Code', 'GPT Codex', 'Gemini CLI') },
    [pscustomobject]@{ label = 'AI teaching workflow'; aliases = @($kwTeaching, $kwTeacher, $kwCourse, $kwPrepareLesson, 'lesson plan', 'Google Classroom', 'Padlet', 'GAS', 'Apps Script', 'NotebookLM', 'Notebook LM', 'Gemini', 'Canvas') },
    [pscustomobject]@{ label = 'Math teaching materials'; aliases = @($kwMath, $kwElementary, $kwJuniorHigh, 'GeoGebra', 'GGB', $kwRubiksCube) },
    [pscustomobject]@{ label = 'Digital whiteboard and classroom tech'; aliases = @($kwDigitalWhiteboard, 'myViewBoard', 'ViewSonic', 'ClassSwift', 'AirPen', 'ID1230') },
    [pscustomobject]@{ label = 'Interactive games and activities'; aliases = @($kwBoardGame, $kwInteractive, 'playingcards.io', 'Arcade') },
    [pscustomobject]@{ label = 'Presentation and video production'; aliases = @($kwPresentation, $kwVideo, $kwVoice, $kwImageGeneration, 'Canva', 'Hyperframes', 'GPT-Image', 'Image 2', 'AIGC') },
    [pscustomobject]@{ label = 'Knowledge base and data workflow'; aliases = @($kwDatabase, $kwKnowledgeBase, 'Obsidian', 'GitHub', 'Supabase', 'Firebase') },
    [pscustomobject]@{ label = 'AI infrastructure'; aliases = @('artificial intelligence', 'data center', 'datacenter', 'robot', 'compute') },
    [pscustomobject]@{ label = 'Memory semiconductors'; aliases = @($kwMemory, $kwDram, $kwMicron, $kwHynix, $kwSamsung, 'Micron', 'SK Hynix', 'Samsung', 'HBM', 'SNDK') },
    [pscustomobject]@{ label = 'Semiconductor equipment'; aliases = @('semiconductor equipment', 'ASML', 'AMAT', 'KLA', 'LRCX', 'Tokyo Electron') },
    [pscustomobject]@{ label = 'SpaceX and private markets'; aliases = @('SpaceX', 'Elon') },
    [pscustomobject]@{ label = 'Trump and US policy'; aliases = @($kwTrump, $kwFedCn, $kwFedTw, $kwRateCut, $kwTariff, 'Trump', 'Fed') },
    [pscustomobject]@{ label = 'Geopolitics and war risk'; aliases = @($kwIran, $kwWar, $kwKorea, $kwJapan, 'geopolitical', 'war') },
    [pscustomobject]@{ label = 'Japan market'; aliases = @($kwTakaichi, $kwJapan, 'Japan') },
    [pscustomobject]@{ label = 'US equities'; aliases = @($kwUsStocks, 'US stocks', 'Nasdaq', 'S&P') },
    [pscustomobject]@{ label = 'Taiwan equities'; aliases = @($kwTaiwanStocks, $kwTsmc, 'Taiwan stocks', 'TSMC') },
    [pscustomobject]@{ label = 'Gold and silver'; aliases = @($kwGold, $kwSilver, 'gold', 'silver') },
    [pscustomobject]@{ label = 'Brokerage and tools'; aliases = @('moomoo', 'Futu', 'Investing.com') },
    [pscustomobject]@{ label = 'Buy-the-dip strategy'; aliases = @($kwBuyDip, $kwAddPosition, $kwBigDrop, $kwCrash, 'buy the dip') }
)

$entityRules = @(
    [pscustomobject]@{ label = 'Claude'; aliases = @('Claude', 'Claude Code') },
    [pscustomobject]@{ label = 'Codex'; aliases = @('Codex', 'GPT Codex', 'GPT-CodeX') },
    [pscustomobject]@{ label = 'OpenCode'; aliases = @('OpenCode', 'Opencode') },
    [pscustomobject]@{ label = 'AntiGravity'; aliases = @('AntiGravity', 'Anti gravity') },
    [pscustomobject]@{ label = 'NotebookLM'; aliases = @('NotebookLM', 'Notebook LM') },
    [pscustomobject]@{ label = 'Gemini'; aliases = @('Gemini', 'Google AI') },
    [pscustomobject]@{ label = 'Google Classroom'; aliases = @('Google Classroom') },
    [pscustomobject]@{ label = 'Padlet'; aliases = @('Padlet') },
    [pscustomobject]@{ label = 'Canva'; aliases = @('Canva') },
    [pscustomobject]@{ label = 'myViewBoard'; aliases = @('myViewBoard') },
    [pscustomobject]@{ label = 'ViewSonic'; aliases = @('ViewSonic') },
    [pscustomobject]@{ label = 'GeoGebra'; aliases = @('GeoGebra', 'GGB') },
    [pscustomobject]@{ label = 'Obsidian'; aliases = @('Obsidian') },
    [pscustomobject]@{ label = 'GitHub'; aliases = @('GitHub') },
    [pscustomobject]@{ label = 'Supabase'; aliases = @('Supabase') },
    [pscustomobject]@{ label = 'Firebase'; aliases = @('Firebase') },
    [pscustomobject]@{ label = 'Micron'; aliases = @($kwMicron, 'Micron', 'MU') },
    [pscustomobject]@{ label = 'SK Hynix'; aliases = @($kwHynix, 'Hynix', 'SK Hynix') },
    [pscustomobject]@{ label = 'Samsung'; aliases = @($kwSamsung, 'Samsung') },
    [pscustomobject]@{ label = 'NVIDIA'; aliases = @($kwNvidia, $kwHuang, 'NVIDIA', 'NVDA') },
    [pscustomobject]@{ label = 'TSMC'; aliases = @($kwTsmc, 'TSMC') },
    [pscustomobject]@{ label = 'ASML'; aliases = @('ASML') },
    [pscustomobject]@{ label = 'Applied Materials'; aliases = @('AMAT', 'Applied Materials') },
    [pscustomobject]@{ label = 'KLA'; aliases = @('KLA') },
    [pscustomobject]@{ label = 'Lam Research'; aliases = @('LRCX', 'Lam Research') },
    [pscustomobject]@{ label = 'Tokyo Electron'; aliases = @('Tokyo Electron') },
    [pscustomobject]@{ label = 'SpaceX'; aliases = @('SpaceX') },
    [pscustomobject]@{ label = 'Tesla'; aliases = @('Tesla', 'TSLA') },
    [pscustomobject]@{ label = 'PLTR'; aliases = @('PLTR', 'Palantir') },
    [pscustomobject]@{ label = 'Microsoft'; aliases = @('Microsoft', 'MSFT') },
    [pscustomobject]@{ label = 'Meta'; aliases = @('Meta', 'META') },
    [pscustomobject]@{ label = 'Donald Trump'; aliases = @($kwTrump, 'Trump') },
    [pscustomobject]@{ label = 'Federal Reserve'; aliases = @($kwFedCn, $kwFedTw, 'Fed', 'Federal Reserve') },
    [pscustomobject]@{ label = 'Sanae Takaichi'; aliases = @($kwTakaichi) },
    [pscustomobject]@{ label = 'Elon Musk'; aliases = @('Elon', 'Musk') },
    [pscustomobject]@{ label = 'Moomoo'; aliases = @('moomoo') },
    [pscustomobject]@{ label = 'Futu'; aliases = @('Futu') }
)

$stanceRules = @(
    [pscustomobject]@{ label = 'tutorial'; aliases = @($kwTeaching, $kwCourse, 'EP', 'tutorial', 'guide', 'how to') },
    [pscustomobject]@{ label = 'workflow-template'; aliases = @($kwAutomation, $kwSkill, 'template', 'workflow', 'repo', 'Skill', 'Agent') },
    [pscustomobject]@{ label = 'classroom-practice'; aliases = @($kwClassroom, $kwAssignment, $kwGrade, $kwWorksheet, 'Google Classroom') },
    [pscustomobject]@{ label = 'downloadable-resource'; aliases = @('free download', 'download', 'template', 'pack', 'repo') },
    [pscustomobject]@{ label = 'bullish'; aliases = @($kwRise, $kwSurge, $kwWealth, 'bull', 'rally') },
    [pscustomobject]@{ label = 'risk-warning'; aliases = @($kwCrash, $kwBigDrop, $kwWar, 'risk', 'crash') },
    [pscustomobject]@{ label = 'portfolio-action'; aliases = @($kwBuy, $kwIncrease, $kwAddPosition, $kwHold, $kwRebalance, 'buy', 'hold') },
    [pscustomobject]@{ label = 'strategy-education'; aliases = @($kwStrategy, $kwMethod, $kwScreen, $kwIndicator, 'strategy', 'screening') }
)

if ($ClassificationProfile -eq 'education-tech') {
    $financeTopicLabels = @(
        'AI infrastructure',
        'Memory semiconductors',
        'Semiconductor equipment',
        'SpaceX and private markets',
        'Trump and US policy',
        'Geopolitics and war risk',
        'Japan market',
        'US equities',
        'Taiwan equities',
        'Gold and silver',
        'Brokerage and tools',
        'Buy-the-dip strategy'
    )
    $financeEntityLabels = @(
        'Micron',
        'SK Hynix',
        'Samsung',
        'NVIDIA',
        'TSMC',
        'ASML',
        'Applied Materials',
        'KLA',
        'Lam Research',
        'Tokyo Electron',
        'SpaceX',
        'Tesla',
        'PLTR',
        'Microsoft',
        'Meta',
        'Donald Trump',
        'Federal Reserve',
        'Sanae Takaichi',
        'Elon Musk',
        'Moomoo',
        'Futu'
    )
    $financeStanceLabels = @(
        'bullish',
        'risk-warning',
        'portfolio-action',
        'strategy-education'
    )

    $topicRules = @($topicRules | Where-Object { $financeTopicLabels -notcontains $_.label })
    $entityRules = @($entityRules | Where-Object { $financeEntityLabels -notcontains $_.label })
    $stanceRules = @($stanceRules | Where-Object { $financeStanceLabels -notcontains $_.label })
}

$resolvedIndexPath = Resolve-ProjectRelativePath -Path $IndexPath
if (-not (Test-Path -LiteralPath $resolvedIndexPath -PathType Leaf)) {
    throw "Text source index not found: $resolvedIndexPath"
}

$resolvedOutputDir = Ensure-Directory -Path $OutputDir
$notesDir = Ensure-Directory -Path (Join-Path $resolvedOutputDir 'notes')
$indexRows = New-Object System.Collections.Generic.List[string]
$topicCounts = @{}
$written = 0

Get-Content -LiteralPath $resolvedIndexPath -Encoding UTF8 | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object {
    $row = $_ | ConvertFrom-Json
    $sourcePath = [string]$row.text_source_path
    $content = Get-Content -LiteralPath $sourcePath -Encoding UTF8 -Raw
    $description = Get-SectionText -Content $content -Heading 'Description'
    $transcript = Get-SectionText -Content $content -Heading 'Transcript'
    $searchCorpus = @($row.title, $transcript) -join "`n"

    $topics = @(Get-MatchingLabels -Text $searchCorpus -Rules $topicRules)
    $entities = @(Get-MatchingLabels -Text $searchCorpus -Rules $entityRules)
    $stances = @(Get-MatchingLabels -Text $searchCorpus -Rules $stanceRules)
    $hashtags = @([regex]::Matches($description, '#[\p{L}\p{N}_-]+') | ForEach-Object { $_.Value } | Select-Object -Unique)
    $fallbackNeedles = if ($ClassificationProfile -eq 'education-tech') {
        @('AI', 'Agent', $kwTeaching, $kwMath, $kwCourse, $kwDigitalWhiteboard, $kwBoardGame)
    } else {
        @('AI', $kwUsStocks, $kwStocks, 'investment', 'risk')
    }
    $needles = @($entities + $topics + $hashtags + $fallbackNeedles) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
    $cues = @(if ([string]::IsNullOrWhiteSpace($transcript)) {
        @()
    } else {
        Get-SearchCues -Transcript $transcript -Needles $needles -Limit $CueCount
    })

    if ($topics.Count -eq 0) {
        $topics = @($DefaultTopic)
    }
    if ($stances.Count -eq 0) {
        $stances = @('commentary')
    }

    foreach ($topic in $topics) {
        if (-not $topicCounts.ContainsKey($topic)) {
            $topicCounts[$topic] = 0
        }
        $topicCounts[$topic] += 1
    }

    $safeTitle = Get-SafeFileName -Name ([string]$row.title)
    $noteName = '{0}_{1}_[{2}].md' -f $row.upload_date, $safeTitle, $row.video_id
    $notePath = Join-Path $notesDir $noteName
    $sourceRelative = $sourcePath

    $yamlTopics = Convert-ToYamlList -Items $topics
    $yamlEntities = Convert-ToYamlList -Items $entities
    $yamlStances = Convert-ToYamlList -Items $stances
    $yamlHashtags = Convert-ToYamlList -Items $hashtags

    $entityText = if ($entities.Count -gt 0) { $entities -join ', ' } else { 'no clear company/person extracted' }
    $topicText = $topics -join ', '
    $stanceText = $stances -join ', '
    $cueLines = if (@($cues).Count -gt 0) {
        @($cues | ForEach-Object { "- $_" })
    } else {
        @('- No short transcript cue found; search the source transcript directly.')
    }
    $hashtagLines = if ($hashtags.Count -gt 0) {
        @($hashtags | ForEach-Object { "- $_" })
    } else {
        @('- none')
    }
    $entityLines = if ($entities.Count -gt 0) {
        @($entities | ForEach-Object { "- $_" })
    } else {
        @('- none')
    }

    $cautionText = if ($ClassificationProfile -eq 'education-tech') {
        'Caution: this is a secondary research note from public education/technology material. Verify claims against the original video, official tool documentation, course materials, or primary references before using it.'
    } else {
        'Caution: this is a secondary research note from public source material. Verify claims against the original video, official filings, company reports, market data, primary news, or other primary references before using it.'
    }

    $body = @(
        '---'
        'source_type: youtube_video_secondary_note'
        'workflow_stage: secondary_knowledge'
        "video_id: `"$($row.video_id)`""
        "url: `"$($row.url)`""
        "upload_date: `"$($row.upload_date)`""
        "channel: `"$($row.channel)`""
        "duration_seconds: $($row.duration_seconds)"
        "subtitle_language: `"$($row.subtitle_language)`""
        'topics:'
        $yamlTopics
        'entities:'
        $yamlEntities
        'stances:'
        $yamlStances
        'hashtags:'
        $yamlHashtags
        "source_text_path: `"$sourceRelative`""
        '---'
        ''
        "# $($row.title)"
        ''
        "Source: $($row.url)"
        ''
        '## Summary'
        ''
        "- Material category: $topicText"
        "- Title thesis: $($row.title)"
        "- Main entities to track: $entityText"
        "- Use / stance: $stanceText"
        "- $cautionText"
        ''
        '## Classification'
        ''
        '### Topics'
        ($topics | ForEach-Object { "- $_" })
        ''
        '### Entities'
        $entityLines
        ''
        '### Hashtags'
        $hashtagLines
        ''
        '## Search Terms'
        ''
        (@($topics + $entities + $hashtags + $stances) | Select-Object -Unique | ForEach-Object { "- $_" })
        ''
        '## Transcript Cues'
        ''
        $cueLines
        ''
        '## How To Use'
        ''
        '- For quoting or detailed analysis, open `source_text_path` and inspect the full description/transcript.'
        '- For cross-video research, filter `index.jsonl` by topics, entities, stances, upload_date, or hashtags.'
        '- For fact checking, combine the entity names and upload date with external official sources.'
    ) -join "`n"

    Set-Content -LiteralPath $notePath -Value $body -Encoding UTF8

    $indexRows.Add(([pscustomobject]@{
        video_id = [string]$row.video_id
        title = [string]$row.title
        url = [string]$row.url
        upload_date = [string]$row.upload_date
        transcript_missing = [bool]$row.transcript_missing
        subtitle_language = [string]$row.subtitle_language
        topics = $topics
        entities = $entities
        stances = $stances
        hashtags = $hashtags
        secondary_note_path = $notePath
        source_text_path = $sourcePath
    } | ConvertTo-Json -Compress))

    $written += 1
}

$knowledgeIndexPath = Join-Path $resolvedOutputDir 'index.jsonl'
Set-Content -LiteralPath $knowledgeIndexPath -Value $indexRows -Encoding UTF8

$indexObjects = $indexRows | ForEach-Object { $_ | ConvertFrom-Json }
$tableLines = New-Object System.Collections.Generic.List[string]
$tableLines.Add('| Date | Title | Topics | Entities |')
$tableLines.Add('| --- | --- | --- | --- |')
foreach ($item in ($indexObjects | Sort-Object upload_date -Descending)) {
    $topicsText = ($item.topics -join ', ') -replace '\|', '/'
    $entitiesText = ($item.entities -join ', ') -replace '\|', '/'
    $titleText = ([string]$item.title) -replace '\|', '/'
    $tableLines.Add("| $($item.upload_date) | [$titleText]($($item.secondary_note_path)) | $topicsText | $entitiesText |")
}

$topicLines = New-Object System.Collections.Generic.List[string]
$topicLines.Add('# Topic Index')
$topicLines.Add('')
foreach ($topic in ($topicCounts.Keys | Sort-Object)) {
    $topicLines.Add("- ${topic}: $($topicCounts[$topic])")
}

$readme = @(
    "# $CollectionTitle Secondary Knowledge"
    ''
    "This folder is generated from local text sources listed in ``$IndexPath``."
    ''
    'Use `index.jsonl` for programmatic filtering, `index.md` for browsing, and `notes/` for per-video secondary notes.'
    ''
    'The secondary notes intentionally do not duplicate full transcripts. They preserve source paths so the original transcript remains the evidence layer.'
    ''
    'Regenerate with:'
    ''
    '```powershell'
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-secondary-knowledge.ps1 -IndexPath `"$IndexPath`" -OutputDir `"$OutputDir`" -CollectionTitle `"$CollectionTitle`" -DefaultTopic `"$DefaultTopic`" -ClassificationProfile `"$ClassificationProfile`""
    '```'
) -join "`n"

Set-Content -LiteralPath (Join-Path $resolvedOutputDir 'README.md') -Value $readme -Encoding UTF8
Set-Content -LiteralPath (Join-Path $resolvedOutputDir 'index.md') -Value (@("# $CollectionTitle Index", '') + $tableLines) -Encoding UTF8
Set-Content -LiteralPath (Join-Path $resolvedOutputDir 'topics.md') -Value $topicLines -Encoding UTF8

Write-Host "Wrote $written secondary notes to $notesDir"
Write-Host "Wrote knowledge index to $knowledgeIndexPath"
