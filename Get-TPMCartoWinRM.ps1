#Requires -Version 5.0
Param(
    [String[]]$ComputerList,
    [int]$Throttle = 100 
)
<#
	.DESCRIPTION
    This script is designed to run from an admin machine in a context who has admin privilege on remote machines. To use it, you simply need in input an array of machines.
    The result is a TPM/DSRegCMD/BIOS/Bitlocker/Meltdown  cartography. When you have to work on O365 with conditionnal access, very quickly you will receive some weird behaviors of
    Non working machines. It seems that clear/Enabled (yes sadly some people disabled TPM...) the TPM chip fix a lot of problems for CA.
    WARNING: This script has been used on Windows 10 only, Windows 7 is out of scope (upgrade those ;) ). I've put V5 just in case.
    Once the report is done, I personnaly dump the csv in a PowerBI to have the big picture. 

    Pre-requisites:
    - WinRM (5985) has to be openned on the remote machines
    - You must be local admin on the machines
    - To have the full potential of this script device registration service has to be enabled (dsregcmd /status) whith your tenant
    - Invoke-Parallel has to be copied in the same folder has your script (https://github.com/RamblingCookieMonster/PowerShell/blob/master/Invoke-Parallel.ps1)

    Once pre-requisites are met, the script will:
    - Gather information using multiple runspaces (did tests with 100)
    - Here what is gathered:
        -   DisplayName  > ComputerNAme
        -    WinVersion  > Windows 10 version
            DaysSinceInstalled  > When the machine has been rebuilded
            Manufacturer > Only official place (to bad for crappy Manufacturer)
            TPMDetected  > Do we have a TPM chip even if it's not enabled. Since 1607 and above
            TPMManufacturerIdTxt > TPM Manufacturer
            Model > Like manufacturer, only the default place
            TPMSpecInfo > 1.2 or 2.0
            TPMManufacturerVersion > TPM Manufacturer version
            BiosVersion 
            BiosReleaseDate 
            BIOSSMVersion 
            IsEnabled > Is TPM Chip enabled 
            BitlockerOnC > Personnal need, is Bitlocker is enabled on C:
            IsReady > Is your TPM chip happy? True yes, false no
            IsReadyInformation > Why your TPM chip is not happy
            EventFound > For Meltdown/Spectre do you have the 1794 sonce last reboot?
            IsOwned > Is your TPM chip owned
            DSRegAzureADJoin > AzureAD Join Status
            DSRegKeyProvider > Do you use TPM or Windows Crypto Key instead
            DSRegTpmProtected > Do you use your TPM chip or not
            DSRegDomainJoined > DsRegCmd DJ Status
            DSRegWorkplaceJoined > DsRegCmd WJ Status
            PresenceStatusWhenClearTPM > Do we need user presence to clear TPM chip?
            EventDRSErrorFound > Do we have error in the user device registration event log since last reboot.

    .EXAMPLE
    $Computerlist = Get-content MyServierlist.txt
    .\Get-TPMCartoWinRM.ps1 -ComputerList $Computerlist  -Throttle 150

    .\Get-TPMCartoWinRM.ps1 -ComputerList "locahost","RemoteMAchine1" "RemoteMAchine1"
    
	.NOTES
    Author: Scomnewbie

    THE SCRIPT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

#Where we will store the Temp logs + clean
$TPMCartoLogsFolder = Join-Path $env:TEMP "TPMCartoLogs"
$IsFolderExist = test-path $TPMCartoLogsFolder
#If folder doesn't exist, let's create it
if (! $IsFolderExist) {
    New-Item -ItemType Directory -Path $TPMCartoLogsFolder 
}

#Clean previous logs
Get-ChildItem -Path $TPMCartoLogsFolder | Remove-Item

$ShortScriptPath = $PSScriptRoot
$IvokeParallelPath = Join-path $ShortScriptPath "Invoke-Parallel.ps1"
$IsInvokeParallelExist = Test-Path $IvokeParallelPath

if (! $IsInvokeParallelExist) {
    Write-Error "Invoke-Paralell module is mandatory for this script. Let's download it first and put it into your script folder." -ErrorAction Stop
}

#Let's dotsource the invoke-parallel
#. "E:\TEMP\WinRM\Invoke-Parallel.ps1"
. $IvokeParallelPath

$SB = {

    Test-WSMan -ComputerName $_ -ErrorAction SilentlyContinue -ErrorVariable ErrTestWSMAN | Out-Null
    #Only if WSMAN
    if ($ErrTestWSMAN.count -eq 0) {
        
        #Sessions Creation to avoid opening/Closing a thread several time per scriptblock
        $CimSession = New-CimSession -ComputerName $_
        $PSSession = New-PSSession -ComputerName $_

        #Get All date that we need
        $TPMStatusCimInstance = Get-CimInstance -ErrorAction SilentlyContinue -Namespace "root\CIMV2\Security\MicrosoftTpm" -ClassName "Win32_TPM" -CimSession $CimSession
        if ($TPMStatusCimInstance -eq $null) {
            $TPMDetected = $false
            #Initialize all output variable to a default value
            $IsEnabled = 'N/A'
            $IsOwned = 'N/A' 
            $IsReady = 'N/A'
            $IsReadyInformation = 'N/A'
            $TPMSpecInfo = 'N/A'
            $TPMManufacturerVersion = 'N/A'
            $TPMManufacturerIdTxt = 'N/A'
            $PresenceStatusWhenClearTPM = 'N/A'

        }
        else {
            $TPMDetected = $true
            #Execute method on this instance
            $IsEnabled = Invoke-CimMethod -InputObject $TPMStatusCimInstance -MethodName isenabled -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Isenabled
            $IsOwned = Invoke-CimMethod -InputObject $TPMStatusCimInstance -MethodName IsOwned -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IsOwned     
            $IsReady = Invoke-CimMethod -InputObject $TPMStatusCimInstance -MethodName IsReady -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IsReady
            $IsReadyInformation = Invoke-CimMethod -InputObject $TPMStatusCimInstance -MethodName IsReadyInformation -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Information
            $TPMSpecInfo = $TPMStatusCimInstance.SpecVersion.ToString().split(',')[0]
            $TPMManufacturerVersion = $TPMStatusCimInstance.ManufacturerVersion
            $TPMManufacturerIdTxt = $TPMStatusCimInstance.ManufacturerIdTxt

            #Get-PresenceConfiramtionStatus 5 means we want info when we will trigger a clear TPM action
            $PresenceProps = @{
                'Operation' = 5
            }

            $PresenceHash = @{
                MethodName = "GetPhysicalPresenceConfirmationStatus"
                Arguments  = $PresenceProps
            }
            $PresenceStatusWhenClearTPM = $TPMStatusCimInstance | Invoke-CimMethod @PresenceHash | select -ExpandProperty ConfirmationStatus
        }

        #Get-CimClass -ClassName "Win32_encryptablevolume" -Namespace "ROOT\CIMV2\Security\Microsoftvolumeencryption" | select -ExpandProperty CimclassMethods
        [string]$ProtectionStatusC = Get-CimInstance -ClassName "Win32_encryptablevolume" -Namespace "ROOT\CIMV2\Security\Microsoftvolumeencryption" -Filter "DriveLetter = 'C:'" -CimSession $CimSession -ErrorAction SilentlyContinue | Select-Object -ExpandProperty  ProtectionStatus
        switch ($ProtectionStatusC) {
            "0" {$BitlockerOnC = 'Unprotected'}
            "1" {$BitlockerOnC = 'Protected'}
            "2" {$BitlockerOnC = 'Uknowned'}
            default {$BitlockerOnC = 'NoReturn'}
        }

        $OS = Get-CimInstance -ClassName win32_operatingsystem -CimSession $CimSession
        $InstallDate = $OS.InstallDate
        $LastBootUpTime = $OS.LastBootUpTime
        $LocalDateTime = $OS.LocalDateTime
        #Get the upTime and we add 10 min just in case for the even search
        $UpAndRunningMilliSeconds = [long](New-TimeSpan -Start $LastBootUpTime -End $LocalDateTime).TotalMilliseconds
        $UpAndRunningMilliSeconds = $UpAndRunningMilliSeconds + 60000
        $UpAndRunningMilliSeconds = $UpAndRunningMilliSeconds.Tostring()
        $DaysSinceInstalled = [int](New-TimeSpan -Start $InstallDate -End $LocalDateTime).TotalDays
        [int]$BuildNumber = $OS.BuildNumber
        switch ($BuildNumber) {
            17134 {$Win10Version = "1803"}
            16299 {$Win10Version = "1709"}
            15063 {$Win10Version = "1703"}
            14393 {$Win10Version = "1607"}
            10240 {$Win10Version = "1511"}
            Default {$Win10Version = "N/A"}
        }

        $NestedSB = {
            param ([string]$UpAndRunning)
            $query = @"
<QueryList>
    <Query Id="0" Path="System">
    <Select Path="System">*[System[Provider[@Name='Microsoft-Windows-TPM-WMI'] and (EventID=1794) and TimeCreated[timediff(@SystemTime) &lt;= $UpAndRunning]]]</Select>
    </Query>
</QueryList>
"@
            $CustomEventSearch = $null
            $CustomEventSearch = Get-WinEvent -FilterXml $query -ErrorAction SilentlyContinue -ErrorVariable ErrCustomEventSearch
            if ($ErrCustomEventSearch.Exception -match 'No events were found that match the specified selection criteria.') {
                [string]$EventFound = "false"
            }
            elseif ($CustomEventSearch.Count -ne 0) {
                [string]$EventFound = "true"
            }
            else {
                [string]$EventFound = "N/A"
            }
            return $EventFound
        }

        #We use Invoke-Command to use only WinRM and not RPC
        $EventFound = Invoke-Command -ScriptBlock $NestedSB -Session $PSSession -ArgumentList $UpAndRunningMilliSeconds

        $NestedSB2 = {
            param ([string]$UpAndRunning)
            $query2 = @"
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-User Device Registration/Admin">
    <Select Path="Microsoft-Windows-User Device Registration/Admin">*[System[(Level=1  or Level=2) and TimeCreated[timediff(@SystemTime) &lt;= $UpAndRunning]]]</Select>
  </Query>
</QueryList>
"@
            $UserDRSErrors = $null
            $DRSErrorFound = ""
            $UserDRSErrors = Get-WinEvent -FilterXml $query2 -ErrorAction SilentlyContinue -ErrorVariable UserDRSErrorsEventSearch
            if ($UserDRSErrorsEventSearch.Exception -match 'No events were found that match the specified selection criteria.') {
                [string]$DRSErrorFound = "false"
            }
            elseif ($UserDRSErrors.Count -ne 0) {
                [string]$DRSErrorFound = "true"
            }
            else {
                [string]$DRSErrorFound = "N/A"
            }
            return $DRSErrorFound
        }

        #We use Invoke-Command to use only WinRM and not RPC
        $EventDRSErrorFound = Invoke-Command -ScriptBlock $NestedSB2 -Session $PSSession -ArgumentList $UpAndRunningMilliSeconds

    
        #Get computer Info
        $ComputerInfo = Get-CimInstance -ClassName Win32_ComputerSystem -CimSession $CimSession
        $Manufacturer = $ComputerInfo.Manufacturer
        $Model = $ComputerInfo.Model
        
        #Get BIOS Info
        $ComputerBios = Get-CimInstance -ClassName Win32_BIOS -CimSession $CimSession
        $BiosVersion = $ComputerBios.Version
        $BiosReleaseDate = $ComputerBios.ReleaseDate.ToString('yyyy/M/d')
        $BIOSSMVersion = $ComputerBios.SMBIOSBIOSVersion 

        $DsregCmd = Invoke-Command -ScriptBlock {dsregcmd.exe /status} -Session $PSSession
        [string]$DSRegAzureADJoin = ($DsregCmd | select-string -Pattern 'AzureAdJoined :')
        if ($DSRegAzureADJoin -eq $null) {
            $DSRegAzureADJoin = 'N/A'
        }
        else {
            $DSRegAzureADJoin = $DSRegAzureADJoin.ToString().trim().Split(':')[1].trim()
        }

        [string]$DSRegKeyProvider = ($DsregCmd | select-string -Pattern 'KeyProvider :')
        if ($DSRegKeyProvider -eq $null) {
            $DSRegKeyProvider = 'N/A'
        }
        else {
            $DSRegKeyProvider = $DSRegKeyProvider.ToString().trim().Split(':')[1].trim()
        }

        [string]$DSRegTpmProtected = ($DsregCmd | select-string -Pattern 'TpmProtected :')
        if ($DSRegTpmProtected -eq $null) {
            $DSRegTpmProtected = 'N/A'
        }
        else {
            $DSRegTpmProtected = $DSRegTpmProtected.ToString().trim().Split(':')[1].trim()
        }

        [string]$DSRegDomainJoined = ($DsregCmd | select-string -Pattern 'DomainJoined :')
        if ($DSRegDomainJoined -eq $null) {
            $DSRegDomainJoined = 'N/A'
        }
        else {
            $DSRegDomainJoined = $DSRegDomainJoined.ToString().trim().Split(':')[1].trim()
        }

        [string]$DSRegWorkplaceJoined = ($DsregCmd | select-string -Pattern 'WorkplaceJoined :')
        if ($DSRegWorkplaceJoined -eq $null) {
            $DSRegWorkplaceJoined = 'N/A'
        }
        else {
            $DSRegWorkplaceJoined = $DSRegWorkplaceJoined.ToString().trim().Split(':')[1].trim()
        }

        $props = @{
            DisplayName                = $_
            WinVersion                 = $Win10Version
            DaysSinceInstalled         = $DaysSinceInstalled
            Manufacturer               = $Manufacturer
            TPMDetected                = $TPMDetected
            TPMManufacturerIdTxt       = $TPMManufacturerIdTxt
            Model                      = $Model
            TPMSpecInfo                = $TPMSpecInfo
            TPMManufacturerVersion     = $TPMManufacturerVersion
            BiosVersion                = $BiosVersion
            BiosReleaseDate            = $BiosReleaseDate
            BIOSSMVersion              = $BIOSSMVersion
            IsEnabled                  = $IsEnabled 
            BitlockerOnC               = $BitlockerOnC
            IsReady                    = $IsReady
            IsReadyInformation         = $IsReadyInformation
            EventFound                 = $EventFound
            IsOwned                    = $IsOwned
            DSRegAzureADJoin           = $DSRegAzureADJoin
            DSRegKeyProvider           = $DSRegKeyProvider
            DSRegTpmProtected          = $DSRegTpmProtected
            DSRegDomainJoined          = $DSRegDomainJoined
            DSRegWorkplaceJoined       = $DSRegWorkplaceJoined
            PresenceStatusWhenClearTPM = $PresenceStatusWhenClearTPM
            EventDRSErrorFound         = $EventDRSErrorFound
        }

        #We can't use append with more than 100 thread in the same time :)
        $object = new-object psobject -Property $props
        $Object | Export-Clixml -path "$TPMCartoLogsFolder\$_.txt"

        #Close all remote session in this thread
        Get-CimSession -ComputerName $_ -ErrorAction SilentlyContinue | % {Remove-CimSession -CimSession $_ -ErrorAction SilentlyContinue}
        Get-PSSession -ComputerName $_ -ErrorAction SilentlyContinue | % {Remove-PSSession -Session $_ -ErrorAction SilentlyContinue}
    }
}

#With 12K devices with 8K devices available at that time, it took 12 min to run.
#$ComputerList | Invoke-Parallel -LogFile "E:\TEMP\WinRM\log.txt" -ErrorAction SilentlyContinue -RunspaceTimeout 30 -Throttle 60 -ScriptBlock $sb
$ComputerList | Invoke-Parallel  -ErrorAction SilentlyContinue -RunspaceTimeout 30 -Throttle $Throttle -ScriptBlock $SB

#We need speed here so I preffer to use the .NET way
$results = New-Object System.Collections.Generic.List[System.Object]

$AllFiles = Get-ChildItem -Path $TPMCartoLogsFolder
foreach ($file in $AllFiles) {
    $Obj = Import-Clixml -Path $file.FullName
    $results.Add($Obj)

}

$results | export-csv -Delimiter ";" -Path "$TPMCartoLogsFolder\Carto.csv" -Encoding UTF8 -NoTypeInformation