Write-Host "####### Run Tests #######"
[array]$Subscriptions = Get-Content .\SubscriptionsList.txt
#Write-Host "Am I really here $($PSVersionTable.Platform)?"
#$var = $env:Mylogin

$global:ProgressPreference = 'SilentlyContinue'
$global:ErrorActionPreference = 'Stop'
#Install-Module Pester -Force -SkipPublisherCheck

Write-Host "Import modules"
Import-Module .\Modules\Pester
Import-Module .\Modules\Az.Accounts
Import-Module .\Modules\Az.Resources

Write-Host "Dot Source MS functions"
# Dot source MS functions
. .\Build-Signature.ps1
. .\Post-LogAnalyticsData.ps1

Write-host "Defined internal variables"
$Timeout = 10 ## second
$CheckEvery = 1 ## second

Write-host "Defined variables from Gitlab"
$TenantID = $env:TenantID
$AppId = $env:AppID
$Secret = $env:Secret
$CustomerId = $env:CustomerID
$SharedKey = $env:SharedKey
$LogType = $env:LogType

#Will represent the id per batch of tests (Count how many tests per run)
$batchId = [System.Guid]::NewGuid()

$passwd = ConvertTo-SecureString $Secret -AsPlainText -Force
$pscredential = New-Object System.Management.Automation.PSCredential($AppId, $passwd)

Foreach ($Subscription in $Subscriptions) {
    #will represent the id for each run per subscription (to track what's going on per subscription)
    $invocationId = [System.Guid]::NewGuid()
    #$PesterResults = Invoke-Pester -Script @{Path = ".\Tests\ValidateSubscriptions.Tests.ps1"; Parameters = @{TenantID = $TenantID ; SubscriptionID = $Subscription; credential = $pscredential } } -PassThru 
    Invoke-Pester -Script @{Path = ".\Tests\ValidateSubscriptions.Tests.ps1"; Parameters = @{TenantID = $TenantID ; SubscriptionID = $Subscription; credential = $pscredential } } -OutputFile "result.xml" -OutputFormat JUnitXml 

    
    #Let's now publish result to our log Analytics*
    $Results = @()
    #Each test will be formatted in a pscustomobject
    foreach ($PesterResult in $PesterResults.TestResult) {
        $Results += [PSCustomObject]@{
            BatchId             = $batchId
            invocationId        = $invocationId
            Identifier          = 'AzureSubChecks'
            SubscriptionChecked = $Subscription
            TimeTaken           = $PesterResult.Time.TotalMilliseconds
            Passed              = $PesterResult.Passed
            Describe            = $PesterResult.Describe
            Context             = $PesterResult.Context
            Name                = $PesterResult.Name
            FailureMessage      = $PesterResult.FailureMessage
            Result              = $PesterResult.Result
        }
    }

    # 10 times retry if the MS API not available, then skip (Alert can be generated on count)
    ## Start the timer
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $Code = $null
    While (-not ($Code -eq 200)) {
        if ($timer.Elapsed.TotalSeconds -ge $Timeout) {
            throw "Timeout exceeded. Unable to Contact the Log Analytics Endpoint"
        }

        [int]$Code = Post-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($($Results | ConvertTo-Json))) -logType $logType
        Write-Host "Code returned by the endpoint is: $Code"
        if ($Code -ne 200) { start-Sleep -Seconds $CheckEvery } 
    }
    
    ## When finished, stop the timer
    $timer.Stop()   
}   

