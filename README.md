# Get-EarthquakeInfo
A cmdlet that outputs "Recent Earthquakes" data from KANDILLI OBSERVATORY AND EARTHQUAKE RESEARCH INSTITUTE (KOERI)

### DESCRIPTION
   Data is fetched from "http://www.koeri.boun.edu.tr/scripts/lasteq.asp" address.
### EXAMPLE 1
   `Get-EarthquakeInfo # Gets full data as a list`
### EXAMPLE 2
   `Get-EarthquakeInfo -ResultSize 50 | Format-Table # Last 50 earthquake records printed as a table for better readability`
### EXAMPLE 3
   `Get-EarthquakeInfo -Url "http://www.koeri.boun.edu.tr/scripts/lst6.asp" # Alternative URL is used in case of outage or address change`
### INPUTS
   - URL
   - ResultSize
### OUTPUTS
   List of Earthquake records
### NOTES
   Since there is not an API published by KOERI, the data needed to be parsed from plain text in `pre` tags. So there might be issues with uncommon formatting some day.
