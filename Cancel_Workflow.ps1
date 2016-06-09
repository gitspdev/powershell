Add-PSSnapin Microsoft.SharePoint.PowerShell

$date = Get-Date "01.05.2016 00:00:00 AM"
$sourceWebURL = ""
$sourceListName = ""

$spSourceWeb = Get-SPWeb $sourceWebURL
$spSourceList = $spSourceWeb.Lists[$sourceListName]
$spSourceItems = $spSourceList.Items | where {$_['Created'] -LT $date }

#Get Workflow Manager
$workflowmanager = $sourceWebURL.Site.WorkFlowManager

$spSourceItems.Workflows | ForEach-Object {

[Microsoft.SharePoint.Workflow.SPWorkflowManager]::CancelWorkflow($_); 
}

$spSourceWeb.Dispose();