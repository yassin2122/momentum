@echo off
REM Grit Analytics - pulls the new Analytics files from the
REM feature/athlete-analytics branch (new files only; your local edits are
REM untouched), then runs pub get, analyze and tests. Logs go to mobile\_analytics\
cd /d "%~dp0"
if not exist _analytics mkdir _analytics
echo running... > _analytics\STATUS.txt
cd ..
git fetch origin feature/athlete-analytics > mobile\_analytics\git_fetch.txt 2>&1
git checkout origin/feature/athlete-analytics -- mobile/lib/features/analytics mobile/test/features/analytics supabase/migrations/20261024200000_athlete_analytics_body_recovery.sql > mobile\_analytics\git_checkout.txt 2>&1
echo checkout exit %ERRORLEVEL% >> mobile\_analytics\git_checkout.txt
git status --short > mobile\_analytics\git_status.txt 2>&1
cd mobile
call flutter pub get > _analytics\pub_get.txt 2>&1
call flutter analyze --no-fatal-infos --no-fatal-warnings > _analytics\analyze.txt 2>&1
call flutter test test/features/analytics test/features/muscle_map test/features/workouts > _analytics\test.txt 2>&1
echo test exit %ERRORLEVEL% >> _analytics\test.txt
call flutter test > _analytics\test_all.txt 2>&1
echo test exit %ERRORLEVEL% >> _analytics\test_all.txt
echo done > _analytics\STATUS.txt
