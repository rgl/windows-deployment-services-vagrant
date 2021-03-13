param(
    [Parameter(Mandatory=$true)]
    [string]$script,

    [Parameter(Mandatory=$false, ValueFromRemainingArguments=$true)]
    [string[]]$scriptArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
trap {
    Write-Output "ERROR: $_"
    Write-Output (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Output (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Exit 1
}

# wrap the choco command (to make sure this script aborts when it fails).
function Start-Choco([string[]]$Arguments, [int[]]$SuccessExitCodes=@(0)) {
    $command, $commandArguments = $Arguments
    if ($command -eq 'install') {
        $Arguments = @($command, '--no-progress') + $commandArguments
    }
    for ($n = 0; $n -lt 10; ++$n) {
        if ($n) {
            # NB sometimes choco fails with "The package was not found with the source(s) listed."
            #    but normally its just really a transient "network" error.
            Write-Host "Retrying choco install..."
            Start-Sleep -Seconds 3
        }
        &C:\ProgramData\chocolatey\bin\choco.exe @Arguments
        if ($SuccessExitCodes -Contains $LASTEXITCODE) {
            return
        }
    }
    throw "$(@('choco')+$Arguments | ConvertTo-Json -Compress) failed with exit code $LASTEXITCODE"
}
function choco {
    Start-Choco $Args
}

function Start-PowerShellScriptAs([string]$username, [string]$password, [string]$script) {
    if (!(Get-Command -ErrorAction SilentlyContinue nssm)) {
        choco install -y nssm
    }
    # NB we have to manually create the service to run as gitlab-runner because psexec 2.32 is fubar.
    $serviceName = "pssas$((Get-Date).Ticks)"
    $serviceHome = "C:\tmp\$serviceName"
    $serviceLogPath = "$serviceHome\service.log"
    mkdir $serviceHome | Out-Null
    $acl = Get-Acl $serviceHome
    $acl.AddAccessRule((
        New-Object `
            Security.AccessControl.FileSystemAccessRule(
                $username,
                'FullControl',
                'ContainerInherit,ObjectInherit',
                'None',
                'Allow')))
    Set-Acl $serviceHome $acl
    Set-Content "$serviceHome\script.ps1" $script
    nssm install $serviceName PowerShell.exe | Out-Null
    nssm set $serviceName AppParameters `
        '-NoLogo' `
        '-NoProfile' `
        '-ExecutionPolicy Bypass' `
        '-File script.ps1' `
        | Out-Null
    nssm set $serviceName ObjectName $username $password | Out-Null
    nssm set $serviceName AppStdout $serviceLogPath | Out-Null
    nssm set $serviceName AppStderr $serviceLogPath | Out-Null
    nssm set $serviceName AppDirectory $serviceHome | Out-Null
    nssm set $serviceName AppExit Default Exit | Out-Null
    Start-Service $serviceName
    $line = 0
    do {
        Start-Sleep -Seconds 1
        if (Test-Path $serviceLogPath) {
            Get-Content $serviceLogPath | Select-Object -Skip $line | ForEach-Object {
                ++$line
                Write-Output $_
            }
        }
    } while ((Get-Service $serviceName).Status -ne 'Stopped')
    nssm remove $serviceName confirm | Out-Null
    Remove-Item -Recurse $serviceHome
}

Set-Location c:\vagrant\provision

$script = Resolve-Path $script

Set-Location (Split-Path -Parent $script)

Write-Host "Running $script..."

. ".\$(Split-Path -Leaf $script)" @scriptArguments
