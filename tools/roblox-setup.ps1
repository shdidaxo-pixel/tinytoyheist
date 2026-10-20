# Creates Tiny Toy Heist's game passes and developer products on Roblox (Open Cloud) and writes their ids into
# src/ReplicatedStorage/Shared/ProductIds.luau. Safe to run again: anything that already exists (same name) is kept.
#
#   1. Creator Hub > (group) > Open Cloud > API Keys > Create: access "game-pass" (read, write) and
#      "developer-product" (read, write) for the experience Tiny Toy Heist. Copy the key.
#   2. In PowerShell, from the repo folder:
#        $env:ROBLOX_API_KEY = "<the key>"
#        powershell -ExecutionPolicy Bypass -File tools\roblox-setup.ps1
#   3. Commit ProductIds.luau, sync to Studio, publish.
#
# The list (names, prices, descriptions, icons) mirrors src/ReplicatedStorage/Shared/Monetization.luau: change both.

param([long]$UniverseId = 10771951800)

$ErrorActionPreference = "Stop"
$key = $env:ROBLOX_API_KEY
if (-not $key) { throw "Set `$env:ROBLOX_API_KEY first (see the top of this script)." }
$repo = Split-Path -Parent $PSScriptRoot
$icons = Join-Path $repo "assets\tth2"
Add-Type -AssemblyName System.Net.Http
$http = New-Object System.Net.Http.HttpClient
$http.DefaultRequestHeaders.Add("x-api-key", $key)

$mystery = "Mystery blankets delivered to your home. Odds: Common 45%, Uncommon 30%, Rare 15%, Epic 7%, Legendary 2.5%, Mythic 0.5%."
$passes = @(
	@{ key = "Speed"; name = "x2 Speed"; price = 99; icon = "PassSpeed3"; description = "Train Speed twice as fast on your Speed wheel. Forever!" },
	@{ key = "Cash"; name = "x2 Cash"; price = 499; icon = "PassCash3"; description = "Every toy in your pen earns double money. Forever!" },
	@{ key = "Luck"; name = "x2 Luck"; price = 399; icon = "PassLuck3"; description = "Every blanket rolls twice and you keep the rarer toy, plus double mutation luck." },
	@{ key = "VIP"; name = "VIP"; price = 799; icon = "PassVIP3"; description = "VIP chat tag and +50% cash from your toys." },
	@{ key = "FastHatch"; name = "Fast Hatch"; price = 249; icon = "Clock"; description = "Every blanket wakes up twice as fast. Forever!" },
	@{ key = "Slots"; name = "+5 Blanket Slots"; price = 149; icon = "PassSlots"; description = "Keep 11 blankets waking up in your home instead of 6." },
	@{ key = "SuperLock"; name = "Super Lock"; price = 99; icon = "Lock"; description = "Your door lock lasts twice as long (90 seconds)." }
)
$products = @(
	@{ key = "Mystery1"; name = "1 Mystery Blanket"; price = 99; icon = "Featured_hero"; description = $mystery },
	@{ key = "Mystery3"; name = "3 Mystery Blankets"; price = 249; icon = "Featured_hero"; description = $mystery },
	@{ key = "Mystery10"; name = "10 Mystery Blankets"; price = 799; icon = "Featured_hero"; description = $mystery },
	@{ key = "Mystery50"; name = "50 Mystery Blankets"; price = 3499; icon = "Featured_hero"; description = $mystery },
	@{ key = "Speed1"; name = "+150K Speed"; price = 59; icon = "SpeedPack1v2"; description = "Instantly adds Speed to your total." },
	@{ key = "Speed2"; name = "+1M Speed"; price = 199; icon = "SpeedPack2v2"; description = "Instantly adds Speed to your total." },
	@{ key = "Speed3"; name = "+10M Speed"; price = 459; icon = "SpeedPack3v2"; description = "Instantly adds Speed to your total." },
	@{ key = "Speed4"; name = "+50M Speed"; price = 999; icon = "SpeedPack4v2"; description = "Instantly adds Speed to your total." },
	@{ key = "Speed5"; name = "+250M Speed"; price = 1999; icon = "SpeedPack5v2"; description = "Instantly adds Speed to your total." },
	@{ key = "Cash1"; name = "+`$100K Cash"; price = 59; icon = "CashPack1v2"; description = "Instantly adds cash to your wallet." },
	@{ key = "Cash2"; name = "+`$500K Cash"; price = 199; icon = "CashPack2v2"; description = "Instantly adds cash to your wallet." },
	@{ key = "Cash3"; name = "+`$2M Cash"; price = 459; icon = "CashPack3v2"; description = "Instantly adds cash to your wallet." },
	@{ key = "Cash4"; name = "+`$20M Cash"; price = 999; icon = "CashPack4v2"; description = "Instantly adds cash to your wallet." },
	@{ key = "Cash5"; name = "+`$100M Cash"; price = 1999; icon = "CashPack5v2"; description = "Instantly adds cash to your wallet." },
	@{ key = "WakeAll"; name = "Wake All Blankets"; price = 29; icon = "Clock"; description = "Every blanket waiting in your home wakes up right now, ready to hatch." },
	@{ key = "Skip"; name = "Skip the Wait"; price = 15; icon = "Clock"; description = "One blanket in your home wakes up right now, ready to hatch." },
	@{ key = "CashBoost"; name = "x2 Cash for 15 Minutes"; price = 49; icon = "Cash"; description = "Double money from all your toys for 15 minutes. Stacks with everything." },
	@{ key = "ServerLuck"; name = "x2 Server Luck for 15 Minutes"; price = 99; icon = "PassLuck3"; description = "Everyone in the server gets x2 luck for 15 minutes: rarer toys and more mutations." },
	@{ key = "Lullaby"; name = "Lullaby"; price = 39; icon = "Moon"; description = "Sings the Giant Kid back to sleep right now and empties the wake meter, for the whole server." }
)
foreach ($p in $passes) {
	$products += @{ key = "Gift" + $p.key; name = "Gift: " + $p.name; price = $p.price; icon = $p.icon; description = "Gift the " + $p.name + " pass to another player." }
}

function List-All([string]$url, [string]$field) {
	$items = @(); $token = ""
	do {
		$u = $url + "?pageSize=50" + $(if ($token) { "&pageToken=" + [Uri]::EscapeDataString($token) } else { "" })
		$res = $http.GetAsync($u).Result
		$body = $res.Content.ReadAsStringAsync().Result
		if (-not $res.IsSuccessStatusCode) { throw "GET $u failed: $($res.StatusCode) $body" }
		$json = $body | ConvertFrom-Json
		if ($json.$field) { $items += $json.$field }
		$token = $json.nextPageToken
	} while ($token)
	return $items
}

function Create([string]$url, $item) {
	$form = New-Object System.Net.Http.MultipartFormDataContent
	$form.Add((New-Object System.Net.Http.StringContent($item.name)), "name")
	$form.Add((New-Object System.Net.Http.StringContent($item.description)), "description")
	$form.Add((New-Object System.Net.Http.StringContent("true")), "isForSale")
	$form.Add((New-Object System.Net.Http.StringContent([string]$item.price)), "price")
	$png = Join-Path $icons ($item.icon + ".png")
	if (Test-Path $png) {
		$file = New-Object System.Net.Http.ByteArrayContent(, [System.IO.File]::ReadAllBytes($png))
		$file.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("image/png")
		$form.Add($file, "imageFile", $item.icon + ".png")
	}
	$res = $http.PostAsync($url, $form).Result
	$body = $res.Content.ReadAsStringAsync().Result
	if (-not $res.IsSuccessStatusCode) { throw "Creating '$($item.name)' failed: $($res.StatusCode) $body" }
	Start-Sleep -Milliseconds 400 # create is limited to 3 a second
	return $body | ConvertFrom-Json
}

$passUrl = "https://apis.roblox.com/game-passes/v1/universes/$UniverseId/game-passes"
$productUrl = "https://apis.roblox.com/developer-products/v2/universes/$UniverseId/developer-products"
$existingPasses = List-All "$passUrl/creator" "gamePasses"
$existingProducts = List-All "$productUrl/creator" "developerProducts"

$passIds = [ordered]@{}
foreach ($p in $passes) {
	$found = $existingPasses | Where-Object { $_.name -eq $p.name } | Select-Object -First 1
	if ($found) { $id = $found.gamePassId; Write-Output "pass $($p.name): exists ($id)" }
	else { $id = (Create $passUrl $p).gamePassId; Write-Output "pass $($p.name): created ($id)" }
	$passIds[$p.key] = $id
}
$productIds = [ordered]@{}
foreach ($p in $products) {
	$found = $existingProducts | Where-Object { $_.name -eq $p.name } | Select-Object -First 1
	if ($found) { $id = $found.productId; Write-Output "product $($p.name): exists ($id)" }
	else { $id = (Create $productUrl $p).productId; Write-Output "product $($p.name): created ($id)" }
	$productIds[$p.key] = $id
}

$lines = @(
	"-- Written by tools/roblox-setup.ps1: the Roblox ids of the game passes and developer products (Monetization.luau).",
	"-- 0 or missing = not created yet. Safe to edit by hand (paste an id from the Creator Hub).",
	"return {",
	"`tPasses = {"
)
foreach ($k in $passIds.Keys) { $lines += "`t`t$k = $($passIds[$k])," }
$lines += "`t},"
$lines += "`tProducts = {"
foreach ($k in $productIds.Keys) { $lines += "`t`t$k = $($productIds[$k])," }
$lines += "`t},"
$lines += "}"
$out = Join-Path $repo "src\ReplicatedStorage\Shared\ProductIds.luau"
[System.IO.File]::WriteAllText($out, ($lines -join "`n") + "`n", (New-Object System.Text.UTF8Encoding($false)))
Write-Output "Wrote $out"
