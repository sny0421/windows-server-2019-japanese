$DefaultHKEY = "HKU\DEFAULT_USER"
$DefaultRegPath = "C:\Users\Default\NTUSER.DAT"

reg load $DefaultHKEY $DefaultRegPath
reg import "C:\Win10-ja-JP-default.reg"
reg unload $DefaultHKEY
reg import "C:\Win10-ja-JP-welcome.reg"

Remove-Item "C:\Win10-ja-JP-default.reg"
Remove-Item "C:\Win10-ja-JP-welcome.reg"
