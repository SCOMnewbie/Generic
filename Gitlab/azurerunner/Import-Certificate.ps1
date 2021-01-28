Function Import-Certificate {
    <#
    .SYNOPSIS
    Import  a certificate from a local or remote system.
    .DESCRIPTION
    Import  a certificate from a local or remote system.
    .PARAMETER  Computername
    A  single or  list of computernames to  perform search against
    .PARAMETER  StoreName
    The  name of  the certificate store name that  you want to search
    .PARAMETER  StoreLocation
    The  location  of the certificate store.
    .NOTES
    Name:  Import-Certificate
    Author:  Boe  Prox
    Version  History:
    1.0  -  Initial Version
    .EXAMPLE
    $File =  "C:\temp\SomeRootCA.cer"
    $Computername = 'Server1','Server2','Client1','Client2'
    Import-Certificate -Certificate $File -StoreName Root -StoreLocation  LocalMachine -ComputerName $Computername   
  
    Description
    -----------
    Adds  the SomeRootCA certificate to the Trusted Root Certificate Authority store on  the remote systems.
    #>
  
    [cmdletbinding(
        SupportsShouldProcess = $True
    )]
  
    Param (
  
        [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias('PSComputername', '__Server', 'IPAddress')]
        [string[]]$Computername = $env:COMPUTERNAME,
        [parameter(Mandatory = $True)]
        [string]$Certificate,
        [System.Security.Cryptography.X509Certificates.StoreName]$StoreName = 'My',
        [System.Security.Cryptography.X509Certificates.StoreLocation]$StoreLocation = 'LocalMachine'
    )
    
    Begin {
        $CertificateObject = New-Object  System.Security.Cryptography.X509Certificates.X509Certificate2
        $CertificateObject.Import($Certificate)
    }
  
    Process {
        ForEach ($Computer in  $Computername) {
            Try {
                Write-Verbose  ("Connecting to {0}\{1}" -f "\\$($Computername)\$($StoreName)", $StoreLocation)
                $CertStore = New-Object   System.Security.Cryptography.X509Certificates.X509Store  -ArgumentList  "\\$($Computername)\$($StoreName)", $StoreLocation
                $CertStore.Open('ReadWrite')
                If ($PSCmdlet.ShouldProcess("$($StoreName)\$($StoreLocation)", "Add  $Certificate")) {
                    $CertStore.Add($CertificateObject)
                }
            }
            Catch {
                Write-Warning  "$($Computer): $_"
            }
        }
    }
}