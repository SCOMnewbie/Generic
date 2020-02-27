<#
.Synopsis
   Adds two numbers
.DESCRIPTION
   This function adds two numbers together and returns the sum
.EXAMPLE
   Add-TwoNumbers -a 2 -b 3
   Returns the number 5
.EXAMPLE
   Add-TwoNumbers 2 4
   Returns the number 6
#>

function Add-TwoNumber
{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # a is the first number
        [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
        [ValidateSet(1, 2, 3)]
        [int]$a,

        # b is the second number
        [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$b
    )

    return ($a + $b)
}
