<#
.Synopsis
   The goal of this function is to resolve the TPM information status code from "integer" to words. 
.DESCRIPTION
   You can find more information folowing this link: https://msdn.microsoft.com/en-us/library/windows/desktop/jj660284.aspx
.EXAMPLE
   Resolve-CustomTPMInformationStatusCode -TPMInformationStatusCode 264448
   Returns
   The EK Certificate was not read from the TPM NV Ram and stored in the registry.
   The TPM owner authorization is not properly stored in the registry.
   The operating system's registry information about the TPM’s Storage Root Key does not match the TPM Storage Root Key.
.EXAMPLE
   Resolve-CustomTPMInformationStatusCode -TPMInformationStatusCode 2304
   Returns
   The TPM owner authorization is not properly stored in the registry.
   The operating system's registry information about the TPM’s Storage Root Key does not match the TPM Storage Root Key.
.NOTES
    Author: Scomnewbie

    THE SCRIPT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>
function Resolve-CustomTPMInformationStatusCode {
    [CmdletBinding()]
    [OutputType([array])]
    Param
    (
        [Parameter(Mandatory = $true,
            Position = 0)]
        [int]  
        $TPMInformationStatusCode
    )
    
    Begin {
        $TPMstatusCode = @{
            8388608 = "The device identifier has not been created.";
            4194304 = "The device lock counter has not been created.";
            2097152 = "An error occurred =  but not specific to a particular task.";
            1048576 = "The TPM is not owned.";
            524288  = "The TCG event log is empty or cannot be read.";
            262144  = "The EK Certificate was not read from the TPM NV Ram and stored in the registry.";
            131072  = "Windows Group Policy is configured to not store any TPM owner authorization so the TPM cannot be fully ready.";
            65536   = "The second portion of the TPM owner authorization information storage in Active Directory is in progress.";
            32768   = "The first portion of the TPM owner authorization information storage in Active Directory is in progress.";
            16384   = "The TPM’s owner authorization has not been backed up to Active Directory.";
            8192    = "The monotonic counter incremented during boot has not been created.";
            4096    = "The TPM permanent flag to allow reading of the Storage Root Key public value is not set.";
            2048    = "The operating system's registry information about the TPM’s Storage Root Key does not match the TPM Storage Root Key.";
            1024    = "If the operating system is configured to disable clearing of the TPM with the TPM owner authorization value and the TPM has not yet been configured to prevent clearing of the TPM with the TPM owner authorization value .";
            512     = "The Storage Root Key (SRK) authorization value is not all zeros.";
            256     = "The TPM owner authorization is not properly stored in the registry.";
            128     = "An Endorsement Key (EK) exists in the TPM.";
            64      = "The TPM ownership was taken.";
            32      = "The TPM is disabled or deactivated.";
            16      = "Physical Presence is required to provision the TPM.";
            8       = "The TPM is already owned. Either the TPM needs to be cleared or the TPM owner authorization value needs to be imported.";
            4       = "Platform restart is required (reboot).";
            2       = "Platform restart is required (shutdown)."
        } 
    
    }
    Process { 
        $TPMstatusCode.Keys | Where-Object { $_ -band $TPMInformationStatusCode } | ForEach-Object { $TPMstatusCode.Get_Item($_) }
    }
}