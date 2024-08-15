# Путь к файлу для проверки
$filePath = "C:\Scripts\GPO_LOGON_DENY_DISABLE"
# Имя задачи в планировщике
$taskName = "Обновление членства GPO_LOGON_DENY"

# Параметры отправки почты
$smtpServer = "example.com"
$from = "alert@example.com"
$to = "it@example.com"
$subject = "GPO_LOGON_DENY"
$body = ""
$secpasswd = ConvertTo-SecureString "!!password!!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("example\alert", $secpasswd)

if (Test-Path $filePath) {
    $fileCreationTime = (Get-Item $filePath).CreationTime
    $currentTime = Get-Date
    $timeDifference = $currentTime - $fileCreationTime

    # Если файл старше 48 часов, удаляем его
    if ($timeDifference.TotalHours -gt 48) {
        Remove-Item $filePath
    }
}

# Получаем информацию о задаче
$task = Get-ScheduledTask -TaskName $taskName
$taskInfo = $task | Get-ScheduledTaskInfo

$taskState = $task.State
$lastRunTime = $taskInfo.LastRunTime
$timeSinceLastRun = (Get-Date) - $lastRunTime


# Проверяем условия и действуем соответственно
if ($taskState -eq "Disabled" -and -not (Test-Path $filePath)) {
    New-Item -Path $filePath -ItemType "file"
    # Здесь добавьте код для отправки уведомления в Telegram
    $body = "Задача GPO_LOGON_DENY на MSKDC во время выполнения проверки находилась в состоянии 'Отключена'.`r`nЭто может означать, что администратор проводил технические работы."
    Send-MailMessage -From $from -To $to -Subject $subject -Body $body -SmtpServer $smtpServer -Encoding 'UTF8' -Priority High -Port 587 -Credential $cred -UseSsl
    }

if ($timeSinceLastRun.TotalHours -gt 48) {
    Enable-ScheduledTask -TaskName $taskName
    $body = "Задача GPO_LOGON_DENY была включена автоматически т.к. прошло более 48 часов с момента её отключения." -join "`r`n"
    Send-MailMessage -From $from -To $to -Subject $subject -Body $body -SmtpServer $smtpServer -Encoding 'UTF8' -Priority High -Port 587 -Credential $cred -UseSsl
    }
