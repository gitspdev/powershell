Add-PSSnapin Microsoft.SharePoint.PowerShell

Get-SPSite -Limit All  | Get-SPWeb  -Limit ALL | %{$_.Lists} | ?{$_.ID –eq "Enter List GUID"} | ft Title, ParentWebURL, RootFolder