<#
.Synopsis
   A cmdlet that outputs "Recent Earthquakes" data from Kandilli Observatory and Earthquake Research Institute (KOERI).
.DESCRIPTION
   Data is fetched from "http://www.koeri.boun.edu.tr/scripts/lasteq.asp" address by default. But it can also use Turkish page "http://www.koeri.boun.edu.tr/scripts/lst7.asp".
.EXAMPLE
   `Get-EarthquakeInfo # Gets full data as a list`
.EXAMPLE
   `Get-EarthquakeInfo -ResultSize 50 | Format-Table # Last 50 earthquake records printed as a table for better readability`
.EXAMPLE
   `Get-EarthquakeInfo -Url "http://www.koeri.boun.edu.tr/scripts/lst6.asp" # Alternative URL is used in case of outage or address change`
.INPUTS
   - `URL` (Default value: http://www.koeri.boun.edu.tr/scripts/lasteq.asp)
   - `ResultSize` (Default value: 500. Cannot be highler than 500 as the page consists of last 500 records.)
.OUTPUTS
   List of Earthquake records.

   ```yaml
   Title           : Gemlik Korfezi (Marmara Sea)
   Date            : 2023.12.04
   Time            : 15:25:15
   DateTime        : 12/04/2023 15:25:15
   Latitude        : 40.4268
   Longtitude      : 28.8648
   Depth           : 5.0
   Magnitude       : 1.9
   MeasurementType : Quick
   ```
.NOTES
   - Since there is not an API published by KOERI, the data needed to be parsed from plain text in `pre` tags. So there might be issues with uncommon formatting some day.
   - Since Date and Time are separately stored as strings with `yyyy.MM.dd` and `HH.mm.ss` formats, it is easier to group records per day and sort by time. On the other hand, the `DateTime` property is an instance of `DateTime` struct, so that you can make calculations with it.
   - `MeasurementType` propery is an enum which consists two values: `Quick` and `Revised`.#>
function Get-EarthquakeInfo
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        # Default: "http://www.koeri.boun.edu.tr/scripts/lasteq.asp"
        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $false,
            Position = 0)]
        [ValidateScript({
                $uri = [System.Uri]::new($_)
                if ($uri.IsWellFormedOriginalString())
                {
                    $true
                }
                else
                {
                    throw "$_ is invalid. Please provide a valid URL"
                }
            })]
        [string]
        $URL = 'http://www.koeri.boun.edu.tr/scripts/lasteq.asp',

        # For performance causes ResultSize parameter is defined. The same result can be obtained by using 
        # "Get-EarthquakeInfo | Select-Object -First 50" command which is recommended.
        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $false)]
        [ValidateRange(1, 500)]
        [int]
        $ResultSize = 500
    )

    Begin
    {
        function parseTitle
        {
            param ($Record)
            $Title = ''
            $null = ([Regex]::new('[A-Za-z\(\)İıÖöÜüÇçĞğŞş]*')).Matches($Record).Value | Where-Object { $_.Length -gt 0 } | ForEach-Object { $Title += $_ + ' ' }
            return $Title
        }

        function cleanupTitle
        {
            param ($Title)
            $Title = $Title.Replace(' Quick', '').Replace(' İlksel', '').Replace(' Ilksel', '').Replace(' REVISE', '').Replace(' REVIZE', '').Replace(' ( )', '').ToLower()
            $NewTitle = ''
            $Words = $Title.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
            foreach ($word in $Words)
            {
                if ($word.Length -gt 1)
                {
                    if ($word[0] -eq '(')
                    {
                        $word = '(' + [char]::ToUpper($word[1]) + $word.Substring(2)
                    }
                    else
                    {
                        $word = [char]::ToUpper($word[0]) + $word.Substring(1)
                    }
                }
                else
                {
                    $word = $word.Toupper()
                }
                $NewTitle = [string]::Join(' ', $NewTitle, $word).Trim()
            }
            return $NewTitle
        }

        function parseDateOnly
        {
            param ($Record)
            Write-Debug 'Parsing dates'
            $DateMatches = @(([Regex]::new('\d{4}\.\d{2}\.\d{2}')).Matches($Record))
            return $DateMatches
        }

        function parseTimeOnly
        {
            param ($Record)
            Write-Debug 'Parsing dates'
            $TimeMatches = @(([Regex]::new('\d{2}\:\d{2}\:\d{2}')).Matches($Record))
            return $TimeMatches
        }

        function parseDateTime
        {
            param ($DateMatches, $TimeMatches)

            $Dates = [System.Collections.Generic.List[datetime]]::new()
            for ($i = 0; $i -lt $DateMatches.Count; $i++)
            {
                $DateOnly = [datetime]::Parse($DateMatches[$i].Value, [cultureinfo]::InvariantCulture)
                Write-Debug $DateOnly.Date.ToString('d')
                $TimeOnly = [datetime]::Parse($TimeMatches[$i].Value, [cultureinfo]::InvariantCulture)
                Write-Debug $TimeOnly.TimeOfDay
                $DateTime = $DateOnly.Date + $TimeOnly.TimeOfDay
                Write-Debug $DateTime
                $Dates.Add($DateTime)
            }
            return $Dates
        }

        enum MeasurementType
        {
            Quick
            Revised
        }

        function parseMeasurementType
        {
            param ($Title)
            if ($RawTitle.Contains('Quick') -or $RawTitle.Contains('İlksel') -or $RawTitle.Contains('Ilksel'))
            {
                return [MeasurementType]::Quick
            }
            elseif ($RawTitle.Contains('REVISE') -or $RawTitle.Contains('REVIZE'))
            {
                return [MeasurementType]::Revised
            }
        }

        function getContent
        {
            param (
                $URL
            )

            $MaximumRetries = 5 # Retry 5 times
            $RetrySleepSeconds = 1 # The time between the retries will increase linearly

            $client = [System.Net.Http.HttpClient]::new()
            $Content = $null
            for ($i = 0; $i -lt $MaximumRetries; $i++)
            {
                try
                {
                    Write-Verbose "Trying to connect to $URL"
                    $Content = $client.GetStringAsync($URL).GetAwaiter().GetResult()
                    break
                }
                catch
                {
                    Write-Verbose "Failed to connect to $URL"
                    $Attempt = ($i + 1)
                    $Sleep = $RetrySleepSeconds * $Attempt
                    Write-Verbose "Waiting for $Sleep second(s)"
                    Start-Sleep -Seconds $Sleep
                    Write-Verbose "Retrying (Attempt $Attempt out of $MaximumRetries)..."
                }
            }
            if ($null -eq $Content)
            {
                Write-Error "Failed to connect to $URL"
            }
            $client.Dispose()

            $TurkishEncoding = [System.Text.Encoding]::GetEncoding('windows-1254')
            $Content = $TurkishEncoding.GetString([System.Text.Encoding]::GetEncoding('windows-1252').GetBytes($Content))

            return $Content
        }

        function parseLines
        {
            param (
                $Content,
                $ResultSize
            )

            $StartIndex = $Content.IndexOf('<pre>') + 5
            $EndIndex = $Content.IndexOf('</pre>')
            $Text = $Content.Substring($StartIndex, $EndIndex - $StartIndex)
            $Lines = $Text.Split([System.Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
            $HeaderLineCount = 6  # Skipping since first 6 rows are titles, etc.

            $Records = New-Object string[] $ResultSize
            [Array]::Copy($Lines, $HeaderLineCount, $Records, 0, $ResultSize)

            return $Records
        }

        function parseRecords
        {
            param ($Records)
            $EarthquakeRecords = [System.Collections.Generic.List[psobject]]::new()

            foreach ($Record in $Records)
            {
                $RawTitle = parseTitle -Record $Record

                $DateMatches = parseDateOnly -Record $Record
                $TimeMatches = parseTimeOnly -Record $Record
                Write-Debug "Found $($DateMatches.Count) dates"

                $Data = [PSCustomObject]@{
                    Title           = cleanupTitle -Title $RawTitle
                    Date            = $DateMatches
                    Time            = $TimeMatches
                    DateTime        = parseDateTime -DateMatches $DateMatches -TimeMatches $TimeMatches
                    Latitude        = ([Regex]::new('\d{2}\.\d{4}')).Matches($Record).Value[0]
                    Longtitude      = ([Regex]::new('\d{2}\.\d{4}')).Matches($Record).Value[1]
                    Depth           = ([Regex]::new('\d\.\d')).Matches($Record).Value[4]
                    Magnitude       = ([Regex]::new('\d\.\d')).Matches($Record).Value[5]
                    MeasurementType = parseMeasurementType -Title $RawTitle
                }
                $EarthquakeRecords.Add($Data) | Out-Null # Because Add() method prints index number to console, we need to add Out-Null
            }
            return $EarthquakeRecords
        }
    }
    Process
    {
        $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

        $Records = parseLines -Content (getContent -URL $URL) -ResultSize $ResultSize
        Write-Verbose "Total $ResultSize earthquake records will be displayed."

        return parseRecords -Records $Records
    }
}
