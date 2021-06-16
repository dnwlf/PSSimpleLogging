#Requires -Version 5
#Powershell Logging Module

function Initialize-Log()
{
  <#
  .SYNOPSIS
    Initialize log, or reinitialize if current log rollover period has expired.

  .DESCRIPTION
    Creates a new log under the path <'Directory'\'BaseName'> and sets an expiration for the log to
    rollover to a new logfile based on the 'Rollover' period specified. If 'MaxCount' is defined,
    when the logs roll over to a new script, the function cleans up the oldest log files greater
    than 'MaxCount'. If 'MaxCount' is not defined, or is set to 0, log cleanup is skipped.

  .PARAMETER Directory
    Optional. The root directory to create the logging folder and logs in.

  .PARAMETER BaseName
    Optional. This is the name of the logging folder which will be created in the 'Directory'.
    It is also used as part of the log file(s) name.

  .PARAMETER Rollover
    Optional. How often to create a new log file. Valid values are "Month", "Week", "Day", "Hour",
    and "Minute". A new log will be created at the beginning of the next timespan.
    (eg: if logging is started on 2017-08-04 and "Month" is passed in, the next log will be created
    at midnight on 2017-09-01).

  .PARAMETER MaxCount
    Optional. Maximum number of logs to keep. If 

  .OUTPUTS
    Log file to <'Directory'\'BaseName'>

  .EXAMPLE
    Initialize-Log -Directory $PSScriptRoot -BaseName "MyLog" -Rollover "Minute" -MaxCount 30
  #>

  [CmdletBinding()]
  Param(
    [string]$Directory = ([environment]::GetEnvironmentVariable("PSSimpleLogDirectory","Process")),
    [string]$BaseName = ([environment]::GetEnvironmentVariable("PSSimpleLogBaseName","Process")),
    [string]$Rollover = ([environment]::GetEnvironmentVariable("PSSimpleLogRollover","Process")),
    [string]$MaxCount = ([environment]::GetEnvironmentVariable("PSSimpleLogMaxCount","Process"))
  )

  #if($Rollover)[ValidateSet("Month","Week","Day","Hour","Minute")]

  Write-Debug ("[PSSimpleLogging] Params Directory: {0}" -f $Directory)
  Write-Debug ("[PSSimpleLogging] Params BaseName: {0}" -f $BaseName)
  Write-Debug ("[PSSimpleLogging] Params Rollover: {0}" -f $Rollover)
  Write-Debug ("[PSSimpleLogging] Params MaxCount: {0}" -f $MaxCount)

  if($Directory){[environment]::SetEnvironmentVariable("PSSimpleLogDirectory",$Directory,"Process")} else {[environment]::SetEnvironmentVariable("PSSimpleLogDirectory",$env:TEMP,"Process")}
  if($BaseName) {[environment]::SetEnvironmentVariable("PSSimpleLogBaseName",$BaseName,"Process")}   else {[environment]::SetEnvironmentVariable("PSSimpleLogBaseName","Logs","Process")}
  if($Rollover) {[environment]::SetEnvironmentVariable("PSSimpleLogRollover",$Rollover,"Process")}   else {[environment]::SetEnvironmentVariable("PSSimpleLogRollover","Day","Process")}
  if($MaxCount) {[environment]::SetEnvironmentVariable("PSSimpleLogMaxCount",$MaxCount,"Process")}   else {[environment]::SetEnvironmentVariable("PSSimpleLogMaxCount","0","Process")}

  Write-Verbose ("[PSSimpleLogging] Directory: {0}" -f $env:PSSimpleLogDirectory)
  Write-Verbose ("[PSSimpleLogging] BaseName: {0}" -f $env:PSSimpleLogBaseName)
  Write-Verbose ("[PSSimpleLogging] Rollover: {0}" -f $env:PSSimpleLogRollover)
  Write-Verbose ("[PSSimpleLogging] MaxCount: {0}" -f $env:PSSimpleLogMaxCount)

  [string]$DateFormat = "yyyyMMdd.HHmmss"

  Switch($env:PSSimpleLogRollover)
  {
    "Month"
    {
      $DateFormat = "yyyyMM"
      $env:PSSimpleLogExpires = ((Get-Date -Day 01 -Hour 00 -Minute 00 -Second 00 -Millisecond 00).AddMonths(1).ToUniversalTime().ToString('s'))
    }

    "Week"
    {
      $DateFormat = "yyyyMMdd.w{0}" -f (Get-Date -UFormat %V)

      $Week = Get-Date
      While($Week.DayOfWeek -ne "Sunday"){$Week = $Week.AddDays(1)}
      $env:PSSimpleLogExpires = ($Week).Date.ToUniversalTime().ToString('s')
    }

    "Day"
    {
      $DateFormat = "yyyyMMdd"
      $env:PSSimpleLogExpires = ((Get-Date -Hour 00 -Minute 00 -Second 00 -Millisecond 00).AddDays(1).ToUniversalTime().ToString('s'))
    }

    "Hour"
    {
      $DateFormat = "yyyyMMdd.HH"
      $env:PSSimpleLogExpires = ((Get-Date -Minute 00 -Second 00 -Millisecond 00).AddHours(1).ToUniversalTime().ToString('s'))
    }

    "Minute"
    {
      $DateFormat = "yyyyMMdd.HHmm"
      $env:PSSimpleLogExpires = ((Get-Date -Second 00 -Millisecond 00).AddMinutes(1).ToUniversalTime().ToString('s'))
    }
  }

  Write-Verbose ("[PSSimpleLogging] DateFormat: {0}" -f $DateFormat)
  Write-Verbose ("[PSSimpleLogging] LogExpires: {0}" -f $env:PSSimpleLogExpires)

  [string]$LogDir = "{0}\{1}" -f $env:PSSimpleLogDirectory, $env:PSSimpleLogBaseName
  New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
  Write-Verbose ("[PSSimpleLogging] LogDir: {0}" -f $LogDir)

  $env:PSSimpleLogLogfile = "{0}\{1}.{2}.log" -f $LogDir, $env:PSSimpleLogBaseName, (Get-Date -Format $DateFormat)
  Write-Verbose ("[PSSimpleLogging] LogFile (to be created): {0}" -f $env:PSSimpleLogLogfile)

  if($env:PSSimpleLogMaxCount -gt 0)
  {
    $LogHistory = Get-ChildItem -Path $LogDir `
     | Where-Object {($_.Extension -eq ".log") -and ($_.Name -match "^$env:PSSimpleLogBaseName\.")}
  
    Write-Verbose ("[PSSimpleLogging] Log file count: {0}" -f $LogHistory.Count)

    if ($LogHistory.Count -gt $env:PSSimpleLogMaxCount)
    {
      $RemoveLogsCount = $LogHistory.Count - $env:PSSimpleLogMaxCount

      Write-Verbose ("[PSSimpleLogging] Log files to remove: {0}" -f $RemoveLogsCount)

      Get-ChildItem -Path $LogDir `
        | Where-Object {($_.Extension -eq ".log") -and ($_.Name -match "^$env:PSSimpleLogBaseName\.")} `
        | Sort-Object CreationTime | Select-Object -First $RemoveLogsCount `
        | Remove-Item -Force
 
      Write-Verbose ("[PSSimpleLogging] Removed oldest {0} log files." -f $RemoveLogsCount)
    }
    else
    {
      Write-Verbose ("[PSSimpleLogging] No old logs to remove. {0} log(s) matched the search" -f $LogHistory.Count)
    }
  }
  else
  {
    Write-Verbose ("[PSSimpleLogging] MaxCount value of {0}. Skipping log cleanup." -f $env:PSSimpleLogMaxCount)
  }
}

function Update-LogFilePath()
{
  <#
  .SYNOPSIS
    Initialize or re-initialize log if rollover date is passed-due, or if log
    file does not exist

  .PARAMETER LogFile
    Required. Path of the log file

  .PARAMETER Expires
    Required. The date the log expires, in UTC, round trip format

  .OUTPUTS
    Returns the current UTC date

  .EXAMPLE
    Update-LogFilePath -LogFile $env:PSSimpleLogLogfile -Expires $env:PSSimpleLogExpires
  #>

  [CmdletBinding()]
  Param(
    [string]$LogFile = ([environment]::GetEnvironmentVariable("PSSimpleLogLogfile","Process")),
    [string]$Expires = ([environment]::GetEnvironmentVariable("PSSimpleLogExpires","Process"))
  )
  Write-Debug "LogFile: $LogFile"
  Write-Debug "Expires: $Expires"

  [datetime]$NowUTC = (Get-Date).ToUniversalTime()

  [bool]$Expired = $NowUTC -gt ($Expires -as [datetime])
  Write-Debug "Expired: $Expired"

  if($Expired -or (-not $LogFile))
  {
    Initialize-Log
  }
  else
  {
    if(-not (Test-Path -Path $LogFile))
    {
      Write-Debug "LogFile path does not exist."
      Initialize-Log
    }
  }

  Return $NowUTC
}

function Write-LogHost()
{
  <#
  .SYNOPSIS
    Adds a timestamp to a string and logs and displays the result.

  .DESCRIPTION
    Adds the provided string as timestamped entry in a log file and displays the timestamped string to the console.

  .PARAMETER Message
    Required. A string to add to the log file, and display to the console.

  .NOTES
    For details about where logs are saved, please see the 'Initialize-Log' help

  .EXAMPLE
    Write-LogHost "Some info to be logged."

  .EXAMPLE
    Write-LogHost "Some info to be logged." -ForegroundColor Gray
  #>

  [CmdletBinding()]
  Param(
    [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true)]
    [AllowEmptyString()]
    [string]$Message,

    [ValidateSet("Black","Blue","Cyan","DarkBlue","DarkCyan","DarkGray","DarkGreen","DarkMagenta",
                 "DarkRed","DarkYellow","Gray","Green","Magenta","Red","White","Yellow")]
    [string]$ForegroundColor
  )

  [string]$EntryTimestamp = (Update-LogFilePath -LogFile $env:PSSimpleLogLogfile -Expires $env:PSSimpleLogExpires).ToString('s')
  Write-Log -LogFile $env:PSSimpleLogLogfile -Timestamp $EntryTimestamp -Level "DEFAULT" -Message $Message

  if($ForegroundColor)
  {
    Write-Host ("[{0}] {1}" -f $EntryTimestamp,$Message) -ForegroundColor $ForegroundColor
  }
  else
  {
    Write-Host ("[{0}] {1}" -f $EntryTimestamp,$Message)
  }
}

function Write-LogDebug()
{
  <#
  .SYNOPSIS
    Adds a timestamp to a string and logs and displays the result.

  .DESCRIPTION
    Adds the provided string as timestamped entry in a log file and displays the timestamped string to the console.
    The script uses the built-in corresponding output preference variable (ex. $DebugPreference, $VerbosePreference,
    $InformationPreference, $WarningPreference, and $ErrorActionPreference) to determine if message should be logged
    and displayed.

  .PARAMETER Message
    Required. A string to add to the log file, and display to the console.

  .NOTES
    For details about where logs are saved, please see the 'Initialize-Log' help

  .EXAMPLE
    Write-LogDebug "Some info to be logged."
  #>

  [CmdletBinding()]
  Param(
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true)]
    [AllowEmptyString()]
    [string]$Message
  )

  if($DebugPreference -ne "SilentlyContinue")
  {
    [string]$EntryTimestamp = (Update-LogFilePath -LogFile $env:PSSimpleLogLogfile -Expires $env:PSSimpleLogExpires).ToString('s')
    Write-Log -LogFile $env:PSSimpleLogLogfile -Timestamp $EntryTimestamp -Level "DEBUG" -Message $Message
  }

  Write-Debug ("[{0}] {1}" -f $EntryTimestamp,$Message)
}

function Write-LogVerbose()
{
  <#
  .SYNOPSIS
    Adds a timestamp to a string and logs and displays the result.

  .DESCRIPTION
    Adds the provided string as timestamped entry in a log file and displays the timestamped string to the console.
    The script uses the built-in corresponding output preference variable (ex. $DebugPreference, $VerbosePreference,
    $InformationPreference, $WarningPreference, and $ErrorActionPreference) to determine if message should be logged
    and displayed.

  .PARAMETER Message
    Required. A string to add to the log file, and display to the console.

  .NOTES
    For details about where logs are saved, please see the 'Initialize-Log' help

  .EXAMPLE
    Write-LogVerbose "Some info to be logged."
  #>

  [CmdletBinding()]
  Param(
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true)]
    [AllowEmptyString()]
    [string]$Message
  )

  if($VerbosePreference -ne "SilentlyContinue")
  {
    [string]$EntryTimestamp = (Update-LogFilePath -LogFile $env:PSSimpleLogLogfile -Expires $env:PSSimpleLogExpires).ToString('s')
    Write-Log -LogFile $env:PSSimpleLogLogfile -Timestamp $EntryTimestamp -Level "VERBOSE" -Message $Message
  }

  Write-Verbose ("[{0}] {1}" -f $EntryTimestamp,$Message)
}

function Write-LogInformation()
{
  #Requires -Version 5

  <#
  .SYNOPSIS
    Adds a timestamp to a string and logs and displays the result.

  .DESCRIPTION
    Adds the provided string as timestamped entry in a log file and displays the timestamped string to the console.
    The script uses the built-in corresponding output preference variable (ex. $DebugPreference, $VerbosePreference,
    $InformationPreference, $WarningPreference, and $ErrorActionPreference) to determine if message should be logged
    and displayed.

  .PARAMETER Message
    Required. A string to add to the log file, and display to the console.

  .NOTES
    For details about where logs are saved, please see the 'Initialize-Log' help

  .EXAMPLE
    Write-LogInformation "Some info to be logged."
  #>

  [CmdletBinding()]
  Param(
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true)]
    [AllowEmptyString()]
    [string]$Message
  )

  if($InformationPreference -ne "SilentlyContinue")
  {
    [string]$EntryTimestamp = (Update-LogFilePath -LogFile $env:PSSimpleLogLogfile -Expires $env:PSSimpleLogExpires).ToString('s')
    Write-Log -LogFile $env:PSSimpleLogLogfile -Timestamp $EntryTimestamp -Level "INFORMATION" -Message $Message
  }

  Write-Information ("[{0}] {1}" -f $EntryTimestamp,$Message)
}

function Write-LogWarning()
{
  <#
  .SYNOPSIS
    Adds a timestamp to a string and logs and displays the result.

  .DESCRIPTION
    Adds the provided string as timestamped entry in a log file and displays the timestamped string to the console.
    The script uses the built-in corresponding output preference variable (ex. $DebugPreference, $VerbosePreference,
    $InformationPreference, $WarningPreference, and $ErrorActionPreference) to determine if message should be logged
    and displayed.

  .PARAMETER Message
    Required. A string to add to the log file, and display to the console.

  .NOTES
    For details about where logs are saved, please see the 'Initialize-Log' help

  .EXAMPLE
    Write-LogWarning "Some info to be logged."
  #>

  [CmdletBinding()]
  Param(
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true)]
    [AllowEmptyString()]
    [string]$Message
  )

  if($WarningPreference -ne "SilentlyContinue")
  {
    [string]$EntryTimestamp = (Update-LogFilePath -LogFile $env:PSSimpleLogLogfile -Expires $env:PSSimpleLogExpires).ToString('s')
    Write-Log -LogFile $env:PSSimpleLogLogfile -Timestamp $EntryTimestamp -Level "WARNING" -Message $Message
  }

  Write-Warning ("[{0}] {1}" -f $EntryTimestamp,$Message)
}

function Write-LogError()
{
  <#
  .SYNOPSIS
    Adds a timestamp to a string and logs and displays the result.

  .DESCRIPTION
    Adds the provided string as timestamped entry in a log file and displays the timestamped string to the console.
    The script uses the built-in corresponding output preference variable (ex. $DebugPreference, $VerbosePreference,
    $InformationPreference, $WarningPreference, and $ErrorActionPreference) to determine if message should be logged
    and displayed.

  .PARAMETER Message
    Required. A string to add to the log file, and display to the console.

  .NOTES
    For details about where logs are saved, please see the 'Initialize-Log' help

  .EXAMPLE
    Write-LogError "Some info to be logged."
  #>

  [CmdletBinding()]
  Param(
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true)]
    [AllowEmptyString()]
    [string]$Message
  )

  if($ErrorActionPreference -ne "SilentlyContinue")
  {
    [string]$EntryTimestamp = (Update-LogFilePath -LogFile $env:PSSimpleLogLogfile -Expires $env:PSSimpleLogExpires).ToString('s')
    Write-Log -LogFile $env:PSSimpleLogLogfile -Timestamp $EntryTimestamp -Level "ERROR" -Message $Message
  }

  Write-Error ("[{0}] {1}" -f $EntryTimestamp,$Message)
}

function Write-LogException()
{
  <#
  .SYNOPSIS
    Logs a caught exception.

  .DESCRIPTION
    Logs a caught exception.

  .PARAMETER Exception
    Required. The exception which needs to have information logged

  .EXAMPLE
    Try
    {
      Throw "Generic Exception"
    }
    Catch
    {
      Write-LogException $_
    }
  #>

  [CmdletBinding()]
  Param(
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true)]
    $Exception
  )

  Write-LogDebug ("Entering function {0}" -f $MyInvocation.MyCommand)

  Write-LogWarning ("[EXCEPTION] FullyQualifiedErrorId            : {0}" -f $_.FullyQualifiedErrorId)
  Write-LogWarning ("[EXCEPTION] InvocationInfo.MyCommand.Name    : {0}" -f $_.InvocationInfo.MyCommand.Name)
  Write-LogWarning ("[EXCEPTION] CategoryInfo                     : {0}" -f $_.CategoryInfo.ToString())
  Write-LogWarning ("[EXCEPTION] Exception.InnerException.Message : {0}" -f $_.Exception.InnerException.Message)
  Write-LogWarning ("[EXCEPTION] ErrorDetails.Message             : {0}" -f $_.ErrorDetails.Message)
  Write-LogWarning ("[EXCEPTION] InvocationInfo.ScriptName        : {0}" -f $_.InvocationInfo.ScriptName)
  Write-LogWarning ("[EXCEPTION] InvocationInfo.ScriptLineNumber  : {0}" -f $_.InvocationInfo.ScriptLineNumber)
  Write-LogWarning ("[EXCEPTION] InvocationInfo.OffsetInLine      : {0}" -f $_.InvocationInfo.OffsetInLine)
  Write-LogWarning ("[EXCEPTION] InvocationInfo.Line              : {0}" -f $_.InvocationInfo.Line)

  Write-LogDebug ("Exiting function {0}" -f $MyInvocation.MyCommand)
}

function Write-Log()
{
  <#
  .SYNOPSIS
    Formats and adds a string to a log file.

  .DESCRIPTION
    Formats and adds a string to a log file.

  .PARAMETER LogFile
    Required. Path to the file which will be appended.

  .PARAMETER Timestamp
    Required. The timestamp to append to the log.

  .PARAMETER Level
    Required. Level of the message to append to the log, eg: DEBUG, VERBOSE, INFORMATION,WARNING, ERROR, etc.

  .PARAMETER Message
    Required. A string to add to the log file.

  .NOTES
    For details about where logs are saved, please see the 'Initialize-Log' help

  .EXAMPLE
    Write-Log -LogFile "C:\file.log" -Timestamp "2017-08-04T10:44:53" -Level "INFORMATION" -Message "Adding a log entry."
  #>
  [CmdletBinding()]
  Param (
    [string]$LogFile = $env:PSSimpleLogLogfile,
    [string]$Timestamp = (Get-Date -Format s),
    [string]$Level = "DEFAULT",
    [string]$Message = ""
  )

  $mutex = New-Object System.Threading.Mutex($false, 'PSSimpleLogging')
  [void]$mutex.WaitOne()

  Try
  {
    ("[{0}] [{1}] {2}" -f $Timestamp,$Level,$Message) | Out-File $LogFile -Append
  }
  Catch
  {
    Write-Warning $_
  }
  Finally
  {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
  }
}

Export-ModuleMember -Function Initialize-Log,Write-LogHost,Write-LogDebug,Write-LogVerbose,Write-LogInformation,Write-LogWarning,Write-LogError,Write-LogException
