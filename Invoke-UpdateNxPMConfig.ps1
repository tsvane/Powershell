$Username = ""
$Password = ""
$NginxPMServer = "http://<ip>:<port>"

# Do login returning Bearer token
$LoginResponse = Invoke-WebRequest -UseBasicParsing -Uri "$($NginxPMServer)/api/tokens" -Method "POST" -ContentType "application/json; charset=UTF-8" -Body "{`"identity`":`"$($Username)`",`"secret`":`"$($Password)`"}"
$Bearer = ($LoginResponse.content | ConvertFrom-Json).token

# Request current config from Nginx Proxy Manager
$CurrentConfigResponse = Invoke-WebRequest -UseBasicParsing -Uri "$($NginxPMServer)/api/nginx/proxy-hosts?expand=owner,access_list,certificate" `
    -Headers @{
    "method"        = "GET"
    "authorization" = "Bearer $($Bearer)"
} -ContentType "application/json; charset=UTF-8"
$CurrentConfig = $CurrentConfigResponse.Content | ConvertFrom-Json;

# Loop current config to re-apply and trigger re-write of conf-files
for ($i = 0; $i -lt $CurrentConfig.Count; $i++) {
    $Config = $CurrentConfig[$i]

    $HostID = $Config.id
    $PutObject = $Config | Where-Object { $_.id -eq $HostID } | Select-Object domain_names, forward_scheme, forward_host, forward_port, caching_enabled, block_exploits, allow_websocket_upgrade, access_list_id, certificate_id, ssl_forced, http2_support, meta, advanced_config, locations, hsts_enabled, hsts_subdomains | ConvertTo-Json

    Write-Host "[$(($i+1).ToString().PadLeft(3," ")) of $($CurrentConfig.Count) ] Updating config for Proxy Host #$($HostID)"
    Write-Host "`tDomain:  $($Config.domain_names[0])"

    $PutStatistics = Measure-Command -Expression {
        Invoke-WebRequest -UseBasicParsing -Uri "$($NginxPMServer)/api/nginx/proxy-hosts/$($HostID)" `
            -Method "PUT" -Headers @{
            "method"        = "PUT"
            "authorization" = "Bearer $($Bearer)"
        } -ContentType "application/json; charset=UTF-8" -Body $PutObject
    }

    Write-Host "`tCompleted in $([math]::Round($PutStatistics.TotalMilliseconds)) ms"
}
