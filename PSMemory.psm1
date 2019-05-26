# BSD 3-Clause License
#
# Copyright(c) 2019, Tobias Heilig
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copynotice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copynotice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyholder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYHOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYHOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


try {
    & {
        $ErrorActionPreference = 'Stop'
        [void] [PSMemory.Native]
    }
} catch {
    Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        namespace PSMemory {
            public class Native {
                [StructLayout(LayoutKind.Sequential)]
                public struct SYSTEM_INFO {
                public ushort wProcessorArchitecture;
                public ushort wReserved;
                public uint dwPageSize;
                public IntPtr lpMinimumApplicationAddress;
                public IntPtr lpMaximumApplicationAddress;
                public UIntPtr dwActiveProcessorMask;
                public uint dwNumberOfProcessors;
                public uint dwProcessorType;
                public uint dwAllocationGranularity;
                public ushort wProcessorLevel;
                public ushort wProcessorRevision;
                };

                [StructLayout(LayoutKind.Sequential)] 
                public struct PSMemoryORY_BASIC_INFORMATION64 { 
                    public ulong BaseAddress; 
                    public ulong AllocationBase; 
                    public int AllocationProtect; 
                    public int __alignment1; 
                    public ulong RegionSize; 
                    public int State; 
                    public int Protect; 
                    public int Type; 
                    public int __alignment2; 
                }

                [DllImport("kernel32.dll", SetLastError = true)]
                public static extern IntPtr OpenProcess(
                    uint processAccess,
                    bool bInheritHandle,
                    int processId);

                [DllImport("kernel32.dll", SetLastError = true)]
                public static extern void GetNativeSystemInfo(
                    ref SYSTEM_INFO lpSystemInfo);

                [DllImport("kernel32.dll", SetLastError = true)] 
                public static extern int VirtualQueryEx(
                    IntPtr hProcess,
                    IntPtr lpAddress,
                    out MEMORY_BASIC_INFORMATION64 lpBuffer,
                    uint dwLength);
                
                [DllImport("kernel32.dll", SetLastError = true)]
                public static extern bool ReadProcessMemory(
                    IntPtr hProcess, 
                    IntPtr lpBaseAddress,
                    byte[] lpBuffer, 
                    Int32 nSize, 
                    out IntPtr lpNumberOfBytesRead);

                [DllImport("kernel32.dll", SetLastError = true)]
                public static extern bool WriteProcessMemory(
                    IntPtr hProcess, 
                    IntPtr lpBaseAddress,
                    byte[] lpBuffer, 
                    Int32 nSize, 
                    out IntPtr lpNumberOfBytesWritten);

                [DllImport("kernel32.dll", SetLastError=true)]
                public static extern bool CloseHandle(
                    IntPtr hHandle);

                [DllImport("msvcrt.dll", CallingConvention=CallingConvention.Cdecl)]
                public static extern int memcmp(
                    byte[] b1,
                    byte[] b2,
                    long count);
            }
        }
"@
}


function New-Win32Exception {
    param(
        $LastWin32Error,
        $From
    )
    $e = [ComponentModel.Win32Exception]$LastWin32Error
    [ComponentModel.Win32Exception]::New(
        "$From (0x$($e.HResult.ToString('x8'))): $($e.Message)"
    )
}


function Format-Memory {
    [Alias('fm')]
    [OutputType([PSObject[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position=0)]
        [Microsoft.PowerShell.Commands.GroupInfo]
        $Memory
    )

    $Memory | Select-Object -ExpandProperty Group

    <#
        .SYNOPSIS
        Format memory references

        .DESCRIPTION
        Turn a memory reference group object into readable format.

        .PARAMETER Memory
        A memory reference Microsoft.PowerShell.Commands.GroupInfo object as returned
        by the *-Memory Cmdlets in this module.

        .INPUTS
        Microsoft.PowerShell.Commands.GroupInfo

        .OUTPUTS
        System.Management.Automation.PSObject
    #>
}


function Search-Memory {
    [Alias('srmem')]
    [OutputType([Microsoft.PowerShell.Commands.GroupInfo])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Diagnostics.Process]
        $Process,

        [Parameter(Mandatory, Position=0)]
        [System.Collections.Hashtable]
        $Values
    )

    $searchObjects = foreach ($type in $Values.Keys) {
        foreach ($val in $Values[$type]) {
            $size, $bytes = switch ($type) {
                'Byte' {
                    1, $val
                }
                'Short' {
                    2, [BitConverter]::GetBytes($val)
                }
                'Int' {
                    4, [BitConverter]::GetBytes($val)
                }
                'Long' {
                    8, [BitConverter]::GetBytes($val)
                }
                'Bytes' {
                    $val.Length, $val
                }
                'String' {
                    $val.Length, [Text.Encoding]::ASCII.GetBytes($val)
                }
                default {
                    Write-Error -Exception (New-Object System.ArgumentException) `
                        -Category InvalidData -TargetObject $Values -ErrorAction Stop `
                        -Message "Unsupported value type '$type'. Supported " + `
                            "value types are Byte, Short, Int, Long, String and Bytes."
                }
            }
            [PSCustomObject]@{
                value = $val
                type = $type
                size = $size
                bytes = $bytes
            }
        }
    }

    # PROCESS_QUERY_INFORMATION (0x0400) | PROCESS_VM_READ (0x10)
    if (($processHandle = [PSMemory.Native]::OpenProcess(
            0x0400 -bor 0x10,
            $false,
            $Process.Id)) -eq [IntPtr]::Zero
    ) {
        $e = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw New-Win32Exception $e -From OpenProcess
    }

    $systemInfo = New-Object PSMemory.Native+SYSTEM_INFO
    [PSMemory.Native]::GetNativeSystemInfo([ref]$systemInfo)
    $minAddress = [long]$systemInfo.lpMinimumApplicationAddress
    $maxAddress = [long]$systemInfo.lpMaximumApplicationAddress

    $memoryInfo = New-Object PSMemory.Native+MEMORY_BASIC_INFORMATION64
    $memoryInfoSize = [Runtime.InteropServices.Marshal]::SizeOf($memoryInfo)

    $progressTimer = [System.Diagnostics.Stopwatch]::StartNew()

    $searchResult = `
	for ($baseAddress = $minAddress; $baseAddress -lt $maxAddress; $baseAddress += $memoryRegionSize) {
        if ([PSMemory.Native]::VirtualQueryEx(
                $processHandle,
				$baseAddress,
				[ref]$memoryInfo,
                $memoryInfoSize) -eq 0
        ) {
            $e = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            throw New-Win32Exception $e -From VirtualQueryEx
        }

        $memoryRegionSize = [long]$memoryInfo.RegionSize

        if ($progressTimer.Elapsed.TotalMilliseconds -ge 500) {
            $percentComplete = ($baseAddress-$minAddress)/($maxAddress-$minAddress)*100
            Write-Progress -Activity 'Searching Virtual Address Space' `
                -Status "$baseAddress/$maxAddress" -PercentComplete $percentComplete
            $progressTimer.Restart()
        }

        # PAGE_GUARD (0x100)
        if ($memoryInfo.Protect -band 0x100) {
            continue
        }

        # MEM_COMMIT (0x1000)
        # PAGE_READWRITE (0x04) | PAGE_WRITECOPY (0x08) | PAGE_EXECUTE_READWRITE (0x40) | PAGE_EXECUTE_WRITECOPY (0x80)
        if ($memoryInfo.State -band 0x1000 -and
            $memoryInfo.Protect -band (0x04 -bor 0x08 -bor 0x40 -bor 0x80)
        ) {
            $buffer = [byte[]]::New($memoryRegionSize)
            if ([PSMemory.Native]::ReadProcessMemory(
                    $processHandle,
                    $baseAddress,
                    $buffer,
                    $memoryRegionSize,
                    [ref][IntPtr]::Zero) -eq 0
            ) {
                $e = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
                throw New-Win32Exception $e -From ReadProcessMemory
            }

            foreach ($obj in $searchObjects) {
                $offset = -1
                while (($offset = [array]::IndexOf($buffer, $obj.bytes[0], $offset+1)) -ge 0) {
                    if ([PSMemory.Native]::memcmp(
                            $buffer[$offset..($offset+$obj.size-1)],
                            $obj.bytes,
                            $obj.size) -eq 0
                    ) {
                        $match = [PSCustomObject]@{
                            ProcessName = $Process.Name
                            ProcessId = $Process.Id
                            Address = $baseAddress + $offset
                            Value = $obj.value
                            Type = $obj.type
                            Size = $obj.size
                            Page = switch ($memoryInfo.Type) {
                                0x1000000 {
                                    'Image'
                                }
                                0x40000 {
                                    'Mapped'
                                }
                                0x20000 {
                                    'Private'
                                }
                            }
                            Protection = switch ($memoryInfo.Protect) {
                                0x04 {
                                    'ReadWrite'
                                }
                                0x08 {
                                    'WriteCopy'
                                }
                                0x40 {
                                    'ExecuteReadWrite'
                                }
                                0x80 {
                                    'ExecuteWriteCopy'
                                }
                            }
                            RegionStart = $memoryInfo.BaseAddress
                            RegionSize = $memoryRegionSize
                        }
                        $match.PSObject.TypeNames.Insert(0, 'PSMemory.Reference')
                        $match
                    }
                }
            }
        }
    }

    $searchResult | Group-Object -Property ProcessId

    [void] [PSMemory.Native]::CloseHandle($processHandle)

    <#
        .SYNOPSIS
        Search process memory

        .DESCRIPTION
        Search any values within the virtual address space of a process.

        .PARAMETER Process
        A System.Diagnostics.Process object as returned by the Get-Process Cmdlet
        representing the process whose memory to scan.

        .PARAMETER Values
        A System.Collections.Hashtable containing typed values to search for. The keys of
        the hashtable define the data type while the corresponding values may contain a
        comma-separated list of concrete values of that type to search for. Valid data
        types respectively hashtable keys are Byte, Short, Int, Long, String and Bytes.

        .INPUTS
        System.Diagnostics.Process
        System.Collections.Hashtable

        .OUTPUTS
        Microsoft.PowerShell.Commands.GroupInfo

        .COMPONENT
        Windows API

        .EXAMPLE
        Get-Process notepad | Search-Memory -Values @{Int=1234,5678; String='Notepad'}
    #>
}


function Compare-Memory {
    [Alias('crmem')]
    [OutputType([Microsoft.PowerShell.Commands.GroupInfo])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position=0)]
        [Microsoft.PowerShell.Commands.GroupInfo]
        $Reference,

        [ScriptBlock]
        $Filter,

        [switch]
        $Increased,

        [switch]
        $Decreased,

        [switch]
        $Changed,

        [switch]
        $Unchanged
    )

    # PROCESS_QUERY_INFORMATION (0x0400) | PROCESS_VM_READ (0x10)
    if (($processHandle = [PSMemory.Native]::OpenProcess(
            0x0400 -bor 0x10,
            $false,
            $Reference.Name)) -eq [IntPtr]::Zero
    ) {
        $e = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw New-Win32Exception $e -From OpenProcess
    }

    $compareResult = `
    foreach ($ref in $Reference.Group) {
        $buffer = [byte[]]::New($ref.Size)
        if ([PSMemory.Native]::ReadProcessMemory(
                $processHandle,
                $ref.Address,
                $buffer,
                $ref.Size,
                [ref][IntPtr]::Zero) -eq 0
        ) {
            $e = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            throw New-Win32Exception $e -From ReadProcessMemory
        }

        $value = switch ($ref.Type) {
            'Byte' {
                $buffer[0]
            }
            'Short' {
                [BitConverter]::ToInt16($buffer, 0)
            }
            'Int' {
                [BitConverter]::ToInt32($buffer, 0)
            }
            'Long' {
                [BitConverter]::ToInt64($buffer, 0)
            }
            'Bytes' {
                $buffer
            }
            'String' {
                [Text.Encoding]::ASCII.GetString($buffer)
            }
        }

        $match = $ref.PSObject.Copy()
        $match.Value = $value

        if ($ref.Type -in 'Byte','Short','Int','Long') {
            if ($Increased.IsPresent -and ($value -gt $ref.Value)) {
                    $match
                    continue
            }

            if ($Decreased.IsPresent -and ($value -lt $ref.Value)) {
                    $match
                    continue
            }
        }

        if ($Changed.IsPresent -and ($value -ne $ref.Value)) {
                $match
                continue
        }

        if ($Unchanged.IsPresent -and ($value -eq $ref.Value)) {
                $match
                continue
        }

        if ($PSBoundParameters.ContainsKey('Filter') -and ($ref | Where-Object $Filter)) {
                $match
                continue
        }
    }

    $compareResult | Group-Object -Property ProcessId

    <#
        .SYNOPSIS
        Compare process memory

        .DESCRIPTION
        Compare memory references found by the Search-Memory Cmdlet with their current in-memory
        values as present in the virtual address space of the process.

        .PARAMETER Reference
        A Microsoft.PowerShell.Commands.GroupInfo object representing memory references as returned by
        the Search-Memory or Compare-Memory Cmdlets.

        .PARAMETER Filter
        A System.Management.Automation.ScriptBlock representing a filter being applied to the memory
        references whether to include them in the result.

        .PARAMETER Increased
        Include those memory references in the result whose in-memory value has increased. Only applies
        to numerical values.

        .PARAMETER Decreased
        Include those memory references in the result whose in-memory value has decreased. Only applies
        to numerical values.

        .PARAMETER Changed
        Include those memory references in the result whose in-memory value has changed.
        
        .PARAMETER Unchanged
        Include those memory references in the result whose in-memory value has not changed.

        .INPUTS
        Microsoft.PowerShell.Commands.GroupInfo
        System.Management.Automation.ScriptBlock

        .OUTPUTS
        Microsoft.PowerShell.Commands.GroupInfo

        .COMPONENT
        Windows API
        
        .EXAMPLE
        Get-Process notepad | Search-Memory -Values @{Int=1234} -OutVariable matches
        $matches | Compare-Memory -Increased -Filter {$_.Value -lt 1000}
    #>
}


function Update-Memory {
    [CmdletBinding()]
    [Alias('udmem')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position=0)]
        [Microsoft.PowerShell.Commands.GroupInfo]
        $Reference,

        [Parameter(Mandatory, ParameterSetName='Byte')]
        [byte]
        $Byte,

        [Parameter(Mandatory, ParameterSetName='Short')]
        [int16]
        $Short,

        [Parameter(Mandatory, ParameterSetName='Int')]
        [int32]
        $Int,

        [Parameter(Mandatory, ParameterSetName='Long')]
        [long]
        $Long,

        [Parameter(Mandatory, ParameterSetName='String')]
        [string]
        $String,

        [Parameter(Mandatory, ParameterSetName='Bytes')]
        [byte[]]
        $Bytes
    )

    $valueSize, $value, $valueBytes = switch ($PSCmdlet.ParameterSetName) {
        'Byte' {
            1, $Byte, $Byte
        }
        'Short' {
            2, $Short, [BitConverter]::GetBytes($Short)
        }
        'Int' {
            4, $Int, [BitConverter]::GetBytes($Int)
        }
        'Long' {
            8, $Long, [BitConverter]::GetBytes($Long)
        }
        'Bytes' {
            $Bytes.Length, $Bytes, $Bytes
        }
        'String' {
            $String.Length, $String,[Text.Encoding]::ASCII.GetBytes($String)
        }
    }

    # PROCESS_QUERY_INFORMATION (0x0400) | PROCESS_VM_WRITE (0x20)
    if (($processHandle = [PSMemory.Native]::OpenProcess(
            0x0400 -bor 0x20,
            $false,
            $Reference.Name)) -eq [IntPtr]::Zero
    ) {
        $e = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw New-Win32Exception $e -From OpenProcess
    }

    $updateResult = `
    foreach ($ref in $Reference.Group) {
        if ([PSMemory.Native]::WriteProcessMemory(
                $processHandle,
                $ref.Address,
                $valueBytes,
                $valueSize,
                [ref][IntPtr]::Zero) -eq 0
        ) {
            $e = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            throw New-Win32Exception $e -From WriteProcessMemory
        }

        $newRef = $ref.PSObject.Copy()
        $newRef.Value = $value
        $newRef.Type = $PSCmdlet.ParameterSetName
        $newRef.Size = $valueSize

        $newRef
    }

    $updateResult | Group-Object -Property ProcessId

    <#
        .SYNOPSIS
        Update process memory

        .DESCRIPTION
        Update in-memory values as present in the virtual address space of a process represented by
        memory references as returned from the Search-Memory and Compare-Memory Cmdlets.

        .PARAMETER Reference
        A Microsoft.PowerShell.Commands.GroupInfo object representing memory references as returned by
        the Search-Memory or Compare-Memory Cmdlet.

        .PARAMETER Byte
        An 8-Bit numerical value to update the in-memory value represented by the memory reference with.

        .PARAMETER Short
        A 16-Bit numerical value to update the in-memory value represented by the memory reference with.

        .PARAMETER Int
        A 32-Bit numerical value to update the in-memory value represented by the memory reference with.

        .PARAMETER Long
        A 64-Bit numerical value to update the in-memory value represented by the memory reference with.
        
        .PARAMETER String
        A string value to update the in-memory value represented by the memory reference with.
        
        .PARAMETER Bytes
        A byte array value to update the in-memory value represented by the memory reference with.

        .INPUTS
        Microsoft.PowerShell.Commands.GroupInfo

        .OUTPUTS
        Microsoft.PowerShell.Commands.GroupInfo

        .COMPONENT
        Windows API
        
        .EXAMPLE
        Get-Process notepad | Search-Memory -Values @{Int=1234} | Update-Memory -Int 4321

        .EXAMPLE
        Get-Process notepad | Search-Memory -Values @{Long=123456789} -OutVariable matches
        $matches | Compare-Memory -Changed
        $matches | Update-Memory -Long 123456789
    #>
}

