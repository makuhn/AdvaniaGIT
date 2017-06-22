﻿Function Configure-NAVRemoteInstanceTenantSettings {
    param(
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyname=$true)]
        [System.Management.Automation.Runspaces.PSSession]$Session,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyname=$true)]
        [System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyname=$true)]
        [String]$DeploymentName,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyname=$true)]
        [PSObject]$SelectedTenant
    )
    PROCESS
    {
    $TenantSettings = Get-NAVRemoteInstanceTenantSettings -Session $Session -SelectedTenant $SelectedTenant
    $NewTenantSettings = New-TenantSettingsDialog -Message "Edit Tenant Settings" -TenantSettings $TenantSettings -TenantIdNotEditable
    $SelectedTenant = Combine-Settings $NewTenantSettings $SelectedTenant
    $RemoteTenantSettings = Set-NAVRemoteInstanceTenantSettings -Session $Session -Credential $Credential -SelectedTenant $SelectedTenant -DeploymentName $DeploymentName   
    Return $SelectedTenant
    }

}