#Change these to "SilentlyContinue" to mute the console and log output for that type
$DebugPreference = "Continue"
$VerbosePreference = "Continue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"
$ErrorActionPreference = "Continue"

Import-Module -Name PSSimpleLogging.psd1 -Force

Initialize-Log -Directory $PSScriptRoot -BaseName MyLog -Rollover Minute -MaxCount 0

$Message = "Message to log."

while($true)
{
  $Color = (Get-Random -InputObject "Black","Blue","Cyan","DarkBlue","DarkCyan","DarkGray","DarkGreen","DarkMagenta",
                                     "DarkRed","DarkYellow","Gray","Green","Magenta","Red","White","Yellow")
  Write-LogHost $Message -ForegroundColor $Color
  Write-LogDebug $Message
  Write-LogVerbose $Message
  Write-LogInformation $Message
  #Write-LogWarning $Message
  #Write-LogError $Message
  #Try { Throw "Here's an error." } Catch { Write-LogException $_ }
}