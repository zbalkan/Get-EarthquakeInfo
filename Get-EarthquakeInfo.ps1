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
        $PreviousProgressReference = $ProgressPreference
        $ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
        if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent)
        {
            $Page = Invoke-WebRequest -Uri $URL -Verbose
        }
        else
        {
            $Page = Invoke-WebRequest -Uri $URL
        }
        $ProgressPreference = $PreviousProgressReference

        $StartIndex = $Page.Content.IndexOf("<pre>") + 7
        $EndIndex = $page.Content.IndexOf("</pre>") - 4
        $Text = $page.Content.Substring($StartIndex, $EndIndex - $StartIndex)
        
        [string[]]$RawList = $Text.Split("`n")
        if($ResultSize -eq 0) { $ResultSize = $RawList.Count } 
        $List = New-Object System.Collections.ArrayList

        $Max = $ResultSize
        if ($RawList.Count -lt $ResultSize)
        {
            $Max = $RawList.Count
        }

        Write-Verbose "Total $Max earthquaqe records have been found."

        for($i = 6; $i -lt $Max; $i++){ # Skipping since first 6 rows are titles, etc.

            $Item = $RawList[$i]
            
            $Title = ""
            $null = ([Regex]::new("[A-Za-z\(\)]*")).Matches($Item).Value | Where-Object { $_.Length -gt 0 } | ForEach-Object { $Title += $_ + " "}
            
            $Measurement = ""
            if ($Title.Contains("Quick"))
            {
                $Measurement = "Quick"
            }
            elseif ($Title.Contains("REVISE"))
            {
                $Measurement = "Revised"
            }

            $Title = $Title.Replace(" Quick","").Replace(" REVISE","")
            $Data = [PSCustomObject]@{
                Title = $Title
                Date = ([Regex]::new('\d{4}\.\d{2}\.\d{2}')).Matches($Item).Value
                Time = ([Regex]::new('\d{2}\:\d{2}\:\d{2}')).Matches($Item).Value
                Latitude = ([Regex]::new('\d{2}\.\d{4}')).Matches($Item).Value[0]
                Longtitude = ([Regex]::new('\d{2}\.\d{4}')).Matches($Item).Value[1]
                Depth = ([Regex]::new('\d\.\d')).Matches($Item).Value[4]
                Magnitude = ([Regex]::new('\d\.\d')).Matches($Item).Value[5]
                Measurement = $Measurement
            }
            
            $List.Add($Data) | Out-Null # Because Add() method prints index number to console, we need to add Out-Null
        }
        return $List
    }
}
