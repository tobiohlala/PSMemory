<p align="center">
<img src="https://i.imgur.com/juiy5FS.png" alt="logo" height="250" width="250" />
</p>

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PSMemory.svg)](https://www.powershellgallery.com/packages/PSMemory)
![powershell version](https://img.shields.io/badge/powershell-v5-blue.svg)
![supported windows versions](https://img.shields.io/badge/supported%20windows%20versions-7%2F8%2F10-yellow.svg)
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/7f35ae966821403c9952a277d3e5d19a)](https://www.codacy.com/app/off-world/PSMemory?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=off-world/PSMemory&amp;utm_campaign=Badge_Grade)

___

**PSMemory** is a 64 bit windows memory scanner written in PowerShell hence fully automation capable.

___

## Description

### Cmdlets

#### `Search-Memory`

searches the virtual address space of a process for specific values returning references to the memory they reside in.
Besides the value itself these references contain other related information such as the concrete memory address or the protection of
the page the value was found in. A search can be specified by the `-Values` parameter in the form of a hashtable where the *keys* define
data types and the corresponding *values* define the values of that data type to be searched for as a comma-separated list. Valid data
types to be specified as *keys* for the search table are
-   **Byte** for 8 bit numerical values
-   **Short** for 16 bit numerical values
-   **Int** for 32 bit numerical values
-   **Long** for 64 bit numerical values
-   **String** for ASCII text of arbitrary length
-   **Bytes** for Unicode byte arrays of arbitrary length

**Example**: a search for two 32 bit numerical values *1234* and *5678* as well as the text *Notepad* within the memory of the process *notepad* saving the result in a variable *notepad* for further processing may look like
```Powershell
Get-Process notepad | Search-Memory -Values @{
    Int = 1234, 5678
    String = 'Notepad'
} -OutVariable notepad
```

#### `Compare-Memory`

compares those references' values as present in memory when the reference was created or last updated to the current
in-memory value. With the `-Changed` and `-Unchanged` parameters each reference will be matched whose in-memory value has either
changed in any way or stood the same. For numerical values exclusively there are additionally the `-Increased` and `-Decreased` parameters which track if the in-memory value did either become greater or lower. For everything else there is the `-Filter` parameter where a PowerShell ScriptBlock may be supplied with a custom comparison criteria.

**Example**: given the above search now keep only those references whose in-memory value is either exactly *42* or has increased and update the reference result variable
```Powershell
$notepad | Compare-Memory -Increased -Filter {$_.Value -eq 42} -OutVariable notepad
```

#### `Update-Memory`

updates the current in-memory value referenced by a reference. The new value to be written may be supplied by one of the data type parameters depending on what value of what size to write.

**Example:** after filtering the memory references above now update each remaining referenced in-memory value with a new 32 bit numerical value of *9876*
```Powershell
$notepad | Update-Memory -Int 9876
```
#### `Format-Memory`

formats reference objects as returned by **all** the aforementioned Cmdlets into formatted and human readable output.

**Example:**
```Powershell
Get-Process notepad | Search-Memory -Values @{Int = 42} -OutVariable notepad | Format-Memory
```
or
```Powershell
$notepad | Compare-Memory -Increased -Filter {$_.Value -eq 42} | Format-Memory
```
Alternatively, you can use the alias `fm`.

## Installation

Install from [PowerShell Gallery](https://www.powershellgallery.com/packages/PSMemory)

```Powershell
Install-Module -Name PSMemory
```
or
```Shell
git clone https://github.com/tobiohlala/PSMemory
```
