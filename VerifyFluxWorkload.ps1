param(
    [string]$EnvName,
    [string]$SpaceName,
    [string]$ServiceName,
    [string]$ImageName,
    [string]$ImageTag,
    [string]$AcrName,
    [string]$AcrPwd,
    [string]$WorkloadType
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
Install-Module powershell-yaml -AllowClobber -Confirm:$false -Force
Import-Module powershell-yaml -Force

function Retry {
    [CmdletBinding()]
    param(
        [int]$MaxRetries = 3,
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        [int]$RetryDelay = 10,
        [bool]$LogError = $true
    )

    $isSuccessful = $false
    $retryCount = 0
    $prevErrorActionPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    while (!$IsSuccessful -and $retryCount -lt $MaxRetries) {
        try {
            $ScriptBlock.Invoke()
            $isSuccessful = $true
        }
        catch {
            $retryCount++

            if ($LogError) {
                Write-Host $_.Exception.InnerException.Message
                Write-Host "failed after $retryCount attempt, wait $RetryDelay seconds and retry"
            }

            Start-Sleep -Seconds $RetryDelay
        }
    }
    $ErrorActionPreference = $prevErrorActionPref
    return $isSuccessful
}

$serviceWorkloadYamlFile = "./generated/$EnvName/$SpaceName/svc/$ServiceName/$WorkloadType.yaml"
Write-Host "Checking repo update in file: $serviceWorkloadYamlFile"
if (-not (Test-Path $serviceWorkloadYamlFile)) {
    throw "Unable to find service workload yaml file: $serviceWorkloadYamlFile"
}

Write-Host "Login to acr: $AcrName"
$AcrPwd | docker login "$AcrName.azurecr.io" --username $AcrName --password-stdin | Out-Null

$newlyPublishedImage = az acr repository show -n $AcrName -t "$($ImageName):$($ImageTag)" | ConvertFrom-Json
$digestToMatch = $newlyPublishedImage.digest

$imageDeployed = Retry(30) {
    git pull -f 
    $workloadInRepo = Get-Content $serviceWorkloadYamlFile -Raw | ConvertFrom-Yaml -Ordered
    $imageFound = $null 
    if ($WorkloadType -ieq "cronjob") {
        $imageFound = $workloadInRepo.spec.jobTemplate.spec.template.spec.containers[0].image
    }
    elseif ($WorkloadType -ieq "deployment") {
        $imageFound = $workloadInRepo.spec.template.spec.containers[0].image
    }
    else {
        throw "workload type $WorkloadType is not supported"
    }
    if ($null -eq $imageFound -or $imageFound -eq "") {
        throw "Unable to find image defined in workload yaml file"
    }

    $imageTagFound = $imageFound.Substring($imageFound.LastIndexOf(":") + 1)
    Write-Host "image in repo: $imageFound"
    if ($imageFound -eq "$($AcrName).azurecr.io/$($ImageName):$($ImageTag)") {
        Write-Host "image tag matched in repo"
        return
    }
    else {
        Write-Host "image tag not matched, found $imageTagFound, expecting $ImageTag"
    }
    
    $deployedImage = az acr repository show -n $AcrName -t "$($ImageName):$($imageTagFound)" | ConvertFrom-Json
    if ($deployedImage.digest -eq $digestToMatch) {
        Write-Host "image digest matched in repo"
        return
    }
    else {
        Write-Host "image digest not matched, found $($deployedImage.digest), expecting $digestToMatch"
    }

    throw "not found, retry..."
}

if (!$imageDeployed) {
    Write-Warning "Image '$ImageName' with tag '$ImageTag' is not deployed"
}