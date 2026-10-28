# WAU Administration Template

In an enterprise environment, it's crucial that different groups can have different settings in applications or implement other mandatory settings for security/management reasons. **WAU** doesn't have any settings that can be changed except during installation (or by editing the registry/the `Winget-AutoUpdate` task as **Admin**). However, with the use of **ADML/ADMX** files, you can manage every **WAU** setting from within **GPO** or **Intune policies**.

![image](https://user-images.githubusercontent.com/102996177/213920242-7ff8e2b4-d926-4407-b860-1e5922e29c3e.png)

## Group Policy (GPO)

### Deploy WAU without installing ADMX/ADML files

The ADMX/ADML files are only needed to display WAU settings in the Group Policy
editor. You can deploy WAU and configure its supported policies without adding
template files to the domain.

#### Install the MSI

1. Copy `WAU.msi` to a stable network share accessible to computer accounts,
   for example `\\<domain>\SYSVOL\<domain>\scripts\WAU\WAU.msi`. Grant the
   computers being targeted read access to the share and its files.
2. In Group Policy Management, create or edit a GPO linked to the OU containing
   the target **computer** accounts.
3. Go to **Computer Configuration > Policies > Software Settings > Software
   installation**, choose **New > Package**, select the MSI using its UNC path,
   and assign it.
4. Restart a target computer to install WAU.

This installs WAU with its default MSI settings. To set MSI properties such as
`USERCONTEXT` during installation, use a computer startup script that runs
`msiexec.exe /i "\\<server>\<share>\WAU.msi" /qn /norestart PROPERTY=value`
instead. Ensure the script handles already-installed versions before running
the installer again.

#### Configure WAU with Registry Preferences

To apply WAU settings without the administrative template, open the GPO's
**Computer Configuration > Preferences > Windows Settings > Registry** and
create registry items under:

`HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Romanitho\Winget-AutoUpdate`

Use the value names and data types shown in the WAU ADMX file. For example:

| Value name | Type | Example data |
|---|---|---|
| `WAU_UpdatesInterval` | `REG_SZ` | `Weekly` |
| `WAU_UpdatesAtTime` | `REG_SZ` | `06:00:00` |
| `WAU_UpdatesAtLogon` | `REG_DWORD` | `1` |
| `WAU_NotificationLevel` | `REG_SZ` | `Full` (`SuccessOnly`, `ErrorsOnly`, or `None` are also supported) |
| `WAU_UseWhiteList` | `REG_DWORD` | `1` |

For an application allowlist, add string values under
`...\Winget-AutoUpdate\WhiteList`; each value's data is a WinGet package ID.
For a blocklist, use `...\Winget-AutoUpdate\BlackList`. For example, create a
`REG_SZ` value named `App1` with data `Microsoft.VisualStudioCode`.

WAU reads these registry policies when running. The `Winget-AutoUpdate-Policies`
scheduled task applies schedule changes daily at 6:00 AM. GPO management is
enabled automatically when policies are present; the old
`WAU_ActivateGPOManagement` value is deprecated.

## Administrative Template

### To an Individual Computer
1. Copy the **`WAU.admx`** file to your Policy Definitions template folder.
   >Example: `C:\Windows\PolicyDefinitions`
2. Copy the **`WAU.adml`** file to the matching language folder in your Policy Definitions folder.
   >Example: `C:\Windows\PolicyDefinitions\en-US`

### To Active Directory
1. On a domain controller or workstation with [RSAT](https://learn.microsoft.com/en-us/troubleshoot/windows-server/system-management-components/remote-server-administration-tools), go to the **PolicyDefinitions** folder (also known as the _Central Store_) on any domain controller for your domain.
2. Copy the **`WAU.admx`** file to the PolicyDefinitions folder.
   >Example: `%systemroot%\sysvol\domain\policies\PolicyDefinitions`
3. Copy the **`WAU.adml`** file to the matching language folder in the PolicyDefinitions folder. Create the folder if it doesn't already exist.
   >Example: `%systemroot%\sysvol\domain\policies\PolicyDefinitions\en-US`
4. If your domain has more than one domain controller, the new [ADMX files](https://learn.microsoft.com/en-us/troubleshoot/windows-client/group-policy/create-and-manage-central-store) will be replicated to them at the next domain replication interval.

## Intune

Please follow the comprehensive Microsoft documentation to import and manage the WAU policies:
[Import and Manage Administrative Templates in Intune](https://learn.microsoft.com/en-us/mem/intune-service/configuration/administrative-templates-import-custom#add-the-admx-and-adml-files)

## Important Notes

- This project only supports the `en-US` ADML file.
