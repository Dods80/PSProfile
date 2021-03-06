#Requires -Version 5

# Version 1.3.6

# check if newer version
$gistUrl = "https://api.github.com/gists/b01b44eaf57400f3bead53baab531de3"
$latestVersionFile = [System.IO.Path]::Combine("$HOME",'.latest_profile_version')
$versionRegEx = "# Version (?<version>\d+\.\d+\.\d+)"

if ([System.IO.File]::Exists($latestVersionFile)) {
  $latestVersion = [System.IO.File]::ReadAllText($latestVersionFile)
  $currentProfile = [System.IO.File]::ReadAllText($profile)
  [version]$currentVersion = "0.0.0"
  if ($currentProfile -match $versionRegEx) {
    $currentVersion = $matches.Version
  }

  if ([version] $latestVersion -gt $currentVersion) {
    Write-Verbose "Your version: $currentVersion" -Verbose
    Write-Verbose "New version: $latestVersion" -Verbose
    $choice = Read-Host -Prompt "Found newer profile, install? (Y)"
    if ($choice -eq "Y" -or $choice -eq "") {
      try {
        $gist = Invoke-RestMethod $gistUrl -ErrorAction Stop
        $gistProfile = $gist.Files."profile.ps1".Content
        Set-Content -Path $profile -Value $gistProfile
        Write-Verbose "Installed newer version of profile" -Verbose
        . $profile
        return
      }
      catch {
        # we can hit rate limit issue with GitHub since we're using anonymous
        Write-Verbose -Verbose "Was not able to access gist, try again next time"
      }
    }
  }
}

$profile_initialized = $false

function prompt {

  function Initialize-Profile {
    if ($null -eq $isWindows) {$isWindows = $true}
    $null = Start-ThreadJob -Name "Get version of `$profile from gist" -ArgumentList $gistUrl, $latestVersionFile, $versionRegEx -ScriptBlock {
      param ($gistUrl, $latestVersionFile, $versionRegEx)
    
      try {
        $gist = Invoke-RestMethod $gistUrl -ErrorAction Stop
    
        $gistProfile = $gist.Files."profile.ps1".Content
        [version]$gistVersion = "0.0.0"
        if ($gistProfile -match $versionRegEx) {
          $gistVersion = $matches.Version
          Set-Content -Path $latestVersionFile -Value $gistVersion
        }
      }
      catch {
        # we can hit rate limit issue with GitHub since we're using anonymous
        Write-Verbose -Verbose "Was not able to access gist to check for newer version"
      }
    }
    
    if ([string] (Get-Module PSReadLine).Version -lt 2.1) {
      throw "Profile requires PSReadLine 2.1+"
    }
  
    # setup psdrives
    if ([System.IO.File]::Exists([System.IO.Path]::Combine("$HOME",'test'))) {
      New-PSDrive -Root ~/test -Name Test -PSProvider FileSystem -ErrorAction Ignore > $Null
    }
  
    if (!(Test-Path repos:)) {
      if (Test-Path ([System.IO.Path]::Combine("$HOME",'git'))) {
        New-PSDrive -Root ~/repos -Name git -PSProvider FileSystem > $Null
      }
      elseif (Test-Path "d:\PowerShell") {
        New-PSDrive -Root D:\ -Name git -PSProvider FileSystem > $Null
      }
    }
    
    $ESC = [char]27
    $versionMinimum = [Version]'6.1.999'
    if (($host.Name -eq 'ConsoleHost') -and ($PSVersionTable.PSVersion -ge $versionMinimum))
    {
        Set-PSReadLineOption -Colors @{ Selection = "$ESC[92;7m"; InLinePrediction = "$ESC[36;7;238m" } -PredictionSource HistoryAndPlugin
    } else {
        Set-PSReadLineOption -Colors @{ Selection = "$ESC[92;7m"; InLinePrediction = "$ESC[36;7;238m" } -PredictionSource History
    }
    Set-PSReadLineKeyHandler -Chord Shift+Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord Ctrl+b -Function BackwardWord
    Set-PSReadLineKeyHandler -Chord Ctrl+f -Function ForwardWord
    Set-PSReadLineKeyHandler -Chord DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Chord UpArrow -Function HistorySearchBackward
    
    # Sometimes you enter a command but realize you forgot to do something else first.
    # This binding will let you save that command in the history so you can recall it,
    # but it doesn't actually execute.  It also clears the line with RevertLine so the
    # undo stack is reset - though redo will still reconstruct the command line.
    Set-PSReadLineKeyHandler -Key Alt+w `
                         -BriefDescription SaveInHistory `
                         -LongDescription "Save current line in history but do not execute" `
                         -ScriptBlock {
        param($key, $arg)

        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory($line)
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    }
  
    if ($IsWindows) {
      Set-PSReadLineOption -EditMode Emacs -ShowToolTips
      Set-PSReadLineKeyHandler -Chord Ctrl+Shift+c -Function Copy
      Set-PSReadLineKeyHandler -Chord Ctrl+Shift+v -Function Paste
    }
    else {
      #try {
      #  Import-UnixCompleters
      #}
      #catch [System.Management.Automation.CommandNotFoundException]
      #{
      #  Install-Module Microsoft.PowerShell.UnixCompleters -Repository PSGallery -AcceptLicense -Force
      #  Import-UnixCompleters
      #}
    }
  
    # add path to dotnet global tools
    $env:PATH += [System.IO.Path]::PathSeparator + [System.IO.Path]::Combine("$HOME",'.dotnet','tools')
  
    # ensure dotnet cli is in path
    $dotnet = Get-Command dotnet -CommandType Application -ErrorAction Ignore
    if ($null -eq $dotnet) {
      if ([System.IO.File]::Exists("$HOME/.dotnet/dotnet")){
        $env:PATH += [System.IO.Path]::PathSeparator+ [System.IO.Path]::Combine("$HOME",'.dotnet')
      }
    }
  
    $global:profile_initialized = $true
  }

  if (!$profile_initialized) {
    Initialize-Profile
    Set-PSReadLineKeyHandler -Chord DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Chord UpArrow -Function HistorySearchBackward
    # Sometimes you enter a command but realize you forgot to do something else first.
    # This binding will let you save that command in the history so you can recall it,
    # but it doesn't actually execute.  It also clears the line with RevertLine so the
    # undo stack is reset - though redo will still reconstruct the command line.
    Set-PSReadLineKeyHandler -Key Alt+w `
                         -BriefDescription SaveInHistory `
                         -LongDescription "Save current line in history but do not execute" `
                         -ScriptBlock {
        param($key, $arg)

        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory($line)
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    }
  }

  $currentLastExitCode = $LASTEXITCODE
  $lastSuccess = $?
  $ESC = [char]27
  $color = @{
    Reset = "$ESC[0m"
    Red = "$ESC[31;1m"
    Green = "$ESC[32;1m"
    Yellow = "$ESC[33;1m"
    Grey = "$ESC[37;0m"
    White = "$ESC[37;1m"
    Invert = "$ESC[7m"
    RedBackground = "$ESC[41m"
  }

  # set color of PS based on success of last execution
  if ($lastSuccess -eq $false) {
    $lastExit = $color.Red
  } else {
    $lastExit = $color.Green
  }


  # get the execution time of the last command
  $lastCmdTime = ""
  $lastCmd = Get-History -Count 1
  if ($null -ne $lastCmd) {
    $cmdTime = ($lastCmd.EndExecutionTime - $lastcmd.StartExecutionTime).TotalMilliseconds
    $units = "ms"
    $timeColor = $color.Green
    if ($cmdTime -gt 250 -and $cmdTime -lt 1000) {
      $timeColor = $color.Yellow
    } elseif ($cmdTime -ge 1000) {
      $timeColor = $color.Red
      $units = "s"
      $cmdTime = ($lastCmd.EndExecutionTime - $lastcmd.StartExecutionTime).TotalSeconds
      if ($cmdTime -ge 60) {
        $units = "m"
        $cmdTIme = ($lastCmd.EndExecutionTime - $lastcmd.StartExecutionTime).TotalMinutes
      }
    }

    $lastCmdTime = "$($color.Grey)[$timeColor$($cmdTime.ToString("#.##"))$units$($color.Grey)]$($color.Reset) "
  }


  # get git branch information if in a git folder or subfolder
  $gitBranch = ""
  $path = Get-Location
  while ($path -ne "") {
    if (Test-Path ([System.IO.Path]::Combine($path,'.git'))) {
      # need to do this so the stderr doesn't show up in $error
      $ErrorActionPreferenceOld = $ErrorActionPreference
      $ErrorActionPreference = 'Ignore'
      $branch = git rev-parse --abbrev-ref --symbolic-full-name '@{u}'
      $ErrorActionPreference = $ErrorActionPreferenceOld

      # handle case where branch is local
      if ($lastexitcode -ne 0 -or $null -eq $branch) {
        $branch = git rev-parse --abbrev-ref HEAD
      }

      $branchColor = $color.Green

      if ($branch -match "/master") {
        $branchColor = $color.Red
      }
      $gitBranch = " $($color.Grey)[$branchColor$branch$($color.Grey)]$($color.Reset)"
      break
    }

    $path = Split-Path -Path $path -Parent
  }

  # truncate the current location if too long
  $currentDirectory = $executionContext.SessionState.Path.CurrentLocation.Path
  $consoleWidth = [Console]::WindowWidth
  $maxPath = [int]($consoleWidth / 2)
  if ($currentDirectory.Length -gt $maxPath) {
    $currentDirectory = "`u{2026}" + $currentDirectory.SubString($currentDirectory.Length - $maxPath)
  }

  # check if running dev built pwsh
  $devBuild = ''
  if ($PSHOME.Contains("publish")) {
    $devBuild = " $($color.White)$($color.RedBackground)DevPwsh$($color.Reset)"
  }

  "${lastCmdTime}${currentDirectory}${gitBranch}${devBuild}`n${lastExit}PS$($color.Reset)$('>' * ($nestedPromptLevel + 1)) "

  # set window title
  try {
    $prefix = ''
    if ($isWindows) {
      $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
      $windowsPrincipal = [Security.Principal.WindowsPrincipal]::new($identity)
      if ($windowsPrincipal.IsInRole("Administrators") -eq 1) {
        $prefix = "Admin:"
      }
    }

    $Host.ui.RawUI.WindowTitle = "$prefix$PWD"
  } catch {
    # do nothing if can't be set
  }

  $global:LASTEXITCODE = $currentLastExitCode
}
