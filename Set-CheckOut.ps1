Import-Module SimplySql

$fqdn = "Your-Snipe-IT-tenant-name"
$key = "your-api-token-here"
$ltUser = "Your LT UserName Here"
$ltServer = 'Your-LT-Server-Address'
[string][ValidateNotNullOrEmpty()]$ltPass = "Your LT Password Here"

Import-Module SimplySql

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


# For this scenario, we were checking out machines used by AAD users. Modify the conditional below to suit your needs
function Find-LTUser($user) {
    if ($user -Match "AzureAD") {
        $output = ($user.Substring(8)).Trim(",0:")
    } else {
        $output = $false
    }
    return $output
}


function Set-Asset($id,$user) {
    $url = "https://$fqdn.snipe-it.io/api/v1/hardware/$id/checkout"
    $data = [PSCustomObject]@{
        id = "$id"
        assigned_user = "$user"
        checkout_to_type = "user"
    }
    $json = ConvertTo-Json -Depth 10 $data
    $req = Invoke-WebRequest -Method Post -Uri $url -Headers $global:headers -Body $json
    return $req
}

function Set-AssetStatus($id) {
    $url = "https://$fqdn.snipe-it.io/api/v1/hardware/$id"
    $data = [PSCustomObject]@{
        status_id = 4
    }
    $json = ConvertTo-Json -Depth 10 $data
    $req = Invoke-WebRequest -Method Patch -Uri $url -Headers $global:headers -Body $json
    return $req
}

[string][ValidateNotNullOrEmpty()]$passw = $ltPassword
$secpass = ConvertTo-SecureString -String $passw -AsPlainText -Force
$user = $ltUser
$dbCred = New-Object System.Management.Automation.PSCredential($user,$secpass)

Open-MySQLConnection -Server $ltServer -Database Labtech -Credential $dbCred

$agents = Invoke-SQLQuery  -Query 'SELECT computers.ComputerID,computers.Name,computers.Username,computers.OS,computers.BiosMFG,computers.BiosVer,computers.LocalAddress,computers.MAC,computers.DateAdded FROM computers WHERE computers.LocationID = 367'

Close-SQLConnection

$snipeUsers = Get-SnipeData("users") | ConvertFrom-Json
$userPool = @()
foreach ($user in $snipeUsers.rows) {
    $person = [PSCustomObject]@{
        name = ($user.name -replace '\s','')
        email = $user.username
        id = $user.id
    }
    $userPool += $person
}

$hardware = Get-SnipeData("hardware") | ConvertFrom-Json
$machines = @()
foreach ($agent in $hardware.rows) {
    $machine = [PSCustomObject]@{
        name = $agent.Name
        id = $agent.id
        status = $agent.status_label.status_meta
    }
    if ($machine.status -eq "deployable") {
        $machines += $machine
    }
}

ForEach ($agent in $agents) {
    $userName = Find-LTUser($agent.Username)
    $computer = $agent.Name
    if ($userName) {
        $chUser = $userPool -match $userName
        if ($chUser) {
            $id = $machines | Where-Object {$_.name -match $computer}
            Set-Asset $id.id $chUser.id
            Set-AssetStatus($id.id)
        }
    }
}