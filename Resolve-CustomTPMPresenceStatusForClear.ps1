<#
.Synopsis
   The goal of this function is to know if a physical presence is required when we will push a TPM clear before doing it. 
.DESCRIPTION
   You can find more information folowing this link: https://msdn.microsoft.com/en-us/library/windows/desktop/jj660278(v=vs.85).aspx
.EXAMPLE
   Resolve-CustomTPMPresenceStatusForClear -ComputerName "localhost", "machine1", "NonPinguableMachine"
   Returns
   No TPM chip on the device
   Allowed and physically present user required
   Unable to connect using Cim

.NOTES
    Author: Scomnewbie

    THE SCRIPT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>
function Resolve-CustomTPMPresenceStatusForClear {
    [CmdletBinding()]
    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory = $true,
            Position = 0)]
        [string[]]$ComputerName
    )
        
    Foreach ($Computer in $ComputerName) {
    
        $CimInstanceArguments = @{
            ClassName    = "Win32_Tpm"
            Namespace    = "ROOT\CIMV2\Security\MicrosoftTpm"
            ComputerName = $Computer
        }
        $TPMCim = Get-CimInstance @CimInstanceArguments -ErrorVariable TPMCimError -ErrorAction SilentlyContinue
    
        if (! $TPMCimError) {
            if ($TPMCim -ne $null) {
                #Get-PresenceConfiramtionStatus 5 means we want info when we will trigger a clear TPM action
                #https://msdn.microsoft.com/en-us/library/windows/desktop/jj660278(v=vs.85).aspx
                $PresenceProps = @{
                    'Operation' = 5
                }
                $PresenceHash = @{
                    MethodName = "GetPhysicalPresenceConfirmationStatus"
                    Arguments  = $PresenceProps
                }
                $PresenceStatus = $TPMCim | Invoke-CimMethod @PresenceHash | Select-Object ConfirmationStatus, ReturnValue
                    
                if ($PresenceStatus.ReturnValue -eq 0) {
                    $result = switch ( $PresenceStatus.ConfirmationStatus ) {
                        0 { 'Not implemented' }
                        1 { 'BIOS only' }
                        2 { 'Blocked for the operating system by the BIOS configuration' }
                        3 { 'Allowed and physically present user required' }
                        4 { 'Allowed and physically present user not required' }
                        default { 'Presence Status Unknown' }
                    }
                    $result 
                }
                else {
                    $result = 'Error during Cim retrieval'
                    $result
                }
            }#TPM chip detected
            else {
                $result = 'No TPM chip on the device'
                $result
            }    
        }#Cim Connection seems OK
        else {
            $result = "Unable to connect using Cim"
            $result 
        }
    }
}
    
