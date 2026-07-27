param(
    [switch]$NoOpen,
    [switch]$SkipInstall,
    [switch]$ForceSync
)

$ErrorActionPreference = "Stop"

if ($SkipInstall -and $ForceSync) {
    throw "-SkipInstall and -ForceSync cannot be used together."
}

$ProjectDir = $PSScriptRoot
$VenvDir = Join-Path $ProjectDir ".venv"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$VenvNbconvert = Join-Path $VenvDir "Scripts\jupyter-nbconvert.exe"
$Notebook = Join-Path $ProjectDir "final_project.ipynb"
$Requirements = Join-Path $ProjectDir "requirements.txt"
$Pyproject = Join-Path $ProjectDir "pyproject.toml"
$Lockfile = Join-Path $ProjectDir "uv.lock"
$Validator = Join-Path $ProjectDir "scripts\validate_project.py"
$ToolsDir = Join-Path $ProjectDir ".tools"

foreach ($RequiredFile in @($Notebook, $Requirements, $Pyproject, $Lockfile, $Validator)) {
    if (-not (Test-Path $RequiredFile -PathType Leaf)) {
        throw "Required file not found: $RequiredFile"
    }
}

Write-Host "Detected Windows."

function Test-Python312 {
    param([string]$Executable, [string[]]$PrefixArguments = @())
    if (-not (Test-Path $Executable) -and -not (Get-Command $Executable -ErrorAction SilentlyContinue)) {
        return $false
    }
    & $Executable @PrefixArguments -c "import sys; raise SystemExit(sys.version_info[:2] != (3, 12))"
    return $LASTEXITCODE -eq 0
}

function Get-UvExecutable {
    New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null
    $LocalUv = Join-Path $ToolsDir "uv.exe"
    if (Test-Path $LocalUv -PathType Leaf) {
        return $LocalUv
    }

    $SystemUv = Get-Command uv -ErrorAction SilentlyContinue
    if ($SystemUv) {
        return $SystemUv.Source
    }

    Write-Host "Installing the uv dependency manager..."
    $UvInstaller = Join-Path $ToolsDir "uv-installer.ps1"
    Invoke-WebRequest -UseBasicParsing `
        -Uri "https://astral.sh/uv/install.ps1" `
        -OutFile $UvInstaller
    $env:UV_INSTALL_DIR = $ToolsDir
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $UvInstaller

    if (-not (Test-Path $LocalUv -PathType Leaf)) {
        throw "uv could not be installed."
    }
    return $LocalUv
}

$PythonExecutable = $null
$PythonPrefixArguments = @()
$UvExecutable = $null

if (Get-Command py -ErrorAction SilentlyContinue) {
    if (Test-Python312 "py" @("-3.12")) {
        $PythonExecutable = "py"
        $PythonPrefixArguments = @("-3.12")
    }
}

if (-not $PythonExecutable -and (Get-Command python3.12 -ErrorAction SilentlyContinue)) {
    if (Test-Python312 "python3.12") {
        $PythonExecutable = "python3.12"
    }
}

if (-not $PythonExecutable) {
    Write-Host "Python 3.12 was not found."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Installing Python 3.12 with Windows Package Manager..."
        & winget install --exact --id Python.Python.3.12 `
            --accept-package-agreements --accept-source-agreements

        $InstalledPython = Join-Path $env:LOCALAPPDATA "Programs\Python\Python312\python.exe"
        if (Test-Python312 $InstalledPython) {
            $PythonExecutable = $InstalledPython
        }
        elseif (Get-Command py -ErrorAction SilentlyContinue) {
            if (Test-Python312 "py" @("-3.12")) {
                $PythonExecutable = "py"
                $PythonPrefixArguments = @("-3.12")
            }
        }
    }
}

if (-not $PythonExecutable) {
    Write-Host "Windows Package Manager did not provide Python 3.12. Using the local Python manager fallback..."
    $UvExecutable = Get-UvExecutable

    if (Test-Path $UvExecutable) {
        & $UvExecutable python install 3.12
        $FoundPython = (& $UvExecutable python find 3.12 | Select-Object -Last 1).Trim()
        if (Test-Python312 $FoundPython) {
            $PythonExecutable = $FoundPython
        }
    }
}

if (-not $PythonExecutable) {
    throw "Python 3.12 could not be installed automatically. Check the network connection and run this script again."
}

$UvExecutable = Get-UvExecutable
$PythonVersion = & $PythonExecutable @PythonPrefixArguments --version
Write-Host "Using $PythonVersion."

if (Test-Path $VenvPython) {
    if (-not (Test-Python312 $VenvPython)) {
        Write-Host "Recreating .venv because it does not use Python 3.12..."
        Remove-Item -Recurse -Force $VenvDir
    }
}

if (-not (Test-Path $VenvPython)) {
    Write-Host "Creating virtual environment in .venv..."
    & $PythonExecutable @PythonPrefixArguments -m venv $VenvDir
}
else {
    Write-Host "Using existing Python 3.12 virtual environment."
}

New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null
$env:PIP_DISABLE_PIP_VERSION_CHECK = "1"
$env:PIP_CACHE_DIR = Join-Path $ToolsDir "pip-cache"
$env:UV_CACHE_DIR = Join-Path $ToolsDir "uv-cache"
$env:MPLCONFIGDIR = Join-Path $ToolsDir "matplotlib"
$env:IPYTHONDIR = Join-Path $ToolsDir "ipython"
New-Item -ItemType Directory -Force -Path $env:PIP_CACHE_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $env:UV_CACHE_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $env:MPLCONFIGDIR | Out-Null
New-Item -ItemType Directory -Force -Path $env:IPYTHONDIR | Out-Null

$LockFingerprint = & $PythonExecutable @PythonPrefixArguments -c `
    "import hashlib, pathlib, sys; h=hashlib.sha256(); [h.update(pathlib.Path(p).read_bytes()) for p in sys.argv[1:]]; print(h.hexdigest())" `
    $Pyproject $Lockfile
$FingerprintFile = Join-Path $VenvDir ".dependency-lock.sha256"
$EnvironmentMatches = $false

if (
    (Test-Path $VenvPython -PathType Leaf) -and
    (Test-Path $VenvNbconvert -PathType Leaf) -and
    (Test-Path $FingerprintFile -PathType Leaf) -and
    (Test-Python312 $VenvPython)
) {
    $SavedFingerprint = (Get-Content $FingerprintFile -Raw).Trim()
    $EnvironmentMatches = $SavedFingerprint -eq $LockFingerprint.Trim()
}

if ($SkipInstall) {
    if (-not $EnvironmentMatches) {
        throw "The environment is missing or out of date. Run without -SkipInstall."
    }
    Write-Host "Using the matching locked environment (-SkipInstall)."
}
elseif ($ForceSync -or -not $EnvironmentMatches) {
    Write-Host "Synchronizing the environment from uv.lock..."
    & $UvExecutable sync --frozen --python 3.12
    Set-Content -Path $FingerprintFile -Value $LockFingerprint.Trim() -Encoding ascii
}
else {
    Write-Host "Dependency lock unchanged; using the existing environment."
}

Write-Host "Executing every cell in final_project.ipynb..."
& $VenvNbconvert `
    --to notebook `
    --execute $Notebook `
    --output $Notebook `
    --ExecutePreprocessor.timeout=1200

Write-Host "Notebook execution completed successfully."
Write-Host "Validating the executed project..."
& $VenvPython $Validator

if ($NoOpen) {
    Write-Host "JupyterLab launch skipped (-NoOpen)."
    exit 0
}

Write-Host "Starting JupyterLab..."
& $VenvPython -m jupyterlab --notebook-dir=$ProjectDir $Notebook
