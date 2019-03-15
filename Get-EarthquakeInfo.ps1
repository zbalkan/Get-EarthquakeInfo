<#
.Synopsis
   A cmdlet that outputs "Recent Earthquakes" data from KANDILLI OBSERVATORY AND EARTHQUAKE RESEARCH INSTITUTE (KOERI)
.DESCRIPTION
   Data is fetched from "http://www.koeri.boun.edu.tr/scripts/lasteq.asp" address.
.EXAMPLE
   Get-EarthquakeInfo # Gets full data as a list
.EXAMPLE
   Get-EarthquakeInfo -Take 50 | Format-Table #Last 50 earthquake records printed as a table for better readability
.EXAMPLE
   Get-EarthquakeInfo -Url "http://www.koeri.boun.edu.tr/scripts/lst6.asp" -Take 50 | Alternatice URL is used in case of outage or adress change
.INPUTS
   - URL
   - Take
.OUTPUTS
   List of Earthquake records
.NOTES
   Since there is not an API published by KOERI, the data needed to be parsed from plain text in <pre> tags. So there might be issues with uncommon formatting some day.
#>
function Get-EarthquakeInfo
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
    # Default: "http://www.koeri.boun.edu.tr/scripts/lasteq.asp"
    [Parameter(Mandatory=$false,
    ValueFromPipelineByPropertyName=$false,
    Position=0)]
    [string]
    $URL = "http://www.koeri.boun.edu.tr/scripts/lasteq.asp",

    # For performance causes ResultSize parameter is defined. The same result can be obtained by using 
    # "Get-EarthquakeInfo | Select-Object -First 50" command which is recommended.
    [Parameter(Mandatory=$false,
    ValueFromPipelineByPropertyName=$false)]
    [int]
    $ResultSize
    )
    
    Process {
        $Page = Invoke-WebRequest -Uri $URL      
        $Text = ($Page.AllElements | Where-Object { $_.tagName -eq "pre"}).innerText
        [string[]]$RawList = $Text.Split("`n")
        if($ResultSize -eq 0) { $ResultSize = $RawList.Count } 
        $List = New-Object System.Collections.ArrayList

        for($i = 6; $i -lt $ResultSize; $i++){ # Skipping since first 6 rows are titles etc.

            $Item = $RawList[$i]
            
            $Title = ""
            $null = ([Regex]::new("[A-Za-z]*")).Matches($Item).Value | Where-Object { $_.Length -gt 0 } | ForEach-Object { $Title += $_ + " "}
            
            $Data = [PSCustomObject]@{
                Title = $Title
                Date = ([Regex]::new('\d{4}\.\d{2}\.\d{2}')).Matches($Item).Value
                Time = ([Regex]::new('\d{2}\:\d{2}\:\d{2}')).Matches($Item).Value
                Latitude = ([Regex]::new('\d{2}\.\d{4}')).Matches($Item).Value[0]
                Longtitude = ([Regex]::new('\d{2}\.\d{4}')).Matches($Item).Value[1]
                Depth = ([Regex]::new('\d\.\d')).Matches($Item).Value[4]
                Magnitude = ([Regex]::new('\d\.\d')).Matches($Item).Value[5]
            }
            
            $List.Add($Data) | Out-Null # Because Add() method prints index number to console, we need to add Out-Null
        }
        return $List
    }
}
