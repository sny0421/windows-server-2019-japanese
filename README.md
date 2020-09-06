# windows-server-2019-japanese

## 目的
Azure Image Builder を使用して、日本語化された Windows Server 2019 イメージを自動生成する。

## 事前準備
### 機能の登録
サブスクリプション単位で実行します。（おそらくプレビュー中のみ）
一度だけ実行すれば次回以降はスキップで問題ないです。

```
Register-AzProviderFeature -FeatureName VirtualMachineTemplatePreview -ProviderNamespace Microsoft.VirtualMachineImages
Register-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages
Register-AzResourceProvider -ProviderNamespace Microsoft.Storage
Register-AzResourceProvider -ProviderNamespace Microsoft.Compute
Register-AzResourceProvider -ProviderNamespace Microsoft.KeyVault
```

### 機能登録の確認
各機能が**[registered]**になっていることを確認します。

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
Image Builder で自動的に仮想マシン作成〜イメージ作成まで行えるように、
サービスで使う資格情報と、必要な権限を提議したカスタムロールを作成します。

```
# カスタムロール名とマネージド ID 名の定義
$imageRoleDefName = "Azure Image Builder Image Def Preview"
$idenityName = "aibIdentityPreview"

# マネージド ID の作成
New-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $idenityName
## マネージド ID のリソース ID
$idenityNameResourceId = $(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $idenityName).Id
## マネージド ID のプリンシパル ID
$idenityNamePrincipalId = $(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $idenityName).PrincipalId

# AIB 用のカスタムロールを作成
## カスタムロール用テンプレートのダウンロードパスを定義
$aibRoleImageCreationUrl = "https://raw.githubusercontent.com/sny0421/windows-server-2019-japanese/master/aib-role-creation.json"
$aibRoleImageCreationPath = "aib-role-reation.json"
## カスタムロール用テンプレートをダウンロード
Invoke-WebRequest -Uri $aibRoleImageCreationUrl -OutFile $aibRoleImageCreationPath -UseBasicParsing

## カスタムロール用テンプレート内の変数を置換
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<imageRoleDefName>', $imageRoleDefName) | Set-Content -Path $aibRoleImageCreationPath
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<subscriptionID>',$subscriptionID) | Set-Content -Path $aibRoleImageCreationPath
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<rgName>', $imageResourceGroup) | Set-Content -Path $aibRoleImageCreationPath

## カスタムロールを作成
New-AzRoleDefinition -InputFile ./aibRoleImageCreation.json

## マネージド ID にカスタムロールを割り当て
New-AzRoleAssignment -ObjectId $idenityNamePrincipalId -RoleDefinitionName $imageRoleDefName -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"
```

## 共有イメージギャラリーの作成
カスタムイメージを保存する共有イメージギャラリーを作成します。

```
# 変数の定義
## 共有イメージギャラリーの名前
$sigGalleryName= "MyAibSig001"
## イメージ定義の名前
$sigImageDefineName ="winSvr2019JP"
## レプリカするリージョンの指定
$repLocation = "japaneast"

# 共有ギャラリーの作成
New-AzGallery -GalleryName $sigGalleryName -ResourceGroupName $imageResourceGroup -Location $location

# イメージ定義の作成
New-AzGalleryImageDefinition -GalleryName $sigGalleryName -ResourceGroupName $imageResourceGroup -Location $location -Name $sigImageDefineName -OsState generalized -OsType Windows -Publisher 'AIB' -Offer 'Windows' -Sku 'Win2019JP'
```

## AIB のイメージテンプレート作成

```
# イメージテンプレートの作成
## イメージテンプレートのダウンロード URL を定義
$templateUrl="https://raw.githubusercontent.com/sny0421/windows-server-2019-japanese/master/image-build-template.json"
$templateFilePath = "image-build-template.json"
## イメージテンプレートをダウンロード
Invoke-WebRequest -Uri $templateUrl -OutFile $templateFilePath -UseBasicParsing


((Get-Content -path $templateFilePath -Raw) -replace '<subscriptionID>',$subscriptionID) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<rgName>',$imageResourceGroup) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<region>',$location) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<runOutputName>',$runOutputName) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<sharedImageGalName>',$sigGalleryName) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<imageDefName>',$sigImageDefineName) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<region1>',$location) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<region2>',$repLocation) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<imgBuilderId>',$idenityNameResourceId) | Set-Content -Path $templateFilePath
```

## イメージテンプレートのデプロイ
カスタムイメージテンプレートをデプロイします。

```
## イメージテンプレートのデプロイ
New-AzResourceGroupDeployment -ResourceGroupName $imageResourceGroup -TemplateFile $templateFilePath -api-version "2019-05-01-preview" -imageTemplateName $imageTemplateName -svclocation $location
```

## イメージテンプレートからのイメージ展開
デプロイしたイメージテンプレートを使用し、カスタムイメージリソースを作成します。

```
## イメージテンプレートの展開実行
Invoke-AzResourceAction -ResourceName $imageTemplateName -ResourceGroupName $imageResourceGroup -ResourceType Microsoft.VirtualMachineImages/imageTemplates -ApiVersion "2019-05-01-preview" -Action Run -Force
```

### イメージ展開状況の確認

```
### Step 1: Update context
$currentAzureContext = Get-AzContext

### Step 2: Get instance profile
$azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
$profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    
Write-Verbose ("Tenant: {0}" -f  $currentAzureContext.Subscription.Name)
 
### Step 4: Get token  
$token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
$accessToken=$token.AccessToken

$managementEp = $currentAzureContext.Environment.ResourceManagerUrl


$urlBuildStatus = [System.String]::Format("{0}subscriptions/{1}/resourceGroups/$imageResourceGroup/providers/Microsoft.VirtualMachineImages/imageTemplates/{2}?api-version=2019-05-01-preview", $managementEp, $currentAzureContext.Subscription.Id,$imageTemplateName)

$buildJsonStatus = (Invoke-WebRequest -Method GET  -Uri $urlBuildStatus -UseBasicParsing -Headers  @{"Authorization"= ("Bearer " + $accessToken)} -ContentType application/json).content
```

## イメージから VM を作成
