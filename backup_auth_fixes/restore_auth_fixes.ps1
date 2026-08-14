# 🚀 1-Click Restore Script
 = Get-Location
 = Join-Path  'backup_auth_fixes'
Copy-Item (Join-Path  'index.html') -Destination (Join-Path  'web\index.html') -Force
Copy-Item (Join-Path  'auth_service.dart') -Destination (Join-Path  'lib\services\auth_service.dart') -Force
Copy-Item (Join-Path  'database_service.dart') -Destination (Join-Path  'lib\services\database_service.dart') -Force
Copy-Item (Join-Path  'auth_provider.dart') -Destination (Join-Path  'lib\providers\auth_provider.dart') -Force
Copy-Item (Join-Path  'main.dart') -Destination (Join-Path  'lib\main.dart') -Force
Copy-Item (Join-Path  'account_screen.dart') -Destination (Join-Path  'lib\screens\account_screen.dart') -Force
Copy-Item (Join-Path  'login.dart') -Destination (Join-Path  'lib\screens\login.dart') -Force
Copy-Item (Join-Path  'pubspec.yaml') -Destination (Join-Path  'pubspec.yaml') -Force
Write-Host '✔ All 8 files successfully restored from backup_auth_fixes!' -ForegroundColor Green
