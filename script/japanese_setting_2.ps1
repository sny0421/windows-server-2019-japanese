#UIの言語を日本語で上書きします。
Set-WinUILanguageOverride -Language ja-JP

#時刻/日付の形式をWindowsの言語と同じにします。
Set-WinCultureFromLanguageListOptOut -OptOut $False

#ロケーションを日本にします。
Set-WinHomeLocation -GeoId 0x7A

#システムロケールを日本にします。
Set-WinSystemLocale -SystemLocale ja-JP

#タイムゾーンを東京にします。
Set-TimeZone -Id "Tokyo Standard Time"

# ユーザーのカルチャー設定を変更します。
Set-Culture ja-JP

# レジストリを変更し、Welcome スクリーンとデフォルトユーザーの表示言語を変更します。
$DefaultHKEY = "HKU\DEFAULT_USER"
$DefaultRegPath = "C:\Users\Default\NTUSER.DAT"

reg load $DefaultHKEY $DefaultRegPath
reg import "C:\ja-JP-default.reg"
reg unload $DefaultHKEY
reg import "C:\ja-JP-welcome.reg"
