@echo off
REM Momentum repair: archive 7 dead legacy files, then verify. No git commands that change state.
cd /d "%~dp0"
if not exist _diag mkdir _diag
echo running > _diag\STATUS2.txt
fsutil volume diskfree C: > _diag\disk_free.txt 2>&1
set A=..\archive\legacy_mobile_lib
for %%D in (features\roadmap\data features\roadmap\presentation\pages features\workout\data features\dashboard\presentation\pages) do if not exist "%A%\%%D" mkdir "%A%\%%D"
(
move /Y lib\features\roadmap\data\achievements_repository.dart %A%\features\roadmap\data\
move /Y lib\features\roadmap\data\roadmap_repository.dart %A%\features\roadmap\data\
move /Y lib\features\roadmap\presentation\pages\achievements_page.dart %A%\features\roadmap\presentation\pages\
move /Y lib\features\roadmap\presentation\pages\galaxy_page.dart %A%\features\roadmap\presentation\pages\
move /Y lib\features\roadmap\presentation\pages\planet_page.dart %A%\features\roadmap\presentation\pages\
move /Y lib\features\roadmap\presentation\pages\roadmap_page.dart %A%\features\roadmap\presentation\pages\
move /Y lib\features\workout\data\workout_repository.dart %A%\features\workout\data\
move /Y lib\features\dashboard\presentation\pages\dashboard_page.dart %A%\features\dashboard\presentation\pages\
) > _diag\move.txt 2>&1
call flutter pub get > _diag\pub_get2.txt 2>&1
call flutter analyze --no-fatal-infos --no-fatal-warnings > _diag\analyze2.txt 2>&1
echo exit %ERRORLEVEL% >> _diag\analyze2.txt
call flutter test > _diag\test2.txt 2>&1
echo exit %ERRORLEVEL% >> _diag\test2.txt
call flutter build web --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=diag > _diag\build_web2.txt 2>&1
echo exit %ERRORLEVEL% >> _diag\build_web2.txt
fsutil volume diskfree C: >> _diag\disk_free.txt 2>&1
echo done > _diag\STATUS2.txt
