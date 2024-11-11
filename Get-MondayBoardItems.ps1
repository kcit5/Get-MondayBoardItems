function Get-MondayBoardItems{
    <#
    .SYNOPSIS
        This cmdlet queries Monday.com for Board items
    .DESCRIPTION
        This cmdlet queries Monday.com for Board items and returns them as PSObject
    .PARAMETER ColumnNames
        Specify columns if desired
        Formatting:
            "checkbox"
            ("checkbox", "status", "person")
    .PARAMETER ItemResults
        The Monday.com API default is set to 25 but this can be extended to avoid programmatically accessing multiple pages via GraphQL queries
    .Example
        Get-MondayBoardItems -ApiKey "xyz123" -BoardID 76351212
        Get-MondayBoardItems -ColumnNames ("checkbox", "status", "person") -BoardID "12345" -APIKey "abcde"
    #>

    param (
        [Parameter(Mandatory = $true)][string]$APIKey,
        [Parameter(Mandatory = $true)][string]$BoardID,
        [string]$ItemResults = 25, 
        [string]$APIurl = "https://api.monday.com/v2/",
        [array]$ColumnNames = $null
	)

    $jobresults = @()

    if ($null -eq $ColumnNames){
        #Constructing the GraphQL query in lieu of specific column names being supplied
        $query = "query { boards( ids: $BoardID ) { items_page( limit: $MondayAPIQuan){ items { id  name column_values { text id } } } } }"
    }

    else{
        #Construct the GraphQL query for specific column names
        # Loop through each column name and construct the query for that column
        $columnQueryParts = @()
	    foreach ($columnName in $ColumnNames) { $columnQueryParts += "`"$columnName`""  }

        # Join all the parts into a single string, separated by commas
        $columnQuery = $columnQueryParts -join ", "

        #Construct the query
        $query = "query { boards( ids: $BoardID ) { items_page( limit: $MondayAPIQuan){ items { id name column_values( ids: [$columnQuery] ) { text id } } } } }"
    }

    # Set up the HTTP request headers
	$headers = @{
		"Authorization" = $APIKey
		"Content-Type"  = "application/json"
	}
    # Format the query
    $body = @{
		query = $query
	} | ConvertTo-Json

    try {
        # Send the HTTP request to Monday.com API
		$response = Invoke-RestMethod -Uri $APIurl -Method Post -Headers $headers -Body $body
		# Extract items from the response
		$items = $response.data.boards.items_page.items

		# Output the items and their column values
		$items | ForEach-Object {
			$itemId = $_.id
			$itemName = $_.name
				
			# Create a PSCustomObject to store main item properties
			$psObject = [PSCustomObject]@{
				ItemId       = $itemId;
				ItemName     = $itemName;
			}

			# Add column values for the main item dynamically
			foreach ($columnValue in $_.column_values) {
				$psObject | Add-Member -MemberType NoteProperty -Name $columnValue.ID -Value $columnValue.text
			}

			$jobResults += [array]$psObject
        }
    }   
    catch {
        Write-Host "Error occurred: $_"
    }

    #Report back object array
    return [array]$jobResults
}
