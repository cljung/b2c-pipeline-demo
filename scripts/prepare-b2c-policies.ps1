param (
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",                                          # path to XML policies (current folder is default)
    [Parameter(Mandatory=$false)][Alias('x')][string]$PolicyPrefix = "",                                        # B2C_1A_... --> B2C_1A_ABC_...
    [Parameter(Mandatory=$true)][Alias('t')][string]$TenantName = "",                                           # yourtenant.onmicrosoft.com
    [Parameter(Mandatory=$true)][Alias('a')][string]$AppID = "",                                                # client creds to use
    [Parameter(Mandatory=$true)][Alias('k')][string]$AppKey = "",                                               # -"-
    [Parameter(Mandatory=$false)][string]$ProxyIdentityExperienceFrameworkAppName = "ProxyIdentityExperienceFramework",
    [Parameter(Mandatory=$false)][string]$IdentityExperienceFrameworkAppName = "IdentityExperienceFramework",
    [Parameter(Mandatory=$false)][string]$B2CExtensionAttributeAppName = "b2c-extensions-app",                  # app for extension attributes
    [Parameter(Mandatory=$false)][hashtable]$ConfigKeyValues = @{"{config:Facebook:client_Id}"="12345678"}      # additional key/value pairs to replace in the policies
)

# get current path as default
if ( "" -eq $PolicyPath ) {
    $PolicyPath = (get-location).Path
}

# convert B2C_1A_signup_signin --> B2C_1A_ABC_signup_signin
if ( $PolicyPrefix.Length -gt 0 -and !$PolicyPrefix.EndsWith("_") ) {
    $PolicyPrefix += "_" 
}

## get an access_token from B2C via client credentials
function GetAccessToken( $scopes ) {
    $oauthBody  = @{grant_type="client_credentials";resource="https://graph.microsoft.com/";client_id=$AppID;client_secret=$AppKey;scope=$scopes}
    return Invoke-RestMethod -Method Post -Uri "https://login.microsoft.com/$tenantName/oauth2/token?api-version=1.0" -Body $oauthBody
}

# get AppID / ObjectID from an B2C registered app
function GetAppInfo( $appName ) {
    $url = "https://graph.microsoft.com/v1.0/applications?`$filter=startswith(displayName,'$appName')&`$select=id,appId,displayName"
    return Invoke-RestMethod -Method GET -Uri $url -ContentType "application/json" -Headers @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"} 
}

# Get AppIDs for IdentityExperienceFramework, ProxyIdentityExperienceFramework and the b2c-extensions-app
$oauth = GetAccessToken "Application.Read.All"
$ProxyIdentityExperienceFrameworkAppId = (GetAppInfo $ProxyIdentityExperienceFrameworkAppName).value.appId
$IdentityExperienceFrameworkAppId = (GetAppInfo $IdentityExperienceFrameworkAppName).value.appId
$resp = GetAppInfo $B2CExtensionAttributeAppName
$extensionsObjectId = $resp.value.id
$extensionsAppId = $resp.value.appId

# create a dictionary of key/value pairs with things that should be replaced in the policies for the target tenant
# the 'keys' are expected to be found in the generic B2C XML policy files
$dict = New-Object 'system.collections.generic.dictionary[string,string]'
$dict["{config:PolicyPrefix}"] = $PolicyPrefix
$dict["{config:yourtenant.onmicrosoft.com}"] = $TenantName
$dict["{config:ProxyIdentityExperienceFrameworkAppId}"] = $ProxyIdentityExperienceFrameworkAppId
$dict["{config:IdentityExperienceFrameworkAppId}"] = $IdentityExperienceFrameworkAppId
$dict["{config:b2c-extension-app:AppId}"] = $extensionsAppId
$dict["{config:b2c-extension-app:objectId}"] = $extensionsObjectId
foreach($key in $ConfigKeyValues.Keys ) {
    $dict[$key] = $ConfigKeyValues[$key]
}

# enumerate all XML files in the specified folders and replace key/value pairs to match a target env
$files = get-childitem -path $policypath -name -include *.xml | Where-Object {! $_.PSIsContainer }
foreach( $file in $files ) {
    $PolicyFile = (Join-Path -Path $PolicyPath -ChildPath $file)
    write-host "Preparing file $PolicyFile..."
    $PolicyData = Get-Content $PolicyFile
    # replace keywords
    foreach( $key in $dict.Keys) { 
        $PolicyData = $PolicyData.Replace( $key, $dict[$key] )
    }
    Set-Content -Path $PolicyFile -Value $PolicyData 
}
