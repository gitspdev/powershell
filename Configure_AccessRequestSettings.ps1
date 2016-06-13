Add-PSSnapin Microsoft.SharePoint.PowerShell

# Get All Web Application
$webApp= Get-SPWebApplication
# Get All site collections
foreach ($SPsite in $webApp.Sites)
{
# get the collection of webs
foreach($SPweb in $SPsite.AllWebs)
{
# if a site inherits permissions, then the Access request mail setting also will be inherited
if (!$SPweb.HasUniquePerm)
{
Write-Host $SPweb.Name "Inheriting from Parent site"
}
elseif($SPweb.RequestAccessEnabled)
{
#Write-Host $SPweb.Name "Not Iheriting from Parent Site"
$SPweb.RequestAccessEmail ="" #If left emtpy Access Request will be disabled
$SPweb.Update()
        }
    }
}