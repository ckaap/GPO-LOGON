$log = @() # Инициализация массива для логов

# Параметры отправки почты
$smtpServer = "example.com"
$from = "alert@example.com"
$to = "it@example.com"
$subject = "GPO_LOGON_DENY"
$body = ""
$secpasswd = ConvertTo-SecureString "!!password!!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("example\alert", $secpasswd)

# Получаем всех пользователей в группе "gpo_logon_deny"
$denyLogonUsers = Get-ADGroupMember -Identity "gpo_logon_deny"

foreach ($user in $denyLogonUsers) {
    # Проверяем, состоит ли пользователь в группе "Protected Users"
    $isProtectedUser = Get-ADPrincipalGroupMembership -Identity $user.distinguishedName |
        Where-Object { $_.Name -eq "Protected Users" }

    # Проверяем рекурсивно наличие пользователя в "Priv_Group"
    $inPrivGroup = Get-ADGroupMember -Identity "Priv_Group" -Recursive |
        Where-Object { $_.distinguishedName -eq $user.distinguishedName }

    if (-not $isProtectedUser -and -not $inPrivGroup) {
        # Если пользователя нет ни в "Protected Users", ни в "Priv_Group" рекурсивно, удаляем его из "gpo_logon_deny"
        Remove-ADGroupMember -Identity "gpo_logon_deny" -Members $user.distinguishedName -Confirm:$false
        $log += "Пользователь $($user.SamAccountName) удалён из группы 'gpo_logon_deny', т.к. не входит ни в 'Protected Users', ни в 'Priv_Group'."
    }
}

# Получаем всех членов группы "Priv_Group"
$Priv_Group = Get-ADGroupMember -Identity "Priv_Group" -Recursive

foreach ($user in $Priv_Group) {
    # Проверяем, состоит ли пользователь в группе "Protected Users"
    $groups = Get-ADPrincipalGroupMembership -Identity $user.distinguishedName
    $isProtectedUser = $groups | Where-Object { $_.Name -eq "Protected Users" }
    # Проверяем наличие пользователя в "gpo_logon_deny"
    $inDenyLogon = Get-ADGroupMember -Identity "gpo_logon_deny" | Where-Object { $_.distinguishedName -eq $user.distinguishedName }

    if ($isProtectedUser -and -not $inDenyLogon) {
        # Если пользователь в "Protected Users", но не в "gpo_logon_deny", пропускаем
    } elseif (-not $isProtectedUser -and $inDenyLogon) {
        # Если пользователя нет в "Protected Users", но есть в "gpo_logon_deny", пропускаем
    } elseif ($isProtectedUser) {
        # Если пользователь в группе "Protected Users", удаляем его из "gpo_logon_deny"
        Remove-ADGroupMember -Identity "gpo_logon_deny" -Members $user.distinguishedName -Confirm:$false
        $log += "Пользователь $($user.SamAccountName) удалён из группы 'gpo_logon_deny' т.к. входит в 'Protected Users'. `r`nВход на рабочие станции разрешён."
    } else {
        # Если пользователя нет в "Protected Users", добавляем его в "gpo_logon_deny"
        Add-ADGroupMember -Identity "gpo_logon_deny" -Members $user.distinguishedName
        $log += "Пользователь $($user.SamAccountName) добавлен в группу 'gpo_logon_deny' т.к. не входит в 'Protected Users'. `r`nВход на рабочие станции запрещён."
    }
}

$body = $log -join "`r`n" # Собираем лог в тело письма

if ([string]::IsNullOrWhiteSpace($body)) {
    Write-Host "Тело письма пустое, отправка не производится."
    # Здесь можно выйти из скрипта, если необходимо
    exit
}

Send-MailMessage -From $from -To $to -Subject $subject -Body $body -SmtpServer $smtpServer -Encoding 'UTF8' -Priority High -Port 587 -Credential $cred -UseSsl
