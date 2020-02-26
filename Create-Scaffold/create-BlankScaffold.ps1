#Execute this script once repo has been sync with origin (.gitignore should exist)


$ModuleName = 'BuildPsModule6'
$Path = "C:\Git\AzureDevOps\$ModuleName"
$Author = 'Francois LEON'
$Description = 'This module is to learn Azure Devops. It can be used for various possibilities'
$CompanyName = 'ScomNewbie'

#To plan the cross-platform
# Nice article: https://powershell.org/2019/02/tips-for-writing-cross-platform-powershell-code/
$DS = [io.path]::DirectorySeparatorChar

#Create top module folder
if( -not (Test-Path $Path)){
    $null = mkdir $Path
}

#Create the .gitignorefile
$GitIgnore = @" 
*.xml
*.txt
"@
$GitIgnore | Out-File -FilePath $(Join-Path $Path '.gitignore')


#Create the Azurepipeline file
$AzurePipeline = @" 
trigger:
  - master

stages:
  - stage: QA
    pool:
      vmImage: `"windows-latest`"
    jobs:
      - job: analyze_test
        displayName: `"Analyze & Test`"
        steps:
          - task: PowerShell@2
            displayName: `"Run PSScriptAnalyzer`"
            inputs:
              targetType: `"inline`"
              script: `'.\build.ps1 -Analyze`'
          - task: PowerShell@2
            displayName: `"Run Pester`"
            inputs:
              targetType: `"inline`"
              script: `'.\build.ps1 -Test`'

  - stage: Build
    pool:
      vmImage: `"windows-latest`"
    jobs:
      - job: compile
        displayName: `"Compile module $ModuleName`"
        steps:
          - task: PowerShell@2
            displayName: `"Compile Module`"
            inputs:
              targetType: `"inline`"
              script: `'.\build.ps1 -Compile`'
          - task: PowerShell@2
            displayName: `"Run Pester`"
            inputs:
              targetType: `"inline`"
              script: `'.\build.ps1 -Test`'
          - task: PublishTestResults@2
            inputs:
              testResultsFormat: `"NUnit`"
              testResultsFiles: `"**/TestResults.xml`"
          - publish: $ModuleName
            artifact: $ModuleName
"@

$AzurePipeline | Out-File -FilePath $(Join-Path $Path 'azure-pipelines.yml')


#Create the build.ps1
$BuildPs1 = @"
[CmdletBinding()]
param(
    [Parameter(
        Mandatory,
        ParameterSetName = `'Analyze`')
    ]
    [switch] `$Analyze,
    [Parameter(
        Mandatory,
        ParameterSetName = `'Compile`')
    ]
    [switch] `$Compile,
    [Parameter(
        Mandatory,
        ParameterSetName = `'Compile`')
    ]
    [ValidateNotNullOrEmpty()]
    [version] `$BuildVersion,
    [Parameter(
        Mandatory,
        ParameterSetName = `'Test`')
    ]
    [switch] `$Test,
    [Parameter(
        Mandatory,
        ParameterSetName = `'Doc`')
    ]
    [switch] `$Doc,
    [Parameter(
        Mandatory,
        ParameterSetName = `'Release`')
    ]
    [switch] `$Release,
    [Parameter(
        Mandatory,
        ParameterSetName = `'Release`')
    ]
    [ValidateNotNullOrEmpty()]
    [string] `$NuGetKey,
    [Parameter(Mandatory)]
    [string]`$ModuleName

)

#To plan the cross-platform
# Nice article: https://powershell.org/2019/02/tips-for-writing-cross-platform-powershell-code/
`$DS = [io.path]::DirectorySeparatorChar

# Analyze step
if (`$PSBoundParameters.ContainsKey(`'Analyze`')) {
    if (-not (Get-Module -Name PSScriptAnalyzer -ListAvailable)) {
        Write-Warning `"Module `'PSScriptAnalyzer`' is missing or out of date. Installing `'PSScriptAnalyzer`' ...`"
        Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
    }

    #Invoke-ScriptAnalyzer -Path .\src -Recurse -EnableExit -ExcludeRule 'PSUseShouldProcessForStateChangingFunctions'
    Invoke-ScriptAnalyzer -Path `$PSScriptRoot -Recurse -ExcludeRule `'PSUseShouldProcessForStateChangingFunctions`',`'PSUseToExportFieldsInManifest`'
}

# Test step
if (`$PSBoundParameters.ContainsKey(`'Test`')) {
    if (-not (Get-Module -Name Pester -ListAvailable) -or (Get-Module -Name Pester -ListAvailable)[0].Version -eq [Version]`'3.4.0`') {
        Write-Warning `"Module `'Pester`' is missing. Installing `'Pester`' ...`"
        Install-Module -Name Pester -Scope CurrentUser -Force
    }

    if (Get-Module `$ModuleName) {
        Remove-Module `$ModuleName -Force
    }

    #".\`$ModuleName\`$ModuleName.psd1"
    `$TempPath = `"{0}`$DS{1}`$DS{2}{3}`" -f `$PSScriptRoot,`$ModuleName,`$ModuleName,`'.psd1`'
    if (-not (Test-Path `$TempPath)) {
        Throw `"Compile your module first before testing it`"
    }

    #".\`$ModuleName\`$ModuleName.psm1"
    `$TempPath = `"{0}`$DS{1}`$DS{2}{3}`" -f `$PSScriptRoot,`$ModuleName,`$ModuleName,`'.psd1`'
    import-module `$TempPath

    `$TempPath = Join-Path `$PSScriptRoot `'test`'
    `$Result = Invoke-Pester -Script @{Path = `$TempPath; Parameters = @{ModuleName = `"`$ModuleName`" } } -OutputFormat NUnitXml -OutputFile TestResults.xml -PassThru

    if (`$Result.FailedCount -gt 0) {
        throw `"`$(`$Result.FailedCount) tests failed.`"
    }
}

# Compile step
if (`$PSBoundParameters.ContainsKey(`'Compile`')) {
    if (Get-Module `$ModuleName) {
        Remove-Module `$ModuleName -Force
    }

    `$TempPath = Join-Path `$PSScriptRoot `$ModuleName
    if ((Test-Path `$TempPath)) {
        Remove-Item -Path `$TempPath -Recurse -Force
    }

    if (-not (Test-Path `$TempPath)) {
        `$null = New-Item -Path `$TempPath -ItemType Directory
    }

    `$TempPath = `"{0}`$DS{1}`$DS{2}`" -f `$PSScriptRoot,`'src`',`'private`'
    if ((Test-Path `$TempPath)) {
        `$TempPath = `"{0}`$DS{1}`$DS{2}`$DS{3}`" -f `$PSScriptRoot,`'src`',`'private`',`'*.ps1`'
        `$TempPath2= `"{0}`$DS{1}`$DS{2}{3}`" -f `$PSScriptRoot,`$ModuleName,`$ModuleName,`'.psm1`'
        Get-ChildItem -Path `$TempPath -Recurse | Get-Content -Raw | ForEach-Object {`"``r``n`$_`"} | Add-Content `$TempPath2
    }

    Copy-Item -Path `$(Join-Path `$PSScriptRoot `'README.md`') -Destination `$(Join-Path `$PSScriptRoot `$ModuleName) -Force
    Copy-Item -Path `"`$ModuleName.psd1`" -Destination `$(Join-Path `$PSScriptRoot `$ModuleName) -Force

    ## Update build version in manifest
    `$TempPath = `"{0}`$DS{1}`$DS{2}{3}`" -f `$PSScriptRoot,`$ModuleName,`$ModuleName,`'.psd1`'
    `$manifestContent = Get-Content -Path `$TempPath -Raw
    `$manifestContent -replace `"ModuleVersion = `'<ModuleVersion>`'`", `"ModuleVersion = `'`$BuildVersion`'`" | Set-Content -Path `$TempPath

    `$TempPath = `"{0}`$DS{1}`$DS{2}`$DS{3}`" -f `$PSScriptRoot,`'src`',`'public`',`'*.ps1`'
    `$Public = @( Get-ChildItem -Path `$TempPath -ErrorAction SilentlyContinue )

    `$TempPath = `"{0}`$DS{1}`$DS{2}{3}`" -f `$PSScriptRoot,`$ModuleName,`$ModuleName,`'.psm1`'
    `$Public | Get-Content -Raw | ForEach-Object {`"``r``n`$_`"} | Add-Content `$TempPath

    `"``r``nExport-ModuleMember -Function `'`$(`$Public.BaseName -join `"`', `'`")`'`" | Add-Content `$TempPath
}

# Doc step
if (`$PSBoundParameters.ContainsKey(`'Doc`')) {
    if (-not (Get-Module -Name PlatyPS -ListAvailable)) {
        Write-Warning `"Module `'PlatyPS`' is missing. Installing `'PlatyPS`' ...`"
        Install-Module -Name PlatyPS -Scope CurrentUser -Force
    }

    if (Get-Module `$ModuleName) {
        Remove-Module `$ModuleName -Force
    }

    `$TempPath = `"{0}`$DS{1}`$DS{2}{3}`" -f `$PSScriptRoot,`$ModuleName,`$ModuleName,`'.psd1`'
    if (-not (Test-Path `$TempPath)) {
        Throw `"Compile your module first before testing it`"
    }
    import-module `$TempPath

    # Regenerate all fresh docs
    Try {
        Remove-Item -Path `$(Join-Path `$PSScriptRoot `'docs`') -Recurse -Force
        #Generate the doc
        `$null = New-MarkdownHelp -Module `$ModuleName -OutputFolder `$(Join-Path `$PSScriptRoot `'docs`') -Force
    }
    Catch {
        throw `$_
    }
}

# Release step
if (`$PSBoundParameters.ContainsKey(`'Release`')) {
    # Release Module to PowerShell Gallery
    Try {
        `$Splat = @{
            Path        = `"`$([Environment]::PIPELINE_WORKSPACE)\`$ModuleName`"
            NuGetApiKey = `$NuGetKey
            ErrorAction = `'Stop`'
        }
        Publish-Module @Splat

        Write-Output `"`$ModuleName PowerShell Module published to the PowerShell Gallery`"
    }
    Catch {
        throw `$_
    }
}
"@

$BuildPs1 | Out-File -FilePath $(Join-Path $path 'Build.ps1')


#Create README.md
$ReadMe =@"
# $ModuleName

A PowerShell module for $ModuleName

## Install

``````powershell
Install-Module -Name $ModuleName
``````

## Disclaimer

This module was created AS IS with no warranty !
"@

$ReadMe | Out-File -FilePath $(Join-Path $path 'README.md')

#Create non compiled psm1
$psm1 =@"
`$Public = @( Get-ChildItem -Path `$PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
`$Private = @( Get-ChildItem -Path `$PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )

Foreach (`$Import in @(`$Public + `$Private)) {
    Try {
        . `$Import.fullname
    }
    Catch {
        Write-Error -Message `"Failed to import function `$(`$Import.fullname): `$_`"
    }
}

Export-ModuleMember -Function `$Public.Basename

"@

$TempPath = "{0}$DS{1}{2}" -f $Path,$ModuleName,'.psm1'
$psm1 | Out-File -FilePath $TempPath

# Create the module and private function directories
$null = mkdir $(Join-Path $path $ModuleName)
$null = mkdir $(Join-Path $path 'src')
$TempPath = "{0}$DS{1}$DS{2}" -f $Path,'src','private'
$null = mkdir $TempPath
$TempPath = "{0}$DS{1}$DS{2}" -f $Path,'src','public'
$null = mkdir $TempPath
$null = mkdir $(Join-Path $path 'test')
$null = mkdir $(Join-Path $path 'docs')

#Create the first generic pester test
$BasicPester =@"
param (
    `$ModuleName
)

Describe "`$ModuleName Module" {
    Context 'Should import the module correctly' {

        It 'Should have at least one public function' {
            (Get-Command -Module `$ModuleName).Count | Should -BeGreaterThan 1
        }
    }
}
"@

$TempPath = "{0}$DS{1}$DS{2}{3}" -f $Path,'test',$Modulename,'.tests.ps1'
$BasicPester | Out-File -FilePath $TempPath

#Create dummy advanced function to help in copy paste
$DummyPs1 = @"
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
        [Parameter(Mandatory=`$true,
        ValueFromPipelineByPropertyName=`$true)]
        [ValidateSet(1, 2, 3)]
        [int]`$a,

        # b is the second number
        [Parameter(Mandatory=`$true,
        ValueFromPipelineByPropertyName=`$true)]
        [ValidateNotNullOrEmpty()]
        [int]`$b
    )

    return (`$a + `$b)
}
"@

$TempPath = "{0}$DS{1}$DS{2}$DS{3}" -f $Path,'src','public','Add-TwoNumber.ps1'
$DummyPs1 | Out-File -FilePath $TempPath

#Create the module and related files
$TempPath = "{0}$DS{1}{2}" -f $Path,$ModuleName,'.psd1'
$Splat =@{
    RootModule = "$ModuleName.psm1"
    CompanyName = $CompanyName
    Description = $Description
    PowerShellVersion = '5.0'
    Author = $Author
    ModuleVersion = '11.12.13'
    Path = $TempPath
}
New-ModuleManifest @Splat

#Let's generalize the module version in the manifest (idea took from Adam Bertram)
$TempPath = "{0}$DS{1}{2}" -f $Path,$ModuleName,'.psd1'
$manifestContent = Get-Content -Path $TempPath -Raw
$manifestContent -replace "ModuleVersion = '11.12.13'", "ModuleVersion = '<ModuleVersion>'" | Set-Content -Path $TempPath