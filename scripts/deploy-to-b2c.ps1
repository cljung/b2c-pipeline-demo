param (
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",                                          # path to XML policies (current folder is default)
    [Parameter(Mandatory=$true)][Alias('t')][string]$TenantName = "",                                           # yourtenant.onmicrosoft.com
    [Parameter(Mandatory=$true)][Alias('a')][string]$AppID = "",                                                # client creds to use
    [Parameter(Mandatory=$true)][Alias('k')][string]$AppKey = ""                                                # -"-
)

# get current path as default
if ( "" -eq $PolicyPath ) {
    $PolicyPath = (get-location).Path
}

## get an access_token from B2C via client credentials
function GetAccessToken( $scopes ) {
    $oauthBody  = @{grant_type="client_credentials";resource="https://graph.microsoft.com/";client_id=$AppID;client_secret=$AppKey;scope=$scopes}
    return Invoke-RestMethod -Method Post -Uri "https://login.microsoft.com/$tenantName/oauth2/token?api-version=1.0" -Body $oauthBody
}

# invoke the Graph REST API to upload the Policy
Function UploadPolicy( [string]$PolicyId, [string]$PolicyData) {
    # https://docs.microsoft.com/en-us/graph/api/trustframework-put-trustframeworkpolicy?view=graph-rest-beta
    write-host "Uploading policy $PolicyId..."
    $url = "https://graph.microsoft.com/beta/trustFramework/policies/$PolicyId/`$value"
    $resp = Invoke-RestMethod -Method PUT -Uri $url -ContentType "application/xml" -Headers @{'Authorization'="$($oauthRWTF.token_type) $($oauthRWTF.access_token)"} -Body $PolicyData
    write-host $resp.TrustFrameworkPolicy.PublicPolicyUri
}

# process each Policy object in the array. For each that has a BasePolicyId, follow that dependency link
# first call has to be with BasePolicyId null (base/root policy) for this to work
Function ProcessPolicies( $arrP, $BasePolicyId ) {
    foreach( $p in $arrP ) {
        if ( $p.xml.TrustFrameworkPolicy.TenantId -ne $TenantName ) {
            write-output "$($p.PolicyId) has wrong tenant configured $($p.xml.TrustFrameworkPolicy.TenantId) - skipped"
        } else {
            if ( $BasePolicyId -eq $p.BasePolicyId -and $p.Uploaded -eq $false ) {                
                UploadPolicy $p.PolicyId $p.PolicyData  # upload this one
                $p.Uploaded = $true                
                ProcessPolicies $arrP $p.PolicyId       # process all policies that has a ref to this one
            }
        }
    }
}

# enumerate all XML files in the specified folders and create a array of objects with info we need
$files = get-childitem -path $policypath -name -include *.xml | Where-Object {! $_.PSIsContainer }
$arr = @()
foreach( $file in $files ) {
    $PolicyFile = (Join-Path -Path $PolicyPath -ChildPath $file)
    write-host "Reading file $PolicyFile..."
    $PolicyData = Get-Content $PolicyFile
    [xml]$xml = $PolicyData
    if ($null -ne $xml.TrustFrameworkPolicy) {
        $policy = New-Object System.Object
        $policy | Add-Member -type NoteProperty -name "PolicyId" -Value $xml.TrustFrameworkPolicy.PolicyId
        $policy | Add-Member -type NoteProperty -name "BasePolicyId" -Value $xml.TrustFrameworkPolicy.BasePolicy.PolicyId
        $policy | Add-Member -type NoteProperty -name "Uploaded" -Value $false
        $policy | Add-Member -type NoteProperty -name "FilePath" -Value $PolicyFile
        $policy | Add-Member -type NoteProperty -name "xml" -Value $xml
        $policy | Add-Member -type NoteProperty -name "PolicyData" -Value $PolicyData
        $policy | Add-Member -type NoteProperty -name "HasChildren" -Value $null
        $arr += $policy
    }
}

# find out who is/are the root in inheritance chain so we know which to upload first
foreach( $p in $arr ) {
    $p.HasChildren = ( $null -ne ($arr | where {$_.PolicyId -eq $p.BasePolicyId}) ) 
}

# upload policies - start with those who are root(s)
$oauthRWTF = GetAccessToken "Policy.ReadWrite.TrustFramework"
foreach( $p in $arr ) {
    if ( $p.HasChildren -eq $False ) {
        ProcessPolicies $arr $p.BasePolicyId
    }
}
