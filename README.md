# b2c-pipeline-demo
Deploying Azure AD B2C Custom Policies with Azure DevOps

There is a companion [blog post](http://www.redbaronofazure.com/?p=7702) to this github repo that explains more about the process of deploying Azure AD B2C Custom Policies to a B2C tenant. This README file will focus more on helping you set it up in your Azure DevOps environment.

## Azure DevOps
To try this sample, you create a new Azure DevOps project and import all files in this repo.

### Build Pipeline
For the build pipeline, you have the YAML file [azure-pipelines.yml](azure-pipelines.yml) that contains all configuration, so you just have to go to Pipelines, select New Pipeline, pick your Azure github repo, then select `Existing Azure Pipelines YAML file` and select `/azure-pipelines.yml`.

You are not done yet. You need to Edit the pipeline, select Variables and add the following:

- B2CTenantName = yourtenant.onmicrosoft.com
- B2CPolicyPrefic = ABC, or whatever prefix you prefer to have in your policies. It is ok to have a blank one, but beware not to overwrite any existing files
- IdentityExperienceFrameworkAppName = IdentityExperienceFramework, unless you named this app something different
- ProxyIdentityExperienceFrameworkAppName = ProxyIdentityExperienceFramework, unless you named this app something different
- B2CExtensionAttributeAppName = b2c-extensions-app. The file [TrustFrameworkExtensions.xml](./policies/TrustFrameworkExtensions.xml) sets the extension attributes app to use, and the default is to use b2c-extensions-app
- AppInsightInstrumentationKey = the guid of your AppInsight instance. If you don't have one, create one, because it will save time troubleshooting a B2C Custom Policy
- ClientCredAppID = the AppID (client_id) of the client credentials app Azure DevOps will use (see below)
- ClientCredAppKey = the AppKey (client_seecret) of the client credentials app Azure DevOps will use (see below). When creating this value, please check `[x] Keep this value secret`

### Release Pipeline
You can't simply import a YAML file for the Azure DevOps release pipeline, regrettably, but here'se how you configure it:

- Goto Repos > Release and create a new release.
- Select a Windows agent and configure `Artifact download`to pickup your latest build
- Add a `Powershell Script` task and set the Working Directory (under Advanced) to sumething like `$(System.DefaultWorkingDirectory)/something`
- Select inline script and add the below

```powershell
.\drop\scripts\deploy-to-b2c.ps1 -TenantName $env:B2CTENANTNAME -AppId $env:CLIENTCREDAPPID -AppKey $env:CLIENTCREDAPPKEY -PolicyPath .\drop\policies
```

- Switch tab to variables and add three variables `B2CTenantName`, `ClientCredAppId` and `ClientCredAppKey` with the same values as you entered for the build pileline. 

### Client Credentials

You need to register an application in your target B2C tenant.

- Goto App registrations, select `+New registration` 
- Select `Accounts in this organization only` radio button
- Enter `Web` and `http://localhost` in the Redirect URI section
- Hit Register
- Goto API Permissions, select `+Add a permission`, Select `Microsoft graph` and `Application permission`
- Check `Application > Application.Read.All` and `Policy > Policy.ReadWrite.TrustFramework` and hit Add permission
- Make sure you hit `Grant admin consent for...` and approve the permissions
- Goto Certicitate & secrets and create a secret for the app

## Testing

If you're not an Azure DevOps guru and want to configure continous integration by yourself, you can trigger a deployment by doing the following

- Goto Repos > Pipelines, select your build pipeline and select `Run pipeline`. This will do the search & replace of your files and produce a build artifact output
- Goto Repos > Releases, select your release pipeline and select `Create release`. You then need to press `Deploy` and possibly also do the `Approve` step (depends on your config).