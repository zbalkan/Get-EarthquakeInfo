# Get-EarthquakeInfo
A cmdlet that outputs "Recent Earthquakes" data from Kandilli Observatory and Earthquake Research Institute (KOERI).

## DESCRIPTION
   Data is fetched from "http://www.koeri.boun.edu.tr/scripts/lasteq.asp" address by default. But it can also use Turkish page "http://www.koeri.boun.edu.tr/scripts/lst7.asp".
### EXAMPLE
   `Get-EarthquakeInfo # Gets full data as a list`
### EXAMPLE
   `Get-EarthquakeInfo -ResultSize 50 | Format-Table # Last 50 earthquake records printed as a table for better readability`
### EXAMPLE
   `Get-EarthquakeInfo -Url "http://www.koeri.boun.edu.tr/scripts/lst6.asp" # Alternative URL is used in case of outage or address change`
## INPUTS
   - `URL` (Default value: http://www.koeri.boun.edu.tr/scripts/lasteq.asp)
   - `ResultSize` (Default value: 500. Cannot be highler than 500 as the page consists of last 500 records.)
## OUTPUTS
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
## NOTES
   - Since there is not an API published by KOERI, the data needed to be parsed from plain text in `pre` tags. So there might be issues with uncommon formatting some day.
   - Since Date and Time are separately stored as strings with `yyyy.MM.dd` and `HH.mm.ss` formats, it is easier to group records per day and sort by time. On the other hand, the `DateTime` property is an instance of `DateTime` struct, so that you can make calculations with it.
   - `MeasurementType` propery is an enum which consists two values: `Quick` and `Revised`.
