function Rollback-ChromeOnVNet {
    param (
        [string]$resourceGroupName,  # The resource group containing the VMs
        [string]$vnetName,  # The name of the VNet where VMs are located
        [string]$domainAdminUser,  # Domain admin username
        [string]$domainAdminPassword,  # Domain admin password in plain text
        [string]$previousChromeVersionUrl  # URL to download the previous Chrome version
    )

    # Convert the plain text password to a secure string
    $securePassword = ConvertTo-SecureString $domainAdminPassword -AsPlainText -Force

    # Create a credential object using the domain admin username and secure password
    $cred = New-Object System.Management.Automation.PSCredential ($domainAdminUser, $securePassword)

    # Get all VMs in the specified VNet by filtering the VMs in the resource group
    $vms = Get-AzVM -ResourceGroupName $resourceGroupName | Where-Object {
        $nic = Get-AzNetworkInterface -ResourceId $_.NetworkProfile.NetworkInterfaces[0].Id  # Get the network interface of the VM
        $ipconfig = $nic.IpConfigurations[0]  # Get the IP configuration of the network interface
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnetName  # Get the VNet object
        $ipconfig.Subnet.Id -like $vnet.Subnets.Id  # Check if the subnet of the VM matches the VNet
    }

    # Loop through each VM found in the VNet
    foreach ($vm in $vms) {
        $vmName = $vm.Name  # Get the VM name
        $publicIp = (Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName | Where-Object { $_.Id -like $vm.NetworkProfile.NetworkInterfaces[0].Id }).IpAddress  # Get the public IP address of the VM

        # Connect to the VM using domain admin credentials
        $session = New-PSSession -ComputerName $publicIp -Credential $cred

        # Script block to rollback or install a previous version of Google Chrome
        $scriptBlock = {
            param ($previousChromeVersionUrl)  # Accepts the URL for the previous Chrome version as a parameter

            # Path to the current Chrome installation
            $chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
            
            # Get the current version of Chrome if installed
            if (Test-Path $chromePath) {
                $chromeVersion = (Get-ItemProperty $chromePath).VersionInfo.FileVersion  # Get the version information of Chrome
            } else {
                $chromeVersion = $null  # Set to null if Chrome is not installed
            }

            # Check for available versions of Chrome in the installation directory
            $chromeVersions = Get-ChildItem "C:\Program Files\Google\Chrome\Application\" -Directory | Select-Object Name

            # If previous versions exist, perform a rollback
            if ($chromeVersions.Count -gt 1) {
                $previousVersion = $chromeVersions[$chromeVersions.Count - 2].Name  # Get the second-to-last version
                Rename-Item "C:\Program Files\Google\Chrome\Application\$chromeVersion" "C:\Program Files\Google\Chrome\Application\$chromeVersion.old"  # Rename the current version folder
                Rename-Item "C:\Program Files\Google\Chrome\Application\$previousVersion" "C:\Program Files\Google\Chrome\Application\$chromeVersion"  # Rename the previous version folder to current
                Write-Output "Chrome has been rolled back to version $previousVersion on $env:COMPUTERNAME"  # Output success message
            } else {
                # If no previous versions are available, download and install the previous version
                Write-Output "No previous versions available. Downloading and installing a previous version of Chrome."
                
                # Define the path to save the Chrome installer
                $installerPath = "C:\Temp\chrome_installer.exe"
                Invoke-WebRequest -Uri $previousChromeVersionUrl -OutFile $installerPath  # Download the installer

                # Install the downloaded version of Chrome
                Start-Process -FilePath $installerPath -ArgumentList "/silent /install" -Wait  # Run the installer silently and wait for it to finish

                # Verify if the installation was successful
                if (Test-Path $chromePath) {
                    $installedVersion = (Get-ItemProperty $chromePath).VersionInfo.FileVersion  # Get the newly installed version
                    Write-Output "Chrome version $installedVersion has been installed on $env:COMPUTERNAME"  # Output success message
                } else {
                    Write-Output "Failed to install Chrome on $env:COMPUTERNAME"  # Output failure message
                }

                # Clean up by removing the installer file
                Remove-Item $installerPath
            }
        }

        # Execute the script block on the remote VM, passing the URL for the previous Chrome version as an argument
        Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $previousChromeVersionUrl

        # Remove the session after the script execution
        Remove-PSSession -Session $session
    }

    # Output a message indicating that the script has executed on all VMs
    Write-Output "Chrome rollback and installation script executed on all VMs in the VNet."
}

# Example usage of the function
Rollback-ChromeOnVNet -resourceGroupName "yourResourceGroupName" `  # Call the function with the specified resource group name
                      -vnetName "yourVNetName" `  # Specify the VNet name
                      -domainAdminUser "yourDomainAdminUsername" `  # Provide the domain admin username
                      -domainAdminPassword "yourDomainAdminPassword" `  # Provide the domain admin password in plain text
                      -previousChromeVersionUrl "https://dl.google.com/release2/q/canary/112.0.5615.49/112.0.5615.49_chrome_installer.exe"  # Provide the URL to download the previous Chrome version
