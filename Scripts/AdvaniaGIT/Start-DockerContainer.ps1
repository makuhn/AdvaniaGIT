﻿function Start-DockerContainer
{
    param
    (
    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyname=$true)]
    [PSObject]$SetupParameters,
    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyname=$true)]
    [PSObject]$BranchSettings,
    [Parameter(Mandatory=$False, ValueFromPipelineByPropertyname=$true)]
    [String]$AdminPassword
    )
    
    $DockerSettings = Get-DockerSettings 
    Write-Host "Connecting to repository $($DockerSettings.RepositoryPath)..."
    if ($DockerSettings.RepositoryPassword -gt "") {
        try {
            docker.exe login $($DockerSettings.RepositoryPath) -u $($DockerSettings.RepositoryUserName) -p $($DockerSettings.RepositoryPassword)
        }
        catch {
            Write-Host -ForegroundColor Red "Unable to login to docker repository: $($DockerSettings.RepositoryPath)"
        }

    }

    if ($AdminPassword -eq "") {
        $DockerCredentials = Get-DockerAdminCredentials -Message "Enter credentials for the Docker Container" -DefaultUserName $env:USERNAME
        $adminUsername = $DockerCredentials.UserName
        $AdminPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($DockerCredentials.Password))
    } else {
        $adminUsername = $env:USERNAME        
    }

    Write-Host "Preparing Docker Container for Dynamics NAV..."    
    $volume = "$($SetupParameters.Repository):C:\GIT"
    $rootPath = "$($SetupParameters.rootPath):C:\Host"
    $image = $SetupParameters.dockerImage
    docker.exe pull $image
    $DockerContainerId = docker.exe run -m 5G -v "$volume" -v "$rootPath" -e ACCEPT_EULA=Y -e username="$adminUsername" -e password="$AdminPassword" -e auth=Windows --detach $image
    Write-Host "Docker Container $DockerContainerId starting..."
    $Session = New-DockerSession -DockerContainerId $DockerContainerId
    $DockerContainerName = Get-DockerContainerName -Session $Session

    $WaitForHealty = $true
    $LoopNo = 1
    while ($WaitForHealty -and $LoopNo -lt 20) {        
        $dockerContainer = Get-DockerContainers | Where-Object -Property Id -ieq $DockerContainerName
        Write-Host "Container status: $($dockerContainer.Status)..."
        $WaitForHealty = $dockerContainer.Status -match "(health: starting)" -or $dockerContainer.Status -match "(unhealthy)"
        if ($WaitForHealty) { Start-Sleep -Seconds 10 }
        $LoopNo ++
    }
    if (!($dockerContainer.Status -match "(healthy)")) {
        Write-Error "Container $DockerContainerName unable to start !" -ErrorAction Stop
    }


    $DockerSettings = Install-DockerAdvaniaGIT -Session $Session -SetupParameters $SetupParameters -BranchSettings $BranchSettings 
    Edit-DockerHostRegiststration -AddHostName $DockerContainerName -AddIpAddress (Get-DockerIPAddress -Session $Session)

    $BranchSettings.databaseServer = $DockerContainerName
    $BranchSettings.dockerContainerName = $DockerContainerName
    $BranchSettings.dockerContainerId = $DockerContainerId
    $BranchSettings.clientServicesPort = $DockerSettings.BranchSettings.clientServicesPort
    $BranchSettings.managementServicesPort = $DockerSettings.BranchSettings.managementServicesPort
    $BranchSettings.developerServicesPort = $DockerSettings.BranchSettings.developerServicesPort
    $BranchSettings.databaseInstance = $DockerSettings.BranchSettings.databaseInstance
    $BranchSettings.databaseName = $DockerSettings.BranchSettings.databaseName
    $BranchSettings.instanceName = $DockerSettings.BranchSettings.instanceName

    Update-BranchSettings -BranchSettings $BranchSettings
    Remove-PSSession -Session $Session 
}
