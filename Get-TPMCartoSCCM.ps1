
#Requires -Version 5.0
#Requires -RunAsAdministrator
<#
	.DESCRIPTION
    This script is designed to run from SCCM with a CI/CB to dump TPM info in a WMI class. So the idea is to create a CI/CB with this script in SCCM, and gather the result with the hardware inventory. 
    The result is a TPM/DSRegCMD/BIOS/Bitlocker/Meltdown  cartography. When you have to work on O365 with conditionnal access, very quickly you will receive some weird behaviors of
    Non working machines. It seems that clear/Enabled (yes sadly some people disabled TPM...) the TPM chip fix a lot of problems for CA.
    WARNING: This script has been used on Windows 10 only, Windows 7 is out of scope (upgrade those ;) ). I've put V5 just in case.

    Pre-requisites:
    - A SCCM agent in good shape

   The script will gather (less thing than the WinRM one because a lot of stuff are already in SCCM DB):
            ComputerName  > ComputerNAme
            WinVersion  > Windows 10 version
            DaysSinceInstalled  > When the machine has been rebuilded
            BiosVersion 
            BiosReleaseDate 
            BIOSSMVersion 
            IsReadyInformation > Why your TPM chip is not happy
            SpectreEventFound > For Meltdown/Spectre do you have the 1794 sonce last reboot?
            IsOwned > Is your TPM chip owned
            DSRegAzureADJoin > AzureAD Join Status
            DSRegKeyProvider > Do you use TPM or Windows Crypto Key instead
            DSRegTpmProtected > Do you use your TPM chip or not
            DSRegDomainJoined > DsRegCmd DJ Status
            DSRegWorkplaceJoined > DsRegCmd WJ Status
            PresenceStatusWhenClearTPM > Do we need user presence to clear TPM chip?
            EventDRSErrorFound > Do we have error in the user device registration event log since last reboot.
    
	.NOTES
    Author: Scomnewbie

    THE SCRIPT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

# Creates a new class in WMI to store our data
function New-WmiClass() {
    $newClass = New-Object System.Management.ManagementClass("root\cimv2", [String]::Empty, $null)
    $newClass["__CLASS"] = "Custom_TPMInfo"
    $newClass.Qualifiers.Add("Static", $true)
    $newClass.Properties.Add("ComputerName", [System.Management.CimType]::String, $false)
    $newClass.Properties["ComputerName"].Qualifiers.Add("key", $true)
    $newClass.Properties["ComputerName"].Qualifiers.Add("read", $true)
    $newClass.Properties.Add("DaysSinceInstalled", [System.Management.CimType]::UInt32, $false)
    $newClass.Properties["DaysSinceInstalled"].Qualifiers.Add("read", $true)
    $newClass.Properties.Add("BiosVersion", [System.Management.CimType]::String, $false)
    $newClass.Properties["BiosVersion"].Qualifiers.Add("read", $true)
    $newClass.Properties.Add("BiosReleaseDate", [System.Management.CimType]::String, $false)
    $newClass.Properties["BiosReleaseDate"].Qualifiers.Add("read", $true)
    $newClass.Properties.Add("SpectreEventFound", [System.Management.CimType]::String, $false)
    $newClass.Properties["SpectreEventFound"].Qualifiers.Add("read", $true)
    $newClass.Properties.Add("DSRegKeyProvider", [System.Management.CimType]::String, $false)
    $newClass.Properties["DSRegKeyProvider"].Qualifiers.Add("read", $true)
    $newClass.Properties.Add("DSRegTpmProtected", [System.Management.CimType]::String, $false)
    $newClass.Properties["DSRegTpmProtected"].Qualifiers.Add("read", $true)
    $newClass.Properties.Add("PresenceStatusWhenClearTPM", [System.Management.CimType]::String, $false)
    $newClass.Properties["PresenceStatusWhenClearTPM"].Qualifiers.Add("read", $true)
    $newClass.Properties.Add("EventDRSErrorFound", [System.Management.CimType]::String, $false)
    $newClass.Properties["EventDRSErrorFound"].Qualifiers.Add("read", $true)
    $newClass.Put()
}

# Check whether we already created our custom WMI class on this PC, if not, create it
[void](Get-WMIObject Custom_TPMInfo -ErrorAction SilentlyContinue -ErrorVariable wmiclasserror)
if ($wmiclasserror) {
    try { 
        New-WmiClass 
    }
    catch {
        "Could not create WMI class"
        Exit
    }
}

#Main
#No more cimsession, no more runspaces, just dummy export of data
$ComputerName = $env:ComputerName
$OS = Get-CimInstance -ClassName "win32_operatingsystem"
$InstallDate = $OS.InstallDate
$LastBootUpTime = $OS.LastBootUpTime
$LocalDateTime = $OS.LocalDateTime
#Get the upTime and we add 10 min just in case for the even search
$UpAndRunningMilliSeconds = [long](New-TimeSpan -Start $LastBootUpTime -End $LocalDateTime).TotalMilliseconds
$UpAndRunningMilliSeconds = $UpAndRunningMilliSeconds + 60000
$UpAndRunningMilliSeconds = $UpAndRunningMilliSeconds.Tostring()
$DaysSinceInstalled = [int](New-TimeSpan -Start $InstallDate -End $LocalDateTime).TotalDays

#Get BIOS Info
$ComputerBios = Get-CimInstance -ClassName "Win32_BIOS"
$BiosVersion = $ComputerBios.Version
$BiosReleaseDate = $ComputerBios.ReleaseDate.ToString('yyyy/M/d')


$SpecterFilter = @"
<QueryList>
<Query Id="0" Path="System">
<Select Path="System">*[System[Provider[@Name='Microsoft-Windows-TPM-WMI'] and (EventID=1794) and TimeCreated[timediff(@SystemTime) &lt;= $UpAndRunningMilliSeconds]]]</Select>
</Query>
</QueryList>
"@

$CustomEventSearch = $null
[string]$SpectreEventFound = ""
$CustomEventSearch = Get-WinEvent -FilterXml $SpecterFilter -ErrorAction SilentlyContinue -ErrorVariable ErrCustomEventSearch
if ($ErrCustomEventSearch.FullyQualifiedErrorId -match 'NoMatchingEventsFound,Microsoft.PowerShell.Commands.GetWinEventCommand') {
    [string]$SpectreEventFound = "false"
}
elseif ($CustomEventSearch.Count -ne 0) {
    [string]$SpectreEventFound = "true"
}
else {
    [string]$SpectreEventFound = "N/A"
}


$DRSStatusFilter = @"
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-User Device Registration/Admin">
    <Select Path="Microsoft-Windows-User Device Registration/Admin">*[System[(Level=1  or Level=2) and TimeCreated[timediff(@SystemTime) &lt;= $UpAndRunningMilliSeconds]]]</Select>
  </Query>
</QueryList>
"@
$UserDRSErrors = $null
[string]$EventDRSErrorFound = ""
$UserDRSErrors = Get-WinEvent -FilterXml $DRSStatusFilter -ErrorAction SilentlyContinue -ErrorVariable UserDRSErrorsEventSearch
if ($UserDRSErrorsEventSearch.FullyQualifiedErrorId -match 'NoMatchingEventsFound,Microsoft.PowerShell.Commands.GetWinEventCommand') {
    [string]$EventDRSErrorFound = "false"
}
elseif ($UserDRSErrors.Count -ne 0) {
    [string]$EventDRSErrorFound = "true"
}
else {
    [string]$EventDRSErrorFound = "N/A"
}

$DsregCmd = Invoke-Command -ScriptBlock {dsregcmd.exe /status}
[string]$DSRegKeyProvider = ($DsregCmd | select-string -Pattern 'KeyProvider :')   

if ($DSRegKeyProvider -eq "") {
    $DSRegKeyProvider = 'N/A'
}
else {
    $DSRegKeyProvider = $DSRegKeyProvider.ToString().trim().Split(':')[1].trim()
}

[string]$DSRegTpmProtected = ($DsregCmd | select-string -Pattern 'TpmProtected :') 
if ($DSRegTpmProtected -eq "") {
    $DSRegTpmProtected = 'N/A'
}
else {
    $DSRegTpmProtected = $DSRegTpmProtected.ToString().trim().Split(':')[1].trim()
}

#Get-PresenceConfiramtionStatus 5 means we want info when we will trigger a clear TPM action
$PresenceProps = @{
    'Operation' = 5
}

$PresenceHash = @{
    MethodName = "GetPhysicalPresenceConfirmationStatus"
    Arguments  = $PresenceProps
}
$TPMStatusCimInstance = Get-CimInstance -ErrorAction SilentlyContinue -Namespace "root\CIMV2\Security\MicrosoftTpm" -ClassName "Win32_TPM"
if ($TPMStatusCimInstance -eq $null) {
    $PresenceStatusWhenClearTPM = 'N/A'
} 
else {
    $PresenceStatusWhenClearTPM = $TPMStatusCimInstance | Invoke-CimMethod @PresenceHash | Select-Object -ExpandProperty ConfirmationStatus
}

$properties = @{
    ComputerName               = $ComputerName
    DaysSinceInstalled         = $DaysSinceInstalled
    BiosVersion                = $BiosVersion
    BiosReleaseDate            = $BiosReleaseDate
    SpectreEventFound          = $SpectreEventFound
    DSRegKeyProvider           = $DSRegKeyProvider
    DSRegTpmProtected          = $DSRegTpmProtected
    PresenceStatusWhenClearTPM = $PresenceStatusWhenClearTPM
    EventDRSErrorFound         = $EventDRSErrorFound
}

# Clear WMI
Get-WmiObject -class Custom_TPMInfo | Remove-WmiObject

#Populate one instance
[void](Set-WmiInstance -Path \\.\root\cimv2:Custom_TPMInfo -Arguments $properties)