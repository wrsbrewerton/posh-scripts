<#
    .SYNOPSIS
        Stops or starts ARM based VMs in a given Resource Group that do not contain '01' in the name

    .DESCRIPTION
        Stops any VM that does not contain '01' in the specified resource group
        Starts any stopped VMs in the specified resource group
        Any VM(s) that have '01' in the name will not be affected

    .PARAMETER SubscriptionName
        The Azure subscription name

    .PARAMETER ResourceGroup
        The Azure resource group name

    .PARAMETER Action
        The action to take (stop or start)

    .NOTES
        Version: 1.0
        Author: Scott Brewerton
        Creation Date:  20180424
#>

Param
(
    [String][Parameter(Mandatory=$true)]$SubscriptionName,
    [String][Parameter(Mandatory=$true)]$ResourceGroup,
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateSet("Stop","Start","stop","start")]
    [String]$Action
)

$UserName = Read-Host -Prompt "Azure logon name ?"
$SecurePass = Read-Host -AsSecureString -Prompt "Azure password ?"
$Creds = New-Object -TypeName System.Management.Automation.PSCredential ($UserName, $SecurePass)

Add-AzureAccount -Credential $Creds

$Action = $Action.ToLower()

# In workflow scenarios, the thread can sometimes be rehydrated in a different app domain, depending on the workflow runtime
# This removes the need to authenticate repeatedly inside the workflow loop
Enable-AzureRmContextAutosave

Workflow Start-Stop-ARM-VMs
{
    Param
    (
        [String]$SubscriptionName,
        [String]$ResourceGroup,
        [String]$Action
    )

    Get-AzureRmSubscription |  Where-Object SubscriptionName -eq $SubscriptionName | Select-AzureRmSubscription

    Write-Output "Getting VMs...."
    $VMs = Get-AzureRmVM -ResourceGroupName $ResourceGroup -Status | Where-Object -Property Name -NotLike "*01*" | Select-Object -Property Name,PowerState

    $VMs

    Switch -CaseSensitive ($Action)
    {
        start
        {
            Foreach -parallel ($VM in $VMs)
            {
                If ($VM.PowerState -ne "Running")
                {
                    #Connect-AzureRmAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint
                    Write-Output "Starting virtual machine..." $VM.Name
                    Start-AzureRmVM -Name $VM.Name -ResourceGroupName $ResourceGroup
                }
            }
        }
        stop
        {
            Foreach -parallel ($VM in $VMs)
            {
                If($VM.PowerState -ne "VM deallocated")
                {
                    #Connect-AzureRmAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint
                    Write-Output "Stopping virtual machine..." $VM.Name
                    Stop-AzureRmVM -Name $VM.Name -ResourceGroupName $ResourceGroup -Force
                }
            }
        }
    }
}

    # Call the workflow passing SubscriptionName, ResourceGroupName and the Action to stop/start
    Start-Stop-ARM-VMs -SubscriptionName $SubscriptionName -ResourceGroup $ResourceGroup -Action $Action