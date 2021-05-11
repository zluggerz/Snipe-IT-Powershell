Import-Module SimplySql
$fqdn = "Your-Snipe-IT-tenant-name"
$key = "Your-SnipeIT-API-Token-Here"
$ltUser = "Your LT UserName Here"
$ltServer = 'Your-LT-Server-Address'
[string][ValidateNotNullOrEmpty()]$ltPass = "Your LT Password Here"

$global:headers = @{
    'Accept' = 'application/json'
    'Content-Type' = 'application/json'
    'Authorization' = "Bearer $key"
}
# Generic function to return data from any chosen API endpoint
function Get-SnipeData($endpoint) {
    $url = "https://$fqdn.snipe-it.io/api/v1/$endpoint"
    $response = Invoke-WebRequest -Method Get -Uri $url -Headers $global:headers
    return $response
}

# Add manufcaturer tag if it doesn't already exist
function Add-SnipeManufacturer($name) {
    $url = "https://$fqdn.snipe-it.io/api/v1/manufacturers"
    $data = [PSCustomObject]@{
        name = "$name"
    }
    $json = ConvertTo-Json -Depth 10 $data
    $req = Invoke-WebRequest -Method Post -Uri $url -Headers $global:headers -Body $json
    return $req
}

# Add LT agent to Snipe IT as an asset
function Add-AgentToSnipe($name,$serial) {
    $url = "https://$fqdn.snipe-it.io/api/v1/hardware"
    if ($serial) {
        $data = [PSCustomObject]@{
            status_id = 2
            model_id = 1
            name = "$name"
            serial = "$serial"
            asset_tag = "$serial"
        }
    } else {
        $data = [PSCustomObject]@{
            status_id = 2
            model_id = 1
            name = "$name"
        }
    }
    $json = ConvertTo-Json -Depth 10 $data
    $req = Invoke-WebRequest -Method Post -Uri $url -Headers $global:headers -Body $json
    return $req
}

$secpass = ConvertTo-SecureString -String $ltPass -AsPlainText -Force
$user = $ltUser
$dbCred = New-Object System.Management.Automation.PSCredential($user,$secpass)

Open-MySQLConnection -Server $ltServer -Database Labtech -Credential $dbCred
# Change the Location ID at the end of the SQL statement below
$agents = Invoke-SQLQuery  -Query 'SELECT computers.ComputerID,computers.Name,computers.Username,computers.OS,computers.BiosMFG,computers.BiosVer,computers.LocalAddress,computers.MAC,computers.DateAdded FROM computers WHERE computers.LocationID = 367'

Close-SQLConnection

$hardware = Get-SnipeData("hardware") | ConvertFrom-Json
$names = @()
foreach ($agent in $hardware.rows) {
    $names += $agent.name
}

$mfgs = Get-SnipeData("manufacturers") | ConvertFrom-Json
$mfgnames = @()
foreach ($mfg in $mfgs.rows) {
    $mfgnames += $mfg.name
}

ForEach ($agent in $agents) {
    if ($names -contains $agent.Name) {
        "Asset exists!"
     } else {
        Add-AgentToSnipe($agent.Name)
     }
    if ($mfgnames -contains $agent.BiosMFG) {
        "Manufacturer Exists!"
    } else {
        Add-SnipeManufacturer($agent.BiosMFG)
    }
}