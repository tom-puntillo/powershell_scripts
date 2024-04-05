# Define the folder to search
$folderPath = "C:\Path\to\folder"

# Define the list of keywords to search for
$keywords = @("keyword1", "keyword2", "keyword3")

# Define the start and end date/time for the search timeframe
$startDate = Get-Date "2024-01-01"
$endDate = Get-Date "2024-01-31"

# Function to search files for the keywords
function Search-Files {
    param (
        [string]$folder,
        [string[]]$keywords,
        [datetime]$startDate,
        [datetime]$endDate
    )

    # Get all files in the folder
    $files = Get-ChildItem $folder -Recurse | Where-Object { $_.LastWriteTime -ge $startDate -and $_.LastWriteTime -le $endDate }

    # Loop through each file
    foreach ($file in $files) {
        # Check if file is not a directory
        if (-not $file.PSIsContainer) {
            # Read the file content
            $content = Get-Content $file.FullName -Raw
            # Loop through each keyword
            foreach ($keyword in $keywords) {
                # Check if content contains the keyword
                if ($content -like "*$keyword*") {
                    Write-Host "Found '$keyword' in file: $($file.FullName)"
                }
            }
        }
    }
}

# Call the function to search for files
Search-Files -folder $folderPath -keywords $keywords -startDate $startDate -endDate $endDate
