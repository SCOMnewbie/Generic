
#https://amp.reddit.com/r/PowerShell/comments/8ecvbz/arrays_and_the_assignment_operator/?utm_source=reddit-android&__twitter_impression=true
#Instead of an array, now we create a Generic list instead
$results = New-Object System.Collections.Generic.List[System.Object]
#Select your two files
$Before = Import-Csv E:\WKS\avant.csv -Encoding UTF8
$After = Import-Csv E:\WKS\apres.csv -Encoding UTF8

#Merge both files to have global picture
$fullTab = $Before + $After | Sort-Object Computer -Unique

#Build a  nested HashTable to speed up the object Recreation at the end
$FullTabHash = @{}
Foreach ($Line in $fullTab) {
    $Values = @{        
        AD_Site_Name0 = $Line.AD_Site_Name0
        OS            = $Line.'operating system long name'
    }
    
    $Key = $Line.Computer
    $FullTabHash.Add($Key, $Values)
}

#Get differences
$Differences = Compare-Object $Before $After -property Computer

foreach ($Difference in $Differences) {

    #Build an object with the previous created hashtable
    $ComputerName = $Difference.Computer
    $OS = $FullTabHash[$ComputerName].OS
    $ADSite = $FullTabHash[$ComputerName].AD_Site_Name0

    $obj = New-Object -TypeName PSObject
    $obj | Add-Member -MemberType NoteProperty -Name ComputerName -Value $ComputerName
    $obj | Add-Member -MemberType NoteProperty -Name ADSite -Value $ADSite
    $obj | Add-Member -MemberType NoteProperty -Name OperatingSystem -value $OS

    #Just add the current object to the generic list
    $results.Add($obj)   
}
#With this method (and we use exactly the same logic) and with the same amount of data, we went from 30min to less than 10 seconds to run the script !

$results
