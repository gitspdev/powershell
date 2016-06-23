param(
  [string]$siteCollectionUrl = $null, #"http://hostname",
  [array]$workflowAssociationNames = @(), # pass $null to cancel all
  [bool]$verbose = $true,
  [array]$workflowStatesToCancel = @(2,6,7)
  )

#Status  Value
#Not Started  0
#Failed on Start  1
#In Progress  2
#Error Occurred  3
#Canceled  4
#Completed  5
#Failed on Start (retrying)  6
#Error Occurred (retrying)  7
#Canceled  15
#Approved  16
#Rejected  17

Write-Host "Canceling workflows in the site collection..."

# Verify parameters
if([string]::IsNullOrEmpty($siteCollectionUrl))
{
  Write-Host "-siteCollectionUrl parameter is required" -F Red
  return
}
if($workflowAssociationNames -ne $null `
  -and $workflowAssociationNames.length -lt 1)
{
  $errMsg = "-workflowAssociationNames parameter must be provided. "
  Write-Host "$errMsg" -F Red
  return
}

# Iterate all webs
$site = Get-SPSite $siteCollectionUrl
$allWebs = $site.AllWebs
foreach($web in $allWebs)
{
  try
  {
    # Iterate all lists
    $lists = $web.Lists
    for($listIndex = 0; $listIndex -lt $lists.Count; $listIndex++)
    {
      $list = $lists[$listIndex]
      
      # Get the collection of workflow associations with running instances
      $was = @()
      foreach ($wa in $list.WorkflowAssociations)
      {
        if($wa.RunningInstances -gt 0)
        {
          $was += $wa
        }
      }
      
      # Check if the list has the workflow we want
      $checkList = $false
      $tempWorkflowAssociationNames = @()
      if($workflowAssociationNames -ne $null)
      {
        foreach($wa in $was)
        {
          if($workflowAssociationNames -contains $wa.Name)
          {
            $tempWorkflowAssociationNames += $wa.Name
          }
        }
        $checkList = $true
      }
      else
      {  
        foreach($wa in $was)
        {
          $tempWorkflowAssociationNames += $wa.Name
          $checkList = $true
        }
      }
      
      # Only investigate list if it has workflow associations
      if($checkList)
      {
        # Query for items that have a column for the workflow 
        # where the column value is not null or empty not is 
        # in the $workflowStatesToSkipCancel array.
        $spQuery = New-Object Microsoft.SharePoint.SPQuery
        $spQuery.ViewAttributes = "Scope='Recursive'"
        $spQuery.RowLimit = 2000
        $spQuery.ViewFieldsOnly = $true
        $spQuery.ViewFields = "<FieldRef Name='FileLeafRef'/>"
        
        # Map workflow association name to column name
        $failedToMapToColumns = $false
        $fieldInternalNames = @()
        foreach($wan in $tempWorkflowAssociationNames)
        {
          try
          {
            $field = $list.Fields.GetField($wan)
            $fieldInternalNames += $field.InternalName
          }
          catch [Exception]
          {
            #Write-Host "Failed to find field $wan on list $($list.Title)" -F Red
            $failedToMapToColumns = $true
          }
        }
        
        # Only attempt to query if we have a field to query against
        if($fieldInternalNames.Length -gt 0 -or $failedToMapToColumns)
        {
          # Build caml query to get items with running workflows
          if(!$failedToMapToColumns)
          {
            $camlFrags = @()
            foreach($fin in $fieldInternalNames)
            {
              foreach($state in $workflowStatesToCancel)
              {
                $camlFrags += "<Eq><FieldRef Name='$fin' />"
                $camlFrags += "<Value Type='WorkflowStatus'>$state</Value></Eq>"
              }
            }      
            $caml = GetNestedCaml $camlFrags "Or"
            $caml = "<Where>$caml</Where>"
            $spQuery.Query = $caml 
          }
          else
          {
            $spQuery.Query = ""
          }
          
          do
          {
            # Iterate all items with workflows that we wish to cancel
            $listItems = $list.GetItems($spQuery)
            $spQuery.ListItemCollectionPosition = $listItems.ListItemCollectionPosition
            for($itemIndex = 0; $itemIndex -lt $listItems.Count; $itemIndex++)
            {
              try
              {
                $item = $listItems[$itemIndex]

                $wfGuids = @()
                foreach ($workflow in $item.Workflows) 
                {
                  $wfpan = $workflow.ParentAssociation.Name
                  if($tempWorkflowAssociationNames -contains $wfpan)
                  {
                    $wfGuids += $workflow.InstanceId
                  }
                }
                
                foreach ($wfGuid in $wfGuids) 
                {
                  # Ensure that the workflow is in a 'running' state
                  $workflow = $item.Workflows[$wfGuid]
                  $wfState = [Microsoft.SharePoint.Workflow.SPWorkflowState]::Running
                  $isWfInState = ($workflow.InternalState -band $wfState) -eq $wfState
                  if($isWfInState)
                  {
                    #Cancel Workflows        
                    [Microsoft.SharePoint.Workflow.SPWorkflowManager]::CancelWorkflow($workflow)
                    if($verbose)
                    {
                      Write-Host "Workflow canceled: $($workflow.ParentAssociation.Name) on $($item.Name)"
                    }
                  }
                }
              }
              catch [Exception]
              {
                Write-Host "Error: $($item.ServerRelativeUrl) $($Error[0])" -F Red
              }
            }
          }
          while ($spQuery.ListItemCollectionPosition -ne $null)
        }
      }
    }
  }
  catch [Exception]
  {
    Write-Host "Error: $($web.Url) $($Error[0])" -F Red
  }
  finally
  {
    $web.Dispose()
  }
}
$site.Dispose()

Write-Host "DONE" -F Green