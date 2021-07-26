throw "Do NOT PRESS F5, this is an interactive demo"

Set-location "<path where you've clonedthe repo>"

#Build
docker build -t pscloudevenv:latest .

#Run the cloud dev env for most of the commands
docker run -it --rm -v "$(pwd):/pscloudevenv" -w "/pscloudevenv" pscloudevenv:latest

#privileged flag required for azcopy (keyctl session issue)
docker run -it --rm --privileged -v "$(pwd):/pscloudevenv" -w "/pscloudevenv" pscloudevenv:latest

#Verify the GCP SDK is installed
$IsSDKInstalled = dpkg-query -l | Select-String "google-cloud-sdk"
$IsSDKInstalled -ne $null ? $(Write-Host "SDK installed" -ForegroundColor green) : $(throw "SDK is mandatory go install it first")

#Let's connect to GCP in an interactive way
gcloud init

Import-Module ".\GCPHelper.psm1"

#Display Organization information
Get-GCPOrganizationInfo

#Get projects inforamtion
$Projects = Get-GCPProjectInformation
$Projects[0..3] | Format-Table

$projects | where CostCenter -eq $null

#Let's now export one IAM assignments (Usage Get-GCPProjectIAMRole)
Get-GCPProjectIAMRole -projectId $Project[0]

#Let's now export all IAM assignments
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

$exports[0..10] | Format-Table -AutoSize

#$exports | Export-Csv -Path '.\exportIAMGCP.csv' -Encoding UTF8 -Delimiter ';' -force

