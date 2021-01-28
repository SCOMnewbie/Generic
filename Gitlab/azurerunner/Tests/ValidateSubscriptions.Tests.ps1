Param (
    [string]$TenantID,
    [string]$SubscriptionID,
    [PSCredential]$Credential
)

Describe "Test Governance on Subscription: $SubscriptionID" {

    Connect-AzAccount -Credential $Credential -ServicePrincipal -Tenant $TenantID -WarningAction SilentlyContinue -ErrorAction stop
    Select-AzSubscription -Subscription $SubscriptionID -ErrorAction Stop
    $Context = Get-AzContext  -ErrorAction Stop  
    write-host "test"
        
    Context 'Subscription Context' {
        # Validate the subscription is enabled
        It 'State should be enabled' {
            $Context.Subscription.State | 
            Should Be 'Enabled'
        }

        It "ID should be $SubscriptionID" {
            $Context.Subscription.Id | 
            Should Be "123"
        }
    }
}
