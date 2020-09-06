# windows-server-2019-japanese

## 目的
Azure Image Builder を使用して、日本語化された Windows Server 2019 イメージを自動生成する。

## 機能の登録
プレビュー中のみ。サブスクリプションで一度実行すればいい。

```
Register-AzProviderFeature -FeatureName VirtualMachineTemplatePreview -ProviderNamespace Microsoft.VirtualMachineImages
Register-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages
Register-AzResourceProvider -ProviderNamespace Microsoft.Storage
Register-AzResourceProvider -ProviderNamespace Microsoft.Compute
Register-AzResourceProvider -ProviderNamespace Microsoft.KeyVault
```

### 機能登録の確認
各機能が**[registered]**になっていることを確認。

```
Get-AzProviderFeature -FeatureName VirtualMachineTemplatePreview -ProviderNamespace Microsoft.VirtualMachineImages
Get-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages
Get-AzResourceProvider -ProviderNamespace Microsoft.Storage 
Get-AzResourceProvider -ProviderNamespace Microsoft.Compute
Get-AzResourceProvider -ProviderNamespace Microsoft.KeyVault
```

## 環境設定とリソースグループ作成

```
# モジュールのインポート
Import-Module Az.Accounts

# 現在のコンテキストを取得
$currentAzContext = Get-AzContext

# 変数の定義
## Image Builder でイメージをデプロイするリソースグループの名前
$imageResourceGroup = "AIB-Deploy-RG"

## Image Builder でイメージをデプロイするリージョン
## (East US. East US 2, West Central US, West US, West US 2, North Europe, West Europe)
$location="westus"

## 現在のサブスクリプション ID を取得
$subscriptionID = $currentAzContext.Subscription.Id

## 作成するイメージの名前
$imageName = "AIB-Windows-SV"

## Image Builder に登録するイメージテンプレートの名前
$imageTemplateName = "AIB-Windows-Server-2019-Japanese-Template"

## 出力オブジェクトの識別名
$runOutputName = "AIB-Output"

# リソースグループの作成
New-AzResourceGroup -Name $imageResourceGroup -Location $location
```

## Azure Image Builder 用のマネージド ID とロールを作成
```
# ロール名の定義（一意にするため、Azure Image Builder Image Def+xxx）
$timeInt=$(get-date -UFormat "%s")
$imageRoleDefName = "Azure Image Builder Image Def"+$timeInt
$idenityName = "aibIdentity"+$timeInt

## Add AZ PS module to support AzUserAssignedIdentity
Install-Module -Name Az.ManagedServiceIdentity
Import-Module Az.ManagedServiceIdentity

# マネージド ID の作成
New-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $idenityName
## マネージド ID のリソース ID
$idenityNameResourceId=$(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $idenityName).Id
## マネージド ID のプリンシパル ID
$idenityNamePrincipalId=$(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $idenityName).PrincipalId
```

```
# AIB 用のカスタムロールを作成
## テンプレートのダウンロードパスを定義
$aibRoleImageCreationUrl="https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/solutions/12_Creating_AIB_Security_Roles/aibRoleImageCreation.json"
$aibRoleImageCreationPath = "aibRoleImageCreation.json"
## テンプレートをダウンロード
Invoke-WebRequest -Uri $aibRoleImageCreationUrl -OutFile $aibRoleImageCreationPath -UseBasicParsing

## テンプレート内の変数を置換
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<subscriptionID>',$subscriptionID) | Set-Content -Path $aibRoleImageCreationPath
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<rgName>', $imageResourceGroup) | Set-Content -Path $aibRoleImageCreationPath
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace 'Azure Image Builder Service Image Creation Role', $imageRoleDefName) | Set-Content -Path $aibRoleImageCreationPath

## ロールを作成
New-AzRoleDefinition -InputFile  ./aibRoleImageCreation.json

## マネージド ID にロールを割り当て
New-AzRoleAssignment -ObjectId $idenityNamePrincipalId -RoleDefinitionName $imageRoleDefName -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"
```

```
# イメージテンプレートの作成
## イメージテンプレートのダウンロード URL を定義
$templateUrl="https://raw.githubusercontent.com/sny0421/windows-server-2019-japanese/master/image-build-template.json"
$templateFilePath = "armImageBuilderTemplate.json"
## イメージテンプレートをダウンロード
Invoke-WebRequest -Uri $templateUrl -OutFile $templateFilePath -UseBasicParsing


((Get-Content -path $templateFilePath -Raw) -replace '<subscriptionID>',$subscriptionID) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<rgName>',$imageResourceGroup) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<region>',$location) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<runOutputName>',$runOutputName) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<imageDefName>',$sigImageDefineName) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<sharedImageGalName>',$sigGalleryName) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<region1>',$location) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<region2>',$repLocation) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<imgBuilderId>',$idenityNameResourceId) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<imageName>',$imageName) | Set-Content -Path $templateFilePath

## イメージテンプレートのデプロイ
New-AzResourceGroupDeployment -ResourceGroupName $imageResourceGroup -TemplateFile $templateFilePath -api-version "2019-05-01-preview" -imageTemplateName $imageTemplateName -svclocation $location
```


