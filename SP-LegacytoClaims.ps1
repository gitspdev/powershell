Add-PSSnapin Microsoft.SharePoint.PowerShell

$WebAppName = "ENTER THE WEBAPPLICATION URL"
$wa = get-SPWebApplication $WebAppName
$wa.UseClaimsAuthentication = $true
$wa.Update()
$account = "ENTER FARM ACCOUNT domain\user"
$account = (New-SPClaimsPrincipal -identity $account -identitytype 1).ToEncodedString()
$wa = get-SPWebApplication $WebAppName
$zp = $wa.ZonePolicies("Default")
$p = $zp.Add($account,"PSPolicy")
$fc=$wa.PolicyRoles.GetSpecialRole("FullControl")
$p.PolicyRoleBindings.Add($fc)
$wa.Update()
$wa.MigrateUsers($true)
$wa.ProvisionGlobally()