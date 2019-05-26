<p align="center">
<img src="https://i.imgur.com/juiy5FS.png" alt="logo" height="250" width="250" />
</p>

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PSMemory.svg)](https://www.powershellgallery.com/packages/PSMemory)
![supported windows versions](https://img.shields.io/badge/supported%20windows%20versions-7%2F8%2F10-yellow.svg)
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/7f35ae966821403c9952a277d3e5d19a)](https://www.codacy.com/app/off-world/PSMemory?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=off-world/PSMemory&amp;utm_campaign=Badge_Grade)

___

**PSMemory** is a 64 bit windows memory scanner written in PowerShell hence fully automation capable.



## Cmdlets

-  `Search-Memory`
searches the virtual address space of a process for specific values returning references to the memory they reside in.
-  `Compare-Memory`
compares such references' values as present in memory when the reference was created or last updated to the current
in-memory value.
-  `Update-Memory`
updates the current in-memory value referenced by a reference.
-  `Format-Memory`
formats reference objects as returned by the aforementioned Cmdlets into readable output.
