# Ortak calisma kurulumu (Windows)
# Calistirma: PowerShell'i acip su satiri yapistirin:
#   irm https://aygundeniiz.github.io/kontrol-merkezi/kurulum.ps1 | iex
# Not: Bu dosya bilerek Turkce karakter kullanmiyor (Windows PowerShell kodlama sorunlari icin).

# Windows PowerShell 5.1, git/gh'nin normal uyari ciktilarini (stderr) hata sanip betigi durdurmasin diye
# 'Continue' kullaniliyor; gercek hatalar asagida $LASTEXITCODE ile kontrol edilip throw ediliyor.
$ErrorActionPreference = 'Continue'
$Repo = 'aygundeniiz/ortak-calisma'          # ornek: kullanici/ortak-calisma
$PanelAdresi = 'https://aygundeniiz.github.io/kontrol-merkezi/'

function Adim($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Tamam($m) { Write-Host "    OK  $m" -ForegroundColor Green }
function Var($k) { [bool](Get-Command $k -ErrorAction SilentlyContinue) }
function YoluYenile { $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User') }

Write-Host "Ortak calisma kurulumu basliyor. Birkac dakika surer." -ForegroundColor Yellow

# 1) Gerekli programlar
Adim "Gerekli programlar kontrol ediliyor (Git, GitHub CLI, Node.js)"
$paketler = @(
  @{ komut='git';  id='Git.Git' },
  @{ komut='gh';   id='GitHub.cli' },
  @{ komut='node'; id='OpenJS.NodeJS.LTS' }
)
foreach ($p in $paketler) {
  if (Var $p.komut) { Tamam "$($p.komut) zaten kurulu" }
  else {
    Write-Host "    $($p.id) kuruluyor..."
    winget install --id $p.id -e --accept-source-agreements --accept-package-agreements --silent | Out-Null
    YoluYenile
    if (Var $p.komut) { Tamam "$($p.komut) kuruldu" } else { throw "$($p.id) kurulamadi. PowerShell'i kapatip acin ve tekrar deneyin." }
  }
}

# 2) Claude Code
Adim "Claude Code kontrol ediliyor"
if (Var 'claude') { Tamam "Claude Code zaten kurulu" }
else {
  irm https://claude.ai/install.ps1 | iex
  YoluYenile
  $env:Path += ";$env:USERPROFILE\.local\bin"
  if (Var 'claude') { Tamam "Claude Code kuruldu" } else { Write-Host "    Claude Code kurulumu tamamlanamadi, sonra 'claude' yazip kontrol edin." -ForegroundColor Yellow }
}

# 3) GitHub girisi
Adim "GitHub hesabina giris"
$null = cmd /c "gh auth status >nul 2>&1"
if ($LASTEXITCODE -ne 0) {
  Write-Host "    Tarayicida GitHub acilacak. Ekrandaki 8 haneli kodu girip 'Authorize' deyin."
  gh auth login --hostname github.com --git-protocol https --web
  $null = cmd /c "gh auth status >nul 2>&1"
  if ($LASTEXITCODE -ne 0) { throw "GitHub girisi tamamlanamadi. Ayni satiri tekrar calistirin." }
}
$null = cmd /c "gh auth setup-git >nul 2>&1"
Tamam "GitHub girisi tamam ($(gh api user --jq .login))"

# 4) Git kimligi
Adim "Git kimligi"
$ad = Read-Host "    Adin (tam olarak: Deniz ya da Mata)"
if (-not (git config --global user.name)) { git config --global user.name $ad }
if (-not (git config --global user.email)) {
  $ghId = gh api user --jq .id
  $login = gh api user --jq .login
  git config --global user.email "$ghId+$login@users.noreply.github.com"
}
Tamam "Git kimligi: $(git config --global user.name)"

# 5) Repoyu indir
Adim "Ortak repo indiriliyor"
$anaKlasor = Join-Path $env:OneDrive 'YAPAY ZEKA MASTERCLASS'
if (-not $env:OneDrive -or -not (Test-Path $anaKlasor)) { $anaKlasor = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'YAPAY ZEKA MASTERCLASS' }
New-Item -ItemType Directory -Force -Path $anaKlasor | Out-Null
$hedef = Join-Path $anaKlasor ($Repo.Split('/')[1])
if (Test-Path (Join-Path $hedef '.git')) { $null = cmd /c "git -C `"$hedef`" pull >nul 2>&1"; Tamam "Repo zaten vardi, guncellendi" }
else {
  $null = cmd /c "gh repo clone $Repo `"$hedef`" 2>&1"
  if ($LASTEXITCODE -ne 0) { throw "Repo indirilemedi. GitHub'dan gelen davet e-postasini kabul ettiginizden emin olun: https://github.com/$Repo/invitations" }
  Tamam "Repo indirildi"
}

# 6) Kontrol merkezi baglantisi ve otomatik senkron
Adim "Kontrol merkezi baglantisi kuruluyor"
$b = Get-Content (Join-Path $hedef 'kurulum\baglanti.json') -Raw | ConvertFrom-Json
git -C $hedef config core.hooksPath .githooks
git -C $hedef config ortak.supabaseUrl $b.supabaseUrl
git -C $hedef config ortak.anonKey $b.anonKey
git -C $hedef config ortak.ad $ad
git -C $hedef config user.name $ad
git -C $hedef config pull.rebase true
git -C $hedef config rebase.autoStash true
Tamam "Bu laptop '$ad ($env:COMPUTERNAME)' olarak kaydedilecek"
Tamam "Claude her mesajda otomatik kaydedip senkronlayacak; ayni anda calisabilirsiniz"

Write-Host "`nKurulum bitti!" -ForegroundColor Green
Write-Host "Calisma klasoru: $hedef"
Write-Host "Baslamak icin:  cd `"$hedef`"  sonra  claude"
Write-Host "Kontrol merkezi: $PanelAdresi (e-posta adresinizle giris yapin)"
Start-Process $PanelAdresi
