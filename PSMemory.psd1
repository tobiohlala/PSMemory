@{
    RootModule          = 'PSMemory.psm1'
    ModuleVersion       = '1.0.0'
    GUID                = '54d44ebf-3b85-428e-9030-a6b7581a50c2'
    Author              = 'Tobias Heilig'
    Copyright           = '3-Clause BSD Copyright 2019 Tobias Heilig'
    Description         = 'Windows 64 Bit Memory Scanner'
    FunctionsToExport   = @('Format-Memory','Search-Memory','Compare-Memory','Update-Memory')
    FormatsToProcess    = @('PSMemory.Format.ps1xml')
    TypesToProcess      = @('PSMemory.Types.ps1xml')
}
