<#
.Synopsis
   A cmdlet that outputs "Recent Earthquakes" data from KANDILLI OBSERVATORY AND EARTHQUAKE RESEARCH INSTITUTE (KOERI)
.DESCRIPTION
   Data is fetched from "http://www.koeri.boun.edu.tr/scripts/lasteq.asp" address by default. But it can also use Turkish page "http://www.koeri.boun.edu.tr/scripts/lst7.asp".
.EXAMPLE 1
   `Get-EarthquakeInfo # Gets full data as a list`
.EXAMPLE 2
   `Get-EarthquakeInfo -ResultSize 50 | Format-Table # Last 50 earthquake records printed as a table for better readability`
.EXAMPLE 3
   `Get-EarthquakeInfo -Url "http://www.koeri.boun.edu.tr/scripts/lst6.asp" # Alternative URL is used in case of outage or address change`
.INPUTS
   - URL (Default value: http://www.koeri.boun.edu.tr/scripts/lasteq.asp)
   - ResultSize (Default value: None. Returns all data.)
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
    [ValidateScript({
        $uri = [System.Uri]::new($_)
        if ($uri.IsWellFormedOriginalString()) {
            $true
        } else {
            throw "$_ is invalid. Please provide a valid URL"
        }
    })]
    [string]
    $URL = "http://www.koeri.boun.edu.tr/scripts/lasteq.asp",

    # For performance causes ResultSize parameter is defined. The same result can be obtained by using 
    # "Get-EarthquakeInfo | Select-Object -First 50" command which is recommended.
    [Parameter(Mandatory=$false,
    ValueFromPipelineByPropertyName=$false)]
    [ValidateRange(1,500)]
    [int]
    $ResultSize = 500
    )
    
    Process {
        $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

        $PreviousProgressReference = $ProgressPreference
        $ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
        $Page = Invoke-WebRequest -Uri $URL
        $ProgressPreference = $PreviousProgressReference

        $TurkishEncoding = [System.Text.Encoding]::GetEncoding("windows-1254")
        $Content = $TurkishEncoding.GetString([System.Text.Encoding]::GetEncoding("windows-1252").GetBytes($page.Content))

        $StartIndex = $Content.IndexOf("<pre>") + 7
        $EndIndex = $Content.IndexOf("</pre>") - 4
        $Text = $Content.Substring($StartIndex, $EndIndex - $StartIndex)
        
        [string[]]$RawList = $Text.Split("`n")
        $EarthquakeRecords = New-Object System.Collections.ArrayList
        Write-Verbose "Total $ResultSize earthquake records will be displayed."

        $HeaderLineCount = 6  # Skipping since first 6 rows are titles, etc.
        for($i = $HeaderLineCount; $i -lt $ResultSize + $HeaderLineCount; $i++){
            Write-Debug "Line number: $i"

            $Item = $RawList[$i]

            $Title = ""
            $null = ([Regex]::new("[A-Za-z\(\)İıÖöÜüÇçĞğŞş]*")).Matches($Item).Value | Where-Object { $_.Length -gt 0 } | ForEach-Object { $Title += $_ + " "}
            
            $Measurement = ""
            if ($Title.Contains("Quick") -or $Title.Contains("İlksel") -or $Title.Contains("Ilksel"))
            {
                $Measurement = "Quick"
                $Revised = ""
            }
            elseif ($Title.Contains("REVISE") -or $Title.Contains("REVIZE"))
            {
                $Measurement = "Revised"
                $Revised = ([Regex]::new("\((?:20[012][0-9])[-/.](?:0[1-9]|1[012])[-/.](?:0[1-9]|[12][0-9]|3[01])\s(?:[0-5][0-9]\:[0-5][0-9]\:[0-5][0-9])\)")).Matches($Item).Value.Replace("(","").Replace(")","")
            }

            $Title = $Title.Replace(" Quick","").Replace(" İlksel","").Replace(" Ilksel","").Replace(" REVISE","").Replace(" REVIZE","").Replace(" ( )","")
            $Data = [PSCustomObject]@{
                Title = $Title
                Date = ([Regex]::new('\d{4}\.\d{2}\.\d{2}')).Matches($Item).Value
                Time = ([Regex]::new('\d{2}\:\d{2}\:\d{2}')).Matches($Item).Value
                Latitude = ([Regex]::new('\d{2}\.\d{4}')).Matches($Item).Value[0]
                Longtitude = ([Regex]::new('\d{2}\.\d{4}')).Matches($Item).Value[1]
                Depth = ([Regex]::new('\d\.\d')).Matches($Item).Value[4]
                Magnitude = ([Regex]::new('\d\.\d')).Matches($Item).Value[5]
                Measurement = $Measurement
                Revised = $Revised
            }
            
            $EarthquakeRecords.Add($Data) | Out-Null # Because Add() method prints index number to console, we need to add Out-Null
        }
        return $EarthquakeRecords
    }
}
