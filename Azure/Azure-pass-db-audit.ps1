<#
    .SYNOPSIS
        Azure PaaS DB Audit
    
    .DESCRIPTION
        Retrieves metadata for all Azure PaaS DBs in all WorldRemit subscriptions (CSRE-1810)
    
    .PARAMETERS
        None
    
    .EXAMPLE
        ./Azure-pass-db-audit.ps1
    
    .DEPENDENCIES
        None
    
    .NOTES
        Version: 1.0
        Author: Scott Brewerton
        Creation Date:  20180109
#>


$AzureSubs = Get-AzureRmSubscription | Sort-Object -Property Name
$DBs = @()
$AllDbs = @()

Foreach ($Sub in $AzureSubs)
{
    Select-AzureRmSubscription -SubscriptionId $Sub.SubscriptionId
    $SQLServers  = Get-AzureRmSqlServer

    Foreach ($Server in $SQLServers)
    {
        $DBs = Get-AzureRmSqlDatabase -ServerName $Server.ServerName -ResourceGroupName $Server.ResourceGroupName | Select-Object @{N="Subscription";E={$Sub.Name}}, ResourceGroupName, ServerName, DatabaseName, Location, DatabaseId, Edition, CollationName, CatalogCollation, MaxSizeBytes, Status, CreationDate, CurrentServiceObjectiveId, CurrentServiceObjectiveName, RequestedServiceObjectiveId, RequestedServiceObjectiveName, ElasticPoolName, EarliestRestoreDate, Tags, ResourceId, CreateMode, ReadScale, ZoneRedundant
        $AllDBs += $DBs
    }
}

# MOdify output path to suit your requirements
$AllDBs | Export-csv -Path C:\Temp\PassDBs.csv -NoTypeInformation