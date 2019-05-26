<p align="center">
<img src="https://i.imgur.com/juiy5FS.png" alt="logo" height="250" width="250" />
</p>

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PSMemory.svg)](https://www.powershellgallery.com/packages/PSMemory)
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

**Example**: a search for two 32 bit numerical values *1234* and *5678* as well as the text *foo* within the memory of the process *foo* may look like
```Powershell
Get-Process foo | Search-Memory -Values @{
    Int = 1234, 5678
    String = 'foo'
}
```

#### `Compare-Memory`

compares such references' values as present in memory when the reference was created or last updated to the current
in-memory value.

#### `Update-Memory`

updates the current in-memory value referenced by a reference.  

#### `Format-Memory`

formats reference objects as returned by the aforementioned Cmdlets into readable output.  

## Installation

Install from [PowerShell Gallery](https://www.powershellgallery.com/packages/PSMemory)

```Powershell
Install-Module -Name PSMemory
```
or
```Shell
git clone https://github.com/off-world/PSMemory
```
