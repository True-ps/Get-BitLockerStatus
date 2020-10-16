#$encryptPassword = $args[0] # this will set the password for all encrypted drives.

$logFileExists = [System.Diagnostics.EventLog]::SourceExists("Nav-BitLocker");
#if the log source exists, it uses it. if it doesn't, it creates it.
if ($logFileExists -eq $false)
{ New-EventLog -LogName Application -Source "Nav-BitLocker"; }
#writes events to the windows event log
$getDrives = Get-WmiObject win32_logicaldisk | Where-Object { $_.DriveType -eq 3 } | Select-Object DeviceID
$eventlogvalues = @{
    LogName = 'Application'
    Source  = 'Nav-BitLocker'
}


foreach ($drive in $getDrives) {
    $getEncryption = Get-BitLockerVolume -MountPoint $drive.DeviceID 
    $encryptionState = @{
        encryptedAndLocked   = ($getEncryption.VolumeStatus -eq $null) -and ($getEncryption.ProtectionStatus -eq "Unknown") -and ($getEncryption.EncryptionPercentage -eq $null)
        encryptionInProgress = ($getEncryption.ProtectionStatus -eq "OFF") -and ($getEncryption.VolumeStatus -ne "FullyDecrypted" -and $getEncryption.EncryptionPercentage -lt 100)
        nonEncrypted         = ($getEncryption.VolumeStatus -eq "FullyDecrypted") -and ($getEncryption.EncryptionPercentage -eq 0)
        encryptedAndUnlocked = ($getEncryption.ProtectionStatus -eq "ON") -and ($getEncryption.EncryptionPercentage -eq 100)
    }
    
    if ($encryptionState.encryptionInProgress) {
        write-Output "Bitlocker protection status is $($getEncryption.ProtectionStatus) on $($drive.DeviceID) Drive but drive is not fully encrypted.`nVolume Status is $($getEncryption.VolumeStatus). `nEncrypted at $($getEncryption.EncryptionPercentage)%"
        $lockInProgressEntry = @{
            EntryType = "Warning"
            EventID   = 817
            Message   = "Bitlocker protection status is $($getEncryption.ProtectionStatus) on $($drive.DeviceID) Drive but drive is not fully encrypted.`nVolume Status is $($getEncryption.VolumeStatus). `nEncrypted at $($getEncryption.EncryptionPercentage)%"
        }
        Write-EventLog @eventlogvalues @lockInProgressEntry
    }
    elseif ($encryptionState.encryptedAndUnlocked) {
        write-output "Bitlocker protection status is $($getEncryption.ProtectionStatus) on $($drive.DeviceID) Drive. Encrypted at $($getEncryption.EncryptionPercentage)%"
        $lockedAndLoadedEntry = @{
            EntryType = "Information"
            EventID   = 816
            Message   = "Bitlocker protection status is $($getEncryption.ProtectionStatus) on $($drive.DeviceID) Drive. Encrypted at $($getEncryption.EncryptionPercentage)%"
        }
        Write-EventLog @eventlogvalues @lockedAndLoadedEntry
    }
    
    elseif ($encryptionState.nonEncrypted) {
        write-output "BitLocker protection status is $($getEncryption.ProtectionStatus) on $($drive.DeviceId) Drive.`nVolume Status is $($getEncryption.VolumeStatus)!`n"
        $nonEncryptedEntry = @{
            EntryType = "Error"
            EventID   = 818
            Message   = "BitLocker protection status is $($getEncryption.ProtectionStatus) on $($drive.DeviceId) Drive.`nVolume Status is $($getEncryption.VolumeStatus)!`n"
        }
        Write-EventLog @eventlogvalues @nonEncryptedEntry
    }
    elseif ($encryptionState.encryptedAndLocked) {
        Write-Output "Bitlocker protection status is ON for drive $($drive.DeviceID). The drive is locked and prottected by $($getEncryption.KeyProtector)"
        $lockedAndUnloadedEntry = @{
            EntryType = "Information"
            EventID   = 815
            Message   = "Bitlocker protection status is ON for drive $($drive.DeviceID). The drive is locked and prottected by $($getEncryption.KeyProtector)"
        }
        Write-EventLog @eventlogvalues @lockedAndUnloadedEntry
    }
 

    #uncomment the following lines to encrypt volumes and check for encryption  % - takes $encryptPassword as parameter
    
    <# <-delete this to uncomment 
    #!!!ALL DRIVES WILL BE ENCRYPTED!!!
    while ($getEncryption.EncryptionPercentage -ne 100) {
        Write-Output "$($getencryption.MountPoint) drive encryption at $($getLocker.EncryptionPercentage)%"
        Start-Sleep -Seconds 30
    }

    $SecureString = ConvertTo-SecureString $encryptpassword -AsPlainText -Force
    Enable-BitLocker -MountPoint $drive.DeviceID -EncryptionMethod Aes256  -Password $SecureString -PasswordProtector
    
    #>
}


