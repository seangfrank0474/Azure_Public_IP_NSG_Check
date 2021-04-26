Login-AzAccount
# Setting up variables and array  
$all_azure_tenants = Get-AzTenant
$all_azure_tnt_subs = @()
$int = 1
$script_root_path = (Get-Item $PSScriptRoot).FullName
$azure_pub_ip_path = $script_root_path + "\azure_public_ip_dump"
$azure_pub_ip_export = $azure_pub_ip_path + "\Azure-Public-IP-Export" + $(get-date -UFormat "%Y_%m_%dT%H_%M_%S") + ".csv"
$azure_nsg_export_csv = $azure_pub_ip_path + "\Azure-NSG-Rule_Export" + $(get-date -UFormat "%Y_%m_%dT%H_%M_%S") + ".csv"
# Setting up the directory where the csv(s) will be written
if (!(Test-Path -Path $azure_pub_ip_path)){
    New-Item -ItemType directory -Path $azure_pub_ip_path | Out-Null
    $screen_output = "[+] {0} Azure Public IP Check path is now setup. Path: {1}" -f $(get-date -UFormat "%Y-%m-%dT%H:%M:%S"),$azure_pub_ip_path
    Write-Output $screen_output
    }
else{
    $screen_output = "[+] {0} Azure Public IP Check path has been previously setup and is ready for the acquisition process. Path: {1}" -f $(get-date -UFormat "%Y-%m-%dT%H:%M:%S"),$azure_pub_ip_path
    Write-Output $screen_output
    }
# Loops that will iterate over all tenants/subs to populate the public IPs and NSG configs and export that information to the their respective csv files
Foreach ($azure_tenant in $all_azure_tenants){
    $all_azure_tnt_subs += Get-AzSubscription -TenantId $azure_tenant.id | Where-Object {$_.state -eq 'Enabled'}
}
Foreach ($azure_tnt_sub in $all_azure_tnt_subs){
    $percent = $null
    $percent = ($int * 100)/$all_azure_tnt_subs.Count
    $percent = "{0:N0}" -f $percent
    Select-AzSubscription -SubscriptionId $azure_tnt_sub.id | Out-Null
    $tnt_sub_azure_pub_ips = Get-AzPublicIpAddress
    $screen_output = "[+] {0} Checking Azure Subscription: {1}" -f $(get-date -UFormat "%Y-%m-%dT%H:%M:%S"),$azure_tnt_sub.name
    Write-Output $screen_output
    $azure_pub_ips_cnt = ($tnt_sub_azure_pub_ips | measure).Count
    if ($azure_pub_ips_cnt -ge 1){
        $screen_output = "[+] {0} Found count of all public ip in the Azure Tenant Environment: {1}" -f $(get-date -UFormat "%Y-%m-%dT%H:%M:%S"),$azure_pub_ips_cnt
        Write-Output $screen_output
        $tnt_sub_azure_pub_ips | select Name,ResourceGroupName,Location,PublicIPAllocationMethod,IpAddress,PublicIpAddressVersion,@{N='SubName';E={$azure_tnt_sub.name}},@{N='SubIde';E={$azure_tnt_sub.id}} | Export-Csv $azure_pub_ip_export -NoTypeInformation -Encoding ASCII -Append
        Set-AzContext -Subscription $azure_tnt_sub.Name | Out-Null
        $azure_nsg_lists = Get-AzNetworkSecurityGroup
        foreach ($azure_nsg_list in $azure_nsg_lists){
            if ($azure_nsg_list | Get-AzNetworkSecurityRuleConfig){
                foreach ($n in $azure_nsg_list) {
                    $azure_nsg_rules = $n.SecurityRules
                    foreach ($azure_nsg_rule in $azure_nsg_rules) {
                        $azure_nsg_rule | Select-Object Name,Description,Priority,
                            @{n="SubscriptionID";e={$azure_tnt_sub.Name}},
                            @{n="SourceAddressPrefix";e={$_.SourceAddressPrefix -join ","}},
                            @{n="SourcePortRange";e={$_.SourcePortRange -join ","}},
                            @{n="DestinationAddressPrefix";e={$_.DestinationAddressPrefix -join ","}},
                            @{n="DestinationPortRange";e={$_.DestinationPortRange -join ","}},
                            Protocol,Access,Direction | Export-Csv $azure_nsg_export_csv -NoTypeInformation -Encoding ASCII -Append
                    }
                }
            }
        }
    }
    write-progress "Getting Azure RM Public IP addresses " "$percent% Complete:" -perc $percent
    $int++
}
$screen_output = "[+] {0} All Azure Public IP addresses and NSG information in the Azure Tenant Environment(s) has been exported. Azure Tenent Public IPs: {1} Azure Tenent NSG Configs: {2}" -f $(get-date -UFormat "%Y-%m-%dT%H:%M:%S"),$azure_pub_ip_export,$azure_nsg_export_csv
Write-Output $screen_output