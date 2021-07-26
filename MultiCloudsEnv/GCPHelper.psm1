<#
.SYNOPSIS
This function helps you to extract GCP organization information. 
.DESCRIPTION
You need to be connected to your organization first before using this command. Make sure you have the SDK installed and execute a Gcloud Init first.
This function helps you to extract GCP organization information
.EXAMPLE
$OrganizationInfo = Get-GCPOrganizationInfo
Will give you you're orgnanization Information such as orgId, DirectoryId, Name,...
.NOTES
VERSION HISTORY
1.0 | 2020/11/09 | Francois LEON
    initial version
POSSIBLE IMPROVEMENT
    Nothing
#>
function Get-GCPOrganizationInfo {
    gcloud organizations list --format=json | ConvertFrom-Json | Select-Object creationTime, lifecycleState, displayName, @{ Name = 'OrganizationID'; Expression = { $_.name.tostring().split('/')[1] } }, @{ Name = 'DirectoryCustomerId'; Expression = { $_.owner.directoryCustomerId } }
}

<#
.SYNOPSIS
This function helps you to extract all GCP projects information. 
.DESCRIPTION
You need to be connected to your organization first before using this command. Make sure you have the SDK installed and execute a Gcloud Init first.
This function helps you to extract all GCP projects information.
.EXAMPLE
$Projects = Get-GCPProjectInformation

Will give you you're projects Information such as cost center (based on labels), the Id/Type of the parent (organization or folder), ProjectID, ... 
.NOTES
VERSION HISTORY
1.0 | 2020/11/09 | Francois LEON
    initial version
POSSIBLE IMPROVEMENT
    Nothing
#>
function Get-GCPProjectInformation {
    gcloud projects list --format=json | ConvertFrom-Json | Select-Object createTime, lifecycleState, name, projectId, projectNumber, `
    @{ Name = 'CostCenter'; Expression = { $_.labels.cost_center } }, `
    @{ Name = 'ParentId'; Expression = { $_.parent.id } }, `
    @{ Name = 'ParentType'; Expression = { $_.parent.type } }
}

<#
.SYNOPSIS
This function helps you to extract all RBAC/IAM applied to a project. 
.DESCRIPTION
You need to be connected to your organization first before using this command. Make sure you have the SDK installed and execute a Gcloud Init first.
This function helps you to extract all RBAC/IAM applied to a project.
.PARAMETER ProjectId
Specify the ProjectId you want to pass
.EXAMPLE
$MyIAMRole = Get-GCPProjectIAMRole -ProjectID <MyProjectId>

Will return all IAM applied such as role, name and type (service account, group, user)
.EXAMPLE
$Projects = Get-GCPProjectInformation

$exports = @()
foreach ($project in $projects) {
    $ProjectIAMs = Get-GCPProjectIAMRole -projectId $project.projectId
    foreach ($ProjectIAM in $ProjectIAMs) {
        $obj = [PSCustomObject]@{
            ProjectCreationTime = $project.createTime
            ProjectName         = $project.Name
            ProjectprojectId    = $Project.ProjectId
            ProjectNumber       = $project.projectNumber
            ProjectParentId     = $project.ParentId
            projectParentType   = $project.ParentType
            CostCenter          = $project.CostCenter
            IAMRole             = $ProjectIAM.Role
            IAMMemberName       = $ProjectIAM.name
            IAMMemberType       = $ProjectIAM.type
        }
        $exports += $obj
    }
}

$exports | Export-Csv -Path '.\exportIAMGCP.csv' -Encoding UTF8 -Delimiter ';' 

Here we return as a csv file all IAM applied to all projects in a flat format.
.NOTES
VERSION HISTORY
1.0 | 2020/11/09 | Francois LEON
    initial version
POSSIBLE IMPROVEMENT
    Nothing
#>
function Get-GCPProjectIAMRole {
    param(
        [parameter(Position=0,Mandatory)]
        [string]$ProjectId
    )

    $results = @()
    $projectInfos = gcloud projects get-iam-policy $projectId --format=json | ConvertFrom-Json | Select-Object -ExpandProperty bindings
    foreach ($Role in $projectInfos.role) {
        $Members = $projectInfos | Where-Object { $_.role -eq $Role } | select-object -ExpandProperty members 
        foreach ($Member in $members) {
            $obj = [PSCustomObject]@{
                Role = $Role
                Name = $Member.tostring().split(':')[1]
                Type = $Member.tostring().split(':')[0]
            }
            $results += $obj
        } 
    }
    $results
}

function Test-IAMRole{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("roles/viewer", "roles/editor", "roles/owner")]
        [String]$role,
        [parameter(Mandatory)]
        [string]$MailAddress,
        [parameter(Mandatory)]
        [ValidateNotNull()]
        $AssignmentOutput
    )

    $RBACs = ($AssignmentOutput | convertfrom-yaml).bindings
    #if last action was OK
    if($?){
        $members = ($RBACs | Where-Object{$_.role -eq $role}).members
        if($members -contains "user:$MailAddress"){
            write-verbose "The role $role is assigned to the account $MailAddress"
            return $true
        }
        else{
            write-verbose "The role $role is NOT assigned to the account $MailAddress"
            return $false
        }
    }
    else{
        write-verbose "Unable to retrieve RBAC assignments"
        return $false
    }
}

function Add-GCPProjectIAMRole {
    [CmdletBinding()]
    param(
        [parameter(Mandatory)]
        [string]$ProjectId,
        [Parameter(Mandatory)]
        [ValidateSet("roles/viewer", "roles/editor", "roles/owner")]
        [String]$role,
        [parameter(Mandatory)]
        [string]$MailAddress
    )

    $AssignmentOutput = gcloud projects add-iam-policy-binding $ProjectId --member="user:$MailAddress" --role=$role

    #Let's now verify the assignment is applied correctly
    #Should NOT be empty
    $isOK = Test-IAMRole -role $role -MailAddress $MailAddress -AssignmentOutput $AssignmentOutput
    if($isOK){
        Write-verbose "Assignement is correct"
        return $true
    }
    else{
        Write-verbose "Assignement is NOT correct"
        return $false
    }

}



function Revoke-GCPProjectIAMRole {
    [CmdletBinding()]
    param(
        [parameter(Mandatory)]
        [string]$ProjectId,
        [Parameter(Mandatory)]
        [ValidateSet("roles/viewer", "roles/editor", "roles/owner")]
        [String]$role,
        [parameter(Mandatory)]
        [string]$MailAddress
    )

    $AssignmentOutput = gcloud projects remove-iam-policy-binding $ProjectId --member="user:$MailAddress" --role=$role

    #Let's now verify the assignment is applied correctly
    #Should be empty
    $isOK = Test-IAMRole -role $role -MailAddress $MailAddress -AssignmentOutput $AssignmentOutput
    if(! $isOK){
        Write-verbose "Not assignment found"
        return $true
    }
    else{
        Write-verbose "Assignement found it's not correct"
        return $false
    }

}