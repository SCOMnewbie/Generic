#Create an array
$results = @()
#Import your two files
$Before = Import-Csv E:\WKS\avant.csv -Encoding UTF8
$After = Import-Csv E:\WKS\apres.csv -Encoding UTF8
#Merge both of them to get all computer name (global picture)
$fullTab = $Before + $After | Sort-Object Computer -Unique

#$Differences = Compare-Object $avant $apres -property Computer | Where-Object {$_.sideIndicator -eq "=>"}
$Differences = Compare-Object $Before $After -property Computer 

foreach ($Difference in $Differences) {
    $ComputerName = $Difference.Computer 
    #Recreate an object with all properties
    $Results += $fullTab | Where-Object {$_.Computer -eq $ComputerName}
}
#With this method, it takes between 1 and 2 seconds with 20K lines in $fullTab and something like 1.5K lines in the Differences variables. More lines you have in $fulltab
#More seconds you have to spend per line. 
#With this method ans those numbers, it tooks an average of 1800 seconds >>> 30 min 
$Results