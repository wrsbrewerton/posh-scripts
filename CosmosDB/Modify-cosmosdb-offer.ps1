Param
(
    [String] $SubscriptionName = "Legacy-MSDN",
    [String] $Location = "West Europe",
    [String] $Environment = "ppd",
    [String] $Project = "ppd", # NO MORE THAN 5 CHARS !!
    [String] $ResourceGroupName = "rg-ppd",
    [String] $ProjectStorage = "store01"+$Project,
    [String] $VnetName = "WorldRemitNetwork",
    [String] $SubnetName = "$Project-subnet",
    [String] $CosmosDBApiVersion = "2017-02-22",
    $CosmosDBs = "",
    $QueryURI = "",
    $Result = ""
)

# Functions to write red, yellow, green output messages
Function WriteBad
{
   Param ([string]$ResultString)
   Write-Host -ForegroundColor Red $ResultString
}

Function WriteWarn
{
   Param ([string]$ResultString)
   Write-Host -ForegroundColor Yellow $ResultString
}

Function WriteGood
{
   Param ([string]$ResultString)
   Write-Host -ForegroundColor Green $ResultString
}

# Fetch primary key
Function Get-PrimaryKey
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)][String]$ResourceGroupName,
        [Parameter(Mandatory=$True)][String]$CosmosDBAccountName
    )

    try
    {
        $Keys = Invoke-AzureRmResourceAction -Action listKeys -ResourceType "Microsoft.DocumentDb/databaseAccounts" -ResourceGroupName $ResourceGroupName -Name $CosmosDBAccountName -Force
        $ConnectionKey = $Keys[0].primaryMasterKey
        Return $ConnectionKey
    }
    catch 
    {
        Write-Host "ErrorStatusDescription:" $_
    }
}

# Generate authorization key using primary key
Function New-MasterKeyAuthSignature
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)][String]$Verb,
        [Parameter(Mandatory=$False)][String]$ResourceType,
        [Parameter(Mandatory=$False)][String]$ResourceLink,
        [Parameter(Mandatory=$True)][String]$DateTime,
        [Parameter(Mandatory=$True)][String]$Key,
        [Parameter(Mandatory=$True)][String]$KeyType,
        [Parameter(Mandatory=$True)][String]$TokenVersion
    )
    $HmacSha256 = New-Object System.Security.Cryptography.HMACSHA256
    $HmacSha256.Key = [System.Convert]::FromBase64String($Key)
    If ($ResourceLink -eq $ResourceType) {
    $ResourceLink = ""
    }
    $PayLoad = "$($Verb.ToLowerInvariant())`n$($ResourceType.ToLowerInvariant())`n$ResourceLink`n$($DateTime.ToLowerInvariant())`n`n"
    $HashPayLoad = $HmacSha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($PayLoad))
    $Signature = [System.Convert]::ToBase64String($HashPayLoad);
    Write-Host $PayLoad
    [System.Web.HttpUtility]::UrlEncode("type=$KeyType&ver=$TokenVersion&sig=$Signature")
}

Function Get-CosmosDBs
{
[CmdletBinding()]
    Param
        (
            [Parameter(Mandatory=$true)][String]$CosmosDBApiVersion,
            [Parameter(Mandatory=$true)][String]$CosmosDbEndPoint,
            [Parameter(Mandatory=$true)][String]$MasterKey
        )
    $Verb = "GET"
    $ResourceType = "dbs";
    $ResourceLink = "dbs"
    $DateTime = [DateTime]::UtcNow.ToString("r")
    $AuthHeader = New-MasterKeyAuthSignature -Verb $Verb -ResourceLink $ResourceLink -ResourceType $ResourceType -Key $MasterKey -KeyType "master" -TokenVersion "1.0" -DateTime $DateTime
    $Header = @{authorization=$AuthHeader;"x-ms-version"=$CosmosDBApiVersion;"x-ms-date"=$DateTime}
    $ContentType= "application/json"
    $QueryURI = "$CosmosDbEndPoint$ResourceLink"
    $Result = Invoke-RestMethod -Method $Verb -ContentType $ContentType -Uri $QueryURI -Headers $Header
    #$CosmosDBId = $Result.Databases.Id
    Return $Result.Databases
}

Function Get-CosmosDBCollections
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)][String]$CosmosDBApiVersion,
        [Parameter(Mandatory=$True)][String]$CosmosDbEndPoint,
        [Parameter(Mandatory=$True)][String]$DatabaseName,
        [Parameter(Mandatory=$True)][String]$MasterKey
    )
    $Verb = "GET"
    $ResourceType = "colls";
    $ResourceLink = "dbs/$DatabaseName"
    $DateTime = [DateTime]::UtcNow.ToString("r")
    $AuthHeader = New-MasterKeyAuthSignature -Verb $Verb -ResourceLink $ResourceLink -ResourceType $ResourceType -Key $MasterKey -KeyType "master" -TokenVersion "1.0" -DateTime $DateTime
    $Header = @{authorization=$AuthHeader;"x-ms-documentdb-isquery"="True";"x-ms-version"=$CosmosDBApiVersion;"x-ms-date"=$DateTime}
    $ContentType= "application/json"
    $QueryURI = "$CosmosDbEndPoint$ResourceLink/colls"
    $Result = Invoke-RestMethod -Method $Verb -ContentType $ContentType -Uri $QueryURI -Headers $Header
    $Result.DocumentCollections
}

Function ModifyCosmosDBOffer
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)][String]$CosmosDBApiVersion,
        [Parameter(Mandatory=$true)][String]$CosmosDbEndPoint,
        [Parameter(Mandatory=$true)][String]$MasterKey,
        [Parameter(Mandatory=$true)][String]$OfferRID
    )
    $Verb = "PUT"
    $ResourceType = "offers";
    $ResourceLink = "offers"
    $Body = '{
        "offerVersion": "V2",
        "offerType": "Invalid",
        "content": {
            "offerThroughput": 400,
            "offerIsRUPerMinuteThroughputEnabled": false
        },
        "resource": "dbs/dbIXAA==/colls/dbIXALjxXgE=/",
        "offerResourceId": "dbIXALjxXgE=",
        "id": "K3b7",
        "_rid": "K3b7"
    }'
    $DateTime = [DateTime]::UtcNow.ToString("r")
    $AuthHeader = New-MasterKeyAuthSignature -Verb $Verb -ResourceLink $OfferRID -ResourceType $ResourceType -Key $MasterKey -KeyType "master" -TokenVersion "1.0" -DateTime $DateTime
    $Header = @{authorization=$AuthHeader;"x-ms-version"=$CosmosDBApiVersion;"x-ms-date"=$DateTime}
    $ContentType= "application/json"
    [System.Web.HttpUtility]::UrlEncode($OfferRID)
    $QueryURI = "$CosmosDbEndPoint$ResourceLink/$OfferRID"
    $Result = Invoke-RestMethod -Method $Verb -ContentType $ContentType -URI $QueryURI -Headers $Header -Body $Body
    $Result | ConvertTo-Json -Depth 10

}

$CosmosDbEndPoint = "https://api-docdb-senderconfig-ppd.documents.azure.com:443/"
$CollectionName = "Collection2-3"
$MasterKey = Get-PrimaryKey -ResourceGroupName $ResourceGroupName -CosmosDBAccountName "api-docdb-senderconfig-ppd"

ModifyCosmosDBOffer -CosmosDBApiVersion $CosmosDBApiVersion -CosmosDbEndPoint $CosmosDbEndPoint -MasterKey $MasterKey -OfferRID $CollectionName


<#
Alternate values for testing with

$CollectionName = "sjbdb1collection1"

$Body = '{
        "offerVersion": "V2",
        "offerType": "Invalid",
        "content": {
            "offerThroughput": 400,
            "offerIsRUPerMinuteThroughputEnabled": false
        },
        "resource": "dbs/dbIXAA==/colls/dbIXAMKbIAA=/",
        "offerResourceId": "dbIXAMKbIAA=",
        "id": "GXIO",
        "_rid": "GXIO"
    }'

#>