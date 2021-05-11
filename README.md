# Snipe IT Powershell Scripts

These Scripts are shared to help other administrators streamline and automate the process of using Snipe IT Asset Management.

When I have a bit more time, I'll put together a module that's more standard and modular for the community to use for scripting. But for now, this is what I can share.

## Requirements

1. Powershell 
1. [SimplySql](https://www.powershellgallery.com/packages/SimplySql/1.6.2) Powershell Module
1. ConnectWise Automate(LabTech) Server.
1. Run this script on the same LAN as your server....unless you're ballsy enough to allow port 3306 to communicate on the WAN. 
1. Seriously though, don't leave 3306 exposed to the WAN, mate.

## Get-LTAgents.ps1

This script retrieves agent computers for a given Client Location in LabTech. 

Make sure you enter your values in the variables at the top. I recommend creating a Read-Only LabTech User. Recent patches from ConnectWise have caused havoc with regular user accounts and their SQL access. It's safer to create a new Read-Only user in MySQL.

```powershell
$fqdn = "Your-Snipe-IT-tenant-name"
$key = "Your-SnipeIT-API-Token-Here"
$ltUser = "Your LT UserName Here"
$ltServer = 'Your-LT-Server-Address'
[string][ValidateNotNullOrEmpty()]$ltPass = "Your LT Password Here"
```

Alter the SQL query in the script to retrieve whatever agent information you want and then you can use that to POST into your Snipe IT instance.

You can change the `WHERE` to be Client ID if you'd like. For my purposes, we only needed it done by location. Make sure you select the proper ID. I do not have any confirmations in these functions. If you need that, you can add those.

You can get fancy for clients with multiple Automate locations and leverage the location attribute in Snipe IT. I have not done that but it should be simple enough.

```powershell
$agents = Invoke-SQLQuery  -Query 'SELECT computers.ComputerID,computers.Name,computers.Username,computers.OS,computers.BiosMFG,computers.BiosVer,computers.LocalAddress,computers.MAC,computers.DateAdded FROM computers WHERE computers.LocationID = 367'
```

Inspect the code closely and notice where the POST requests are made to Snipe IT. Look at the [API reference](https://snipe-it.readme.io/reference) and see what pieces of information are required.

You will likely want to add logic for different models. When I wrote this, we only had to get several hundred of the same make and model of asset into the system so I don't have any functions in there that deal with multiple models.

There is a function for adding a manufacturer that I wrote just so I wouldn't have to manually create that bit.

## Set-CheckOut.ps1

This script automates device checkout. If a user is signed into a machine when the script is run, the machine will be checked out to the user in Snipe IT.

You will need to have users populated into Snipe IT before this script will do you any good. If you're savvy enough, you can pretty easily populate them dynamically from LabTech's data for Last Logged In User if that is good enough.

You will need to modify this function to suit your needs. I only needed to check out assets to users signed in with AzureAD accounts on Azure-AD-Joined machines. So this function only checks for that criteria.

```powershell
function Find-LTUser($user) {
    if ($user -Match "AzureAD") {
        $output = ($user.Substring(8)).Trim(",0:")
    } else {
        $output = $false
    }
    return $output
}
```
Same deal here with the SQL query as the above script. Modify it to suit your needs.




